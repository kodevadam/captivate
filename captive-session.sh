#!/bin/sh
# Captive gate session. LightDM autologins straight into this instead of XFCE.
# The gate must be passed before XFCE starts. No window manager runs until the
# gate exits 0, so there is nothing to escape to. If the gate dies for any
# reason (crash, kill) it is simply relaunched, so it cannot be bypassed.

GATE=/usr/local/bin/captive-gate

while :; do
    "$GATE" && break
    sleep 1
done

exec startxfce4
