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
    global flag exmh flist mhProfile
    set flag(state) init
    
    # Note - if you change the icon, there is some code in ExmhArgv
    # that positions icons that can depend on the iconsize.
    Preferences_Resource flag(iconup) iconUpBitmap flagup.bitmap
    Preferences_Resource flag(icondown) iconDownBitmap flagdown.bitmap
    Preferences_Resource flag(iconspool) iconSpoolBitmap flagspool.bitmap
    Preferences_Resource flag(labelup) iconUpLabel {$flist(totalcount,$mhProfile(unseen-sequence)) Unseen}
    Preferences_Resource flag(labeldown) iconDownLabel exmh
    Preferences_Resource flag(labelspool) iconSpoolLabel {$exmh(numUnInced) Spooled}
    Preferences_Resource flag(iconupmask) iconUpMask flagup.mask
    Preferences_Resource flag(icondownmask) iconDownMask flagdown.mask
    Preferences_Resource flag(iconspoolmask) iconSpoolMask flagspool.mask
    Preferences_Resource flag(iconupglyph) iconUpGlyph flagup.gif
    Preferences_Resource flag(icondownglyph) iconDownGlyph flagdown.gif
    Preferences_Resource flag(iconspoolglyph) iconSpoolGlyph flagspool.gif

    foreach i {iconup icondown iconspool iconupmask icondownmask iconspoolmask iconupglyph icondownglyph iconspoolglyph} {
	if ![string match /* $flag($i)] {
	    set flag($i) $exmh(library)/$flag($i)
	}
	if ![file exists $flag($i)] {
	    set flag($i) 0
	}
    }
    if {$exmh(slowDispColorIcon)} {
	if [catch {
	    Exmh_Debug "Creating .icon"
	    toplevel .icon
	    wm group .icon .
	    pack [canvas .icon.c]
	    image create photo icondown -file $flag(icondownglyph)
	    image create photo iconup -file $flag(iconupglyph)
	    image create photo iconspool -file $flag(iconspoolglyph)
	    .icon.c configure -width [image width iconup] \
		    -height [image height iconup]
	    wm iconwindow . .icon
	} err] {
	    Exmh_Debug "Can't create .icon: $err"
	    destroy .icon
	}
    }
    FlagInner down icondown labeldown
    trace variable flist(totalcount,$mhProfile(unseen-sequence)) wu Flag_Trace
}
proc Flag_Trace args {
    global flist mhProfile

    if {[info exists flist(oldtotalcount,$mhProfile(unseen-sequence))]} {
	set oldtotal $flist(oldtotalcount,$mhProfile(unseen-sequence))
    } else {
	set oldtotal 0
    }
    if {[info exists flist(totalcount,$mhProfile(unseen-sequence))]} {
	set newtotal $flist(totalcount,$mhProfile(unseen-sequence))
    } else {
	set newtotal 0
    }
Exmh_Debug oldtotal $oldtotal newtotal $newtotal
    set delta [expr {$newtotal - $oldtotal}]
    set flist(oldtotalcount,$mhProfile(unseen-sequence)) $newtotal
    if {($delta > 0) && ($newtotal > 0)} {
	set count $newtotal
	if {$count == 1} {set m ""} else {set m "s"}
	set len [llength $flist($mhProfile(unseen-sequence))]
	if {$len == 1} {set f ""} else {set f "s"}
	Exmh_Status "$count unseen message$m in $len folder$f"
	Flag_NewMail
	Sound_Feedback $delta
    }
    if {($newtotal <= 0) && ($delta != 0)} {
	Flag_NoUnseen
	Exmh_Status "No unseen messages"
    }
}
proc Flag_NewMail { {folder {}} } {
    FlagInner up iconup labelup
}
# Flag_MsgSeen drops the flag but retains the proper label
# This is called after viewing a message
proc Flag_MsgSeen { {folder {}} } {
    global flist mhProfile
    if {[info exists flist(totalcount,$mhProfile(unseen-sequence))] &&
	$flist(totalcount,$mhProfile(unseen-sequence)) > 0} {
	FlagInner spool iconspool labelup
    } else {
	FlagInner down icondown labeldown
    }
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
    Exmh_Debug "In FlagInner $state $icon $label"
    if {$flag(state) != $state} {
	if [winfo exists .icon.c] {
	    Exmh_Debug "Setting flag glyph to $icon"
	    .icon.c delete image -tag icon
	    .icon.c create image 0 0 -anchor nw -image $icon -tag icon
	} else {
	    Exmh_Debug "Setting flag bitmap to $icon"
	    wm iconbitmap . @$flag($icon)
	    if {$flag(${icon}mask) != 0} {
		wm iconmask . @$flag(${icon}mask)
	    }
	}
	set flag(state) $state
	Exmh_Debug "Set flag state to $state"
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
