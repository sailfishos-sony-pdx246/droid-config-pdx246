#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
#
# Map the logical partitions of the "super" partition with device-mapper, as
# Android's first-stage init would. Without it there is no /system, /vendor,
# /vendor_dlkm, /odm, /product or /system_ext under Sailfish OS.
#
# parse-android-dynparts reads metadata slot 0 (slot a) and prints a
# "dmsetup create --concise" table for every logical partition, named
# dynpart-<partition> (so dynpart-vendor_a, ...). The mount units in
# /usr/lib/systemd/system mount the _a ones.
#
# Run by dmsetup-dynparts.service once udev has created
# /dev/disk/by-partlabel/super. /dev/sda95 (super on pdx246's stock GPT, checked
# on the phone 2026-10-04) is only a fallback.

PATH=/usr/sbin:/usr/bin:/sbin:/bin

SUPER=/dev/disk/by-partlabel/super
FALLBACK=/dev/sda95

log() {
    echo "dmsetup-dynparts: $*"
}

if [ ! -b "$SUPER" ]; then
    log "$SUPER missing, using $FALLBACK"
    SUPER=$FALLBACK
fi

if [ ! -b "$SUPER" ]; then
    log "no super block device found"
    exit 1
fi

# Idempotent: a restarted service must not try to create the devices again.
if dmsetup info dynpart-system_a >/dev/null 2>&1; then
    log "dynamic partitions already mapped"
    exit 0
fi

TABLE="$(parse-android-dynparts "$SUPER")"
if [ -z "$TABLE" ]; then
    log "parse-android-dynparts found no partitions on $SUPER"
    exit 1
fi

dmsetup create --concise "$TABLE" || exit 1

# Fail loudly if slot a is not complete; the mount units would only time out.
missing=
for p in system system_ext product vendor vendor_dlkm odm; do
    dmsetup info "dynpart-${p}_a" >/dev/null 2>&1 || missing="$missing ${p}_a"
done
if [ -n "$missing" ]; then
    log "missing in super (slot a):$missing"
    exit 1
fi

log "mapped the logical partitions of $SUPER"
exit 0
