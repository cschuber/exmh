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
    set ftoc(displayValid) 1		;# 0 => pick results, not full scan
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
    set ftoc(curLine) $msgid		;# current display line number
    Ftoc_ClearMsgCache
}
proc Ftoc_Update { numMsgs } {
    # Update size of message list after inc'ing into current folder
    global ftoc
    Exmh_Debug Ftoc_Update $ftoc(folder) has $numMsgs msgs (was $ftoc(numMsgs))
    if {$numMsgs > $ftoc(numMsgs)} {
	set msgids {}
	set lineno $ftoc(numMsgs)
	while {$lineno < $numMsgs} {
	    incr lineno
	    lappend msgids [Ftoc_MsgNumber $lineno]
	}
	Ftoc_ShowSequences $msgids
    }
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
proc FtocRangeStart { lineno } {
    # For normal button-down "start a selection"
    global ftoc
    Ftoc_RangeUnHighlight
    set ftoc(pickstart) $lineno
    set ftoc(pickend) $lineno
    set ftoc(pickstate) new
    set ftoc(extend) 0
    Ftoc_RangeHighlight $lineno $lineno
}
proc FtocRangeAdd { lineno } {
    # For shift-select "add to selection"
    global ftoc
    set ftoc(pickstart) $lineno
    set ftoc(pickend) $lineno
    set ftoc(pickstate) invert
    set ftoc(extend) 0
    FtocRangeInvert $lineno $lineno
}
proc FtocRangeEnd { {lineno {}} {addcurrent 0} } {
    # For end of button sweep
    global ftoc exwin
    catch {unset ftoc(extend)}
    if ![info exists ftoc(pickend)] {
	# Spurious button-release event
	return
    }
    if {($lineno == $ftoc(pickstart)) && !$addcurrent} {
	# regular button click optimization
	unset ftoc(pickend)
	Msg_Pick $lineno show
	return
    }
    if {$lineno != {}} {
	FtocRangeExtend $lineno
    }
    FtocPickRange $addcurrent
    catch {unset ftoc(pickend)}
}
proc Ftoc_PickMsgs { msgids addtosel } {
    # For adding to the selection by message number
    global ftoc
    Exmh_Status "Marking [llength $msgids] hits"
    Ftoc_LinesHighlight [Ftoc_FindMsgs $msgids]
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
proc FtocRangeExtend { lineno } {
    global ftoc
    if ![info exists ftoc(pickend)] {
	return
    }
    if {$lineno <= 0} {
	set lineno 1
    }
    if {$lineno > $ftoc(numMsgs)} {
	set lineno $ftoc(numMsgs)
    }
    if {$lineno == $ftoc(pickend)} {
	# Invariant, previously defined selection is fine.
	return
    }
    if {$lineno == 0} {
	# no messages in folder
	return
    }
    if {$ftoc(pickstate) != "invert"} {
	if {$ftoc(pickstart) < $ftoc(pickend)} {
	    # Growing downward
	    if {$lineno > $ftoc(pickend)} {
		Ftoc_RangeHighlight [expr $ftoc(pickend)+1] $lineno
	    } else {
		if {$lineno < $ftoc(pickstart)} {
		    if {$ftoc(pickstart) != $ftoc(pickend)} {
			# Change direction
			FtocRangeClear [expr $ftoc(pickstart)+1] \
					$ftoc(pickend)
		    }
		    Ftoc_RangeHighlight [expr $ftoc(pickstart)-1] $lineno
		} else {
		    # Shrink selection
		    FtocRangeClear [expr $lineno+1] $ftoc(pickend)
		}
	    }
	} else {
	    # Growing upward
	    if {$lineno < $ftoc(pickend)} {
		Ftoc_RangeHighlight [expr $ftoc(pickend)-1] $lineno
	    } else {
		if {$lineno > $ftoc(pickstart)} {
		    if {$ftoc(pickstart) != $ftoc(pickend)} {
			# Change direction
			FtocRangeClear [expr $ftoc(pickstart)-1] \
					$ftoc(pickend)
		    }
		    Ftoc_RangeHighlight [expr $ftoc(pickstart)+1] $lineno
		} else {
		    # Shrink selection
		    FtocRangeClear [expr $lineno-1] $ftoc(pickend)
		}
	    }
	}
    } else {
	if {$ftoc(pickstart) < $ftoc(pickend)} {
	    # Growing downward
	    if {$lineno > $ftoc(pickend)} {
		FtocRangeInvert [expr $ftoc(pickend)+1] $lineno
	    } else {
		if {$lineno < $ftoc(pickstart)} {
		    if {$ftoc(pickstart) != $ftoc(pickend)} {
			# Change direction
			FtocRangeInvert [expr $ftoc(pickstart)+1] \
					$ftoc(pickend)
		    }
		    FtocRangeInvert [expr $ftoc(pickstart)-1] $lineno
		} else {
		    # Shrink selection
		    FtocRangeInvert [expr $lineno+1] $ftoc(pickend)
		}
	    }
	} else {
	    # Growing upward
	    if {$lineno < $ftoc(pickend)} {
		FtocRangeInvert [expr $ftoc(pickend)-1] $lineno
	    } else {
		if {$lineno > $ftoc(pickstart)} {
		    if {$ftoc(pickstart) != $ftoc(pickend)} {
			# Change direction
			FtocRangeInvert [expr $ftoc(pickstart)-1] \
					$ftoc(pickend)
		    }
		    FtocRangeInvert [expr $ftoc(pickstart)+1] $lineno
		} else {
		    # Shrink selection
		    FtocRangeInvert [expr $lineno-1] $ftoc(pickend)
		}
	    }
	}
    }
    set ftoc(pickend) $lineno
}
proc FtocRangeInvert { start end } {
    global exwin
    set win $exwin(ftext)
    if {$start > $end} {
	set tmp $start ; set start $end ; set end $tmp
    }
    for {set lineno $start} {$lineno <= $end} {incr lineno} {
	catch {
	    set newtag range
	    set oldtag {}
	    set nuke 0
	    foreach tag [$win tag names $lineno.0] {
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
		set ix [lsearch $ftoc(lineset) $lineno]
		if {$ix >= 0} {
		    set ftoc(lineset) [lreplace $ftoc(lineset) $ix $ix]
		}
	    }
	    if {$oldtag != {}} {
		$win tag remove $oldtag $lineno.0 $lineno.end
	    }
	    if {$newtag != {}} {
		$win tag add $newtag $lineno.0 $lineno.end
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
    for {set lineno $start} {$lineno <= $end} {incr lineno} {
	set newtag range
	foreach tag [$win tag names $lineno.0] {
	    case $tag {
		{drange deleted} { set newtag drange ;  break; }
		{mrange moved} { set newtag mrange ;  break; }
	    }
	}
	$win tag add $newtag $lineno.0 $lineno.end
    }
}
proc Ftoc_LinesHighlight { linenos } {
    global exwin
    set win $exwin(ftext)
    if {$linenos == {}} {
	return
    }
    WidgetTextYview $exwin(ftext) -pickplace [lindex $linenos 0].0
    update idletasks
    foreach lineno $linenos {
	set newtag range
	foreach tag [$win tag names $lineno.0] {
	    case $tag {
		{drange deleted} { set newtag drange ;  break; }
		{mrange moved} { set newtag mrange ;  break; }
	    }
	}
	$win tag add $newtag $lineno.0 $lineno.end
    }
}
proc FtocRangeClear { start end } {
    global exwin
    set win $exwin(ftext)
    if {$start > $end} {
	set tmp $start ; set start $end ; set end $tmp
    }
    for {set lineno $start} {$lineno <= $end} {incr lineno} {
	catch {
	    set newtag {}
	    set oldtag range
	    foreach tag [$win tag names $lineno.0] {
		case $tag {
		    drange { set newtag deleted ; set oldtag drange; break; }
		    mrange { set newtag moved ; set oldtag mrange; break; }
		    range { break }
		}
	    }
	    $win tag remove $oldtag $lineno.0 $lineno.end
	    if {$newtag != {}} {
		$win tag add $newtag $lineno.0 $lineno.end
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

proc Ftoc_FindMsgs {msgids} {
    global ftoc msgtolinecache
    set linenos {}
    foreach msg $msgids {
	set lineno [Ftoc_FindMsg $msg]
	if {$lineno != {}} {
	    lappend linenos $lineno
	}
    }
    return $linenos
}
proc Ftoc_FindMsg { msgid } {
    global ftoc msgtolinecache
    if {$msgid == {}} {
        return {}
    }
    if {[info exist msgtolinecache($msgid)]} {
        return $msgtolinecache($msgid)
    }
    if !$ftoc(displayValid) {
        #
        # Linear search for pick and thread FTOCs (pseudo-displays)
        #
        for {set lineno 1} {$lineno <= $ftoc(numMsgs)} {incr lineno} {
            if {[Ftoc_MsgNumber $lineno] == $msgid} {
                return $lineno
            }
        }
        return {}
    }

    #
    # Binary search for other FTOCs
    #
    set minlineno 1
    set minmsgid [Ftoc_MsgNumber $minlineno]
    if {$msgid == $minmsgid} {
        return $minlineno
    }
    set maxlineno $ftoc(numMsgs)  ;# Ignore trailing blank line
    set maxmsgid [Ftoc_MsgNumber $maxlineno]
    if {$msgid == $maxmsgid} {
        return $maxlineno
    }
    while (1) {
        if {$msgid > $maxmsgid || $msgid < $minmsgid} {
            Exmh_Status "Cannot find $msgid ($minmsgid,$maxmsgid)" warn
            if {[info exist msgtolinecache($msgid)]} {
                unset msgtolinecache($msgid)
            }
            return {} ;# new message not listed
        }
        if {$maxlineno == $minlineno} {
            if {[info exist msgtolinecache($msgid)]} {
                unset msgtolinecache($msgid)
            }
            return {}   ;# not found
        }
        #set nextlineno [expr int(($maxlineno+$minlineno)/2)]
        # Don't divide in two, guestimate where the line might be instead
        set nextlineno [expr int($minlineno+1+($msgid-$minmsgid)*($maxlineno-$minlineno-2)/($maxmsgid-$minmsgid))]
        set nextmsgid [Ftoc_MsgNumber $nextlineno]
        # Note that a side effect of Ftoc_MsgNumber was to put this entry in 
	# the cache,so we don't have to do it here.
        if {$nextmsgid == $msgid} {
            return $nextlineno
        } elseif {$nextmsgid > $msgid} {
            set maxlineno $nextlineno
            set maxmsgid $nextmsgid
        } elseif {$minlineno == $nextlineno} {
            Exmh_Status "Cannot find $msgid" warn
            if {[info exist msgtolinecache($msgid)]} {
                unset msgtolinecache($msgid)
            }
            return {} ;# new message not listed
        } else {
            set minlineno $nextlineno
            set minmsgid $nextmsgid
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
proc Ftoc_MsgNumbers { linenos } {
    global exwin
    set msgids {}
    foreach lineno $linenos {
	set msgid [Ftoc_MsgNumber $lineno]
	if {$msgid != {}} {
	    lappend msgids $msgid
	}
    }
    return $msgids
}
proc Ftoc_MsgNumber { lineno } {
    global exwin linetomsgcache msgtolinecache
    if {[info exist linetomsgcache($lineno]} {
        return $linetomsgcache($lineno)
    }
    if [catch {$exwin(ftext) get $lineno.0 $lineno.end} line] {
        return {}
    }
    set msgid [Ftoc_MsgNumberRaw $line]
    if {$msgid != {}} {
        set msgtolinecache($msgid) $lineno
        set linetomsgcache($lineno) $msgid
    }
    return $msgid
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
	set lineno [lindex [split $mark1 .] 0]
	lappend lineset $lineno
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
proc Ftoc_NewFtoc {{linenos ftoclineset}} {
    global ftoc
    if {$linenos == "ftoclineset"} {
	set linenos $ftoc(lineset)
    }
    set msgids [Ftoc_MsgNumbers $linenos]
    if {[llength $msgids] <= 1} {
	Exmh_Status "Select more than one message first" warn
	return
    }
    if {[Ftoc_Changes "new ftoc"] == 0} {
	Exmh_Status $msgids
	Scan_ProjectSelection $msgids
    }
}

# Ftoc_ClearCurrent and Ftoc_Change are two parts of
# dinking the ftoc display when advancing a message.

proc Ftoc_ClearCurrent {} {
    # Clear display of current message
    global ftoc exwin
    set ftoc(pickone) 1
    set ftoc(lineset) {}
    
    if {$ftoc(curLine) == {}} {
	set ftoc(curLine) [Mh_Cur $ftoc(folder)]
    }
    if {$ftoc(curLine) != {}} {
	$exwin(ftext) tag remove cur $ftoc(curLine).0 $ftoc(curLine).end
	Ftoc_RescanLine $ftoc(curLine)
    }
    return $ftoc(curLine)
}
proc Ftoc_Change { lineno {show show} } {
    global ftoc exwin mhProfile
    set ftoc(curLine) $lineno
    if {$ftoc(curLine) == {}} {
	set ok 0
    } else {
	if {$show == "show"} {
	    $exwin(ftext) tag remove $mhProfile(unseen-sequence) $ftoc(curLine).0 $ftoc(curLine).end
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
    set seqs [option get . sequences {}]
    foreach seq $seqs {
	eval $w tag configure $seq \
	    [option get . sequence_$seq {}]
	$w tag raise $seq
    }
}

# Highlight a set of messages (or all in the folder) that belong
# to a sequence.  If msgsids is null, then we only work on that
# subset of the folder.  Otherwise we highlight all the messages
# in the folder that are in the sequence.

proc Ftoc_ShowSequence { seq {msgids {}} } {
    global exwin exmh mhProfile
Exmh_Debug Ftoc_ShowSequence $seq msgids $msgids
    set seqids [Seq_Msgs $exmh(folder) $seq]
    if {$msgids != {}} {
	foreach msg $msgids {
	    set lineno [Ftoc_FindMsg $msg]
	    if {$lineno != {}} {
		if {[lsearch -exact $seqids $msg] == -1} {
		    $exwin(ftext) tag remove $seq $lineno.0 $lineno.end
		} else {
		    $exwin(ftext) tag add $seq $lineno.0 $lineno.end
		}
	    }
	}
    } else {
	$exwin(ftext) tag remove $seq 1.0 end
        if {$seq == $mhProfile(unseen-sequence)} {
            FtocShowUnseen $seqids
        } else {
            foreach lineno [Ftoc_FindMsgs $seqids] {
                $exwin(ftext) tag add $seq $lineno.0 $lineno.end
            }
	}
    }
}

proc Ftoc_ShowSequences { {msgids {}} } {
    global exwin exmh
    if {$msgids == {}} {
Exmh_Debug Ftoc_ShowSequences msgids null
	set seqs [option get . sequences {}]
	set hiddenseqs [option get . hiddensequences {}]
	foreach seq $seqs {
	    if {[lsearch -exact $hiddenseqs $seq] == -1} {
		$exwin(ftext) tag remove $seq 1.0 end
	    }
	}
    } else {
Exmh_Debug Ftoc_ShowSequences msgids $msgids
    }
    foreach seq [Mh_Sequences $exmh(folder)] {
        Ftoc_ShowSequence $seq $msgids
    }
}

# This is optimized for the unseen sequence, which tends to
# cluster at the end of a folder, and get big

proc FtocShowUnseen { unseen } {
    global exwin flist
    if {[llength $unseen] > 0} {
Exmh_Debug FtocShowUnseen $unseen
	set end [$exwin(ftext) index end]
	set line [lindex [split $end .] 0]
	set msgNum 0
	for {} {$line > 0} {incr line -1} {
	    set msgNum [Ftoc_MsgNumber $line]
	    set i [lsearch $unseen $msgNum]
	    if {$i >= 0} {
		$exwin(ftext) tag add unseen $line.0 $line.end
		set unseen [lreplace $unseen $i $i]
		if {[llength $unseen] == 0} {
		    return 1
		}
	    }
	}
        # Here is some code from the old Ftoc_ShowUnseen that
        # I don't think we need any more
        if {0} {
          # Repair bogus unseen sequences
          # msgNum is the smallest message number, but it might not be
          # the first message in the folder because of short scans
          # Anything in the unseen sequence above msgNum is probably wrong
          # and can result from races with the background process
          foreach id $unseen {
	    if {$id > $msgNum} {
                # This API doen't exist anymore
		Flist_MsgSeenXXX $id
	    }
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
    global exmh flist ftoc mhProfile
    
    set ftoc(direction) "next"
    if {$ftoc(curLine) == {}} {
	if [Msg_Show $mhProfile(unseen-sequence)] {
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
    global ftoc exmh mhProfile
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
    set folder [Flist_NextUnvisited]
    if {[string length $folder] != 0} {
	if {$ftoc(softChange)} {
	    set ftoc(lastFolder) $exmh(folder)
	    Folder_Change $folder [list Msg_Show $mhProfile(unseen-sequence)]
	    return
	} else {
	    set ftoc(softChange) 1
	    Ftoc_ClearCurrent
	    Msg_ClearCurrent
	    Exmh_Status ""
	    Exmh_Status "End of folder; <Next> => $folder" warn
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
proc Ftoc_Marked { msgid } {
    global ftoc exwin
    if {$ftoc(skipMarked) == 0} {
	return 0	;# Pretend it isn't marked
    }
    set lineno [Ftoc_FindMsg $msgid]
    if {[string length $lineno] == 0} {
	return 1	;# Can't find it, pretend it's marked
    }
    set marked 0
    foreach tag [$exwin(ftext) tag names $lineno.0] {
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

proc Ftoc_CurLines {} {
    global ftoc
    if {$ftoc(curLine) != {}} {
	return $ftoc(curLine)
    } elseif {!$ftoc(pickone)} {
	return $ftoc(lineset);
    } else {
	return {}
    }
}

proc Ftoc_CurMsgs {} {
    Ftoc_MsgNumbers [Ftoc_CurLines]
}

proc Ftoc_Iterate { linenoVar body } {
    global ftoc
    upvar $linenoVar lineno
    foreach lineno [Ftoc_CurLines] {
	uplevel 1 $body
    }
}
proc Ftoc_MsgIterate { msgidVar body } {
    global ftoc
    upvar $msgidVar msgid
    foreach msgid [Ftoc_CurMsgs] {
	uplevel 1 $body
    }
}
proc Ftoc_Unmark {} {
    global ftoc
    
    set hits 0
    Ftoc_Iterate lineno {
	if [FtocUnmarkInner $lineno] { incr hits }
    }
    Exmh_Status "Unmarked $hits msgs"
    incr ftoc(changed) -$hits
}
proc FtocUnmarkInner { lineno {all 0}} {
    global exwin
    set res 0
    if {$all} {
	set pat (deleted|moved|drange|mrange|copied)
    } else {
	set pat (deleted|moved|drange|mrange)
    }
    foreach tag [$exwin(ftext) tag names $lineno.0] {
	if [regexp $pat $tag] {
	    $exwin(ftext) tag remove $tag $lineno.0 $lineno.end
	    if [regexp {(drange|mrange|crange)} $tag] {
		eval $exwin(ftext) tag add range $lineno.0 $lineno.end
	    }
	    set res 1
	}
    }
    return $res
}
proc Ftoc_Delete { lineno } {
    global exwin ftoc
    $exwin(ftext) configure -state normal
    $exwin(ftext) delete $lineno.0 "$lineno.end + 1 chars"
    $exwin(ftext) configure -state disabled
    set ftoc(displayDirty) 1
    Ftoc_ClearMsgCache
}
proc Ftoc_RemoveMark { lineno } {
    # Flag the current message(s) for deletion
    global ftoc exwin
    if ![FtocUnmarkInner $lineno 1] {
	incr ftoc(changed)
    }
    
    if {$ftoc(pickone)} {
	$exwin(ftext) tag add deleted $lineno.0 $lineno.end
    } else {
	$exwin(ftext) tag remove range $lineno.0 $lineno.end
	$exwin(ftext) tag add drange $lineno.0 $lineno.end
    }
}
proc Ftoc_MoveMark { lineno } {
    global ftoc exwin exmh
    if ![FtocUnmarkInner $lineno] {
	incr ftoc(changed)
    }
    # This tag records the target folder
    $exwin(ftext) tag add [list moved $exmh(target)] $lineno.0 $lineno.end
    
    if {$ftoc(pickone)} {
	$exwin(ftext) tag add moved $lineno.0 $lineno.end
    } else {
	$exwin(ftext) tag remove range $lineno.0 $lineno.end
	$exwin(ftext) tag add mrange $lineno.0 $lineno.end
    }
}
proc Ftoc_CopyMark { lineno } {
    global ftoc exwin exmh
    if ![FtocUnmarkInner $lineno] {
	incr ftoc(changed)
    }
    # This tag records the target folder
    $exwin(ftext) tag add [list copied $exmh(target)] $lineno.0 $lineno.end
    
    if {$ftoc(pickone)} {
	$exwin(ftext) tag add moved $lineno.0 $lineno.end
    } else {
	$exwin(ftext) tag remove range $lineno.0 $lineno.end
	$exwin(ftext) tag add mrange $lineno.0 $lineno.end
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
    global ftoc exmh exwin msg mhProfile
    
    set delmsgs {}
    set curid [file tail $msg(path)]
    set pairs [FtocMakeReversePairs [$exwin(ftext) tag ranges $tagname]]
    foreach range $pairs {
	set c0 [lindex $range 0]
	set ce [lindex $range 1]
	scan $c0 "%d" lineno
	set msgid [Ftoc_MsgNumber $lineno]
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
	Seq_Del $exmh(folder) $mhProfile(unseen-sequence) $msgid	;# in case deleted or moved w/out viewing
	if {$delline} {
	    $exwin(ftext) delete $c0 "$ce + 1 chars"
	    set ftoc(displayDirty) 1
	    Ftoc_ClearMsgCache
	    if {$msgid == $curid} {
		Ftoc_ClearCurrent
		Msg_ClearCurrent
	    }
	    if {$lineno == $ftoc(curLine)} {
		set ftoc(curLine) {}
	    } elseif {$ftoc(curLine) != {}} {
		if {$lineno < $ftoc(curLine)} {
		    incr ftoc(curLine) -1
		    if {$ftoc(curLine) == 0} {
			set ftoc(curLine) {}
		    }
		}
	    }
	    incr ftoc(numMsgs) -1
	} else {
	    FtocUnmarkInner $lineno
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

proc Ftoc_MoveFeedback { msgid } {
    global exwin ftoc
    set lineno [Ftoc_FindMsg $msgid]
    set msg [Exmh_OldStatus]
    foreach tag [$exwin(ftext) tag names $lineno.0] {
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
proc FtocDragSelect {w x y wx wy} {
    global exmh ftoc ftocDrag mhProfile
    
    set folder $ftoc(folder)
    if !$ftoc(displayValid) {
	set folder $exmh(folder)
    }
    if $ftoc(pickone) {
	set lineno [lindex [split [$w index cur] .] 0]
	set msgids [Ftoc_MsgNumber $lineno]
	if {$msgids == {} || $msgids == 0} return
	set ftocDrag(data,filename) $mhProfile(path)/$folder/$msgids
    } else {
	set msgids [Ftoc_MsgNumber $ftoc(lineset)]
	catch {unset ftocDrag(data,filename)}
    }
    
    # Hand off to Drag code
    set ftocDrag(source) $w
    set ftocDrag(data,foldermsg) "+$folder $msgids"
    Drag_Source ftocDrag $x $y
}
proc FtocToggleSequence { seq } {
    global ftoc exmh
    set folder $exmh(folder)
    set origmsgids [Seq_Msgs $folder $seq]
    set selmsgids [Ftoc_CurMsgs]
    if {$selmsgids == {}} {
	Exmh_Status "No messages were selected"
    } else {
	# If any selected message is not already in the sequence, then add 
	#   messages to the sequence.
	# If all selected messages are already in the sequence, then remove
	#   messages from the sequence.
	set flag del
	foreach msgid $selmsgids {
	    if {[lsearch -exact $origmsgids $msgid] == -1} {
		set flag add
	    }
	}
	if {$flag == "del"} {
	    Seq_Del $folder $seq $selmsgids
	} else {
	    Seq_Add $folder $seq $selmsgids
	}
	Ftoc_ShowSequence $seq $selmsgids
    }
}

# exmh-2.5 APIs
# Ftoc_ColorConfigure
# Ftoc_MarkSeen
# Ftoc_ShowUnseen
