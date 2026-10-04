#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
#
# Pre-flight check for flashing Sailfish OS on the Sony Xperia 10 VI (pdx246).
# flash.sh runs it (flash-config.sh: "run ./flash-preflight.sh") after
# "fastboot --set-active=a" and "fastboot reboot fastboot", before anything is
# written. It can also be run by hand with the phone in fastbootd.
#
# It exits 1, and so stops flash.sh, unless fastbootd reports:
#   is-userspace              yes   the phone is in fastbootd, not the bootloader
#   current-slot              a     fastbootd looks up logical partitions in the
#                                   super metadata of the current slot
#   snapshot-update-status    none  no Virtual A/B merge is pending (fastbootd
#                                   refuses userdata during a merge, but only
#                                   after vendor_dlkm_a has been written)
#   is-logical:vendor_dlkm_a  yes   slot a holds the LineageOS dynamic partitions
# The checks run in fastbootd because the Sony bootloader fails many getvar
# names.
#
# fastboot binary: $FASTBOOT_BIN_NAME if set (flash.sh passes it in the
# environment when it re-runs itself with sudo), else "fastboot" from PATH.
# With more than one fastboot device connected, set ANDROID_SERIAL.

FB=${FASTBOOT_BIN_NAME:-fastboot}
case $FB in
    */*) ;;
    *)
        if ! command -v "$FB" >/dev/null 2>&1 && [ -x "./$FB" ]; then
            FB=./$FB
        fi
        ;;
esac

fail() {
    echo
    echo "PRE-FLIGHT CHECK FAILED: $1"
    shift
    for line in "$@"; do
        echo "$line"
    done
    echo
    echo "No partition has been written (flash.sh only made slot a active). Once"
    echo "the above is fixed, return to the bootloader ('fastboot reboot"
    echo "bootloader', or power off and hold volume up while plugging in USB) and"
    echo "start ./flash.sh again."
    echo
    exit 1
}

if ! command -v "$FB" >/dev/null 2>&1; then
    fail "fastboot binary '$FB' not found." \
         "Put fastboot in PATH or set FASTBOOT_BIN_NAME to its path."
fi

if [ -z "$ANDROID_SERIAL" ]; then
    n=$("$FB" devices 2>/dev/null | grep -c .)
    if [ "$n" -ne 1 ]; then
        fail "$n fastboot devices are connected." \
             "Connect only the phone, or set ANDROID_SERIAL to its serial number."
    fi
fi

# Value of a fastboot variable ("<name>: <value>" on stderr), empty on failure.
getvar() {
    "$FB" getvar "$1" 2>&1 | sed -n "s/^$1: *//p" | head -n 1 | tr -d '\r'
}

v=$(getvar is-userspace)
echo "<< is-userspace: $v"
if [ "$v" != "yes" ]; then
    fail "the phone is not in fastbootd (is-userspace: '$v')." \
         "From the bootloader, 'fastboot reboot fastboot' must reach the" \
         "fastbootd screen of the LineageOS recovery. If it does not (for" \
         "example when re-flashing over Sailfish OS), flash the saved LineageOS" \
         "boot_a, vendor_boot_a and dtbo_a from the bootloader first" \
         "(flashing-README.txt)."
fi

v=$(getvar current-slot)
echo "<< current-slot: $v"
if [ "$v" != "a" ]; then
    fail "fastbootd runs from slot '$v', not slot a." \
         "In the bootloader, run 'fastboot --set-active=a', then" \
         "'fastboot reboot fastboot', and check again."
fi

v=$(getvar snapshot-update-status)
echo "<< snapshot-update-status: $v"
if [ "$v" != "none" ]; then
    fail "a Virtual A/B update is not finished (snapshot-update-status: '$v')." \
         "Run 'fastboot reboot' to start LineageOS from slot a, wait at the home" \
         "screen for a minute so that the merge completes, then power off and" \
         "start again from the bootloader."
fi

v=$(getvar is-logical:vendor_dlkm_a)
echo "<< is-logical:vendor_dlkm_a: $v"
if [ "$v" != "yes" ]; then
    fail "vendor_dlkm_a is not a logical partition of slot a ('$v')." \
         "Slot a does not hold a complete LineageOS 23.2 install. Install" \
         "LineageOS to slot a, boot it once to the home screen and wait a" \
         "minute, then start again from the bootloader."
fi

echo "Pre-flight check passed: fastbootd on slot a, no pending merge, vendor_dlkm_a present."
exit 0
