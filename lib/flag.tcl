# 
# flag.tcl
#
# Manage the iconic flag feedback.  The flag module understands three states,
# but the icon only shows two states:
#
# State 0 - no unseen messages.
# State 1 - newly arrived unseen messages.
# State 2 - messages viewed while in State 1, but not necessarily all unseen
#	messages viewed yet.
#
# The mailbox flag goes up on the transition to State 1 (from either State 0
# or State 2), and the flag goes down on the transition to State 2.  So,
# it is possible to have the flag down and still have unseen messages.  The
# idea is that the flag means new mail has arrived since you last looked
# at *something*.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Flag_Init {} {
    global flag exmh
    set flag(state) init
    
    # Note - if you change the icon, there is some code in ExmhArgv
    # that positions icons that can depend on the iconsize.
    Preferences_Resource flag(iconup) iconUpBitmap flagup.bitmap
    Preferences_Resource flag(icondown) iconDownBitmap flagdown.bitmap
    Preferences_Resource flag(iconspool) iconSpoolBitmap flagup.bitmap
    Preferences_Resource flag(labelup) iconUpLabel {$flist(newMsgs) Unseen}
    Preferences_Resource flag(labeldown) iconDownLabel exmh
    Preferences_Resource flag(labelspool) iconSpoolLabel {$exmh(numUnInced) Spooled}
    Preferences_Resource flag(iconupmask) iconUpMask flagup.mask
    Preferences_Resource flag(icondownmask) iconDownMask flagdown.mask
    Preferences_Resource flag(iconspoolmask) iconSpoolMask flagspool.mask

    foreach i {iconup icondown iconspool iconupmask icondownmask iconspoolmask} {
	if ![string match /* $flag($i)] {
	    set flag($i) $exmh(library)/$flag($i)
	}
	if ![file exists $flag($i)] {
	    set flag($i) 0
	}
    }
    FlagInner down icondown labeldown
}
proc Flag_NewMail { {folder {}} } {
    FlagInner up iconup labelup
}
# Flag_MsgSeen drops the flag but retains the proper label
# This is called after viewing a message
proc Flag_MsgSeen { {folder {}} } {
    global flist
    FlagInner down icondown \
	[expr { ($flist(newMsgs) > 0) ? "labelup" : "labeldown" }]
}
proc Flag_NoUnseen {} {
    FlagInner down icondown labeldown
}
proc Flag_Spooled {} {
    FlagInner spool iconspool labelspool
}
proc Flag_NoSpooled {} {
    FlagInner down icondown labeldown
}
proc FlagInner {state icon label} {
    global exmh flag
    if {$flag(state) != $state} {
	wm iconbitmap . @$flag($icon)
	if {$flag(${icon}mask) != 0} {
	    wm iconmask . @$flag(${icon}mask)
	}
	set flag(state) $state
    }
    set l [uplevel #0 list $flag($label)]
    if {[info exists flag(lastLabel)] &&
	([string compare $l $flag(lastLabel)] == 0)} {
	return
    }
    wm title . $l
    wm iconname . $l
    set flag(lastLabel) $l

}
