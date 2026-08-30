#!/bin/sh
# Removes the multi-second delay sudo/login show after a wrong password.
#
# Root cause: pam_unix.so has a built-in ~2s minimum delay on auth failure
# (anti-timing-attack / anti-bruteforce). Nothing on a stock Arch install
# overrides it, so sudo eats that full delay on every wrong attempt
# (verified: several seconds of wall time, ~nothing of CPU time -> it's
# just sleeping). This installs a system-auth that disables pam_unix's
# delay ("nodelay") and pins an explicit, shorter one via pam_faildelay.so
# instead. pam_faillock's lockout-after-3-failures protection is untouched.
#
# Must be run with root privileges (asks for sudo itself). Takes a backup
# of the current file before touching anything.

set -e

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
SRC="$BASEDIR/etc/pam.d/system-auth"
DST="/etc/pam.d/system-auth"

if [ ! -f "$SRC" ]; then
    echo "error: $SRC not found" >&2
    exit 1
fi

if diff -q "$SRC" "$DST" >/dev/null 2>&1; then
    echo "already applied, nothing to do"
    exit 0
fi

BACKUP="${DST}.bak-$(date +%Y%m%d%H%M%S)"
echo "backing up $DST -> $BACKUP"
sudo cp "$DST" "$BACKUP"

echo "installing $SRC -> $DST"
sudo install -m 644 -o root -g root "$SRC" "$DST"

echo "done. Test with: sudo -k; sudo true (enter a wrong password on purpose)"
echo "to revert: sudo cp $BACKUP $DST"
