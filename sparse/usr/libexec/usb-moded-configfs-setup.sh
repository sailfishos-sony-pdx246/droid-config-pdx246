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
# The gadget stays owned by root (usb-moded runs as root with CAP_DAC_OVERRIDE).
# It is not chowned to system:usb as on Android: without SELinux, vendor
# daemons running as system (the QTI USB HALs) could then rewrite or unbind it.

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
# Charging from a PC: b.1 starts at 2 mA (CONFIG_USB_GADGET_VBUS_DRAW).
# usb-moded writes gadget_max_power once at startup; this keeps b.1 off 2 mA
# from the start.
echo 900 > "$G/configs/b.1/MaxPower" 2>/dev/null || :
# buteo-mtp 0.9.12 sends no SuperSpeed descriptors, and without them the kernel
# offers no configuration on a SuperSpeed link (composite.c config_desc), so MTP
# would not enumerate on a USB 3 port. Keep the gadget at high speed.
echo high-speed > "$G/max_speed" 2>/dev/null || :

# Bring-up aid, to drop once R4 is settled (NOTES.md): the UDC a600000.dwc3
# appears when the dwc3-msm glue gets its first role, from the Type-C role
# switch (ucsi_glink sets one when it registers its port, also without a
# cable) or from a write to the glue's mode. ucsi_glink and the battery
# charger's "usb" power supply both come up with the ADSP (pmic_glink), 2-11 s
# after droid-hal-init in the boots seen so far. So: wait for the UDC up to
# 30 s, but no longer than 3 s after the "usb" power supply has appeared; if it
# is still absent, force peripheral and log it. The write is a one-off role
# change: the next Type-C event (unplug, OTG device) overrides it. In host mode
# (OTG device attached) there is no UDC by design: do not force.
UDC=/sys/class/udc/a600000.dwc3
GLUE_MODE=/sys/bus/platform/devices/a600000.ssusb/mode
PSY=/sys/class/power_supply/usb
n=0
g=0
while [ ! -e "$UDC" ] && [ $n -lt 30 ]; do
    [ "$(cat "$GLUE_MODE" 2>/dev/null)" = host ] && break
    if [ -e "$PSY" ]; then
        g=$((g + 1))
        [ $g -gt 3 ] && break
    fi
    sleep 1
    n=$((n + 1))
done
role=$(cat "$GLUE_MODE" 2>/dev/null)
typec=$(ls /sys/class/typec 2>/dev/null | tr '\n' ' ')
if [ -e "$UDC" ]; then
    echo "usb-moded-configfs-setup: UDC a600000.dwc3 present after $n s without a mode write (glue mode '$role'; typec: $typec)" >&2
elif [ "$role" = host ]; then
    echo "usb-moded-configfs-setup: glue in host mode (OTG device attached); not forcing peripheral" >&2
else
    echo "usb-moded-configfs-setup: no UDC a600000.dwc3 after $n s (glue mode '$role'; typec: $typec); writing peripheral to $GLUE_MODE (bring-up fallback)" >&2
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

# usb-moded picks its charger device once at startup and ignores later "add"
# events. If /sys/class/power_supply/usb is missing then, it guesses another
# supply (ucsi_glink's ucsi-source-psy reports TYPE=USB for any partner, so
# a wall charger would look like a PC), or, when none qualifies (both come
# with the ADSP), exits; usb-moded.service.d/51-pdx246-retry.conf restarts it
# every 5 s. Wait for it.
n=0
while [ ! -e "$PSY" ] && [ $n -lt 30 ]; do
    sleep 1
    n=$((n + 1))
done
[ -e "$PSY" ] || echo "usb-moded-configfs-setup: no $PSY after 30 s; with extcon tracking off usb-moded exits ('no charger device found') and retries every 5 s until it appears" >&2

exit 0
