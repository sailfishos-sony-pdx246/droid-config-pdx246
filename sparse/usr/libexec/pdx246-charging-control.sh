#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
#
# Copy mce's charging decision to Sony's SmartCharge node.
#
# mce writes 0 (allow charging) or 1 (suspend it) to /run/pdx246-charging-control
# (/etc/mce/70-battery-pdx246.ini) when its decision changes, and only then.
# Run by pdx246-charging-control.path (mce wrote) and by
# pdx246-charging-control.timer (3 min after boot, then 10 min after the last
# run). Sony's somc_battchg_ext driver:
# - registers the battchg_ext class only when its pmic_glink device probes
#   after the ADSP is up, seconds after mce's one check of ControlPath, so the
#   first run waits for the node (at most until 180 s after boot);
# - ignores interruption writes, while reporting success, until
#   smart_charging_activation is 1. droid-hal-init writes that "on boot"
#   (init.target.rc) but waits at most 5 s for the node, so write it here as
#   well (it only sets a flag);
# - resumes charging 30 min after the last write of 1
#   (SMART_CHARGE_WDOG_DELAY_MS). Writing 1 again re-arms that watchdog and
#   changes nothing else (an equal vote is not sent again), so 1 is rewritten
#   on every run.
# mce leaves the file as it is when it stops. Without a running mce the file
# is not followed to 1: a stale 1 must not keep charging suspended.

PATH=/usr/sbin:/usr/bin:/sbin:/bin
SRC=/run/pdx246-charging-control
SYS=/sys/class/battchg_ext
NODE=$SYS/smart_charging_interruption
ACT=$SYS/smart_charging_activation

while [ ! -e "$NODE" ]; do
    up=$(cut -d. -f1 /proc/uptime)
    if [ "${up:-999}" -ge 180 ]; then
        echo "$NODE does not exist, mce's decision not applied" >&2
        exit 0
    fi
    sleep 1
done

act=
read -r act < "$ACT"
if [ "$act" != 1 ]; then
    if echo 1 > "$ACT"; then
        echo "smart_charging_activation: $act -> 1"
    else
        echo "cannot write 1 to $ACT" >&2
    fi
fi

note=
mce=active
systemctl -q is-active mce.service || mce=inactive

# A start request that arrives while this runs is merged into this run, so
# read the file again after each write until it stays the same.
applied=
n=0
while [ $n -lt 10 ]; do
    want=
    read -r want < "$SRC" || :
    case $want in
        0|1) ;;
        *) echo "$SRC holds '$want', not 0 or 1; node left as it is" >&2
           exit 0 ;;
    esac
    if [ "$want" = 1 ] && [ $mce != active ]; then
        want=0
        note=" (mce is not running)"
    fi
    [ "$want" = "$applied" ] && exit 0
    cur=
    read -r cur < "$NODE" || :
    if [ "$want" = 1 ] || [ "$cur" != 0 ]; then
        if echo "$want" > "$NODE"; then
            [ "$cur" = "$want" ] ||
                echo "smart_charging_interruption: $cur -> $want$note"
        else
            echo "cannot write $want to $NODE" >&2
        fi
    fi
    applied=$want
    n=$((n + 1))
done
exit 0
