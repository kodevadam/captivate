#!/usr/bin/env wish
# Captive clock-set gate for an autologin XFCE session.
#
# The target machine has no RTC and no network, so it cannot know the time on
# its own. This gate runs fullscreen before the desktop and asks the human to
# pick a timezone and type the current date and time; that becomes the system
# clock and timezone, then XFCE starts. It does NOT validate against the
# existing clock (there is nothing trustworthy to validate against). The time
# you type is interpreted in the timezone you pick, so it shows unchanged on
# the desktop.
#
# The window is override-redirect (no titlebar, can't be closed), runs with no
# window manager, and takes a global input grab, so there is nothing to switch
# away to. Setting the clock needs root, which comes from a NOPASSWD sudo rule
# scoped to /usr/local/bin/captive-setclock (installed by install.sh).

package require Tk

set BG  "#101216"
set FG  "#e6e6e6"
set DIM "#9aa0a6"
set ERR "#ff6b6b"

# Friendly label -> zoneinfo name. First entry is the default selection.
set ZONES {
    "Japan"           "Asia/Tokyo"
    "Korea"           "Asia/Seoul"
    "China"           "Asia/Shanghai"
    "India"           "Asia/Kolkata"
    "UTC"             "UTC"
    "UK"              "Europe/London"
    "Central Europe"  "Europe/Paris"
    "US Eastern"      "America/New_York"
    "US Central"      "America/Chicago"
    "US Mountain"     "America/Denver"
    "US Pacific"      "America/Los_Angeles"
    "Australia East"  "Australia/Sydney"
}
set tzlabel [lindex $ZONES 0]

# --- window ---------------------------------------------------------------
wm overrideredirect . 1
wm geometry . "[winfo screenwidth .]x[winfo screenheight .]+0+0"
. configure -bg $BG -cursor left_ptr
raise .

# --- widgets --------------------------------------------------------------
frame .c -bg $BG
place .c -relx 0.5 -rely 0.5 -anchor center

label .c.title -text "Set the current date and time to continue" \
    -bg $BG -fg $FG -font {Sans 24 bold}
label .c.hint  -text "This sets the system clock. Time is 24-hour: 1:30 PM = 13:30." \
    -bg $BG -fg $DIM -font {Sans 12}

label .c.dlbl -text "Date  (YYYY-MM-DD)" -bg $BG -fg $DIM -font {Sans 11}
entry .c.date -justify center -font {Sans 18} -width 18

label .c.tlbl -text "Time  (24-hour, 00:00 - 23:59)" -bg $BG -fg $DIM -font {Sans 11}
entry .c.time -justify center -font {Sans 18} -width 18

label .c.zlbl -text "Timezone" -bg $BG -fg $DIM -font {Sans 11}
set tz_labels {}
foreach {lbl z} $ZONES { lappend tz_labels $lbl }
tk_optionMenu .c.tz ::tzlabel {*}$tz_labels
.c.tz configure -bg $BG -fg $FG -activebackground $BG -activeforeground $FG \
    -highlightthickness 0 -font {Sans 14} -width 16
[.c.tz cget -menu] configure -bg $BG -fg $FG -activebackground "#2a2f3a" \
    -activeforeground $FG

button .c.unlock -text "Set clock & continue" -font {Sans 14} -command submit
label  .c.error  -text "" -bg $BG -fg $ERR -font {Sans 12}
label  .c.bypass -text "Ctrl+Alt+Esc  -  skip to the desktop" \
    -bg $BG -fg $DIM -font {Sans 10}

grid .c.title  -row 0 -column 0 -pady {0 4}
grid .c.hint   -row 1 -column 0 -pady {0 18}
grid .c.dlbl   -row 2 -column 0 -sticky w
grid .c.date   -row 3 -column 0 -pady {0 12}
grid .c.tlbl   -row 4 -column 0 -sticky w
grid .c.time   -row 5 -column 0 -pady {0 12}
grid .c.zlbl   -row 6 -column 0 -sticky w
grid .c.tz     -row 7 -column 0 -pady {0 12} -sticky ew
grid .c.unlock -row 8 -column 0 -pady {4 8}
grid .c.error  -row 9 -column 0
grid .c.bypass -row 10 -column 0 -pady {18 0}

# --- submit ---------------------------------------------------------------
proc reject {msg} {
    .c.error configure -text $msg
}

proc zone_for {label} {
    foreach {lbl z} $::ZONES { if {$lbl eq $label} { return $z } }
    return "UTC"
}

proc submit {} {
    set dt [string trim [.c.date get]]
    set tm [string trim [.c.time get]]
    regsub {\.} $tm ":" tm   ;# accept 09.39 as 09:39

    # Accept any real moment, but reject impossible ones. clock scan with
    # -format is lenient (it rolls 25:99 or 2026-13-40 over), so round-trip the
    # parse and require it to come back unchanged. We do not compare to the
    # current clock - there is nothing trustworthy to compare against.
    if {[catch {clock scan "$dt $tm" -format "%Y-%m-%d %H:%M"} epoch]
        || [clock format $epoch -format "%Y-%m-%d %H:%M"] ne "$dt $tm"} {
        reject "Use date YYYY-MM-DD and 24-hour time 00:00-23:59 (e.g. 13:30)."
        return
    }

    set zone [zone_for $::tzlabel]
    set stamp "$dt $tm:00"
    if {[catch {exec sudo -n /usr/local/bin/captive-setclock $zone $stamp} err]} {
        reject "Could not set the clock. $err"
        return
    }

    catch {grab release .}
    exit 0
}

# Escape hatch: jump straight to a normal XFCE session without setting the
# clock. The wrapper exec's startxfce4 on exit 0; autologin means no password.
proc bypass {} {
    catch {grab release .}
    exit 0
}

# --- input grab & key handling -------------------------------------------
proc grab_input {} {
    if {[catch {grab -global .}]} {
        after 150 grab_input   ;# another grab is active, keep trying
        return
    }
    focus -force .c.date
}

bind all <Control-Alt-Escape> {bypass}
bind .c.date <Return> {focus -force .c.time}
bind .c.time <Return> {submit}
wm protocol . WM_DELETE_WINDOW {}         ;# ignore close requests

update idletasks
after 200 grab_input
