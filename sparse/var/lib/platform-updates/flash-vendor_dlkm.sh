#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: GPL-2.0-only
#
# Preinit oneshot: write /boot/vendor_dlkm.img (droid-hal-pdx246-vendor_dlkm)
# into the logical partition vendor_dlkm_a of super. UNTESTED on the phone.
#
# Registered by droid-hal-pdx246-vendor_dlkm on upgrade and by
# pdx246-kernel-set.sh when a kernel release change is flashed. It runs in
# preinit, before systemd, so /vendor_dlkm is not mounted and nothing has the
# partition open. It only writes once the running kernel is the one the
# modules were built for (/boot/vendor_dlkm.release == uname -r): the first
# boot of a new kernel. Until then it exits non-zero, which keeps it
# registered for the next boot.
#
# It also waits one more boot when vendor_boot_a was rewritten in this boot
# (pdx246-kernel-set.sh records that boot's boot_id in .pdx246-set-written):
# the initrd of this boot loaded the old first-stage modules, which a rebuild
# with an unchanged kernel release would otherwise mix with the new
# second-stage ones.
#
# How: check that flash-partition will write at all (CPUCHECK_STRING), map
# vendor_dlkm_a read-write under a private name from the super metadata
# (parse-android-dynparts, slot a), check that the unsparsed image fits the
# partition, write it with flash-partition, read the partition back and
# compare (flash-partition exits 0 without writing when its CPU check fails,
# and does not check dd), unmap. The metadata of super is never written, so
# the partition cannot grow; an image that does not fit has to be flashed
# from fastbootd (fastboot flash vendor_dlkm_a), which resizes it.

. /var/lib/platform-updates/pdx246-kernel-set.sh

NAME=pdx246-vendor_dlkm-update
DEV=/dev/mapper/$NAME
# Unsparsed copy for the read-back check of a sparse image. /var/tmp, not
# /tmp: in preinit /tmp is still the root file system's directory, which the
# tmpfs mounted later would hide.
RAW=/var/tmp/pdx246-vendor_dlkm.raw

fail() {
    ks_log "flash-vendor_dlkm.sh: $*"
    rm -f "$RAW"
    dmsetup remove "$NAME" >/dev/null 2>&1 || :
    exit 1
}

ks_on_slot_a || fail "not running from slot a; nothing flashed"
ks_cpucheck || fail "CPUCHECK_STRING of /var/lib/flash-partition/device-info not found in the DT model or /proc/cpuinfo, so flash-partition would not write; nothing flashed"

[ -f "$KS_DLKM_IMG" ] || fail "$KS_DLKM_IMG missing"
want=$(cat "$KS_DLKM_RELEASE" 2>/dev/null)
running=$(uname -r)
[ -n "$want" ] || fail "$KS_DLKM_RELEASE missing or empty"
if [ "$want" != "$running" ]; then
    ks_log "flash-vendor_dlkm.sh: modules are for $want, running $running; flashing at the first boot of $want"
    exit 1
fi

bid=$(ks_boot_id)
[ -n "$bid" ] || fail "cannot read /proc/sys/kernel/random/boot_id"
if [ "$(cat "$KS_SET_WRITTEN" 2>/dev/null)" = "$bid" ]; then
    ks_log "flash-vendor_dlkm.sh: vendor_boot_a was rewritten in this boot; flashing at the next boot"
    exit 1
fi

# Never write under a mounted file system (the script run by hand, later).
if grep -qs ' /vendor_dlkm ' /proc/mounts; then
    fail "/vendor_dlkm is mounted; run this only from preinit"
fi

SUPER=/dev/disk/by-partlabel/super
[ -b "$SUPER" ] || SUPER=/dev/sda95
[ -b "$SUPER" ] || fail "no super block device"

# "dynpart-vendor_dlkm_a,,,ro,<table>[,<table>...]" -> private name, rw
ENTRY=$(parse-android-dynparts "$SUPER" | tr ';' '\n' | grep '^dynpart-vendor_dlkm_a,')
[ -n "$ENTRY" ] || fail "vendor_dlkm_a not found in the super metadata"
RW=$(echo "$ENTRY" | sed -e "s/^dynpart-vendor_dlkm_a,/$NAME,/" \
                         -e 's/^\([^,]*,[^,]*,[^,]*,\)ro,/\1rw,/')

dmsetup remove "$NAME" >/dev/null 2>&1 || :
# No udev runs in preinit: do not wait for it, create the node directly.
dmsetup create --noudevsync --concise "$RW" || fail "dmsetup create failed"
dmsetup mknodes "$NAME" >/dev/null 2>&1 || :
[ -b "$DEV" ] || fail "$DEV did not appear"

PART_SIZE=$(blockdev --getsize64 "$DEV") || fail "cannot read the size of $DEV"

# Size of the image once unsparsed: Android sparse header (magic 0xed26ff3a,
# little endian), blk_sz at byte 12 and total_blks at byte 16.
MAGIC=$(od -An -t x4 -N 4 "$KS_DLKM_IMG" | tr -d ' \n')
if [ "$MAGIC" = "ed26ff3a" ]; then
    set -- $(od -An -t u4 -j 12 -N 8 "$KS_DLKM_IMG")
    IMG_SIZE=$(( $1 * $2 ))
else
    IMG_SIZE=$(stat -c %s "$KS_DLKM_IMG")
fi

if [ "$IMG_SIZE" -gt "$PART_SIZE" ]; then
    fail "image needs $IMG_SIZE bytes, vendor_dlkm_a has $PART_SIZE; flash it from fastbootd"
fi

# flash-partition needs simg2img for a sparse image, and without it deletes
# the image file; the read-back check needs it as well.
if [ "$MAGIC" = "ed26ff3a" ] && ! command -v simg2img >/dev/null 2>&1; then
    fail "simg2img missing (droid-hal-pdx246-tools); nothing flashed"
fi

ks_log "flash-vendor_dlkm.sh: writing $KS_DLKM_IMG ($want) to vendor_dlkm_a"
flash-partition "$DEV" "$KS_DLKM_IMG" || fail "flash-partition failed"
sync

# Read back: the first IMG_SIZE bytes of the partition must equal the
# (unsparsed) image.
if [ "$MAGIC" = "ed26ff3a" ]; then
    rm -f "$RAW"
    simg2img "$KS_DLKM_IMG" "$RAW" || fail "simg2img failed; cannot verify vendor_dlkm_a"
    REF=$RAW
else
    REF=$KS_DLKM_IMG
fi
head -c "$IMG_SIZE" "$DEV" | cmp -s - "$REF" \
    || fail "verification failed: vendor_dlkm_a does not hold $KS_DLKM_IMG"
rm -f "$RAW"

dmsetup remove "$NAME" || ks_log "flash-vendor_dlkm.sh: could not unmap $NAME"

ks_log "flash-vendor_dlkm.sh: vendor_dlkm_a updated for $want"
exit 0
