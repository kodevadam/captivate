# captivate

An inescapable time/date gate for an autologin **Void Linux + XFCE + LightDM**
machine (built and tested target: a Raspberry Pi 400, aarch64).

Before the desktop appears, a fullscreen prompt demands the **current date and
time**. Type it correctly and XFCE starts; get it wrong and the prompt stays
up. There is no way out of it from the GUI.

## How it works

Instead of an autostart entry that races the panel (and is trivial to escape),
the gate **is** the X session:

1. LightDM autologins into a custom session, `captive-xfce`, instead of XFCE.
2. That session runs `captive-session.sh`, which launches the gate
   (`gate.tcl`, a Tcl/Tk app) **with no window manager running** — so there is
   nothing to alt-tab to.
3. The gate is fullscreen, `overrideredirect` (no titlebar, can't be closed),
   and takes a global input grab. It asks for the date and time.
4. Only a correct answer exits the gate `0`; the wrapper then `exec`s
   `startxfce4`. If the gate is killed or crashes, the wrapper just relaunches
   it, so it can't be bypassed.

## Requirements

These are already true on a normal autologin XFCE box:

- LightDM with `autologin-user=` set in `/etc/lightdm/lightdm.conf`.
- XFCE installed (`startxfce4` on `PATH`).
- Internet access during install (to fetch the one dependency, `tk`).

## Install

On the Pi:

```sh
git clone https://github.com/kodevadam/captivate.git
cd captivate
sudo sh install.sh
sudo reboot
```

`install.sh` must be run from inside the cloned directory — it copies
`gate.tcl` and the session files from alongside itself. It will:

- install `tk` via `xbps-install`,
- copy the gate to `/usr/local/bin/captive-gate`,
- copy the session wrapper to `/usr/local/bin/captive-session`,
- install the session entry `/usr/share/xsessions/captive-xfce.desktop`,
- back up `lightdm.conf` and set `autologin-session=captive-xfce`
  (your `autologin-user` is left untouched).

After reboot you'll get the gate before the desktop.

## Using the gate

Enter, then press Enter or click **Unlock**:

- **Date** — `YYYY-MM-DD`, zero-padded (e.g. `2026-05-28`).
- **Time** — 24-hour `HH:MM` (e.g. `14:05`). Accepted within **3 minutes** of
  the real clock, so reading a watch and typing won't fail you.

## Full lockdown (optional)

By default you can still reach a text console with **Ctrl+Alt+F2** — your
escape hatch. To seal that too:

```sh
sudo sh install.sh --seal
```

This drops `/etc/X11/xorg.conf.d/10-captive-seal.conf` with `DontVTSwitch` and
`DontZap`, disabling VT switching and Ctrl+Alt+Backspace for the **entire** X
session (desktop included).

> **Warning:** with `--seal` there is no TTY escape hatch. If the gate ever
> breaks, recovery requires SSH or mounting the SD card on another machine.
> **Enable and verify SSH before rebooting into sealed mode.**

## Recovery / uninstall

Normal install — drop to a console and revert:

```sh
# Ctrl+Alt+F2, log in, then:
sudo sh uninstall.sh
sudo reboot
```

`uninstall.sh` restores the original `lightdm.conf` from the backup, removes the
gate, session wrapper, xsession entry, and the seal config (if present).

If you used `--seal` and the gate is broken, either SSH in and run
`uninstall.sh`, or mount the SD card on another machine and delete
`/etc/X11/xorg.conf.d/10-captive-seal.conf` (and reset `autologin-session=` in
`lightdm.conf`).

## Configuration

- **Time tolerance:** edit `TOLERANCE_MIN` at the top of `gate.tcl`
  (then reinstall, or edit `/usr/local/bin/captive-gate` in place).

## Files

| File | Installed to | Purpose |
|------|--------------|---------|
| `gate.tcl` | `/usr/local/bin/captive-gate` | the Tcl/Tk gate |
| `captive-session.sh` | `/usr/local/bin/captive-session` | session wrapper that gates XFCE |
| `captive-xfce.desktop` | `/usr/share/xsessions/captive-xfce.desktop` | LightDM session entry |
| `install.sh` | — | installer (`--seal` for full lockdown) |
| `uninstall.sh` | — | revert everything |

## Caveat

The Tk window has only been smoke-tested for its date/time logic, not run on a
real display by the author. **Do your first reboot when you can reach a TTY**,
and don't use `--seal` until you've confirmed the gate works and SSH is up.
