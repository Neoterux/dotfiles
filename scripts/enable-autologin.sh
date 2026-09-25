#!/bin/sh
# Enables autologin on tty1 by installing
# etc/systemd/system/getty@tty1.service.d/autologin.conf.
#
# This is only safe together with the v3 Hyprland session lock: the machine
# profile needs `session.lock_on_start: true` (see
# v3/hypr/hyprland-neo/machines/README.md), so the desktop comes up behind
# hyprlock and the password is asked there instead. The hyprlock password
# also unlocks the GNOME keyring through PAM.
#
# Must be run with root privileges (asks for sudo itself). Only takes effect
# on the next boot: restarting getty@tty1 now would kill a session running on
# tty1.

set -e

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
SRC="$BASEDIR/etc/systemd/system/getty@tty1.service.d/autologin.conf"
DST="/etc/systemd/system/getty@tty1.service.d/autologin.conf"

if [ ! -f "$SRC" ]; then
    echo "error: $SRC not found" >&2
    exit 1
fi

if diff -q "$SRC" "$DST" >/dev/null 2>&1; then
    echo "already applied, nothing to do"
    exit 0
fi

echo "installing $SRC -> $DST"
sudo install -D -m 644 -o root -g root "$SRC" "$DST"
sudo systemctl daemon-reload

echo "done. Active from the next boot."
echo "to revert: sudo rm $DST && sudo systemctl daemon-reload"
