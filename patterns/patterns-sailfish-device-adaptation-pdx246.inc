# Feel free to disable non-critical HA parts during devel by commenting lines out
# Generated in hadk by executing: rpm/dhd/helpers/add_new_device.sh

# SPDX-FileCopyrightText: Jolla Ltd.
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: GPL-2.0-only
#
# Generated with DEVICE=pdx246 from droid-configs-device/patterns/templates/
# patterns-sailfish-device-adaptation-@DEVICE@.inc (mer-hybris/droid-hal-configs
# 1dae7f2), then edited for pdx246; NOTES.md lists every change with evidence.
# This file is included by the spec: no percent sign in comments.

%package -n patterns-sailfish-device-adaptation-pdx246
Summary: Jolla HW Adaptation pdx246
Requires: droid-hal-pdx246
# hybris-boot.img (LVM initrd, boot_a) and hybris-recovery.img (debug image, for
# boot_a only, never recovery_a), both from droid-hal-img-boot-pdx246
Requires: droid-hal-pdx246-img-boot
Requires: droid-hal-pdx246-img-recovery
# Kernel modules: deliberately NOT required here. build_packages.sh -i runs
# "mic create fs" (rootfs tarball) when this file has a line starting with
# "Requires: droid-hal-pdx246-kernel-modules", and "mic create loop" (the
# root.img/home.img that kickstart/pack/pdx246/hybris turns into the LVM image
# sailfish.img001) otherwise. droid-hal-pdx246-img-boot ships /lib/modules and
# provides/obsoletes the kernel-modules package anyway.
#Requires: droid-hal-pdx246-kernel-modules
# Kernel-dependent images from the same droid-hal build as the kernel: kernel,
# vendor_boot, dtbo and vendor_dlkm are one matched set (module CRCs).
Requires: droid-hal-pdx246-kernel-dtbo
Requires: droid-hal-pdx246-vendor_boot
Requires: droid-hal-pdx246-vendor_dlkm
# simg2img for flash-partition (on-device updates of the images above)
Requires: droid-hal-pdx246-tools
Requires: droid-config-pdx246-sailfish
Requires: droid-config-pdx246-pulseaudio-settings
Requires: droid-config-pdx246-policy-settings
Requires: droid-config-pdx246-preinit-plugin
Requires: droid-config-pdx246-flashing
Requires: droid-config-pdx246-bluez5
Requires: droid-hal-version-pdx246

# Dynamic partitions: no Android first-stage init runs, so dmsetup-dynparts.service
# maps the logical partitions of super with these two
Requires: parse-android-dynparts
Requires: device-mapper

# For suspend to work with Wi-Fi enabled on newer Qualcomm devices
Requires: sailfish-connman-plugin-suspend

# Hybris packages
Requires: libhybris-libEGL
Requires: libhybris-libGLESv2
Requires: libhybris-libwayland-egl

# Sensors: pdx246 serves AIDL ISensors v3 (multihal); the binder backend of
# sensorfw 0.15.2 talks to it (it tries AIDL first, then HIDL)
Requires: sensorfw-qt5
Requires: hybris-libsensorfw-qt5-binder >= 0.15.2

# Bluetooth (CONFIG_BT_HCIVHCI=y in the Sailfish kernel fragment)
Requires: bluebinder

# Telephony: IRadio 1.6 on slot1 and slot2, used through radioInterface 1.5
Requires: ofono-binder-plugin
Requires: dummy_netd
# IMS on pdx246 is AIDL only (vendor.qti.hardware.radio.ims v12). No ext-qti
# plugin is known to support it yet; see NOTES.md TODO.
#Requires: ofono-binder-plugin-ext-qti

# Vibra
Requires: ngfd-plugin-native-vibrator
Requires: libngf-qt5-qtfeedback

# Needed for /dev/touchscreen symlink
Requires: qt5-plugin-generic-evdev

# Audio: pulseaudio-modules-droid loads "audio.primary" through the hybris
# libhardware, which finds droid-config's symlink
# /usr/libexec/droid-hybris/system/lib64/hw/audio.primary.parrot.so ->
# audio.hidl_compat.default.so (built in the Android tree from
# vendor/halium/hardware, packaged by droid-hal-pdx246); that forwards to the
# vendor's HIDL 7.0 audio service. See NOTES.md.
Requires: pulseaudio-modules-droid
Requires: pulseaudio-modules-droid-hidl

# Bluetooth headset call audio (HFP/HSP): droid-bthelper tells the vendor
# audio HAL (IDevice 7.0 setConnectedState) when a headset connects or
# disconnects, so that PAL marks its SCO devices available and accepts
# BT_SCO=on; without it call audio stays on the phone. Local build of
# rinigus' droid-bthelper 0.3.0 (hybris/mw/droid-bthelper, branch
# pdx246-0.3.0, tag 0.3.0 = upstream 511bcd9); the 10 IV/10 V copy targets
# audio 6.0. NOTES.md D26.
Requires: droid-bthelper >= 0.3.0

# The -dummy-af is needed for newer devices that run the main
# audiosystem-passthrough in qti mode (e.g. >=Android 9 Qualcomm),
# to fix non-responding Camera app and/or voice during a phone call:
Requires: audiosystem-passthrough-dummy-af

# for audio recording to work:
Requires: qt5-qtmultimedia-plugin-mediaservice-gstmediacapture

# These need to be per-device due to differing backends (fbdev, eglfs, hwc, ..?)
Requires: qt5-qtwayland-wayland_egl
Requires: qt5-qpa-hwcomposer-plugin
Requires: qtscenegraph-adaptation

# For hybris devices with droidmedia, see HADK pdf for more information
Requires: gstreamer1.0-droid
Obsoletes: gmp-droid

# This is needed for notification LEDs
Requires: mce-plugin-libhybris

# USB mode controller
Requires: usb-moded

# hammerhead, grouper, and maguro use this in scripts, so include for all
Requires: rfkill

# Device lock with fingerprint (B5, tested on the phone 2026-10-09): Jolla's
# fpd stack. sailfish-devicelock-fpd replaces jolla-devicelock-daemon-encsfa and
# provides jolla-devicelock-plugin-encsfa; sailfish-fpd pulls in
# sailfish-fpd-slave-binder, a client of the vendor's HIDL fingerprint 2.1 HAL.
# Its settings (/etc/sailfish-fpd/50-settings.ini) and wait_for_keymint.service
# come from droid-configs-device sparse-16. Fallback if ever needed:
# sailfish-fpd-community + droid-biometry-fp (notes: fingerprint research).
Requires: sailfish-devicelock-fpd
Requires: sailfish-fpd
Obsoletes: jolla-devicelock-daemon-encsfa
Obsoletes: jolla-devicelock-plugin-encsfa

# Enable home encryption
#Requires: sailfish-device-encryption

# For GPS
# Local build of mer-hybris/geoclue-providers-hybris 0.3.1 with an AIDL
# interface-version check (hybris/mw/geoclue-providers-hybris, branch
# pdx246-0.3.1): pdx246's vendor serves AIDL IGnss V1, which lacks start and
# setPositionMode, and 0.3.0 used it anyway (NOTES.md D25).
Requires: geoclue-provider-hybris-binder >= 0.3.1

# VoLTE and SMS over IMS: AIDL IMS client for oFono, local build of
# rinigus/ofono-binder-plugin-ext-qti 0.1.1+aidl (hybris/mw, branch
# pdx246-0.1.1-aidl). pdx246's vendor IMS radio interface is AIDL only
# (vendor.qti.hardware.radio.ims.IImsRadio V12). It ships
# /etc/ofono/binder.d/qti.conf (extPlugin = qti). NOTES.md D13.
Requires: ofono-binder-plugin-ext-qti >= 0.1.1

# For FM radio on some QCOM devices
#Requires: qt5-qtmultimedia-plugin-mediaservice-irisradio
#Requires: jolla-mediaplayer-radio

# NFC support
# 1. binder plugin requires Android 8 or a newer base
# 2. pn54x plugin talks directly to pn54x driver
# These plugins are mutually exclusive, you need to pick one:
# pdx246: NXP SN-series behind android.hardware.nfc_snxxx@1.2-service
Requires: nfcd-binder-plugin
# Local build of mer-hybris/libncicore 1.2.0 that polls only in passive modes
# for reader/writer (hybris/mw/libncicore, branch pdx246-1.2.0): the SN220
# rejects RF_DISCOVER_CMD with active-poll entries (no NFC-DEP). The
# adaptation-common repo has 1.1.31. NOTES.md D18.
Requires: libncicore >= 1.2.0
#Requires: nfcd-pn54x-plugin

%description -n patterns-sailfish-device-adaptation-pdx246
Pattern with packages for pdx246 HW Adaptation

%files -n patterns-sailfish-device-adaptation-pdx246
