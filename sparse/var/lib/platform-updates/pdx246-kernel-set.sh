# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: GPL-2.0-only
#
# Shared by the platform-updates scripts of pdx246 (sourced, not executed).
#
# On pdx246 the kernel (in hybris-boot.img, boot_a), vendor_boot.img
# (vendor_boot_a: dtb, cmdline and the first-stage modules), dtbo.img (dtbo_a)
# and vendor_dlkm.img (vendor_dlkm_a in super: the second-stage modules) are one
# matched set: the Sailfish OS kernel config changes the module CRCs, so a
# kernel only loads modules from its own build. A half-updated set leaves the
# initrd without UFS (no root file system) or Sailfish OS without Wi-Fi, audio
# and modem.
#
# The packages register these scripts as preinit oneshots on upgrade
# (droid-hal-pdx246-img-boot: flash-bootimg.sh; droid-hal-pdx246-vendor_boot,
# -kernel-dtbo, -vendor_dlkm: flash-vendor_boot.sh, flash-dtbo.sh,
# flash-vendor_dlkm.sh). How Sailfish OS's /sbin/preinit runs them
# (jolla-sessions-qt5, run_preinit_oneshot; checked on the phone 2026-10-18):
# - before anything else of the boot, in `find` order (not sorted);
# - a job that exits 0 is removed; a job that exits non-zero is turned into
#   /etc/oneshot.d/preinit/<name>.failed and is NOT run again;
# - after the jobs, preinit always reboots (`reboot -f`).
# So nothing of that boot ever mounts /vendor_dlkm or loads a module from it,
# and the whole set can be written in that one pass. Each of the four scripts
# calls ks_flash_set: the first one checks everything, then writes every
# partition that differs from its image; the others find the set up to date.
#
# The rules:
# - Only on slot a (the device-info map has only _a partitions).
# - Nothing is written unless all four images and /boot/vendor_dlkm.release are
#   installed, the kernel in /boot/hybris-boot.img has the release that
#   /boot/vendor_dlkm.release names (the release of the droid-hal build that
#   produced vendor_boot.img, dtbo.img and vendor_dlkm.img), the unsparsed
#   vendor_dlkm image fits vendor_dlkm_a (only fastbootd can resize it) and
#   flash-partition will write at all (CPUCHECK_STRING).
# - vendor_dlkm_a is written through a private read-write device-mapper
#   mapping of its extents in super (parse-android-dynparts, slot a); the
#   metadata of super is never written.
# - Every write is verified by reading the partition back after flushing the
#   block device's buffers. The write order is vendor_dlkm_a, vendor_boot_a,
#   dtbo_a, boot_a; the first failure stops the pass (the set is then mixed
#   and needs fastboot; the log says which partitions were written).
# - Everything is logged to the kernel log and, because the pass ends in a
#   reboot that loses the kernel log, to /var/log/pdx246-platform-updates.log.

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

KS_DIR=/var/lib/platform-updates
KS_BOOT_IMG=/boot/hybris-boot.img
KS_VENDOR_BOOT_IMG=/boot/vendor_boot.img
KS_DTBO_IMG=/boot/dtbo.img
KS_DLKM_IMG=/boot/vendor_dlkm.img
KS_DLKM_RELEASE=/boot/vendor_dlkm.release
KS_LOG=/var/log/pdx246-platform-updates.log
# Private device-mapper name for vendor_dlkm_a, and the unsparsed copy of a
# sparse vendor_dlkm image. /var/tmp, not /tmp: in preinit /tmp is still the
# root file system's directory, which the tmpfs mounted later would hide.
KS_DM_NAME=pdx246-vendor_dlkm-update
KS_DM_DEV=/dev/mapper/$KS_DM_NAME
KS_RAW=/var/tmp/pdx246-vendor_dlkm.raw

ks_log() {
    echo "pdx246-platform-updates: $*"
    echo "pdx246-platform-updates: $*" 2>/dev/null > /dev/kmsg || :
    echo "$(date '+%F %T' 2>/dev/null) boot $(ks_boot_id | cut -c1-8): $*" 2>/dev/null >> "$KS_LOG" || :
}

ks_on_slot_a() {
    grep -qs 'androidboot.slot_suffix *= *"_a"' /proc/bootconfig && return 0
    grep -qs 'androidboot.slot_suffix=_a' /proc/cmdline && return 0
    return 1
}

# Kernel release of the kernel in a boot image. pdx246's boot image carries the
# uncompressed arm64 Image (BOARD_KERNEL_IMAGE_NAME := Image), whose
# linux_banner reads "Linux version <release> (..." (the image also holds the
# format string "Linux version %s (%s)", hence the digit). The phone's grep is
# BusyBox: -a and -o work, while its tr has no character classes, so the
# earlier `tr -c '[:print:]'` filter read nothing there. Tested on the phone
# against /boot/hybris-boot.img: 5.10.269-gki-ged8ecc8be140.
ks_boot_img_release() {
    grep -a -o -m 1 'Linux version [0-9][^ ]*' "$1" 2>/dev/null \
        | head -n 1 | cut -d ' ' -f 3
}

# Current boot_id (changes at every boot).
ks_boot_id() {
    cat /proc/sys/kernel/random/boot_id 2>/dev/null
}

# 0 if flash-partition will flash at all: it skips (and exits 0) unless
# CPUCHECK_STRING from device-info is in /proc/cpuinfo or the DT model.
ks_cpucheck() {
    (
        . /var/lib/flash-partition/device-info
        [ -n "$CPUCHECK_STRING" ] || exit 1
        grep -qs "$CPUCHECK_STRING" /sys/firmware/devicetree/base/model /proc/cpuinfo
    )
}

# /dev node of a partition name: vendor_dlkm_a is the private mapping (which
# ks_dlkm_map creates), the others come from flash-partition's device-info.
ks_part_dev() {
    if [ "$1" = vendor_dlkm_a ]; then
        echo "$KS_DM_DEV"
        return 0
    fi
    (
        . /var/lib/flash-partition/device-info
        for i in $PART_I; do
            eval p="\${PART_$i}"
            if [ "$p" = "$1" ]; then
                eval echo "/dev/\${PART_REAL_$i}"
                exit 0
            fi
        done
        exit 1
    )
}

# 0 if the partition starts with exactly the image's bytes (read from the
# device after flushing its buffers, so not from the page cache).
ks_part_matches() {
    local dev img
    dev=$(ks_part_dev "$1") || return 1
    img=$2
    [ -b "$dev" ] || return 1
    blockdev --flushbufs "$dev" 2>/dev/null || :
    head -c "$(stat -c %s "$img")" "$dev" | cmp -s - "$img"
}

# Map vendor_dlkm_a read-write under KS_DM_NAME from the super metadata:
# "dynpart-vendor_dlkm_a,,,ro,<table>[,<table>...]" -> private name, rw.
ks_dlkm_map() {
    local super entry rw
    super=/dev/disk/by-partlabel/super
    [ -b "$super" ] || super=/dev/sda95
    [ -b "$super" ] || { ks_log "no super block device"; return 1; }
    # parse-android-dynparts reports every empty _b partition on stderr
    # ("Skipping zero-length logical partition"); keep that off the console and
    # show only its last message if vendor_dlkm_a is not found.
    entry=$(parse-android-dynparts "$super" 2>/dev/null | tr ';' '\n' | grep '^dynpart-vendor_dlkm_a,')
    if [ -z "$entry" ]; then
        ks_log "vendor_dlkm_a not found in the super metadata ($(parse-android-dynparts "$super" 2>&1 >/dev/null | tail -n 1))"
        return 1
    fi
    rw=$(echo "$entry" | sed -e "s/^dynpart-vendor_dlkm_a,/$KS_DM_NAME,/" \
                             -e 's/^\([^,]*,[^,]*,[^,]*,\)ro,/\1rw,/')
    dmsetup remove "$KS_DM_NAME" >/dev/null 2>&1 || :
    # No udev runs in preinit: do not wait for it, create the node directly.
    dmsetup create --noudevsync --concise "$rw" || { ks_log "dmsetup create failed"; return 1; }
    dmsetup mknodes "$KS_DM_NAME" >/dev/null 2>&1 || :
    [ -b "$KS_DM_DEV" ] || { ks_log "$KS_DM_DEV did not appear"; return 1; }
}

ks_cleanup() {
    rm -f "$KS_RAW"
    dmsetup remove "$KS_DM_NAME" >/dev/null 2>&1 || :
}

# The vendor_dlkm image as written to the partition: the image itself, or for
# an Android sparse image (magic 0xed26ff3a) an unsparsed copy in KS_RAW.
# Prints the path; fails if a sparse image cannot be unsparsed.
ks_dlkm_raw() {
    local magic
    magic=$(od -An -t x4 -N 4 "$KS_DLKM_IMG" | tr -d ' \n')
    if [ "$magic" != "ed26ff3a" ]; then
        echo "$KS_DLKM_IMG"
        return 0
    fi
    command -v simg2img >/dev/null 2>&1 || { ks_log "simg2img missing (droid-hal-pdx246-tools)"; return 1; }
    rm -f "$KS_RAW"
    simg2img "$KS_DLKM_IMG" "$KS_RAW" >/dev/null 2>&1 || { ks_log "simg2img failed"; return 1; }
    echo "$KS_RAW"
}

# Check the whole set, then write every partition that differs from its image.
# Returns 0 when the set is on the partitions afterwards, non-zero when it was
# refused (nothing written) or a write failed. With KS_DRY_RUN=1 it only checks
# and reports what it would write.
ks_flash_set() {
    local caller new_boot new_set running dlkm part img todo part_size img_size

    caller=$1
    running=$(uname -r)
    ks_log "$caller: start (running $running${KS_DRY_RUN:+, dry run})"

    if ! ks_on_slot_a; then
        ks_log "$caller: not running from slot a; nothing flashed"
        return 1
    fi
    if ! ks_cpucheck; then
        ks_log "$caller: CPUCHECK_STRING of /var/lib/flash-partition/device-info not found in the DT model or /proc/cpuinfo, so flash-partition would not write; nothing flashed"
        return 1
    fi
    for img in "$KS_BOOT_IMG" "$KS_VENDOR_BOOT_IMG" "$KS_DTBO_IMG" "$KS_DLKM_IMG" "$KS_DLKM_RELEASE"; do
        if [ ! -f "$img" ]; then
            ks_log "$caller: $img missing; nothing flashed"
            return 1
        fi
    done

    new_boot=$(ks_boot_img_release "$KS_BOOT_IMG")
    new_set=$(cat "$KS_DLKM_RELEASE" 2>/dev/null)
    if [ -z "$new_boot" ] || [ -z "$new_set" ]; then
        ks_log "$caller: cannot read the kernel release of the new images; nothing flashed"
        return 1
    fi
    if [ "$new_boot" != "$new_set" ]; then
        ks_log "$caller: hybris-boot.img has kernel $new_boot, vendor_boot/dtbo/vendor_dlkm are for $new_set; nothing flashed"
        return 1
    fi

    # vendor_dlkm_a: map it, then check that the image fits and is readable.
    if [ -z "$KS_DRY_RUN" ] && grep -qs ' /vendor_dlkm ' /proc/mounts; then
        ks_log "$caller: /vendor_dlkm is mounted; run this only from preinit (or with KS_DRY_RUN=1); nothing flashed"
        return 1
    fi
    if ! ks_dlkm_map; then
        ks_log "$caller: cannot map vendor_dlkm_a; nothing flashed"
        ks_cleanup
        return 1
    fi
    dlkm=$(ks_dlkm_raw) || { ks_log "$caller: nothing flashed"; ks_cleanup; return 1; }
    part_size=$(blockdev --getsize64 "$KS_DM_DEV" 2>/dev/null)
    img_size=$(stat -c %s "$dlkm")
    if [ -z "$part_size" ] || [ "$img_size" -gt "$part_size" ]; then
        ks_log "$caller: vendor_dlkm image needs $img_size bytes, vendor_dlkm_a has ${part_size:-?}; flash it from fastbootd; nothing flashed"
        ks_cleanup
        return 1
    fi

    # What differs from its image, in write order.
    todo=
    for part in vendor_dlkm_a:"$dlkm" vendor_boot_a:"$KS_VENDOR_BOOT_IMG" \
                dtbo_a:"$KS_DTBO_IMG" boot_a:"$KS_BOOT_IMG"; do
        if ks_part_matches "${part%%:*}" "${part#*:}"; then
            ks_log "$caller: ${part%%:*} up to date"
        else
            todo="$todo $part"
        fi
    done
    if [ -z "$todo" ]; then
        ks_log "$caller: the set for $new_set is on the partitions; nothing to write"
        ks_cleanup
        return 0
    fi
    if [ -n "$KS_DRY_RUN" ]; then
        ks_log "$caller: dry run, would write for $new_set:$(for p in $todo; do printf ' %s' "${p%%:*}"; done)"
        ks_cleanup
        return 0
    fi

    for part in $todo; do
        img=${part#*:}
        part=${part%%:*}
        ks_log "$caller: writing $img to $part ($new_set)"
        if ! flash-partition "$(ks_part_dev "$part")" "$img" >/dev/null 2>&1; then
            ks_log "$caller: flash-partition FAILED for $part; stopped, the set is mixed: use fastboot"
            ks_cleanup
            return 1
        fi
        sync
        if ! ks_part_matches "$part" "$img"; then
            ks_log "$caller: verification FAILED for $part; stopped, the set is mixed: use fastboot"
            ks_cleanup
            return 1
        fi
        ks_log "$caller: $part written and verified"
    done
    ks_cleanup
    ks_log "$caller: the set for $new_set is written; preinit reboots into it"
    return 0
}
