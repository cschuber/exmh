# exwin.tcl
#
# Main window layout for the application
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Exwin_Init {} {
    global exwin
    Preferences_Resource exwin(mtextLines) mtextLines 25
    Preferences_Add "Windows & Scrolling" \
"Window placement and scroll-related preferences are set here.
Contrained scrolling keeps the last line of text in a window stuck
to the bottom of the window.  This can be set independently for
the scan listing (FTOC)." {
	{exwin(scrollbarSide) scrollbarSide {CHOICE left right} {Vertical Scrollbar Side}
"Which side the vertical scrollbars appear on.  This
only takes effect after you restart exmh."}
	{exwin(hscrollbarSide) hscrollbarSide {CHOICE none top bottom} {Horizontal Scrollbar Side}
"Which side the horizontal scrollbars appear on.  This
only takes effect after you restart exmh."}
	{exwin(scrollSpeed) scrollSpeed 1 {Drag-Scroll speed}
"How fast things scroll when you drag a text widget
around with the (by default) middle button."}
	{exwin(scrollAccel) scrollAccel 4 {Drag-Scroll acceleration}
"How fast things scroll when you drag a text widget
around with the (by default) middle button with Shift depressed."}
  	{exwin(wheelEnabled) wheelEnabled OFF "Wheel Mouse"
"Enables the use of wheel mice, assuming proper
X Server support (ie, button 4 + 5)
You must restart exmh for this option to take effect."}
    {widgetText(constrained) textConstrainScroll OFF "Constrained Scrolling"
"Constrained scrolling clamps the last line
of text to the bottom of the text widget."} 
    {widgetText(constrainFtoc) textConstrainFtoc ON "Constrain FTOC"
"In spite of the general constrained text setting,
constrain the scrolling of the folder table-of-contents."}
    {widgetText(scrollContext) textContextLines 2 "Scroll Context"
"Scroll context is the number of lines that pages
overlap when paging up and down through text."}
    {widgetText(smoothScroll) textSmoothScroll ON "Smooth-scroll ends"
"If set, the last partial page is scrolled line-by-line instead
of jumping to the new location.  This helps you maintain context."}
    {widgetText(selectDelay) textSelectDelay 50 "Scroll/Select Time Constant"
"When you drag a selection off the top or bottom of a text widget,
the widget automatically scrolls and extends the selection.  This
parameter is a polling time period that affects the behavior.  Too
big and it is not responsive enough.  Too small and it may consume too
many cycles.  Units are milliseconds."}
    {widgetText(autoNext) textAutoNext ON "Scroll into the next message"
"If on, hitting spacebar (or your scroll down key) on the last page
of a message automatically advances you to the next message, as if
you had hit the Next button. If off, you must always explicitly
advance via appropriate exmh commands or buttons, making it safe to
just hit space repeatedly until things stop scrolling to skim a
message."}
	{exwin(placeToplevel)	placeToplevel ON	{Remember window placement}
"With this enabled, exmh will remember the placement of the various
popup windows between sessions.  This means you can position them
once manually and they will always appear there.  However, if you
use a virtual root window manager and run exmh in different \"rooms\"
then a remembered placement might be in the wrong room.  You can nuke
all the placement memory from the end of the .exmh-defaults file and
always run exmh from the same room, or just disable this feature."}
    {exwin(keepPlaces) keepPlaces ON {Remember within session}
"With this enabled, exmh will remember window placements within a
session.  This means that even if \"Remember window placement\" is
OFF, if you place a window and dismiss it, exmh will remember its
placement and re-use it for the rest of the current session.
Disabling this option always allows your window manager to place
windows."}
    }
    set exwin(ftextLinesSave) $exwin(ftextLines)
    trace variable exwin(ftextLines) w ExwinFixupFtextLines
#    trace variable exwin(mtextLines) w ExwinFixupMtextLines

    if {$exwin(wheelEnabled)} {
	mscroll TScroll 5
    }

    if ![info exists exwin(toplevels)] {
	set exwin(toplevels) [option get . exwinPaths {}]
    }
}

proc mscroll {bindtag num} {
    bind $bindtag <Button-5> [list %W yview scroll $num units]
    bind $bindtag <Button-4> [list %W yview scroll -$num units]
    bind $bindtag <Shift-Button-5> [list %W yview scroll 1 units]
    bind $bindtag <Shift-Button-4> [list %W yview scroll -1 units]
    bind $bindtag <Control-Button-5> [list %W yview scroll 1 pages]
    bind $bindtag <Control-Button-4> [list %W yview scroll -1 pages]
}


proc ExwinFixupFtextLines { args } {
    global exwin
    Exmh_Debug ExwinFixupFtextLines $exwin(ftextLines)
    if [catch {
	$exwin(ftext) configure -height $exwin(ftextLines)
	set exwin(ftextLinesSave) $exwin(ftextLines)
    } err] {
	Exmh_Status $err
	set exwin(ftextLines) $exwin(ftextLinesSave)
	$exwin(ftext) configure -height $exwin(ftextLines)
    }
}
#proc ExwinFixupMtextLines { args } {
#    global exwin
#    Exmh_Debug ExwinFixupMtextLines $exwin(mtextLines)
#    $exwin(mtext) configure -height $exwin(mtextLines)
#}

proc Exwin_Layout {} {
    global exwin exmh

    set fixed {top fill}
    set expand {top fill expand}
    set exwin(grab) {}

    wm minsize . 100 100
    Flag_Init

    # Top row of buttons for global ops and version string
    set exwin(mainButtons) [Widget_Frame . main Main $fixed]
    Buttons_Main $exwin(mainButtons)
    Label_MainSetup $exwin(mainButtons)

    # Folders with unread messages
    Fdisp_Window [Widget_Frame . flist Fdisp $fixed]

    # Second row of buttons for folder ops and current folder label
    set exwin(fopButtons) [Widget_Frame . fops Fops $fixed]
    Buttons_Folder $exwin(fopButtons)
    Label_FolderSetup $exwin(fopButtons)

    # Folder display (Ftoc)
    set exwin(ftext) [Widget_Text [Widget_Frame . ftoc Ftoc $fixed] \
				$exwin(ftextLines)]
    Ftoc_Bindings $exwin(ftext)

    if {$exwin(wheelEnabled)} {
	mscroll $exwin(ftext) 1
    }

    # Frame for faces, status, message buttons
    set mid     [Widget_Frame . mid Mid $fixed]
    Widget_SplitFrameR $mid Face Right
    Faces_Create $mid.left

    # Status line + MsgID
    set right $mid.right
    Widget_SplitFrameV $right Status Mops

    # FTOC/MSG boundary changer
    ExwinFtocMsgBoundary $right.top

    set exwin(status) [Widget_Entry $right.top msg {right expand fill}]
    set statusConfig [option get . statusConfig StatusConfig]
    if {[string length $statusConfig] > 0} {
        catch [concat $exwin(status) configure $statusConfig]
    }
    Label_MessageSetup $right.top
    # Status line does double-duty for folder/msg selection typein
    Select_EntryBind $exwin(status)

    # Buttons for message ops, plus display of current message id
    set exwin(mopButtons) $right.bot
    Buttons_Message $exwin(mopButtons)

    # Message display
    set exwin(mtext) [Widget_Text [Widget_Frame . msg Msg $expand] \
				$exwin(mtextLines)]
    Msg_Setup $exwin(mtext)
    Bindings_Main $exwin(mtext)

    focus $exwin(mtext)
}
proc ExwinFtocMsgBoundary {frame} {
    global exwin
    set c [canvas $frame.boundary -width 16 -height 15]
    pack $frame.boundary -side right -fill y
    set fg [option get . c_foreground {}]
    set it [$c create poly 8 2  15 9  8 16  1 9 -fill $fg]
    $c bind $it <ButtonPress-1> {ExwinFtocMsgScroll %W %x %y}
    $c bind $it <B1-Motion> {ExwinFtocMsgMove %W %x %y}
    $c bind $it <ButtonRelease-1> {ExwinFtocMsgStop %W %x %y}
    set exwin(mode) {}
}
proc ExwinTopY {w y} {
    # Find Y hit relative to toplevel window
    set top [winfo toplevel $w]
    while {[string compare $w $top] != 0} {
	incr y [winfo y $w]
	set w [winfo parent $w]
    }
    return $y
}
proc ExwinFtocMsgScroll {canvas x y} {
    global exwin
    set top [winfo toplevel $canvas]
    if {$top == "."} {
	set exwin(boundary) .boundary
    } else {
	set exwin(boundary) $top.boundary
    }
    set bg [option get . c_foreground {}]
    frame $exwin(boundary) -width [winfo width $top] -height 2 -bg $bg
    place $exwin(boundary) -y [ExwinTopY $canvas $y] -x 0 -anchor w
    global fdisp
    Exmh_Status "Adjust FTOC (and other) subwindow boundaries"

    # Record Y coordinate of bottom of each subwindow
    set exwin(yftoc) [ExwinTopY $exwin(ftext) [winfo height $exwin(ftext)]]
    if [info exists fdisp(cache)] {
	set exwin(yfcache) \
	    [ExwinTopY $fdisp(cache) [winfo height $fdisp(cache)]]
    } else {
	catch {unset exwin(yfcache)}
    }
    if {!$fdisp(toplevel)} {
	set exwin(yfdisp) \
	    [ExwinTopY $fdisp(canvas) [winfo height $fdisp(canvas)]]
    } else {
	catch {unset exwin(yfdisp)}
    }
    set exwin(mode) ftoc
}
proc ExwinFtocMsgMove {canvas x y} {
    global exwin
    set ytop [ExwinTopY $canvas $y]
    place $exwin(boundary) -y $ytop
    switch $exwin(mode) {
	ftoc {
	    if {[info exists exwin(yfcache)] &&
		$ytop <= $exwin(yfcache)} {	# Above FTOC window
		set exwin(mode) fcache
		Exmh_Status "Adjust Folder Cache boundary"
	    } elseif {[info exists exwin(yfdisp)] &&
		$ytop <= $exwin(yfdisp)} {	# Above Fcache window
		set exwin(mode) fdisp
		Exmh_Status "Adjust Folder Display boundary"
	    }
	}
	fcache {
	    if {[info exists exwin(yfdisp)] &&
		$ytop <= $exwin(yfdisp)} {	# Above Fcache window
		set exwin(mode) fdisp
		Exmh_Status "Adjust Folder Display boundary"
	    }
	    if {$ytop >= $exwin(yftoc)} { # Below FTOC window
		set exwin(mode) ftoc
		Exmh_Status "Adjust FTOC boundary"
	    }
	}
	fdisp {
	    if {[info exists exwin(yfcache)] &&
		$ytop >= $exwin(yfcache)} {	# Below Fcache window
		set exwin(mode) fcache
		Exmh_Status "Adjust Folder Cache boundary"
	    } elseif {$ytop >= $exwin(yftoc)} { # Below FTOC window
		set exwin(mode) ftoc
		Exmh_Status "Adjust FTOC boundary"
	    }
	}
    }
}
proc ExwinFtocMsgStop {canvas x y} {
    global exwin fdisp
    catch {destroy $exwin(boundary)}
    # Deduce height of text line in FTOC
    if ![info exists exwin(ftocLineHeight)] {
	if [catch {ExwinLineHeight $exwin(ftext)} x] {
	    Exmh_Status "Display a message before resizing" warn
	    return
	}
	set exwin(ftocLineHeight) $x
    }
    switch $exwin(mode) {
	ftoc {
	    set dy [expr [ExwinTopY $canvas $y] - $exwin(yftoc)]
	    set chunk $exwin(ftocLineHeight)
	}
	fcache {
	    set dy [expr [ExwinTopY $canvas $y] - $exwin(yfcache)]
	    set chunk [expr $fdisp(itemHeight) + $fdisp(ygap)]
	}
	fdisp {
	    set dy [expr [ExwinTopY $canvas $y] - $exwin(yfdisp)]
	    set chunk [expr $fdisp(itemHeight) + $fdisp(ygap)]
	}
    }
    Exmh_Debug "dy $dy chunk $chunk"
    set dl [expr int(round($dy / double($chunk)))]
    if {$dl != 0} {
	# The exwin(ftextLines) and fdisp(maxLines) are traced so
	# the display updates when they change.
	switch $exwin(mode) {
	    ftoc {
		set x [expr $exwin(ftextLines) + $dl]
		if {$x <= 0} {set x 1}
		set exwin(ftextLines) $x
		set msg "Saving preference: $exwin(ftextLines) FTOC lines"
		set var exwin(ftextLines)
	    }
	    fcache {
		global fcache
		set x [expr $fcache(lines) + $dl]
		if {$x <= 0} {set x 1}
		set fcache(lines) $x
		set msg "Saving preference: $fcache(lines) Folder Cache lines"
		set var fcache(lines)
	    }
	    fdisp {
		set x [expr $fdisp(maxLines) + $dl]
		if {$x <= 0} {set x 1}
		set fdisp(maxLines) $x
		set msg "Saving preference: $fdisp(maxLines) Folder Display lines"
		set var fdisp(maxLines)
	    }
	}
	# Let redisplay kick in
	after 100 "
	    Exmh_Status \"$msg...\"
	    Preferences_Tweak $var
	    Exmh_Status \"$msg...ok\"
	"
    } else {
	Exmh_Status ok
    }
}
proc ExwinLineHeight {w} {
    set i 0
    if {[scan [$w index @0,$i] %d top] != 1} {
	error ExwinLineHeight
    }
    set limit [winfo height $w]
    while {$i < $limit} {
	incr i
	scan [$w index @0,$i] %d next
	if {$next != $top} {
	    return $i
	}
    }
    error "Cannot handle empty windows"
}
proc Exwin_FullFtoc {} {
    global exwin
    if ![info exists exwin(fullFtoc)] {
	set exwin(fullFtoc) notFullScreen
    }
    if {$exwin(fullFtoc) == "notFullScreen"} {
	set exwin(fullFtoc) fullScreen
	set exwin(ftocPack) [pack newinfo .msg]
	pack forget .msg
	$exwin(ftext) configure -height \
		[expr $exwin(ftextLines)+$exwin(mtextLines)]
    } else {
	set exwin(fullFtoc) notFullScreen
	$exwin(ftext) configure -height $exwin(ftextLines)
	eval pack .msg $exwin(ftocPack)
    }
}

proc Exwin_IconPosition { w icon } {
    if {[string length $icon] == 0} {
	return	;# Don't mess
    }
    # icon looks like +x+y, or -x-y, etc.
    set x 0 ; set y 0
    if {[llength $icon] == 1} {
	if [regexp {([\+-])([0-9]+)([\+-])([0-9]+)} $icon match s1 x s2 y] {
	    if {$s1 == "-"} {
		set x -$x
	    }
	    if {$s2 == "-"} {
		set y -$y
	    }
	}
    } else {
	set x [lindex $icon 0]
	set y [lindex $icon 1]
    }
    if {($x < 0) || ([string compare $x "-0"] == 0)} {
	# 48 depends on icon width
	set x [expr [winfo screenwidth $w]+$x-48]
    }
    if {($y < 0) || ([string compare $y "-0"] == 0)} {
	# 64 depends on icon height
	set y [expr [winfo screenheight $w]+$y-64]
    }
    if [catch {wm iconposition $w $x $y} err] {
	puts stderr "wm iconposition $w $x $y: $err"
    }
}

proc Exwin_Toplevel { path name {class Dialog} {dismiss yes}} {
    global exwin
    if [catch {wm state $path} state] {
	set t [Widget_Toplevel $path $name $class]
	if ![info exists exwin(toplevels)] {
	    set exwin(toplevels) [option get . exwinPaths {}]
	}
	set ix [lsearch $exwin(toplevels) $t]
	if {$ix < 0} {
	    lappend exwin(toplevels) $t
	}
	set decor [option get $path clientDecoration ClientDecoration]
	if {$decor == "none"} {
	    wm transient $path
	}
	if {$dismiss == "yes"} {
	    set f [Widget_Frame $t but Menubar {top fill}]
	    Widget_AddBut $f quit "Dismiss" [list Exwin_Dismiss $path]
	}
	return 1
    } else {
	if {$state != "normal"} {
	    catch {
		if {$exwin(keepPlaces)} {
		    wm geometry $path $exwin(geometry,$path)
		    wm positionfrom $path user
		} else {
		    wm geometry $path {}
		    wm positionfrom $path program
		}
		Exmh_Debug Exwin_Toplevel $path $exwin(geometry,$path)
	    }
	    wm deiconify $path
	} else {
	    catch {
		if {! $exwin(keepPlaces)} {
		    wm geometry $path {}
		    wm positionfrom $path program
		}
		raise $path
	    }
	}
	return 0
    }
}
proc Exwin_Dismiss { path {geo ok} } {
    global exwin
    case $geo {
	"ok" {
	    set exwin(geometry,$path) [wm geometry $path]
	}
	"nosize" {
	    set exwin(geometry,$path) [string trimleft [wm geometry $path] 0123456789x]
	}
	default {
	    catch {unset exwin(geometry,$path)}
	}
    }
    if [info exists exwin(geometry,$path)] {
	# Some window managers return geometry like
	# 80x24+-1152+10
	regsub -all {\+-} $exwin(geometry,$path) + exwin(geometry,$path)
    }
    Exmh_Focus    
    wm withdraw $path
    update idletasks	;# Helps window dismiss
}
proc Exwin_CheckPoint { } {
    global exwin
    if {! $exwin(placeToplevel)} {
	Preferences_RewriteSection "Saved Window Positions" "End Positions" {}
	return
    }
    set oldstuff [Preferences_ReadSection "Saved Window Positions" "End Positions"]
    set newstuff {}
    foreach path $exwin(toplevels) {
	set npath [string trimleft $path .]
	if [catch {wm state $path} state] {
	    # No widget - retrieve from old values, if possible
	    set geo {}
	    foreach item $oldstuff {
		if [regexp ^\\*$npath\\.position: $item] {
		    set geo [lindex $item 1]
		    break
		}
	    }
	} else {
	    case $state {
		"normal" {set geo [wm geometry $path]}
		default {
		    if [info exists exwin(geometry,$path)] {
			set geo $exwin(geometry,$path)
		    } else {
			set geo [option get $path position Position]
			if {$geo == {}} {
			    set geo [wm geometry $path]
			}
		    }
		}
	    }
	}
	if {[string length $geo] != 0} {
	    lappend newstuff [format "*%s.position:\t%s" $npath \
			[string trimleft $geo -x0123456789]]
	} else {
	    set ix [lsearch $exwin(toplevels) $path]
	    set exwin(toplevels) [lreplace $exwin(toplevels) $ix $ix]
	}
    }
    lappend newstuff [format "*exwinPaths:\t%s" $exwin(toplevels)]
    lappend newstuff [format "%s.geometry:\t%s" [winfo name .] [wm geometry .]]
    Fdisp_Checkpoint newstuff
    Preferences_RewriteSection "Saved Window Positions" "End Positions" $newstuff
}
proc Exwin_ClearCheckPoint {} {
    Preferences_RewriteSection "Saved Window Positions" "End Positions" {}
}
