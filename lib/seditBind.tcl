# seditBind.tcl
#
# Support routines to define a set of consistent editing bindings for
# Text and Entry widgets
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Sedit_BindInit {} {
    global sedit exmh

    foreach editproc [option get . sedit_editprocs {}] {
	set sedit(key,$editproc) [option get . sedit_key_$editproc {}]
    }
    Preferences_Resource sedit(pasteSetsInsert) sedit_pasteSetsInsert 1
    Preferences_Resource sedit(typeKillsSel) sedit_typeKillsSel 1
    Preferences_Resource sedit(scrollButton) sedit_scrollButton Middle

    # Don't really need sedit-bindings and local.sedit-bindings anymore
    # with the use of resources
    set sedit(defaultfile) $exmh(library)/sedit-bindings
    set sedit(localfile)   $exmh(library)/local.sedit-bindings
    set sedit(dotfile)     ~/.exmhsedit

    SeditReadPref
    Sedit_ClassBindings
    SeditComposedKeyBindings
}
proc SeditReadPref {} {
    global sedit

    foreach file {defaultfile localfile dotfile} {
	if [file exists $sedit($file)] {
	    if [catch {uplevel #0 source [glob $sedit($file)]} msg] {
		Exmh_Status "Error in $sedit($file): $msg"
	    }
	}
    }
}
proc SeditBind { class key body } {
    global sedit
    if [catch {
	foreach seq $sedit(key,$key) {
	    if {$seq == {}} {
		continue
	    }
	    bind $class $seq $body
	    # Double-bind Meta-key and Escape-key
	    if [regexp {<Meta-(.*)>} $seq match letter] {
		bind $class <Escape><$letter> $body
	    }
	    # Make leading keystroke harmless
	    if [regexp {(<.+>)<.+>} $seq match prefix] {
		global tk_version
		if {$tk_version >= 4.0} {
		    bind $class $prefix break
		} else {
		    bind $class $prefix { }
		}
	    }
	}
    } err] {
	if ![info exists sedit(key,$key)] {
	    Exmh_Debug "Bind $class $key: $err"
	} else {
	    Exmh_Debug "Bind $class $key $sedit(key,$key): $err"
	}
    }
}
proc Sedit_TagBindings { w tag } {
    $w tag bind $tag <Button-1>		{WidgetTextSelBegin %W %x %y char}
    $w tag bind $tag <Double-Button-1>	{WidgetTextSelBegin %W %x %y word}
    $w tag bind $tag <Triple-Button-1>	{WidgetTextSelBegin %W %x %y line}
    $w tag bind $tag <Any-B1-Motion>	{WidgetTextSelMotion %W %x %y}
    $w tag bind $tag <Any-ButtonRelease-1>	{WidgetTextSelDone %W}
}
proc SeditTextBindings { draft t } {
    global sedit tk_version quote
    # Define binding tags:
    # SeditText - simple editor commands and data entry
    # TScroll - drag scrolling
    # TSelect - text selection
    # $t - send message binding
    # toplevel - not used
    # all - not used because it has focus-change bindings on <Tab>
    bindtags $t [list $t SeditText TSelect TScroll [winfo toplevel $t]]
    SeditBind $t sendMsg "SeditSend $draft $t ; break"
    SeditBind Entry sendMsg { }
    SeditBind $t abortMsg "SeditAbort $draft $t ; break"
    SeditBind Entry abortMsg { }
    SeditBind $t quoteMsg "SeditInsertFile $draft $t $quote(filename) ; break"
    SeditBind Entry quoteMsg { }

    # redisplay debug loggin
    if {[info commands log_dump] == "log_dump"} {
	bind $t <Key> {log "Key %A %K"}
	bind $t <Enter> {log "Enter %W"}
	bind $t <Leave> {log "Leave %W"}
	bind $t <ButtonPress> {log "ButtonPress %W"}
	bind $t <ButtonRelease> {log "ButtonRelease %W"}
    }
}
proc Sedit_ClassBindings { } {
    global sedit tk_version

    foreach class {SeditText Entry} {
	foreach b [bind $class] {
	    bind $class $b ""
	}
    }
    # This is needed because there are no Text bindings at this
    # point - they have not been faulted in yet from the library -
    # So erasing them now doesn't help.  We use an alternate class.
    set tclass SeditText

    # Modification bindings

    bind $tclass <Return> {
	SeditKill?Sel %W
	Text_Insert %W insert \n; %W yview -pickplace insert
	SeditDirty %W
    }
    bind $tclass <Tab> {
	if [%W compare insert <= hlimit] {
	    Text_MoveInsert %W insert+1line
	    Text_MoveInsert %W "insert lineend"
	} else {
	    Text_Insert %W insert \t
	    %W yview -pickplace insert
	    SeditDirty %W
	}
    }
    bind $tclass <Double-Tab> {
	if [%W compare insert <= hlimit] {
	    Text_MoveInsert %W hlimit+1line
	} else {
	    Text_Insert %W insert %A; %W yview -pickplace insert
	    SeditDirty %W
	}
    }
    bind $tclass <Control-i> [bind $tclass <Tab>]

    # These bindings ensure that unbound control, meta, and escape
    # sequences don't do anything.
    foreach ignore {<Escape> <Control-Key> <Meta-Key>} {
	bind $tclass $ignore { } ;# no-op
	bind Entry $ignore { } ;# no-op
    }

    SeditBind $tclass selpaste {
	Text_Yank %W
	SeditDirty %W
    }
    SeditBind Entry selpaste {
	if [catch {%W insert insert [selection get]}] {
	    if [catch {%W insert insert [selection get -selection CLIPBOARD]}] {
		catch {%W insert insert [cutbuffer get]}
	    }
	}
    }


    # When <Dcircumflex_accent> is pressed, wait for one char and insert the
    # compose key ^ <letter>
    SeditBind $tclass <Dcircumflex_accent> {
	bind SeditText <Any-Key> {
	    if {"%%A" != "{}"} {
		SeditComposedKey %%W "^" "%%A"
	    }
	}
    }

    # When <Ddiaeresis> is pressed, wait for one char and insert the
    # compose key " <letter>
    SeditBind $tclass <Ddiaeresis> {
	bind SeditText <Any-Key> {
	    if {"%%A" != "{}"} {
		SeditComposedKey %%W "\"" "%%A"
	    }
	}
    }

    # when the compose char is pressed, wait for 2 chars
    # (the first may be part of the composechar event)
    SeditBind $tclass composechar {
	bind SeditText <Any-Key> {
	    if {"%%A" != "{}"} {
		if {"%A" == "{}"} {
		    bind SeditText <Any-Key> {
			if {"%%%%A" != "{}"} {
			    SeditComposedKey %%%%W "%%A" "%%%%A"
			}
		    }
		} else {
		    SeditComposedKey %%W "%A" "%%A"
		}
	    }
	}
    }

    SeditBind $tclass seldelete {
	Text_KillSelection %W
	SeditDirty %W
    }
    SeditBind Entry seldelete {
	catch {%W delete sel.first sel.last}
    }

    SeditBind $tclass backspace {
	if ![SeditKill?Sel %W] {
	    Text_Delete %W insert-1c insert
	}
	%W yview -pickplace insert
	SeditDirty %W
    }
    SeditBind Entry backspace {
	tk_entryBackspace %W
    }

    SeditBind $tclass openline {
	Text_Insert %W insert \n
	Text_MoveInsert %W insert-1c
	SeditDirty %W
    }
    SeditBind Entry openline { info library }

    SeditBind $tclass deleol {
	if {! [SeditKill?Sel %W]} {
	    if {[%W index insert] == [%W index {insert lineend}]} {
		Text_Delete %W insert insert+1c 1
	    } else {
		Text_Delete %W insert "insert lineend" 1
	    }
	}
	%W yview -pickplace insert
	SeditDirty %W
    }
    SeditBind Entry deleol {
	%W delete insert end
    }

    SeditBind $tclass delbol {
	if {! [SeditKill?Sel %W]} {
	    if {[%W index insert] == [%W index {insert linestart}]} {
		Text_Delete %W insert-1c insert 1
	    } else {
		Text_Delete %W "insert linestart" insert 1
	    }
	}
	%W yview -pickplace insert
	SeditDirty %W
    }
    SeditBind Entry delbol {
	%W delete 0 insert
    }

    SeditBind $tclass delwordforw {
	if {! [SeditKill?Sel %W]} {
	    Text_Delete %W insert [Text_NextWord %W insert] 1
	}
	SeditDirty %W
    }
    SeditBind Entry delwordforw { }

    SeditBind $tclass delwordback {
	if {! [SeditKill?Sel %W]} {
	    Text_Delete %W [Text_PrevWord %W insert] insert 1
	}
	%W yview -pickplace insert
	SeditDirty %W
    }
    SeditBind Entry delwordback {
	tk_entryBackword %W; tk_entrySeeCaret %W
    }

    SeditBind $tclass delchar {
	if {! [SeditKill?Sel %W]} {
	    Text_Delete %W insert
	}
	%W yview -pickplace insert
	SeditDirty %W
    }
    SeditBind Entry delchar {
	%W delete insert
    }

    SeditBind $tclass transpose {
	Text_TransposeChars %W
	SeditDirty %W
    }
    SeditBind $tclass transemacs {
	Text_TransposeCharsEmacs %W
	SeditDirty %W
    }
    SeditBind Entry transpose {
	SeditEntryTranspose %W 
    }
    SeditBind Entry transemacs {
	SeditEntryTranspose %W emacs
    }

    SeditBind $tclass transword {
	Text_TransposeWords %W
	SeditDirty %W
    }
    SeditBind Entry transword {
    }

    # Motion bindings
    SeditBind $tclass bof {
	Text_MoveInsert %W 1.0
    }
    SeditBind Entry bof { }

    SeditBind $tclass eof {
	Text_MoveInsert %W end
    }
    SeditBind Entry eof { }

    SeditBind $tclass linestart {
	Text_MoveToBOL %W
    }
    SeditBind Entry linestart {
	%W icursor 0
	tk_entrySeeCaret %W
   }

    SeditBind $tclass lineend {
	Text_MoveInsert %W "insert lineend"
    }
    SeditBind Entry lineend {
	%W icursor end
	tk_entrySeeCaret %W
    }

    set sedit(lastpos,Text) {}
    SeditBind $tclass up1line {
	Text_MoveInsert %W insert-1line
    }
    SeditBind Entry up1line { }

    SeditBind $tclass down1line {
	Text_MoveInsert %W insert+1line
    }
    SeditBind Entry down1line { }

    SeditBind $tclass backword {
	Text_MoveInsert %W [Text_PrevWord %W insert]
    }
    SeditBind Entry backword {
	set string [%W get]
	set curs [expr [%W index insert]-1]
	if {$curs < 0} return
	for {set x $curs} {$x > 0} {incr x -1} {
	    if {([string first [string index $string $x] " \t"] < 0)
		    && ([string first [string index $string [expr $x-1]] " \t"]
		    >= 0)} {
		break
	    }
	}
	%W icursor $x
	tk_entrySeeCaret %W
    }

    SeditBind $tclass forwword {
	Text_MoveInsert %W [Text_NextWord %W insert]
    }
    SeditBind Entry forwword {
	set string [%W get]
	set curs [expr [%W index insert]+1]
	set len [string length $string]
	if {$curs < 0} return
	for {set x $curs} {$x < $len} {incr x} {
	    if {([string first [string index $string $x] " \t"] < 0)
		    && ([string first [string index $string [expr $x+1]] " \t"]
		    >= 0)} {
		break
	    }
	}
	%W icursor $x	
	tk_entrySeeCaret %W
    }

    SeditBind $tclass backchar {
	Text_MoveInsert %W insert-1c
    }
    SeditBind Entry backchar {
	set x [%W index insert]
	if {$x > 0} {
	    incr x -1
	    %W icursor $x
	    tk_entrySeeCaret %W
	}
    }

    SeditBind $tclass forwchar {
	Text_MoveInsert %W insert+1c
    }
    SeditBind Entry forwchar {
	set x [%W index insert]
	incr x
	%W icursor $x
	tk_entrySeeCaret %W
    }

    SeditBind $tclass up1page {
	Widget_TextPageUp %W
    }
    SeditBind Entry up1page { } ;# no-op

    SeditBind $tclass down1page {
	Widget_TextPageDown %W
    }
    SeditBind Entry down1page { } ;# no-op

    bind $tclass <Any-Key> { SeditInsert %W %A }
    bind $tclass <Mod2-Key> { SeditInsert %W %A }

    if {[info commands kinput_start] == "kinput_start"} {
	bind $tclass <Control-backslash> {SeditKinput_start %W}
	bind $tclass <Control-Kanji> {SeditKinput_start %W}
	bind $tclass <Control-Shift_R> {SeditKinput_start %W}
    }

    SeditBind SeditText addrexpand {Addr_KeyExpand %W}
    SeditBind SeditText format {Sedit_FormatParagraph %W}

    foreach cmd [info commands Hook_TextBind*] {
	$cmd $tclass
    }

    # Selection bindings
    set tclass TSelect
    SeditBind $tclass selcopy {
	catch {clipboard clear ; clipboard append [Text_Selection]}
	cutbuffer set [Text_Selection]
    }
    SeditBind Entry selcopy {
	catch {clipboard clear ; clipboard append [Text_Selection]}
	cutbuffer set [Text_Selection]
    }

    SeditBind $tclass selclear { Text_LoseSelection %W }
    SeditBind Entry selclear { %W select clear }

    SeditBind $tclass selstart {
	Text_LoseSelection %W; WidgetTextSelStart %W insert char
    }
    SeditBind Entry selstart {
	%W select clear ; %W select from insert
    }

    SeditBind $tclass selforw {
	Text_SelectTo %W insert
	Text_SelectionEnd %W 1
    }
    SeditBind Entry selforw {
	set x [%W index insert]
	incr x
	%W icursor $x
	%W select to insert
    }

    SeditBind $tclass selback {
	Text_SelectTo %W insert
	Text_SelectionEnd %W 1
    }
    SeditBind Entry selback {
	set x [%W index insert]
	incr x -1
	%W icursor $x
	%W select to insert
    }

    SeditBind $tclass selextend {
	Text_SelectTo %W insert
	Text_SelectionEnd %W 1
	Text_SelectionEnd %W 1
    }
    SeditBind Entry selextend {
	%W select to insert
    }

    bind $tclass <Button-1>		{WidgetTextSelBegin %W %x %y char}
    bind $tclass <Double-Button-1>	{WidgetTextSelBegin %W %x %y word}
    bind $tclass <Triple-Button-1>	{WidgetTextSelBegin %W %x %y line}
    bind $tclass <B1-Motion>		{WidgetTextSelMotion %W %x %y}
    bind $tclass <ButtonRelease-1>	{WidgetTextSelDone %W}
    bind $tclass <Shift-Button-1>	{WidgetTextSelAgain %W %x %y}
    bind $tclass <Shift-B1-Motion>	{WidgetTextSelMotion %W %x %y}
    bind $tclass <Shift-ButtonRelease-1>	{WidgetTextSelDone %W}
    bind $tclass <Control-Button-1>	{Text_MoveInsert %W @%x,%y noclear}

    bind Entry <Any-Key>	{SeditEntryInsert %W %A}
    bind Entry <Mod2-Key>	{SeditEntryInsert %W %A}

    bind Entry <Button-1> 	{SeditEntrySelect %W %x}
    bind Entry <Shift-Button-1> {SeditEntryShiftSelect %W %x}
    bind Entry <B1-Motion>	{SeditEntryDrag %W %x}
    bind Entry <Shift-B1-Motion> {SeditEntryDrag %W %x}
    bind Entry <Double-Button-1> {SeditEntryWordSelect %W %x}
    bind Entry <Triple-Button-1> {SeditEntryLineSelect %W %x}

    # Hack.  This has been here all the time as part of the default
    # entry class bindings.  Should be settable though.
    bind Entry <Control-u>	{%W delete 0 end}

    # Scroll bindings
    set tclass TScroll

    # Clear default scroll bindings
    foreach seq {<Button-2> <B2-Motion>} {
	bind $tclass $seq {}
	bind Entry $seq {}
    }

    global exwin
    switch -- $sedit(scrollButton) {
	Middle { set b 2 }
	Right { set b 3 }
	ShiftMiddle { set b shift2 }
	None { set b {} }
    }
    # focus debug hack
    if {([info command log_dump] == "log_dump")} {
	bind $tclass <Double-Escape> {
	    if [catch {
		if ![info exists logID] {set logID 0}
		while {[file exists /tmp/log$logID]} {
		    incr logID
		}
		log SEDIT "/tmp/log$logID"
		set out [open /tmp/log$logID w]
		puts $out [log_dump]
		close $out
		Exmh_Status "Debug log in /tmp/log$logID"
		incr logID
	    } err] {
		Exmh_Status $err
	    }
	}
    }
    if {$b == 2 || $b == 3} {
	bind $tclass <Button-$b> {
	    WidgetTextMark %W %y
	}
	bind $tclass <B$b-Motion> {
	    WidgetTextDragto %W %y $exwin(scrollSpeed)
	}
	bind $tclass <Shift-Button-$b> {
	    WidgetTextMark %W %y
	    set widgetText(%W,paste?) 0
	}
	bind $tclass <Shift-B$b-Motion> {
	    WidgetTextDragto %W %y [expr $exwin(scrollAccel)*$exwin(scrollSpeed)]
	}

	bind Entry <Button-$b>		{%W scan mark %x}
	bind Entry <B$b-Motion>		{%W scan dragto %x}
    } elseif {$b == "shift2"} {
	set b 2
	bind $tclass <Shift-Button-$b> 	{WidgetTextMark %W %y}
	bind $tclass <Shift-B$b-Motion> 	\
	    {WidgetTextDragto %W %y $exwin(scrollSpeed)}

	bind Entry <Shift-Button-$b>		{%W scan mark %x}
	bind Entry <Shift-B$b-Motion>		{%W scan dragto %x}
    }
    bind $tclass <Button-2> {+
	set widgetText(%W,time) %t
	set widgetText(%W,paste?) 1
	set widgetText(%W,x) %x
	set widgetText(%W,y) %y
    }
    bind $tclass <ButtonRelease-2> {
	if [info exists widgetText(%W,paste?)] {
	    if {$widgetText(%W,paste?) &&
		(%t - $widgetText(%W,time)) < 500 &&
		(abs(%x - $widgetText(%W,x)) < 3) &&
		(abs(%y - $widgetText(%W,y)) < 3)} {
		catch {
		    if $sedit(pasteSetsInsert) {
			Text_MoveInsert %W @%x,%y noclear
		    }
		    Text_Yank %W
		    SeditDirty %W
		}
	    }
	}
    }
    bind Entry <Button-2> {+
	set widgetText(%W,time) %t
	set widgetText(%W,paste?) 1
	set widgetText(%W,x) %x
	set widgetText(%W,y) %y
    }
    bind Entry <ButtonRelease-2> {
	if [info exists widgetText(%W,paste?)] {
	    if {$widgetText(%W,paste?) &&
		(%t - $widgetText(%W,time)) < 500 &&
		(abs(%x - $widgetText(%W,x)) < 3) &&
		(abs(%y - $widgetText(%W,y)) < 3)} {
		if [catch {
		    %W insert insert [selection get]
		}] {
		    if [catch {%W insert insert [cutbuffer get]}] {
    #		catch {%W insert insert $sedit(killbuf)}
		    }
		}
	    }
	}
    }
}
proc SeditEntryInsert { w a } {
    global sedit
    if {$a != ""} {
	if {$sedit(typeKillsSel)} {
	    catch {$w delete sel.first sel.last}
	}
	$w insert insert $a
	tk_entrySeeCaret $w
    }
}
proc SeditEntrySelect { w x } {
    global sedit
    set sedit(selectmode,$w) char
    $w icursor @$x
    $w select from @$x
    set sedit(anchor,$w) [$w index @$x]
    if {[lindex [$w config -state] 4] == "normal"} {focus $w}
}
proc SeditEntryShiftSelect { w x } {
    global sedit
    if ![info exists sedit(selectmode,$w)] {
	return
    }
    if {$sedit(selectmode,$w) == "word"} {
	set nx [$w index @$x]
	set ix [SeditEntryFindWord $w $x [expr {$nx >= $sedit(anchor,$w)}]]
    } else {
	set ix [$w index @$x]
    }
    $w select adjust $ix
}
proc SeditEntryDrag { w x } {
    global sedit
    if ![info exists sedit(selectmode,$w)] {
	return
    }
    if {$sedit(selectmode,$w) == "word"} {
	set nx [$w index @$x]
	set ix [SeditEntryFindWord $w $x [expr {$nx >= $sedit(anchor,$w)}]]
    } else {
	set ix [$w index @$x]
    }
    $w select to $ix
}
proc SeditEntryWordSelect { w x } {
    global sedit
    set sedit(selectmode,$w) word
    set ix [SeditEntryFindWord $w $x 0]
    $w select from $ix
    $w icursor $ix
    tk_entrySeeCaret $w
    $w select to [SeditEntryFindWord $w $x 1]
    set sedit(anchor,$w) $ix
}
proc SeditEntryFindWord { w x {forw 1} } {
    set string [$w get]
    set ix [$w index @$x]
    set start 1
    set char [string index $string $ix]
    if {$forw} {
	while {[string length $char] && ![regexp {[ 	]} $char]} {
	    incr ix
	    set char [string index $string $ix]
	    set start 0
	}
    } else {
	while {[string length $char] && ![regexp {[ 	]} $char]} {
	    incr ix -1
	    set char [string index $string $ix]
	    set start 0
	}
   }
   if {! $start} {
       if {$forw} {
	   incr ix -1
       } else {
	   incr ix 1
       }
   }
   return $ix
}
proc SeditEntryLineSelect { w x } {
    global sedit
    set sedit(selectmode,$w) char	;# yes, char
    $w select from 0
    $w select to end
    $w icursor 0
    tk_entrySeeCaret $w
}
proc SeditEntryTranspose { w {how ""} } {
    set _x [$w index insert]
    if {$how == "emacs"} {
	# Transpose two characters around insert and advance insert
	incr _x -1
	if {$_x < 0} {set _x 0}
	set _c [string index [$w get] $_x]
	$w delete $_x
	$w icursor [expr [$w index insert] +1]
	$w insert insert $_c
    } else {
	# Transpose two characters before insert
	incr _x -2
	if {$_x < 0} {set _x 0}
	set _c [string index [$w get] $_x]
	$w delete $_x
	incr _x
	$w insert $_x $_c
    }
    tk_entrySeeCaret $w
}

proc SeditKill?Sel { w } {
    global sedit
    if $sedit(typeKillsSel) {
	return [Text_KillSelection $w]
    } else {
	return 0
    }
}
proc SeditInsert { w a } {
    global sedit

    if {"X$a" != "X"} {
	if $sedit(typeKillsSel) {
	    Text_KillSelection $w
	}
	scan $a %c X
	if {$X > 127} {
	    set sedit($w,8bit) 1
	}
	if {[string compare $sedit($w,format) "OnType"] == 0} {
	    set i [SeditCount $w insert]
	    if {$i >= $sedit(lineLength)} {
		if [$w compare insert <= hlimit] {
		    set stuff "\n "
		} else {
		    set stuff \n
		}
		if [catch {$w insert wordbreak $stuff}] {
		    $w insert insert $stuff
		}
		$w mark unset wordbreak
	    }
	    $w insert insert $a
	    if [regexp $sedit(wordbreakpat) $a] {
		$w mark set wordbreak insert
		$w mark gravity wordbreak left
	    }
	} else {
	    $w insert insert $a
	}
	$w yview -pickplace insert
	set sedit($w,dirty) 1
    }
}
proc SeditCount {w mark} {
    set string [$w get "$mark linestart" $mark]
    set i 0
    foreach c [split $string {}] {
	if {"$c" == "\t"} {
	    set i [expr $i/8 + 8]
	} else {
	    incr i
	}
    }
    return $i
}
proc SeditMarkClean { t } {
    global sedit
    set sedit($t,dirty) 0
}
proc SeditDirty { t } {
    global sedit
    set sedit($t,dirty) 1
}
proc SeditIsDirty { t } {
    global sedit
    return $sedit($t,dirty)
}

proc Sedit_Pref {} {
    global sedit
    if [Exwin_Toplevel .seditpref "Simple Edit Preferences" Pref] {
	Widget_AddBut .seditpref.but save "Save" {SeditPrefSave}
	Widget_AddBut .seditpref.but help "Help" {SeditPrefHelp}
	Widget_AddBut .seditpref.but event "Events" {SeditEventHelp}
	Widget_Label .seditpref.but label {left fill} \
	    -text "Text and Entry class bindings"


	set f2 [Widget_Frame .seditpref tog]
	pack $f2 -padx 10 -pady 4 -fill none
	$f2 configure -bd 2
	Widget_Label $f2 label {left padx 10} -text "Options"
	Widget_CheckBut $f2 type "Type Kills SEL" sedit(typeKillsSel) {left padx 4}
	Widget_CheckBut $f2 paste "Paste Sets Insert" sedit(pasteSetsInsert) {left padx 4}
	set f2 [Widget_Frame .seditpref tog2 Frame {top expand fillx padx 10 pady 4}]
	$f2 configure -bd 2
	pack $f2 -padx 10 -pady 4 -fill none
	Widget_Label $f2 label {left padx 10} -text "Scroll Button"
	Widget_RadioBut $f2 but2 "Middle" sedit(scrollButton) {left padx 4}
	Widget_RadioBut $f2 but3 "Right" sedit(scrollButton) {left padx 4}
	Widget_RadioBut $f2 shift2 "Shift-Middle" sedit(scrollButton) {left padx 4}
	Widget_RadioBut $f2 none "None" sedit(scrollButton) {left padx 4}

	set f [Widget_Frame .seditpref p Dialog]
	$f configure -bd 10
	set lr [Widget_SplitFrame $f Left Right]
	set left [lindex $lr 0]
	set right [lindex $lr 1]
	set width 0
	foreach item [array names sedit] {
	    if [regexp ^key $item] {
		set name [lindex [split $item ,] 1]
		set w [string length $name]
		if {$w > $width} { set width $w }
	    }
	}
	set size 0
	if [info exists sedit(key,delword)] {
	    lappend sedit(key,delwordforw) $sedit(key,delword)
	    unset sedit(key,delword)
	}
	foreach item [lsort [array names sedit]] {
	    if [regexp ^key $item] {
		set name [lindex [split $item ,] 1]
		incr size
		set keystroke $sedit($item)
		set frame [lindex $lr [expr {$size % 2}]]
		SeditPrefItem $frame $width $name $keystroke
	    }
	}
    }
    Exwin_ToplevelFocus .seditpref none
}
proc SeditPrefItem { frame width name keystroke } {
    global sedit
    Widget_Frame $frame $name Preference
    Widget_Label $frame.$name label {left} -text $name -width $width
    Widget_Entry $frame.$name entry {right expand fill}
    set sedit(entry,$name) $frame.$name.entry
    $frame.$name.entry insert 0 $keystroke
}
proc SeditPrefHelp {} {
    Help Seditpref "Simple Edit Bindings Help"
}
proc SeditPrefSave { } {
    global sedit
    # Save it
    set out [open $sedit(dotfile) w]
    foreach item [array names sedit] {
	if [regexp ^key $item match] {
	    set name [lindex [split $item ,] 1]
	    set entry $sedit(entry,$name)
	    set keystrokes [$entry get]
	    puts $out [list set sedit($match,$name) $keystrokes]
	}
    }
    puts $out "set sedit(pasteSetsInsert) $sedit(pasteSetsInsert)"
    puts $out "set sedit(typeKillsSel) $sedit(typeKillsSel)"
    puts $out "set sedit(scrollButton) $sedit(scrollButton)"
    close $out
    Exwin_Dismiss .seditpref
    # Apply it to current session
    SeditReadPref
    Sedit_ClassBindings
}
proc SeditKinput_start { w } {
    global sedit

# modified by k.furukawa, jan.1995.  for automatic iso-2022-jp detection.
# sedit($window, Acharset) is initialized with {} in Sedit_Start.
# once kinput2 is used, the message header will have "charset=iso-2022-jp"
# if you set "on" for "specify charset ..." in sedit preference.

    if [catch {kinput_start $w over} msg] {
	Exmh_Status "kinput2 failed: $msg"
	return
    }
    set sedit($w,Acharset) iso-2022-jp
}

proc SeditEventHelp {} {
    global tk_version
    set t .seditevent.text
    if [Exwin_Toplevel .seditevent "Event Helper" Pref] {
	Widget_SimpleText .seditevent text {expand fill} -width 40 -height 10
	if {$tk_version >= 4.0} {
	    bind $t <Key> {SeditEventFeedback %W %K %A ; break}
	} else {
	    foreach seq [bind $t] {
		if [string match Key* $seq] {
		    bind $t $seq {}
		}
	    }
	    bind $t <Any-Key> {SeditEventFeedback %W %K %A}
	}
    }
    $t delete 1.0 end
    $t insert 1.0 "Type into this window to see what events\nare generated by your keyboard\n***\n"
}
proc SeditEventFeedback {t keysym char} {
    $t insert end "Keysym $keysym "
    if {[string length $char] == 0} {
	switch -glob -- $keysym {
	    Control* {set mod Control}
	    Alt* {set mod Meta}
	    Shift* {set mod Shift}
	}
	if [info exists mod] {
	    $t insert end "Modifier $mod"
	}
	$t insert end \n
    } else {
	$t insert end "Char \"$char\"\n"
    }
    $t yview -pickplace end
}

if {$tk_version >= 4.0} {
    proc tk_entrySeeCaret { w } { tkEntrySeeInsert $w }
    proc tk_entryBackspace { w } { tkEntryBackspace $w }
    proc tk_entryBackword { w } {
	$w delete [string wordstart [$w get] [expr [$w index insert] - 1]] \
		insert
    }
}
