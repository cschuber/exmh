# bindings.tcl
#
# Keystroke bindings
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Bindings_Main { w } {
    # Keystroke bindings for operations on messages and folders
    # Assert $w == $exwin(mtext)
    global bindings
    catch {unset bindings}
    set bindings(dotfile) ~/.exmhbindings
    BindingsReadPref
    BindingsReset $w
}
proc BindingsReset { w } {
    global bindings
    bindtags $w [list TSelect TScroll Command $w all]
    set w Command
    bind $w <Any-Key> {if {"%A" != "{}"} {Exmh_Status "bad key %A"} }
    Bind_Key $w <Control-Return> 	{Folder_Commit}
    Bind_Key $w <Key-A> {MimeSunAppSelection}
    Bind_Key $w <Key-i> {Inc}
    Bind_Key $w <Key-c> {Msg_Compose}
    Bind_Key $w <Key-C> {Msg_CompSel}
    Bind_Key $w <Key-d> {Msg_Remove}
    Bind_Key $w <Key-D> {Msg_RemoveNoshow}
    Bind_Key $w <Key-g> {URI_OpenSelection}
    Bind_Key $w <Key-z> {URI_ScanMsg {} $uri(scanLimit)}
    Bind_Key $w <Key-p> {Ftoc_Prev show}
    Bind_Key $w <Key-P> {Ftoc_Prev noshow}
    Bind_Key $w <minus> {Ftoc_PrevMarked}
    Bind_Key $w <Key-n> {Ftoc_Next show}
    Bind_Key $w <Key-N> {Ftoc_Next noshow}
    Bind_Key $w <Key-m> {Msg_Move}
    Bind_Key $w <Key-M> {Msg_MoveNoshow}
    Bind_Key $w <Key-r> {Msg_Reply -nocc to -nocc cc}
    Bind_Key $w <Key-R> {Msg_Reply -cc to -cc cc}
    Bind_Key $w <Key-f> {Msg_Forward}
    Bind_Key $w <Key-F> {Folder_Unseen}
    Bind_Key $w <Key-s> {Msg_ShowCurrent}
    Bind_Key $w <Key-u> {Ftoc_Unmark}
    Bind_Key $w <Key-U> {Msg_ShowUnseen}
    Bind_Key $w <asciicircum> {Msg_First}
    Bind_Key $w <dollar> {Msg_Last}
    Bind_Key $w <Control-s> {Find_It forw}
    Bind_Key $w <Control-r> {Find_It prev}
    Bind_Key $w <question> {Bind_Pref}
    Bind_Key $w <period> {Folder_AutoRefile}
    # Page message - the function keys are Sun4 keyboard specific
    Bind_Key $w <space>			{Msg_PageOrNext}
    Bind_Key $w {<BackSpace> <Prior> <F29>}	{Msg_PageUp}
    Bind_Key $w {<Up> <Key-k>}		{Msg_LineUp}
    Bind_Key $w {<Next> <F35>}		{Msg_PageDown}
    Bind_Key $w {<Down> <Key-j>}	{Msg_LineDown}
    Bind_Key $w {<Home> <Key-less>}	{Msg_Top}
    Bind_Key $w {<End> <Key-greater>}	{Msg_Bottom}
    # Page Ftoc
    Bind_Key $w {<Control-n> <Shift-Next>}  {Ftoc_PageDown}
    Bind_Key $w {<Control-p> <Shift-Prior>} {Ftoc_PageUp}
    #
    Bind_Key $w <Control-w>	{Msg_CopySelection}

    Select_Bindings $w	;# Keyboard selection of folders
    Addr_Bindings $w	;# Address book bindings.

    if {[info command User_Bindings] != ""} {
	User_Bindings $w
    }
    foreach item [array names bindings] {
	if [regexp ^key $item match] {
	    set cmd [lindex [split $item ,] 1]
	    # This will just install any extras from the users .exmhbindings
	    Bind_Key $w {} $cmd 
	}
    }
}

proc Bindings_Search { entry } {
    # Bindings for the search entry widget
    Widget_BindEntryCmd $entry <Return> { Find_It }
    Widget_BindEntryCmd $entry <Control-r> { Find_It prev }
    Widget_BindEntryCmd $entry <Control-s> { Find_It forw }
}

proc UserCommitAction { } {
    global bind
    if [info exists bind(commitAction)] {
	if [eval $bind(commitAction)] {
	    unset bind(commitAction)
	}
    }
}
proc BindOrderReset {} {
    global bindings
    set bindings(order) {}
}
proc Bind_Key { w defaultSeq cmd } {
    global bindings
    if [info exists bindings(key,$cmd)] {
	# Preserve existing key specifications (from ~/.exmhbindings)
	set seqs $bindings(key,$cmd)
    } else {
	set seqs $defaultSeq
    }
    foreach seq $seqs {
	if [catch {
	    if {$seq == {}} {
		continue
	    }
	    bind $w $seq $cmd
	    # Double-bind Meta-key and Escape-key
	    if [regexp {<Meta-(.*)>} $seq match letter] {
		bind $w <Escape><$letter> $cmd
	    }
	    # Make leading keystroke harmless
	    if [regexp {(<.+>)<.+>} $seq match prefix] {
		bind $w $prefix { }
	    }
	    bind $w $seq $cmd
	} err] {
	    Exmh_Status "$cmd: $err"
	}
    }
    set bindings(key,$cmd) $seqs
    if {[string length $defaultSeq] != 0} {
	set bindings(default,$cmd) $defaultSeq
    } elseif {! [info exists bindings(default,$cmd)]} {
	set bindings(default,$cmd) {}
    }
}

proc Bind_Pref {} {
    global bindings
    if [Exwin_Toplevel .bindpref "Key Commands Preferences" Pref] {
	Widget_Label .bindpref.but label {left fill} \
	    -text "Key command bindings"

	Widget_AddBut .bindpref.but save "Save" {BindingsPrefSave}
	Widget_AddBut .bindpref.but help "Help" {BindingsPrefHelp}
	set f2 [Widget_Frame .bindpref def Dialog {top fillx}]
	$f2 configure -bd 10

	Widget_Frame $f2 cmd Preference {top fillx}
	Widget_Label $f2.cmd label {left} -text Command -width 10 -anchor w
	Widget_Entry $f2.cmd entry {right expand fillx} -width 30

	Widget_Frame $f2 key Preference {top fillx}
	Widget_Label $f2.key label {left} -text Key -width 10 -anchor w
	Widget_Entry $f2.key entry {left expand fillx} -width 30
    
	set cmdEntry $f2.cmd.entry
	set keyEntry $f2.key.entry
	bind $cmdEntry <Tab> [list focus $keyEntry]
	bind $keyEntry <Return> [list BindingsDefine $cmdEntry $keyEntry]
	set doit [button $f2.key.doit -text Define \
	    -command [list BindingsDefine $cmdEntry $keyEntry]]
	pack $doit -side left

	set f [Widget_Frame .bindpref c ScrollCanvas]

	canvas $f.can -width 500 -height 300 \
	    -yscrollcommand [list $f.scroll set] \
	    -scrollregion "0 0 500 300"
	wm minsize .bindpref 300 200
	scrollbar $f.scroll -command [list $f.can yview] -orient vertical
	pack $f.scroll -side right -fill y
	pack $f.can -side left -fill both -expand true
	BindPrefDisplay .bindpref.c.can
    }
    Exwin_ToplevelFocus .bindpref .bindpref.def.cmd
}
proc BindingsPrefHelp {} {
    Help Bindings "Command Bindings Help"
}
proc BindPrefDisplay { canvas } {
    global bindings
    set width 0
    foreach item [array names bindings] {
	if [regexp ^key $item] {
	    set name [lindex [split $item ,] 1]
	    set w [string length $name]
	    if {$w > $width} { set width $w }
	    set map($name) $bindings($item)
	}
    }
    set size 0
    if {$width > 50} {
	set width 50
    }
    catch {destroy $canvas.f}
    frame $canvas.f
    $canvas create window 5 0 -anchor nw -window $canvas.f
    foreach name [lsort -command BindPrefSort [array names map]] {
	set keystroke $map($name)
	incr size
	BindingsPrefItem $canvas.f $width $name action$size $keystroke
	if {[string length $keystroke] == 0} {
	    pack forget $canvas.f.action$size
	}
    }
    set child [lindex [pack slaves $canvas.f] 0]
    Visibility_Wait $child
    $canvas config -scrollregion "0 0 [winfo width $canvas.f] [winfo height $canvas.f]"
}
proc BindPrefSort {s1 s2} {
    string compare [string tolower $s1] [string tolower $s2]
}
proc BindingsPrefItem { frame width cmd name keystroke } {
    global bindings
    Widget_Frame $frame $name Preference
    set label [string range $cmd 0 [expr $width-1]]
    Widget_Label $frame.$name label {left} -text $label -width $width -anchor w
    Widget_Entry $frame.$name entry {right expand fill} -width 30
    set bindings(entry,$cmd) $frame.$name.entry
    $frame.$name.entry insert 0 $keystroke
    Widget_BindEntryCmd $frame.$name.entry <Return> [list BindRebind $cmd]
}
proc BindingsPrefSave { } {
    global bindings
    # Save it
    set out [open $bindings(dotfile) w]
    foreach item [array names bindings] {
	if [regexp ^key $item match] {
	    set name [lindex [split $item ,] 1]
	    set entry $bindings(entry,$name)
	    set keystrokes [$entry get]
	    if {[catch {set bindings(default,$name)} default] == 0} {
		if {[string compare $default $keystrokes] == 0} {
		    # Don't save settings that are system defaults
		    # Because default for user-defined things is NULL, this
		    # also means you can delete user-defined bindings by
		    # clearing their binding string.
		    continue
		}
	    }
	    puts $out [list set bindings($match,$name) $keystrokes]
	}
    }
    close $out
    Exwin_Dismiss .bindpref
    # Apply it to current session
    global exwin
    BindingsReset $exwin(mtext)
}

proc BindingsReadPref {} {
    global bindings
    if [file exists $bindings(dotfile)] {
	if [catch {uplevel #0 source [glob $bindings(dotfile)]} msg] {
	    Exmh_Status "Error in $bindings(dotfile): $msg"
	    return
	} 
    }
}

proc BindingsDefine { cmdEntry keyEntry } {
    set cmd [$cmdEntry get]
    set key [$keyEntry get]
    Exmh_Status "Bind $key => $cmd"
    BindingsDefineInner $cmd $key
}
proc BindRebind { cmd } {
    global bindings
    set key [$bindings(entry,$cmd) get]
    Exmh_Status "Bind $key => $cmd"
    BindingsDefineInner $cmd $key
}
proc BindingsDefineInner { newcmd key } {
    global bindings exwin
    #
    # Make sure we get any unsaved changes to other entries
    #
    foreach item [array names bindings] {
	if {[string match entry,* $item]} {
	    set cmd [lindex [split $item ,] 1]
	    set seqs [$bindings(entry,$cmd) get]
	    set bindings(key,$cmd) $seqs
	}
    }
    # But override a change from the main entires
    set bindings(key,$newcmd) $key
    BindingsReset $exwin(mtext)	;# clear and reset everything
    BindPrefDisplay .bindpref.c.can
}
