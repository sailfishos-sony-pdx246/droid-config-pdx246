# droid-config-pdx246: decisions, TODOs, provenance

Draft of 2026-10-04. Placeholders for local paths:

- `<sfos>` = the Sailfish OS workspace that holds the reference ports (`pdx225/`,
  `pdx235/`) and the port's working notes (`notes/`, not part of this repository).
- `$ANDROID_ROOT` = the `hybris-23.2` Android tree (HADK convention).
- `<lineageos tree>` = the checkout of the pdx246 LineageOS 23.2 port.
- `$PLATFORM_SDK_ROOT` = the Platform SDK installation (HADK convention).

Abbreviations:

- **dcd** = `<sfos>/pdx235/droid-config-pdx235/droid-configs-device`
  (mer-hybris/droid-hal-configs at 1dae7f2, the pin in SUBMODULES.md).
- **dhd** = `<sfos>/pdx225/droid-hal-pdx225/dhd` (mer-hybris/droid-hal-device at be67bbc,
  the droid-hal-pdx246 pin).
- **initrd** = `<sfos>/pdx235/droid-hal-img-boot-sony-xqdc72/initrd`
  (mer-hybris/hybris-initrd; the pin is 7b972b6, cited at that commit).
- **ref** = `<sfos>/pdx235/droid-config-pdx235` (sharks-dev's 10 V port, 97525b2; no
  licence, read only, no text copied).
- **zambezi** = Jolla's official 10 V config, mer-hybris/droid-config-sony-zambezi at
  70a3767d1ed505e30e412d7a958029d72fae45ce (read via raw.githubusercontent.com).
- **murray** = Jolla's official 10 IV config, mer-hybris/droid-config-sony-murray at
  83c7d48dfee5a0fa320b30c2e494c4489bd3002a.
- **LOS out** = `<lineageos tree>/out/target/product/pdx246` (the 2026-09-24 LineageOS
  release build; read only).
- **dev** = `$ANDROID_ROOT/device/sony/pdx246` (branch hybris-23.2, d7d7056; read only).
- **findings** = `<sfos>/notes/analysis/adaptation-map-2026-10-04/findings.md`.
- **PORTING-NOTES.md** = the porting notes of the pdx246 LineageOS port; **TRAP 2**
  there is the USB drop while fastboot sends a large sparse image.

Nothing here has been built or run on the phone. The spec was parsed with the
SDK's rpmspec, and the `%install` part of droid-configs.inc was replayed in a
scratch directory against this tree and dcd; see "Checks done".

---

## Decisions

### D1. Names and spec macros

- `device pdx246`, `vendor sony`, `vendor_pretty Sony`, `device_pretty Xperia 10 VI`;
  `rpm_device` is not defined, so it defaults to `device` (dcd/droid-configs.inc:61-63).
  User decision: DEVICE=pdx246 everywhere. The sibling droid-hal-version-pdx246 NOTES
  (section 5) needs `rpm_device` = pdx246 for the ssu board mapping.
- `android_version_major 16`: accepted (dcd/droid-configs.inc:263) and selects
  `sparse-16` (:367-374).
- `community_adaptation 1`: build_packages.sh -c then builds
  community-adaptation-localbuild (dhd/helpers/build_packages.sh:136-177), and
  droid-configs.inc adds the adaptation-community ssu feature (:485-499).
- `out_of_image_files 1` (as zambezi's droid-config-common.inc): flash.sh,
  flash-config.sh and the READMEs go to `droid-config-pdx246-out-of-image-files`
  (dcd/droid-configs.inc:221-231, 438-445), which the kickstart attaches. The ref
  attaches that package without defining the macro (findings adaptation-repos FACTS,
  bug d), so its zip has no flash.sh.
- `pixel_ratio 1.75`: 6.1", 1080x2520, TARGET_SCREEN_DENSITY 450 (dev/BoardConfig.mk:56);
  449 ppi / 245 = 1.83, nearest 0.25 step 1.75; the 10 V (same size class) uses 1.75
  (ref/rpm/droid-config-xqdc72.spec). icon_res resolves to 1.75 (checked with rpmspec:
  `sailfish-content-graphics-z1.75`).
- `Provides: usb-moded-configs` / `Obsoletes: usb-moded-defaults` and
  `Provides: ofono-configs` / `Obsoletes: ofono-configs-mer, ofono-configs-binder`:
  as zambezi's droid-config-common.inc and the ref spec; this package ships the
  usb-moded and ofono configuration.
- `ofono_enable_plugins bluez5,hfp_ag_bluez5` and the matching disable list: copied
  as values from zambezi's droid-config-common.inc (HFP audio gateway for headsets).
- `Requires: libgbinder-tools`: sparse-16 `usr/bin/droid/wait_for_keymint` calls
  `binder-list`.
- Not set: `droid_target_aarch64` (droid-configs.inc never reads it),
  `__requires_exclude` (the ref needed it only for the ELF in its overlays/).

### D2. Install route: LVM loop image, kernel-modules kept out of the pattern

- Verified in dhd/helpers/build_packages.sh:410-427: `-i` runs `mic create fs`
  (rootfs tarball, needed for the stowaways route) only if
  `grep -qsE "^Requires: droid-hal-($DEVICE|$HABUILD_DEVICE)-kernel-modules"` matches the
  adaptation pattern, otherwise `mic create loop --copy-kernel`, which writes one
  image per kickstart `part` (root.img, home.img) for the LVM pack script. The user
  chose the LVM route, so the pattern has the line only commented out (`#Requires:`
  does not match `^Requires:`).
- The modules still reach the rootfs: droid-hal-pdx246-img-boot copies
  `/lib/modules/<kver>` into itself and `Provides`/`Obsoletes`
  `droid-hal-pdx246-kernel-modules` (initrd/droid-hal-device-img-boot.inc at 7b972b6:
  :473-482 copy /lib/modules, :239-240 Provides/Obsoletes). mal on the 10 IV port: "droid-hal-pdx225-kernel-modules is needed when
  using community style boot image, lvm based boot image contains those"
  (pdx225/sailfish-on-murray/IRCLOGS.md:808).
- build_packages.sh -g greps `^Requires: gstreamer1.0-droid` and
  `^Requires: pulseaudio-modules-droid-hidl` (:300, :322); -c greps
  `^(-|Requires:) droid-config-$DEVICE-bluez5` (:185). All three are present.

### D3. Patterns

Generated as `rpm/dhd/helpers/add_new_device.sh` does (dhd/helpers/add_new_device.sh:42-53,
unchanged on master): header lines, then the template with `@DEVICE@` = pdx246.
Changes against the templates (dcd/patterns/templates/*.inc):

Adaptation pattern:

| change | why |
|---|---|
| `-kernel-modules` commented out | D2 |
| + `droid-hal-pdx246-img-recovery` | hybris-recovery.img for debugging (boot_a only); zambezi's pattern has it |
| + `-kernel-dtbo`, `-vendor_boot`, `-vendor_dlkm` | the matched set; mal asked the 10 IV port for vendor_boot and kernel-dtbo (IRCLOGS.md:805, 811); `-vendor_dlkm` is the new subpackage of droid-hal-pdx246 (cross-repo contract) |
| + `droid-hal-pdx246-tools` | simg2img for flash-partition; zambezi has it |
| + `parse-android-dynparts`, `device-mapper` | D6; device-mapper is a Sailfish package with `/usr/sbin/dmsetup` (SDK target rpmdb: device-mapper-2.03.32+git1) |
| + `sailfish-connman-plugin-suspend` | zambezi and ref: suspend with Wi-Fi on newer Qualcomm |
| `hybris-libsensorfw-qt5` -> `sensorfw-qt5` + `hybris-libsensorfw-qt5-binder >= 0.15.2` | D17 |
| + `bluebinder`, `ofono-binder-plugin`, `dummy_netd` | BT via HCI VHCI (sailfish.config BT_HCIVHCI=y), binder ofono (D13), sparse-16 ships dummy_netd's config |
| `ofono-binder-plugin-ext-qti` commented | IMS is AIDL only on pdx246 (findings adaptation-repos 6); TODO |
| `audiosystem-passthrough-dummy-af` enabled | template comment: needed with qti-mode passthrough on Qualcomm; zambezi and ref enable it |
| `jolla-devicelock-daemon-encsfa` kept, fpd lines commented | the fingerprint packages are not yet sorted out for this build (TODO); template default keeps the image buildable |
| `nfcd-binder-plugin` enabled | NXP HAL android.hardware.nfc_snxxx@1.2-service (LOS out vendor/etc/init) |

Configuration pattern: `jolla-settings-networking-multisim` (dsds, two IRadio
slots), `jolla-settings-system-flashlight` (leds-qpnp-flash-v2), the three NFC
packages, and `mapplauncherd-booster-silica-qt5-media` (8 GB RAM) enabled.

### D4. Kickstart

- `part/pdx246`: root 4000 MB and home 800 MB, labels root/home, the same as zambezi's
  `kickstart/part/xqdc54` (and ref). mic names the loop images after the labels;
  the pack script shrinks both, and hybris-initrd grows root to lvm_root_size and
  home to the rest on first boot. No `@LVM_ROOT_PART_SIZE@` placeholder, so
  droid-configs.inc:505-507 leaves it alone.
- `attachment/pdx246`: hybris-boot.img, hybris-recovery.img (img-boot),
  vendor_boot.img, dtbo.img, vendor_dlkm.img (droid-hal-pdx246), the
  out-of-image-files package, /etc/hw-release. Missing files only give a mic warning
  (`No file matching attachment`, `$PLATFORM_SDK_ROOT/sdks/sfossdk/usr/lib/python3.11/site-packages/mic/imager/baseimager.py:896-902`),
  and flash.sh's dry run then stops on the missing image. zambezi also attaches
  `droid-flashing-tools`; left out (Windows/macOS fastboot binaries; this port
  documents Linux flashing only). No comments in the file: ssu pastes it into
  `%attachment`, where mic would look a comment up as a package name.
- `pack/pdx246/hybris`: ssu concatenates every file in `kickstart/pack/<device>/`
  (ssu ssuks/ssukickstarter.cpp scriptletSection), and
  droid-configs.inc first installs the generic droid-updater pack as `.../pack/pdx246/hybris`
  (:510-515) and then copies this repository's kickstart/ over it (:522-525), so this
  file replaces it. The LVM part is Jolla's (zambezi `kickstart/pack/xqdc54/hybris`,
  identical to the ref's copy). Changes: the VALID_PRODUCTS substitution is gone
  (flash-config.sh has the list), no .bat, READMEs and flash-preflight.sh included
  in the zip (`chmod 755` as for flash.sh), nullglob for the file list (Jolla's
  `mv ${FILES}` fails on an unmatched `*.exe`), and the list names each flashing
  file once: `FILES=(flash.sh flash-config.sh flash-preflight.sh *README.txt *.img* *-release)`.
  A `flash*` glob would also match flashing-README.txt, which `*README.txt` lists
  again, and the second `mv` fails with "cannot stat" (reproduced in scratch).

### D5. Flash configuration (sparse/boot/flash-config.sh, flash-preflight.sh)

- `VALID_PRODUCTS` pdx246, XQ-ES54, XQ-ES72 (user decision; dev/board-info.txt and
  TARGET_OTA_ASSERT_DEVICE list the same three). flash.sh matches
  `getvar product` against each (dcd/sparse/boot/flash.sh:331-336).
- Operations, in this order (FASTBOOTD FIRST, the procedure all four adaptation
  repos document):
  1. `getvar_fail_if secure yes` (dry run only, as dcd flash.sh does);
  2. `run fastboot --set-active=a`; `run fastboot reboot fastboot`;
  3. `run ./flash-preflight.sh`;
  4. from fastbootd `flash_dont_fail vendor_dlkm_a vendor_dlkm.img`,
     `flash userdata sailfish.img001`;
  5. `run fastboot reboot bootloader`; from the bootloader `boot_a` (hybris-boot.img),
     `vendor_boot_a`, `dtbo_a`; `run fastboot --set-active=a`.
- Why fastbootd first: on the first install, recovery_a (ramdisk only, kernel_size
  0; it hosts fastbootd) still boots on LineageOS's boot_a kernel and vendor_boot_a,
  which is known to work (findings boot-layout FACTS, recovery). The earlier plan
  wrote boot_a/vendor_boot_a/dtbo_a first, so fastbootd would have run on the
  Sailfish OS kernel with the LineageOS recovery ramdisk, an untested combination
  (findings boot-layout OPEN).
- Why `--set-active=a` first and the preflight: fastbootd works on the current slot.
  It looks up `vendor_dlkm_a` in the super metadata of that slot
  (`$ANDROID_ROOT/system/core/fastboot/device/utility.cpp:216-223`), and a resize
  writes that slot's table to every metadata slot (:201-213). It refuses userdata
  while a snapshot merge is SNAPSHOTTED/MERGING (commands.cpp:81-87, 612-615), but
  only after the flash of vendor_dlkm_a has already cancelled that partition's
  snapshot (:587-598, 617-619). A LineageOS install to slot a by sideload leaves
  exactly such a pending merge until LineageOS has booted once (PORTING-NOTES.md
  ~1013: "snapshot merge MergeCompleted" after the boot). Without the check, the run
  would stop halfway with Sailfish modules in vendor_dlkm_a and LineageOS's slot-a
  update half cancelled.
- `flash-preflight.sh` (new, POSIX sh, shipped in out-of-image-files) exits 1 with an
  explanation unless, in fastbootd, `getvar is-userspace` is yes, `current-slot` is
  a, `snapshot-update-status` is none (variables.cpp:464-486) and
  `is-logical:vendor_dlkm_a` is yes. The getvars run in fastbootd because the Sony
  bootloader fails many getvar names. flash.sh's `run` op calls it as
  `./flash-preflight.sh` (an empty third field is dropped by the unquoted `$@` in
  print_and_run, flash.sh:126); a non-zero exit stops flash.sh (`print_and_run`
  exits). FASTBOOTCMD is not exported, so the script uses `$FASTBOOT_BIN_NAME`
  (exported when flash.sh re-runs itself through sudo, flash.sh:247) or `fastboot`,
  and requires exactly one fastboot device unless ANDROID_SERIAL is set (the
  fastboot client reads it; without -s it would pick the first device).
- Precondition, in flash-config.sh and flashing-README.txt: LineageOS 23.2 is
  installed on slot a (super slot a incl. vendor_dlkm_a; vbmeta_a with verification
  disabled) and was booted once to the home screen and left running a minute, so the
  Virtual A/B merge has completed. An install that went to slot b (an OTA or a
  sideload writes the inactive slot) has to be moved to slot a first.
- Re-flashing over an installed Sailfish OS: fastbootd then runs on the Sailfish OS
  kernel and vendor_boot. If `fastboot reboot fastboot` does not reach fastbootd
  (the client dies in reboot_to_userspace_fastboot, fastboot.cpp:1539-1555), flash
  the saved LineageOS boot_a, vendor_boot_a and dtbo_a from the bootloader first,
  then run ./flash.sh again (flashing-README.txt). Untested (TODO R16).
- Interrupted run (USB drop while sending a large sparse image, TRAP 2 in
  PORTING-NOTES.md:7438-7448): reconnect until `fastboot devices` lists the phone,
  `fastboot reboot bootloader`, start ./flash.sh again; the rerun rewrites a
  half-written userdata or vendor_dlkm_a. Without the reboot, flash.sh's dry run
  would ask fastbootd for `secure`, which answers yes (ro.secure=1 in the LineageOS
  recovery; variables.cpp:92-94), and stop with GETVAR_ERROR_secure; that message
  therefore also says: "If the phone shows the fastbootd screen (e.g. after an
  interrupted run), run fastboot reboot bootloader and start ./flash.sh again."
- Slot b holds no bootable LineageOS: Virtual A/B keeps one copy of the dynamic
  partitions, and fastbootd's resize rewrites every metadata slot from slot a.
  Rollback = reflash the saved slot-a LineageOS set (flashing-README.txt).
- vendor_dlkm_a is logical: fastbootd only (PORTING-NOTES.md:7450-7462).
  userdata from fastbootd because fastbootd reports max-download-size; the Sony
  bootloader truncates getvar names ("max-downlo not supported",
  PORTING-NOTES.md:7422-7436), so large images from the bootloader need `-S 256M`,
  which flash.sh's `flash` op cannot pass (the README explains it for manual use).
- flash.sh mechanics checked: each op string is split by
  `read var_op var_arg1 var_arg2` (flash.sh:521), so `run fastboot reboot fastboot`
  passes "reboot fastboot" as one argument, which print_and_run word-splits again
  (flash.sh:126, 500); getvar tests only run in the dry run (flash.sh:452), `run` ops
  only in the real run (:495); `flash_dont_fail` retries 30 times, used for the
  first flash after each reboot. The whole op list was replayed with flash.sh's own
  functions and stub fastboot/preflight (Checks done).
- `getvar secure` is the check Jolla's Sony configs use (ref and zambezi
  flash-config.sh). Unverified on pdx246: if an unlocked pdx246 reports
  secure=yes in the bootloader, the dry run stops before anything is written (TODO D6).

### D6. Dynamic partitions: super by partlabel, sda95 as fallback

- `dmsetup-dynparts.service` runs `usr/bin/droid/dmsetup-dynparts.sh`:
  `dmsetup create --concise "$(parse-android-dynparts <super>)"`. parse-android-dynparts
  reads metadata slot 0 = slot a (`ReadMetadata(argv[1], 0)`, sailfish-on-nabu/parse-android-dynparts
  main.cpp) and names the devices `dynpart-<name>`.
- Device: `/dev/disk/by-partlabel/super`, with `/dev/sda95` as fallback. Reasons:
  the UFS LUNs are scanned asynchronously, and the unit can wait for the udev
  device (`Wants=`/`After=dev-disk-by\x2dpartlabel-super.device`) instead of racing
  the scan; the GPT label is unique (one `super` in by-name-live.txt); hybris-initrd
  finds userdata by label too, and dhd master switched its mount units to
  by-partlabel (44a1036, findings adaptation-repos FACTS). sda95 is what the live
  phone shows (`<sfos>/notes/analysis/device-data-2026-10-04/by-name-live.txt`) and what
  hybris-boot's fixup-mountpoints uses. The Sailfish target has
  60-persistent-storage.rules and the device-mapper rules 10-dm.rules/13-dm-disk.rules
  (`$PLATFORM_SDK_ROOT/targets/sony-pdx246-aarch64/lib/udev/rules.d`).
- `Wants=` rather than `Requires=` on the device: if the link never appears, the
  script still runs after the device timeout and uses sda95.
- The script is idempotent and fails if any of the six _a partitions is missing
  (an install that went to slot b; with Virtual A/B, dev/device.mk:14
  launch_with_vendor_ramdisk, a recovery sideload may have removed the _a
  partitions from the metadata).

### D7. Mount units

- `system_root.mount` (dynpart-system_a), `system.mount` (bind /system_root/system),
  `system_ext`, `product`, `vendor`, `vendor_dlkm`, `odm` (dynpart-*_a), all ext4 ro,
  each `Requires=`/`After=dmsetup-dynparts.service`, enabled through
  `local-fs.target.wants` links. All six are ext4 (dev/BoardConfig.mk, findings
  boot-layout FACTS; fstab.default lines for /system ... /odm).
- system-as-root: the system image has the root layout (LOS out misc_info.txt:78
  `root_dir=out/target/product/pdx246/root`), so it is mounted at /system_root and
  its system/ directory is bound to /system, as the 10 IV/10 V ports do.
- droid-hal-pdx246 skips these entries in makefstab (`makefstab_skip_entries / /system_root
  /system /system_ext /product /vendor /vendor_dlkm /odm ...`, droid-hal-pdx246 spec).
- The other mount units come from droid-hal-pdx246: dhd generates 10 units from the
  hybris out (config, dev-binderfs, linkerconfig, metadata = sda54,
  mnt-vendor-persist = sda3, mnt-vendor-qmcs = sda63, mnt-vm, vendor-bt_firmware =
  sda68, vendor-dsp = sda71, vendor-firmware_mnt = sda67). The hybris out installs
  only vendor/etc/init/hw/init.qti.kernel.rc, so vendor rc mounts such as
  /mnt/vendor/spunvm (and the cgroup and functionfs mounts) are not units: droid-hal-init
  performs them at runtime from the LineageOS vendor partition. Skip entries that only
  matter for the LineageOS out stay in droid-hal's list but are marked as such there.

### D8. No modules-load.d

Android's `vendor.modprobe` service (vendor init.qti.kernel.rc:34-35, 179-185 in LOS out)
runs `/vendor/bin/vendor_modprobe.sh`, which loads `/vendor_dlkm/lib/modules/modules.load`
(265 entries, wlan `qca_cld3_adrastea.ko` at dev/vendor_dlkm.modules.load:209) under
droid-hal-init, and on a normal boot hybris-initrd has already loaded the 86
first-stage modules of vendor_boot's `modules.load` (7b972b6 main-init:17-25; the
full 302-entry `modules.load.recovery` only in recovery mode). Together that is
the ~351 the LineageOS boot loads. The ref's
modules-load.d list exists because its kernel set differs. Runtime check:
`getprop vendor.all.modules.ready` = 1 (TODO R3).

### D9. SELinux: generic default (no policy shipped)

- Generic: dcd/sparse/etc/selinux/config is `SELINUX=disabled` (Jolla, e4bb3bf
  2019-08-15, unchanged at 1dae7f2); sparse-16 does not override it; droid-hal-init's
  SELinux is compiled out by hybris-patches system/core 0017 "(hybris) Disable SELinux".
- Permissive + "minimum" needs Jolla's compiled `policy.30`. It exists only as a
  binary in device repos (ref sparse/etc/selinux/minimum/policy/policy.30, copied from
  Jolla's droid-config-sony-seine d7fd7a9; zambezi has the same set) without sources
  or licence. No package provides it: the only SELinux-related repositories are
  sailfishos/selinux (archived userspace) and mer-hybris/android_external_selinux_stubs
  (GitHub repository search, 2026-10-04); the SDK target has libselinux only
  (target rpmdb). Shipping it would redistribute a Jolla binary we have no grant for.
- So this repository ships no SELinux file; the image gets SELINUX=disabled.
  Revisit if Jolla publishes the policy as a package.
- Consequence, found on the first boot (2026-10-06): without selinuxfs, Android 16's
  servicemanager and vndservicemanager abort in Access::Access()
  (`CHECK(selinux_status_open(true) >= 0)`, frameworks/native/cmds/servicemanager/Access.cpp:103)
  and droid-hal-init restarts them every 5 s, class_restarting main/hal/early_hal each
  time; no HAL registers, so there is no UI. The refs avoid it for servicemanager by
  loading the policy and preload libselinux_stubs (mer-hybris/android_external_selinux_stubs,
  in the hybris-23.2 manifest; hybris-boot builds it when */selinux_stubs exists) into
  vndservicemanager and hwservicemanager. Here
  `sparse/usr/libexec/droid-hybris/system/etc/init/servicemanager_selinux_stubs.rc`
  preloads it into all three, with Android 16's definitions (hwservicemanager is
  /system/system_ext/bin/hwservicemanager; pdx246's vendor has HIDL HALs: audio, bluetooth,
  fingerprint, gatekeeper, keymaster, wifi). The name sorts after droid-hal's
  servicemanager.rc, so "override" applies; droid-hal-init parses droid-hybris, /system,
  /system_ext, /vendor in that order and drops the later definitions without "override".

### D10. Audio: hidl_compat through the hybris libhardware search path

Design: `sparse/usr/libexec/droid-hybris/system/lib64/hw/audio.primary.parrot.so`
is a symlink to `audio.hidl_compat.default.so` (built in the Android tree from
vendor/halium/hardware halium-16.0 audio/Android.mk: `LOCAL_MODULE := audio.hidl_compat.default`,
system module, `LOCAL_MODULE_RELATIVE_PATH := hw`; dhd copies out/.../system/lib64 to
/usr/libexec/droid-hybris/system/lib64, dhd/droid-hal-device.inc:728, 1246). No bind mount.

Why this works and the ref's bind mount would not:

- pdx246's vendor has both audio.primary.parrot.so and audio.primary.default.so
  (LOS out vendor/lib64/hw). libhardware tries `ro.hardware.audio.primary`, then
  `ro.hardware` (qcom), `ro.product.board` (parrot) ... before `default`
  (`$ANDROID_ROOT/hardware/libhardware/hardware.c:250-270`), so a mount over
  audio.primary.default.so is never reached.
- The hybris libhardware (system, built by hybris-hal, used by pulseaudio through
  libhybris) searches `/usr/libexec/droid-hybris/system/lib64/hw` FIRST
  (hybris-patches hardware/libhardware 0002; applied: hardware.c:51, 196-198). So
  pulseaudio's `hw_get_module_by_class("audio", "primary")`
  (pulseaudio-modules-droid droid-util.c droid_hw_module_open)
  finds the symlink under the name `audio.primary.parrot.so`.
- The vendor audio service (vendor.audio-hal, android.hardware.audio.service_64)
  uses the vendor libhardware, which has no droid-hybris path (strings of LOS out
  vendor/lib64/libhardware.so: only /vendor/lib64/hw and /odm/lib64/hw), so it still
  loads the real audio.primary.parrot.so. No self-loop (the risk findings CRITIC
  raised for a mount over the parrot module).
- hidl_compat opens the vendor HAL through libaudiohal
  (`DevicesFactoryHalInterface::create()` / `openDevice(AUDIO_HARDWARE_MODULE_ID_PRIMARY)`,
  halium-16.0 audio_hw.cpp), i.e. over hwbinder to vendor.audio-hal. That service
  must run: sparse-16 disables `vendor.audio-hal` (sparse-16 disabled_services.rc:16),
  but pdx246's definition carries `override` (LOS out
  vendor/etc/init/android.hardware.audio.service_64.rc:28-29) and is parsed after
  the droid-hybris directory (hybris-patches system/core 0022), and Android 16 init
  replaces an earlier definition with an `override` one
  (`$ANDROID_ROOT/system/core/init/service_parser.cpp:702-716`). So it keeps running.
- The sphal namespace may load from /usr/libexec/droid-hybris/system/${LIB}
  (hybris-patches system/linkerconfig 0001:35, 47); this is the "linkerconfig" route
  mal described for the FP4 (pdx225/sailfish-on-murray/IRCLOGS.md:358-360), whose
  droid-config ships the same kind of link
  (mlehtima/droid-config-fp4 sparse/usr/libexec/droid-hybris/system/lib64/hw/audio.primary.lito.so
  -> audio.hidl_compat.default.so, read via the GitHub API).
- Danger noted: a vendor image built by this tree (hybris-hal builds vendorimage)
  would carry a hybris-patched vendor libhardware that also searches droid-hybris;
  flashing it would make vendor.audio-hal load hidl_compat (loop). Never flash the
  Sailfish-built vendor.img.
- `etc/pulse/arm_droid_card_custom.pa`: `module-droid-card rate=48000 hw_volume=false`
  (droid.pa includes it instead of its default, dcd/sparse/etc/pulse/default_sailfish.pa.d/droid.pa).
  `hw_volume=false` as in Jolla's zambezi sparse/etc/pulse/arm_droid_card_custom.pa
  (`... hw_volume=false source_format=s24-32le` plus module-udev-detect): volume is
  applied in PulseAudio. The ref's one-line file reads the same; the Jolla original
  is cited. No source_format and no module-udev-detect yet (TODO R2).
- `99-pulseaudio-ignore-builtin-card.rules`: PULSE_IGNORE on the built-in card, by
  id prefix `parrot*` (dtbo strings: parrot-qrd-snd-card, parrot-qrd-sku1-snd-card;
  ALSA id = alphanumerics, 15 chars). Only matters once udev-detect is loaded.

Fifth boot (2026-10-06): no droid card ("Failed to parse any configuration"):
pulseaudio-modules-droid searches only /odm/etc, /vendor/etc/audio, /vendor/etc and
/system/etc (src/common/droid-config.c), and pdx246's vendor has the policy only as
/vendor/etc/audio/sku_parrot/audio_policy_configuration.xml (absolute xi:includes, all
present). `arm_droid_card_custom.pa` now passes `config=` with that path.
Call audio (round-5 review, 2026-10-07): module-droid-hidl picks the audiosystem-passthrough
type "qti" only if IQcRilAudio is in /vendor/etc/vintf/manifest.xml or /vendor/manifest.xml;
pdx246 has it only in the per-SKU ODM manifests, so it would use "af" and qcrild's
IQcRilAudioCallback (vsid, call_state) would never reach the audio HAL. The user unit drop-in
`usr/lib/systemd/user/pulseaudio.service.d/50-pdx246-qti-passthrough.conf` sets
AUDIOSYSTEM_PASSTHROUGH_TYPE=qti (the module's setenv does not overwrite it).
Call volume (sixth boot, 2026-10-07): Sailfish never sent a voice-call volume to the HAL (no
adev_set_voice_volume in logcat; AHAL "session volume is not set"), so PAL ran every call at its
default, the loudest voice level, and the volume keys did nothing in calls; this may also be why
the far end hears echo on speakerphone (unproven: routing, the nn-sm speaker-mic ACDB profile and
the DSP-internal EC reference match Android). Cause: dcd 8d935d8 loads module-meego-mainvolume
with virtual_stream=false, which expects pulseaudio-modules-droid >= 14.2.107 (own voice volume
stream); we pin 14.2.106 for SFOS 5.1, so no media.role=phone sink-input exists and droid-sink
never calls set_voice_volume. `sparse/etc/pulse/default_sailfish.pa` is dcd's file with
virtual_stream=true restored (REUSE.toml: PulseAudio developers, Jolla, user; LGPL-2.1-or-later).
Drop it when moving to pulseaudio-modules-droid >= 14.2.107 (and upgrade nemo at the same time:
nemo >= 14.2.33 ignores virtual_stream). Expect calls to start quieter (phone role -15 dB).
Confirmed on the seventh boot: the volume keys work in calls and the speakerphone echo is gone.

### D11. disabled_services: sparse-16 file kept, two device entries

- sparse-16's disabled_services.rc already has `user root` on every entry (Android
  16 init errors without a user only when ro.vendor.api_level > 202404,
  service_parser.cpp:684-693; pdx246 reports ro.vendor.api_level 34,
  device-data adb-readonly.txt).
- Added in a separate `disabled_services_device.rc` (zambezi's pattern): `iddd`
  only. It is Sony's diagnostics daemon (LOS out vendor/etc/init/init.sony.idd.rc),
  its definition has no `override`, so the stub parsed first wins; the 10 V port
  disables it too (ref disabled_services.rc:1). Optional: drop the line if Sony
  services complain.
- `vendor.atrace-hal-1-0` (added after the third boot, 2026-10-06): its constructor
  CHECKs that tracefs is mounted (hardware/interfaces atrace/1.0/default
  AtraceDevice.cpp:66-74). Nothing mounts it: droid-hal-init's mount builtin is a no-op
  (hybris patch 0024), GKI has CONFIG_TRACEFS_DISABLE_AUTOMOUNT=y and dhd's makefstab skips
  /sys/kernel/tracing. It aborted every 5 s; nothing in Sailfish OS uses it.
- odsign gets its own file, `odsign_hybris.rc` (D24).
- Not disabled: vendor.audio-hal (D10), vendor.qti.vibrator (sibling droid-hal-version
  NOTES section 5 asks to keep it), vendor.usb-hal / vendor.usbgadget-hal (idle without
  the framework; the ref disabled vendor.usb-hal without a recorded reason).

- `vendor.dataqti` (2026-10-07): /vendor/bin/qti, the USB RmNet/tethering helper (vendor
  dataqti.rc, class main, disabled, no override), exited every 10 s on the fifth boot (244
  restarts; with the default namespace ready it counted as updatable-crashing and made apexd
  try reverts). Mobile data goes through netmgrd/ipacm and oFono.
- `adbd` (2026-10-07): once the compressed APEXes are active (D24), com.android.adbd brings
  `service adbd ... override`. This stub is not `updatable`, so init rejects the APEX override
  (service_parser.cpp:710-713), the same way sparse-16's non-updatable `bpfloader` stub keeps
  tethering's `bpfloader` (netbpfload.35rc: `reboot_on_failure reboot,bpfloader-failed`,
  `override`) out. Never mark either stub updatable.
- `vendor.imsdaemon` (2026-10-07, interim): once data worked, imsdaemon brought up the IMS PDN
  and the modem registered VoLTE; with no client for the AIDL-only vendor IMS interface, SMS over
  IMS were never acknowledged there (30-60 s late, resent repeatedly). Stubbed until an IMS client
  exists (TODO B4); calls use CS fallback and SMS go over SGs.

### D12. USB (usb-moded)

- `99-usb-moded-pdx246.ini`: `gadget_udc_device = a600000.dwc3` (bootconfig
  androidboot.usbcontroller, dev/BoardConfig.mk:97), `configs/b.1`,
  `function_rndis = rndis.usb0` (CONFIG_USB_CONFIGFS_RNDIS=y in the LineageOS
  kernel .config; usb-moded's default `rndis_bam.rndis` is a function this kernel
  does not have), network interface usb0. Keys and defaults from usb-moded
  src/usb_moded-configfs.c (upstream source); keys and layout as in zambezi's
  usb-moded-zambezi.ini, values from pdx246.
- usb-moded makes function directories but expects the gadget, strings and
  configs/b.1 to exist and does not mount configfs (same source). On pdx246 these
  come from init.qcom.usb.rc `on zygote-start` (LOS out vendor/etc/init/hw/init.qcom.usb.rc:52-126),
  and the hybris init.rc never triggers zygote-start (hybris-patches system/core
  0015:31-32). `usb-moded-configfs-setup.service` (Before=usb-moded, pulled in by a
  drop-in) creates them. Written new; the ref has a longer script for the same gap.
- Peripheral-mode fallback (bring-up aid, to drop once the Type-C role switch is
  shown to work, TODO R4): the UDC a600000.dwc3 appears only after the dwc3 glue is
  put into peripheral mode (pdx246's init.recovery.qcom.rc:32-36 writes
  `peripheral` to the glue's `mode` and then waits for the UDC). In normal boot that
  is the Type-C role switch in the ADSP, at the end of an untested chain
  (vendor_dlkm modules, vendor.modprobe, the boot_adsp write in
  init.qti.kernel.rc:50, 74, then charger and role switch). If any link fails there
  is no USB networking and no SSH on the first headless boots. So
  usb-moded-configfs-setup.sh, after droid-hal-init, waits up to 30 s for
  /sys/class/udc/a600000.dwc3; if it is absent, it writes `peripheral` to
  /sys/bus/platform/devices/a600000.ssusb/mode and logs that to the journal. This
  disables USB host/OTG until the next boot. The service runs before usb-moded, so
  usb-moded finds the UDC; TimeoutStartSec=90 covers the waits. This is the
  running-OS half of droid-hal-img-boot-pdx246's contract (its recovery initrd
  does the same write for the debug image).
- extcon: unknown (TODO D1); without it usb-moded follows the `usb` power supply.

### D13. ofono

`etc/ofono/binder.d/pdx246.conf`: `radioInterface = 1.5`, `useNetworkScan = true`.
The vendor serves IRadio 1.6 on slot1 and slot2 (findings, HAL inventory); the plugin
knows 1.0-1.5 (ofono-binder-plugin binder.conf sample, "versions 1.0 to 1.5"), and HIDL
1.6 implements 1.5. Slots come from dcd binder.conf (slot1) and binder.d/dual-sim.conf
(slot2), both kept (the ref deletes dual-sim; pdx246 is dsds). useNetworkScan as on
the 10 IV/10 V ports (TODO R6).

### D14. mce charging control

`etc/mce/70-battery-pdx246.ini`: `/sys/class/battchg_ext/smart_charging_interruption`,
EnableValue 0, DisableValue 1, the node and values of the LineageOS port's charging
control (dev/device.mk:360-365). Keys as in zambezi's 70-battery-zambezi.ini. The ref's
qcom-charge-control-fixup files are not needed.

Backlight (third boot, 2026-10-06): mce probes /sys/class/backlight/* once at startup
(5.28 s), but panel0-backlight appears only when msm_drm's deferred panel bind completes
(5.96-6.11 s), so mce had no brightness control. `mce.service.d/50-pdx246-wait-backlight.conf`
waits up to 10 s for it. `etc/mce/70-pdx246-hybris-features.ini` sets BackLight/KeyPad false:
mce-plugin-libhybris is built without libhybris (upstream `%bcond_with hybris`, LED code only),
so those lookups only logged "undefined symbol mce_hybris_backlight_init".

Charging limiter (sixth boot, 2026-10-07): not active. mce checks ControlPath once at startup
(modules/charging.c mch_config_init), but /sys/class/battchg_ext only appears when battchg_ext's
pmic_glink device probes after the ADSP is up (module loaded at 6.8 s, device at 17.2 s; the ADSP
boot comes from droid-hal-init's early-boot). Waiting for it in mce's ExecStartPre held mce
(and the user session behind it) for 10 s and still missed it, so that wait was removed again.
TODO: a later trigger (e.g. a path/udev-triggered unit that re-applies the policy, or an mce
change that re-probes ControlPath).

### D15. connman

`etc/connman/main.conf.d/50-pdx246.conf` (Sailfish connman reads `main.conf.d`,
sailfishos/connman src/main.c CONFIGMAINDIR). NetworkInterfaceBlacklist: the drop-in
replaces the whole key, so it repeats the image's list (connman-configs-sailfish
main.conf: ifb,p2p,usb,rmnet,rev_rmnet; "usb" covers usb-moded's usb0, 99-usb-moded-pdx246.ini)
and connman's built-in defaults, plus p2p, rmnet, rev_rmnet (zambezi main-custom.conf) and the
Ethernet-type devices this GKI kernel creates: gretap/erspan (CONFIG_NET_IPGRE=y),
ip6gretap (CONFIG_IPV6_GRE=y), ifb (CONFIG_IFB=y) (LOS out obj/KERNEL_OBJ/.config), and
rndis (IPA rndisipam, dev/vendor_dlkm.modules.load:251). TODO R7.
First boots (2026-10-06): the first version left out "usb" (it was based on connman's
built-in defaults only), and the USB debug network on usb0 lost its address mid-boot. With
"usb" back, the next boot kept it. connman logs nothing about usb0 either way, so the link is
inferred, not seen.

### D16. WLAN

`wifisetup.service` -> `usr/bin/droid/wlan-driver-on.sh`: waits for wlan0, then writes
`ON` to `/dev/wlan`. qcacld-3.0 built as a module creates `/dev/wlan` at insmod (WLAN_CTRL_NAME "wlan",
`$ANDROID_ROOT/kernel/sony/sm6450-modules/qcom/opensource/wlan/qcacld-3.0/configs/parrot_gki_adrastea_defconfig:212`);
the `/sys/kernel/boot_wlan` interface zambezi uses exists only for built-in builds
(`#ifndef MODULE`, wlan_hdd_main.c:270-282).

Corrected after the third boot (2026-10-06): "ON" does not start the firmware. On SM6450
the WLAN firmware runs on the WPSS remoteproc, which the vendor boots at early-boot
(/vendor/etc/init/init.vendor.wlan.rc: `write /sys/kernel/icnss/wpss_boot 1`, icnss2
main.c wpss_boot_store -> rproc_boot). On FW-ready icnss2 probes the driver, which creates
wlan0; "ON" only waits up to 20 s for that probe (HDD_WLAN_START_WAIT_TIME, wlan_hdd_main.c
wlan_hdd_state_ctrl_param_write) and syncs the regulatory domain. The first version wrote ON
at 6.7 s, the driver timed out at 27.6 s (EINVAL), WPSS was never booted (D24 stall), and
connman (Before=connman) waited for it. Now the unit is WantedBy=multi-user.target, without
Before=connman: network.target lies on the path to systemd-user-sessions, so a wait here
would delay the UI, and connman picks up a later wlan0 (to check on the next boot).

### D17. sensorfw

AIDL ISensors v3 (multihal). sensorfw's binder backend tries
`android.hardware.sensors.ISensors/default` on /dev/binder before HIDL
(sailfishos/sensorfw core/hybrisbackend_binder.cpp, hybrisbackend_binder_aidl.cpp,
upstream source); the adaptor names in dcd/sparse/etc/sensorfw/primaryuse.conf are
unchanged. `sensord.conf.d/60-sensors-pdx246.conf` only turns off the pressure sensor
(no barometer). The pattern requires `hybris-libsensorfw-qt5-binder >= 0.15.2`
(0.15.1 in adaptation-common 5.1.0.11 per the sibling droid-hal-version NOTES), so it
must be built with `--mw=https://github.com/sailfishos/sensorfw --spec=rpm/sensorfw-qt5-binder.spec`.

`sensorfwd.service.d/50-pdx246-wait-sensors-hal.conf` (third boot, 2026-10-06): sensorfw's
binder backend gives up after 5 x 1 s without a HAL (hybrisbackend_binder.cpp:41-55) and
systemd stops after 3 restarts; the multihal only starts with class hal ("on boot") and needs
the ADSP sensor domain. The drop-in waits up to 45 s for ISensors/default (binder-list).

### D18. NFC

`etc/libncicore.conf`, `[Configuration] Technologies = A,B,F` = libncicore's default
(mer-hybris/libncicore src/nci_sm.c NCI_TECH_DEFAULT), written out as the one place to
tune; the 10 V port limits to A,B. nfcd off by default comes from dcd.

Fifth boot (2026-10-06): the SN220 opened, but RF discovery was rejected (RF_DISCOVER_RSP
status 1) with A,B,F. Now `Technologies = A,B` as on the 10 IV/10 V. Sixth boot: still
RF_DISCOVER_RSP error 1, so not the technologies. Next lead: the NXP HAL log before it
('phNxpNciHal_getChipInfoInFwDnldMode read status error', i2c -107 'maybe in standby'), and nfcd
talking android.hardware.nfc@1.0::INfc to a @1.2 HAL.

### D19. CSD, camera, ssu

- `usr/share/csd/settings.d/hw-settings.ini`: derived from murray's
  sparse/usr/share/csd/settings.d/10-hw-settings.ini (Jolla): the same [features] keys
  in Jolla's order (only CellInfo moved), Jolla's LED comment, and the [BackCamera],
  [SIM] and [Battery] sections; values set for the Xperia 10 VI, with TODOs for LED,
  second mic, stereo speaker, second SIM. `ModemCount=2` follows dsds. Header: Jolla
  Ltd. + user, GPL-2.0-only, with a "Based on" line. `;` comments (Qt INI).
- `etc/dconf/db/vendor.d/jolla-camera-hw.txt`: two back cameras, labels 1.0 and 0.6.
- `usr/share/ssu/board-mappings.d/10-community.ini`: `[pdx246] deviceDesignation=community`,
  Jolla's advice to community ports (mal and Keto, pdx225/sailfish-on-murray/IRCLOGS.md:819-826:
  the store side uses it to tell ports apart).

### D20. TrimArea (tad)

`lib/udev/rules.d/99-pdx246-trimarea.rules`: the partition labelled TA gets owner/group
2997, mode 0770. tad runs as oem_2997 (LOS out odm/etc/init/init.sony-platform.rc:32-37),
stock ueventd sets `.../by-name/TA 0770 vendor_tad vendor_tad` (vendor/etc/ueventd.rc:378-379,
uid 2997 in vendor/etc/passwd), and dhd's makeudev turns that by-name path into rules
that never match (dhd/helpers/makeudev:86-97). The ref used `chmod 666 /dev/sda1` instead.
/dev/block/bootdevice itself comes from the odm rc (`symlink /dev/block/platform/soc/1d84000.ufshc
/dev/block/bootdevice`, init.sony-platform.rc:8) and dcd's 998-droid-system.rules by-name
links; the UFS BSG node for the boot HAL from dcd 997-droid-bsg.rules.

### D21. On-device updates (flash-partition, platform-updates)

- `var/lib/flash-partition/device-info`: boot_a sda72, dtbo_a sda77, vendor_boot_a sda79
  (by-name-live.txt); slot a only. CPUCHECK_STRING "Parrot" (TODO D3): flash-partition
  only flashes when the string is in /proc/cpuinfo or the DT model
  (dcd/sparse/usr/sbin/flash-partition:70-80); the dtb/dtbo sources hold only Qualcomm
  "Parrot" model strings (rg in kernel/sony/sm6450-devicetrees; no Sony model in LOS
  out dtbo.img strings).
- The packages register `flash-bootimg.sh` (img-boot, initrd/droid-hal-device-img-boot.inc:445),
  `flash-vendor_boot.sh`, `flash-dtbo.sh` (dhd/droid-hal-device.inc:1149-1176) and
  `flash-vendor_dlkm.sh` (the %post of droid-hal-pdx246-vendor_dlkm in the
  droid-hal-pdx246 spec) as preinit oneshots on upgrade. A failing oneshot stays
  registered (sailfishos/oneshot scripts/oneshot: `$SCRIPTLET && rm`). Preinit runs
  them in name order, so flash-vendor_dlkm.sh runs last in a pass.
- This is option P of droid-hal-img-boot-pdx246's NOTES (on-device updates of the
  whole set). droid-hal-img-boot-pdx246's spec Requires `droid-hal-pdx246-vendor_dlkm`
  with the same version-release as `-vendor_boot` and `-kernel-dtbo`, so an img-boot
  upgrade pulls the matching vendor_dlkm package.
- Matched-set rule (`pdx246-kernel-set.sh`): the three boot scripts each write
  vendor_boot_a, dtbo_a and boot_a together (skipping partitions that already hold the
  image), and only if the kernel release in /boot/hybris-boot.img (linux_banner; the
  boot image holds the uncompressed Image, dev/BoardConfig.mk:76; extraction tested on
  LOS out boot.img -> 5.10.269-gki-gf985b93da718) equals /boot/vendor_dlkm.release
  (written by droid-hal-pdx246 from the same build as vendor_boot.img and dtbo.img). A
  release change additionally requires flash-vendor_dlkm.sh, which it registers.
  Each write is verified with `ks_part_matches` (read back and `cmp`).
- flash-partition exits 0 without writing when CPUCHECK_STRING is in neither
  /proc/cpuinfo nor the DT model (dcd flash-partition:137, 212-214), and it does not
  check dd. So both ks_flash_boot_set and flash-vendor_dlkm.sh first check
  `grep -qs "$CPUCHECK_STRING" /sys/firmware/devicetree/base/model /proc/cpuinfo`
  (`ks_cpucheck`) and fail early with a clear message (the oneshot stays registered);
  "Parrot" is still a guess (TODO D3).
- Same-boot guard: a rebuild that changes only the modules keeps the kernel release
  (the release names only the kernel commit). Its upgrade registers
  flash-vendor_dlkm.sh, which would then write vendor_dlkm_a in the same preinit pass
  in which the boot scripts rewrite vendor_boot_a, while that boot's initrd has
  already loaded the old first-stage modules (hybris-initrd main-init loads modules
  before preinit). ks_flash_boot_set therefore writes the current
  /proc/sys/kernel/random/boot_id to `/var/lib/platform-updates/.pdx246-set-written`
  before it rewrites vendor_boot_a, and flash-vendor_dlkm.sh exits 1 (stays
  registered) while that file holds the current boot_id. Not done: a second line in
  vendor_dlkm.release with a hash of vendor_boot.img, which would make the set
  identity the build rather than the kernel commit; the release file stays one line,
  which every reader of it expects.
- `flash-vendor_dlkm.sh` (UNTESTED on the phone): runs at the first boot of the new
  kernel (/boot/vendor_dlkm.release == uname -r), not in the boot that rewrote
  vendor_boot_a, in preinit before /vendor_dlkm is mounted; maps vendor_dlkm_a
  read-write under a private name from the super metadata, refuses if the unsparsed
  image is larger than the partition (only fastbootd can resize), refuses a sparse
  image when simg2img is missing (dcd flash-partition would delete the image file,
  :192-196), writes it with flash-partition, then reads the partition back and
  compares the image size worth of bytes with the image (after `simg2img` into
  /var/tmp for a sparse image; /tmp in preinit is the root file system's directory,
  later hidden by the tmpfs). On a mismatch it fails and stays registered. Sparse
  header parsing tested on LOS out system.img; the vendor_dlkm.img of the current
  Sailfish build is a raw ext4 image (66 MiB).
- Logic of both scripts unit-tested with stubs in scratch (Checks done).
- TODO (not implemented, cross-repo): img-boot's Release is 1 for every rebuild with
  the same kernel sublevel (hybris-initrd droid-hal-device-img-boot.inc:
  `Version: %{localver}`, the kernel version without the local suffix, and
  `Release: 1`), so a rebuilt img-boot does not upgrade the installed one, and the
  installed one keeps requiring the old -vendor_boot/-kernel-dtbo/-vendor_dlkm
  version-release. Before any update channel exists, img-boot's release must change
  per build (tags, or derived from the droid-hal release). Until then, do kernel
  updates with fastboot (TODO R11).
- No `flash-recoveryimg.sh`: hybris-recovery.img must never reach recovery_a (the
  bootloader red-states a recovery with a kernel, findings boot-layout FACTS). The
  img-recovery %post then only logs that the script is missing
  (initrd .inc:415, `|| :`).

### D22. delete_file_pdx246.list (dummy_netd); slot a marked once the boot HAL runs

Every sparse-16 default fits pdx246: disabled_services.rc and ecclist.rc (D11), gbinder.conf
ApiLevel 36 (Android 16), droid-bootctl (pdx246 has the AIDL boot HAL; bootctl is in
hybris-boot's HYBRIS_COMMON_ANDROID8_TARGETS, `$ANDROID_ROOT/hybris/hybris-boot/Android.mk:379`),
wait_for_keymint (LOS out vendor/etc/vintf/manifest/android.hardware.security.keymint-service-qti.xml:
IKeyMintDevice/default), ril_subscription.conf/dual-sim.conf (inert without
the ril binder transport plugin; the ref deletes dual-sim, wrongly for pdx246, which runs
dsds), mce and fpd settings. `boot/flashing-README.txt` (a one-line pointer to Jolla's
install page) is replaced by this repository's file at the same path instead.

Slot marking: sparse-16's droid-bootctl.service runs After=start-user-session.service
and is WantedBy=graphical.target, so slot a is marked successful only once the UI is
up. During bring-up every boot that does not reach the UI uses up a boot attempt, and
after about 7 the bootloader fails over to slot b, which holds no bootable system here
("device is corrupt"; PORTING-NOTES.md:7563-7566). A/B fallback has no value on this
port. So `pdx246-mark-slot.service` (After=droid-hal-init.service, Type=oneshot,
ExecStart=/bin/sh /usr/bin/droid/droid-bootctl.sh, WantedBy=multi-user.target via the
`multi-user.target.wants/` link) marks slot a as soon as the boot HAL runs. The
script is idempotent (it marks only an unmarked slot), so droid-bootctl.service later
does nothing. bootctl waits for the HAL (BootControlClient::WaitForService), so the
unit has TimeoutStartSec=60: a HAL that never registers holds multi-user.target for
at most a minute.

Third boot (2026-10-06): the HAL never registered. android.hardware.boot-service.qti does
CHECK(bootcontrol_init()), which reads the Virtual A/B message from misc, found through
vendor fstab.default:47 as `/dev/block/by-name/misc`. ueventd (which makes
/dev/block/by-name) does not run under hybris, and dcd's 998-droid-system.rules only make
.../1d84000.ufshc/by-name. So the HAL aborted every 10 s, pdx246-mark-slot timed out and
droid-bootctl.service (no timeout) held graphical.target. Fixes:
`lib/udev/rules.d/99-pdx246-by-name.rules` makes absolute /dev/block/by-name/<label> links for
UFS partitions only (DEVPATH match), and `droid-bootctl.service.d/50-pdx246-timeout.conf`
gives droid-bootctl 120 s. With by-name present, apexd's /dev/block/by-name/userdata and
thermal-engine-v2's limits-cdsp (read-only) resolve as on Android. GPT on that boot:
boot_a attrs 0x0037... (active, retry 6, not successful), boot_b 0x00f2... (unbootable).

Correction (2026-10-07): dummy_netd's sysconfig MUST be deleted, as both refs do.
`delete_file_pdx246.list` removes /etc/sysconfig/dummy_netd. sparse-16's file starts dummy_netd
with --device=/dev/binder (AIDL netd only). This vendor's netmgrd waits, with no timeout, for the
HIDL android.system.net.netd@1.1::INetd/default (libnetmgr_utils.so; lshal: declared, no server),
so it never finishes init, DSI never initializes, and qcril's CallManager answers every
setupDataCall with OEM_DCFAILCAUSE_4 (0x1004) before reading the request ("DSI init not yet
completed"; disassembly of libqcrilDataModule.so). That was the mobile-data failure on the sixth
boot. The 10 IV hit the same (it broke their VoLTE; IRC). Without the file dummy_netd runs on
/dev/hwbinder and serves HIDL netd@1.1. Risk to test: once DSI works, the modem may register
VoLTE without an oFono IMS plugin (TODO B4), so incoming calls/SMS over IMS would not reach
oFono; test incoming calls and SMS after the fix.

### D23. Not taken from the ref (and why)

overlays/, mount-overlays, overlays.service (fingerprint workaround for an AIDL-only
HAL; pdx246 has HIDL 2.1); wait_for_keymaster (sparse-16 wait_for_keymint fits; the
ref's wants link is broken); qcom-charge-control-fixup (D14); hwservicemanager.rc and
vndservicemanager.rc LD_PRELOAD overrides (hybris-17.1 era; not in sparse-16);
ofono-ril-ecclists.rc (duplicate of sparse-16 ecclist.rc); ld.config.txt (an Android 15
dump; droid-hal packages the A16 linkerconfig, see D24 for why it ran only once);
etc/selinux (D9); compositor droid-hal-device.conf (same as dcd's); droid-bthelper
(optional --mw package, BT call audio did not work on the 10 IV); modules-load.d (D8);
flash-on-windows.bat and the SODP flashing README (Jolla texts, other device).

Correction (third boot, 2026-10-06): task_profiles IS needed. libprocessgroup reads
/etc/task_profiles.json (task_profiles.cpp:53), and on Sailfish /etc is not /system/etc.
Without it logd's DropPrivs (system/logging/logd/main.cpp:76-79) finds no
SCHED_SP_BACKGROUND profile and aborts with PLOG(FATAL) every 5 s, so there was no logcat.
`etc/task_profiles.json` is now a copy of the Android 16 file (AOSP
system/core/libprocessgroup/profiles/task_profiles.json, md5 e3bf84c5, identical to the LOS
system image's /system/etc/task_profiles.json; REUSE.toml: AOSP, Apache-2.0). Not a link: the
first try (fourth boot) was a link and logd still failed, because libprocessgroup reads it with
android::base::ReadFileToString(), which opens with O_NOFOLLOW (system/libbase/file.cpp:250).
first_api_level 34 needs no /etc/task_profiles/ directory. SCHED_SP_BACKGROUND is an aggregate profile and returns
true even when no cgroup action applies. cgroups.json is left out on purpose: its v2 entry
points at systemd's /sys/fs/cgroup, and /dev/cpuctl, /dev/blkio, /dev/cpuset do not exist.

### D24. odsign and the linker configuration (Android 16 init under hybris)

Third boot (2026-10-06), found by a diagnosis workflow and confirmed by independent
verifiers (`notes/analysis/boot3-diagnosis-2026-10-06/`):
- init.rc post-fs-data does `start odsign`, then `wait_for_prop odsign.key.done 1` (no
  timeout; init runs no other action while it waits, init.cpp:1286). odsign could not link
  (libstatspull.so is only in /apex/com.android.os.statsd) and exited 1 every 5 s, so
  early-boot, "on boot" (class_start hal/core: composer, allocator, sensors, BT...) and the
  queued droid.late_start trigger never ran: no UI, no WPSS/ADSP/CDSP boot.
- Why it could not link: Android 16 (system/core 33b0992eba, "init: refactor
  perform_apex_config") runs perform_apex_config's body once per mount namespace. hybris
  patch 0033 disables SetupMountNamespaces(), so GetCurrentMountNamespace() always fails and
  both calls (early-init, post-fs-data) count as bootstrap; the second does nothing. Before it,
  enter_default_mount_ns bind-mounts /linkerconfig/default (the "#" placeholder from
  early-init) over /linkerconfig. Everything started after ~6.9 s ran without linker
  namespaces: APEX libraries not found, and vendor HALs loading /system/lib64 libbinder etc.
- Fixes: (1) system/core hybris-23.2 commit "(hybris) Regenerate the linker configuration
  after enter_default_mount_ns" (builtins.cpp: remember enter_default_mount_ns and count the
  post-fs-data call as NS_DEFAULT), built into droid-hal-init. (2) `odsign_hybris.rc` here:
  odsign stubbed (`_HYBRIS_DISABLED`, `override`) and odsign.key.done /
  odsign.verification.done set `on post-fs`, because odsign has no job without ART/zygote and
  any hang in it would stop init's queue again. Not at post-fs-data: that action would queue
  behind init.rc's waiting one.
- The compressed APEXes (26 .capex: art, conscrypt, media.swcodec, tethering, adbd, ...) were not
  activated: apexd decompressed each one and then deleted it, because
  OpenAndValidateDecompressedApex (system/apex apexd/apexd.cpp) requires a staging_data_file
  SELinux label, and with SELinux disabled getfilecon() fails with ENODATA. Consequence (fifth
  boot): no media.swcodec, so the Codec2 "software" store declared in both VINTF manifests never
  registered and mediaserver's codec list hung, and with it every GStreamer client (camera,
  voicecall-manager, ngfd). Fix (2026-10-07): system/apex hybris-23.2 commit "(hybris) Skip the
  SELinux context check of decompressed APEXes without SELinux". What the newly active APEXes
  bring (audited from LOS out apex/*/etc): media.swcodec (class main, wanted); tethering's
  bpfloader override with reboot_on_failure, rejected because sparse-16's stub is
  non-updatable; adbd override, rejected by our stub (D11); ot-daemon, artd, art_boot (exec from
  init.rc), mainline aconfigd, wpa_supplicant_mainline, media.transcoding, uprobestats: all
  disabled or exec'd without reboot_on_failure; the conscrypt BoringSSL self-test runs without
  reboot_on_failure (boringssl_apex_hybris.rc).
- Fourth boot (2026-10-06): with init no longer stuck, the boot looped. Every boot ended at
  ~17.8 s with `Got shutdown_command 'reboot,boringssl-self-check-failed'`: once
  apexd.status=ready, init.boringssl.zygote64_32.rc runs `exec_start boringssl_self_test_apex32`,
  whose binary is in the conscrypt APEX, which is a .capex and not active here; the
  service has `reboot_on_failure`. `boringssl_apex_hybris.rc` redefines the two APEX self-tests
  (init.rc's definitions, `override`, without reboot_on_failure), so they still run if conscrypt
  is ever active. That boot did reach class hal/core/main/late_start: composer and allocator
  started at 16.2 s, the linker config was regenerated at 15.9 s.


### D25. GNSS: geoclue-providers-hybris 0.3.1 with an AIDL version check (2026-10-07)

pdx246's vendor android.hardware.gnss-aidl-service-qti serves AIDL android.hardware.gnss.IGnss
**V1** (getInterfaceVersion = 1, hash 10839720..., linked against gnss-V1-ndk) and HIDL
gnss@1.0-2.1 in the same process. AIDL V1 has only setCallback, close and the extension getters;
start, setPositionMode (call 20) and injectLocation (call 17) exist from V2 on. SFOS 5.1.0.11
ships geoclue-provider-hybris-binder 0.3.0, which uses AIDL whenever IGnss/default is registered,
so setPositionMode failed ("GNSS set position mode failed"), positioning never started, and
location pages got a cell/Wi-Fi estimate from geoclue-provider-mlsdb (user test, sixth boot).
Android itself uses HIDL gnss@2.1 on V1 vendors (frameworks/base services/core/jni/gnss/Gnss.cpp).
Fix: local build of mer-hybris/geoclue-providers-hybris (hybris/mw/geoclue-providers-hybris,
branch pdx246-0.3.1 = tag 0.3.1, which adds GEOCLUE_HYBRIS_DISABLE_AIDL, plus commit 6ba81f2:
isSupported() asks getInterfaceVersion and falls back to HIDL below V2; upstream candidate).
build-packages-sdk.sh step `geoclue`; the adaptation pattern requires
geoclue-provider-hybris-binder >= 0.3.1. No environment drop-in needed. Side note: xtra-daemon
cannot resolve DNS (no netd DNS proxy under hybris), so assistance data is missing and the first
fix is slower.

---

## TODOs

### Device data (adb root on LineageOS, or any root shell on Sailfish OS)

- **D1 extcon** of the dwc3 glue: `for e in /sys/class/extcon/*; do echo $e $(cat $e/name); done`
  -> `[udev] extcon_tracking/extcon_path` in 99-usb-moded-pdx246.ini.
- **D2 ALSA card id**: `cat /proc/asound/cards` -> exact id in
  99-pulseaudio-ignore-builtin-card.rules.
- **D3 DT model**: `cat /sys/firmware/devicetree/base/model` -> CPUCHECK_STRING in
  device-info (the current "Parrot" is a guess from the sources).
- **D4 LED**: `ls /sys/class/leds`, which controller (aw2016 or qti-tri-led) drives
  red/green/blue -> mce LED backend ini (not written yet) and hw-settings [LED].
- **D5 second SIM**: is slot 2 a physical SIM on XQ-ES54 and XQ-ES72 or eSIM only? ->
  ModemCount, multisim pattern line, dual-sim.conf.
- **D6** `fastboot getvar secure` on the unlocked phone (bootloader): must not be "yes",
  or drop the getvar_fail_if line.
- **D7** stereo speakers / second microphone / hall sensor for hw-settings.ini; sensor
  list of the multihal for sensord.conf.d (stepcounter, wakeup).

### Runtime (first Sailfish OS boots)

- **R1 dynparts**: `systemctl status dmsetup-dynparts`, `dmsetup ls` shows dynpart-*_a,
  all seven mounts active; boot without a usable by-partlabel link uses sda95.
- **R2 audio**: `grep audio.primary /proc/$(pgrep -f pulseaudio)/maps` shows
  audio.hidl_compat.default.so through the parrot link (no "not accessible for the
  namespace" in the journal); `getprop init.svc.vendor.audio-hal` = running; playback,
  recording, call audio. Check module-droid-card arguments against the
  pulseaudio-modules-droid version (14.2.106 recommended for 5.1, IRCLOGS.md:30, 598).
- **R3 modules**: `getprop vendor.all.modules.ready` = 1; `lsmod | wc -l` about 351.
- **R4 USB**: with a cable, `/sys/class/udc/a600000.dwc3` exists and developer mode
  (RNDIS, usb0) and MTP work. `journalctl -u usb-moded-configfs-setup` shows whether
  the peripheral fallback (D12) fired. Once boots with the cable attached show the
  UDC appearing without the fallback (Type-C role switch working), drop the fallback
  from usb-moded-configfs-setup.sh. Check that `/etc/usb-moded/dyn-modes` has
  developer_mode; if not, add `usb-moded-developer-mode-android` to the pattern.
- **R5 Wi-Fi**: `/dev/wlan` appears, wlan0 comes up, connman lists wifi; WPA3 networks.
- **R6 ofono**: both slots appear (`list-modems`), SIM, calls, SMS, data; manual network
  scan with useNetworkScan.
- **R7 connman**: no ethernet technology from gretap/erspan/ifb; mobile data still works
  with rmnet blacklisted.
- **R8 tad**: `ls -l /dev/sda1` (2997:2997 0770), tad running.
- **R9 bootctl**: pdx246-mark-slot.service marks slot a successful early
  (`systemctl status pdx246-mark-slot`, then in the bootloader `fastboot getvar all`:
  slot-successful:a:yes), also on a boot that does not reach the UI; else the slot
  fails over after about 7 boots (D22).
- **R10 charging control**: Settings > Battery limit toggles
  smart_charging_interruption.
- **R11 on-device update**: one package upgrade with an unchanged kernel (only
  boot_a/vendor_boot_a/dtbo_a rewritten), then one with a new kernel (two boots;
  vendor_dlkm_a written on the second), and one modules-only rebuild (vendor_dlkm_a
  written one boot after vendor_boot_a, see `.pdx246-set-written`). Confirm preinit
  oneshots run with /proc/bootconfig and /proc/sys/kernel/random/boot_id readable and
  dmsetup/blockdev/od/cmp/head available, and that the read-back checks pass. Until
  then, and until img-boot's release changes per build (D21), do kernel updates with
  fastboot.
- **R12 NFC** tag reading; **R13** camera labels; **R14** flashlight.
- **R15 fastbootd reachable** from the build VM (USB passthrough must include the
  recovery's fastbootd USB ID), `fastboot --set-active=a` and `fastboot reboot fastboot`
  from the Sony bootloader, and flash-preflight.sh's four getvars answered by
  fastbootd as expected (run it by hand first).
- **R16 re-flash over Sailfish OS**: does `fastboot reboot fastboot` reach fastbootd
  when boot_a/vendor_boot_a hold the Sailfish OS set (LineageOS recovery_a on the
  Sailfish kernel)? If not, the documented route (saved LineageOS boot_a,
  vendor_boot_a, dtbo_a first) is the only one; say so in flashing-README.txt.

### Build-time

- **B1** Build order (README.md "Building"): on the host
  `make hybris-hal droidmedia vendor_dlkmimage audio.hidl_compat.default` (lunch
  lineage_pdx246-bp4a-userdebug; without audio.hidl_compat.default the parrot link
  dangles, and droid-hal's matched-set.sh check() now refuses to package without
  system/lib64/hw/audio.hidl_compat.default.so); in the Platform SDK `-d`, `-c`, `-o --mw`
  (after checking out pulseaudio-modules-droid 14.2.106), `--mw` parse-android-dynparts,
  `--mw` sensorfw with the binder spec (0.15.2, D17), `-g`, img-boot with
  `rpm/dhd/helpers/build_packages.sh -o -N --mw=droid-hal-img-boot-pdx246`, `-v`,
  `-i`. Check ngfd-plugin-native-vibrator availability (droid-hal-version NOTES B1).
  Network clones need a download OK.
- **B2** After `-c`: `rpm -qlp droid-config-pdx246-[0-9]*.rpm` lists the mount units and
  the symlink as a link; `rpm -qlp droid-config-pdx246-flashing-*.rpm` lists device-info
  and the five platform-updates files with mode 755 for the four scripts.
- **B3** After `-i`: the zip holds sailfish.img001, hybris-boot.img, hybris-recovery.img,
  vendor_boot.img, dtbo.img, vendor_dlkm.img, flash.sh (755), flash-config.sh,
  flash-preflight.sh (755), the two READMEs, hw-release, os-release, md5.lst, and the
  mic log shows no "cannot stat"; `./flash.sh --dry-run`-style check with the
  phone in fastboot mode only runs the dry run (`ONLY_DRY_RUN=1 ./flash.sh`).
- **B4** IMS/VoLTE: find an ofono ext plugin for AIDL IMS v12, then enable the pattern line.
- **B5** Fingerprint: decide the fpd stack (sailfish-fpd / sailfish-devicelock-fpd /
  droid-fake-crypt as on the 10 IV/10 V, or Jolla's) and switch the pattern lines.
- **B6** img-boot release per build before any update channel (D21; not implemented).

---

## Cross-repo contract

The final contract all four adaptation repos follow (2026-10-04):

- **Packages.** droid-hal-pdx246 (+ `-devel`, `-users`, `-tools`, `-kernel`,
  `-kernel-modules`, `-detritus`, `-kernel-dtbo`, `-vendor_boot`, `-vendor_dlkm`) from
  `$ANDROID_ROOT/rpm` (droid-hal-pdx246); `droid-hal-pdx246-img-boot` and `-img-recovery`
  from `hybris/mw/droid-hal-img-boot-pdx246` (hybris-initrd); `droid-config-pdx246` and
  its sub-packages from `hybris/droid-configs` (this repo); `droid-hal-version-pdx246`
  from `hybris/droid-hal-version-pdx246`. Submodule pins: dhd be67bbc,
  droid-hal-configs 1dae7f2, droid-hal-version 09c2745, hybris-initrd 7b972b6.
- **Images.** hybris-boot.img (img-boot), vendor_boot.img (`-vendor_boot`), dtbo.img
  (`-kernel-dtbo`), vendor_dlkm.img + vendor_dlkm.release (`-vendor_dlkm`; the release
  file holds the kernel release of that build). The four are one matched set from one
  Sailfish OS build. droid-hal-pdx246 does not build img-boot/img-recovery
  (have_custom_*), skips / /system_root /system /system_ext /product /vendor
  /vendor_dlkm /odm in makefstab (this repo mounts them), and ships
  /usr/libexec/droid-hybris/system/lib64/hw/audio.hidl_compat.default.so.
- **Flash procedure** (decision D5, flash-config.sh, flashing-README.txt): fastbootd first.
  Bootloader: `getvar_fail_if secure yes` (dry run), `fastboot --set-active=a`,
  `fastboot reboot fastboot`; `./flash-preflight.sh` (current-slot a,
  snapshot-update-status none, is-logical:vendor_dlkm_a yes); fastbootd:
  vendor_dlkm_a, userdata (sailfish.img001); `fastboot reboot bootloader`; bootloader:
  boot_a (hybris-boot.img), vendor_boot_a, dtbo_a; `fastboot --set-active=a`; reboot.
  Preconditions and recovery paths: LineageOS on slot a, booted once and merged;
  re-flash over Sailfish OS via the saved LineageOS boot_a/vendor_boot_a/dtbo_a if
  fastbootd is not reached; interrupted run: reconnect, `fastboot reboot bootloader`,
  rerun; slot b holds no bootable LineageOS, rollback = the saved slot-a set.
- **On-device kernel updates** (option P, decision D21): ks_flash_boot_set writes
  boot_a/vendor_boot_a/dtbo_a as a set, gated on /boot/vendor_dlkm.release, verified
  with ks_part_matches, and records the boot_id in .pdx246-set-written when it rewrites
  vendor_boot_a; `-vendor_dlkm`'s %post registers flash-vendor_dlkm.sh, which checks
  CPUCHECK_STRING, waits for the first boot of its kernel and for a boot after the
  vendor_boot_a rewrite, and verifies the written partition. img-boot's spec Requires
  `droid-hal-pdx246-vendor_dlkm` with the same version-release as `-vendor_boot` and
  `-kernel-dtbo`; its %post registers flash-bootimg.sh. Open: img-boot's Release must
  change per build before any update channel (B6).
- **USB in the running OS** (decision D12): usb-moded-configfs-setup.sh waits up to 30 s after
  droid-hal-init for /sys/class/udc/a600000.dwc3 and, if absent, writes `peripheral`
  to /sys/bus/platform/devices/a600000.ssusb/mode and logs it; a bring-up aid to drop
  once the Type-C role switch is shown to work.
- **Slot marking** (decision D22): pdx246-mark-slot.service in this repo.
- **Build** (README.md): host `make hybris-hal droidmedia vendor_dlkmimage
  audio.hidl_compat.default` (lunch lineage_pdx246-bp4a-userdebug); SDK `-d`, `-c`,
  `-o --mw` (after checking out pulseaudio-modules-droid 14.2.106), `--mw` parse-android-dynparts,
  `--mw` sensorfw binder spec, `-g`, img-boot via `-o -N --mw=droid-hal-img-boot-pdx246`
  (not `-b`), `-v`, `-i`.
- **Mount units** (decision D7): this repo's seven dynamic-partition units; droid-hal's 10
  dhd units; vendor rc mounts at runtime by droid-hal-init.
- This repo provides: patterns-sailfish-device-adaptation-pdx246 and
  -configuration-pdx246; droid-config-pdx246-flashing with
  /var/lib/flash-partition/device-info and /var/lib/platform-updates/{flash-bootimg.sh,
  flash-vendor_boot.sh, flash-dtbo.sh, flash-vendor_dlkm.sh, pdx246-kernel-set.sh};
  droid-config-pdx246-out-of-image-files (flash.sh, flash-config.sh,
  flash-preflight.sh, the READMEs); kickstart pack producing sailfish.img001.
  droid-hal-version-pdx246 Requires patterns-sailfish-device-configuration-pdx246.
- Device names: DEVICE=pdx246, VENDOR=sony; partition names on the phone always
  carry `_a`.

---

## Checks done

- `rpmspec -q` on rpm/droid-config-pdx246.spec (SDK's rpmspec, scratch copy with dcd
  linked in; re-run after the final changes): 13 packages as expected, adaptation
  pattern requires as written, `sailfish-content-graphics-z1.75`; the only
  macro-in-comment warning comes from droid-configs.inc:160, none from this repo.
- Replayed droid-configs.inc's %install file handling (dcd + this sparse) in scratch,
  again after the final changes: device files land in droid-config-pdx246 (including
  pdx246-mark-slot.service and its multi-user.target.wants link, kept under
  /usr/lib/systemd), the pulse rule and .pa in -pulseaudio-settings,
  jolla-camera-hw.txt in -sailfish, device-info and platform-updates in -flashing,
  the five boot files (flash.sh, flash-config.sh, flash-preflight.sh with mode 755,
  flashing-README.txt, extracting-README.txt) in -out-of-image-files and none of
  them in the main package; the generic /etc/selinux/config (disabled) is the one
  installed.
- `sh -n`, `bash -n` and `dash -n` on every shell script (flash-preflight.sh,
  the platform-updates scripts, dmsetup-dynparts.sh, wlan-driver-on.sh,
  usb-moded-configfs-setup.sh), `bash -n` on flash-config.sh and the pack scriptlet.
- Unit tests with stubs in scratch: ks_flash_boot_set (flash all, skip when current,
  refuse a mismatched set, CPU check failing, a flash-partition that exits 0 without
  writing, kernel change registering flash-vendor_dlkm.sh); flash-vendor_dlkm.sh
  (waits in the boot that rewrote vendor_boot_a, writes and verifies at the next,
  raw and sparse images, verification failure, missing simg2img, CPU check);
  kernel-release extraction on LOS out boot.img; sparse header parsing on LOS out
  system.img; the vendor_dlkm table rewrite on a sample concise table.
- flash-preflight.sh against a stub fastboot (pass; 0 or 2 devices; 2 devices with
  ANDROID_SERIAL; not in fastbootd; slot b; merging; getvar FAILED for
  is-logical); the whole FLASH_OPS list replayed with dcd flash.sh's own
  run_flash_op/print_and_run (preflight called without stray arguments; a failing
  preflight stops the run before the first flash); GETVAR_ERROR_secure printed
  through flash.sh's `eval echo -e`.
- The pack's file list on a sample directory: 13 files, no duplicate, `mv` exits 0.

---

## PROVENANCE

| file | origin | licence handling |
|---|---|---|
| rpm/droid-config-pdx246.spec | derived from mer-hybris/droid-hal-configs@1dae7f2:droid-config-@DEVICE@.spec.template (Jolla Ltd.) | keeps Jolla (`SPDX-FileCopyrightText: Jolla Ltd.`, no year: the template history spans 2015-2026) + user; GPL-2.0-only (droid-configs.inc `License: GPLv2`) |
| patterns/patterns-sailfish-device-adaptation-pdx246.inc | generated by mer-hybris/droid-hal-device@be67bbc:helpers/add_new_device.sh from droid-hal-configs@1dae7f2:patterns/templates/patterns-sailfish-device-adaptation-@DEVICE@.inc, edited | Jolla Ltd. + user; GPL-2.0-only |
| patterns/patterns-sailfish-device-configuration-pdx246.inc | same, from ...-configuration-@DEVICE@.inc | Jolla Ltd. + user; GPL-2.0-only |
| kickstart/pack/pdx246/hybris | derived from mer-hybris/droid-config-sony-zambezi@70a3767:kickstart/pack/xqdc54/hybris (Jolla Ltd., no in-file notice) | header: Jolla Ltd. + user, GPL-2.0-only; derivation stated in the file |
| kickstart/part/pdx246 | same content as mer-hybris/droid-config-sony-zambezi@70a3767:kickstart/part/xqdc54 | REUSE.toml: Jolla Ltd. only, GPL-2.0-only |
| kickstart/attachment/pdx246 | adapted from mer-hybris/droid-config-sony-zambezi@70a3767:kickstart/attachment/xqdc54 | REUSE.toml: Jolla Ltd. + user, GPL-2.0-only |
| out-of-image-files.files | new (list of the five files that exist) | REUSE.toml: user, Apache-2.0 |
| .gitmodules (created by `git submodule add`, SUBMODULES.md) | new | REUSE.toml: user, Apache-2.0 |
| sparse/boot/flash-config.sh | new (format documented in dcd sparse/boot/flash.sh) | header: user, Apache-2.0 |
| sparse/boot/flash-preflight.sh | new | header: user, Apache-2.0 |
| sparse/boot/flashing-README.txt | new | header: user, Apache-2.0 |
| sparse/etc/connman/main.conf.d/50-pdx246.conf | new | header |
| sparse/etc/dconf/db/vendor.d/jolla-camera-hw.txt | new (dconf key as used by Jolla configs) | header |
| sparse/etc/libncicore.conf | new | header |
| sparse/etc/mce/70-battery-pdx246.ini | new (keys as in zambezi 70-battery-zambezi.ini; values from dev/device.mk) | header |
| sparse/etc/ofono/binder.d/pdx246.conf | new (keys from mer-hybris/ofono-binder-plugin binder.conf) | header |
| sparse/etc/pulse/arm_droid_card_custom.pa | new; `hw_volume=false` as in mer-hybris/droid-config-sony-zambezi@70a3767:sparse/etc/pulse/arm_droid_card_custom.pa (Jolla) | header |
| sparse/etc/sensorfw/sensord.conf.d/60-sensors-pdx246.conf | new (layout of sailfishos/sensorfw config/60-sensors-DEVICE.conf) | header (`;` comments) |
| sparse/etc/usb-moded/99-usb-moded-pdx246.ini | new; keys and layout as zambezi usb-moded-zambezi.ini, values from pdx246 | header |
| sparse/lib/udev/rules.d/99-pdx246-trimarea.rules | new | header |
| sparse/lib/udev/rules.d/99-pulseaudio-ignore-builtin-card.rules | new (rule form as in zambezi's file of that name) | header |
| sparse/usr/bin/droid/dmsetup-dynparts.sh | new | header |
| sparse/usr/bin/droid/wlan-driver-on.sh | new | header |
| sparse/usr/libexec/usb-moded-configfs-setup.sh | new (written from init.qcom.usb.rc and usb-moded's configfs code; the ref's script not used) | header |
| sparse/usr/libexec/droid-hybris/system/etc/init/disabled_services_device.rc | new (file name as in zambezi) | header |
| sparse/usr/libexec/droid-hybris/system/etc/init/servicemanager_selinux_stubs.rc | derived from AOSP's servicemanager.rc, vndservicemanager.rc and hwservicemanager.rc (Android 16); setenv/override as in the refs' vndservicemanager.rc | header: The Android Open Source Project + user, Apache-2.0 |
| sparse/usr/libexec/droid-hybris/system/lib64/hw/audio.primary.parrot.so | new symlink | REUSE.toml: user, Apache-2.0 |
| sparse/usr/lib/systemd/system/dmsetup-dynparts.service | new | header |
| sparse/usr/lib/systemd/system/{system_root,system,system_ext,product,vendor,vendor_dlkm,odm}.mount | new (ref units not used) | header |
| sparse/usr/lib/systemd/system/local-fs.target.wants/*.mount | new symlinks | REUSE.toml |
| sparse/usr/lib/systemd/system/usb-moded-configfs-setup.service, usb-moded.service.d/50-configfs-setup.conf | new | header |
| sparse/usr/lib/systemd/system/wifisetup.service | new | header |
| sparse/usr/lib/systemd/system/multi-user.target.wants/wifisetup.service | new symlink (was network.target.wants until 2026-10-06, D16) | REUSE.toml |
| sparse/usr/lib/systemd/system/droid-bootctl.service.d/50-pdx246-timeout.conf | new | header |
| sparse/usr/lib/systemd/system/sensorfwd.service.d/50-pdx246-wait-sensors-hal.conf | new | header |
| sparse/usr/lib/systemd/system/mce.service.d/50-pdx246-wait-backlight.conf | new | header |
| sparse/etc/mce/70-pdx246-hybris-features.ini | new | header |
| sparse/etc/task_profiles.json | copy of AOSP system/core/libprocessgroup/profiles/task_profiles.json (D23) | REUSE.toml: The Android Open Source Project, Apache-2.0 |
| sparse/usr/libexec/droid-hybris/system/etc/init/boringssl_apex_hybris.rc | derived from AOSP init.rc service definitions (D24) | header: The Android Open Source Project + user, Apache-2.0 |
| sparse/lib/udev/rules.d/99-pdx246-by-name.rules | new | header |
| sparse/usr/libexec/droid-hybris/system/etc/init/odsign_hybris.rc | new | header |
| sparse/usr/lib/systemd/user/pulseaudio.service.d/50-pdx246-qti-passthrough.conf | new | header |
| delete_file_pdx246.list | new (device delete list read by droid-configs.inc) | header |
| sparse/etc/pulse/default_sailfish.pa | copy of dcd's file, virtual_stream=true (D10) | REUSE.toml: PulseAudio developers, Jolla Ltd., user; LGPL-2.1-or-later |
| sparse/usr/lib/systemd/system/pdx246-mark-slot.service | new (runs sparse-16's droid-bootctl.sh earlier) | header |
| sparse/usr/lib/systemd/system/multi-user.target.wants/pdx246-mark-slot.service | new symlink | REUSE.toml |
| sparse/usr/share/csd/settings.d/hw-settings.ini | derived from mer-hybris/droid-config-sony-murray@83c7d48:sparse/usr/share/csd/settings.d/10-hw-settings.ini (Jolla Ltd.) | header: Jolla Ltd. + user, GPL-2.0-only, "Based on" line (`;` comments) |
| sparse/usr/share/ssu/board-mappings.d/10-community.ini | new (content as advised by Jolla on IRC) | header (`;` comments) |
| sparse/var/lib/flash-partition/device-info | new (variables read by dcd flash-partition) | header |
| sparse/var/lib/platform-updates/flash-{bootimg,vendor_boot,dtbo,vendor_dlkm}.sh, pdx246-kernel-set.sh | new | header |
| .gitignore | new; same entries as zambezi .gitignore | header |
| README.md | new | HTML-comment header |
| NOTES.md, SUBMODULES.md | new | REUSE.toml |
| REUSE.toml | new | header |
| LICENSES/Apache-2.0.txt, LICENSES/GPL-2.0-only.txt | licence texts, copied from dev/LICENSES (identical sha256 to the other adaptation repos) | REUSE convention |

No text was taken from sharks-dev's files; they were read for the list of topics
only. Where values coincide with them, the Jolla original is cited (hw-settings.ini,
arm_droid_card_custom.pa, 99-usb-moded-pdx246.ini, the kickstart files). No compiled
Jolla artefact is included. LineageOS is credited
for nothing here: the facts taken from the LineageOS port (device.mk values, fstab,
BoardConfig) are this project's own device tree.
