#
# fdisp.tcl
#
# Folder display, handling nesting and highlights to reflect folder state.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Fdisp_Init {} {
    global fdisp mhProfile exmh flist

    if {[info exists exmh(newuser)] && [info exists flist(allfolders)]} {
	set N [llength $flist(allfolders)]
	if {$N < 5} {
	    set fdisp(maxLines) 1
	} elseif {$N < 15} {
	    set fdisp(maxLines) 2
	} elseif {$N < 30} {
	    set fdisp(maxLines) 3
	} else {
	    set fdisp(maxLines) 4
	}
    }

    Preferences_Add "Folder Display" \
"These items affect the display of the labels in the folder display window.
If you change key bindings on labels, you'll have to toggle one of the other
options to force a redisplay because that's when the bindings are set." {
	{fdisp(maxLines) fdispLines 4 {Max fdisp rows}
"The maximum number of rows of folder labels in
the folder display.  If there are more folders than
will fit in this space, the display becomes scrollable." }
	{fdisp(toplevel) fl_toplevel OFF {Detached fdisp display}
"The folder display area can be displayed in a separate
toplevel window.  You can use the *Fltop.position Xresource
to control its initial placement on the screen, and the
*Fltop.Canvas.width and *Fltop.Canvas.height to control
its size."}
	{fdisp(oneCol) fdisp1Col OFF {Use one column}
"Enabling this with a detached display aligns all the
folders in one vertical column."}
	{fdisp(popdownStyle) fdispPopdownStyle {CHOICE polygon rectangle} {Subfolder popdown}
"The style of the sub folder popdown menu
used to display subfolders." }
	{fdisp(popdownAction) fdispPopdownAction {CHOICE navbutton enter redisplay} {Popdown action}
"This determines how the popdown display is triggered:
navbutton - press navigation (middle) button to get the popdown.
enter - move the mouse over the button to get the popdown.
redisplay - do not use popdowns at all.  Instead, navbutton
(middle) causes the whole folder display to change.
The navigation button is settable via an Xresource." }
	{fdisp(popdownRemove) fdispPopdownRemove {CHOICE leave navbutton} {Remove popdown on...}
"This determines what causes a popdown display to be removed:
navbutton - press navigation (middle) button on another label.
leave - leave the area of the popdown.  This actually has to
be implemented by triggering on <Enter> to other labels." }
    }
    # The remaining parameters can be overridden by hand in the user resources

    Preferences_Resource fdisp(font)		fl_font fixed
    Preferences_Resource fdisp(xgap)		fl_xgap 8
    Preferences_Resource fdisp(ygap)		fl_ygap 8
    Preferences_Resource fdisp(curbutton)	fl_curbutton 1
    Preferences_Resource fdisp(navbutton)	fl_navbutton 2
    Preferences_Resource fdisp(tarbutton)	fl_tarbutton 3

    Preferences_Resource fdisp(c_current)	c_current red
    Preferences_Resource fdisp(c_unseen)	c_unseen  blue
    Preferences_Resource fdisp(c_moved)		c_moved   yellow
    Preferences_Resource fdisp(c_popup)		c_popup   wheat
    Preferences_Resource fdisp(c_fg)		c_foreground black
    Preferences_Resource fdisp(c_bg)		c_background white

    trace variable fdisp(font) w FdispFixupFont
    set fdisp(lastFont) $fdisp(font)
    trace variable fdisp(maxLines) w FdispFixupMaxLines
    set fdisp(lastMaxLines) $fdisp(maxLines)
    trace variable fdisp(toplevel) w FdispFixupToplevel
    set fdisp(lastToplevel) $fdisp(toplevel)
    trace variable fdisp(oneCol) w FdispFixupRedisplay
    trace variable fdisp(popdownStyle) w FdispFixupRedisplay
}

# Hooks for recreating the folder display when config changes
proc FdispFixupMaxLines { args } {
    global exwin fdisp

    if [catch {expr {$fdisp(maxLines) * 2}}] {
	set fdisp(maxLines) $fdisp(lastMaxLines)
	return	;# bogus value
    }
    if {$fdisp(maxLines) != $fdisp(lastMaxLines)} {
	set fdisp(width,canvas) 0
	set fdisp(maxLines,$fdisp(canvas)) $fdisp(maxLines)
	set fdisp(lastMaxLines) $fdisp(maxLines)
	set h [expr {$fdisp(maxLines)*($fdisp(itemHeight) + $fdisp(ygap)) + $fdisp(ygap)}]
	$fdisp(canvas) configure -height $h
    }
}
proc FdispFixupRedisplay { args } {
    Fdisp_Redisplay
}
proc FdispFixupToplevel { args } {
    global fdisp
    if {$fdisp(toplevel) != $fdisp(lastToplevel)} {
	if [info exists fdisp(topWidget)] {
	    destroy $fdisp(topWidget)
	    unset fdisp(topWidget)
	} else {
	    destroy $fdisp(frame)
	    unset fdisp(frame)
	}
	FdispMake
    }
    set fdisp(lastToplevel) $fdisp(toplevel)
}

# Make the folder display
proc FdispMake {} {
    global fdisp
    if {$fdisp(toplevel)} {
	FdispMakeToplevel
    } else {
	FdispMakeFrame
    }
}

# Create folder list in a toplevel and make the canvas inside it
proc FdispMakeToplevel { } {
    global fdisp
    Exwin_Toplevel .fl "Folder list" Fltop nomenu
    set fdisp(topWidget) .fl
    wm minsize $fdisp(topWidget) 100 30
    wm protocol .fl WM_DELETE_WINDOW FdispDeleted
    FdispMakeCanvas $fdisp(topWidget)
    focus $fdisp(canvas)
    set icon [option get $fdisp(topWidget) iconposition IconPosition]
    catch {
	Exwin_IconPosition $fdisp(topWidget) $icon
    }
    set iconic [option get $fdisp(topWidget) iconic Iconic]
    if {$iconic == {}} {
	set iconic $exmh(iconic)
    }
    if {$iconic} {
	wm iconify $fdisp(topWidget)
    }
}
proc FdispDeleted {} {
    wm iconify .fl
    Exmh_Status "Folder display closed, not destroyed"
}
proc Fdisp_Checkpoint { varName } {
    # Add Xresources lines to $varName that save window size
    upvar $varName newstuff
    global fdisp
    catch {
	set can $fdisp(topWidget).can
	set width [winfo width $can]
	set height [winfo height $can]
	set bd [$can cget -borderwidth]
	incr bd [$can cget -highlightthickness]
	set width [expr $width - 2*$bd]
	set height [expr $height - 2*$bd]
	lappend newstuff "*Fltop.Canvas.height:\t$height"
	lappend newstuff "*Fltop.Canvas.width:\t$width"
    }
}

# Create folder list in a frame and make the canvas inside it
proc FdispMakeFrame { } {
    global fdisp
    set fdisp(frame) [Widget_Frame $fdisp(parent) f1 Frame]
    FdispMakeCanvas $fdisp(frame)
}

# Create the canvas for the folder display
proc FdispMakeCanvas { frame } {
    global fdisp exwin
    set fdisp(canvas) [canvas $frame.can -bd 2 -relief raised \
	-highlightthickness 0]
    set s [scrollbar $frame.sv -command [list $fdisp(canvas) yview] \
	-highlightthickness 0]
    $fdisp(canvas) configure -yscrollcommand [list $s set]

    # Find out how big labels are
    if [catch {
	set id [$fdisp(canvas) create text 0 0 \
	    -anchor nw -justify center -text 0123456789 -font $fdisp(font)]
    } err] {
	Exmh_Status $err
	set fdisp(font) fixed
	set id [$fdisp(canvas) create text 0 0 \
	    -anchor nw -justify center -text 0123456789 -font $fdisp(font)]
    }
    set size [$fdisp(canvas) bbox $id]
    set fdisp(itemHeight) [expr {[lindex $size 3] - [lindex $size 1]}]
    set fdisp(charWidth) [expr {([lindex $size 2] - [lindex $size 0])/10}]
    $fdisp(canvas) delete $id

    catch {
	$fdisp(canvas) configure -yscrollincrement \
	    [expr {$fdisp(itemHeight)+$fdisp(ygap)+1}]
    }

    if {!$fdisp(toplevel)} {
	set h [expr {$fdisp(maxLines)*($fdisp(itemHeight) + $fdisp(ygap)) + $fdisp(ygap)}]
	$fdisp(canvas) configure -height $h
    }

    bindtags $fdisp(canvas) \
	[list $fdisp(canvas) Command [winfo toplevel $fdisp(canvas)] all]
    bind $fdisp(canvas) <2> {%W scan mark %x %y}
    bind $fdisp(canvas) <B2-Motion> {%W scan dragto %x %y}
    bind $fdisp(canvas) <Configure> FdispCanvasConfigure
    pack $s -side $exwin(scrollbarSide) -fill y
    pack $fdisp(canvas) -side $exwin(scrollbarSide) -fill both -expand 1

    # fdisp popup color hack
    if {[tk colormodel $fdisp(canvas)] != "color"} {
	if {! [regexp {black|white} $fdisp(c_popup)]} {
	    set fdisp(c_popup) [$fdisp(canvas) cget -bg]
	}
    }

    FdispDragAttach canvas
}
proc FdispFixupFont { args } {
    global exwin fdisp
    if {$fdisp(lastFont) != $fdisp(font)} {

	# Find out how big labels are
	if [catch {
	    set id [$fdisp(canvas) create text 0 0 \
		-anchor nw -justify center -text foo -font $fdisp(font)]
	} err] {
	    Exmh_Status $err
	    set fdisp(font) fixed
	    set id [$fdisp(canvas) create text 0 0 \
		-anchor nw -justify center -text foo -font $fdisp(font)]
	}
	set size [$fdisp(canvas) bbox $id]
	set fdisp(itemHeight) [expr {[lindex $size 3] - [lindex $size 1]}]
	$fdisp(canvas) delete $id
	set fdisp(lastFont) $fdisp(font)

	# Changing canvas size triggers redisplay
	set h [expr {$fdisp(maxLines)*($fdisp(itemHeight) + $fdisp(ygap)) + $fdisp(ygap)}]
	$fdisp(canvas) configure -height $h
	if [info exists fdisp(cache)] {
	    set h [expr {($fdisp(itemHeight) + $fdisp(ygap)) + $fdisp(ygap)}]
	    $fdisp(cache) configure -height $h
	}
    }
}

proc Fdisp_Window { parent } {
    global fdisp exwin

    set fdisp(parent) $parent

    # a bogus child is needed inside fdisp(parent) so it properly
    # shrinks down when the cache is removed or when the main display
    # is moved to a separate top-level
    Widget_Frame $parent bogus Frame

    # The following creates fdisp(canvas), either in a toplevel or a frame
    FdispMake

    global fcache
    if $fcache(enabled) {
	Fcache_CreateWindow
	FdispDragAttach cache
    }

    set fdisp(folder) .
    foreach can {canvas cache} {
	set fdisp(entered,$can) 0		;# Display routine entered
	set fdisp(pending,$can) 0		;# Display routine blocked
	set fdisp(width,$can) 0			;# last display width
	set fdisp(fset,$can) {}			;# last folder set
	set fdisp(cur,$can) {}			;# current folder name
	set fdisp(tar,$can) {}			;# target folder name
	set fdisp(curid,$can) {}		;# canvas item ids
	set fdisp(boxid,$can) {}
	set fdisp(tarid,$can) {}
	set fdisp(tboxid,$can) {}
	set fdisp(leafs,$can) {}		;# list of leaf highlight tags
    }

}
proc Fdisp_Redisplay {} {
    global fdisp
    FdispMain $fdisp(folder) 1
    Fcache_Display 1
}

proc FdispCanvasConfigure {} {
    global fdisp
    FdispMain $fdisp(folder) 1
}

proc FdispMain { {folder {.}} {force 0} } {
    # Layout the current level of folder buttons on the canvas
    global fdisp exmh
    Label_Main [expr {[string compare $folder "."]==0 ? {} : "$folder"}]
    set fdisp(folder) $folder
    Flist_FindAllFolders
    set folderSet [Flist_FolderSet $folder]
    set len [llength $folderSet]
    set msec [lindex [time [list Fdisp_Layout canvas $folderSet $folder $force]] 0]
    Exmh_Debug Fdisp_HighlightCanvas [time [list Fdisp_HighlightCanvas canvas]]
}

proc Fdisp_Layout { can folderSet {folder {}} {force 0} } {
    # Main layout routine.  Because this is triggered by
    # <Configure> events, and because it dinks with the
    # size of the canvas, it needs to be reentrant.
    #
    global fdisp

    set canvas $fdisp($can)

    if {$fdisp(entered,$can)} {
	set fdisp(pending,$can) 1
	return
    }
    set width [winfo width $canvas]
    set bd [$canvas cget -borderwidth]
    incr bd [$canvas cget -highlightthickness]
    set width [expr $width - 2*$bd]

    if {! $force &&
	($width == $fdisp(width,$can)) &&
	($folderSet == $fdisp(fset,$can))} {
	if {$fdisp(pending,$can)} {
	    set fdisp(pending,$can) 0
	    after 1 [list Fdisp_Layout $can $folderSet $folder]
	}
	return
    }
    incr fdisp(entered,$can)

    set fdisp(width,$can) $width
    set fdisp(fset,$can) $folderSet

    catch { $canvas delete all }
    Fdisp_ClearSpecials $canvas

    if {$can != "cache"} {
	FdispPopdownReset
	Exmh_Status "Building folder display... $folder"
    }
    set fdisp(maxy,$can) [FdispLayoutInner $can $fdisp(xgap) $fdisp(ygap) \
		    $width $folderSet $folder FdispBindLabel]

    set fdisp(bgid,$can) [$canvas create rect 0 0 0 0 \
		-fill [$canvas cget -bg] -outline ""]
    $canvas lower $fdisp(bgid,$can)
    FdispSetCanvasSize $can $fdisp(maxy,$can)
    if {$can != "cache"} {
	Exmh_Status ""
    }
    incr fdisp(entered,$can) -1
    if {$fdisp(pending,$can)} {
	set fdisp(pending,$can) 0
	after 1 [list Fdisp_Layout $can $folderSet $folder]
    }
}
proc FdispLayoutInner { can x1 y1 width folderSet folder bindProc {skipSelf no} {tag _notag_} } {
    global fdisp
    set canvas $fdisp($can)
    set maxy $fdisp(itemHeight)		;# Per row max item height
    set x $x1
    set y $y1
    set iscache [string match cache $can]
    foreach f $folderSet {
	# Determine label text for the folder
	if {[string compare $f $folder] == 0} {
	    if [string match skipSelf $skipSelf] {
		continue
	    } else {
		set text ".."
	    }
	} else {
	    if $iscache {
		set text [Fcache_FolderName $f]
	    } else {
		set text [file tail $f]
	    }
	}
	# Create the text (or bitmap) at location 0 0
	set id [Fdisp_Label $canvas $f $text]
	set bbox [$canvas bbox $id]
	set twidth [expr [lindex $bbox 2]-[lindex $bbox 0]]
	set theight [expr [lindex $bbox 3]-[lindex $bbox 1]]
	if {($twidth + $fdisp(xgap)/2 + $x > $width) ||
		(($fdisp(oneCol) && !$iscache) && ($y > $y1 || $x > $x1))} {
	    incr y [expr {$fdisp(ygap) + $maxy}]
	    set x $x1
	    set maxy $fdisp(itemHeight)		;# Per row max item height
	}
	if {$theight > $maxy} {
	    set maxy $theight
	}
	# Move it into position after we see how big it is.
	$canvas move $id $x $y
	incr x [expr {$fdisp(xgap) + $twidth}]

	# Determine style of the box, depending on nesting
	if {[string compare $f $folder] == 0} {
	    set ftype goParent
	} else {
	    if [Flist_SubFolders $f] {
		if $iscache {
		    # This supresses the drop-shadow in the cache display,
		    # but also turns off the redisplay mode behavior...
		    set ftype leaf
		} else {
		    set ftype hasNested
		}
	    } else {
		set ftype leaf
	    }
	}
	set box [Fdisp_Box $fdisp($can) $id $ftype $tag]
	FdispUpdateMap $can $f $id
	FdispUpdateBmap $can $f $box
	$bindProc $can $id $ftype $f
	if {$fdisp(popdownAction) != "enter"} {
	    $bindProc $can $box $ftype $f
	}
    }
    return [expr $y + $maxy]
}
proc Fdisp_Label { canvas f text } {
    global fdisp folderInfo fdispSpecial
    if [info exists folderInfo(bitmap,$f)] {
	set special 0
	if [info exists folderInfo(fg,$f)] {
	    set fg $folderInfo(fg,$f)
	    set special 1
	} else {
	    set fg black
	}
	if [info exists folderInfo(bg,$f)] {
	    set bg $folderInfo(bg,$f)
	    set special 1
	} else {
	    set bg white
	}
	set id [$canvas create bitmap 0 0 -anchor nw \
		    -bitmap $folderInfo(bitmap,$f) \
		    -foreground $fg -background $bg]
	if {! $special} {
	    $canvas addtag bitmap withtag $id
	} else {
	    lappend fdispSpecial($canvas) $id
	    set fdispSpecial($canvas,$id) [list $fg $bg]
	}
    } else {
	set id [$canvas create text 0 0 -anchor nw \
		-justify center -text $text -font $fdisp(font) -tag text]
    }
    return $id
}
proc Fdisp_FixupSpecials { canvas } {
    global fdispSpecial
    if ![info exists fdispSpecial($canvas)] {
	return
    }
    foreach id $fdispSpecial($canvas) {
	if [info exists fdispSpecial($canvas,$id)] {
	    set fg [lindex $fdispSpecial($canvas,$id) 0]
	    set bg [lindex $fdispSpecial($canvas,$id) 1]
	    $canvas itemconfigure $id -background $bg -foreground $fg
	}
    }
}
proc Fdisp_ClearSpecials { canvas } {
    global fdispSpecial
    if ![info exists fdispSpecial($canvas)] {
	return
    }
    foreach id $fdispSpecial($canvas) {
	unset fdispSpecial($canvas,$id)
    }
    unset fdispSpecial($canvas)
}
proc Fdisp_Box { canvas tid ftype {tag {}} } {
    # outline box.  I note that for variable width fonts,
    # the bbox is too long.  Oh well.
    global fdisp

    if {$tag != {}} {
	$canvas addtag $tag withtag $tid
    }

    set bbox [$canvas bbox $tid]
    set x1 [expr {[lindex $bbox 0] - 1}]
    set x2 [expr {[lindex $bbox 2] + 1}]
    set y1 [expr {[lindex $bbox 1] - 1}]
    set y2 [expr {[lindex $bbox 3] + 1}]

    set box [$canvas create rect $x1 $y1 $x2 $y2 -fill $fdisp(c_bg) \
	-tags [list box $tag]]

    # Need one box for a dropshadow, and then one extra box to ensure
    # a stippled foreground obscures the dropshadow box
    if {[string compare $ftype goParent] == 0} {
	$canvas lower [$canvas create rect $x1 $y1 $x2 $y2 \
				-fill $fdisp(c_bg) -tags $tag]
	$canvas lower [$canvas create rect \
	    [expr $x1+3] [expr $y1+3] [expr $x2+3] [expr $y2+3] \
				-fill $fdisp(c_bg) -tags $tag]
    } else {
	if {[string compare $ftype hasNested] == 0} {
	    $canvas lower [$canvas create rect $x1 $y1 $x2 $y2 \
				-fill $fdisp(c_bg) -tags $tag]
	    $canvas lower [$canvas create rect \
		[expr $x1+3] [expr $y1+3] [expr $x2+3] [expr $y2+3] \
				-fill $fdisp(c_fg) -tags $tag]
	}
    }
    $canvas raise $tid	;# display text over top the box
    return $box
}
proc FdispBindLabel { can id ftype f } { 
    global fdisp
    set canvas $fdisp($can)

    $canvas bind $id <$fdisp(curbutton)> [list Folder_Change $f]
    $canvas bind $id <$fdisp(tarbutton)> \
		    [list Folder_TargetMove $f]
    $canvas bind $id <Shift-$fdisp(tarbutton)> \
		    [list Folder_TargetCopy $f]
    $canvas bind $id <Control-$fdisp(tarbutton)> \
		    [list Folder_TargetClear $f]


    if {[string compare $ftype goParent] == 0} {
	$canvas bind $id <$fdisp(navbutton)> \
	    [list FdispMain [file dirname $f]]
    } else {
	if {[string compare $ftype hasNested] == 0} {
	    if {$can != "cache"} {
		case $fdisp(popdownAction) {
		    redisplay {
			$canvas bind $id <$fdisp(navbutton)> \
			    [list FdispMain $f]
		    }
		    enter {
			$canvas bind $id <Any-Enter> \
			    [list FdispDisplayPopdown $f down %x %y]
		    }
		    navbutton {
			$canvas bind $id <$fdisp(navbutton)> \
			    [list FdispDisplayPopdown $f down %x %y]
		    }
		}
	    } else {
		if {$fdisp(popdownAction) == "redisplay"} {
		    $canvas bind $id <$fdisp(navbutton)> \
			    [list FdispMain $f]
		}
	    }
	} else {
	    # Leaf
	    if {$fdisp(popdownAction) == "redisplay"} {
		$canvas bind $id <$fdisp(navbutton)> {}
	    } else {
		if {$fdisp(popdownRemove) == "navbutton"} {
		    $canvas bind $id <$fdisp(navbutton)> FdispPopdownRemove
		} else {
		    # Use enter on another leaf label to simulate Leave
		    # of the popdown.  Cannot bind to <Leave> on the popdown
		    # background because that triggers when you enter one
		    # of its own labels.
		    $canvas bind $id <Enter> FdispPopdownRemove
		}
	    }
	}
    }
}
proc FdispSetCanvasSize { can maxy {noshrink 0}} {
    global fdisp

    set canvas $fdisp($can)
    set w $fdisp(width,$can)

    set height [winfo height $canvas]
    set bd [$canvas cget -borderwidth]
    incr bd [$canvas cget -highlightthickness]
    set height [expr $height - 2*$bd]

    set h [expr $maxy + $fdisp(ygap) + $fdisp(ygap)]
    if {$height > $h} {set h $height}

    #puts "SetSize $maxy->$h [lindex [$canvas cget -scrollregion] 3]"

    if {$noshrink && [lindex [$canvas cget -scrollregion] 3] > $h} {
	return
    }

    $canvas configure -scrollregion [list 0 0 $w $h]
    # adjust background to cover new scrollregion
    $canvas coords $fdisp(bgid,$can) 0 0 $w $h
}

proc FdispUpdateMap { can folder id } {
    global fdisp
    $fdisp($can) addtag Ftext=$folder withtag $id
}
proc FdispUpdateBmap { can folder box } {
    global fdisp
    $fdisp($can) addtag Fbox=$folder withtag $box
}
proc FdispGetMap { can folder } {
    global fdisp
    return [$fdisp($can) find withtag Ftext=$folder]
}
proc FdispGetBmap { can folder } {
    global fdisp
    return [$fdisp($can) find withtag Fbox=$folder]
}
# Routines to Highlight the folder display

proc Fdisp_ResetHighlights {} {
    global fdisp
    Fdisp_ClearHighlights
    Fdisp_HighlightCanvas canvas
    if [info exists fdisp(cache)] {
	Fdisp_HighlightCanvas cache
    }
}
proc Fdisp_ClearHighlights {} {
    global fdisp
    FdispClearHighlights canvas
    if [info exists fdisp(cache)] {
	FdispClearHighlights cache
    }
}

proc Fdisp_HighlightCanvas { can } {
    global fdisp flist
    if ![info exist fdisp($can)] {
	return
    }
    if {$fdisp(cur,$can) != {}} {
	FdispHighlightCur $can $fdisp(cur,$can)
    }
    if {$fdisp(tar,$can) != {}} {
	FdispHighlightTarget $can $fdisp(tar,$can)
    }
    foreach f [Flist_UnseenFolders] {
	FdispHighlightUnseen $can $f
    }
    Fdisp_LabelConfigure $fdisp($can)
}

proc FdispWhichLabel { can f } {
    # Figure out what label to highlight, handling nesting
    global fdisp mhProfile

    if {"$can" == "cache" || [FdispNotDotDot $can $f]} {
	return $f
    }
    while {[string compare $f "."] && [string compare $f "/"]} {
	set nf [file dirname $f]
	if {[string compare $nf $f] == 0} {
	    break
	}
	set f $nf
	if [FdispNotDotDot $can $f] {
	    return $f
	}
    }
    return {}
}
proc FdispAllLabels { can f } {
    # Figure out what labels to highlight, returning
    # multiple labels if they are present because of popdowns.
    global fdisp mhProfile

    set res {}
    if [FdispNotDotDot $can $f] {
	lappend res $f
    }
    while {[string compare $f "."] && [string compare $f "/"]} {
	set nf [file dirname $f]
	if {[string compare $nf $f] == 0} {
	    break
	}
	set f $nf
	if [FdispNotDotDot $can $f] {
	    lappend res $f
	}
    }
    return $res
}
# See if the folder label displayed for $f is ".." (and is displayed at all)
proc FdispNotDotDot { can f } {
    global fdisp
    set map [FdispGetMap $can $f]
    if {$map != {}} {
	if [catch {$fdisp($can) itemcget $map -text} l] {
	    if [string compare $f ".."] {
		return 1
	    }
	} else {
	    if [string compare $l ".."] {
		return 1
	    }
	}
    }
    return 0
}
proc Fdisp_HighlightCur { f } {
    global fdisp

    Fcache_Folder $f
    foreach can {canvas cache} {
	if [info exists fdisp($can)] {
	    FdispHighlightCur $can $f
	    Fdisp_LabelConfigure $fdisp($can)
	}
    }
}
proc FdispHighlightCur { can f } {
    global fdisp
    set l [FdispWhichLabel $can $f]
    set canvas $fdisp($can)
    if {$fdisp(curid,$can) != {}} {
	$canvas dtag $fdisp(curid,$can) cur[$canvas type $fdisp(curid,$can)]
	$canvas dtag $fdisp(boxid,$can) curbox
    }

    set fdisp(cur,$can) $f
    if {[string compare $l {}]} {
	set id [FdispGetMap $can $l]
	set box [FdispGetBmap $can $l]
	$canvas addtag cur[$canvas type $id] withtag $id
	$canvas addtag curbox withtag $box
	set fdisp(curid,$can) $id
	set fdisp(boxid,$can) $box
    }
}
proc Fdisp_HighlightTarget { f } {
    global fdisp fcache

    if $fcache(cacheTarget) {
       Fcache_Folder $f
    }
    foreach can {canvas cache} {
	if [info exists fdisp($can)] {
	    FdispHighlightTarget $can $f
	    Fdisp_LabelConfigure $fdisp($can)
	}
    }
}
proc FdispHighlightTarget { can f } {
    global fdisp
    set l [FdispWhichLabel $can $f]
    set canvas $fdisp($can)
    if {$fdisp(tarid,$can) != {}} {
	$canvas dtag $fdisp(tarid,$can) tar[$canvas type $fdisp(tarid,$can)]
	$canvas dtag $fdisp(tboxid,$can) tarbox
    }

    set fdisp(tar,$can) $f
    if {[string compare $l {}]} {
	set id [FdispGetMap $can $l]
	set box [FdispGetBmap $can $l]
	$canvas addtag tar[$canvas type $id] withtag $id
	$canvas addtag tarbox withtag $box
	set fdisp(tarid,$can) $id
	set fdisp(tboxid,$can) $box
    }
}

proc Fdisp_HighlightUnseen { f } {
    global fdisp fcache

    if $fcache(cacheUnseen) {
       Fcache_Folder $f
    }
    foreach can {canvas cache} {
	if [info exists fdisp($can)] {
	    FdispHighlightUnseen $can $f
	    Fdisp_LabelConfigure $fdisp($can)
	}
    }
}
proc FdispHighlightUnseen { can f } {
    global exmh fdisp
    if {$can != "cache"} {
	set ll [FdispAllLabels $can $f]
    } else {
	set ll [list $f]
    }
    set canvas $fdisp($can)
    foreach l $ll {
	set id [FdispGetMap $can $l]
	set box [FdispGetBmap $can $l]
	$canvas addtag leaf=$f withtag $id
	if {[lsearch $fdisp(leafs,$can) leaf=$f] < 0} {
	    # needed when resetting highlights
	    lappend fdisp(leafs,$can) leaf=$f
	}
	$canvas addtag unsn[$canvas type $id] withtag $id
	$canvas addtag unsnbox withtag $box
    }
}
proc Fdisp_UnHighlightUnseen { f } {
    global fdisp
    foreach can {canvas cache} {
	if [info exists fdisp($can)] {
	    FdispUnHighlightUnseen $fdisp($can) $can $f
	    Fdisp_LabelConfigure $fdisp($can)
	}
    }
}
proc FdispUnHighlightUnseen { canvas can f } {
    global exmh fdisp
    set ll [FdispAllLabels $can $f]
    set canvas $fdisp($can)
    foreach l $ll {
	set id [FdispGetMap $can $l]
	set box [FdispGetBmap $can $l]
	set stillLight 0
	foreach tag [$canvas gettags $id] {
	    if [string match leaf=* $tag] {
		set leaf [lindex [split $tag =] 1]
		if {[string compare $leaf $f] == 0} {
		    $canvas dtag $id $tag
		} else {
		    set stillLight 1
		}
	    }
	}
	if {! $stillLight} {
	    $canvas dtag $id unsn[$canvas type $id]
	    $canvas dtag $box unsnbox
	}
    }
}
proc Fdisp_Lines { canvas labels } {
    # Return the number of lines needed to display the set of labels
    global fdisp
    set x $fdisp(xgap)
    set lines 1
    set width [winfo width $canvas]
    set bd [$canvas cget -borderwidth]
    incr bd [$canvas cget -highlightthickness]
    set width [expr $width - 2*$bd]
    foreach folder $labels {
	set f [Fcache_FolderName $folder]
	set id [Fdisp_Label $canvas $f $f]
	set bbox [$canvas bbox $id]
	set twidth [expr [lindex $bbox 2]-[lindex $bbox 0]]
	if {$twidth + $fdisp(xgap)/2 + $x > $width} {
	    incr lines
	    set x $fdisp(xgap)
	}
	incr x [expr {$fdisp(xgap) + $twidth}]
	$canvas delete $id
    }
    return $lines
}

#
# Interface to Drag & Drop
#
set fdispDrag(callback) FdispDragRelease
set fdispDrag(types) {folder filename}
set fdispDrag(formats) string
set fdispDrag(format,folder) string
set fdispDrag(format,filename) string
set fdispDrag(type,string) folder
set fdispDrag(decorate) FdispDragWindow

proc FdispDragAttach {where} {
	global fdisp

	Drag_Attach $fdisp($where) FdispDragSelect Shift $fdisp(navbutton)
	if [string match cache $where] {
		Drop_Attach $fdisp(cache) FdispDropCache
	} else {
		Drop_Attach $fdisp(canvas) FdispDropCanvas
	}
}

# A drag was dropped on the cache
proc FdispDropCache {w args} {
	global dragging

	if ![info exists dragging(data,folder)] return
	set folder $dragging(data,folder)

	# Add the folder to the cache
	Fcache_Folder $folder
}

# A drag was dropped on the canvas
proc FdispDropCanvas {w args} {
	global fdisp dragging

	if ![info exists dragging(data,folder)] return
	set folder $dragging(data,folder)

	# If dropped on the folder display and source was cache,
	# remove the folder from the cache
	if {[info exists fdisp(cache)] && 
	    $dragging(source) == $fdisp(cache)} {
		Fcache_FolderDiscard $folder
	}
}

# Called when after a drag we sourced has been dropped
proc FdispDragRelease {dstw args} {

	global fdisp dragging
	set folder $dragging(data,folder)

tlog-add .t "released on $dstw"

	# If we tossed it somewhere unknown, Add the folder to the cache
	if {$dragging(source) == $fdisp(canvas) && $dstw != $fdisp(canvas) &&
	    "$dstw" != {}} {
		Fcache_Folder $folder
	}
}

# Drag Selected
proc FdispDragSelect {c x y wx wy} {
	global fdisp

	set closest [$c find closest [$c canvasy $wx] [$c canvasy $wy]]

	# Find what folder we're over
	set tags [$c gettags $closest]
	set which [lsearch -glob $tags F*=*]
	if {$which >= 0} {
		set tag [lindex $tags $which]
		regsub -- .*=(.*) $tag {\1} folder
	}
	if ![info exists folder] return

	# Hand off to Drag code
	global fdispDrag mhProfile
	set fdispDrag(source) $c
	set fdispDrag(data,folder) $folder
	set fdispDrag(data,filename) $mhProfile(path)/$folder

	Drag_Source fdispDrag $x $y

}

# How do decorate the Drag window
proc FdispDragWindow {w} {
	global fdisp dragging

	set c $w.fdisp
	if ![winfo exists $c] {
		set height [expr $fdisp(itemHeight) + $fdisp(ygap)]
		canvas $c -height $height
	}

	pack $c
	catch {$c delete all}

	set f $dragging(data,folder)

	set id [Fdisp_Label $c $f $f]
	set bbox [$c bbox $id]
	set twidth [expr [lindex $bbox 2]-[lindex $bbox 0]]
	set theight [expr [lindex $bbox 3]-[lindex $bbox 1]]
	$c move $id [expr $fdisp(xgap)/2 + 1] [expr $fdisp(ygap)/2]
	set width [expr $twidth + $fdisp(xgap)]
	$c config -width $width
	set bid [Fdisp_Box $c $id leaf {}]
}
