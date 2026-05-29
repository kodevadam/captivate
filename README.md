# captivate

A manual clock-set gate for an autologin **Void Linux + XFCE + LightDM**
machine with **no RTC and no network** (built and tested target: a Raspberry
Pi 400, aarch64).

The Pi 400 has no battery-backed clock, and this box runs offline, so it has no
way to know the time on its own. Before the desktop appears, a fullscreen
prompt asks the human to type the current date and time. Whatever you enter
**becomes the system clock**, then XFCE starts. You can't get to the desktop
without setting it.

## How it works

The gate **is** the X session, so it runs before anything else:

1. LightDM autologins into a custom session, `captive-xfce`, instead of XFCE.
2. That session runs `captive-session.sh`, which launches the gate
   (`gate.tcl`, a Tcl/Tk app) **with no window manager running** — so there is
   nothing to alt-tab to.
3. The gate is fullscreen, `overrideredirect` (no titlebar, can't be closed),
   and takes a global input grab. It asks for the date and time.
4. On a valid entry it sets the system **timezone and clock** (via a small root
   helper, `captive-setclock`, allowed through a tightly-scoped NOPASSWD sudo
   rule) and exits `0`; the wrapper then `exec`s `startxfce4`. If the gate is
   killed or crashes, the wrapper relaunches it, so it can't be bypassed.

It does **not** validate your entry against the existing clock — that clock is
meaningless, which is the whole reason this exists. It only rejects *impossible*
values (e.g. `25:99`, `2026-02-30`). The time is interpreted in the timezone you
pick and the system is switched to that zone, so what you type is what shows.

## Requirements

Already true on a normal autologin XFCE box:

- LightDM with `autologin-user=` set in `/etc/lightdm/lightdm.conf`.
- XFCE installed (`startxfce4` on `PATH`).

Installed for you by `install.sh`: `tk` (the `wish` interpreter), `sudo`, and
`tzdata` (timezone database). The installer needs to fetch those once, so run it
with network available, even though the gate itself runs fully offline
afterwards.

## Install

```sh
git clone https://github.com/kodevadam/captivate.git
cd captivate
sudo sh install.sh
sudo reboot
```

`install.sh` must be run from inside the cloned directory — it copies the gate
and session files from alongside itself. It will:

- install `tk` and `sudo`,
- copy the gate to `/usr/local/bin/captive-gate`,
- copy the clock helper to `/usr/local/bin/captive-setclock` (root-owned),
- copy the session wrapper to `/usr/local/bin/captive-session`,
- install the session entry `/usr/share/xsessions/captive-xfce.desktop`,
- write `/etc/sudoers.d/captive` granting the autologin user permission to run
  **only** `captive-setclock` without a password (validated with `visudo`),
- back up `lightdm.conf` and set `autologin-session=captive-xfce`
  (your `autologin-user` is left untouched).

## Using the gate

Enter, then press Enter or click **Set clock & continue**:

- **Date** — `YYYY-MM-DD`, zero-padded (e.g. `2026-05-29`).
- **Time** — strictly **24-hour** `HH:MM`, `00:00`–`23:59` (e.g. `13:30`;
  `13.30` is also accepted). 12-hour / am-pm input is rejected — 1:30 PM is
  `13:30`.
- **Timezone** — a dropdown, **defaulting to Japan** (Asia/Tokyo). The time you
  type is interpreted in this zone and the system is switched to it, so the
  wall time you enter is exactly what the desktop shows — no offset.

Any real date/time is accepted and becomes the clock. There is no "correct"
answer to guess and no tolerance window — you are *setting* the time, not
proving you know it.

To change the dropdown list or default, edit the `ZONES` table at the top of
`gate.tcl` (first entry is the default).

**Escape hatch:** press **Ctrl+Alt+Esc** at the gate to skip straight into a
normal XFCE session without setting the clock. Because the desktop autologins,
no password is needed. This works even in `--seal` mode (it's handled inside
the gate, not by the X server), so it's your way back in if something's off.

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
> breaks, recovery requires mounting the SD card on another machine (this box
> has no network for SSH). Don't use `--seal` until you've confirmed the gate
> works.

## A note on VTs (not a bug)

When the gate is up, *it is* your graphical X session — XFCE does not exist as
a running session until the gate exits. So `Ctrl+Alt+F7` shows the gate, not a
desktop, and `Ctrl+Alt+F2` switches to a spare *text* console. There is no
separate desktop VT to find; to reach XFCE, either set the clock or press
**Ctrl+Alt+Esc** to skip to it.

## Recovery / uninstall

Normal install — drop to a console and revert:

```sh
# Ctrl+Alt+F2, log in, then:
cd ~/captivate
sudo sh uninstall.sh
sudo reboot
```

`uninstall.sh` restores the original `lightdm.conf` from the backup and removes
the gate, clock helper, sudoers rule, xsession entry, and the seal config (if
present).

If you used `--seal` and the gate is broken, mount the SD card on another
machine and delete `/etc/X11/xorg.conf.d/10-captive-seal.conf` (and reset
`autologin-session=` in `lightdm.conf`).

## Files

| File | Installed to | Purpose |
|------|--------------|---------|
| `gate.tcl` | `/usr/local/bin/captive-gate` | the Tcl/Tk gate |
| `captive-setclock.sh` | `/usr/local/bin/captive-setclock` | root helper that sets the timezone + clock (inputs whitelisted) |
| `captive-session.sh` | `/usr/local/bin/captive-session` | session wrapper that gates XFCE |
| `captive-xfce.desktop` | `/usr/share/xsessions/captive-xfce.desktop` | LightDM session entry |
| `install.sh` | — | installer (`--seal` for full lockdown) |
| `uninstall.sh` | — | revert everything |

## Caveat

The Tk window has only been smoke-tested for its date/time logic, not run on a
real display by the author. **Do your first reboot when you can reach a TTY**,
and don't use `--seal` until you've confirmed the gate works.
