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

# Waydroid (Android apps in an LXC container): the device glue. Waydroid itself
# is the port's own package (hybris/mw/waydroid: 1.6.3 with patches). The files
# are in sparse/ and listed in packaged-in-main-spec.files, so the main package
# leaves them out. Why the container needs its own view of /vendor: see
# sparse/usr/libexec/pdx246-waydroid/vendor-view.
%package waydroid
Summary: Waydroid integration for the Sony Xperia 10 VI
Requires: waydroid >= 1.6.3
# Only the port's waydroid binds the vendor view (its patch 0006); a waydroid
# from another repository must not replace it.
Requires: waydroid(vendor-view)
Requires: waydroid-gbinder-config-hybris
Recommends: waydroid-runner

%description waydroid
Device glue for Waydroid on the Sony Xperia 10 VI: the container's view of
/vendor without the vendor's copies of the libraries the Android 13 image
ships itself, the container's binder nodes in /dev, and a check that keeps
the container off the phone's own binder. Also masks lxc@multi-user.service,
which the lxc package's enabled template unit would start (and fail) at
every boot.

%files waydroid
%defattr(-,root,root,-)
/usr/libexec/pdx246-waydroid
/usr/share/pdx246-waydroid
/usr/lib/systemd/system/pdx246-waydroid-vendor-view.service
/usr/lib/systemd/system/multi-user.target.wants/pdx246-waydroid-vendor-view.service
%dir /usr/lib/systemd/system/waydroid-container.service.d
/usr/lib/systemd/system/waydroid-container.service.d/50-pdx246.conf
/usr/lib/tmpfiles.d/pdx246-waydroid.conf
# lxc's install enables the template lxc@.service without an instance, so
# systemd starts lxc@multi-user.service at every boot and it fails (no such
# container). A link to /dev/null masks that one instance.
/usr/lib/systemd/system/lxc@multi-user.service

%post waydroid
systemd-tmpfiles --create /usr/lib/tmpfiles.d/pdx246-waydroid.conf || :
systemctl daemon-reload || :
systemctl reset-failed lxc@multi-user.service >/dev/null 2>&1 || :
# Waydroid starts its own dnsmasq on its bridge; the system-wide service would
# hold the address first (dnsmasq: failed to create listening socket).
systemctl mask --now dnsmasq.service >/dev/null 2>&1 || :
# Mount the vendor view now, not only at the next boot: a waydroid init run
# before that would write /vendor into the container's mount list.
systemctl start pdx246-waydroid-vendor-view.service >/dev/null 2>&1 || :

%preun waydroid
if [ $1 -eq 0 ] ; then
  # Also stops waydroid-container.service (it requires the view).
  systemctl stop pdx246-waydroid-vendor-view.service >/dev/null 2>&1 || :
fi

%postun waydroid
if [ $1 -eq 0 ] ; then
  systemctl unmask dnsmasq.service >/dev/null 2>&1 || :
  systemctl daemon-reload || :
fi
