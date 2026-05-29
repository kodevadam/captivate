#!/bin/sh
# Set the system clock from a "YYYY-MM-DD HH:MM:SS" string supplied by the
# captive gate. Invoked via sudo (NOPASSWD) by the autologin user, so the
# argument is strictly whitelisted before use: this script accepts nothing but
# a fully-formed timestamp and runs nothing but `date -s`.
set -eu

ts="${1:-}"
case "$ts" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]:[0-9][0-9]) ;;
    *) echo "captive-setclock: refusing malformed timestamp" >&2; exit 1 ;;
esac

# No RTC to write back to; just set the running clock. date itself rejects
# impossible dates (e.g. 2026-02-30), which surfaces as an error in the gate.
date -s "$ts"
