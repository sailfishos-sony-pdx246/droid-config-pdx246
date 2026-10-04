# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
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
# flash-vendor_dlkm.sh). Preinit runs them before systemd, in name order; a
# script that exits non-zero stays registered and runs again at the next boot.
#
# The rules implemented here:
# - Only on slot a (the device-info map has only _a partitions).
# - boot_a, vendor_boot_a and dtbo_a are written together, by whichever of the
#   three scripts runs first; the others find them up to date. Nothing is
#   written unless the kernel in /boot/hybris-boot.img has the release that
#   /boot/vendor_dlkm.release names (the release of the droid-hal build that
#   produced vendor_boot.img, dtbo.img and vendor_dlkm.img).
# - vendor_dlkm_a is written by flash-vendor_dlkm.sh at the first boot of the
#   new kernel, before /vendor_dlkm is mounted: a kernel release change is
#   only allowed when that script is registered.
# - vendor_dlkm_a is never written in the boot that rewrote vendor_boot_a:
#   that boot's initrd still loaded the old first-stage modules. A rebuild that
#   changes only the modules keeps the kernel release, so the release check
#   alone would let flash-vendor_dlkm.sh write in the same preinit pass.
#   ks_flash_boot_set records the boot_id in KS_SET_WRITTEN before it rewrites
#   vendor_boot_a, and flash-vendor_dlkm.sh waits while that file holds the
#   current boot_id.
# - Every write is verified by reading the partition back: flash-partition
#   exits 0 without writing when CPUCHECK_STRING (device-info) does not match.

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

KS_DIR=/var/lib/platform-updates
KS_BOOT_IMG=/boot/hybris-boot.img
KS_VENDOR_BOOT_IMG=/boot/vendor_boot.img
KS_DTBO_IMG=/boot/dtbo.img
KS_DLKM_IMG=/boot/vendor_dlkm.img
KS_DLKM_RELEASE=/boot/vendor_dlkm.release
KS_SET_WRITTEN=$KS_DIR/.pdx246-set-written

ks_log() {
    echo "pdx246-platform-updates: $*"
    echo "pdx246-platform-updates: $*" 2>/dev/null > /dev/kmsg || :
}

ks_on_slot_a() {
    grep -qs 'androidboot.slot_suffix *= *"_a"' /proc/bootconfig && return 0
    grep -qs 'androidboot.slot_suffix=_a' /proc/cmdline && return 0
    return 1
}

# Kernel release of the kernel in a boot image. pdx246's boot image carries the
# uncompressed arm64 Image (BOARD_KERNEL_IMAGE_NAME := Image), whose
# linux_banner reads "Linux version <release> (..." (the image also holds the
# format string "Linux version %s (%s)", hence the digit). Tested on the
# LineageOS boot.img: 5.10.269-gki-gf985b93da718.
# (tr and plain grep only, so that busybox variants work too.)
ks_boot_img_release() {
    LC_ALL=C tr -c '[:print:]' '\n' < "$1" 2>/dev/null \
        | grep -m 1 '^Linux version [0-9]' | cut -d ' ' -f 3
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

# /dev node of a partition name, from flash-partition's device-info.
ks_part_dev() {
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

# 0 if the partition already starts with exactly the image's bytes.
ks_part_matches() {
    local dev img
    dev=$(ks_part_dev "$1") || return 1
    img=$2
    [ -b "$dev" ] || return 1
    head -c "$(stat -c %s "$img")" "$dev" | cmp -s - "$img"
}

# Flash boot_a, vendor_boot_a and dtbo_a as one set. Returns non-zero (keep the
# oneshot) when the installed images do not form a set or a write fails.
ks_flash_boot_set() {
    local caller new_boot new_set running part img failed bid

    caller=$1

    if ! ks_on_slot_a; then
        ks_log "$caller: not running from slot a; nothing flashed"
        return 1
    fi

    if ! ks_cpucheck; then
        ks_log "$caller: CPUCHECK_STRING of /var/lib/flash-partition/device-info not found in the DT model or /proc/cpuinfo, so flash-partition would not write; nothing flashed"
        return 1
    fi

    for img in "$KS_BOOT_IMG" "$KS_VENDOR_BOOT_IMG" "$KS_DTBO_IMG" "$KS_DLKM_RELEASE"; do
        if [ ! -f "$img" ]; then
            ks_log "$caller: $img missing; nothing flashed"
            return 1
        fi
    done

    new_boot=$(ks_boot_img_release "$KS_BOOT_IMG")
    new_set=$(cat "$KS_DLKM_RELEASE" 2>/dev/null)
    running=$(uname -r)

    if [ -z "$new_boot" ] || [ -z "$new_set" ]; then
        ks_log "$caller: cannot read the kernel release of the new images; nothing flashed"
        return 1
    fi

    if [ "$new_boot" != "$new_set" ]; then
        ks_log "$caller: hybris-boot.img has kernel $new_boot, vendor_boot/dtbo/vendor_dlkm are for $new_set; waiting for matching packages, nothing flashed"
        return 1
    fi

    if [ "$new_set" != "$running" ]; then
        # The module ABI changes: vendor_dlkm must follow at the first boot of
        # the new kernel.
        if [ ! -x "$KS_DIR/flash-vendor_dlkm.sh" ] || [ ! -f "$KS_DLKM_IMG" ]; then
            ks_log "$caller: kernel changes from $running to $new_set but vendor_dlkm cannot follow; nothing flashed. Flash the whole set with fastboot."
            return 1
        fi
        add-preinit-oneshot "$KS_DIR/flash-vendor_dlkm.sh" >/dev/null 2>&1 || {
            ks_log "$caller: could not register flash-vendor_dlkm.sh; nothing flashed"
            return 1
        }
        ks_log "$caller: kernel changes from $running to $new_set; vendor_dlkm follows at the next boot"
    fi

    # vendor_boot and dtbo first, boot last. Partitions that already hold the
    # image are skipped, so the other two scripts of the set do nothing.
    failed=
    for part in vendor_boot_a:"$KS_VENDOR_BOOT_IMG" dtbo_a:"$KS_DTBO_IMG" boot_a:"$KS_BOOT_IMG"; do
        img=${part#*:}
        part=${part%%:*}
        if ks_part_matches "$part" "$img"; then
            ks_log "$caller: $part already up to date"
            continue
        fi
        if [ "$part" = vendor_boot_a ]; then
            # Keeps flash-vendor_dlkm.sh from writing in this boot.
            bid=$(ks_boot_id)
            if [ -z "$bid" ] || ! echo "$bid" > "$KS_SET_WRITTEN"; then
                ks_log "$caller: cannot record the boot_id in $KS_SET_WRITTEN; nothing flashed"
                return 1
            fi
        fi
        ks_log "$caller: flashing $img to $part"
        if ! flash-partition "$part" "$img" || ! ks_part_matches "$part" "$img"; then
            ks_log "$caller: flashing $part FAILED"
            failed=1
        fi
    done
    sync

    [ -z "$failed" ]
}
