#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
#
# Start the qcacld-3.0 WLAN driver (qca_cld3_adrastea.ko, loaded from
# /vendor_dlkm by vendor_modprobe.sh in droid-hal-init). Built as a module, the
# driver creates /dev/wlan (WLAN_CTRL_NAME "wlan" in
# configs/parrot_gki_adrastea_defconfig) and brings the firmware up when "ON"
# is written to it (wlan_hdd_main.c, wlan_hdd_state_ctrl_param_write); on
# Android the Wi-Fi HAL does this write.

n=0
while [ ! -e /dev/wlan ] && [ $n -lt 30 ]; do
    sleep 1
    n=$((n + 1))
done

if [ ! -e /dev/wlan ]; then
    echo "wlan-driver-on: /dev/wlan did not appear" >&2
    exit 1
fi

echo ON > /dev/wlan
