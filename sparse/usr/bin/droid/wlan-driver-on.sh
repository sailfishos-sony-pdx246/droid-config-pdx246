#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: GPL-2.0-only
#
# qcacld-3.0 WLAN driver (qca_cld3_adrastea.ko, loaded from /vendor_dlkm by
# vendor_modprobe.sh in droid-hal-init). The WLAN firmware runs on the WPSS
# remote processor, which the vendor init boots at early-boot
# (/vendor/etc/init/init.vendor.wlan.rc: write /sys/kernel/icnss/wpss_boot 1).
# On FW-ready, icnss2 probes the driver, which creates wlan0. Writing "ON" to
# /dev/wlan (wlan_hdd_main.c, wlan_hdd_state_ctrl_param_write) starts nothing:
# it waits at most 20 s for that probe and syncs the regulatory domain; on
# Android the Wi-Fi HAL does this write. So wait for wlan0 first.

n=0
while [ ! -e /sys/class/net/wlan0 ] && [ $n -lt 60 ]; do
    sleep 1
    n=$((n + 1))
done

if [ ! -e /dev/wlan ]; then
    echo "wlan-driver-on: /dev/wlan did not appear" >&2
    exit 1
fi
[ -e /sys/class/net/wlan0 ] || echo "wlan-driver-on: no wlan0 after 60 s, trying anyway" >&2

echo ON > /dev/wlan
