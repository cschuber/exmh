# pick.tcl
#
# Interface to MH pick functionality
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Pick {} {
    if [Exwin_Toplevel .pick "Pick Messages" Pick] {
	set t .pick
	set f .pick.but

	.pick.but.quit configure -command {Exwin_Dismiss .pick nosize}
	Widget_AddBut $f clear "Clear" { PickClear }
	Widget_AddBut $f mark "Mark Seen" {PickMarkSeen}
	Widget_AddBut $f pick "Pick" {Pick_It} {left padx 1 filly}
	Widget_CheckBut $f add "Add to Sel" pick(addtosel) {left padx 1 filly}
	Widget_AddBut $f project "New FTOC" Ftoc_NewFtoc {left padx 1 filly}

	PickSetup
        Widget_AddBut .pick or "-Or-" PickOr {bottom pady 5 filly}
    }
}
proc PickClear {} {
    global pick
    for {set pane 0} {$pane <= $pick(panes)} {incr pane} {
	destroy .pick.rim$pane
    }
    PickSetup
}
proc PickSetup {} {
    global pick

    catch {unset pick}
    set pick(panes) 0
    set pick(addtosel) 0
    set pick(fields) {subject from to cc tocc before after search component}

    set f [Widget_Frame .pick rim0 Rim]
    Widget_BeginEntries 20 25 Pick_It
    Widget_LabeledEntry $f.sequence	"Add to Sequence(s)" pick(sequence)
    set pick(sequence) ""
    Widget_LabeledEntry $f.msgs		"Pick from Seq/msg(s)" pick(msgs)
    set pick(msgs) all
    set pad [Widget_Frame $f pad Pad]
    $pad configure -height 10 -width 10
    set pick(0,lastentry) [Widget_EndEntries]		;# This sets focus

    PickNewPane
}
proc PickOr {} {
    global pick

    Widget_Label .pick.rim$pick(panes) or {fill bottom} -text "- Or -"
    PickNewPane
}
proc PickNewPane {} {
    global pick

    set f [Widget_Frame .pick rim[incr pick(panes)] Rim]
    $f configure -bd 5

    set menu [Widget_AddMenuB $f fields "Choose pick attribute" {top}]
    foreach who $pick(fields) {
	Widget_AddMenuItem $menu $who [list PickAddField $f $pick(panes) $who]
    }
}
proc PickAddField {f pane what} {
    global pick

    if ![info exists pick($pane,$what,and)] {
	set pick($pane,$what,and) 0
    }
    set iter [incr pick($pane,$what,and)]
    set who $what$iter
    set pick($pane,$who,or) 1

    lappend pick($pane,fields) [list $what $iter]

    # Find last entry for linking focus
    for {set rim $pane} {$rim >=0} {incr rim -1} {
	if [info exists pick($rim,lastentry)] {
	    set last $pick($rim,lastentry)
	    break
	}
    }
    Widget_BeginEntries 10 25 Pick_It $last

    set l [string toupper [string index $what 0]][string range $what 1 end]
    if [string match component $what] {
	Widget_EntryEntry $f.$who pick($pane,$who,component) pick($pane,$who,1)
    } else {
	Widget_LabeledEntry $f.$who $l pick($pane,$who,1)
    }

    set b [Widget_CheckBut $f.$who not "Not" pick($pane,$who,not)]
    $b config -padx 0 -pady 0
    pack forget $f.$who.not
    pack $f.$who.not -before $f.$who.label -side left

    set b [Widget_AddBut $f.$who or "Or" [list PickAddOrField $pane $who] \
	{left padx 10 fill}]
    $b config -padx 0 -pady 0

    set pick($pane,lastentry) [Widget_EndEntries]
    focus $pick($pane,lastentry)
}
proc PickAddOrField {pane who} {
    global pick

    set or [incr pick($pane,$who,or)]
    set f .pick.rim$pane.$who
    Widget_LabeledEntryOr $f $or pick($pane,$who,$or)
    set me $f.entry$or
    if {$or == 2} {
	set lcheck $f.entry
    } else {
	set lcheck $f.entry[expr $or -1]
    }
    if {$pick($pane,lastentry) == $lcheck} {
	set pick($pane,lastentry) $me
    }
}
proc Pick_It {} {
    global pick exmh
    set cmd [list exec pick +$exmh(folder) -list]
    set inpane 0
    set hadpane 0
    for {set pane 1} {$pane <= $pick(panes)} {incr pane} {
	set and 0
	if ![info exists pick($pane,fields)] continue
	foreach l $pick($pane,fields) {
	    set field [lindex $l 0]
	    set iter [lindex $l 1]
	    set who $field$iter
	    set or 0
	    for {set i 1} {$i <= $pick($pane,$who,or)} {incr i} {
		set text [string trim $pick($pane,$who,$i)]
		if {[string length $text] == 0} continue

		if {$inpane != $pane} {
		    if $hadpane {lappend cmd -or}
		    lappend cmd -lbrace
		    set inpane $pane
		    set hadpane 1
		} elseif $and {
		    lappend cmd -and
		    set and 0
		} elseif $or {
		    lappend cmd -or
		}
		if !$or {
			if $pick($pane,$who,not) {
				lappend cmd -not
			}
			lappend cmd -lbrace
		}
		switch -exact $field \
		component {lappend cmd --$pick($pane,$who,component) $text} \
		tocc      {lappend cmd -lbrace -to $text -or -cc $text -rbrace} \
		default   {lappend cmd -$field $text}
	        set or 1
	    }
	    if $or {
		lappend cmd -rbrace
	    }
	    set and 1
	}
	if {$inpane == $pane} {lappend cmd -rbrace}
    }
    set msgs $pick(msgs)
    foreach s $pick(sequence) {
	lappend msgs -sequence $s
    }

    Exmh_Debug Pick_It $cmd $msgs
    busy PickInner $cmd $msgs
    Ftoc_ShowSequences $exmh(folder)
    Exmh_Focus
}
proc PickInner {cmd msgs} {
    global pick
    Exmh_Status "$cmd $msgs" warning
    if [catch [concat $cmd $msgs] ids] {
	Exmh_Status "Fail: [string range $ids 2 end]" error
	return
    }
    set pick(ids) [split $ids \n]
    Exmh_Debug Ftoc_PickMsgs $pick(ids)
    if {! $pick(addtosel)} {
	Ftoc_RangeUnHighlight
    }
    Ftoc_PickMsgs $pick(ids) $pick(addtosel)
    Exmh_Status "Pick hit [llength $pick(ids)] msgs"
}
proc PickMarkSeen {} {
    global exmh pick mhProfile
    if ![info exists pick(ids)] {
	return
    }
    Seq_Del $exmh(folder) $mhProfile(unseen-sequence) $pick(ids)
}
proc Pick_MarkSeen {} {
    global exmh pick mhProfile
    Exmh_Status "Clearing unseen sequence..." warning
    set pick(ids) [Seq_Msgs $exmh(folder) $mhProfile(unseen-sequence)]
    busy PickMarkSeen
    Exmh_Status ok
}
