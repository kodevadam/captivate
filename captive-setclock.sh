#!/bin/sh
# Set the system timezone and clock from values supplied by the captive gate.
# Invoked via sudo (NOPASSWD) by the autologin user, so both arguments are
# strictly validated before use: this script accepts only a known-good zoneinfo
# name and a fully-formed timestamp, and runs nothing but `ln`/`date`.
#
# Usage: captive-setclock <Zone/Name> "YYYY-MM-DD HH:MM:SS"
set -eu

zone="${1:-}"
ts="${2:-}"

# Zone: reject traversal/absolute paths and anything outside a strict charset,
# then require the zoneinfo file to actually exist.
case "$zone" in
    *..*|/*|*/|"") echo "captive-setclock: bad timezone" >&2; exit 1 ;;
    *[!A-Za-z0-9_/+-]*) echo "captive-setclock: bad timezone" >&2; exit 1 ;;
esac
if [ ! -f "/usr/share/zoneinfo/${zone}" ]; then
    echo "captive-setclock: unknown timezone: ${zone}" >&2
    exit 1
fi

# Timestamp: exact YYYY-MM-DD HH:MM:SS shape only.
case "$ts" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]:[0-9][0-9]) ;;
    *) echo "captive-setclock: refusing malformed timestamp" >&2; exit 1 ;;
esac

# Point the system at the chosen zone first, so the typed wall time is parsed
# and displayed in the same zone (no offset). Then set the clock; with TZ unset
# and /etc/localtime now correct, date interprets the input in that zone. There
# is no RTC to write back to. date itself rejects impossible dates.
ln -sf "/usr/share/zoneinfo/${zone}" /etc/localtime
unset TZ
date -s "$ts"
