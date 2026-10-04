# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
#
# Flash configuration for the Sony Xperia 10 VI (pdx246; XQ-ES54, XQ-ES72),
# read by flash.sh (droid-hal-configs sparse/boot/flash.sh, which documents the
# operations). Start with the phone in the bootloader's fastboot mode
# (power off, hold volume up while plugging in USB). flash.sh first does a dry run
# (the getvar check and an image-presence check), then flashes.
#
# hybris-boot.img (kernel), vendor_boot.img, dtbo.img and vendor_dlkm.img are
# one matched set from one Sailfish OS build (the kernel config changes the
# module CRCs): never mix them with LineageOS images. Slot a only, with
# explicit _a partition names, because Sailfish OS maps and mounts the slot-a
# logical partitions.
#
# Order (fastbootd first):
#  1. From the bootloader: make slot a active and reboot into fastbootd.
#     fastbootd lives in recovery_a, which has no kernel of its own: it boots
#     with boot_a's kernel and vendor_boot_a's modules. On the first install
#     these are still LineageOS's, which is known to work, so fastbootd runs
#     before boot_a and vendor_boot_a change.
#  2. flash-preflight.sh checks in fastbootd that the current slot is a, that
#     no Virtual A/B merge is pending, and that vendor_dlkm_a is a logical
#     partition of slot a. No partition is written before that check passes.
#  3. From fastbootd: vendor_dlkm_a (logical, so fastbootd only) and userdata
#     (fastbootd reports a usable max-download-size, so the sparse image is
#     chunked correctly; the Sony bootloader does not).
#  4. Back to the bootloader for the physical partitions boot_a, vendor_boot_a
#     and dtbo_a, then make slot a active again.
#
# Before the first run (see flashing-README.txt): slot a must hold a complete
# LineageOS 23.2 install of the matching release (super: system_a, vendor_a,
# odm_a, product_a, system_ext_a, vendor_dlkm_a), booted once to the home
# screen and left running for a minute so that the Virtual A/B merge has
# completed, and vbmeta_a must have verification disabled (the LineageOS flash
# procedure does that).
#
# Re-flashing over an installed Sailfish OS: fastbootd then runs on the
# Sailfish OS kernel. If "fastboot reboot fastboot" does not reach fastbootd,
# flash the saved LineageOS boot_a, vendor_boot_a and dtbo_a from the
# bootloader, then run ./flash.sh again (flashing-README.txt).

VALID_PRODUCTS=(
"pdx246"
"XQ-ES54"
"XQ-ES72"
)

FLASH_OPS=(
"getvar_fail_if secure yes"
"run fastboot --set-active=a"
"run fastboot reboot fastboot"
"run ./flash-preflight.sh"
"flash_dont_fail vendor_dlkm_a vendor_dlkm.img"
"flash userdata sailfish.img001"
"run fastboot reboot bootloader"
"flash_dont_fail boot_a hybris-boot.img"
"flash vendor_boot_a vendor_boot.img"
"flash dtbo_a dtbo.img"
"run fastboot --set-active=a"
)

GETVAR_ERROR_secure="
The bootloader reports secure=yes: it looks locked. Sailfish OS can only be
flashed on an unlocked bootloader (Sony's unlock procedure, then LineageOS 23.2
for pdx246 installed on slot a). If your unlocked phone still reports
secure=yes, flash by hand as described in flashing-README.txt.
If the phone shows the fastbootd screen (e.g. after an interrupted run), run
fastboot reboot bootloader and start ./flash.sh again.
"

FLASH_COMPLETED_MESSAGE="
Flashing completed. Unplug the USB cable and power the phone on, or run
'fastboot reboot'. The first boot resizes the root and home volumes and
takes longer than later boots.
"
