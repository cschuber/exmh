#
# sequences.tcl
#
# Routines for handling sequences.  Based on and generalized from the
# old code for dealing with the unseen sequence which was in either
# flist.tcl or mh.tcl. (or both!)

proc Seq_Init {} {
    global flist seqwin
    Preferences_Add "Sequences Window" \
	"The sequences window, if enabled, shows lists by sequence of
folders with messages in that sequence with a count of messages.
Options exist to control its size (which in turn controls its behavior
as entries are inserted or removed and also to control the action that
will occur if you click in the window)." \
  {
    { seqwin(on) seqWinOn OFF {Enable Sequence Window}
"Enables the sequence window."
    }

    { seqwin(icon) seqWinIcon OFF {Icon Window}
"Tries to tell the window manager to use the sequence window as
exmh's icon.
Note: doesn't work with all window managers."
    }

    { seqwin(orientation) seqWinOrientation
      {CHOICE Horizontal Vertical}
      {Orientation}
"The orientation of the sequence panels in the sequences window."
    }

    { seqwin(minlines) seqWinMinLines 3 {Minimum Entry Lines}
"The minimum number of entries that the sequence window will show.
This controls the minimum height that the sequence window will adopt."
    }

    { seqwin(maxlines) seqWinMaxLines 10 {Maximum Entry Lines}
"The maximum number of entries that the sequence window will show.

If set and the size of the entries exceeds the maximum,
scanning (using button 2) is enabled in the window.

If left blank (or set to a value less than the minimum),
the icon window will always grow to accomodate the current
number of entries."
    }

    { seqwin(minwidth) seqWinMinNameWidth 11 {Minimum Name Width}
"The minimum number of characters that will be used
for the folder name.  This in turn controls the minimum
width that the sequence window will adopt."
    }

    { seqwin(maxwidth) seqWinMaxNameWidth 20 {Maximum Name Width}
"The maximum number of characters that will be used
for the folder name.

If set and a folders name exceeds the width, it is cropped
to display just the last characters preceeded by ellipsis such
that it doesn't exceed the given width.

If left blank (or set to a value less than the minimum width),
the sequence window will always grow to accomodate the maximum
folder width."
    }

    { seqwin(font) seqWinFont 6x10 {Font}
"The font to use in the sequence window."
    }

    { seqwin(nevershow) seqNeverShow {cur} {Never Show Sequences}
"Sequences to never display in the sequences window."
    }

    { seqwin(alwaysshow) seqAlwaysShow {} {Always Show Sequences}
"Sequences to always display, even when they're empty."
    }

    { seqwin(hidewhenempty) seqWinHideWhenEmpty OFF {Hide When Empty}
"The sequence window will only be displayed when there are messages to
display.

Note: if \"Always Show Sequences\" is non-empty, this option has no effect."
    }

    { seqwin(emptymsg) seqWinEmptyMsg {None} {Empty Message}
"The message to display in the sequence window when there are
no messages to display.

Note: if \"Always Show Sequences\" is empty, this option has no effect."
    }

    { seqwin(b1mode) seqWinButton1
      {CHOICE None Raise Warp {Warp & Show} {Warp & Narrow} Inc Compose}
      {Button 1 Mode}
"The behavior when you click on the sequence window depends
on this setting.

None:          Nothing
Raise:         Bring the main window to the front
               (deiconifying if necessary)
Warp:          Raise, then change to the folder clicked on
Warp & Show:   Warp, then select the first message in the sequence
Warp & Narrow: Warp, then list only the messages in the sequence
Inc:           Just like clicking the Inc button
Compose:       Starts a mail composition"
    }

    { seqwin(b2mode) seqWinButton2
      {CHOICE None Raise Warp {Warp & Show} {Warp & Narrow} Inc Compose}
      {Button 2 Mode}
"The behavior when you press mouse button 2 depends on
this setting.


None:          Nothing
Raise:         Bring the main window to the front
               (deiconifying if necessary)
Warp:          Raise, then change to the folder clicked on
Warp & Show:   Warp, then select the first message in the sequence
Warp & Narrow: Warp, then list only the messages in the sequence
Inc:           Just like clicking the Inc button
Compose:       Starts a mail composition"
    }

    { seqwin(b3mode) seqWinButton3
      {CHOICE None Raise Warp {Warp & Show} {Warp & Narrow} Inc Compose}
      {Button 3 Mode}
"The behavior when you press mouse button 3 depends on
this setting.

None:          Nothing
Raise:         Bring the main window to the front
               (deiconifying if necessary)
Warp:          Raise, then change to the folder clicked on
Warp & Show:   Warp, then select the first message in the sequence
Warp & Narrow: Warp, then list only the messages in the sequence
Inc:           Just like clicking the Inc button
Compose:       Starts a mail composition"
    }

    { seqwin(mb1mode) seqWinModifiedButton1
      {CHOICE None Raise Warp {Warp & Show} {Warp & Narrow} Inc Compose}
      {Modified Button 1 Mode}
"The behavior when you shift-click, control-click or
shift-contol-click on the sequence window depends
on this setting.

None:          Nothing
Raise:         Bring the main window to the front
               (deiconifying if necessary)
Warp:          Raise, then change to the folder clicked on
Warp & Show:   Warp, then select the first message in the sequence
Warp & Narrow: Warp, then list only the messages in the sequence
Inc:           Just like clicking the Inc button
Compose:       Starts a mail composition"
    }
  }
}

proc Seq_TraceInit {} {
    global flist seqwin

    trace variable seqwin(on) w SeqWinToggle
    trace variable seqwin(nevershow) w SeqWinFixShowList
    trace variable seqwin(alwaysshow) w SeqWinFixShowList
    trace variable seqwin(orientation) w SeqWinFixOrientation

    SeqWin_Init

    trace variable flist wu Seq_Trace
}
proc Seq_Trace {array elem op} {
    global flist seqwin mhProfile
Exmh_Debug "Seq_Trace $array $elem $op"
    set indices [split $elem ,]
    set var [lindex $indices 0]
    if {$var == {seqcount}} {
	set folder [lindex $indices 1]
	set seq [lindex $indices 2]
	if {![info exists flist(seqcount,$folder,$seq)]} {
	    set flist(seqcount,$folder,$seq) 0
	}
	if [info exists flist($elem)] {
	    set num $flist($elem)
	} else {
	    set num 0
	}
	if [info exists flist(oldseqcount,$folder,$seq)] {
	    set oldnum $flist(oldseqcount,$folder,$seq)
	} else {
	    set oldnum 0
	}
	set flist(oldseqcount,$folder,$seq) $num
	set delta [expr {$num - $oldnum}]
	if {$delta != 0} {
	    Exmh_Debug $folder has $num msgs in $seq (delta: $delta)
	}
	if {$num > 0} {
	    if [info exists flist($seq)] {
		if {[lsearch $flist($seq) $folder] < 0} {
		    lappend flist($seq) $folder
		}
	    } else {
		set flist($seq) $folder
	    }
	} else {
	    if [info exists flist($seq)] {
		set ix [lsearch $flist($seq) $folder]
		if {$ix >= 0} {
		    set flist($seq) [lreplace $flist($seq) $ix $ix]
		}
	    } else {
		set flist($seq) {}
	    }
	}
	if {$delta != 0} {
	    if {[info exists flist(totalcount,$seq)]} {
		incr flist(totalcount,$seq) $delta
	    } else {
		set flist(totalcount,$seq) $delta
	    }
	}
	if {$seqwin(on)} {
	    BgRPC SeqWinUpdate $seq $folder $num
	}
    } elseif {$var == {totalcount}} {
	set seq [lindex $indices 1]
#	if [info exists flist($seq)] {
#	    Exmh_Debug "$flist(totalcount,$seq) $seq msgs in [llength $flist($seq)] folders ($flist($seq))"
#	} else {
#	    Exmh_Debug "$flist(totalcount,$seq) $seq msgs in no folders"
#	}
	if {$flist(totalcount,$seq) <  0} {
	    Exmh_Status "$flist(totalcount,$seq) $seq!"
	    set flist(totalcount,$seq) 0
	}
	if {$seqwin(on)} {
	    BgRPC SeqWinShowSeqPane $seq
	}
    }
}

# Reset the cached state about sequences because the user
# has just packed, sorted, or threaded the folder.
# This should be followed shortly by a call to Seq_Msgs
#
# Don't call gratitiously because it confuses the sequences window.

proc Seq_Forget {folder seq} {
    global flist
    Mh_SequenceUpdate $folder clear $seq
    set flist(seq,$folder,$seq) {}
    set flist(seqcount,$folder,$seq) 0
    set ix [lsearch $flist($seq) $folder]
    if {$ix >= 0} {
	set flist($seq) [lreplace $flist($seq) $ix $ix]
    }
}

# Add messages to the list for a given folder.
# This has to be careful about already known unseen messages
# and messages that have been read but not committed as read.
proc Seq_Add {folder seq msgids} {
    global flist exmh mhProfile
    Exmh_Debug Seq_Add $folder $seq $msgids
#   eval {MhExec mark +$folder -seq $seq} $msgids
    Mh_SequenceUpdate $folder add $seq $msgids
    set msgids [MhSeqExpand $folder $msgids]
    # Check overlap with already seen msgs and unseen messages already known
    if [info exists flist(seq,$folder,$seq)] {
	if [info exists flist(seqcount,$folder,$seq)] {
	    set new $flist(seqcount,$folder,$seq)
	} else {
	    set new 0
	}
    } else {
	set flist(seq,$folder,$seq) {}
	set new 0
    }
    set known $flist(seq,$folder,$seq)
    # Subtract elements of $known from $msgids
  Exmh_Debug Seq_Add list diff [time {
    if {[llength $known] > [llength $msgids]} {
	set nmsgids {}
	foreach id $msgids {
	    if {[lsearch $known $id] < 0} {
		lappend nmsgids $id
	    }
	}
	set msgids $nmsgids
    } else {
	foreach id $known  {
	    set ix [lsearch $msgids $id]
	    if {$ix >= 0} {
		set msgids [lreplace $msgids $ix $ix]
	    }
	}
    }
  } 1]
    set num [llength $msgids]
    if {$num <= 0} {
	return
    }
    set flist(seqcount,$folder,$seq) [expr $new + $num]
    set flist(seq,$folder,$seq) [concat $flist(seq,$folder,$seq) $msgids]
    if {[lsearch $flist($seq) $folder] < 0} {
	lappend flist($seq) $folder
    }
    if {$seq == $mhProfile(unseen-sequence)} {
	if {[string compare $folder $exmh(folder)] != 0 &&
	    [lsearch $flist(unvisited) $folder] < 0} {
	    lappend flist(unvisitedNext) $folder
	}
	Fdisp_HighlightUnseen $folder
    }
}

# Set the contents of a sequence for a folder.
# This no longer synchronizes with the file system -
# use Mh_SequenceUpdate explicitly for that.

proc Seq_Set {folder seq msgids} {
    global flist exmh mhProfile
#    catch {MhExec mark +$folder $msgids -seq $seq -zero}
#    Mh_SequenceUpdate $folder replace $seq $msgids
    if [info exists flist(seqcount,$folder,$seq)] {
	set oldnum $flist(seqcount,$folder,$seq)
    } else {
	set oldnum 0
    }
    set newnum [llength $msgids]
    if {$newnum <= 0} {
	set flist(seqcount,$folder,$seq) 0
	set flist(seq,$folder,$seq) {}
	return
    }
    set flist(seqcount,$folder,$seq) $newnum
    set flist(seq,$folder,$seq) $msgids
    if {[lsearch $flist($seq) $folder] < 0} {
	lappend flist($seq) $folder
    }
    if {$seq == $mhProfile(unseen-sequence)} {
	if {[string compare $folder $exmh(folder)] != 0 &&
	    [lsearch $flist(unvisited) $folder] < 0} {
	    lappend flist(unvisitedNext) $folder
	}
	Fdisp_HighlightUnseen $folder
    }
}
# Deletes messages from a sequence
proc Seq_Del {folder seq msgids} {
    global flist mhProfile
#   eval {MhExec mark +$folder -seq $seq -delete} $msgids
    Mh_SequenceUpdate $folder del $seq $msgids
    set delta 0
    foreach msgid $msgids {
	if [info exists flist(seq,$folder,$seq)] {
	    set ix [lsearch $flist(seq,$folder,$seq) $msgid]
	    if {$ix >= 0} {
		set flist(seq,$folder,$seq) \
		    [lreplace $flist(seq,$folder,$seq) $ix $ix]
		incr delta -1
	    }
	}
    }
    if {$delta != 0} {
	incr flist(seqcount,$folder,$seq) $delta
	if {$seq == $mhProfile(unseen-sequence)} {
	    if {$flist(seqcount,$folder,$seq) == 0} {
		FlistUnseenFolder $folder
	    }
	}
    }
}
proc Seq_Msgs { folder seq } {
    global flist
    Seq_Set $folder $seq [Mh_Sequence $folder $seq]
    return $flist(seq,$folder,$seq)
}
proc Seq_Count { folder seq } {
    global flist
    if [info exists flist(seqcount,$folder,$seq)] {
	return $flist(seqcount,$folder,$seq)
    } else {
	return 0
    }
}
