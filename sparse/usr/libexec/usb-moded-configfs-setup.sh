#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
#
# Prepare the configfs USB gadget for usb-moded.
#
# usb-moded creates function directories itself, but expects the gadget, its
# strings and configs/b.1 to exist. On Android, pdx246's
# /vendor/etc/init/hw/init.qcom.usb.rc creates them "on zygote-start", a trigger
# the hybris init.rc never fires (hybris-patches system/core 0015 comments out
# "trigger zygote-start"), so nothing creates them under Sailfish OS.
# The ownership follows init.qcom.usb.rc (system:usb, 0770).

PATH=/usr/sbin:/usr/bin:/sbin:/bin
G=/config/usb_gadget/g1

# droid-hal-init mounts configfs on /config ("on init" in init.rc); wait for
# it briefly, then mount it here if it is still missing.
n=0
while ! mountpoint -q /config && [ $n -lt 10 ]; do
    sleep 1
    n=$((n + 1))
done
if ! mountpoint -q /config; then
    mkdir -p /config
    mount -t configfs none /config || exit 1
fi

for d in "$G" "$G/strings/0x409" "$G/configs/b.1" "$G/configs/b.1/strings/0x409"; do
    [ -d "$d" ] || mkdir -m 0770 "$d" || exit 1
done
chown -R system:usb "$G" 2>/dev/null || :

# Bring-up aid, to be dropped once the Type-C role switch is shown to work
# (NOTES.md R4): the UDC a600000.dwc3 appears only once the dwc3-msm glue is in
# peripheral mode (pdx246's init.recovery.qcom.rc writes "peripheral" to the
# glue's mode for the same reason). Under Android the Type-C role switch in the
# ADSP (pmic_glink/ucsi_glink) does that on cable insertion; under Sailfish OS
# that chain (vendor_dlkm modules, vendor.modprobe, ADSP boot) is untested.
# So: wait up to 30 s after droid-hal-init for the UDC; if it is still absent,
# force peripheral mode and log it. Forcing it disables USB host/OTG until the
# next boot.
UDC=/sys/class/udc/a600000.dwc3
GLUE_MODE=/sys/bus/platform/devices/a600000.ssusb/mode
n=0
while [ ! -e "$UDC" ] && [ $n -lt 30 ]; do
    sleep 1
    n=$((n + 1))
done
if [ ! -e "$UDC" ]; then
    echo "usb-moded-configfs-setup: no UDC a600000.dwc3 after 30 s; writing peripheral to $GLUE_MODE (bring-up fallback, USB host disabled until reboot)" >&2
    if echo peripheral > "$GLUE_MODE"; then
        n=0
        while [ ! -e "$UDC" ] && [ $n -lt 5 ]; do
            sleep 1
            n=$((n + 1))
        done
        [ -e "$UDC" ] || echo "usb-moded-configfs-setup: UDC a600000.dwc3 still missing after the peripheral write" >&2
    else
        echo "usb-moded-configfs-setup: writing $GLUE_MODE failed" >&2
    fi
fi

exit 0
