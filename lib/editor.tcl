#
# editor.tcl --
#	Editor interactions
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

# Message composing and editor interaction

proc Edit_Init {} {
    global mhProfile editor
    case $mhProfile(editor) {
	{*mxedit* sedit} {set prog $mhProfile(editor)}
	default {set prog sedit}
    }
    Preferences_Add "Editor Support" \
"Exmh has a built-in editor for composing messages, named \"sedit\".
It can also interface to other editors.  For non-TK editors like vi
or emacs, preface the editor command with \"exmh-async\" so the editor
runs as a detached process.  For TK-aware applications, suffix the
command with an & so your editor detaches into the background.  In
this case the first argument to the editor is the name of the exmh
interpreter, and the second argument is the draft file name.
If your editor knows how to post a message directly, preface
the command with \"give-away\".  The emacsclient and gnuclient
cases listed in the examples below are special cases of this.
If you want to pass a -geo argument to your program, you need to
wrap it up to prevent exmh-async from grabbing it.  See the last
example below.
Example commands include:
sedit
mxedit
emacsclient &
give-away emacsclient
gnuclient &
give-away gnuclient
exmh-async emacs
exmh-async emacsclient
exmh-async xterm -e vi
exmh-async xterm {-geom 80x44+0+0} -e vi" \
    [list \
	[list editor(prog) editCmd $prog {Editor command} \
"The editor command used to compose mail messages.
The filename will be appended to the command."] \
	[list editor(alternate) edit2Cmd {exmh-async emacs} {2nd Editor command} \
"This is an alternate editor command.  For example, if your default
editor is sedit, you might want to drop into emacs for a particular
message.  The filename will be appended to the command."] \
	[list editor(autowhom) autoWhom ON {Auto Whom} \
"Enabling this causes whom to be invoked automatically whenever a
What Now? dialog is displayed."] \
	[list editor(sedit!) seditOverride OFF {Sedit override} \
"Use this to override the regular editor command and
use the built-in editor instead.  This parameter is set
initially by the command line -sedit switch."] \
	[list editor(async_sedit) seditAfterAsync OFF {Use Sedit after Async} \
"If enabled, after editing with external editor, exmh will bring the message
up in sedit.  This is so you can initially create the message with your
favorite editor, and then pop into to sedit for richtext or attachments."] \
    [list editor(spell) spellCmd "exmh-async xterm -e ispell" {Spell command} \
"The spell command specifies a program used to spell-check mail messages. 
The filename will be appended to the command."] \
        [list editor(mhn) mhnCmd "mhn" {MHN command} \
"The mhn command specifies a program used to reformat
a message with the MH mhn program.
The filename will be appended to the command."] \
    ]
    set editor(sedit) sedit
}

proc Edit_Draft {} {
    global mhProfile exmh
    # Run the editor on the current draft
    if {$exmh(folder) == $mhProfile(draft-folder)} {
	Msg_CheckPoint	;# Update cur message
    }
    set draftID [Mh_Cur $mhProfile(draft-folder)]
    if {$draftID == {}} {
	Exmh_Status "No current message in Draft-Folder $mhProfile(draft-folder)" error
	return
    }
    EditWhatNow $draftID prog
}
proc Edit_DraftID { id } {
    # No mucking with context
    EditWhatNow $id prog
}

proc EditDraftFolderHook { f what } {
    # Called when we change to the drafts folder
    Buttons_DraftMode 1
}
proc EditDraftFolderCleanup { f what } {
    Buttons_DraftMode 0
}

# Throw up a dialog asking whether user wants to
# send, re-edit, save as draft, abort.
# As with the command line whatnowproc, this also starts up the
# editor on the draft.

proc EditWhatNow {draftID {edittype prog}} {
    global mhProfile editor

    if {([string compare $edittype prog] == 0) && $editor(sedit!)} {
	set edittype sedit	;# sedit override
    }
    Exmh_Debug EditWhatNow $draftID $edittype
    if ![regexp {^[0-9]+$} $draftID] {
	# Must be a message in a non-drafts folder
	set path $mhProfile(path)/$draftID
    } else {
	# Delete ".orig" file if it exists, Mhn_* thanks to Colm Buckley
	Mhn_DeleteOrig $draftID
	set path [Mh_Path $mhProfile(draft-folder) $draftID]
    }
    if [EditStart $path $edittype] {
	# Editor has run synchronously, so we go right into the dialog
	Edit_Dialog $draftID
    }
    global exmh
    if {[string compare $exmh(folder) $mhProfile(draft-folder)] == 0} {
	# It isn't safe to leave a current message active in the drafts
	# folder because a second edit can loose changes in the first.
	# User saves a draft.
	# User changes to draft folder.
	# The "Send" button uses the saved draft, and they make edits.
	# Another "Send" button hit resets the draft to their last save,
	# but they probably expected to start a new draft.
	Msg_ClearCurrent
    }
}

# The following can be invoked by remote editor interpreters
proc Edit_Dialog {draftID} {
    global exmh mhProfile editor
    Exmh_Debug Edit_Dialog $draftID
    if {$editor(async_sedit)} {
	Sedit_Start $mhProfile(path)/$mhProfile(draft-folder)/$draftID
    } else {
	EditShowDialog $draftID "What should I do with draft $draftID?"
    }
}
# For compatibility with old versions of mxedit
proc EditDialog {draftID} {
    Edit_Dialog $draftID
}

# Turn passphrase pane ON/OFF/disabled depending on pgp(seditpgp) and
# pgp(keeppass)
proc EditMaybeAddPhrasePane {id w} {
    global pgp

    if {!$pgp(enabled)} {
	return
    }

    set dismsg "Disabled since passphrases are not being kept."
    if {$pgp(seditpgp)} {
	# Need to add pane
	if {[lsearch [pack slaves $w] $w.pgp] < 0} {
	    EditAddPassPhrasePane $id $w
	}
	# Just in case the user is playing with pgp(keeppass) value
	if {$pgp(echopass)} {
	    $w.pgp.e configure -show * -state normal
	} else {
	    $w.pgp.e configure -show {} -state normal
	}
	if {![string compare $pgp(cur,pass,$id) $dismsg]} {
	    set pgp(cur,pass,$id) {}
	}
    } else {
	# Need to take away the pane (if it is there)
	if {[lsearch [pack slaves $w] $w.pgp] >= 0} {
	    destroy $w.pgp
	}
    }

    if {!$pgp(keeppass) && [lsearch [pack slaves $w] $w.pgp] >= 0} {
	# Need to disable the pane (if it is there)
	set pgp(cur,pass,$id) $dismsg
	$w.pgp.e configure -show {} -state disabled
    }
}

proc EditAddPassPhrasePane {id w} {
    global pgp
    if {$pgp(enabled) && $pgp(seditpgp)} {

	# seditpgp main area
	Pgp_SetSeditPgpName $pgp($pgp(version,$id),myname,$id) $id
	set pgp(fullName,$id) $pgp($pgp(version,$id),fullName)

	if {![winfo exists $w.pgp]} {
	    pack [frame $w.pgp] -side bottom -fill x -ipady 2
	}
	if {![winfo exists $w.pgp.l1]} {
	    pack [label $w.pgp.l1 -text "Passphrase for "] \
		    -side left
	}
	if {![winfo exists $w.pgp.b]} {
	    pack [button $w.pgp.b -textvariable pgp(sedit_label,$id) \
		    -command "Pgp_SetMyName \$pgp(version,$id) $id"] \
		    -side left -ipady 2
	}
	if {![winfo exists $w.pgp.l2]} {
	    pack [label $w.pgp.l2 -text ": "] \
		    -side left
	}
	if {![winfo exists $w.pgp.e]} {
	    pack [entry $w.pgp.e -textvariable pgp(cur,pass,$id)] \
		    -side left -expand yes -fill x -ipady 2
	    if {$pgp(echopass)} {
		$w.pgp.e configure -show *
	    }
	}

	# Add extras if requested
	if {$pgp(seditpgpextras)} {
	    if {![winfo exists $w.pgp2]} {
		pack [frame $w.pgp2] -side bottom -fill x
	    }
	    if {![winfo exists $w.pgp2.l1]} {
		pack [label $w.pgp2.l1 -textvariable pgp(sedit_label2,$id)] -side left
	    }
	}
    }
}
proc EditShowDialog {id text} {
    global exwin editor pgp
    # Create the buttons and arrange them from left to right in the RH
    # frame. Embed the left button in an additional sunken frame to indicate
    # that it is the default button.

    if [Exwin_Toplevel .edit$id "What Now?" WhatNow nomenu] {
	set d .edit$id
	wm transient $d
	$d config -relief raised -borderwidth 2

	# PGP version-setting moved out from seditpgp code
	if {$pgp(enabled)} {
	    if {![info exists pgp($pgp(version,$id),myname,$id)]} {
		set pgp($pgp(version,$id),myname,$id) $pgp($pgp(version,$id),myname)
	    }
	    EditMaybeAddPhrasePane $id $d
	}

	foreach but [Widget_GetButDef $d] {
	    Widget_AddButDef $d $but {right}
	    Widget_ReEvalCmd $d.$but	;# expand $id variable now
	}
	catch {pack $d.abort -padx 15}
	catch {pack $d.send -ipady 5 -ipadx 5 -padx 5}

	foreach M [Widget_GetMenuBDef $d] {
	    set menu [Widget_AddMenuBDef $d $M {right padx 1}]
	    ButtonMenuInner $menu	;# This also expands variables
	}

	# Make sure only valid entries are enabled in version submenu
	# otherwise things may fail in post-processing.
	# We don't have to take care of the active entry since 
	# preferences only allows valid entries as initial version
	if {$pgp(enabled)} {
	    set submenu $d.more.m.encrypt.version
	    for {set sm 0} {$sm<=[$submenu index last]} {incr sm} {
		if [catch {$submenu entrycget $sm -value} v] {
		    continue
		}
		if {[info exists pgp($v,enabled)] && \
			!$pgp($v,enabled) } {
		    $submenu entryconfigure $sm -state disabled
		}
	    }
	}

	Widget_Message $d msg -text "$text\nReturn for Send\nControl-c for Kill" -aspect 400

	focus $d
	bind $d <Return> [list $d.send invoke]
	bind $d <Control-c> [list $d.abort invoke]

	Visibility_Wait .edit$id
	Exmh_Focus
    } else {
	set d .edit$id
        catch {destroy $d.f}	;# Whom results
	EditMaybeAddPhrasePane $id $d
    }
    if $editor(autowhom) {
	EditDialogDone whom $id nohide
    }
}
proc EditDialogMsg {id msg} {
    set d .edit$id
    catch {destroy $d.f}
    Widget_Frame $d f
    pack $d.f -before [lindex [pack slaves $d] 0] -side bottom
    set lines [llength [split $msg \n]]
    Widget_Text $d.f [expr {$lines > 8 ? 8 : $lines}]
    $d.f.t insert 1.0 $msg
    $d.f.t config -state disabled -width 40
}
proc EditDialogDone {act id {hide hide}} {
    if [string match hide $hide] {
	Exwin_Dismiss .edit$id nosize
    }
    Edit_Done $act $id
}

proc EditStart { draft {type prog} } {
    # Start the editor, reusing an existing session if possible
    global editor exmh mhProfile pgp

    Exmh_Debug EditStart $draft $type

    if $pgp(enabled) {
	# Copy the default PGP values into this window only if they
	# don't already exists. This way, we preserve values between
	# re-edit sessions. Edit_Done takes care of resetting to 
	# preference values when we send or abort (ie. get done draft).
	set id [SeditId $draft]
	foreach var {encrypt sign format version} {
	    if ![info exists pgp($var,$id)] {
		set pgp($var,$id) $pgp($var)
	    }
	}
    }
    
    switch -glob -- $editor($type) {
	*mxedit* {
	    if ![info exists exmh(editInterp)] {
		set exmh(editInterp) "mxedit"
	    }
	    if ![info exists exmh(mxeditVersion)] {
		if ![catch {send $exmh(editInterp) {set mxVersion}} vers] {
		    set exmh(mxeditVersion) $vers
		}
	    }
	    set id "$exmh(editInterp) $draft"
	    if [info exists exmh(mxeditVersion)] {
		if {$exmh(mxeditVersion) >= 2.4} {
		    global env
		    if [regsub $env(HOME) $draft ~ newpath] {
			set id "$exmh(editInterp) $newpath"
		    }
		}
	    }
	    Exmh_Debug $id mxReset
	    if [catch {send $id mxReset}] {
		if [catch {send $exmh(editInterp) {set mxVersion}}] {
		    Exmh_Status "Starting mxedit..." warn
		    # Start the editor and tell it to make a callback
		    # that identifies the TCL interpreter in the editor
		    eval exec $editor($type) {-globalCmd [list mxSendInterpName [winfo name .] Edit_Ident] $draft &}
		} else {
		    Exmh_Status "Opening mxedit..." warn
		    catch {send $exmh(editInterp) [list mxOpen $draft]}
		}
	    } else {
		Exmh_Status "Reopening mxedit..." warn
		catch {send $id {wm deiconify .}}
	    }
	    return 0		;# Asynchronous edit
	}
	sedit {
	    Sedit_Start $draft
	    return 0		;# Asynchronous edit
	}
	exmh-async* {
	    global wish argv0
	    Exmh_Status "Starting ASYNC $editor($type) ..." warn
	    eval exec $wish -f ${argv0}-async \"[winfo name .]\" \
		[lrange $editor($type) 1 end] $draft &
	    return 0		;# Asynchronous edit
	}
	give-away* -
	gnuclient*& -
	emacsclient*& {
	    set cmd $editor($type)	;# Tcl 7.0 bug in regsub
	    regsub ^give-away $cmd {} cmd
            set cmd [string trimright $cmd "& \t"]
	    Exmh_Status "Starting $cmd ..." warn
            if [catch {eval exec $cmd $draft &} err] {
                Exmh_Status $err error
            }
	    return 0		;# Asynchronous edit

	}
	*& {
	    Exmh_Status "Starting TK $editor($type) ..." warn
            set cmd [string trimright $editor($type) "& \t"]
            if [catch {eval exec $cmd \"[winfo name .]\" $draft &} err] {
                Exmh_Status $err error
            }
	    return 0		;# Asynchronous edit

	}
	default {
	    Exmh_Status "Starting $editor($type) ..." warn
	    if [catch {eval exec $editor($type) $draft} err] {
		Exmh_Status $err error
	    }
	    return 1		;# Synchronous edit
	}
    }
}

# The following is invoked via "send" by mxedit when it
# starts up the first time in order to identify itself to us.

proc Edit_Ident { interpName } {
    global exmh
    set exmh(editInterp) $interpName
}

# The following is invoked by remote editor interpreters
proc EditDone {act msg} {
    Edit_Done $act $msg
}
proc Edit_Done {act {msg cur}} {
    # Commit or abort an edit session
    global mhProfile exmh env editor pgp
    if {$msg == "cur"} {
	set msg [Mh_Cur $mhProfile(draft-folder)]
	if {$msg == {}} {
	    Exmh_Status "No current draft"
	    return
	}
    }
    Exmh_Debug action = $act msg = $msg
    if ![regexp {^[0-9]+$} $msg] {
	# Message not in the drafts folder
	set path $mhProfile(path)/$msg
    }
    case $act in {
	send	{
	    Aliases_CheckPoint
	    if [info exists path] {
		# Copy message to drafts folder
		set id [file tail [Mh_Path $mhProfile(draft-folder) new]]
		Exmh_Status "Copying $msg to draft $id"
		MhExec comp +[file dirname $msg] [file tail $msg] -nowhatnowproc
		set msg $id
	    }
	    set anno [Mh_AnnoEnviron $msg]
	    Exmh_Debug Edit_Done send: anno=$anno
	    Exmh_Debug "Mh_Send [time {set code [catch {Mh_Send $msg} err2]}]"
	    if $code {
		# move the orig message back to the draft if it exists
		Mhn_RenameOrig $msg
		Exmh_Status $err2 error
		Send_Error $err2 $msg
		return
	    }
	    if {$exmh(folder) == $mhProfile(draft-folder)} {
		# Clean up scan listing
		if [catch {Msg_RemoveById $msg} err] {
		    Exmh_Debug Msg_RemoveById $msg $err
		}
	    }
	    Exmh_Status "Draft $msg sent" normal
	    # Delete "orig" message if it exists
	    Mhn_DeleteOrig $msg
	    Quote_Cleanup
	    if {$anno} {
		if {[string compare $exmh($msg,folder) $exmh(folder)] == 0} {
		    set ix [Ftoc_FindMsg $exmh($msg,mhmessages)]
		    Exmh_Debug Edit_Done ix=$ix
		    if {$ix != {}} {
			Ftoc_RescanLine $ix dash
		    }
		}
	    }
	    Mh_AnnoCleanup $msg
	    if $pgp(enabled) {
		# Done with this draft, set PGP defaults for next call
		set id [SeditId $msg]
		foreach var {encrypt sign format version} {
		    set pgp($var,$id) $pgp($var)
		}
	    }
	}
	reedit	{
	    Exmh_Status " "
            # Rename the orig message back to the draft
	    Mhn_RenameOrig $msg
	    EditWhatNow $msg prog
	}
	sedit	{
	    Exmh_Status " "
	    EditWhatNow $msg sedit
	}
	alternate {
	    Exmh_Status " "
	    EditWhatNow $msg alternate
	}
        spell {
            Exmh_Status " "
            EditWhatNow $msg spell
        }
        mhn {
	    # If the orig file exists, move it back to the draft
	    Mhn_RenameOrig $msg
	    if [info exists path] {
		set env(mhdraft) $path
	    } else {
		set env(mhdraft) [Mh_Path $mhProfile(draft-folder) $msg]
	    }
	    if [catch {exec $editor(mhn) $env(mhdraft)} err] {
		EditDialogMsg $msg "MHN failed: $err"
	    } else {
		EditDialogMsg $msg "MHN returned a-o.k."
	    }
        }
	abort	{
	    if ![info exists path]  {
		catch {Mh_Rmm $mhProfile(draft-folder) $msg}
		Mhn_DeleteOrig $msg
		if {$exmh(folder) == $mhProfile(draft-folder)} {
		    # Clean up scan listing
		    if [catch {Msg_RemoveById $msg} err] {
			Exmh_Debug Msg_RemoveById $msg $err
		    }
		}
		Exmh_Status "Draft $msg aborted" error
		Quote_Cleanup
		Mh_AnnoCleanup $msg
		if $pgp(enabled) {
		    # Done with this draft, set PGP defaults for next call
		    set id [SeditId $msg]
		    foreach var {encrypt sign format version} {
			set pgp($var,$id) $pgp($var)
		    }
		}
	    }
	}
	dismiss	{
	    Exmh_Status "Draft $msg dismissed" normal
	    Quote_Cleanup
	    Mhn_RenameOrig $msg
	    Mh_AnnoCleanup $msg
	}
	whom	{
	    Mh_AnnoEnviron $msg
	    if [info exists path] {
		catch {Mh_Whom $path} result
	    } else {
		catch {Mh_Whom $msg} result
	    }
	    EditDialogMsg $msg $result
	}
	default	{
	    Exmh_Error "Unknown action in Edit_Done"
	}
    }
}

