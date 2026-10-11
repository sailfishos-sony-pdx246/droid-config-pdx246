SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
SPDX-License-Identifier: GPL-2.0-only

= SAILFISH OS FOR THE SONY XPERIA 10 VI (pdx246) - FLASHING =

Unofficial community port, not affiliated with Jolla or Sony. Supported
models: XQ-ES54 and XQ-ES72 (codename pdx246).

Flashing erases everything on the phone's userdata partition (all Android
data, apps and files) and replaces the boot chain of slot a.


= BEFORE YOU START =

1. Unlock the bootloader (Sony's unlock procedure).

2. Install LineageOS 23.2 for pdx246 and make sure it runs from SLOT A,
   complete with its super partition (system_a, system_ext_a, product_a,
   vendor_a, vendor_dlkm_a, odm_a). Sailfish OS runs on top of these Android
   partitions of slot a and never uses slot b. An install that went to slot b
   (for example an OTA or sideload, which write the inactive slot) has to be
   repeated so that slot a holds it. The LineageOS flash procedure also writes
   vbmeta_a with verification disabled, which the unsigned Sailfish OS boot
   image needs.

3. After installing LineageOS to slot a, boot it to the home screen once and
   leave it running for a minute, so that the Virtual A/B merge completes.
   Until then fastbootd refuses to flash userdata.

4. Keep the LineageOS images of exactly that release (boot, vendor_boot,
   dtbo, vendor_dlkm, recovery) to go back. Going back is all or nothing as
   well: the Sailfish OS kernel and the LineageOS modules do not mix.
   Slot b holds no bootable LineageOS (Virtual A/B keeps only one copy of
   the dynamic partitions), so these saved slot-a images are the only way
   back.

5. Use a recent Android platform-tools fastboot (version 34 or newer).


= FLASHING WITH THE SCRIPT (LINUX) =

1. Extract the zip and enter the directory.
2. Put the phone into the bootloader's fastboot mode (power off, then hold
   volume up while plugging in the USB cable) and check that
   "fastboot devices" lists it.
3. Run:

     ./flash.sh

   The script checks the phone model and the md5 sums, makes slot a active
   and reboots into the userspace fastboot (fastbootd) of the LineageOS
   recovery. There ./flash-preflight.sh checks that fastbootd runs from slot
   a, that no Virtual A/B merge is pending and that vendor_dlkm_a exists, and
   stops with an explanation if not; no partition has been written at that
   point.
   Then the script writes vendor_dlkm_a and userdata from fastbootd, returns
   to the bootloader, writes boot_a, vendor_boot_a and dtbo_a, and makes
   slot a active.

   Why fastbootd comes first: fastbootd lives in recovery_a, which has no
   kernel of its own and boots with the kernel of boot_a and the modules of
   vendor_boot_a. On the first install these are still LineageOS's, which is
   known to work.


= IF FLASH.SH STOPS HALFWAY =

The USB connection can drop during a large transfer. Reconnect the cable
until "fastboot devices" lists the phone, run

  fastboot reboot bootloader

and start ./flash.sh again from the beginning. A half-written userdata or
vendor_dlkm_a is rewritten by the new run. If the run had already written
boot_a and "fastboot reboot fastboot" now fails, continue as in the next
section.


= RE-FLASHING OVER AN INSTALLED SAILFISH OS =

fastbootd cannot be reached while boot_a holds Sailfish OS: "fastboot reboot
fastboot" then simply boots Sailfish OS again (tested 2026-10-08), and flash.sh
waits for fastbootd forever (stop it with Ctrl-C; nothing has been written).
So before running ./flash.sh over an installed Sailfish OS, enter the
bootloader (power off, hold volume up while plugging in USB) and flash the
saved LineageOS images of the release on slot a:

  fastboot flash boot_a <LineageOS boot.img>
  fastboot flash vendor_boot_a <LineageOS vendor_boot.img>
  fastboot flash dtbo_a <LineageOS dtbo.img>

Do not let the phone boot normally with these, then run ./flash.sh. It writes
the Sailfish OS boot_a, vendor_boot_a and dtbo_a again at the end.

If flash.sh stops right after "reboot fastboot" with "FAILED (usb_read failed:
No such device)", the phone usually reached fastbootd anyway (the reboot raced
the reply): check with "fastboot getvar is-userspace" and either run
"fastboot reboot bootloader" and ./flash.sh again, or continue by hand from
fastbootd as in the next section.


= FLASHING BY HAND =

From the bootloader (fastboot mode):

  fastboot --set-active=a
  fastboot reboot fastboot

In fastbootd, check first; do not continue unless the answers are exactly
these (or run ./flash-preflight.sh, which does the same checks):

  fastboot getvar current-slot                -> current-slot: a
  fastboot getvar snapshot-update-status      -> snapshot-update-status: none
  fastboot getvar is-logical:vendor_dlkm_a    -> is-logical:vendor_dlkm_a: yes

Then, still in fastbootd:

  fastboot flash vendor_dlkm_a vendor_dlkm.img
  fastboot flash userdata sailfish.img001
  fastboot reboot bootloader

Back in the bootloader:

  fastboot flash boot_a hybris-boot.img
  fastboot flash vendor_boot_a vendor_boot.img
  fastboot flash dtbo_a dtbo.img
  fastboot --set-active=a
  fastboot reboot

Notes:
- Always use the explicit _a partition names; the bootloader does not report
  the slot layout reliably.
- The bootloader does not report max-download-size. If you ever flash a large
  image (super, userdata) from the bootloader instead of fastbootd, add
  "-S 256M" to the fastboot command.
- Logical partitions such as vendor_dlkm_a can only be flashed from fastbootd.
- Every image in this zip comes from one build. Flash all of boot,
  vendor_boot, dtbo and vendor_dlkm together.
- hybris-recovery.img is a debug image (USB network shell). Only ever flash it
  to boot_a, never to recovery_a, and restore hybris-boot.img afterwards.


= IF THE PHONE DOES NOT BOOT =

- If it falls back to slot b ("device is corrupt"), enter fastboot mode and
  run "fastboot --set-active=a". Slot b holds no bootable system.
- To return to LineageOS, flash the saved LineageOS boot, vendor_boot, dtbo
  and recovery images to the _a partitions from the bootloader, its
  vendor_dlkm image to vendor_dlkm_a from fastbootd, and format userdata from
  the LineageOS recovery.
