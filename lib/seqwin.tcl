#
# seqwin.tcl
#
# Displays a window with counts of messages in sequences.
#   Based on and largely borrowed from Olly Stephens
#   <olly@zycad.com>'s unseenwin.tcl, which is obsoleted by this code.
#		--- cwg-exmh@deepeddy.com

proc SeqWinSetGeom {seq width height} {
    global seqwin

    incr width [expr $seqwin(digits,$seq) + 1]
    .sequences.pane$seq.lb configure -width $width -height $height
}

proc SeqWinSetSelection {seq {which -1}} {
    .sequences.pane$seq.lb select clear 0 end
    if {$which != -1} {
	.sequences.pane$seq.lb select set $which
    }
}

proc SeqWinToggle {args} {
    global seqwin flist

    if {$seqwin(on) && ![winfo exists .sequences]} {
	Exwin_Toplevel .sequences "Sequences" SeqWin no
	wm resizable .sequences 0 1
	SeqWinFixShowList
	wm protocol .sequences WM_TAKE_FOCUS {
	    global exwin
	    focus $exwin(mtext)
	}
	wm protocol .sequences WM_DELETE_WINDOW SeqWinDeleted
	catch {Flist_FindSeqs 1}
    } elseif {!$seqwin(on) && [winfo exists .sequences]} {
	destroy .sequences
    }
}
proc SeqWinShowSeqPane {seq} {
    global seqwin flist
    if {[winfo exists .sequences]} {
	if {![info exists seqwin(folders,$seq)]} {
	    set seqwin(folders,$seq) {}
	}
	if {![info exists seqwin(listwidth,$seq)]} {
	    set seqwin(listwidth,$seq) $seqwin(minwidth)
	}
	if {![info exists seqwin(curlines,$seq)]} {
	    set seqwin(curlines,$seq) $seqwin(minlines)
	}
	if {![info exists seqwin(curwidth,$seq)]} {
	    set seqwin(curwidth,$seq) $seqwin(minwidth)
	}
	if {![info exists seqwin(digits,$seq)]} {
	    set seqwin(digits,$seq) 1
	}
	if {![winfo exists .sequences.pane$seq]} {
	    frame .sequences.pane$seq
	    label .sequences.pane$seq.l -text $seq -font $seqwin(font)
	    pack .sequences.pane$seq.l -side top -fill x
	    listbox .sequences.pane$seq.lb -exportselection no -font $seqwin(font) \
		-relief flat -bd 2
	    .sequences.pane$seq.lb configure -highlightthickness 0 -setgrid 1
	    SeqWinSetGeom $seq $seqwin(minwidth) $seqwin(minlines)
	    SeqWinEmptyMsg $seq
	    set seqopts [option get . sequence_$seq {}]
	    if {$seqopts != {}} {
		catch {eval .sequences.pane$seq configure $seqopts}
		catch {eval .sequences.pane$seq.l configure $seqopts}
		catch {eval .sequences.pane$seq.lb configure $seqopts}
	    }
	    pack .sequences.pane$seq.lb -side top

	    bind .sequences.pane$seq.lb <1> "SeqWinButton $seq %y b1mode"
	    foreach b { Shift-1 Control-1 Control-Shift-1 } {
		bind .sequences.pane$seq.lb <$b> "SeqWinButton $seq %y mb1mode"
	    }
	    foreach b { B1-Motion Shift-B1-Motion Control-B1-Motion
		2 B2-Motion
		3 B3-Motion Control-3 Control-Shift-3 } {
		bind .sequences.pane$seq.lb <$b> {;}
	    }
	    bind .sequences.pane$seq.lb <Any-ButtonRelease-2> "SeqWinButton $seq %y b2mode"
	    bind .sequences.pane$seq.lb <Any-ButtonRelease-3> "SeqWinButton $seq %y b3mode"
	    SeqWinToggleClick $seq

	}
	set num $flist(totalcount,$seq)
	if {$num <= 0} {
	    SeqWinEmptyMsg $seq
	    if {[lsearch $seqwin(alwaysshow) $seq] < 0} {
		if {[winfo ismapped .sequences.pane$seq]} {
		    SeqWinHideSeqPane $seq
		}
	    }
	}
	if {[lsearch $seqwin(nevershow) $seq] < 0} {
	    if {($num > 0) || ([lsearch $seqwin(alwaysshow) $seq] >= 0)} {
		if {![winfo ismapped .sequences.pane$seq]} {
		    if {$seqwin(orientation) == "Horizontal"} {
			pack .sequences.pane$seq -side left -anchor n -fill y
		    } else {
			pack .sequences.pane$seq -side top -anchor n -fill y
		    }
		}
	    }
	}
    }
}
proc SeqWinHideSeqPane {seq} {
    global seqwin
    if {[winfo exists .sequences]} {
	if {[winfo exists .sequences.pane$seq]} {
	    pack forget .sequences.pane$seq
	}
	if {[pack slaves .sequences] == {}} {
	    if $seqwin(hidewhenempty) {
		catch {wm withdraw .sequences}
		return
	    } elseif (!$seqwin(icon)) {
		catch {wm deiconify .sequences}
	    }
	} else {
	    catch {wm deiconify .sequences}
	}
    }
}
proc SeqWinFixShowList {args} {
    global seqwin flist
    foreach seq [option get . sequences {}] {
	if {![info exists flist($seq)]} {
	    set flist($seq) {}
	}
	if {![info exists flist(totalcount,$seq)]} {
	    set flist(totalcount,$seq) 0
	}
	if {([lsearch $seqwin(alwaysshow) $seq] >= 0) ||
	    (($flist(totalcount,$seq) > 0) && 
	     ([lsearch $seqwin(nevershow) $seq] < 0))} {
	    SeqWinShowSeqPane $seq
	} else {
	    SeqWinHideSeqPane $seq
	}
    }
}
proc SeqWinFixOrientation {args} {
    global seqwin
    foreach seq [option get . sequences {}] {
	SeqWinHideSeqPane $seq
    }
    SeqWinFixShowList
}
proc SeqWinDeleted {} {
    wm iconify .sequences
    Exmh_Status "Sequences window closed, not destroyed"
}

proc SeqWinShow {seq index delete folder count} {
    global seqwin
    
    if $delete {
	.sequences.pane$seq.lb delete $index
    }
    if {![info exists seqwin(listwidth,$seq)]} {
	set seqwin(listwidth,$seq) $seqwin(minwidth)
    }
    if {![info exists seqwin(curwidth,$seq)]} {
	set seqwin(curwidth,$seq) $seqwin(minwidth)
    }
    set width $seqwin(listwidth,$seq)
    set digits $seqwin(digits,$seq)
    .sequences.pane$seq.lb insert $index [format "%${width}s %${digits}d" $folder $count]
    if {$width > $seqwin(curwidth,$seq)} {
	.sequences.pane$seq.lb xview [expr $width - $seqwin(curwidth,$seq)]
    }
}

proc SeqWinAdd {seq folder num} {
    global seqwin flist
    
    set index [llength $seqwin(folders,$seq)]
    if {$index == 0} {
	if $seqwin(hidewhenempty) {
	    catch {wm deiconify .sequences}
	    raise .sequences
	}
	.sequences.pane$seq.lb delete 0 end
    } elseif {$index < $seqwin(curlines,$seq)} {
	.sequences.pane$seq.lb delete end
    }
    
    set newlines $index
    set newwidth [string length $folder]
    
    set hasmaxlines [expr $seqwin(maxlines) >= $seqwin(minlines)]
    set hasmaxwidth [expr $seqwin(maxwidth) >= $seqwin(minwidth)]
    
    set resize 0
    set redisplay 0
    
    # adding a folder, so only need to see if digits has increased
    set digits [expr int(log10($num) + 1)]
    if {$digits > $seqwin(digits,$seq)} {
	set seqwin(digits,$seq) $digits
	set resize 1
	set redisplay 1
    }
    
    if {($index >= $seqwin(minlines)) &&
	(!$hasmaxlines || ($seqwin(curlines,$seq) < $seqwin(maxlines)))} {
	incr seqwin(curlines,$seq)
	set resize 1
    }
    if {$newwidth > $seqwin(listwidth,$seq)} {
	set redisplay 1
	set seqwin(listwidth,$seq) $newwidth
	if {!$hasmaxwidth || ($seqwin(curwidth,$seq) < $seqwin(maxwidth))} {
	    set resize 1
	    if {$hasmaxwidth && ($newwidth > $seqwin(maxwidth))} {
		set seqwin(curwidth,$seq) $seqwin(maxwidth)
	    } else {
		set seqwin(curwidth,$seq) $newwidth
	    }
	}
    }
    
    if $resize {
	SeqWinSetGeom $seq $seqwin(curwidth,$seq) $seqwin(curlines,$seq)
    }
    if {($seqwin(listwidth,$seq) > $seqwin(curwidth,$seq)) ||
	($index >= $seqwin(curlines,$seq))} {
	bind .sequences.pane$seq.lb <2> {%W scan mark %x %y}
	bind .sequences.pane$seq.lb <B2-Motion> {%W scan dragto %x %y}
    }
    if {$index == 0} {
	for {set i 1} {$i < $seqwin(curlines,$seq)} {incr i} {
	    .sequences.pane$seq.lb insert end " "
	}
    }
    if $redisplay {
	set i 0
	foreach f $seqwin(folders,$seq) {
	    SeqWinShow $seq $i 1 $f $flist(seqcount,$f,$seq)
	    incr i
	}
    }
    SeqWinShow $seq $index 0 $folder $num
    lappend seqwin(folders,$seq) $folder
}

proc SeqWinUpdate {seq folder num} {
    global seqwin flist
    
    if {![info exist seqwin(folders,$seq)]} {
        set seqwin(folders,$seq) {}
    }
    set index [lsearch $seqwin(folders,$seq) $folder]
    if {$index == -1} {
	if {$num > 0} {
	    SeqWinAdd $seq $folder $num
	}
    } else {
	if {$num == 0} {
	    SeqWinRemove $seq $index $folder
	} else {
	    # the number of digits may have changed: recalculate
	    set old_digits $seqwin(digits,$seq)
	    set seqwin(digits,$seq) 1
	    foreach f $seqwin(folders,$seq) {
		if {[catch {set digits [expr int(log10($flist(seqcount,$f,$seq)) + 1)]}]} {
		    set digits 1
		}
		if {$digits > $seqwin(digits,$seq)} {
		    set seqwin(digits,$seq) $digits
		}
	    }
	    # if it did change, set the geometry and re-show every folder
	    if {$seqwin(digits,$seq) != $old_digits} {
		Exmh_Debug digits changed
		SeqWinSetGeom $seq $seqwin(curwidth,$seq) $seqwin(curlines,$seq)
		set i 0
		foreach f $seqwin(folders,$seq) {
		    SeqWinShow $seq $i 1 $f $flist(seqcount,$f,$seq)
		    incr i
		}
	    } else {
		SeqWinShow $seq $index 1 $folder $num
	    }
	}
    }
}

proc SeqWinRemove {seq index folder} {
    global seqwin flist
    
    set seqwin(folders,$seq) [lreplace $seqwin(folders,$seq) $index $index]
    set newlines [llength $seqwin(folders,$seq)]
    .sequences.pane$seq.lb delete $index

    set resize 0
    set redisplay 0
    
    if {[string length $folder] == $seqwin(listwidth,$seq)} {
	set newwidth 0
	foreach f $seqwin(folders,$seq) {
	    set len [string length $f]
	    if {$len > $newwidth} {
		set newwidth $len
	    }
	}
	if {$newwidth < $seqwin(minwidth)} {
	    set newwidth $seqwin(minwidth)
	}
	if {$newwidth < $seqwin(listwidth,$seq)} {
	    set redisplay 1
	    if {$newwidth < $seqwin(curwidth,$seq)} {
		set resize 1
		set seqwin(curwidth,$seq) $newwidth
	    }
	    set seqwin(listwidth,$seq) $newwidth
	}
    }
    if {($newlines < $seqwin(curlines,$seq)) &&
	($newlines >= $seqwin(minlines))} {
	incr seqwin(curlines,$seq) -1
	set resize 1
    }
    
    # the number of digits may have changed: recalculate
    set old_digits $seqwin(digits,$seq)
    set seqwin(digits,$seq) 1
    foreach f $seqwin(folders,$seq) {
	set count $flist(seqcount,$f,$seq)
	if {$count > 0} {
	    set digits [expr int(log10($flist(seqcount,$f,$seq)) + 1)]
	    if {$digits > $seqwin(digits,$seq)} {
		set seqwin(digits,$seq) $digits
	    }
	}
    }
    if {$seqwin(digits,$seq) != $old_digits} {
	set resize 1
	set redisplay 1
    }
    
    if $resize {
	SeqWinSetGeom $seq $seqwin(curwidth,$seq) $seqwin(curlines,$seq)
    }
    if {($seqwin(listwidth,$seq) == $seqwin(curwidth,$seq)) &&
	($newlines <= $seqwin(curlines,$seq))} {
	bind .sequences.pane$seq.lb <2> {;}
	bind .sequences.pane$seq.lb <B2-Motion> {;}
    }
    if {$newlines == 0} {
	SeqWinEmptyMsg $seq
    } else {
	if $redisplay {
	    set i 0
	    foreach f $seqwin(folders,$seq) {
		SeqWinShow $seq $i 1 $f $flist(seqcount,$f,$seq)
		incr i
	    }
	}
	while {$newlines < $seqwin(curlines,$seq)} {
	    .sequences.pane$seq.lb insert end " "
	    incr newlines
	}
    }
}

proc SeqWinToggleIcon {args} {
    global seqwin
    
    if [winfo exists .sequences] {
	set already [expr [string compare [wm iconwindow .] .sequences] == 0]
	if {$seqwin(icon) && !$already} {
	    wm iconwindow . .sequences
	} elseif $already {
	    wm iconwindow . {}
	    catch {wm deiconify .sequences}
	}
    }
}

proc SeqWinToggleClick {seq args} {
    global seqwin
    
    if [winfo exists .sequences.pane$seq] {
	if {[string match "W*" $seqwin(b1mode)] ||
	    [string match "W*" $seqwin(mb1mode)]} {
	    bind .sequences.pane$seq.lb <Leave> "SeqWinSetSelection $seq"
	    bind .sequences.pane$seq.lb <Motion> "SeqWinMove $seq %y"
	} else {
	    SeqWinSetSelection $seq
	    bind .sequences.pane$seq.lb <Leave> {;}
	    bind .sequences.pane$seq.lb <Motion> {;}
	}
    }
}

proc SeqWinChangeFont {seq args} {
    global seqwin
    
    if [winfo exists .sequences] {
	set old [lindex [.sequences.pane$seq.lb configure -font] 4]
	if {[catch {
	    .sequences.pane$seq.lb configure -font $seqwin(font)
	} err] != 0} {
	    set seqwin(font) $old
	}
    }
}

proc SeqWinChangeMinMax {args} {
    global seqwin flist
    if {[catch {expr $seqwin(minlines)}] ||  $seqwin(minlines) < 1} {
	set seqwin(minlines) 1
    }
    if {[catch {expr $seqwin(minwidth)}] || $seqwin(minwidth) < 5} {
	set seqwin(minwidth) 5
    }
    if {[catch {expr $seqwin(maxlines)}]} {
	set seqwin(maxlines) $seqwin(minlines)
    }
    if {[catch {expr $seqwin(maxwidth)}]} {
	set seqwin(maxwidth) $seqwin(minwidth)
    }
    if [winfo exists .sequences] {
	# Trigger the trace
	set seqwin(on) 0
	set seqwin(on) 1
    }
}

proc SeqWinEmptyMsg {seq} {
    global seqwin
    
    if {[winfo exists .sequences]} {
	if {[llength $seqwin(folders,$seq)] == 0} {
	    set elen [string length $seqwin(emptymsg)]
	    set pad [expr ((($seqwin(listwidth,$seq) + 4) - $elen) / 2) + $elen]
	    set empty [expr (($seqwin(curlines,$seq) + 1) / 2) - 1]

	    .sequences.pane$seq.lb delete 0 end
	    for {set i 1} {$i < $seqwin(curlines,$seq)} {incr i} {
		.sequences.pane$seq.lb insert end " "
	    }
	    .sequences.pane$seq.lb insert $empty [format "%${pad}s" $seqwin(emptymsg)]
	    .sequences.pane$seq.lb yview 0
	    .sequences.pane$seq.lb xview 0
	    SeqWinSetSelection $seq
	}
    }
}

proc SeqWinMove {seq y} {
    global seqwin
    
    set entry [.sequences.pane$seq.lb nearest $y]
    
    if {$entry < [llength $seqwin(folders,$seq)]} {
	SeqWinSetSelection $seq $entry
    } else {
	SeqWinSetSelection $seq
    }
}

proc SeqWinButton {seq y mode} {
    global seqwin exmh ftoc
    
    Exmh_Debug SeqWinButton $seq $y $mode
    set mode $seqwin($mode)
    if {[string compare $mode None] == 0} {
	return
    }
    
    set entry [.sequences.pane$seq.lb nearest $y]
    
    switch $mode {
	Inc {
	    Inc
	}
	Compose {
	    Msg_Compose
	}
	default {
	    if {($entry < [llength $seqwin(folders,$seq)]) &&
		([string compare $mode Raise] != 0)} {
		set folder [lindex $seqwin(folders,$seq) $entry]
		if {[string compare $exmh(folder) $folder] != 0} {
		    if {[string compare $mode Warp] == 0} {
			Folder_Change $folder
		    } elseif {[string compare $mode "Warp & Narrow"] == 0} {
			Folder_Change $folder [list Ftoc_NewFtoc [Ftoc_FindMsgs [Seq_Msgs $folder $seq]]]
		    } else {
			Folder_Change $folder [list Msg_Show $seq]
		    }
		} elseif {[string compare $mode "Warp & Show"] == 0} {
		    if {!$ftoc(displayValid)} {
			Folder_Change $folder [list Msg_Show $seq]
		    } else {
			Msg_Show $seq
		    }
		} elseif {[string compare $mode "Warp & Narrow"] == 0} {
		    Ftoc_NewFtoc [Ftoc_FindMsgs [Seq_Msgs $folder $seq]]
		}
	    }
	    wm deiconify .
	    raise .
#	    update idletasks
	}
    }
}
