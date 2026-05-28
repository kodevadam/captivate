#!/usr/bin/env wish
# Captive time/date gate for an autologin XFCE session.
#
# Shown fullscreen and override-redirect, with a global input grab, before the
# desktop starts. The user must type the current date and time (read from a
# watch/phone) to continue. There is no window manager running in this session,
# so there is nothing to switch away to; the window has no decorations and
# cannot be closed. Exits 0 only on a correct answer; wrong answers keep the
# prompt up.

package require Tk

set TOLERANCE_MIN 3   ;# how far the typed time may differ from the clock

set BG  "#101216"
set FG  "#e6e6e6"
set DIM "#9aa0a6"
set ERR "#ff6b6b"

# --- window ---------------------------------------------------------------
wm overrideredirect . 1
wm geometry . "[winfo screenwidth .]x[winfo screenheight .]+0+0"
. configure -bg $BG -cursor left_ptr
raise .

# --- widgets --------------------------------------------------------------
frame .c -bg $BG
place .c -relx 0.5 -rely 0.5 -anchor center

label .c.title -text "Enter the current date and time to continue" \
    -bg $BG -fg $FG -font {Sans 24 bold}
label .c.hint  -text "Use 24-hour time. You have a few minutes of leeway." \
    -bg $BG -fg $DIM -font {Sans 12}

label .c.dlbl -text "Date  (YYYY-MM-DD)" -bg $BG -fg $DIM -font {Sans 11}
entry .c.date -justify center -font {Sans 18} -width 18

label .c.tlbl -text "Time  (HH:MM)" -bg $BG -fg $DIM -font {Sans 11}
entry .c.time -justify center -font {Sans 18} -width 18

button .c.unlock -text "Unlock" -font {Sans 14} -command submit
label  .c.error  -text "" -bg $BG -fg $ERR -font {Sans 12}

grid .c.title  -row 0 -column 0 -pady {0 4}
grid .c.hint   -row 1 -column 0 -pady {0 18}
grid .c.dlbl   -row 2 -column 0 -sticky w
grid .c.date   -row 3 -column 0 -pady {0 12}
grid .c.tlbl   -row 4 -column 0 -sticky w
grid .c.time   -row 5 -column 0 -pady {0 12}
grid .c.unlock -row 6 -column 0 -pady {4 8}
grid .c.error  -row 7 -column 0

# --- validation -----------------------------------------------------------
proc reject {msg} {
    .c.error configure -text $msg
    .c.time delete 0 end
    focus -force .c.time
}

proc parse_dt {date time} {
    foreach fmt {"%Y-%m-%d %H:%M" "%Y-%m-%d %H.%M"} {
        if {![catch {clock scan "$date $time" -format $fmt} epoch]} {
            return $epoch
        }
    }
    return ""
}

proc submit {} {
    global TOLERANCE_MIN
    set now   [clock seconds]
    set today [clock format $now -format %Y-%m-%d]
    set dt [string trim [.c.date get]]
    set tm [string trim [.c.time get]]

    if {$dt ne $today} {
        reject "That date is not correct (use YYYY-MM-DD)."
        return
    }
    set entered [parse_dt $dt $tm]
    if {$entered eq ""} {
        reject "Check the time format: HH:MM (24-hour)."
        return
    }
    if {abs($now - $entered) > $TOLERANCE_MIN * 60} {
        reject "That time is not correct."
        return
    }
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

bind . <Escape> {break}                  ;# swallow Escape
bind .c.date <Return> {focus -force .c.time}
bind .c.time <Return> {submit}
wm protocol . WM_DELETE_WINDOW {}         ;# ignore close requests

update idletasks
after 200 grab_input
