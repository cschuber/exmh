# msg.tcl
#
# Operations on messages
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Msg_Init {} {
    Preferences_Resource msg(tagnames) m_tagnames general
    Preferences_Resource msg(tag,general) m_general {-relief flat}
    Msg_Reset 0
}

proc Msg_Reset { numMsgs {folder {}} } {
    # Reset state after scanning a new folder
    global msg
    set msg(dpy)  {}			;# Currently displayed message
    set msg(id) [Mh_Cur $folder]	;# pick current message
    set msg(path) ""			;# File pathname of current message
    Buttons_Current [expr {$msg(id) != {}}]	;# Enable/disable buttons
    Ftoc_Reset $numMsgs $msg(id) $folder	;# Reset display
}
proc Msg_Pick { line {show show} } {
    # Select a message
    global exwin msg
    Exmh_Debug Msg_Pick line=$line
    set msgNum [Ftoc_MsgNumber $line]
    if {$msgNum != {} && $msgNum != 0} {
	Ftoc_RangeUnHighlight
	Msg_Change $msgNum $show
    } else {
	Msg_ClearCurrent
    }
}
proc Msg_Show { {seq cur} {show show} } {
    global exmh msg
    Exmh_Debug Msg_Show $seq $show
    if {$seq != "cur"} {
	foreach id [Seq_Msgs $exmh(folder) $seq] {
	    if {![Ftoc_Marked $id]} {
		Msg_Change $id $show
		return 1
	    }
	}
	# If we can't find a message in $seq, then fall through to do
	# what we would have done if we were going to 'cur'.
    } 
    if {$msg(id) != {}} {
	set msg(dpy) {}	;# force redisplay
	Msg_Change $msg(id) $show
	return 1
    } else {
	Msg_ClearCurrent
	Ftoc_Yview end
	return 0
    }
    return 0
}
proc Msg_ShowCurrent {} {
    Msg_Show cur
}
proc Msg_ClearCurrent { } {
    global msg exmh
    set msg(id) {}		;# Clear current message
    set msg(dpy) {}		;# and currently displayed message
    Seq_Forget $exmh(folder) cur
    MsgClear
    Buttons_Current 0
    Uri_ClearCurrent
}
proc MsgClear {} {
    global exwin msg
    Label_Message ""
    set msg(dpy) {}
    $exwin(mtext) configure -state normal
    $exwin(mtext) delete 0.0 end
    $exwin(mtext) configure -state disabled
    Face_Delete
    catch {destroy $exwin(mopButtons).list}
}
proc Msg_ShowSomething {} {
    global exmh msg mhProfile
    set order [list $mhProfile(unseen-sequence) cur]
    foreach pick $order {
	if {[catch {MhExec pick +$exmh(folder) $pick} tmp] == 0} then {
	    Msg_Change [lindex $tmp 0] show
	    return
	}
    }
    # Hack
    global ftoc
    Msg_Pick $ftoc(numMsgs) show
}
proc Msg_First { {show noshow} } {
    Msg_Change [Ftoc_MsgNumber 1] $show
}

proc Msg_Last { {show noshow} } {
    global ftoc
    Msg_Change [Ftoc_MsgNumber $ftoc(numMsgs)] $show
}

proc Msg_Change {msgid {show show} } {
    Exmh_Debug Msg_Change id=$msgid
    Exmh_Debug Msg_Change [time [list MsgChange $msgid $show]]
}
proc MsgChange {msgid {show show}} {
    global exmh exwin msg mhProfile
    
    Ftoc_ClearCurrent
    set oldcur [Seq_Msgs $exmh(folder) cur]
    Mh_SetCur $exmh(folder) $msgid
    Ftoc_ShowSequence cur [concat $oldcur $msgid]
    set lineno [Ftoc_FindMsg $msgid]
    if {! [Ftoc_Change $lineno $show]} {
	Exmh_Status "Cannot find msg $msgid - Rescan?"
    } else {
	if {$msg(id) == {}} {
	    Buttons_Current 1
	}
	set msg(id) $msgid
	set msg(path) $mhProfile(path)/$exmh(folder)/$msg(id)
	if {$show == "show"} {
	    MsgShow $msgid
	    Seq_Del $exmh(folder) $mhProfile(unseen-sequence) $msgid
	} elseif {$show != "skipdisplay"} {
	    MsgClear
	}
	if {$lineno != {}} {
	    Ftoc_MoveFeedback $msgid
	}
    }
}

proc MsgSeen { msgid } {
    # Suppress duplicates or else mark does the wrong thing.
    global msg exmh mhProfile
    Seq_Del $exmh(folder) $mhProfile(unseen-sequence) $msgid
    Flag_MsgSeen
}

# Message operations.
# These take two forms of arguments.  The original form is a single
# argument that is the name of a hook procedure.  The new form is
# a set of arguments for the underlying MH command.  The distinction is
# made by seeing if the argument is the name of a Tcl command, if
# not it is assumed to be arguments to the MH command.

proc Msg_Compose { args } {
    if {[string length $args] == 0} {
	set args Mh_CompSetup
    }
    if {[string compare [info command $args] $args] == 0} {
	# Old interface with hook procedure
	if [catch {$args} err] {			;# Setup draft msg
	    Exmh_Status "$args: $err" error
	    return
	}
    } else {
	if {![eval MsgComp $args]} {
	    return
	}
    }
    Edit_Draft					;# Run the editor
}
proc Msg_CompUse {folder id} {
    global mhProfile
    if {[string compare $folder $mhProfile(draft-folder)] == 0} {
	Mh_SetCur $mhProfile(draft-folder) $id
	Msg_Compose $id -use
    } else {
	Msg_Compose +$folder $id
    }
}
# Compose a message to a particular person
proc Msg_CompTo {address args} {
    eval {Msg_Mailto "mailto:$address"} $args
}

# Compose a message based on a mailto URL
proc Msg_Mailto {url args} {
    global mhProfile
    if {![eval MsgComp $args]} {
	return
    }
    set draftID [Mh_Cur $mhProfile(draft-folder)]
    if {$draftID == {}} {
	return
    }
    # See RFC 2368 for mailto: URL syntax
    regsub mailto: $url {} url
    if [catch {
	set path $mhProfile(path)/$mhProfile(draft-folder)/$draftID
	set in [open $path]
	set X [read $in]
	close $in
	if {[regexp -nocase {\?} $url]} {
	    regsub -nocase {.*\?} $url {} headers
	    foreach hdr [split $headers &] {
		if {[regexp -nocase {body=} $hdr]} {
		    regsub -nocase {body=} $hdr {} body
		    set body [MsgDecodeURL $body]
		} else {
		    regexp {(.*)=(.*)} $hdr {} hdr_name hdr_value
		    set hdr_name [string toupper [string range $hdr_name 0 0]][string tolower [string range $hdr_name 1 end]]
		    set hdr_value [MsgDecodeURL $hdr_value]
		    if {[string compare $hdr_name To] == 0} {
			set to $hdr_value
		    }
		    if {![regsub -nocase "(^|\n)$hdr_name:\[^\n\]*\n" $X "\\1$hdr_name: $hdr_value\n" X]} {
			set hend [string last "\n--" $X]
			set X "[string range $X 0 $hend]$hdr_name: $hdr_value\n[string range $X [expr $hend + 1] end]"
		    }
		}
	    }
	    regsub -nocase {\?.*} $url {} url
	}
	if [info exists body] {
	    append X "\n$body" 
	}
	set url [MsgDecodeURL $url]
	if {[string length $url]>0} {
	    if [info exists to] {
		regsub -nocase "(^|\n)to:\[^\n\]*\n" $X "\\1To: $url, $to\n" X
	    } else {
		regsub -nocase "(^|\n)to:\[^\n\]*\n" $X "\\1To: $url\n" X
	    }
	} else {
	    if [info exists to] {
		regsub -nocase "(^|\n)to:\[^\n\]*\n" $X "\\1To: $to\n" X
	    }
	}
	set out [open $path w]
	puts -nonewline $out $X
	close $out
    } err] {
	Exmh_Status $err
	return
    }
    Edit_Draft					;# Run the editor
}

# Use current selection as To: header
proc Msg_CompSel {args} {
    global mhProfile
    if {[catch {selection get} address]} {
	Exmh_Status "Select an address for Msg_CompTo"
	return
    }
    eval {Msg_CompTo $address} $args
}

# General wrapper around comp
proc MsgComp {args} {
    # allow args to include $exmh(folder) $msg(id) $mhProfile(path)
    global exmh msg mhProfile	
    if [catch {
	set ix [lsearch $args -form]
	if {$ix < 0} {
	    if [file exists $mhProfile(path)/$exmh(folder)/components] {
		lappend args -form $exmh(folder)/components
	    }
	}
	Exmh_Status "comp $args"
	eval {MhExec comp -nowhatnowproc} $args
	set exmh([Mh_Cur $mhProfile(draft-folder)],action) comp
    } err] {
	Exmh_Status "comp: $err"
	return 0
    }
    return 1
}

proc Msg_ReplyAll { } {
    global nmh
    
    if {$nmh == 1} {
	Msg_Reply -group
    } else {
	Msg_Reply -cc to -cc cc
    }
}

proc Msg_Reply { args } {
    global exmh msg mhProfile
    if {[string length $args] == 0} {
	set args Mh_ReplySetup
    }
    
    if [MsgOk $msg(id) m] {
	Quote_MakeFile $exmh(folder) $m
	set edit 1
	if {[string compare [info command $args] $args] == 0} {
	    # Old interface with hook procedure
	    if [catch {$args $exmh(folder) $m} err] {	;# Setup draft msg
		Exmh_Status "${args}: $err" error
		Quote_Cleanup
		return
	    }
	} else {
	    Exmh_Status "repl $args" error
	    if [catch {
		set ix [lsearch $args -noedit]
		if {$ix >= 0} {
		    set edit 0
		    set args [lreplace $args $ix $ix]
		}
		set ix [lsearch $args -form]
		if {$ix < 0} {
		    set path [Mh_FindFile "replcomps"]
		    if {0 != [string length $path]} {
			lappend args -form $path/replcomps
			Exmh_Status "repl $args" error
		    }
		}
		eval {MhExec repl +$exmh(folder) $m -nowhatnowproc} $args
		eval {MhAnnoSetup $exmh(folder) $m repl} $args
	    } err] {	;# Setup draft msg
		Exmh_Status "repl: $err" error
		Quote_Cleanup				;# Nuke @ link
		return
	    }
	}
	if {$edit} {
	    Edit_Draft					;# Run the editor
	} else {
	    Edit_Done send				;# Just send it
	}
    }
}

proc Msg_Forward { args } {
    global exmh msg mhProfile
    if {[string length $args] == 0} {
	set args Mh_ForwSetup
    }
    
    set msgids [Ftoc_CurMsgs]
    if {[llength $msgids] > 0} {
	set mime 0
	if [info exists mhProfile(forw)] {
	    if {[lsearch $mhProfile(forw) -mime] >= 0} {
		set mime 1
	    }
	}
	if {[string compare [info command $args] $args] == 0} {
	    # Old interface with hook procedure
	    if [catch {$args $exmh(folder) $msgids} err] {	;# Setup draft msg
		Exmh_Status "${args}: $err" error
		return
	    }
	}  else {
	    Exmh_Status "forw +$exmh(folder) $msgids $args"
	    if [catch {
		if {[lsearch $args -mime] >= 0} {
		    set mime 1
		}
		set ix [lsearch $args -form]
		if {$ix < 0} {
		    if [file exists $mhProfile(path)/$exmh(folder)/forwcomps] {
			lappend args -form $exmh(folder)/forwcomps
			Exmh_Status "forw +$exmh(folder) $msgids $args"
		    }
		}
		eval {MhExec forw +$exmh(folder)} $msgids -nowhatnowproc $args
		eval {MhAnnoSetup $exmh(folder) $msgids forw} $args
		if {$mhProfile(forwtweak)} {
		    Mh_Forw_MungeSubj $exmh(folder) $msgids
		}
	    } err] {
		Exmh_Status "forw: $err" error
		return
	    }
	}
	# sedit hack
	global sedit
	set old $sedit(mhnDefault)
	if {$mime} {set sedit(mhnDefault) 1}
	Edit_Draft					;# Run the editor
	set sedit(mhnDefault) $old
    }
}

proc Msg_Dist { args } {
    global exmh msg
    if {[string length $args] == 0} {
	set args Mh_DistSetup
    }
    
    if [MsgOk $msg(id) m] {
	if {[string compare [info command $args] $args] == 0} {
	    # Old interface with hook procedure
	    if [catch {$args $exmh(folder) $m} err] {   ;# Setup draft msg
		Exmh_Status "${args}: $err" error
		return
	    }
	}  else {
	    if [catch {
		Exmh_Status "dist +$exmh(folder) $m"
		eval {MhExec dist +$exmh(folder) $m} -nowhatnowproc $args
		eval {MhAnnoSetup $exmh(folder) $m dist} $args
	    } err] {
		Exmh_Status "dist: $err" error
		return
	    }
	}
	Edit_Draft                                  ;# Run the editor
    }
}

proc MsgOk { number msgvar } {
    upvar $msgvar msg
    if {$number != ""} {
	set msg $number
	return 1
    } else {
	Exmh_Status "No valid message number" warning
	return 0
    }
}

proc Msg_Remove { {rmProc Ftoc_RemoveMark} {show show} } {
    Exmh_Debug Msg_Remove $rmProc $show
    Ftoc_Iterate lineno {
	Exmh_Debug Msg_Remove l=$lineno
	$rmProc $lineno
    }
    if {[Ftoc_PickSize] == 1} {
	Ftoc_NextImplied $show
    }
}
proc Msg_RemoveNoshow { {rmProc Ftoc_RemoveMark} } {
    Msg_Remove $rmProc noshow
}
proc Msg_RemoveById { msgid {rmProc Ftoc_Delete} } {
    global msg
    set lineno [Ftoc_FindMsg $msgid]
    $rmProc $lineno
    if {$msg(id) == $msgid} {
	Msg_ClearCurrent
    }
}
proc Msg_Move { {moveProc Ftoc_MoveMark} {advance 1} {show show} } {
    global exmh fdisp
    
    if {$exmh(target) == ""} {
	Exmh_Status "Must first click button $fdisp(tarbutton) on folder label to pick destination" error
	return
    }
    if { $exmh(target) != $exmh(folder)} then {
	Ftoc_Iterate lineno {
	    $moveProc $lineno
	}
	Exmh_Status "=> $exmh(target)"
	if {[Ftoc_Advance $advance] && ([Ftoc_PickSize] == 1)} {
	    Ftoc_NextImplied $show
	}
    } else {
	Exmh_Status "Move or copy requires target folder != current folder"
    }
}
proc Msg_MoveNoshow { {moveProc Ftoc_MoveMark} } {
    Msg_Move $moveProc 1 noshow
}
proc Msg_Clip { {folder {}}  {id {}} } {
    # "Tear off" a message into a top-level text widget
    global mhProfile exmh msg exwin
    
    if {$folder == {}} {set folder $exmh(folder)}
    if {$id     == {}} {set id     $msg(id)}
    
    if {$id == {}} {
	Exmh_Status "Select a message to clip first" warning
	return
    }
    if ![info exists msg(tearid)] {
	set msg(tearid) 0
    } else {
	incr msg(tearid)
    }
    set self [Widget_Toplevel .tear$msg(tearid) "$folder $id" Clip]
    
    Widget_Frame $self but Menubar {top fill}
    Widget_AddBut $self.but quit "Dismiss" [list destroy $self]
    Widget_Label $self.but label {left fill} -text $folder/$id
    set cursor [option get $self cursor Text]
    set t [Widget_Text $self $exwin(mtextLines) -cursor $cursor -setgrid true]
    Msg_Setup $t
    if [MsgShowInText $t $mhProfile(path)/$folder/$id] {
	foreach cmd [info commands Hook_MsgClip*] {
            if [catch {$cmd $mhProfile(path)/$folder/$id $t} err] {
		SeditMsg $t "$cmd $err"
	    }
        }
    }
    
}
proc Msg_FindMatch {L string} {
    global exwin
    return [FindTextMatch $exwin(mtext) $L $string]
}
proc Msg_BurstDigest {} {
    global msg exmh mhProfile
    
    if {$msg(id) == {}} {
	Exmh_Status "No message selected to burst" error
	return
    }
    if {[Ftoc_Changes "Burst Digest"] != 0} {
	# Pending changes and no autoCommit
	return
    }
    
    Exmh_Status "Bursting message $msg(id) in $exmh(folder)..."
    
    # burst the digest; catch the output
    if [catch { MhExec burst -verbose $msg(id) +$exmh(folder)} out] {
	Exmh_Status "Error bursting digest: $out"
    } else {
	# burst OK, split up the output
	set allmsgids {}
	foreach line [ split $out \n] {
	    #extract the new message number and save in $allmsgids
	    if [regexp {of digest .* becomes message ([0-9]+)} $line match msgid] {
		lappend allmsgids $msgid
	    }
	}
	set allmsgids [lsort -increasing -integer $allmsgids]
	# mark new messages as unread
	Exmh_Debug burst created msgs $allmsgids
	if {$allmsgids != {}} {
	    eval { MhExec mark +$exmh(folder) -sequence $mhProfile(unseen-sequence) } $allmsgids
	}
	# rescan to pick them up, make sure Commit is done.
	Background_Wait
	Exmh_Status "Bursting message $msg(id) in $exmh(folder)...done"
	Scan_FolderUpdate $exmh(folder)
	if {$allmsgids != {}} {
	    Msg_Change [lindex $allmsgids 0]
	} else {
	    Msg_ClearCurrent
	}
    }
}
proc Msg_Save {} {
    global exmh mhProfile
    set files {}
    Ftoc_MsgIterate msgid {
	lappend files $mhProfile(path)/$exmh(folder)/$msgid
    }
    
    set name [FSBox "Select file to create/append to:" ]
    if {$name != {}} {
	set exists [file exists $name]
	if [catch {eval {exec cat} $files {>> $name}} err] {
	    Exmh_Status $err error
	} else {
	    set plural [expr {([llength $files] > 1) ? "s" : ""}]
	    if {$exists} {
		Exmh_Status "Message$plural appended to $name"
	    } else {
		Exmh_Status "Message$plural stored in $name"
	    }
	}
    } else {
	Exmh_Status "canceled"
    }
}

proc Msg_Edit {} {
    global exmh msg editor
    if {$msg(path) == ""} {
	Exmh_Status "No current message"
	return
    }
    Exmh_Status "Editing $exmh(folder)/$msg(id)"
    #
    # Hack because exmh-async isn't appropriate in this case.
    #
    if {$editor(sedit!)} {
	set edittype sedit
    } else {
	set edittype prog
    }
    if [regsub {^([ 	]*)exmh-async(.*)$} $editor($edittype) {\2} newprog] {
	set cmd [split [join [string trimright $newprog "& \t"]]]
	Exmh_Status "Starting $cmd ..." warn
	if [catch {eval exec $cmd $msg(path) &} err] {
	    Exmh_Status $err error
	}
    } else {
	if {$editor($edittype) == "sedit"} {
	    set exmh([SeditId $msg(path)],action) auto
	}
	EditStart $msg(path) $edittype
    }
}

proc Msg_UUdecode {} {
    global msg
    set name [FSBox "Select file to decode into:" ]
    if {$name != {}} {
	Mime_Uudecode $msg(path) $name
    } else {
	Exmh_Status "uudecode canceled"
    }
}

proc Msg_Mark {seq} {
    global exmh mhProfile
    set msgids [Ftoc_CurMsgs]
    Seq_Add $exmh(folder) $seq $msgids
    if {$seq == $mhProfile(unseen-sequence)} {
	Msg_ClearCurrent
	Ftoc_ClearCurrent
    }
    Ftoc_ShowSequence $seq $msgids
}
proc Msg_UnMark {seq} {
    global exmh mhProfile
    set msgids [Ftoc_CurMsgs]
    Seq_Del $exmh(folder) $seq $msgids
    Ftoc_ShowSequence $seq $msgids
}

proc Msg_ReplyHelp {} {
    Help Reply "Defining Reply Buttons and Menu Entries"
}

proc Msg_PageOrNext {} {
    global exwin
    Widget_TextPageOrNext $exwin(mtext) implied
}
proc Msg_PageOrNextCommit {} {
    global exwin
    Widget_TextPageOrNext $exwin(mtext) no
}
proc Msg_PageDown {} {
    global exwin
    Widget_TextPageDown $exwin(mtext)
}
proc Msg_PageUp {} {
    global exwin
    Widget_TextPageUp $exwin(mtext)
}
proc Msg_LineDown {} {
    global exwin
    Widget_TextLineDown $exwin(mtext)
}
proc Msg_LineUp {} {
    global exwin
    Widget_TextLineUp $exwin(mtext)
}
proc Msg_Top {} {
    global exwin
    Widget_TextTop $exwin(mtext)
}
proc Msg_Bottom {} {
    global exwin
    Widget_TextBottom $exwin(mtext)
}
proc Msg_CopySelection {} {
    global exwin sedit
    catch {set sedit(killbuf) [$exwin(mtext) get sel.first sel.last]}
}
proc Msg_Trash { {trashFolder TRASH} } {
    Folder_TargetMove $trashFolder
}
proc MsgDecodeURL { url } {
    regsub -all -nocase {%0a} $url {}   url
    regsub -all -nocase {%0d} $url "\n" url
    regsub -all         {%20} $url { }  url
    regsub -all         {%25} $url {%}  url
    regsub -all -nocase {%2c} $url {,}  url
    regsub -all -nocase {%3c} $url {<}  url
    regsub -all -nocase {%3d} $url {=}  url
    regsub -all -nocase {%3e} $url {>}  url
    regsub -all -nocase {%3f} $url {?}  url
    return $url
}

