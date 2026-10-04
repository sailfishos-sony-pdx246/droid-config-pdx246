#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
#
# Preinit oneshot, registered when vendor_boot.img (droid-hal-pdx246-vendor_boot) is upgraded.
# Writes boot_a, vendor_boot_a and dtbo_a together, and only as a matched set;
# see pdx246-kernel-set.sh. Exits non-zero (and so runs again at the next
# boot) while the installed images do not form a set.

. /var/lib/platform-updates/pdx246-kernel-set.sh

ks_flash_boot_set flash-vendor_boot.sh
