# 
# scan.tcl
#
# Folder scanning, with optimizations.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

#### Display folder contents

proc Scan_Folder {folder {adjustDisplay 1}} {
    Exmh_Debug Scan_Folder $folder $adjustDisplay
    Exmh_Debug Scan_Folder [time [list ScanFolder $folder $adjustDisplay]]
}
proc ScanFolder {folder adjustDisplay} {
    global mhProfile flist ftoc exwin exmh

    if {[string compare $folder $ftoc(folder)] == 0} {
	Exmh_Debug Updating $folder
	set update 1	;# Need to check for new messages.
	set samefolder 1	;# Same folder as before
	ScanAddLineInit
    } else {
	set samefolder 0
	set cacheFile $mhProfile(path)/$folder/.xmhcache
	if [catch {open $cacheFile} input] {
	    # No cache, scan last N messages
	    Exmh_Status "Limit scan $folder last:$ftoc(scanSize) - Rescan?" warn
	    set input  [open "|$mhProfile(scan-proc) [list +$folder] \
		    last:$ftoc(scanSize) -width $ftoc(scanWidth) -noheader"]
	    set ftoc(displayDirty) 1
	    set update 0
	} else {
	    Exmh_Debug "loading .xmhcache"
	    set ftoc(displayDirty) 0
	    set update 1	;# Need to check for new messages.
	}
	ScanAddLineReset $folder
	ScanAddLines [read $input]
	catch {close $input}
    }

    if {$update} {
	# Add new messages to cached information
	# Scan last message (again) plus any new messages
	if {! $samefolder} {
	    Ftoc_Reset [Widget_TextEnd $exwin(ftext)] {} $folder
	}
	if {$ftoc(numMsgs) > 0} {
	    set msgid [Ftoc_MsgNumber $ftoc(numMsgs)]
	    if [catch {
		Exmh_Debug Scanning new messages $msgid-last
		set input [open "|$mhProfile(scan-proc) [list +$folder] \
		    $msgid-last -width $ftoc(scanWidth) -noheader"]
		set check [gets $input]
		set new [read $input]
		close $input
		Exmh_Debug Scan complete
	    } err] {
		# The last message no longer exists
		Exmh_Debug No last msg $msgid: $err
	    } else {
		set msgid2 [Ftoc_MsgNumberRaw $check]
		if {$msgid2 == $msgid} {
		    # Last message still matches: add the new lines
		    ScanAddLines $new
		    set ftoc(displayDirty) 1
		    set update 0	;# OK
		} else {
		    Exmh_Debug "My last $msgid != $msgid2"
		}
	    }
	}
	if {$update} {
	    # Something went wrong: rescan
	    if {[Ftoc_Changes "Scan Update Failed"] == 0} {
	    Exmh_Status "scan +$folder last:$ftoc(scanSize)"
		Background_Wait
		set input  [open "|$mhProfile(scan-proc) [list +$folder] \
			last:$ftoc(scanSize) -width $ftoc(scanWidth) -noheader"]
		set ftoc(displayDirty) 1
		ScanAddLineReset $folder
		ScanAddLines [read $input]
		catch {close $input}
	    }
	}
    }
    ScanAddLineCleanup $folder
    if {! $samefolder} {
	Msg_Reset [Widget_TextEnd $exwin(ftext)] $folder
    } else {
	Ftoc_Update [Widget_TextEnd $exwin(ftext)]
    }
    set ftoc(displayValid) 1
    if {$adjustDisplay} {
	Ftoc_Yview end
    }
    return
}
proc Scan_FolderForce {{folder ""}} {
    global exmh mhProfile ftoc
    if {$folder == ""} {
	set folder $exmh(folder)
    }
    set cacheFile $mhProfile(path)/$folder/.xmhcache
    if {$folder == ""} {
	Exmh_Status "No current folder" warning
    } elseif {$folder != $exmh(folder)} {
	# If we aren't currently viewing the folder, just delete
	# the cache file and we'll take care of this later
	Exmh_Debug "Clearing $cacheFile"
	file delete $cacheFile
    } elseif {! [Ftoc_Changes Rescan]} {
	Background_Wait
	Label_Folder $folder
	Exmh_Status "rescanning $folder ..."
	Scan_IO $folder [open "|$mhProfile(scan-proc) [list +$folder] \
		-width $ftoc(scanWidth) -noheader"]
	set ftoc(displayValid) 1
	set ftoc(displayDirty) 1
	Ftoc_Yview end
	Seq_Msgs $folder $mhProfile(unseen-sequence)
	Ftoc_ShowSequences
	Exmh_Status ok
    }
}
proc Scan_FolderUpdate { folder } {
    global ftoc

    if !$ftoc(displayValid) {
        return                  ;#  don't update pseudo-displays
    }
    Label_Folder $folder
    Scan_Folder $folder 0
}
proc Scan_Iterate { incout linenoVar body } {
    upvar $linenoVar lineno
    foreach lineno [split $incout \n] {
	if [regexp ^Incorporating $lineno] {
	    continue
	}
	if {[string length $lineno] > 0} {
	    uplevel $body
	}
    }
}

proc Scan_Inc {folder incOutput} {
    global exwin ftoc
    # Append output of an Inc to the scan display
    ScanAddLineInit
    Scan_Iterate $incOutput line {
	ScanAddLine $line
    }
    ScanAddLineCleanup $folder
    Ftoc_Update [Widget_TextEnd $exwin(ftext)]
    set ftoc(displayDirty) 1
    if {$ftoc(showNew)} {
	Ftoc_Yview end
    }
    Label_Folder $folder
}
proc Scan_IO {folder scanIO } {
    Exmh_Debug Scan_IO [time [list ScanIO $folder $scanIO]]
}
proc ScanIO {folder scanIO } {
    global exmh exwin

    ScanAddLineReset $folder
    if [catch {
	ScanAddLines [read $scanIO]
	close $scanIO
    } err] {
	Exmh_Status $err warning
	catch {close $scanIO}
    }
    ScanAddLineCleanup $folder
    Msg_Reset [Widget_TextEnd $exwin(ftext)] $folder
}

proc ScanAddLineInit {} {
    global exmh exwin
    $exwin(ftext) configure -state normal
}
proc ScanAddLineReset { folder } {
    global exwin ftoc
    if {$ftoc(folder) == $folder} {
	# Rescanning a folder, so save mark state
#	Ftoc_Save $folder
    }
    ScanAddLineInit
    $exwin(ftext) delete 0.0 end
    update idletasks
}
proc ScanAddLine { line } {
    global exwin
    $exwin(ftext) insert end "$line\n"
}
proc ScanAddLines { text } {
    global exwin
    $exwin(ftext) insert end $text
}
proc ScanAddLineCleanup { folder } {
    global exwin flist ftoc
    if {$ftoc(folder) == $folder} {
	# Restore mark state
#	Ftoc_Restore $folder
    }
    set ftoc(folder) $folder
    $exwin(ftext) configure -state disabled
}
proc Scan_ProjectSelection { msgids } {
    global ftoc exwin
    set lines {}
    set num 0
    foreach lineno [Ftoc_FindMsgs $msgids] {
	if {$lineno != {}} {
	    lappend lines [$exwin(ftext) get $lineno.0 $lineno.end]
	    incr num
	}
    }
    set ftoc(displayValid) 0	;# Don't cache this display
    ScanAddLineReset $ftoc(folder)
    foreach line $lines {
	ScanAddLine $line
    }
    ScanAddLineCleanup $ftoc(folder)
    Ftoc_ClearMsgCache
    Ftoc_ShowSequences $msgids
    Msg_ClearCurrent
    Msg_Reset $num
}
proc Scan_CacheValid {folder} {
    # Maintain a cache of folder listings
    global mhProfile exmh
    set cacheFile $mhProfile(path)/$folder/.xmhcache
    if {![file exists $cacheFile] || ![file size $cacheFile]} {
	return 0
    }
    if {[file mtime $mhProfile(path)/$folder] >
	[file mtime $cacheFile]} {
	return 0
    }
    return 1
}
proc Scan_CacheUpdate {} {
    global exmh mhProfile exwin ftoc
    set folder $exmh(folder)
    if {$folder == {}} {
	return
    }
    if !$ftoc(displayDirty) {
	return
    }
    set cacheFile $mhProfile(path)/$folder/.xmhcache

#
# Display is invalid but changes (deletes) still must be reflected in cache. 
# A full rescan is the penalty you have to pay for deleting messages inside 
# this thing.
#
    if !$ftoc(displayValid) {
	set curLine [Ftoc_ClearCurrent]			;# Clear +
        if [file writable $cacheFile] {
            set scancmd "exec $mhProfile(scan-proc) [list +$folder] \
		    -width $ftoc(scanWidth) -noheader > [list $cacheFile]"
            if [catch $scancmd err] {
                Exmh_Status "failed to rescan folder $folder: $err" warn
            }
        }
	Ftoc_Change $curLine	;# Restore it
    } elseif [catch {
	set cacheIO [open $cacheFile w]
	set curLine [Ftoc_ClearCurrent]			;# Clear +
	set display [$exwin(ftext) get 1.0 "end -1 char"]
	Ftoc_Change $curLine	;# Restore it
	puts $cacheIO $display nonewline
	close $cacheIO
	set ftoc(displayDirty) 0
    } err] {
	Exmh_Debug Scan_CacheUpdate error $err
	catch {close $cacheIO}
    }
}

# Move scan lines to the scan cache for another folder
proc Scan_Move { folder scanlinesR new } {
    global mhProfile
    set cacheFile $mhProfile(path)/$folder/.xmhcache
    if ![file writable $cacheFile] {
	Exmh_Debug Scan_Move $folder scan cache not writable
	return
    }
    # Reverse engineer the scan format
    if ![regexp {( *)([0-9]+)} [lindex $scanlinesR 0] prefix foo2 number] {
	Exmh_Debug Scan_Move cannot handle scan format
	return
    }
    set len [string length $prefix]
    set fmt [format "%%%dd%%s" $len]
    set cacheIO [open $cacheFile a]
    for {set i [expr [llength $scanlinesR]-1]} {$i >= 0} {incr i -1} {
	set line [lindex $scanlinesR $i]
	if [regsub {( *[0-9]+)(\+)} $line {\1 } newline] {
	    puts $cacheIO [format $fmt $new [string range $newline $len end]] \
		nonewline
	} else {
	    puts $cacheIO [format $fmt $new [string range $line $len end]] \
		nonewline
	}
	incr new
    }
    close $cacheIO
}
proc Scan_AllFolders { {force 0} } {
    global flist mhProfile ftoc wish
    if [catch {open [Env_Tmp]/scancmds w} out] {
	Exmh_Status "Scan_AllFolders $out"
	return
    }
    set ctx [Env_Tmp]/scanctx
    puts $out "wm withdraw ."
    set myname [winfo name .]
    puts $out "catch \{ exec touch $ctx.\[pid\] \}"
    puts $out "set env(MHCONTEXT) $ctx.\[pid\]"
    foreach f $flist(allfolders) {
	if {$force || ! [Scan_CacheValid $f]} {
	    puts $out "catch \{send $myname \{Exmh_Status \"scan +$f\"\}\}"
	    puts $out "catch {
		set out \[open $mhProfile(path)/$f/.xmhcache w $mhProfile(msg-protect)\]
		exec $mhProfile(scan-proc) +$f -width $ftoc(scanWidth) -noheader >@\$out
		close \$out
	    }"
	}
    }
    puts $out "catch \{send $myname \{Exmh_Status \"scans completed\"\}\}"
    puts $out "file delete -force $ctx.\[pid\]"
    puts $out exit
    close $out
    Exmh_Status "wish -f [Env_Tmp]/scancmds &"
    exec $wish -f [Env_Tmp]/scancmds &
}
