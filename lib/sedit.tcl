# sedit
#
# A simple editor for composing mail messages.
# See also the Text and Entry bindings in seditBind.tcl
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc SeditHelp {} {
    Help Sedit "Simple Editor Help"
}
proc SeditId { draft } {
    global mhProfile
    if [regsub ^$mhProfile(path)/$mhProfile(draft-folder)/ $draft {} newdraft] {
	return $newdraft
    } else {
	set newdraft $draft	;# TCL 7.0 bug
	regsub ^$mhProfile(path)/ $draft {} newdraft
	regsub -all {\.} $newdraft _ newdraft
	return $newdraft
    }
}
proc SeditProperSigfileDefault {} {
    global sedit
    if {[string length $sedit(sigfileDefault)] == 0} {
	set sedit(sigfileDefault) ~/.signature
    }
    if ![regexp {^[/~]} $sedit(sigfileDefault)] {
	set sedit(sigfileDefault) ~/$sedit(sigfileDefault)
    }
    return [glob -nocomplain $sedit(sigfileDefault)]
}
proc SeditSigfileDefault {} {
    global intelligentSign
    set propersig [SeditProperSigfileDefault]
    if {$intelligentSign(state)} {
	return {///auto///}
    }
    return $propersig
}
proc Sedit_Start { draft } {
    global sedit intelligentSign quote pgp pgpPass msg
    global exmh	;# for menu references to $exmh(...)
    if ![info exists sedit(init)] {
	Sedit_Init
    }
    if ![info exists sedit(checkpoint)] {
	SeditPeriodicSave
    }
    set id [SeditId $draft]
    set b .sedit${id}.but
    if {[Exwin_Toplevel .sedit$id $draft Sedit] == 0} {
	# Reuse existing window
	set t $sedit($id,text)
	SeditMsg $t $draft
	$t delete 1.0 end
	.sedit$id.but.send config -state normal
	set sedit($t,sigfile) [SeditSigfileDefault]
    } else {
	wm iconname .sedit$id draft/$id
	set f [Widget_Frame .sedit$id f Frame {top expand fill}]
	set t [Widget_Text $f $sedit(height) -setgrid true -wrap char]

	Drop_Attach $t SeditDragDrop

	if {$pgp(enabled) && $pgp(seditpgp)} {
	    set keyid [lindex $pgp(myname) 0]
	    set label "PGP password:"
	    Widget_BeginEntries [string length $label] 10 [list SeditSend $draft $t]
	    Widget_LabeledEntry .sedit$id.pgp $label pgpPass($keyid) \
		    -show *
	    Widget_EndEntries
	}

	set sedit($t,status) [Widget_Entry .sedit${id} status {top fill} -relief raised]

	# Nuke the Dismiss button because the Abort, Send, and Save&Quit
	# buttons pretty much cover the gamut
	set cmd [option get .sedit$id.but.quit command {}]
	if {[string length $cmd] == 0} {
	    set cmd [list SeditQuit $draft $t]
	} else {
	    set cmd [eval list $cmd]
	}
	destroy $b.quit
	wm protocol .sedit$id WM_DELETE_WINDOW $cmd

	# Send has command defined by app-defaults, but we
	# need to fix it up with an eval here
	Widget_AddButDef $b send 
	pack [frame $b.sendpad -width 6 -height 1] -side right -fill y
	Widget_ReEvalCmd $b.send	;# expand variables now

	if [catch {glob ~/.signature*} sigFiles1] {
	    set sigFiles1 [glob ~]/.signature
	}
	set sigFiles {}
	foreach sig $sigFiles1 {
	    if {! [string match *~ $sig]} {
		lappend sigFiles $sig
	    }
	}
	set sedit($t,sigfile) [SeditSigfileDefault]
	set sigFiles [lsort $sigFiles]
	if {([llength $sigFiles] <= 1) && !$sedit(autoSign)} {
	    Widget_AddButDef $b sign
	    Widget_ReEvalCmd $b.sign
	    # Fix up third argument to SeditSign
	    if {[string length $sigFiles] != 0} {
		set cmd [lindex [$b.sign config -command] 4]
		lappend cmd $sigFiles
		$b.sign config -command $cmd
	    }
	} else {
	    set menu [Widget_AddMenuBDef $b sign {right padx 1}]
	    set cmd [option get $b.sign command {}]
	    set txt [option get $b.sign text {}]
	    if ![string match *... $txt] {
		$b.sign config -text $txt...
	    }
	    if {$sedit(autoSign)} {
		Widget_RadioMenuItem $menu "(none)" { } sedit($t,sigfile) {}
		Widget_RadioMenuItem $menu "(intelligent)" { } sedit($t,sigfile) {///auto///}
		$menu add separator
		set i 1
	    } else {
		set i -1
	    }
	    foreach file $sigFiles {
		if {$sedit(autoSign)} {
		    incr i
		    Widget_RadioMenuItem $menu [file tail $file] { } sedit($t,sigfile) $file
#		    if {[string compare [file tail $file] [file tail $sedit(sigfileDefault)]] == 0} {
#			$menu invoke $i
#		    }
		} else {
		    # The eval-hairyness causes the variable references
		    # in $cmd to be expanded at this point.
			Widget_AddMenuItem $menu [file tail $file] \
			[eval list $cmd $file]
		}
	    }
	}
	foreach but [Widget_GetButDef $b] {
	    if {[regexp (abort|save) $but]} {
		Widget_AddButDef $b $but {left padx 5}
	    } else {
		Widget_AddButDef $b $but {right padx 1}
	    }
	    Widget_ReEvalCmd $b.$but	;# expand variables now
	}

	foreach M [Widget_GetMenuBDef .sedit$id.but] {
	    global pgp
	    if {$pgp(enabled) || ($M != "pgp")} {
		set menu [Widget_AddMenuBDef .sedit$id.but $M {right padx 1}]
		#
		# Here is another way to set context for the menu commands.
		# Jam the draft and text widget name into a global that
		# can be accessed by the menu-invoked commands.
		#
		$menu config -postcommand [list SeditSetContext $draft $t]
		ButtonMenuInner $menu
	    }
	}
	SeditMsg $t $draft

	# Define a bunch of maps among things
	set sedit($t,toplevel) .sedit$id
	set sedit($id,text) $t
	set sedit($t,id) $id
	lappend sedit(allids) .sedit$id
	set sedit(.sedit$id,draft) $draft
	set sedit(.sedit$id,id) $id
    }
    Exwin_ToplevelFocus .sedit$id $t

    SeditTextBindings $draft $t		;# set up sendMsg binding
    if [file readable $quote(filename)] {
		$b.repl configure -state normal
		$b.repl.m entryconfigure 1 -command \
		 [list SeditInsertFile $draft $t $quote(filename)]
		$b.repl.m entryconfigure 2 -command \
		 [list SeditAttachQuotedMessage $draft $t $msg(path)]
    } else {
	$b.repl configure -state disabled
    }
    set sedit($t,keep) $sedit(keepDefault)
    set sedit($t,mhn) $sedit(mhnDefault)
    set sedit($t,format) $sedit(formatChoice)
    switch $sedit($t,format) {
	OnType	{$t config -wrap char}
	OnSend	{$t config -wrap word}
	Never	{$t config -wrap none}
    }
    switch -- $sedit(quoteDefault) {
	always	{ set sedit($t,quote) 1 }
	never	{ set sedit($t,quote) 0 }
	default { set sedit($t,quote) -1 }
    }
    set sedit($t,8bit) 0
    set sedit($t,sent) 0
    set sedit($t,dirty) 0
    set sedit($t,encoding) {}
    set sedit($t,Acharset) {}	;# for iso-2022-jp - see SeditKinput_start
    set sedit(t) $t	;# ugly state hack
    global exmh
    if {! [info exists exmh($id,action)]} {
	# If someone cares to figure out how this happens, that would be nice.
	# It might happen after a send error.
	Exmh_Debug "Set action for $id"
	set exmh($id,action) {}
    }
    SeditMimeReset $t
    if [catch {open $draft r} in] {
	$t insert 1.0 "Cannot open $draft"
    } else {
	$t insert 1.0 [read $in]
	close $in
	SeditPositionCursor $t
    }
    SeditSetIsigHeaders $t
    SeditMimeParse $t
    if {$sedit(iso)} {
	SeditInitMimeType $draft $t
    }
    foreach cmd [info commands Hook_SeditInit*] {
	if [catch {$cmd $draft $t} err] {
	    SeditMsg $t "$cmd $err"
	}
    }
}
proc SeditSetContext { draft t } {
    # Called when menus are posted to set the context for some commands
    global sedit
    set sedit(draft) $draft
    set sedit(t) $t
    Exmh_Status "Sedit $t [file tail $draft]"
}
proc SeditPositionCursor { t } {
    global sedit tk_version
    # Position cursor when the draft is first open.
    # Either on the first blank header line, or the first line of the message.
    # Body tag is assigned to the body and is used later when/if
    # composing MIME multipart messages.
    set l 1
    set insert 0	;# insert mark set
    set header 0	;# header insert mark set (new headers go here)
    set hlimit 0	;# header limit mark set (cannto do richtext here)
    set sedit($t,dash) 0
    for {set l 1} {1} {incr l} {
	if {[$t compare $l.0 > end]} {
	    if {! $insert} {
		$t mark set insert end
	    }
	    if {! $header} {
		$t mark set hlimit $l.end
		if {$tk_version >= 4.0} {
		    $t mark gravity hlimit left
		}
		if {$l > 1} {incr l -1}
		$t mark set header $l.end
	    }
	    $t tag add Body "header +1c" end
	    return
	}
	set line [$t get $l.0 $l.end]
	if [regexp {^[^ X].*: *$} $line] {
	    if {! $insert} {
		$t mark set insert $l.end
		set insert 1
	    }
	}
	if {[regexp {^--} $line]} {
	    set sedit($t,dash) 1
	    set line {}
	}
	if {[string length $line] == 0} {
	    # hlimit is used for <Tab> control
	    # header is used to insert new header information
	    $t mark set hlimit $l.end
	    if {$tk_version >= 4.0} {
		$t mark gravity hlimit left
	    }
	    if {$l > 1} {incr l -1}
	    $t mark set header $l.end
	    if {! $insert} {
		incr l 2
		$t mark set insert $l.0
	    }
	    $t tag add Body "header +1c" end
	    return
	}
    }
}

proc SeditQuit { draft t } {
    global sedit
    if [SeditIsDirty $t] {
	catch {destroy $t.seditDirty}
	set f [frame $t.seditDirty -class Dialog -bd 4 -relief raised]
	Widget_Message $f msg  -aspect 1000 -text "
$draft
has not been saved or sent.
Do you want to abort (destroy) it,
send it now,
save it for later editting,
or do nothing?"
	Widget_Frame $f f Dialog
	$f.f configure -bd 10
	Widget_AddBut $f.f ok "Abort" [list SeditAbortDirect $draft $t]
	Widget_AddBut $f.f send "Send\n(Ctrl-c)" [list SeditSend $draft $t]
	Widget_AddBut $f.f save "Save\n(Ctrl-s)" \
		[list SeditSave $draft $t SeditNuke]
	Widget_AddBut $f.f no "Do nothing\n(Return)" [list destroy $f]
	bind $f.f <Return>    "$f.f.no   flash ; $f.f.no   invoke"
	bind $f.f <Control-c> "$f.f.send  flash ; $f.f.send  invoke"
	bind $f.f <Control-s> "$f.f.save flash ; $f.f.save invoke"
	Widget_PlaceDialog $t $f
	focus $f.f
    } else {
	SeditNuke $draft $t
    }
}
proc SeditAbortDirect { draft t } {
    global mhProfile
    set id [SeditId $draft]
    if [regexp -- $mhProfile(draft-folder)/\[0-9\]+$ $draft] {
	Edit_Done abort $id	;# Nuke (rm) draft message
    }
    SeditNuke $draft $t
}
proc SeditAbort { draft t } {
    global sedit
    if [catch {frame $t.abort -bd 4 -relief ridge -class Dialog} f] {
	# dialog already up
	SeditAbortConfirm $t.abort $t abort
	return
    }
    Widget_Message $f msg -aspect 1000 -text "
Really ABORT?
Draft will be destroyed.
You might prefer Save&Quit."
    pack $f.msg -padx 10 -pady 10
    frame $f.but -bd 10 -relief flat
    pack $f.but -expand true -fill both
    set sedit($t,abort) nop
    Widget_AddBut $f.but ok "Abort\n(Return)" [list SeditAbortConfirm $f $t abort] left
    Widget_AddBut $f.but save "Save&Quit\n(Ctrl-s)" [list SeditAbortConfirm $f $t save] left
    Widget_AddBut $f.but nop "Do Nothing\n(Ctrl-c)" [list SeditAbortConfirm $f $t nop] right
    bind $f.but <Return>    "$f.but.ok   flash ; $f.but.ok   invoke"
    bind $f.but <Control-c> "$f.but.nop  flash ; $f.but.nop  invoke"
    bind $f.but <Control-s> "$f.but.save flash ; $f.but.save invoke"
    Widget_PlaceDialog $t $f
    focus $f.but
    tkwait window $f
    switch $sedit($t,abort) {
	abort {SeditAbortDirect $draft $t}
	save  {SeditSave $draft $t SeditNuke}
	default { focus $t }
    }
}
proc SeditAbortConfirm { f t yes } {
    global sedit
    set sedit($t,abort) $yes
    destroy $f
}
proc SeditNuke { draft t } {
    global sedit
    SeditMarkClean $t
    catch {destroy .seditUnsent}
    catch {destroy $t.seditDirty}
    catch {destroy $sedit($t,toplevel).whom}
    catch {destroy $sedit($t,toplevel).spell}
    update idletasks
    Exwin_Dismiss $sedit($t,toplevel)
}
proc SeditMsg { t text } {
    # Status line message output
    global sedit
    $sedit($t,status) configure -state normal
    $sedit($t,status) delete 0 end
    $sedit($t,status) insert 0 $text
    $sedit($t,status) configure -state disabled
    update idletasks
}

proc SeditSend { draft t } {
    global sedit exmh intelligentSign editor
    set id [SeditId $draft]
    SeditCheckForIsigHeaders $t
    Exmh_Debug SeditSend id=$id action=$exmh($id,action)
    if {$sedit(autoSign) && ($sedit($t,sigfile) != "") &&
	([string compare $exmh($id,action) "dist"] != 0)} {
	set b .sedit${id}.but
	set cmd [option get $b.sign command {}]
	if {[string length $cmd] == 0} {
	    Exmh_Debug SeditSend null cmd for $b.sign
	    set cmd {SeditSign $draft $t}
	}
	if {[string compare $sedit($t,sigfile) {///auto///}] == 0} {
	    SeditSignIntelligent $draft $t [SeditProperSigfileDefault]
	} else {
	    eval $cmd $sedit($t,sigfile)
	}
    }
    foreach cmd [info commands Hook_SeditSave*] {
	if [catch {$cmd $draft $t} err] {
	    SeditMsg $t "$cmd $err"
	}
    }
    if {$sedit($t,mhn)} {
	SeditFixupMhn $draft $t
    }
    if {$sedit(iso)} {
	SeditFixupCharset $draft $t
    }
    if [SeditSave $draft $t {} 0] {
	global env sedit
	$sedit($t,toplevel).but.send config -state disabled
	# Decide if this file needs to go through mhn
	if {$sedit($t,mhn) && ![catch {exec grep -l ^# $draft}]} {
	    set env(mhdraft) $draft
	    SeditMsg $t "Running mhn..."
	    if [catch {exec $editor(mhn) $draft} err] {
		SeditMsg $t $err
		$sedit($t,toplevel).but.send config -state normal
		return
	    }
	}
	if {$sedit($t,8bit)} {
	    # Turn on automatic quoting if we've entered 8-bit characters.
	    if {$sedit($t,quote) < 0} {
		set sedit($t,quote) 1
	    }
	}
	if {$sedit($t,8bit) || ($sedit($t,quote) > 0)} {
	    # Insert content-transfer-encoding headers
	    SeditFixupEncoding $draft $t [expr ($sedit($t,quote) > 0)]
	}
	foreach cmd [info commands Hook_SeditSend*] {
	    if [catch {$cmd $draft $t} err] {
		SeditMsg $t "$cmd $err"
		$sedit($t,toplevel).but.send config -state normal
		return
	    }
	}
	# Keep on send hack
	global mhProfile
	set async $mhProfile(sendType)
	if {$sedit($t,keep)} {
	    if {$async == "async"} {
		set mhProfile(sendType) "wait"
	    }
	}
	SeditMsg $t "Sending message..."
	SeditMarkSent $t
	set time [time [list Edit_Done send $id]]
	Exmh_Debug Message sent $time
	SeditMsg $t "Message sent $time"
	global sedit
	if {! $sedit($t,keep)} {
	    SeditNuke $draft $t
	} else {
	    SeditSave $draft $t		;# Restore draft deleted by MH
	    set mhProfile(sendasync) $async
	    $sedit($t,toplevel).but.send config -state normal
	    if {[string compare $exmh(folder) $mhProfile(draft-folder)] == 0} {
		Scan_Folder $exmh(folder)
	    }
	    SeditMsg $t "Message saved and sent $time"
	}
    }
}

proc SeditSave { draft t {hook {}} {isigw 1} } {
    global sedit mhProfile exmh
    if [catch {
	SeditMsg $t "Saving message..."
	set out [open $draft w]
	if {([string compare $sedit($t,format) "Never"] != 0)} {
	    SeditFormatMail $t $out $isigw
	} else {
	    # Prevent duplicate X-Mailer or X-Exmh-Isig-* headers
	    set id $sedit($t,id)
	    SeditCheckForIsigHeaders $t
	    if {[catch {set end [$t index hlimit]}] &&
		[catch {set end [$t index header]}]} {
		    set end end
	    }
	    set X1 [$t get 1.0 $end]
	    set X2 [$t get $end end]
	    regsub -all -nocase "(^|\n)(x-mailer:\[^\n\]*\n)+" $X1 {\1} X1
	    regsub -all -nocase "(^|\n)(x-exmh-isig-(comptype|folder):\[^\n\]*\n)+" $X1 {\1} X1
	    # No X-Mailer on redistributed messages
	    if {[string compare $exmh($id,action) dist] != 0} {
		puts $out "X-Mailer: exmh $exmh(version)"
	    }
	    # Replace X-Exmh-Isig-* headers if necessary
	    if {$isigw} {
		puts $out "X-Exmh-Isig-CompType: $sedit($t,isigc)"
		puts $out "X-Exmh-Isig-Folder: $sedit($t,isigf)"
	    }
	    puts -nonewline $out "$X1$X2"
	}
	close $out
	SeditMsg $t "Message saved"
	if ![regexp -- $mhProfile(draft-folder)/\[0-9\]+$ $draft] {
	    # Not from the drafts folder - see if we need to update
	    # the main display.
	    Msg_Redisplay $draft
	}
	if {$hook != {}} {
	    after 1 [list $hook $draft $t]
	}
    } err] {
	global errorInfo
	error "SeditSave $draft: $err" $errorInfo
	return 0
    }
    SeditMarkClean $t
    return 1
}
proc SeditAlternate { draft t } {
    SeditSave $draft $t SeditNuke
    Edit_Done alternate [SeditId $draft]
}
proc SeditSaveBody { t outfile } {
    set out [open $outfile w 0600]
    puts -nonewline $out [$t get [$t index "header + 1 line"] end]
    close $out
}

proc SeditReplaceBody { t infile } {
    set in [open $infile]
    set tags [$t tag names "header + 1 line"]
    $t delete "header + 1 line" end
    $t insert end [read $in] $tags
    close $in
    SeditMimeParse $t	;# Reconstruct formatting state
}

proc SeditMarkSent { t } {
    global sedit
    set sedit($t,sent) 1
}
proc SeditNotSent { t } {
    global sedit
    return [expr {! $sedit($t,sent)}]
}

proc Sedit_CheckPoint {} {
    global sedit
    foreach top $sedit(allids) {
	if [info exists sedit($top,id)] {
	    set draft $sedit($top,draft)
	    set id $sedit($top,id)
	    set t $sedit($id,text)
	    if [SeditIsDirty $t] {
		Exmh_Status "Saving draft $id"
		SeditSave $draft $t
	    }
	}
    }
}
proc SeditPeriodicSave {} {
    global sedit
    Sedit_CheckPoint
    set sedit(checkpoint) [after [expr 1000 * 60] SeditPeriodicSave]
}

proc SeditFixupMhn { draft t } {
    global sedit
    set state header
    set mhn 0
    set lines {}
    Exmh_Debug SeditFixupMhn
    for {set i 1} {[$t compare $i.0 < end]} {incr i} {
	set line [$t get $i.0 $i.end]
	set len [string length $line]
	if {$state == "header"} {
	    if [regexp -nocase {^(content-type|mime-version|content-transfer-encoding):} $line match type] {
		lappend lines $i
	    }
	    if [regexp {^(--+.*--+)?$} $line] {
		set state body
	    }
	} else {
	    if [regexp ^# $line] {
		set mhn 1
	    }
	}
    }
    if {$mhn} {
	if [llength $lines] {
	    SeditMsg $t "Cleaning up for MHN"
	}
	foreach i [lsort -integer -decreasing $lines] {
	    $t delete $i.0 "$i.end +1 char"
	}
	set sedit($t,8bit) 0	;# Let MHN do quote-printable
	set sedit($t,quote) 0
    }
}

proc SeditDragDrop { w args } {
    set t [winfo toplevel $w].f.t

    global dragging
    if [info exists dragging(data,folder)] {
        set folder $dragging(data,folder)
	SeditSetHeader $t fcc $folder
    } elseif [info exists dragging(text)] {
	$t insert insert $dragging(text)
    }
}

proc SeditSetHeader { t key value } {
    set hit 0
    for {set L 1} {[$t compare $L.0 < hlimit]} {incr L} {
	set line [$t get $L.0 $L.end]
	if [regexp -nocase ^[string tolower $key]: $line] {
	    set hit 1
	    set line " dummy"
	    while {[regexp {^[ 	]} $line]} {
		$t delete $L.0 "$L.0 + 1 line"
		set line [$t get $L.0 $L.end]
	    } 
	    $t insert $L.0 "[string toupper [string index $key 0]][string tolower [string range $key 1 end]]: $value\n"
	    $t tag remove Charset $L.0 $L.end
	    return
	} 
    }
    if {! $hit} {
	incr L -1
	$t insert $L.0 "[string toupper [string index $key 0]][string tolower [string range $key 1 end]]: $value\n"
	$t tag remove Charset $L.0 $L.end
    }
}

# Set/Replace/Append a message header
# (does not handle duplicate headers)
proc SeditSetHeader { t key value {append NO}} {
    if [string match NO $append] {
	unset append
    }

    # let the text widget search for the header
    set start [$t search -nocase -regexp ^${key}: 1.0 header]

    if {[string compare "" $start]} {
	# find the end of the header, looking past any continuation lines
	set end [$t search -regexp {^[^	 ]} "$start + 1 line" header]

	# in case user mangled the header.
        if {[string match "" $end]} {
            set end "$start +1 line"
        }

	# if we are appending, do it now.
	if [info exists append] {
	    $t insert "$end -1c" "$append$value"
	    return
	}

	# otherwise, delete the whole header to set up for insertion.
	$t delete $start $end
    } else {
	# insert a new header near the end of the headers
	set start "header linestart"
    }

    # insert the new/replaced header
    $t insert $start "[string toupper [string index $key 0]][string tolower [string range $key 1 end]]: $value\n"
    $t tag remove Charset $start "$start lineend"
}



