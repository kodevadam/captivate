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
SETCLOCK_BIN="/usr/local/bin/captive-setclock"
XSESSION="/usr/share/xsessions/${SESSION_NAME}.desktop"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
XORG_SEAL="/etc/X11/xorg.conf.d/10-captive-seal.conf"
SUDOERS="/etc/sudoers.d/captive"
SRC="$(cd "$(dirname "$0")" && pwd)"

# --seal also disables VT switching (Ctrl+Alt+F-keys) and Ctrl+Alt+Backspace
# for the whole X session. Off by default because it removes the TTY escape
# hatch (see warning below).
SEAL=0
for arg in "$@"; do
    case "$arg" in
        --seal|--lockdown) SEAL=1 ;;
        *) echo "Unknown option: $arg (use --seal to disable VT switching)" >&2; exit 1 ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo sh install.sh [--seal]" >&2
    exit 1
fi

echo ">> Installing dependencies: tk (wish), sudo"
xbps-install -Sy tk sudo

echo ">> Installing gate            -> ${GATE_BIN}"
install -Dm755 "${SRC}/gate.tcl" "${GATE_BIN}"

echo ">> Installing clock helper    -> ${SETCLOCK_BIN}"
install -Dm755 -o root -g root "${SRC}/captive-setclock.sh" "${SETCLOCK_BIN}"

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

if [ "${SEAL}" -eq 1 ]; then
    echo ">> Sealing VT switching       -> ${XORG_SEAL}"
    mkdir -p /etc/X11/xorg.conf.d
    cat > "${XORG_SEAL}" <<'CONF'
Section "ServerFlags"
    Option "DontVTSwitch" "on"
    Option "DontZap"      "on"
EndSection
CONF
    echo "!! WARNING: VT switching is now DISABLED for the ENTIRE X session,"
    echo "!! including the desktop. If the gate ever breaks you CANNOT reach a"
    echo "!! TTY. Recovery then requires SSH, or mounting the SD card on another"
    echo "!! machine to delete ${XORG_SEAL} and rerun uninstall.sh."
fi

user="$(grep -E '^autologin-user=' "${LIGHTDM_CONF}" | head -n1 | cut -d= -f2 || true)"
if [ -z "${user}" ]; then
    echo "!! WARNING: autologin-user is not set in ${LIGHTDM_CONF}."
    echo "   Add it under [Seat:*], e.g.  autologin-user=youruser"
    echo "!! Without it the gate cannot be granted permission to set the clock."
else
    echo ">> Autologin user: ${user}"
    # Grant exactly one privileged command, password-free, so the gate (running
    # as this user) can set the system clock.
    tmp="$(mktemp)"
    printf '%s ALL=(root) NOPASSWD: %s\n' "${user}" "${SETCLOCK_BIN}" > "${tmp}"
    if visudo -cf "${tmp}" >/dev/null 2>&1; then
        install -m 0440 -o root -g root "${tmp}" "${SUDOERS}"
        echo ">> Installed sudoers rule     -> ${SUDOERS}"
    else
        echo "!! Generated sudoers rule failed visudo validation; not installed." >&2
        echo "!! The gate will not be able to set the clock until this is fixed." >&2
    fi
    rm -f "${tmp}"
fi

echo
echo "Done. autologin-session is now '${SESSION_NAME}'."
echo "Reboot to apply:  sudo reboot"
echo
if [ "${SEAL}" -eq 1 ]; then
    echo "Sealed mode: no TTY escape hatch. Make sure SSH works before rebooting."
else
    echo "Escape hatch if anything goes wrong: switch to a text console with"
    echo "Ctrl+Alt+F2, log in, and run:  sudo sh ${SRC}/uninstall.sh"
    echo "(Run with --seal to also disable VT switching.)"
fi
