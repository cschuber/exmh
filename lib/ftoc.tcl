# 
# ftoc.tcl
#
# Folder table of contents display.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Ftoc_Init {} {
    global ftoc
    set ftoc(displayValid) 0		;# 1 => pick results, not full scan
    set ftoc(displayDirty) 0		;# 1 => display differs from cache
    set ftoc(mono) [expr {[winfo depth .] <= 4}]
    # Parameters to the Next button
    Preferences_Add "Scan Listing" \
"These settings affect the behavior of Exmh as you move through the scan listing to view and mark messages.
While the default for Auto Commit is OFF, I suggest you try it out.
Messages are still temporarily marked, but the commit is done when you need it." {
    {exwin(ftextLines)	ftextLines 15	{Scan listing lines}
"Lines in the Scan listing window, which is
also called Folder-Table-Of-Contents (FTOC)."}
    {ftoc(implied) impliedDirection ON "Implied Direction"
"If set, Exmh will remember your current direction,
next or previous, and go that way after you mark a
message for deletion or refiling."}
    {ftoc(nextGuard) nextGuard OFF "Next Guard"
"If set, Exmh will warn you that you are about to
change folders when you hit Next.  This means you
end up hitting Next twice to chain the to next
folder with unseen messages."}
    {ftoc(autoCommit) autoCommit OFF "Auto Commit"
"If set, Exmh will invoke the Commit operation to
commit deletions and refiles when it would otherwise
just complain that such a commit is required."}
    {ftoc(commitDialog) commitDialog ON "Commit Dialog"
"If set, you get a confirmation dialog when exmh wants
you to commit pending changes.  Otherwise you just
get a warning message and have to hit the Commit button."}
    {ftoc(autoPack) autoPack OFF "Auto Pack"
"If set, Exmh will pack the folder every time a commit is performed."}
    {ftoc(autoSort) autoSort OFF "Auto Sort"
"If set, Exmh will sort the folder every time you change into it"}
    {ftoc(autoSortType) autoSortType {CHOICE date subject sender custom} {Sorting criterion}
"Sort by Date:/Subject:/From: or user-defined fields. Uses MH sortm command."}
    {ftoc(autoSortCrit) autoSortCrit {-textfield keywords} {Custom criterion}
"Custom parameters for sortm"}
    {ftoc(showNew) ftocShowNew OFF "Show New Messages"
"If set, Exmh will scroll the FTOC display to show
new message that arrive because of an Inc."}
    {ftoc(linkAdvance) advanceOnLink OFF "Advance after Link"
"If set, Exmh will advance to the next message after a link."}
    {ftoc(skipMarked) skipMarked ON "Next/Prev skip marked msgs"
"If set, Next and Prev will skip over messages that have
been marked for move or delete."}
    {flist(cycleBack)	cycleBack ON	"Cycle back to first"
"If there are no folders with unseen messages, then this
option causes you to change to the first folder given by your
Folder-Order MH profile entry."}
    {ftoc(scanWidth) scanWidth 100 "Default scan width"
"This value is passed as the -width argument to scan and in."}
    {ftoc(scanSize) scanSize 100 "Default amount to scan"
"Only the last N messages are scanned when you first enter a folder.
The number is controlled by this setting."}
    }
}
proc Ftoc_Reset { numMsgs msgid folder } {
    global ftoc exwin
    Exmh_Debug Ftoc_Reset $folder has $numMsgs msgs
    set ftoc(numMsgs) $numMsgs		;# num msgs in the scan listing
    set ftoc(changed) 0			;# Number of moves/deletes marked
    set ftoc(lineset) {}		;# set of selected messages
    set ftoc(pickone) 1			;# lineset is empty
    set ftoc(folder) $folder		;# Currently displayed folder
    set ftoc(direction) next		;# assumed next direction
    set ftoc(softChange) [expr {! $ftoc(nextGuard)}]
    set ftoc(lasthit) {}		;# search anchor
    if {$msgid == {}} {
	set ftoc(curLine) {}		;# current display line number
    } else {
	set ftoc(curLine) {}		;# Set later in Msg_Change ?
    }
    Ftoc_ClearMsgCache
}
proc Ftoc_Update { numMsgs folder } {
    # Update size of message list after inc'ing into current folder
    global ftoc
    Exmh_Debug Ftoc_Update $folder has $numMsgs msgs
    set ftoc(numMsgs) $numMsgs
}

proc Ftoc_Bindings { w } {
    # Bindings for the ftoc text widget

    # The TScroll binding to too general.
    # We'll do our own scroll bindings here.
    bindtags $w [list $w]

    # Button-1 starts selection range
    bind $w <Button-1> {
	FtocRangeStart [lindex [split [%W index current] .] 0]
	Exmh_Focus
    }
    bind $w <Shift-Button-1> {
	FtocRangeAdd [lindex [split [%W index current] .] 0]
	Exmh_Focus
    }
    bind $w <B1-Motion> {
	FtocRangeExtendXY %x %y
    }
    bind $w <Shift-B1-Motion> {
	FtocRangeExtendXY %x %y
    }
    bind $w <Any-ButtonRelease-1> {
	FtocRangeEnd [lindex [split [%W index current] .] 0] 0
    }
    bind $w <Shift-ButtonRelease-1> {
	FtocRangeEnd [lindex [split [%W index current] .] 0] 1
    }
    bind $w <Button-3> {
	set lineNumber [lindex [split [%W index current] .] 0]
	Msg_Pick $lineNumber noshow
	Exmh_Focus
    }
    bind $w <Double-Button-1> { }
    bind $w <Triple-Button-1> { }

    bind $w <Button-2> {WidgetTextMark %W %y}
    bind $w <B2-Motion> {WidgetTextDragto %W %y $exwin(scrollSpeed)}

    Drag_Attach $w FtocDragSelect Shift 3
}
proc FtocRangeStart { line } {
    # For normal button-down "start a selection"
    global ftoc
    Ftoc_RangeUnHighlight
    set ftoc(pickstart) $line
    set ftoc(pickend) $line
    set ftoc(pickstate) new
    set ftoc(extend) 0
    Ftoc_RangeHighlight $line $line
}
proc FtocRangeAdd { line } {
    # For shift-select "add to selection"
    global ftoc
    set ftoc(pickstart) $line
    set ftoc(pickend) $line
    set ftoc(pickstate) invert
    set ftoc(extend) 0
    FtocRangeInvert $line $line
}
proc FtocRangeEnd { {line {}} {addcurrent 0} } {
    # For end of button sweep
    global ftoc exwin
    catch {unset ftoc(extend)}
    if ![info exists ftoc(pickend)] {
	# Spurious button-release event
	return
    }
    if {($line == $ftoc(pickstart)) && !$addcurrent} {
	# regular button click optimization
	unset ftoc(pickend)
	Msg_Pick $line show
	return
    }
    if {$line != {}} {
	FtocRangeExtend $line
    }
    FtocPickRange $addcurrent
    catch {unset ftoc(pickend)}
}
proc Ftoc_PickMsgs { ids addtosel } {
    # For adding to the selection by message number
    global ftoc
    Exmh_Status "Marking [llength $ids] hits"
    set lines {}
    for {set L 0} {$L <= $ftoc(numMsgs)} {incr L} {
	set ix [lsearch $ids [Ftoc_MsgNumber $L]]
	if {$ix >= 0} {
	    lappend lines $L
	    set ids [lreplace $ids $ix $ix]
	    if {[string length $ids] == 0} {
		break
	    }
	}
    }
    Ftoc_LinesHighlight $lines
    FtocPickRange $addtosel
}
proc FtocRangeExtendXY { x y } {
    global ftoc exwin widgetText

    if ![info exists ftoc(extend)] {
	return
    }
    set active $ftoc(extend)

    set h [winfo height $exwin(ftext)]
    if {$y > $h} {
	set ftoc(extend) [expr $y-$h]
    } else {
	if {$y < 0} {
	    set ftoc(extend) $y
	} else {
	    set ftoc(extend) 0
	}
    }
    
    if {$ftoc(extend) == 0} {
	FtocRangeExtend [lindex [split [$exwin(ftext) index @$x,$y] .] 0]
    } else {
	if {! $active} {
	    set ftoc(lastmark) [lindex [ split [$exwin(ftext) index @$x,$y] .] 0]
	    after $widgetText(selectDelay) [list FtocSelExtend]
	}
    }
}
proc FtocSelExtend {} {
    global ftoc exwin widgetText
    set w $exwin(ftext)
    if {![info exists ftoc(extend)] ||
	($ftoc(extend) == 0)} {
	return
    }
    catch {
	set delta [expr {$ftoc(extend) / 16}]
	if {$delta == 0} {
	    set delta [expr { ($ftoc(extend) < 0) ? -1 : 1 }]
	}
	set newmark [expr {$ftoc(lastmark) + $delta}]
	FtocRangeExtend $newmark
	set ftoc(lastmark) $newmark
	$w yview -pickplace $newmark.0
	after $widgetText(selectDelay) [list FtocSelExtend]
    }
}
proc FtocRangeExtend { line } {
    global ftoc
    if ![info exists ftoc(pickend)] {
	return
    }
    if {$line <= 0} {
	set line 1
    }
    if {$line > $ftoc(numMsgs)} {
	set line $ftoc(numMsgs)
    }
    if {$line == $ftoc(pickend)} {
	# Invariant, previously defined selection is fine.
	return
    }
    if {$line == 0} {
	# no messages in folder
	return
    }
    if {$ftoc(pickstate) != "invert"} {
	if {$ftoc(pickstart) < $ftoc(pickend)} {
	    # Growing downward
	    if {$line > $ftoc(pickend)} {
		Ftoc_RangeHighlight [expr $ftoc(pickend)+1] $line
	    } else {
		if {$line < $ftoc(pickstart)} {
		    if {$ftoc(pickstart) != $ftoc(pickend)} {
			# Change direction
			FtocRangeClear [expr $ftoc(pickstart)+1] \
					$ftoc(pickend)
		    }
		    Ftoc_RangeHighlight [expr $ftoc(pickstart)-1] $line
		} else {
		    # Shrink selection
		    FtocRangeClear [expr $line+1] $ftoc(pickend)
		}
	    }
	} else {
	    # Growing upward
	    if {$line < $ftoc(pickend)} {
		Ftoc_RangeHighlight [expr $ftoc(pickend)-1] $line
	    } else {
		if {$line > $ftoc(pickstart)} {
		    if {$ftoc(pickstart) != $ftoc(pickend)} {
			# Change direction
			FtocRangeClear [expr $ftoc(pickstart)-1] \
					$ftoc(pickend)
		    }
		    Ftoc_RangeHighlight [expr $ftoc(pickstart)+1] $line
		} else {
		    # Shrink selection
		    FtocRangeClear [expr $line-1] $ftoc(pickend)
		}
	    }
	}
    } else {
	if {$ftoc(pickstart) < $ftoc(pickend)} {
	    # Growing downward
	    if {$line > $ftoc(pickend)} {
		FtocRangeInvert [expr $ftoc(pickend)+1] $line
	    } else {
		if {$line < $ftoc(pickstart)} {
		    if {$ftoc(pickstart) != $ftoc(pickend)} {
			# Change direction
			FtocRangeInvert [expr $ftoc(pickstart)+1] \
					$ftoc(pickend)
		    }
		    FtocRangeInvert [expr $ftoc(pickstart)-1] $line
		} else {
		    # Shrink selection
		    FtocRangeInvert [expr $line+1] $ftoc(pickend)
		}
	    }
	} else {
	    # Growing upward
	    if {$line < $ftoc(pickend)} {
		FtocRangeInvert [expr $ftoc(pickend)-1] $line
	    } else {
		if {$line > $ftoc(pickstart)} {
		    if {$ftoc(pickstart) != $ftoc(pickend)} {
			# Change direction
			FtocRangeInvert [expr $ftoc(pickstart)-1] \
					$ftoc(pickend)
		    }
		    FtocRangeInvert [expr $ftoc(pickstart)+1] $line
		} else {
		    # Shrink selection
		    FtocRangeInvert [expr $line-1] $ftoc(pickend)
		}
	    }
	}
    }
    set ftoc(pickend) $line
}
proc FtocRangeInvert { start end } {
    global exwin
    set win $exwin(ftext)
    if {$start > $end} {
	set tmp $start ; set start $end ; set end $tmp
    }
    for {set line $start} {$line <= $end} {incr line} {
	catch {
	    set newtag range
	    set oldtag {}
	    set nuke 0
	    foreach tag [$win tag names $line.0] {
		case $tag {
		    deleted { set newtag drange ; set oldtag $tag ; break; }
		    moved { set newtag mrange ; set oldtag $tag ; break; }
		    range { set newtag {} ; set oldtag $tag ; break; }
		    drange { set newtag deleted ; set oldtag $tag ;
			    set nuke 1; break}
		    mrange { set newtag moved ; set oldtag $tag ;
			    set nuke 1; break; }
		}
	    }
	    if {$nuke} {
		set ix [lsearch $ftoc(lineset) $line]
		if {$ix >= 0} {
		    set ftoc(lineset) [lreplace $ftoc(lineset) $ix $ix]
		}
	    }
	    if {$oldtag != {}} {
		$win tag remove $oldtag $line.0 $line.end
	    }
	    if {$newtag != {}} {
		$win tag add $newtag $line.0 $line.end
	    }
	}
    }
}
proc Ftoc_RangeHighlight { start end } {
    global exwin
    set win $exwin(ftext)
    if {$start > $end} {
	set tmp $start ; set start $end ; set end $tmp
    }
    for {set line $start} {$line <= $end} {incr line} {
	set newtag range
	foreach tag [$win tag names $line.0] {
	    case $tag {
		{drange deleted} { set newtag drange ;  break; }
		{mrange moved} { set newtag mrange ;  break; }
	    }
	}
	$win tag add $newtag $line.0 $line.end
    }
}
proc Ftoc_LinesHighlight { lines } {
    global exwin
    set win $exwin(ftext)
    if {$lines == {}} {
	return
    }
    WidgetTextYview $exwin(ftext) -pickplace [lindex $lines 0].0
    update idletasks
    foreach line $lines {
	set newtag range
	foreach tag [$win tag names $line.0] {
	    case $tag {
		{drange deleted} { set newtag drange ;  break; }
		{mrange moved} { set newtag mrange ;  break; }
	    }
	}
	$win tag add $newtag $line.0 $line.end
    }
}
proc FtocRangeClear { start end } {
    global exwin
    set win $exwin(ftext)
    if {$start > $end} {
	set tmp $start ; set start $end ; set end $tmp
    }
    for {set line $start} {$line <= $end} {incr line} {
	catch {
	    set newtag {}
	    set oldtag range
	    foreach tag [$win tag names $line.0] {
		case $tag {
		    drange { set newtag deleted ; set oldtag drange; break; }
		    mrange { set newtag moved ; set oldtag mrange; break; }
		    range { break }
		}
	    }
	    $win tag remove $oldtag $line.0 $line.end
	    if {$newtag != {}} {
		$win tag add $newtag $line.0 $line.end
	    }
	}
    }
}
proc Ftoc_RangeUnHighlight { } {
    global exwin exmh
    set win $exwin(ftext)
    foreach tag {range drange mrange} {
	foreach range [FtocMakePairs [$win tag ranges $tag]] {
	    eval $win tag remove $tag $range
	    if {$tag == "drange"} {
		eval $win tag add deleted $range
	    }
	    if {$tag == "mrange"} {
		eval $win tag add moved $range
	    }
	}
    }
}

# For user programming
proc Ftoc_BindDouble { cmd } {
    global exwin
    bind $exwin(ftext) <Double-1> $cmd
}
proc Ftoc_BindRight { cmd } {
    global exwin
    bind $exwin(ftext) <3> $cmd
}

proc Ftoc_FindMsg { msgid {line {}} } {
    global ftoc msgtolinecache
    if {![catch {set msgtolinecache($msgid)} L]} {
	return $L
    }
    if {$line != {}} {
	switch -glob -- $line {
	    first  {return 1}
	    last   {return $ftoc(numMsgs)}
	    [0-9]* {
		if {$line > $ftoc(numMsgs)} {
		    return $ftoc(numMsgs)
		} else {
		    return $line
		}
	    }
	    default {return {}}
	}
    }
    if {$msgid == {}} {
	return {}
    }
#
# Linear search for pick and thread FTOCs (pseudo-displays)
#
    if !$ftoc(displayValid) {
        for {set L 1} {$L <= $ftoc(numMsgs)} {incr L} {
            if {[Ftoc_MsgNumber $L] == $msgid} {
                return $L
            }
        }
        return {}
    }

    set minLine 1
    set minMsg [Ftoc_MsgNumber $minLine]
    if {$msgid == $minMsg} {
	return $minLine
    }
    set maxLine $ftoc(numMsgs)	;# Ignore trailing blank line
    set maxMsg [Ftoc_MsgNumber $maxLine]
    if {$msgid == $maxMsg} {
	return $maxLine
    }
    while (1) {
	if {$msgid > $maxMsg || $msgid < $minMsg} {
	    Exmh_Status "Cannot find $msgid ($minMsg,$maxMsg)" warn
	    set msgtolinecache($msgid) {}
	    return {} ;# new message not listed
	}
	if {$maxLine == $minLine} {
	    set msgtolinecache($msgid) {}
	    return {}	;# not found
	}
	#set nextLine [expr int(($maxLine+$minLine)/2)]
	# Don't divide in two, guestimate the where the line might be instead
	set nextLine [expr int($minLine+1+($msgid-$minMsg)*($maxLine-$minLine-2)/($maxMsg-$minMsg))]
	set nextMsg [Ftoc_MsgNumber $nextLine]
	if {$nextMsg == $msgid} {
	    return $nextLine
	} elseif {$nextMsg > $msgid} {
	    set maxLine $nextLine
	    set maxMsg $nextMsg
	} elseif {$minLine == $nextLine} {
	    Exmh_Status "Cannot find $msgid" warn
	    set msgtolinecache($msgid) {}
	    return {} ;# new message not listed
	} else {
	    set minLine $nextLine
	    set minMsg $nextMsg
	}
    }
    # not reached
}
proc Ftoc_ClearMsgCache {} {
    global linetomsgcache msgtolinecache
    foreach x {linetomsgcache msgtolinecache} {
        if {[info exists $x]} {
            unset $x
        }
    }
}
proc Ftoc_MsgNumber { L } {
    global exwin linetomsgcache msgtolinecache
    if [catch {set linetomsgcache($L)} msgno] {
	if [catch {$exwin(ftext) get $L.0 $L.end} line] {
	    set linetomsgcache($L) {}
	    return {}
	}
	set msgno [Ftoc_MsgNumberRaw $line]
	set msgtolinecache($msgno) $L
	set linetomsgcache($L) $msgno
    }
    return $msgno
}
proc Ftoc_MsgNumberRaw { line } {
    if [regexp {^( *)([0-9]+)} $line foo foo2 number] {
	return $number
    } else {
	return ""
    }
}
proc FtocPickRange { {addcurrent 0} } {
    # Select a range of messages, or add to the current range
    # Because of toggle/inverted selections, we pretty much
    # have to recompute the select set from range tags
    global exwin ftoc
    set lineset {}
    if {$ftoc(curLine) != {}} {
	if {$addcurrent} {
	    Ftoc_RangeHighlight $ftoc(curLine) $ftoc(curLine)
	}
	Ftoc_ClearCurrent
	Msg_ClearCurrent
	set ftoc(curLine) {}
    }
    foreach range [concat \
	[FtocMakePairs [$exwin(ftext) tag ranges range]] \
	[FtocMakePairs [$exwin(ftext) tag ranges drange]] \
	[FtocMakePairs [$exwin(ftext) tag ranges mrange]]] {
	set mark1 [lindex $range 0]
	set line [lindex [split $mark1 .] 0]
	lappend lineset $line
    }
    if {$lineset == {}} {
	return			;# spurious <ButtonRelease-1> events
    }
    set ftoc(lineset) $lineset
    set ftoc(pickone) 0
    if {[llength $ftoc(lineset)] == 1} {
	# This calls Msg_Change,
	# which calls Ftoc_ClearCurrent, which sets pickone to 1,
	# and calls Ftoc_Change, which sets curline
	Msg_Pick [lindex $ftoc(lineset) 0] show
    } else {
	Buttons_Range	;# Enable actions on ranges
    }
}
proc Ftoc_PickSize {} {
    global ftoc
    if {$ftoc(curLine) != {}} {
	return [llength $ftoc(curLine)]
    } else {
	return [llength $ftoc(lineset)]
    }
}
proc Ftoc_NewFtoc {} {
    global ftoc
    set ids {}
    foreach l $ftoc(lineset) {
	lappend ids [Ftoc_MsgNumber $l]
    }
    if {[llength $ids] <= 1} {
	Exmh_Status "Select more than one message first" warn
	return
    }
    if {[Ftoc_Changes "new ftoc"] == 0} {
	Exmh_Status $ids
	Scan_ProjectSelection $ids
    }
}

# Ftoc_ClearCurrent and Ftoc_Change are two parts of
# dinking the ftoc display when advancing a message.

proc Ftoc_ClearCurrent {} {
    # Clear display of current message
    global ftoc exwin
    set ftoc(pickone) 1
    set ftoc(lineset) {}

    if {$ftoc(curLine) != {}} {
	$exwin(ftext) tag remove cur $ftoc(curLine).0 $ftoc(curLine).end
	Ftoc_RescanLine $ftoc(curLine)
    }
    return $ftoc(curLine)
}
proc Ftoc_Change { msgid line {show show} } {
    global ftoc exwin
    set ftoc(curLine) [Ftoc_FindMsg $msgid $line]
    if {$ftoc(curLine) == {}} {
	set ok 0
    } else {
	if {$show == "show"} {
	    $exwin(ftext) tag remove unseen $ftoc(curLine).0 $ftoc(curLine).end
	}
	Ftoc_RescanLine $ftoc(curLine) +
	$exwin(ftext) tag add cur $ftoc(curLine).0 $ftoc(curLine).end
	set top [$exwin(ftext) index @0,4]
	if [catch {expr {$top+1}}] {set top 0}	;# trap 100.-1 format, iconic
	if {$ftoc(curLine) == $top ||
	    $ftoc(curLine) == $top+$exwin(ftextLines)-1} {
	    WidgetTextYview $exwin(ftext) [expr $ftoc(curLine)-$exwin(ftextLines)/2].0
	} else {
	    WidgetTextYview $exwin(ftext) -pickplace $ftoc(curLine).0
	}
	set ok 1
    }
    return $ok
}
proc Ftoc_InitSequences { w } {
    global exwin
    set sequences [option get . sequences {}]
    foreach sequencename $sequences {
	eval $w tag configure $sequencename \
		[option get . sequence_$sequencename {}]
	$w tag raise $sequencename
    }
}
proc Ftoc_ShowSequences { folder } {
    global exwin
    Exmh_Debug Ftoc_ShowSequences $folder
    set sequences [option get . sequences {}]
    set hiddensequences [option get . hiddensequences {}]
    foreach sequence $sequences {
	if {[lsearch -exact $hiddensequences $sequence] == -1} {
	    $exwin(ftext) tag remove $sequence 1.0 end
	}
    }
    foreach sequencename [Mh_Sequences $folder] {
	$exwin(ftext) tag remove $sequencename 0.0 end
	set sequence [Mh_Sequence $folder $sequencename]
	Exmh_Debug $sequencename: $sequence
	foreach i $sequence {
	    set line [Ftoc_FindMsg $i]
	    if {$line != {}} {
		$exwin(ftext) tag add $sequencename $line.0 $line.end
	    }
	}
    }
}
proc Ftoc_MarkSeen { ids } {
    global exwin ftoc

    set ids [lsort -integer -decreasing $ids]
    for {set L $ftoc(numMsgs)} {$L > 0} {incr L -1} {
	set ix [lsearch $ids [Ftoc_MsgNumber $L]]
	if {$ix >= 0} {
	    $exwin(ftext) tag remove unseen $L.0 $L.end
	    set ids [lreplace $ids $ix $ix]
	    if {[llength $ids] == 0} {
		break
	    }
	}
    }
}
proc Ftoc_RescanLine { ix {plus none} } {
    global exmh exwin ftoc
    if [catch {
	set text [$exwin(ftext) get ${ix}.0 ${ix}.end]
	set ok 0
	case $plus {
	    "none" {
		# Replace + (current marker) with blank
		set ok [regsub {^( *[0-9]+)(\+)} $text {\1 } newtext]
	    }
	    "+" {
		# Stick a + after the number, if needed
		if ![regexp {^( *)([0-9]+)(\+)} $text] {
		    set ok [regsub {^( *[0-9]+)( )} $text {\1+} newtext]
		}
	    }
	    "dash" {
		# Stick a - after the number, if needed
		if ![regexp {^( *)([0-9]+).-} $text] {
		    set ok [regsub {^( *[0-9]+.)(.)} $text {\1-} newtext]
		}
		# Annotations result in writes to the directory.
		# Here we mark the display dirty to force an update
		# of the cache and prevent later rescans.
		set ftoc(displayDirty) 1
		Ftoc_ClearMsgCache
	    }
	}
	if {$ok} {
	    set tags [$exwin(ftext) tag names ${ix}.0]
	    $exwin(ftext) configure -state normal
	    $exwin(ftext) delete ${ix}.0 ${ix}.end
	    $exwin(ftext) insert ${ix}.0 $newtext
	    $exwin(ftext) configure -state disabled
	    foreach tag $tags {
		$exwin(ftext) tag add $tag ${ix}.0 ${ix}.end
	    }
	}
    } msg] {
	Exmh_Error "FtocRescanLine $ix : $msg"
    }
}
proc Ftoc_NextImplied { {show show} {implied implied} } {
    global ftoc
    if {$ftoc(implied) && $ftoc(direction) == "prev"} {
	Ftoc_Prev $show
    } else {
	Ftoc_Next $show $implied
    }
}
proc Ftoc_Next { show {implied no} } {
    # Go to the next message in the scan display
    global exmh flist ftoc

    set ftoc(direction) "next"
    if {$ftoc(curLine) == {}} {
	if [Msg_ShowUnseen] {
	    return
	}
    }
    set next [FtocSkipMarked $ftoc(curLine) 1]
    if {($ftoc(curLine) == $next) || \
	($ftoc(curLine) >= $ftoc(numMsgs)) || \
	($ftoc(curLine) <= 0)} {
	# End of folder
	Ftoc_NextFolder $implied
    } else {
	# Simple case - go to the next message.
	Msg_Pick $next $show
    }
}
proc Ftoc_Prev { {show show} } {
    global ftoc

    Exmh_Debug Ftoc_Prev
    if {$ftoc(curLine) == {}} {
	if {$ftoc(numMsgs) > 0} {
	    Msg_Pick $ftoc(numMsgs) $show
	}
	return
    }
    if {$ftoc(curLine) > 1} then {
	set ftoc(direction) "prev"
	Msg_Pick [FtocSkipMarked $ftoc(curLine) -1] $show
    } else {
	Ftoc_Next $show implied
    }
}
proc Ftoc_NextFolder { {implied no} } {
    global ftoc exmh
    # Try to chain to the next folder with unread messages.
    if {$implied != "no"} {
	# Implied - chained with some other operation - be lenient
	if {$ftoc(changed) > 0} {
	    # Dirty folder - do not change.
	    # If on last message, clear display because the
	    # message is moved or deleted
	    if {$ftoc(curLine) != {}} {
		Ftoc_ClearCurrent
		Msg_ClearCurrent
	    }
	    Exmh_Status ""
	    Exmh_Status "Changes pending; End of folder" warn
	    return
	}
    }
    set f [Flist_NextUnseen]
    if {[string length $f] != 0} {
	if {$ftoc(softChange)} {
	    set ftoc(lastFolder) $exmh(folder)
	    Folder_Change $f Msg_ShowUnseen
	    return
	} else {
	    set ftoc(softChange) 1
	    Ftoc_ClearCurrent
	    Msg_ClearCurrent
	    Exmh_Status ""
	    Exmh_Status "End of folder; <Next> => $f" warn
	    return
	}
    }
    Exmh_Status ""
    Exmh_Status "End of folder" warn
}
proc Ftoc_LastFolder {} {
    global ftoc
    if {[info exist ftoc(lastFolder)]} {
	return $ftoc(lastFolder)
    } else {
	return ""
    }
}
proc Ftoc_PrevMarked { {show show} } {
    global ftoc
    set skip $ftoc(skipMarked)
    set ftoc(skipMarked) 0
    Ftoc_Prev $show
    set ftoc(skipMarked) $skip
}
proc Ftoc_Marked { id } {
    global ftoc exwin
    if {$ftoc(skipMarked) == 0} {
	return 0	;# Pretend it isn't marked
    }
    set i [Ftoc_FindMsg $id]
    if {[string length $i] == 0} {
	return 1	;# Can't find it, pretend it's marked
    }
    set marked 0
    foreach tag [$exwin(ftext) tag names $i.0] {
	if [regexp {(deleted|moved|drange|mrange)} $tag] {
	    set marked 1 ; break;
	}
    }
    return $marked
}
proc FtocSkipMarked {start inc} {
    global exwin ftoc

    if {$start == {}} {
	return {}
    }
    for {set i [expr $start+$inc]} {$i > 0 && $i <= $ftoc(numMsgs)} {incr i $inc} {
	if {$ftoc(skipMarked) == 0} {
	    return $i
	}
	set marked 0
	foreach tag [$exwin(ftext) tag names $i.0] {
	    if [regexp {(deleted|moved|drange|mrange)} $tag] {
		set marked 1 ; break;
	    }
	}
	if {! $marked} {
	    return $i
	}
    }
    return $start
}

proc Ftoc_Changes {type {allowAuto 1} } {
    global ftoc

    if {$ftoc(changed) != 0} then {
	Exmh_Debug Ftoc_Changes $type
	if {("$allowAuto" == "1") && $ftoc(autoCommit)} {
	    Folder_CommitType $type
	    return 0
	}
	if {$type != {}} {
	    if {[string compare $type iconified] == 0} {
		set msg "$ftoc(changed) changes pending"
	    } else {
		if {$ftoc(commitDialog) &&
		    [FtocDialog $ftoc(changed) $type]} {
		    Folder_CommitType $type
		    Exmh_Focus
		    return 0
		} else {
		    set msg "$ftoc(changed) changes pending: $type cancelled"
		}
	    }
	    Exmh_Focus
	    Exmh_Status $msg warn
	    Sound_Error
	} else {
	    Exmh_Status "Oops, $ftoc(changed) left over changes" error
	    set ftoc(changed) 0
	    return 1
	}
    } else {
	Msg_CheckPoint		;# Sync unseen and cur message state.
    }
    return $ftoc(changed)
}
proc FtocDialog { changes type } {
    global exwin ftoc
    if [winfo exists $exwin(mtext).commit] {
	destroy $exwin(mtext).commit
    }
    set f [frame $exwin(mtext).commit -class Dialog -bd 4 -relief ridge]
    set blurb [expr {($changes > 1) ? "are $changes changes" : "is one change"}]
    Widget_Message $f msg -text \
"There $blurb pending.
(Press Return to Commit)
(Press <Control-c> to Cancel)" -aspect 1000
    set but [Widget_Frame $f but Dialog {top expand fill} -bd 10]
    set ftoc(okToCommit) 0
    Widget_AddBut $but cancel "Cancel" {set ftoc(okToCommit) 0}
    Widget_AddBut $but ok "Commit and $type" {set ftoc(okToCommit) 1}
    focus $but
    bind $but <Return> "$but.ok flash ; $but.ok invoke"
    bind $but <KP_Enter> "$but.ok flash ; $but.ok invoke"
    bind $but <Control-c> "$but.cancel flash ; $but.cancel invoke"
    Widget_PlaceDialog $exwin(mtext) $exwin(mtext).commit
    Visibility_Wait $but
    catch {grab $but}
    tkwait variable ftoc(okToCommit)
    catch {grab release $but}
    destroy $exwin(mtext).commit
    return $ftoc(okToCommit)
}

proc Ftoc_Iterate { lineVar body } {
    global ftoc
    upvar $lineVar line
    catch {
	if {$ftoc(curLine) != {}} {
	    set line $ftoc(curLine)
	    uplevel 1 $body
	} elseif {!$ftoc(pickone)} {
	    foreach line $ftoc(lineset) {
		uplevel 1 $body
	    }
	}
    }
}
proc Ftoc_Unmark {} {
    global ftoc

    set hits 0
    Ftoc_Iterate line {
	if [FtocUnmarkInner $line] { incr hits }
    }
    Exmh_Status "Unmarked $hits msgs"
    incr ftoc(changed) -$hits
}
proc FtocUnmarkInner { line {all 0}} {
    global exwin
    set res 0
    if {$all} {
	set pat (deleted|moved|drange|mrange|copied)
    } else {
	set pat (deleted|moved|drange|mrange)
    }
    foreach tag [$exwin(ftext) tag names $line.0] {
	if [regexp $pat $tag] {
	    $exwin(ftext) tag remove $tag $line.0 $line.end
	    if [regexp {(drange|mrange|crange)} $tag] {
		eval $exwin(ftext) tag add range $line.0 $line.end
	    }
	    set res 1
	}
    }
    return $res
}
proc Ftoc_Delete { line msgid } {
    global exwin ftoc
    $exwin(ftext) configure -state normal
    $exwin(ftext) delete $line.0 "$line.end + 1 chars"
    $exwin(ftext) configure -state disabled
    set ftoc(displayDirty) 1
    Ftoc_ClearMsgCache
}
proc Ftoc_RemoveMark { line msgid } {
    # Flag the current message(s) for deletion
    global ftoc exwin
    if ![FtocUnmarkInner $line 1] {
	incr ftoc(changed)
    }

    if {$ftoc(pickone)} {
	$exwin(ftext) tag add deleted $line.0 $line.end
    } else {
	$exwin(ftext) tag remove range $line.0 $line.end
	$exwin(ftext) tag add drange $line.0 $line.end
    }
}
proc Ftoc_MoveMark { line msgid } {
    global ftoc exwin exmh
    if ![FtocUnmarkInner $line] {
	incr ftoc(changed)
    }
    # This tag records the target folder
    $exwin(ftext) tag add [list moved $exmh(target)] $line.0 $line.end

    if {$ftoc(pickone)} {
	$exwin(ftext) tag add moved $line.0 $line.end
    } else {
	$exwin(ftext) tag remove range $line.0 $line.end
	$exwin(ftext) tag add mrange $line.0 $line.end
    }
}
proc Ftoc_CopyMark { line msgid } {
    global ftoc exwin exmh
    if ![FtocUnmarkInner $line] {
	incr ftoc(changed)
    }
    # This tag records the target folder
    $exwin(ftext) tag add [list copied $exmh(target)] $line.0 $line.end

    if {$ftoc(pickone)} {
	$exwin(ftext) tag add moved $line.0 $line.end
    } else {
	$exwin(ftext) tag remove range $line.0 $line.end
	$exwin(ftext) tag add mrange $line.0 $line.end
    }
}
proc Ftoc_Commit { rmmCommit moveCommit copyCommit } {
    global ftoc exwin

    # Disable operations on ranges
    Ftoc_RangeUnHighlight
    if {! $ftoc(pickone)} {
	Buttons_Range 0
	set ftoc(lineset) {}
	set ftoc(pickone) 1
    }

    Exmh_Status "Committing $ftoc(changed) changes..."
    $exwin(ftext) configure -state normal
    FtocCommit deleted $rmmCommit
    FtocCommit moved $moveCommit $copyCommit
    $exwin(ftext) configure -state disabled
    set l $ftoc(curLine)
    if {$l == {}} {
	set l $ftoc(numMsgs)
    }
    if {$l > 0} {
	WidgetTextYview $exwin(ftext) $l
    }
    if {! [Ftoc_Changes {} noautocommit]} {
	Exmh_Status "ok"
    }
}
proc FtocCommit {tagname commitProc {copyCommitProc {}} } {
    global ftoc exmh exwin msg

    set delmsgs {}
    set curid [file tail $msg(path)]
    set pairs [FtocMakeReversePairs [$exwin(ftext) tag ranges $tagname]]
    foreach range $pairs {
	set c0 [lindex $range 0]
	set ce [lindex $range 1]
	scan $c0 "%d" L
	set msgid [Ftoc_MsgNumber $L]
	set F {}
	set delline 0	;# Nuke display line
	foreach tag [$exwin(ftext) tag names $c0] {
	    if {([llength $tag] == 2) && ([lindex $tag 0] == "moved")} {
		set F [lindex $tag 1]
		# Build up a list of moved messages
		# Note that the original order of the messages is maintained,
		# (We are going from bottom to top thru the display.)
		# The scan lines are reversed, which is handled by Scan_Move.
		if ![info exists movemsgs($F)] {
		    set movemsgs($F) $msgid
		} else {
		    set movemsgs($F) [concat $msgid " " $movemsgs($F)]
		}
		lappend movescan($F) [$exwin(ftext) get $c0 "$ce + 1 chars"]
		set delline 1
	    }
	    if {([llength $tag] == 2) && ([lindex $tag 0] == "copied")} {
		set F [lindex $tag 1]
		# Build up a list of moved messages
		# Note that the original order of the messages is maintained,
		# (We are going from bottom to top thru the display.)
		# The scan lines are reversed, which is handled by Scan_Move.
		if ![info exists copymsgs($F)] {
		    set copymsgs($F) $msgid
		} else {
		    set copymsgs($F) [concat $msgid " " $copymsgs($F)]
		}
		lappend movescan($F) [$exwin(ftext) get $c0 "$ce + 1 chars"]
	    }
	}
	if {$tagname == "deleted"} {
	    # Batch up deletes
	    lappend delmsgs $msgid
	    set delline 1
	}
	Flist_MsgSeen $msgid	;# in case deleted or moved w/out viewing
	if {$delline} {
	    Msg_UnSeen $msgid	;# avoid MH mark bug
	    $exwin(ftext) delete $c0 "$ce + 1 chars"
	    set ftoc(displayDirty) 1
	    Ftoc_ClearMsgCache
	    if {$msgid == $curid} {
		Ftoc_ClearCurrent
		Msg_ClearCurrent
	    }
	    if {$L == $ftoc(curLine)} {
		set ftoc(curLine) {}
	    } elseif {$ftoc(curLine) != {}} {
		if {$L < $ftoc(curLine)} {
		    incr ftoc(curLine) -1
		    if {$ftoc(curLine) == 0} {
			set ftoc(curLine) {}
		    }
		}
	    }
	    incr ftoc(numMsgs) -1
	} else {
	    FtocUnmarkInner $L
	}
	incr ftoc(changed) -1
    }
    if {$delmsgs != {}} {
	Exmh_Status "$commitProc $delmsgs"
	if [catch {
	    BgAction "Rmm $exmh(folder)" $commitProc $exmh(folder) $delmsgs
	} err] {
	    Exmh_Status $err error
	}
    }
    # Do copies before links so you can both move and copy a message.
    if {[catch {array names copymsgs} flist] == 0} {
	foreach f $flist {
	    Exmh_Status "Copying to $f, $copymsgs($f)"
	    if [catch {
		BgAction "Refile $f" $copyCommitProc $exmh(folder) $copymsgs($f) $f
	    } err] {
		Exmh_Status $err error
	    }
	}
    }
    if {[catch {array names movemsgs} flist] == 0} {
	foreach f $flist {
	    Exmh_Status "Refiling to $f, $movemsgs($f)"
	    if [catch {
		BgAction "Refile $f" $commitProc $exmh(folder) $movemsgs($f) $f
	    } err] {
		Exmh_Status $err error
	    }
	}
    }
}
proc FtocMakePairs { list } {
    set result {}
    for {set i 0} {$i < [expr [llength $list]-1]} {incr i +2} {
	set first [lindex $list $i]
	set second [lindex $list [expr $i+1]]
	lappend result [list $first $second]
    }
    if {$result == {}} {
	return $list
    } else {
	return $result
    }
}
proc FtocMakeReversePairs { list } {
    set result {}
    for {set i [expr [llength $list]-1]} {$i >= 0} {incr i -2} {
	set second [lindex $list $i]
	set first [lindex $list [expr $i-1]]
	lappend result [list $first $second]
    }
    if {$result == {}} {
	return $list
    } else {
	return $result
    }
}

proc Ftoc_MoveFeedback { msgid line } {
    global exwin ftoc
    set msg [Exmh_OldStatus]
    if {[string compare $line "last"] == 0} {
	set line $ftoc(numMsgs)
    } elseif {[string compare $line first] == 0} {
	set line 1
    }
    foreach tag [$exwin(ftext) tag names $line.0] {
	if [regexp {moved (.+)} $tag match folder] {
	    Exmh_Status "$msgid => +$folder"
	    return
	} elseif [regexp deleted $tag] {
	    Exmh_Status "$msgid Pending Delete"
	    return
	}
    }
    Exmh_Status $msg
}
proc Ftoc_FindNext {} {
    Find_It forw
}
proc Ftoc_FindPrev {} {
    Find_It back
}
proc Ftoc_FindAll {string} {
    global exwin find ftoc
    if {[string length $string] == 0} {
	Exmh_Status "No search string" warn
	return -1
    }
    set msgids {}
    for {set L 1} 1 {incr L} {
	if [$exwin(ftext) compare $L.end >= end] {
	    break
	}
	if [catch {$exwin(ftext) get $L.0 $L.end} text] {
	    break
	}
	if [regexp -nocase -- $string $text] {
	    lappend msgids [Ftoc_MsgNumberRaw $text]
	}
    }
    if {[llength $msgids] == 0} {
	Exmh_Status "No match" warn
	return 0
    } else {
	Ftoc_PickMsgs $msgids 0
	return 1
    }

}
proc Ftoc_FindMatch {L string} {
    global exwin ftoc
    if {$L == $ftoc(lasthit)} {
	return 0
    }
    if [catch {$exwin(ftext) get $L.0 $L.end} text] {
	return -1	;# off the end or beginning
    }
    if [regexp -nocase -- $string $text] {
	set ftoc(lasthit) $L
	Msg_Pick $L show
	return 1
    }
    return 0
}
proc Ftoc_Yview {args} {
    global exwin
    eval {WidgetTextYview $exwin(ftext)} $args
}
proc Ftoc_Advance { advance } {
    global ftoc
    if {[string compare $advance "advance?"] == 0} {
	return $ftoc(linkAdvance)
    } else {
	return $advance
    }
}
proc Ftoc_PageUp {} {
    global exwin
    Widget_TextPageUp $exwin(ftext)
}
proc Ftoc_PageDown {} {
    global exwin
    Widget_TextPageDown $exwin(ftext)
}

proc Ftoc_Sort {} {
    global ftoc
    case $ftoc(autoSortType) {
	{date} { Folder_Sort -datefield date }
	{subject} { Folder_Sort -textfield subject }
	{sender} { Folder_Sort -textfield from }
	{custom} { eval Folder_Sort $ftoc(autoSortCrit) }
    }
}
proc Ftoc_SelectAll {} {
    global ftoc
    FtocRangeStart 1
    FtocRangeEnd $ftoc(numMsgs)
}
proc Ftoc_SelectAllToEnd {} {
    global ftoc
    if {$ftoc(curLine) != {}} {
      FtocRangeStart $ftoc(curLine)
    } else {
      if {$ftoc(direction) == "next"} {
        FtocRangeStart 1
      } else {
        FtocRangeStart $ftoc(numMsgs)
      }
    }
    if {$ftoc(direction) == "next"} {
      FtocRangeEnd $ftoc(numMsgs)
    } else {
      FtocRangeEnd 1
    }
}
proc Ftoc_CatchUp {} {
    global ftoc
    Ftoc_SelectAll
    Msg_Remove
    Folder_Commit
    Msg_PageOrNext
}
proc Ftoc_CatchUpToEnd {} {
    global ftoc
    Ftoc_SelectAllToEnd
    Msg_Remove
    Folder_Commit
    Msg_PageOrNext
}
#
# Interface to Drag & Drop
#
set ftocDrag(types) {foldermsg}
set ftocDrag(formats) {string filename}
set ftocDrag(format,foldermsg) string
set ftocDrag(format,filename) string
set ftocDrag(type,string) foldermsg

# Drag Selected
proc FtocDragSelectOld {w x y wx wy} {
	global exmh ftoc

        set folder $ftoc(folder)
        if !$ftoc(displayValid) {
            set folder $exmh(folder)
        }
	set line [lindex [split [$w index cur] .] 0]
	set msg [Ftoc_MsgNumber $line]
	if {$msg == {} || $msg == 0} return

	# Hand off to Drag code
	global ftocDrag mhProfile
	set ftocDrag(source) $w
	set ftocDrag(data,foldermsg) "+$folder $msg"
	set ftocDrag(data,filename) $mhProfile(path)/$folder/$msg
	Drag_Source ftocDrag $x $y
}
proc FtocDragSelect {w x y wx wy} {
    global exmh ftoc ftocDrag mhProfile

    set folder $ftoc(folder)
    if !$ftoc(displayValid) {
        set folder $exmh(folder)
    }
    set msgs {}
    if $ftoc(pickone) {
	set line [lindex [split [$w index cur] .] 0]
	set msgs [Ftoc_MsgNumber $line]
	if {$msgs == {} || $msgs == 0} return
	set ftocDrag(data,filename) $mhProfile(path)/$folder/$msgs
    } else {
	foreach line $ftoc(lineset) {
	    set msgid [Ftoc_MsgNumber $line]
	    if {$msgid != {}} {
		lappend msgs $msgid
	    }
	}
    	catch {unset ftocDrag(data,filename)}
    }

    # Hand off to Drag code
    set ftocDrag(source) $w
    set ftocDrag(data,foldermsg) "+$folder $msgs"
    Drag_Source ftocDrag $x $y
}
proc FtocToggleSequence { sequencename } {
    global ftoc exmh
    set folder $exmh(folder)
    set sequence [Mh_Sequence $folder $sequencename]
    # If any selected message is not in the sequence, then add to the sequence.
    # If none are in the sequence, then remove from the sequence.
    set flag del
    set msgs {}
    Ftoc_Iterate line {
	set msgid [Ftoc_MsgNumber $line]	
	if {[lsearch -exact $sequence $msgid] == -1} {
	    set flag add
	}
	lappend msgs $msgid
    }
    if {$msgs != {}} {
	Mh_SequenceUpdate $folder $flag $sequencename $msgs
	Ftoc_ShowSequences $folder
    }
}
