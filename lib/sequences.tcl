#
# sequences.tcl
#
# Routines for handling sequences.  Based on and generalized from the
# old code for dealing with the unseen sequence which was in either
# flist.tcl or mh.tcl. (or both!)

proc Seq_Init {} {
    global flist
    trace variable flist wu Seq_Trace
}
proc Seq_Trace {array elem op} {
    global flist

    set indices [split $elem ,]
    set var [lindex $indices 0]
    if {$var != {seqcount}} {
	# Not seqcount
	return
    }
    set folder [lindex $indices 1]
    set sequence [lindex $indices 2]
    if [info exists flist($elem)] {
	set num $flist($elem)
    } else {
	set num 0
    }
    if [info exists flist(oldseqcount,$folder,$sequence)] {
	set oldnum $flist(oldseqcount,$folder,$sequence)
    } else {
	set oldnum 0
    }
    set flist(oldseqcount,$folder,$sequence) $num
    set delta [expr {$num - $oldnum}]
    Exmh_Debug $folder has $num msgs in $sequence
    if {[info exists flist(totalcount,$sequence)]} {
	incr flist(totalcount,$sequence) $delta
    } else {
	set flist(totalcount,$sequence) $delta
    }
    if {$num > 0} {
	if [info exists flist($sequence)] {
	    if {[lsearch $flist($sequence) $folder] < 0} {
		lappend flist($sequence) $folder
	    }
	} else {
	    set flist($sequence) $folder
	}
    } else {
	if [info exists flist($sequence)] {
	    set ix [lsearch $flist($sequence) $folder]
	    if {$ix >= 0} {
		set flist($sequence) [lreplace $flist($sequence) $ix $ix]
	    }
	} else {
	    set flist($sequence) {}
	}
    }
    Exmh_Debug "$flist(totalcount,$sequence) $sequence msgs in [llength $flist($sequence)] folders ($flist($sequence))"
}

# The routines below here manage sequence state per folder.

proc Seq_Expand { folder sequence } {
    global mhProfile
    # Explode a sequence into a list of message numbers
    set seq {}
    set rseq {}
    foreach range [split [string trim $sequence]] {
	set parts [split [string trim $range] -]
	if {[llength $parts] == 1} {
	    lappend seq $parts
	    set rseq [concat $parts $rseq]
	} else {
	    for {set m [lindex $parts 0]} {$m <= [lindex $parts 1]} {incr m} {
		lappend seq $m
		set rseq [concat $m $rseq]
	    }
	}
    }
    # Hack to weed out sequence numbers for messages that don't exist
    foreach m $rseq {
	if ![file exists $mhProfile(path)/$folder/$m] {
	    Exmh_Debug $mhProfile(path)/$folder/$m not found
	    set ix [lsearch $seq $m]
	    set seq [lreplace $seq $ix $ix]
	} else {
	    # Real hack
	    break
	}
    }
    return $seq
}

# Reset the cached state about sequences because the user
# has just packed, sorted, or threaded the folder.
# This should be followed shortly by a call to Seq_Msgs
#
# Don't call gratitiously because it confuses the exmhunseen window.

proc Seq_Forget {folder seq} {
    global flist
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
    global flist exmh

    set msgids [Seq_Expand $folder $msgids]
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
    if {([string compare $folder $exmh(folder)] == 0) && ($seq == {unseen})} {
	set known [concat [Msg_Seen] $flist(seq,$folder,$seq)]
    } else {
	set known $flist(seq,$folder,$seq)
    }
    # Subtract elements of $known from $msgids
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
    set num [llength $msgids]
    if {$num <= 0} {
	return
    }
    set flist(seqcount,$folder,$seq) [expr $new + $num]
    set flist(seq,$folder,$seq) [concat $flist(seq,$folder,$seq) $msgids]
    if {[lsearch $flist($seq) $folder] < 0} {
	lappend flist($seq) $folder
    }
    if {$seq == {unseen}} {
	if {[string compare $folder $exmh(folder)] != 0 &&
	    [lsearch $flist(unvisited) $folder] < 0} {
	    lappend flist(unvisitedNext) $folder
	}
	Fdisp_HighlightUnseen $folder
    }
}
# Set the contents of a sequence for a folder.
proc Seq_Set {folder seq msgids} {
    global flist exmh

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
    if {$seq == {unseen}} {
	if {[string compare $folder $exmh(folder)] != 0 &&
	    [lsearch $flist(unvisited) $folder] < 0} {
	    lappend flist(unvisitedNext) $folder
	}
	Fdisp_HighlightUnseen $folder
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
proc Seq_RemoveMsg { seq msgid } {
    global flist exmh
    if [info exists flist(seq,$exmh(folder),$seq)] {
	set ix [lsearch $flist(seq,$exmh(folder),$seq) $msgid]
	if {$ix >= 0} {
	    set flist(seq,$exmh(folder),$seq) \
		[lreplace $flist(seq,$exmh(folder),$seq) $ix $ix]
	    incr flist(seqcount,$exmh(folder),$seq) -1
	    if {$seq == {unseen}} {
		if {$flist(seqcount,$exmh(folder),$seq) == 0} {
		    FlistUnseenFolder $exmh(folder)
		}
	    }
	    if {$flist(totalcount,$seq) <  0} {
		Exmh_Status "$flist(totalcount,$seq) $seq!"
		set flist(totalcount,$seq) 0
	    }
	}
    }
}
proc Seq_Modify { folder how oldmsgs msgs } {
    set new [Seq_Expand $folder $msgs]
    set old [Seq_Expand $folder $oldmsgs]
    if {[string compare $how "add"] == 0} {
	set merge [lsort -integer -increasing [concat $old $new]]
    } elseif {[string compare $how "del"] == 0} {
	set ix 0
	set new [lsort -integer -increasing $new]
	set next [lindex $new 0]
	set merge {}
	foreach id [lsort -integer -increasing $old] {
	    while {$id > $next} {
		incr ix
		set next [lindex $new $ix]
		if {[string length $next] == 0} {
		    incr ix -1
		    set next [lindex $new $ix]
		    break
		}
	    }
	    if {$id == $next} {
		incr ix
		set next [lindex $new $ix]
	    } else {
		lappend merge $id
	    }
	}
    } elseif {[string compare $how "replace"] == 0} {
	# replace
	return $msgs
    } else {
	return {}
    }
    set seq [SeqMake $merge]
    Exmh_Debug $seq
    return $seq
}
proc SeqMake { msgs } {
    set result [lindex $msgs 0]
    set first $result
    set last $result
    set id {}
    foreach id [lrange $msgs 1 end] {
	if {$id != $last} {
	    if {$id == $last + 1} {
		set last $id
	    } else {
		if {$last != $first} {
		    append result -$last
		}
		set first $id
		set last $id
		append result " $first"
	    }
	}
    }
    if {$id == $last && [string length $msgs]} {
	append result -$last
    }
    return $result
}
