# 
# folder.tcl
#
# Folder operations, minus scan & inc.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Folder_Init {} {
    global exmh argc argv mhProfile
    set exmh(target) {}		;# Name of target, for refile
    set exmh(started) 0		;# For Folder_Change, the first time
    if {$argc > 0 && \
	[file isdirectory $mhProfile(path)/[lindex $argv 0]]} then {
	#scan named folder
	set exmh(folder) $argv
    } else {
	if [catch {exec folder -fast < /dev/null} folder] {
	    set exmh(folder) {}
	} else {
	    set exmh(folder) $folder
	}
    }
}

proc Folder_Summary { folder } {
    global mhProfile env
    if [catch {pwd} cwd] {
	Exmh_Status $cwd
	cd
	set cwd [pwd]
    }
    if [catch {cd $mhProfile(path)/$folder}] {
	catch {cd $cwd}
	return "${folder}+ does not exist"
    }
    set low 100000
    set high 0
    set num 0
    if {[catch {glob *} files] == 0} {
	foreach f $files {
	    if {[regexp {^[0-9]+$} $f]} {
		if {$f < $low} {
		    set low $f
		}
		if {$f > $high} {
		    set high $f
		}
		incr num
	    }
	}
    }
    catch {cd $cwd}
    if {$num <= 0} {
	return "${folder}+ has no messages"
    } else {
	return "${folder}+ $num msgs ($low-$high)"
    }
}

proc Folder_Change {folder {msgShowProc {Msg_Show cur}}} {
    Exmh_Debug Folder_Change $folder $msgShowProc
    Exmh_Debug Folder_Change $folder [time [list  FolderChange $folder $msgShowProc]]
}
proc FolderChange {folder msgShowProc} {
    global exmh mhProfile ftoc msg
    if {[string compare [wm state .] normal] != 0} {
	if {$exmh(iconic)} {
	    # Ignore once if starting up with -iconic flag
	    set exmh(iconic) 0
	} else {
	    wm deiconify .
	}
    }
    if {$exmh(started) && [Ftoc_Changes "Change folder"] > 0} {
	# Need to reselect previous button here
	return
    }
    # Trim off leading mail path
    if [regsub ^$mhProfile(path)/ $folder {} newfolder] {
	set folder $newfolder
    }
    if {[string length $folder] == 0} {
	return
    }
    if ![file isdirectory $mhProfile(path)/$folder] {
	Exmh_Status "Folder $folder doesn't exist" error
	return
    }
    set oldFolder $exmh(folder)
    Exmh_Status "Changing to $folder ..."
    set msg(id) ""
    if {$folder != $exmh(folder)} {
	Exmh_Debug Exmh_CheckPoint [time Exmh_CheckPoint]
	global mhProfile
	set summary [Mh_Folder $folder]	;# Set MH folder state
    } else {
	if {$ftoc(folder) == {} && $exmh(started)} {
	    # pseudo-display -> Checkpoint to set cur msg
	    # startup -> don't checkpoint (clears cur sequence)
	    Exmh_Debug Exmh_CheckPoint [time Exmh_CheckPoint]
        }
	set summary {}
    }
    set ftoc(displayValid) 1
    set exmh(started) 1
    global folderHook
    if [info exists folderHook(leave,$oldFolder)] {
	$folderHook(leave,$oldFolder) $oldFolder leave
    }
    Label_Folder $folder $summary
    Fdisp_HighlightCur $folder
    Flist_Visited $folder
    set exmh(folder) $folder
    Flist_UnseenUpdate $folder 0
    Scan_CacheUpdate
    Ftoc_ShowSequences
    Exmh_Status $folder
    # Usually {Msg_Show $seq} or {Msg_Change $msg}
    eval $msgShowProc

    # Take any required folder-specific action (e.g., for drafts folder)
    if [info exists folderHook(enter,$folder)] {
	$folderHook(enter,$folder) $folder enter
    }
    foreach cmd [info commands Hook_FolderChange*] {
	$cmd $folder
    }
    foreach seq [option get . sequences {}] {
	BgRPC Seq_Msgs $oldFolder $seq
    }
}

proc Folder_Target {folder} {
    global exmh mhProfile

    if ![file isdirectory $mhProfile(path)/$folder] {
	Exmh_Status "$mhProfile(path)/$folder doesn't exist"
	return 0
    }
    if {$exmh(folder) == $folder} {
	Exmh_Status "Target must be different than current" warning
	return 0
    }
    Fdisp_HighlightTarget $folder
    set exmh(target) $folder
    Exmh_Status "$folder is target for moves and copies"
    return 1
}
proc Folder_TargetMove { folder {moveProc Ftoc_MoveMark} } {
    if [Folder_Target $folder] {
	Msg_Move $moveProc
	Fcache_Folder $folder
    }
}

proc Folder_TargetCopy { folder {copyProc Ftoc_CopyMark} } {
    if [Folder_Target $folder] {
	Msg_Move $copyProc advance?
	Fcache_Folder $folder
    }
}

proc Folder_TargetClear {} {
    global exmh

    Fdisp_HighlightTarget ""
    set exmh(target) ""
    Exmh_Status "No target set for moves and copies"
}


proc Folder_Sort { args } {
    global exmh

    if {[Ftoc_Changes "Sort"] == 0} then {
	Background_Wait
	Exmh_Status "Sorting folder..."
	eval {Mh_Sort $exmh(folder)} $args
	Scan_FolderForce
	set id [Mh_Cur $exmh(folder)]
	if {$id != {}} {
	    Msg_Change $id skipdisplay
	} else {
	    Msg_ClearCurrent
	}
    }
}

proc Folder_Previous {} {
    set folder [Ftoc_LastFolder]
    if {[string length $folder]} {
	Folder_Change $folder
    }
}

proc Folder_Pack {} {
    global exmh

    if {[Ftoc_Changes "Pack"] == 0} then {
	Background_Wait
	Exmh_Status "Packing folder..."
	Mh_Pack $exmh(folder)
	Scan_FolderForce
	set id [Mh_Cur $exmh(folder)]
	if {$id != {}} {
	    Msg_Change $id skipdisplay
	} else {
	    Msg_ClearCurrent
	}
    }
}
proc Folder_Commit { {rmmCommit Mh_Rmm} {moveCommit Mh_Refile} {copyCommit Mh_Copy} } {
    busy FolderCommit $rmmCommit $moveCommit $copyCommit
    return 0
}
proc FolderCommit { rmmCommit moveCommit copyCommit } {
    global exmh exwin ftoc

    Ftoc_Commit $rmmCommit $moveCommit $copyCommit
    Exmh_Debug Scan_CacheUpdate [time Scan_CacheUpdate]

    if $ftoc(autoPack) {
	Background_Wait	;# Let folder ops complete
        Folder_Pack	;# Before packing
    }
    Label_Folder $exmh(folder)
}
# Streamlined Commit called before Folder_Change
proc Folder_CommitType { type } {
    global ftoc exmh
    Exmh_Debug Folder_CommitType $type
    if {[string compare $type "Change folder"] == 0} {
	busy Ftoc_Commit Mh_Rmm Mh_Refile Mh_Copy
	if $ftoc(autoPack) {
	    Background_Wait	;# Let folder ops complete
	    Folder_Pack		;# Before packing
	}
    } else {
	Folder_Commit
    }
}

proc Folder_Purge { {folder {}} } {
    global exmh
    if {[string length $folder] == 0} {
	set folder $exmh(folder)
    }
    set uid 0
    while {[file exists [set fn /tmp/exmh.[pid].touch.$uid]]} {
	incr uid
    }
    exec touch $fn
    set now [file mtime $fn]
    File_Delete $fn

    global mhProfile
    if ![info exists mhProfile(delprefix)] {
	set mhProfile(delprefix) #
    }
    if ![info exists mhProfile(purgeage)] {
	set mhProfile(purgeage) 7
    }
    set purgesecs [expr $mhProfile(purgeage) * 24 * 60 * 60]
    set n 0
    foreach file [glob -nocomplain $mhProfile(path)/$folder/$mhProfile(delprefix)*] {
	if {[file mtime $file] + $purgesecs < $now} {
	    Exmh_Debug Purge $file
	    File_Delete $file
	    incr n
	}
    }
    if {$n > 0} {
	Exmh_Status "Folder_Purge $folder $n msgs purged"
    }
    return $n
}

proc Folder_PurgeAll {} {
    global flist
    set n 0
    foreach folder $flist(allfolders) {
	incr n [Folder_Purge $folder]
    }
    if {$n > 0} {
	Exmh_Status "Folder_PurgeAll $n msgs purged total"
    }
}

proc Folder_PurgeBg { {folderlist {}} } {
    global exmh mhProfile wish
    if {[string length $folderlist] == 0} {
	set folderlist $exmh(folder)
    }
    set uid 0
    while {[file exists [set fn [Env_Tmp]/exmh.[pid].purge.$uid]]} {
	incr uid
    }
    catch {File_Delete}	;# auto-load it

    set out [open $fn w]
    puts $out "wm withdraw ."
    puts $out "source $exmh(library)/folder.tcl"
    puts $out [list set mhProfile(delprefix) $mhProfile(delprefix)]
    puts $out [list set mhProfile(purgeage) $mhProfile(purgeage)]
    puts $out [list set mhProfile(path) $mhProfile(path)]
    puts $out "proc Exmh_Status { s } \{catch \{send \"[winfo name .]\" \[list Exmh_Status \$s]\}\}"
    puts $out "proc Exmh_Debug { args } {}"
    puts $out [list proc File_Delete [info args File_Delete] [info body File_Delete]]
    foreach folder $folderlist {
	puts $out "Folder_Purge $folder"
    }
    puts $out "exec rm $fn"
    puts $out exit
    close $out
    exec $wish -f $fn &
}
proc Folder_PurgeAllBg {} {
    global flist
    Folder_PurgeBg $flist(allfolders)
}
proc Folder_IsShared {folder} {
    global folder
    set folder(shared,$folder) 1
}
proc Folder_FindShared {} {
    global mhProfile
    if {[catch {open $mhProfile(path)/.folders_shared} in]} {
	Exmh_Debug Folder_FindShared $in
	return
    }
    foreach folder [split [read $in] \n] {
	Folder_IsShared $folder
    }
    close $in
}

# exmh-2.5 APIs
# Folder_CheckPointShared
# Folder_Unseen
