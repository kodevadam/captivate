#!/bin/sh
# Remove the captive gate and restore normal autologin.
#
#   sudo sh uninstall.sh
set -u

SESSION_NAME="captive-xfce"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo sh uninstall.sh" >&2
    exit 1
fi

# Restore the oldest (pristine) backup taken by install.sh, if any.
backup="$(ls -1tr "${LIGHTDM_CONF}".captive.bak.* 2>/dev/null | head -n1 || true)"
if [ -n "${backup}" ] && [ -f "${backup}" ]; then
    cp -a "${backup}" "${LIGHTDM_CONF}"
    echo ">> Restored ${LIGHTDM_CONF} from ${backup}"
elif grep -q "^autologin-session=${SESSION_NAME}" "${LIGHTDM_CONF}" 2>/dev/null; then
    sed -i "s/^autologin-session=${SESSION_NAME}.*/autologin-session=xfce/" "${LIGHTDM_CONF}"
    echo ">> No backup found; set autologin-session=xfce"
fi

rm -f /usr/local/bin/captive-gate /usr/local/bin/captive-session
rm -f "/usr/share/xsessions/${SESSION_NAME}.desktop"
echo ">> Removed gate, session wrapper, and xsession entry."
echo ">> Reboot to return to your normal desktop:  sudo reboot"
