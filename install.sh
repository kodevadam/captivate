#!/bin/sh
# Installer for the captive time/date gate on an autologin Void + XFCE + LightDM
# machine (tested target: Raspberry Pi 400, aarch64).
#
#   sudo sh install.sh
#
# This points LightDM's autologin at a custom session that runs the gate before
# XFCE. Your existing autologin-user is left untouched.
set -eu

SESSION_NAME="captive-xfce"
GATE_BIN="/usr/local/bin/captive-gate"
SESSION_BIN="/usr/local/bin/captive-session"
XSESSION="/usr/share/xsessions/${SESSION_NAME}.desktop"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
SRC="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo sh install.sh" >&2
    exit 1
fi

echo ">> Installing dependency: tk (provides wish)"
xbps-install -Sy tk

echo ">> Installing gate            -> ${GATE_BIN}"
install -Dm755 "${SRC}/gate.tcl" "${GATE_BIN}"

echo ">> Installing session wrapper -> ${SESSION_BIN}"
install -Dm755 "${SRC}/captive-session.sh" "${SESSION_BIN}"

echo ">> Installing xsession entry  -> ${XSESSION}"
install -Dm644 "${SRC}/captive-xfce.desktop" "${XSESSION}"

if [ ! -f "${LIGHTDM_CONF}" ]; then
    echo "!! ${LIGHTDM_CONF} not found. Is LightDM installed?" >&2
    exit 1
fi

backup="${LIGHTDM_CONF}.captive.bak.$(date +%s)"
cp -a "${LIGHTDM_CONF}" "${backup}"
echo ">> Backed up LightDM config   -> ${backup}"

# Anchor our key under a [Seat:*] section.
if ! grep -q '^\[Seat:\*\]' "${LIGHTDM_CONF}"; then
    printf '\n[Seat:*]\n' >> "${LIGHTDM_CONF}"
fi

if grep -q '^autologin-session=' "${LIGHTDM_CONF}"; then
    sed -i "s/^autologin-session=.*/autologin-session=${SESSION_NAME}/" "${LIGHTDM_CONF}"
elif grep -q '^#autologin-session=' "${LIGHTDM_CONF}"; then
    sed -i "s/^#autologin-session=.*/autologin-session=${SESSION_NAME}/" "${LIGHTDM_CONF}"
else
    sed -i "/^\[Seat:\*\]/a autologin-session=${SESSION_NAME}" "${LIGHTDM_CONF}"
fi

user="$(grep -E '^autologin-user=' "${LIGHTDM_CONF}" | head -n1 | cut -d= -f2 || true)"
if [ -z "${user}" ]; then
    echo "!! WARNING: autologin-user is not set in ${LIGHTDM_CONF}."
    echo "   Add it under [Seat:*], e.g.  autologin-user=youruser"
else
    echo ">> Autologin user: ${user}"
fi

echo
echo "Done. autologin-session is now '${SESSION_NAME}'."
echo "Reboot to apply:  sudo reboot"
echo
echo "Escape hatch if anything goes wrong: switch to a text console with"
echo "Ctrl+Alt+F2, log in, and run:  sudo sh ${SRC}/uninstall.sh"
