#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: GPL-2.0-only
#
# Preinit oneshot that writes nothing. The %post of droid-hal-pdx246-img-recovery
# (hybris-initrd's droid-hal-device-img-boot.inc) registers flash-recoveryimg.sh
# on every upgrade. On pdx246 hybris-recovery.img must never reach recovery_a:
# the bootloader rejects a recovery image with a kernel, and recovery_a stays
# the LineageOS recovery, whose fastbootd every reflash needs. The image is a
# debug image, flashed by hand to boot_a only (flashing-README.txt).
#
# Without this file a registration could stay behind as a dangling link that
# fails at every boot (seen on the phone 2026-10-11). With it, the job runs
# once, exits 0 and removes itself.

. /var/lib/platform-updates/pdx246-kernel-set.sh

ks_log "flash-recoveryimg.sh: hybris-recovery.img is never flashed on pdx246 (recovery_a stays LineageOS); nothing to do"
exit 0
