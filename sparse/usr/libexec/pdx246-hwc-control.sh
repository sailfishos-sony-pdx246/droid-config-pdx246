#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: GPL-2.0-only
#
# Start, stop or restart Android's display composer for mce's compositor
# handover (/etc/mce/60-compositor-pdx246.ini). The encryption unlock screen
# draws with DRM/KMS and needs the composer gone, because the composer holds
# DRM master; Lipstick needs it running.
#
# droid-hal-init (hybris) accepts ctl.stop and ctl.restart but sends no signal
# (KillProcessGroup is compiled out), so the service would stay alive in
# "stopping". After asking init, end the process here, as init would on
# Android: init then reaps it and, for a restart, starts it again and runs its
# onrestart actions. mce waits for this script before it lets the next UI draw.

PATH=/usr/sbin:/usr/bin:/sbin:/bin
SVC=vendor.qti.hardware.display.composer

# Wait up to 10 s until init reports state $1, with a pid other than $2 if
# given (init restarts a service at the earliest 5 s after its last start).
wait_state() {
    n=0
    while [ $n -lt 100 ]; do
        if [ "$(getprop init.svc.$SVC)" = "$1" ]; then
            [ -z "$2" ] && return 0
            pid=$(getprop init.svc_debug_pid.$SVC)
            [ -n "$pid" ] && [ "$pid" != "$2" ] && return 0
        fi
        sleep 0.1
        n=$((n + 1))
    done
    echo "$SVC is not $1 after 10 s" >&2
    return 1
}

case "$1" in
start)
    setprop ctl.start $SVC
    wait_state running
    ;;
stop|restart)
    old=$(getprop init.svc_debug_pid.$SVC)
    setprop ctl.$1 $SVC
    # init made the service its own process group leader.
    if [ -n "$old" ] && grep -q composer-service /proc/$old/cmdline 2>/dev/null; then
        kill -KILL -$old 2>/dev/null || kill -KILL $old
    fi
    if [ "$1" = stop ]; then
        wait_state stopped
    else
        wait_state running "$old"
    fi
    ;;
*)
    echo "usage: $0 start|stop|restart" >&2
    exit 2
    ;;
esac
