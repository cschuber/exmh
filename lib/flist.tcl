#
# flist.tcl
#
# Manage the folder list.
# For folder display (fdisp.tcl):
#	What folders have nested folders under them
#	What folders have unseen messages
# For scan listing (ftoc.tcl):
#	What messages are unread.
#
# Some of the routines here are set up to run in a background interpreter.
# When you see calls to BgRPC it is invoking the routine in the
# forground UI interpreter, whether or not the current routine
# is already running there.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.


proc Flist_Init {} {
    global flist
    FlistResetVars		;# Reset unseen msgs state
    set flist(context) {}
    set flist(contextMtime) 0
    set flist(cacheFileMtime) 0
    set flist(active) 0
    Flist_FindAllFolders
}
proc FlistResetVars {} {
    global flist mhProfile flistcache
    set flist($mhProfile(unseen-sequence)) {}	;# Sequence of folders to visit
    set flist(unvisited) {}	;# Unseen folders not yet visited
    Exmh_Debug FlistResetVars
    set flist(unvisitedNext) {}	;# Temporary copy (next iteration)
    if {[info exist flistcache]} {
        unset flistcache
    }

    # flist(seqcount,$folder,$seq)
    #	number of sequence elements in a folder
    #	(Update with care; 'trace'd by Seq_Trace)
    # flist(oldseqcount,$folder,$seq)
    #	previous number of sequence elements in a folder
    # flist(seq,$folder,$seq)
    #	message id's of messages in $seq
    # flist(mtime,$folder)
    #	modification time of .mh_sequences file
    # flist(totalcount,$seq)	;# Total count of messages in sequence

    foreach x [lsort -ascii [array names flist]] {
	if [regexp {^(seq),} $x] {
	    # reset state
	    set flist($x) {}
	} elseif [regexp {^(mtime|totalcount|seqcount|oldseqcount),} $x] {
	    # reset state
	    set flist($x) 0
	}
    }
    if ![info exists flist(debug)] {
	set flist(debug) 0
    }

    # Note - I think this flist debugging window is obviated by
    # the Unseen_window/Sequences_window - consider nuking it.

    if {$flist(debug)} {
	trace variable flist(totalcount,$mhProfile(unseen-sequence)) w FlistTraceTotalUnseen
	trace variable flist($mhProfile(unseen-sequence)) w FlistTraceUnseen
	trace variable flist(unvisited) w FlistTraceUnvisited
	set flist(listbox) .flistbox
	set f $flist(listbox)
	if ![winfo exists $f] {
	    Exwin_Toplevel $f "Flist Debug" Flist
	    Widget_Label $f newMsgs {top fillx } -textvariable flist(totalcount,$mhProfile(unseen-sequence))
	    Widget_Frame $f top Labels
	    Widget_Label $f.top unseen {left fill expand} -text Unseen
	    Widget_Label $f.top unvisited {left fill expand} -text Unvisited
	    FontWidget listbox $f.unseen
	    FontWidget listbox $f.unvisited
	    pack $f.unseen $f.unvisited -side left -fill both -expand true
	}
    }
}
proc FlistTraceTotalUnseen {args} {
    global flist mhProfile
    set l [info level]
    incr l -1
    Exmh_Debug FlistTraceTotalUnseen flist(totalcount,$mhProfile(unseen-sequence)) => $flist(totalcount,$mhProfile(unseen-sequence)) : [info level $l] $args
}
proc FlistTraceUnseen {args} {
    global flist
    $flist(listbox).unseen delete 0 end
    foreach f $flist($mhProfile(unseen-sequence)) {
	$flist(listbox).unseen insert end $f
    }
}
proc FlistTraceUnvisited {args} {
    global flist
    $flist(listbox).unvisited delete 0 end
    foreach f $flist(unvisited) {
	$flist(listbox).unvisited insert end $f
    }
}

### Routines to find all folders, figure out which have nested folders, etc.

# This is commonly bound to the "Flist" button - reset the state
# about folders.

proc Flist_Refresh {} {
    global flist
    FlistResetVars
    FlistFindAllInner
    Fdisp_Redisplay
    Flist_FindSeqs 1
    Folder_FindShared
    Inc_PresortFinish
}

proc Flist_FindAllFolders {{force 0}} {
    global flist mhProfile flistSubCache flistParents

    if ![info exists flist(cacheFile)] {
	set flist(cacheFile) $mhProfile(path)/.folders
    }
    if {$force || ![file readable $flist(cacheFile)] ||
	    [file size $flist(cacheFile)] == 0} {
	FlistFindAllInner
    } elseif {![info exists flist(allfolders)]||
	    [file mtime $flist(cacheFile)] > $flist(cacheFileMtime)} {
	set in [open $flist(cacheFile)]
	set flist(allfolders) [FlistSort [split [read $in] \n]]
	close $in
	set flist(cacheFileMtime) [file mtime $flist(cacheFile)]
	FlistSubFoldersInit
	BgAction FlistUnseenFoldersInit FlistUnseenFoldersInit
    }
    Folder_FindShared
}
proc FlistFindAllInner {} {
    global flist flistSubCache flistParents mhProfile
    catch {destroy .scanning}
    Widget_Toplevel .scanning "Scanning..."
    Widget_Message .scanning msg -cursor watch -text "
Scanning for nested folders.
(folders -all -fast -recurse)

The results are cached in
$mhProfile(path)/.folders
so you won't have to wait like
this until you press the Folders
button to update the folder set.

Please wait...
"
    Exmh_Status "Scanning for nested folders ..." warn
    update
    set bogus [catch {exec folders -all -fast -recurse} raw]
    set raw [split $raw \n]
    if {$bogus} {
	set ix [lsearch -glob $raw "* * *"]
	if {$ix >= 0} {
	    set msg [lindex $raw $ix]
	    .scanning.msg config -text $msg
	    Exmh_Status $msg
	    catch {puts stderr $raw}
	    update
	    after 1000
	    set raw [lreplace $raw $ix $ix]
	} else {
	    Exmh_Status "Folders error report on stderr"
	    catch {puts stderr $raw}
	}
    }

    set flist(allfolders) [FlistSort $raw]
    FlistSubFoldersInit
    BgAction FlistUnseenFoldersInit FlistUnseenFoldersInit
    FlistCacheFolderList
    destroy .scanning
}
proc Flist_AddFolder { folder } {
    global flist
    if {[lsearch $flist(allfolders) $folder] >= 0} {
	Exmh_Debug "Flist_AddFolder already has $folder"
    } else {
	lappend flist(allfolders) $folder
    }
    set flist(allfolders) [FlistSort $flist(allfolders)]
    FlistSubFoldersInit
    BgAction FlistUnseenFoldersInit FlistUnseenFoldersInit
    FlistCacheFolderList
    Fdisp_Redisplay
}
proc Flist_DelFolder { folder } {
    global flist
    set ix [lsearch $flist(allfolders) $folder]
    if {$ix < 0} {
	return
    }
    set flist(allfolders) [FlistSort [lreplace $flist(allfolders) $ix $ix]]
    FlistSubFoldersInit
    BgAction FlistUnseenFoldersInit FlistUnseenFoldersInit
    FlistCacheFolderList
    Fdisp_Redisplay
}
proc FlistCacheFolderList {} {
    global flist
    if [catch {open $flist(cacheFile) w} out] {
	Exmh_Status "Cannot cache folder list: $out" warning
    } else {
	foreach f $flist(allfolders) {
	    puts $out $f
	}
	close $out
	set flist(cacheFileMtime) [file mtime $flist(cacheFile)]
    }
}
proc FlistUnseenFoldersInit {} {
    global flist mhProfile

    set flist(unseenfolders) {}
    foreach f $flist(allfolders) {
        foreach pat $mhProfile(folder-unseen) {
	    if {[string compare ! [string range $pat 0 0]] == 0} {
		if [string match [string range $pat 1 end] $f] {
			break
		}
	    }
            if [string match $pat $f] {
                lappend flist(unseenfolders) $f
                break
            }
        }
    }
}
proc FlistSubFoldersInit {} {
    global flist subFolders flistSubCache flistParents

    catch {unset subFolders}	;# Map from name to list of children
    catch {unset flistSubCache}
    catch {unset flistParents}
    foreach f $flist(allfolders) {
	append subFolders([file dirname $f]) "$f "
    }
}
proc Flist_SubFolders {{folder .}} {
    global subFolders

    return [info exists subFolders($folder)]
}
proc Flist_FolderSet { {subfolder .} } {
    #  Find all folders at a given level in the folder hierarchy
    global flist flistSubCache
    if [info exists flistSubCache($subfolder)] {
	return $flistSubCache($subfolder)
    }
    foreach f $flist(allfolders) {
	set parent [file dirname $f]
	if {$subfolder == $parent || $subfolder == $f} {
	    lappend result $f
	}
    }
    if ![info exists result] {
	return {}
    } else {
	set flistSubCache($subfolder) $result
	return $result
    }
}

# exmh-2.5
# FlistSeq
# Flist_ForgetUnseen
# Flist_AddUnseen

proc Flist_Done { {resetVisited 1} } {
    global flist exmh

    # See Flag_Trace, which has code that used to be called from this point

    Exmh_Debug Flist_Done
    if {$resetVisited} {
      # This procedure is called from FolderChange, which doesn't
      # want to reset this list, and from external sorting, which does
      set flist(unvisited) [FlistSort $flist(unvisitedNext)]
    }
    set flist(active) 0
}


# Call Flist_UnseenUpdate from external sorting programs after
# they add messages to a folder

proc Flist_UnseenUpdate { folder {resetVisited 1} } {
    global exmh flist ftoc mhProfile
    Exmh_Debug Flist_UnseenUpdate $folder
    foreach seq [Mh_Sequences $folder] {
	Seq_Set $folder $seq [MhGetSeqCache $folder $seq]
    }
    if {[string compare $folder $exmh(folder)] == 0} {
	if {$ftoc(autoSort)} {
	    if [Flist_NumUnseen $folder $mhProfile(unseen-sequence)] {
		Ftoc_Sort
	    }
	}
	Scan_FolderUpdate $folder
    } elseif {[lsearch $flist(unvisited) $folder] < 0} {
	lappend flist(unvisited) $folder
	set flist(unvisitedNext) $flist(unvisited)
    }
    # This wiggles the flag and sorts flist(unvisited)
    Flist_Done $resetVisited
}
proc Flist_UnseenFolders {} {
    global flist mhProfile
    return $flist($mhProfile(unseen-sequence))
}

# Flist enumerates folders that have unseen messages.
proc Flist_FindSeqs {{reset 0}} {
    Exmh_Debug Flist_FindSeqs reset=$reset
    Exmh_Debug Flist_FindSeqs end [time [list FlistFindSeqs $reset]]
}

proc FlistFindStart {reset} {
    global flist
    if ![info exists flist(active)] {
	set flist(active) 0
    }
    Exmh_Debug FlistFindStart reset=$reset active=$flist(active)
    if {$flist(active)} {
	return 0
    }
    set flist(active) 1
    if {$reset} {
	Fdisp_ClearHighlights
	FlistResetVars
    }
    return 1
}

proc FlistFindSeqsInner {} {
    global flist seqwin flistcache
    if {[catch {
    FlistGetContext
    foreach folder $flist(unseenfolders) {
Exmh_Debug FlistFindSeqsInner $folder
        foreach seq [Mh_Sequences $folder] {
            if {[lsearch $seqwin(nevershow) $seq] < 0} {
                set seqlist [MhGetSeqCache $folder $seq]
                if {![info exist flistcache($folder,$seq)] ||
                    [string compare $seqlist $flistcache($folder,$seq)]} {

                  # Cache added 2/11/03
                  # Sequence is different than last time we checked

                  set flistcache($folder,$seq) $seqlist
                  Seq_Set $folder $seq $seqlist
                }
            }
	}
    }
    } err]} {
	# An error here is most likely a flakey NFS connection
	# It is important to trap this so we can mark the
	# flist action as "Done" below.  Otherwise, we'll stop
	# looking for new messages.
	Exmh_Debug "FlistFindSeqs: $err"
    }
}

proc FlistFindSeqs {reset} {
    global flist
    if {![BgRPC FlistFindStart $reset]} {
	# Flist active
	return
    }
    BgRPC FlistFindSeqsInner
    BgRPC Flist_Done
}
proc FlistGetContext {} {
    global flist mhProfile
    if {$flist(contextMtime) < [file mtime $mhProfile(context)]} {
	if {[catch {open $mhProfile(context)} in] == 0} {
	    set flist(context) [split [read $in] \n]
	    set flist(contextMtime) [file mtime $mhProfile(context)]
	    close $in
	}
    }
}
proc Flist_SeenAll { folder } {
    FlistUnseenFolder $folder
}
proc FlistUnseenFolder { folder } {
    global flist mhProfile
    Exmh_Debug FlistUnseenFolder $folder
    set flist(seqcount,$folder,$mhProfile(unseen-sequence)) 0
    set flist(seq,$folder,$mhProfile(unseen-sequence)) {}
    Fdisp_UnHighlightUnseen $folder
    set ix [lsearch $flist($mhProfile(unseen-sequence)) $folder]
    if {$ix >= 0} {
	set flist($mhProfile(unseen-sequence)) [lreplace $flist($mhProfile(unseen-sequence)) $ix $ix]
	if {[llength $flist($mhProfile(unseen-sequence))] == 0} {
	    Flag_NoUnseen
	}
    }
    set ix [lsearch $flist(unvisited) $folder]
    if {$ix >= 0} {
	set flist(unvisited) [lreplace $flist(unvisited) $ix $ix]
    }
    set ix [lsearch $flist(unvisitedNext) $folder]
    if {$ix >= 0} {
	set flist(unvisitedNext) [lreplace $flist(unvisitedNext) $ix $ix]
    }
}

proc FlistSort { dirlist } {
    # Order the folder list according to a pattern template.
    # Patterns early in the list have higher priority.

    # Hack to check against mh-e .folders file
    if [regexp {\("\+} $dirlist] {
	global flist
	error \
"Conflict with mh-e $flist(cacheFile).  Either remove it or override its name.
The mh-e variable is mh-folder-list-filename.
For exmh, set the variable flist(cacheFile) to another file.
Add this to your user.tcl file (see exmh-custom man page for details).
set flist(cacheFile) /usr/joe/Mail/.exmhfolders
"
    }
    global mhProfile
    set patterns $mhProfile(folder-order)

    set max [llength $patterns]
    set dirlist [lsort $dirlist]
    foreach f $dirlist {
	set patLength($f) 0
    }
    foreach f $dirlist {
	set hit 0
	for {set pri 0} {$pri < $max} {incr pri} {
	    set pat [lindex $patterns $pri]
	    set patLen [string length $pat]
	    if {$patLen > $patLength($f)} {
		if [string match $pat $f] {
		    set priority($f) $pri
		    set patLength($f) $patLen
		    set hit 1
		}
	    }
	}
	if {! $hit} {
	    set priority($f) $max
	}
    }
    foreach f $dirlist {
	set hide 0
	if {$f == {}} {
	    set hide 1
	}
	foreach pat $mhProfile(folder-ignore) {
	    if [string match $pat $f] {
		set hide 1
		break
	    }
	}
	if {! $hide} {
	    lappend pset($priority($f)) $f
	}
    }
    set result ""
    for {set pri 0} {$pri <= $max} {incr pri} {
	if [info exists pset($pri)] {
	    append result $pset($pri) " "
	}
    }
    return $result
}

proc Flist_NextUnvisited { } {
    # Return the next folder in Folder-Order that has unseen messages
    global flist exmh mhProfile

    foreach f $flist(unvisited) {
	if {[string compare $f $exmh(folder)] != 0} {
	    return $f
	}
    }
    foreach f $flist($mhProfile(unseen-sequence)) {
	if {[string compare $f $exmh(folder)] != 0} {
	    return $f
	}
    }
    set first [lindex $flist(allfolders) 0]
    if {$flist(cycleBack) && [string compare $first $exmh(folder)]} {
	return $first
    } else {
	return {}
    }
}
proc Flist_Visited { f } {
    global flist
    set ix [lsearch $flist(unvisited) $f]
    if {$ix >= 0} {
	set flist(unvisited) [lreplace $flist(unvisited) $ix $ix]
    }
}

# exmh-2.5 APIS
proc Flist_FindUnseen args {
  eval Flist_FindSeqs $args
}
proc Flist_NumUnseen {folder seq} {
  Seq_Count $folder $seq
}
# Flist_AddUnseen
# Flist_ForgetUnseen
# Flist_MsgSeen
# Flist_NextUnseen
# Flist_NumUnseen
# Flist_ResetUnseen
# Flist_UnseenMsgs
