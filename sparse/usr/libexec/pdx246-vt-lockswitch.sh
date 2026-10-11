#!/bin/sh
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: GPL-2.0-only
#
# Lock VT switching once the user session owns the console (NOTES D27).
# Locking earlier keeps the console on tty1: the session's own switch to its
# VT (7) then fails and seat0 has no active session (seen on the first boot
# with the lock, 2026-10-10). So wait for seat0's active session, at most
# 120 s; without one, leave switching unlocked (suspend then only stays awake
# ~2 s longer after resumes, as before).
# VT_LOCKSWITCH = 0x560B (include/uapi/linux/vt.h).

PATH=/usr/sbin:/usr/bin:/sbin:/bin
i=0
while [ $i -lt 120 ]; do
    s=$(loginctl show-seat seat0 -p ActiveSession --value 2>/dev/null)
    if [ -n "$s" ]; then
        if python3 -I -c "import fcntl, os; fcntl.ioctl(os.open('/dev/tty0', os.O_RDWR | os.O_NOCTTY), 0x560B)"; then
            echo "VT switching locked (seat0 session $s on $(cat /sys/class/tty/tty0/active))"
            exit 0
        fi
        echo "VT_LOCKSWITCH failed" >&2
        exit 0
    fi
    i=$((i + 1))
    sleep 1
done
echo "no active seat0 session after 120 s; VT switching left unlocked" >&2
exit 0
