#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: GPL-2.0-only
#
# Preinit oneshot, registered when hybris-boot.img (droid-hal-pdx246-img-boot) is upgraded.
# Writes boot_a, vendor_boot_a and dtbo_a together, and only as a matched set;
# see pdx246-kernel-set.sh. Exits non-zero (and so runs again at the next
# boot) while the installed images do not form a set.

. /var/lib/platform-updates/pdx246-kernel-set.sh

ks_flash_boot_set flash-bootimg.sh
