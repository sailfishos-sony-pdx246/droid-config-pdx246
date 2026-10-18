#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: GPL-2.0-only
#
# Preinit oneshot, registered when vendor_dlkm.img (droid-hal-pdx246-vendor_dlkm) is upgraded.
# Writes the whole matched set (vendor_dlkm_a, vendor_boot_a, dtbo_a, boot_a)
# in this one preinit pass, after checking all of it; see pdx246-kernel-set.sh.
# The other scripts of the set then find it up to date.

. /var/lib/platform-updates/pdx246-kernel-set.sh

ks_flash_set flash-vendor_dlkm.sh
