# buttons.tcl
#
# Action buttons for EXMH.  These are divided into three sets:
# Main - global things like Help and Quit
# Folder - operations on folders like Pack, or Inc.
# Message - operations on the current message.
#
# Support routines for buttons (and menus) in exmh.  The main abstraction
# is the notion of sets of buttons that are enabled and disabled to
# reflect different modes in exmh.  For example, some buttons (and menu
# entries) are disabled when there is no current message.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Buttons_Init {} {
    global buttons
    set buttons(draftMode) 0
    set buttons(group,current) {}
    set buttons(group,nodraft) {}
    set buttons(group,range) {}
    set buttons(group,comp) {}
    set buttons(groupMenu,current) {}
    set buttons(groupMenu,nodraft) {}
    set buttons(groupMenu,range) {}
    set buttons(groupMenu,comp) {}
}
proc Buttons_Group { frame name buts } {
    global buttons
    foreach but $buts {
	lappend buttons(group,$name) $frame.$but
    }
    if {$name == "comp"} {
	# TODO - eliminate this comp special case and add a comp -use button
	set w [lindex $buts 0]
	if {$w != {}} {
	    set buttons(comp) $frame.$w
	}
    }
}

proc Buttons_GroupMenu { menu name labels } {
    global buttons
    foreach l $labels {
	lappend buttons(groupMenu,$name) [list $menu $l]
    }
}

proc ButtonsGroupState { group state } {
    global buttons
    foreach button $buttons(group,$group) {
	if [catch {$button configure -state $state} err] {
	    Exmh_Status $err error
	}
    }
    foreach item $buttons(groupMenu,$group) {
	set menu [lindex $item 0]
	set label [lindex $item 1]
	if [catch {$menu entryconfigure $label -state $state} err] {
	    # The group stuff is not menu-specific, so adding another
	    # menu results in error messages from this point.
	    # Exmh_Status $err error
	}
    }
}

proc Buttons_Current { curMsg } {
    # if curMsg is false, then disable inappropriate buttons
    # otherwise, reenable them.
    # This gets called before Buttons_DraftMode when entering
    # the drafts folder (i.e., buttons(draftMode) may be wrong)
    global buttons
    set buttons(curMsg) $curMsg
    if {$curMsg} {
	ButtonsGroupState current normal
	Buttons_Range $curMsg
	if $buttons(draftMode) {
	    ButtonsGroupState nodraft disabled
	    ButtonsGroupState comp normal
	}
    } else {
	ButtonsGroupState current disabled
	if $buttons(draftMode) {
	    ButtonsGroupState comp disabled
	}
    }
}

proc Buttons_DraftMode { inDraftMode } {
    # This procedure is called when entering the drafts folder
    # in order to dink the buttons so you can edit and send
    # a message in the drafts folder.  The inDraftMode
    # parameter is true when entering the drafts folder,
    # and it is false when leaving it.
    global buttons
    set buttons(draftMode) $inDraftMode
    if {$inDraftMode} {
	# Disable inappropriate buttons
	ButtonsGroupState nodraft disabled
	ButtonsGroupState comp normal
	# Override the Send button
	if [info exists buttons(comp)] {
	    if [catch {
		set buttons(comp,label) [lindex [$buttons(comp) configure -text] 4]
		set buttons(comp,cmd) [lindex [$buttons(comp) configure -command] 4]
		$buttons(comp) configure -text EDIT -command Edit_Draft
		if {! $buttons(curMsg)} {
		    $buttons(comp) configure -state disabled
		}
	    } err] {
		Exmh_Status $err error
	    }
	}
    } else {
	# Reenable buttons
	ButtonsGroupState nodraft normal
	ButtonsGroupState comp normal
	# Restore Send button
	if {[info exists buttons(comp,cmd)] && \
	    [info exists buttons(comp,label)]} { 
	    $buttons(comp) configure -command $buttons(comp,cmd) \
		    -text $buttons(comp,label) -state normal
	    unset buttons(comp,cmd)
	    unset buttons(comp,label)
	}
    }
    return
}

proc Buttons_Range { {ok 1} } {
    if {$ok} {
	ButtonsGroupState range normal
    } else {
	ButtonsGroupState range disabled
    }
}

#####################################################################

proc Buttons_Main { frame } {
    # Note that the unused space in $frame is used
    # by Exmh_MainLabel to hold the version string
    global buttons
    set buttons(mainF) $frame

    foreach b [Widget_GetButDef $frame] {
	Widget_AddButDef $frame $b
    }
    foreach M [Widget_GetMenuBDef $frame] {
	set menu [Widget_AddMenuBDef $frame $M {right padx 1 filly}]
	ButtonMenuInner $menu
    }
}

proc Buttons_Folder { frame } {
    # Create the buttons for operations on items in MH folders
    # Note that the unsed space in $frame is used by
    # Folder_Label to display the status of the current folder.
    global buttons inc
    set buttons(folderF) $frame

    # Menu for extra stuff
    foreach M [Widget_GetMenuBDef $frame] {
	set menu [Widget_AddMenuBDef $frame $M {right padx 1 filly}]
	ButtonMenuInner $menu
    }

    foreach b [Widget_GetButDef $frame] {
	if {$inc(style) == "none" && $b == "inc"} continue
	Widget_AddButDef $frame $b
    }

    # Sequences
    set menu $buttons(folderF).sequences.m
    set sequences [option get . sequences {}]
    set hiddensequences [option get . hiddensequences {}]
    foreach sequence $sequences {
	if {[lsearch -exact $hiddensequences $sequence] == -1} {
	    Widget_AddMenuItem $menu $sequence [list FtocToggleSequence $sequence]
	}
    }
}

proc Buttons_Message { frame } {
    global buttons
    set buttons(msgF) $frame

    # Menu for extra stuff
    # Loop through system and user-defined menus
    foreach M [Widget_GetMenuBDef $frame] {
	set menu [Widget_AddMenuBDef $frame $M {right padx 1 filly}]
	ButtonMenuInner $menu

	# but only deal with system-defined groups
	foreach g [Widget_GetGroupDef $frame] {
	    Buttons_GroupMenu $menu $g [Widget_GetMenuGrDef $frame $g]
	}
    }

    foreach b [Widget_GetButDef $frame] {
	Widget_AddButDef $frame $b
    }

    # The group assignments associate buttons with states.

    foreach g [Widget_GetGroupDef $frame] {
	Buttons_Group $frame $g [Widget_GetButGrDef $frame $g]
    }
}
proc ident { args } {
    concat $args
}
# Ugh! - macro expand the variable name in
# the context of the (original) caller of ButtonMenuInner
# Allows variable references in the app-defaults file
# The split-join trick is basically a no-op that gives the
# TCL interpreter a chance to do variable expansion.  The
# list and protected brackets are required to defend against
# command strings ($c values) that contain semi-colons
proc ButtonMenuInner { menu {level 1} } {
    global pgp

    foreach e [Widget_GetEntryDef $menu] {
	set l [option get $menu l_$e {}]
        if {$pgp(enabled) || ![string match "*PGP*" $l]} {
	    set c [option get $menu c_$e {}]
	    set v [option get $menu v_$e {}]
	    set x [option get $menu x_$e {}]
	    set v [uplevel $level [list subst $v]]	 ;# was ident
	    set c [uplevel $level [list subst $c]]
	    Exmh_Debug \"$l\" $c
	    case [option get $menu t_$e {}] {
		default {Widget_AddMenuItem $menu $l $c}
		check   {Widget_CheckMenuItem $menu $l $c $v}
		radio   {Widget_RadioMenuItem $menu $l $c $v $x}
		cascade {
		    set sub [option get $menu m_$e {}]
		    if {[string length $sub] != 0} {
			set submenu [Widget_CascadeMenuItem $menu $l $c $sub]
			ButtonMenuInner $submenu [expr $level+1]
		    }
		}
		separator {Widget_AddMenuSeparator $menu}
	    }
	}
    }
    return $menu
}
