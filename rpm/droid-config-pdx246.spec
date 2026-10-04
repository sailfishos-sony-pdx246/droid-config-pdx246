# SPDX-FileCopyrightText: Jolla Ltd.
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: GPL-2.0-only
#
# droid-config-pdx246: Sailfish OS device configuration for the Sony Xperia 10 VI
# (pdx246; XQ-ES54 and XQ-ES72), Android 16 / LineageOS 23.2 base (hybris-23.2).
# Checked out at $ANDROID_ROOT/hybris/droid-configs, with mer-hybris/droid-hal-configs
# at droid-configs-device (SUBMODULES.md). Built from $ANDROID_ROOT with
#   rpm/dhd/helpers/build_packages.sh -c
#
# Started from droid-configs-device/droid-config-@DEVICE@.spec.template
# (mer-hybris/droid-hal-configs 1dae7f2, Jolla Ltd.; the package is tagged
# GPLv2 in droid-configs.inc). NOTES.md gives the evidence for every value.
#
# These and other macros are documented in ../droid-configs-device/droid-configs.inc
#
# IMPORTANT: rpm expands macros in comments too. No comment in this file (or in
# the included patterns) may contain a percent sign; to disable a macro, delete
# its line instead of commenting it out.

# One build serves XQ-ES54 and XQ-ES72, so the device name is the codename and
# rpm_device is left at its default (= device). hw-release, the ssu board
# mapping, the kickstart and every package name use pdx246.
%define device pdx246
%define vendor sony

%define vendor_pretty Sony
%define device_pretty Xperia 10 VI

# Use droid-configs-device/sparse-16 on top of the base sparse.
%define android_version_major 16

# Community HW adaptations need this
%define community_adaptation 1

# Build droid-config-pdx246-out-of-image-files (flash.sh, flash-config.sh,
# flash-preflight.sh and the READMEs, listed in out-of-image-files.files). The
# kickstart attaches that package, so the files land next to the images in the
# release zip.
%define out_of_image_files 1

# 6.1 inch, 1080x2520 (TARGET_SCREEN_DENSITY 450, about 449 ppi). 449/245 is
# 1.83; the nearest step is 1.75, the value the 10 V (same panel class) uses.
%define pixel_ratio 1.75

# Device-specific usb-moded configuration (etc/usb-moded/99-usb-moded-pdx246.ini)
Provides: usb-moded-configs
Obsoletes: usb-moded-defaults

# Device-specific ofono configuration (etc/ofono/binder.d/pdx246.conf on top of
# the binder.conf, dual-sim.conf and ril_subscription files from the generic
# sparse trees, which this package installs)
Provides: ofono-configs
Obsoletes: ofono-configs-mer
Obsoletes: ofono-configs-binder

# Bluetooth hands-free audio gateway for headsets and car kits, as the official
# Sony ports configure it.
%define ofono_enable_plugins bluez5,hfp_ag_bluez5
%define ofono_disable_plugins bluez4,dun_gw_bluez4,hfp_ag_bluez4,hfp_bluez4,dun_gw_bluez5,hfp_bluez5

# binder-list, used by sparse-16 usr/bin/droid/wait_for_keymint
Requires: libgbinder-tools

%include droid-configs-device/droid-configs.inc
%include patterns/patterns-sailfish-device-adaptation-pdx246.inc
%include patterns/patterns-sailfish-device-configuration-pdx246.inc

# IMPORTANT if you want to comment out any macros in your .spec, delete the
# percent sign, otherwise they will remain defined! E.g.:
#define some_macro "I'll not be defined because I don't have a percent sign in front"
