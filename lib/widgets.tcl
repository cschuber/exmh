# widgets.tcl
#
# Widget utilities
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Widget_Toplevel { path name {class Dialog} {x {}} {y {}} } {
    set self [toplevel $path -class $class]
    set usergeo [option get $path position Position]
    if {$usergeo != {}} {
	if [catch {wm geometry $self $usergeo} err] {
	    Exmh_Debug Widget_Toplevel $self $usergeo => $err
	}
    } else {
	if {($x != {}) && ($y != {})} {
	    Exmh_Debug Event position $self +$x+$y
	    wm geometry $self +$x+$y
	}
    }
    wm title $self $name
    wm iconname $self $name
    wm group $self .
    return $self
}
proc Widget_Vgeo { geo win } {
    set vx [winfo vrootx $win]
    set vy [winfo vrooty $win]
    if {$vx == 0 && $vy == 0} {
	Exmh_Debug Widget_Vgeo vx=$vx vy=$vy
	return $geo
    }
    set wd [winfo width $win]
    set ht [winfo height $win]
    if [regexp {([\+-])([0-9]+)([\+-])([0-9]+)} $geo match s1 x s2 y] {
	if {$s1 == "-"} {
	    set x -$x
	}
	if {$s2 == "-"} {
	    set y -$y
	}
	if {($x < 0) || ([string compare $x "-0"] == 0)} {
	    set x [expr [winfo screenwidth $win]+$x-$wd]
	}
	if {($y < 0) || ([string compare $y "-0"] == 0)} {
	    # 64 depends on icon height
	    set y [expr [winfo screenheight $win]+$y-$ht]
	}
	set x [expr $x-$vx]
	set y [expr $y-$vy]
	Exmh_Debug Widget_Vgeo: $geo, vx=$vx vy=$vy, => +$x+$y
	return +$x+$y
    } else {
	Exmh_Debug Widget_Vgeo failed on $geo
	return $geo
    }
}
proc Widget_Frame {par child {class Exmh} {where {top expand fill}} args } {

    if {$par == "."} {
	set self .$child
    } else {
	set self $par.$child
    }
    eval {frame $self -class $class} $args
    pack append $par $self $where
    return $self
}

proc Widget_SplitFrame {f c1 c2} {
    # Create a left and right frame within a frame
    frame $f.left -class $c1
    frame $f.right -class $c2
    pack append $f $f.left {left fill expand} $f.right {left fill expand}
    return [list $f.left $f.right]
}

proc Widget_SplitFrameR {f c1 c2} {
    # Create a left and right frame within a frame - left frame doesn't expand
    frame $f.left -class $c1
    frame $f.right -class $c2
    pack append $f $f.left {left fill} $f.right {left fill expand}
    return [list $f.left $f.right]
}
proc Widget_SplitFrameV {f c1 c2} {
    # Create a top and bottom frame within a frame
    frame $f.top -class $c1
    frame $f.bot -class $c2
    pack append $f $f.top {top fill expand} $f.bot {bottom fill expand}
    return [list $f.top $f.bot]
}

proc Widget_AddButDef {par but {where {right padx 1 filly}} } {
    # Create a Packed button.  Return the button pathname
    set cmd2 [list button $par.$but -highlightthickness 1]
    if [catch $cmd2 t] {
	catch {puts stderr "Widget_AddButDef (warning) $t"}
	eval $cmd2 {-font fixed}
    }
    pack append $par $par.$but $where
    return $par.$but
}
proc Widget_ReEvalCmd { but } {
    uplevel "$but config -command \[subst \[$but cget -command]]"
}

proc Widget_AddBut {par but txt cmd {where {right padx 1 filly}} } {
    # Create a Packed button.  Return the button pathname
    set cmd2 [list button $par.$but -text $txt -command $cmd -highlightthickness 1]
    if [catch $cmd2 t] {
	catch {puts stderr "Widget_AddBut (warning) $t"}
	eval $cmd2 {-font fixed}
    }
    pack append $par $par.$but $where
    return $par.$but
}

proc Widget_CheckBut {par but txt var {where {right padx 1}} args} {
    # Create a check button.  Return the button pathname
    set cmd [list checkbutton $par.$but -text $txt -variable $var]
    if [catch [concat $cmd $args] t] {
	catch {puts stderr "Widget_CheckBut (warning) $t"}
	eval $cmd {-font fixed} $args
    }
    pack append $par $par.$but $where
    return $par.$but
}

proc Widget_RadioBut {par but txt var {where {right padx 1}} args} {
    # Create a radio button.  Return the button pathname
    set cmd [list radiobutton $par.$but -text $txt -variable $var -value $txt]
    if [catch [concat $cmd $args] t] {
	catch {puts stderr "Widget_RadioBut (warning) $t"}
	eval $cmd {-font fixed} $args
    }
    pack append $par $par.$but $where
    return $par.$but
}

proc Widget_AddMenuBDef {par b {where {left filly}} } {
    # Create a button and a menu to go with it.  Return the menu pathname
    set cmd [list menubutton $par.$b -menu $par.$b.m -highlightthickness 1]
    if [catch $cmd t] {
	catch {puts stderr "Widget_AddMenuBDef (warning) $t"}
	eval $cmd {-font fixed}
    }
    if [catch {menu $par.$b.m}] {
	menu $par.$b.m -font fixed
    }
    pack append $par $par.$b $where
    return $par.$b.m
}
proc Widget_AddMenuB {par b {label {}} {where {left filly}} } {
    # Create a button and a menu to go with it.  Return the menu pathname
    set cmd [list menubutton $par.$b -menu $par.$b.m -text $label -highlightthickness 1]
    if [catch $cmd t] {
	catch {puts stderr "Widget_AddMenuB (warning) $t"}
	eval $cmd {-font fixed}
    }
    if [catch {menu $par.$b.m}] {
	menu $par.$b.m -font fixed
    }
    pack append $par $par.$b $where
    return $par.$b.m
}

proc Widget_AddMenuItem {m l cmd {accel NONE}} {
    # Create a menu command entry with optional accelerator string.
    set cmd2 [list $m add command -label $l  -command $cmd]
    if [catch $cmd2 t] {
	catch {puts stderr "Widget_AddMenuItem (warning) $t"}
	eval $cmd2 {-font fixed}
    }
    if {$accel != "NONE"} {
	$m entryconfigure $l -accelerator $accel
    }
}

proc Widget_AddMenuSeparator {m} {
    $m add separator
}

proc Widget_RadioMenuItem {m l {cmd { }} {var {}} {value {}} args} {
    # Create a radio menu entry.  By default all radio entries
    # for a menu share a variable.
    if {$var == {}} {
	set var v$m
    }
    set cmd2 [list $m add radio -label $l  -variable $var -value $value -command $cmd]
    if [catch [concat $cmd2 $args] t] {
	catch {puts stderr "Widget_RadioMenuItem (warning) $t"}
	eval $cmd2 $args {-font fixed}
    }
}

proc Widget_CheckMenuItem {m l {c { }} {var {}} args} {
    # Create a Check button menu entry.  By default all check entries
    # have their own variable.
    if {$var == {}} {
	set var v$m.$l
    }
    set cmd [list $m add check -label $l -variable $var -command $c]
    if [catch [concat $cmd $args] t] {
	catch {puts stderr "Widget_CheckMenuItem (warning) $t"}
	eval $cmd $args {-font fixed}
    }
    return $var
}

proc Widget_CascadeMenuItem {menu l {c { }} {sub {}}} {
    # Create a cascade menu entry.
    # Note that sub is the component after menu
    if [catch {menu $menu.$sub} submenu] {
	set submenu [menu $menu.$sub -font fixed]
    }
    set cmd [list $menu add cascade -label $l -menu $submenu -command $c]
    if [catch $cmd t] {
	catch {puts stderr "Widget_CascadeMenuItem (warning) $t"}
	eval $cmd {-font fixed}
    }
    return $submenu
}


proc Widget_SimpleText { frame name {where {expand fill}} args } {
    # Create a one-line text widget
    global exwin
    set cmd [list text $frame.$name]
    if [catch [concat $cmd $args] t] {
	catch {puts stderr "Widget_SimpleText (warning) $t"}
	set t [eval $cmd $args {-font fixed}]
    }
    pack append $frame $t $where
    $t mark set insert 0.0

    if [regexp {setgrid} $args] {
	wm minsize [winfo toplevel $frame] 10 1
    }
    Widget_TextInitText $t
    return $t
}
proc Widget_Message { frame {name msg} args} {
    set cmd [list message $frame.$name]
    if [catch [concat $cmd $args] t] {
	catch {puts stderr "Widget_Message (warning) $t"}
	eval $cmd $args {-font fixed}
    }
    pack append $frame $frame.$name {top fill expand}
    return $frame.$name
}
proc Widget_Label { frame {name label} {where {left fill}} args} {
    set cmd [list label $frame.$name ]
    if [catch [concat $cmd $args] t] {
	catch {puts stderr "Widget_Label (warning) $t"}
	eval $cmd $args {-font fixed}
    }
    pack append $frame $frame.$name $where
    return $frame.$name
}
proc Widget_Entry { frame {name entry} {where {left fill}} args} {
    set cmd [list entry $frame.$name ]
    if [catch [concat $cmd $args] t] {
	catch {puts stderr "Widget_Entry (warning) $t"}
	eval $cmd $args {-font fixed}
    }
    pack append $frame $frame.$name $where
    return $frame.$name
}


proc Widget_ReadOnlyText { w } {
    # Undo the modification keystrokes
    foreach b [bind $w] {
	if {! [string match *Button* $b] && ! [string match {*B[123]*} $b]} {
	    bind $w $b ""
	}
    }
}
proc Widget_PlaceDialog { parent frame } {
    place $frame -in $parent -relx 0.5 -rely 0.5 -anchor center
}
#
# Widget_BeginEntries, Widget_LabeledEntry, and Widget_EndEntries
# are used to create a set of labeled-entry widgets.  The labels
# line up and <Tab> takes the focus from one to the next.
#
# Make sure to call Widget_EndEntries because it doesn't some cleanup
# and sets up bindtags so <Tab> doesn't get inserted into the entries.
#
proc Widget_BeginEntries { {lwidth 10} {ewidth 20} {okCmd {}} {link {}}} {
    global widgetEntry
    set widgetEntry(lwidth) $lwidth
    set widgetEntry(ewidth) $ewidth
    set widgetEntry(okCmd) $okCmd
    catch {unset widgetEntry(last)}
    if {$link != {}} {
	set widgetEntry(last) $link
	set widgetEntry(first) [lindex [bind $link <Tab>] 1]
	if {[string length [string trim $widgetEntry(first)]] == 0} {
	    error "Widget_BeginEntries link=$link"
	}
    }
}
proc Widget_LabeledEntry { w name textvar args} {
    global widgetEntry
    set f [frame $w -class LabeledEntry]
    Widget_Label $f label {left} -text $name -width $widgetEntry(lwidth)
    eval {Widget_Entry $f entry {left fillx} \
	    -width $widgetEntry(ewidth) -textvariable $textvar} $args
    pack $f -side top -fill x
    if [info exists widgetEntry(last)] {
	bind $widgetEntry(last) <Tab> [list focus $f.entry]
	bind $f.entry <Shift-Tab> [list focus $widgetEntry(last)]
    } else {
	set widgetEntry(first) $f.entry
    }
    Widget_BindEntryCmd $f.entry <Return> $widgetEntry(okCmd)
    set widgetEntry(last) $f.entry
    return $f
}
proc Widget_BindEntryCmd {entry  sequence cmd} {
    bind $entry $sequence "$cmd ; break"
    # toplevel bindings before Entry so that <Tab>, <Shift-Tab>, <Return>
    # all can break
    bindtags $entry [list $entry [winfo toplevel $entry] Entry all]
}
proc Widget_EntryEntry { w labelvar textvar} {
    global widgetEntry
    set f [frame $w -class LabeledEntry]
    Widget_Label $f label {left} -text "xx" -width $widgetEntry(lwidth)
    Widget_Entry $f elabel {left} -textvariable $labelvar \
	-width [expr $widgetEntry(lwidth) - 1]
    pack forget $f.elabel
    place $f.elabel -in $f.label -anchor ne -relx 1.0 -y -1 
    Widget_Entry $f entry {left fillx} \
	-width $widgetEntry(ewidth) -textvariable $textvar
    pack $f -side top -fill x
    bind $f.elabel <Tab> [list focus $f.entry]
    bind $f.entry <Shift-Tab> [list focus $f.elabel]
    if [info exists widgetEntry(last)] {
	bind $widgetEntry(last) <Tab> [list focus $f.elabel]
	bind $f.elabel <Shift-Tab> [list focus $widgetEntry(last)]
    } else {
	set widgetEntry(first) $f.elabel
    }
    Widget_BindEntryCmd $f.entry <Return> $widgetEntry(okCmd)
    Widget_BindEntryCmd $f.elabel <Return> $widgetEntry(okCmd)
    set widgetEntry(last) $f.entry
    return $f
}
proc Widget_LabeledEntryOr { f iter textvar} {
    global widgetEntry
    if {$iter > 2} {
	set pe $f.entry[expr $iter -1]
    } else {
	set pe $f.entry
    }
    Widget_Entry $f entry$iter {top fillx} -textvariable $textvar \
    	-width [lindex [$pe config -width] 4]
    set me $f.entry$iter
    bindtags $me [list $me [winfo toplevel $me] Entry]
    bind $me <Return> [bind $pe <Return>]
    bind $me <Tab> [bind $pe <Tab>]
    bind $pe <Tab> [list focus $me]
    bind $me <Shift-Tab> [list focus $pe]
    bind [lindex [bind $me <Tab>] 1] <Shift-Tab> [list focus $me]
    focus $me
    return $f
}
proc Widget_EndEntries {} {
    global widgetEntry
    if [info exists widgetEntry(first)] {
	# So <Return> <Tab> and <Shift-Tab> bindings skip the
	# default action to enter the character
	set w $widgetEntry(first)
	bind [winfo toplevel $w] <Return> break
	bind [winfo toplevel $w] <Tab> break
	bind [winfo toplevel $w] <Shift-Tab> break
	bind $widgetEntry(last) <Tab> [list focus $widgetEntry(first)]
	bind $widgetEntry(first) <Shift-Tab> [list focus $widgetEntry(last)]
	focus $widgetEntry(first)
	return $widgetEntry(last)
    }
}
# Widget_ListEditor
#
# Constructs a ListEditor widget which consists of a label, a
# scrolling list an entry and three buttons marked "Insert", "Delete",
# and "Change".  A ListEditor allows the user to add, remove, or
# change the items in a list.
#
# Arguments:
#
# frame		- the frame into which the ListEditor should be packed
# title		- the text that is placed in the label at the top
# entryvar	- the name of the variable that should be associated
# 		  with the entry
# insert	- the command to be executed by "Insert" button
# change	- the command to be executed by "Change" button
# delete	- the command to be executed by "Delete" button
# select	- the command to be executed after an item is selected
#

proc Widget_ListEditor {frame title entryvar {insert {}} {change {}} {delete {}} {select {}}} {
    global exwin

    FontWidget label $frame.label \
	-text $title

    FontWidget listbox $frame.listbox \
	-exportselection {1} \
	-relief {sunken} \
	-yscrollcommand "$frame.scrollbar set"

    scrollbar $frame.scrollbar \
	    -command "$frame.listbox yview" \
	    -relief {sunken}

    FontWidget entry $frame.entry \
	    -textvariable $entryvar
    
    frame $frame.buttons
    
    FontWidget button $frame.buttons.insert \
	    -text {Insert} \
	    -command $insert
    
    FontWidget button $frame.buttons.change \
	    -text {Change} \
	    -command $change
    
    FontWidget button $frame.buttons.delete \
	    -text {Delete} \
	    -command $delete
    
    # pack button frame
    pack $frame.buttons.insert \
	    $frame.buttons.change \
	    $frame.buttons.delete \
	    -side left -padx 10
    
    # bindings
    $frame.listbox config -selectmode browse
    bind $frame.listbox <Any-B1-Motion> \
	    [list WidgetListSelect %W %y $entryvar $select]
    bind $frame.listbox <Any-Button-1> \
	    [list WidgetListSelect %W %y $entryvar $select]

    bind $frame.entry <Any-Return> $insert

    # pack it all in now
    pack $frame.label -side top -fill x
    pack $frame.buttons -side bottom
    pack $frame.entry -side bottom -pady 5 -fill x
    pack $frame.scrollbar -side $exwin(scrollbarSide) -padx 8 -fill y
    pack $frame.listbox -side top -expand 1 -fill both

    return $frame
}

proc FontWidget { args } {
    if [catch $args err] {
	eval $args -font fixed
    }
}
proc WidgetListSelect { w y varName selCmd } {
    upvar #0 $varName entryvar
    set i [$w nearest $y]
    $w select set $i
    set entryvar [$w get $i]
    eval $selCmd
}

proc Widget_ListSearch { frame } {
    set str [$frame.entry get]
    if {[string length $str] == 0} {
	return
    }
    set l $frame.listbox
    set size [$l size]
    $l select clear 0 end
    for {set i 0} {$i < $size} {incr i} {
	if {[string match ${str}* [$l get $i]]} {
	    $l select set $i
	    $l see $i
	    return
	}
    }
}

#
# Procedures hiding the configuration resource hierarchy
# 
proc Widget_GetButDef { f } {
    WidgetGetResources $f buttonlist
}
proc Widget_GetMenuBDef { f } {
    WidgetGetResources $f menulist
}
proc Widget_GetEntryDef { m } {
    WidgetGetResources $m entrylist
}
proc Widget_GetButGrDef { f g } {
    WidgetGetResources $f g_$g
}
proc Widget_GetMenuGrDef { f g } {
    WidgetGetResources $f gm_$g
}
# Only system groups allowed (mentioned in buttons.tcl)
proc Widget_GetGroupDef { f } {
    option get $f groups {}
}
proc WidgetGetResources { w resname } {
    set res	[option get $w $resname {}]
    set lres    [option get $w l$resname {}]
    set ures 	[option get $w u$resname {}]

    set l-res	[option get $w l-$resname {}]
    set u-res	[option get $w u-$resname {}]

    set list [WidgetResListSubtract $res ${l-res}]
    set list [concat $list $lres]
    set list [WidgetResListSubtract $list ${u-res}]

    return [concat $list $ures]
}

proc WidgetResListSubtract { orglist remlist } {
    #Remove words in 'remlist' from 'orglist'
    set newlist $orglist
    foreach dele $remlist {
    	set tmplist ""
	foreach item $newlist {
	    if {"x$item" != "x$dele"} { lappend  tmplist $item }
	}
	set newlist $tmplist
    }
    return $newlist
}
proc Widget_ColorDefault {w resource {class {}}} {
    set color [option get $w $resource $class]
    if {[string length $color] == 0} {
	set color [lindex [$w config -[string tolower $resource]] 3]
    }
    return $color
}
