#
# fdispPopup.tcl
#
# Nested folder popup (or popdown) display.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

# Reset notion of displayed popdowns when canvas is init'd or destroyed
proc FdispPopdownReset {} {
    global fdisp
    set fdisp(poptop) -1
}
# Remove all displayed popdowns
proc FdispPopdownRemove {} {
    FdispDisplayPopdown "" remove
}
proc FdispDisplayPopdown {folder pop {bx -1} {by -1}} {
    global fdisp

    set can canvas	;# popdowns only on main display

    set folderSet [Flist_FolderSet $folder]
    set canvas $fdisp($can)
    set width [winfo width $canvas]

    if ![info exists fdisp(maxy,canvas)] {
	return	;# display not initialized yet
    }
    case $fdisp(popdownStyle) in {
	{r*}	{set style 1}
	default	{set style 0}
    }
    set tag T_$folder

    Exmh_Debug FdispDisplayPopdown $folder $pop top=$fdisp(poptop) $tag
    if {($pop == "down") && ($fdisp(poptop) != -1)} {
	if {$fdisp(popdown,0) == $tag} {
	    # Clicking on a folder with popup already displayed.
	    set pop "remove"
	}
    }
    if {($pop == "stack") && ($fdisp(popdown,$fdisp(poptop)) == $tag) &&
	($fdisp(popdownAction) == "navbutton")} {
	Exmh_Debug Remove leaf $tag
	$canvas lower $fdisp(popdown,$fdisp(poptop))
	incr fdisp(poptop) -1
	return
    }

    if {$pop == "stack"} {
	if {$fdisp(popdownAction) == "navbutton"} {
	    set hit 0
	    for {set i 0} {$i <= $fdisp(poptop)} {incr i} {
		if {$fdisp(popdown,$i) == $tag} {
		    set hit 1	;# Already visible.  Decide what to nuke.
		}
	    }
	    if {$hit} {
		for {set i $fdisp(poptop)} {$i >= 0} {incr i -1} {
		    Exmh_Debug remove popdown $fdisp(popdown,$i)
		    $canvas lower $fdisp(popdown,$i)
		    incr fdisp(poptop) -1
		    if {$fdisp(popdown,$i) == $tag} {
			return
		    }
		}
	    }
	}
	if {$fdisp(popdown,$fdisp(poptop)) == $tag} {
	    Exmh_Debug "Reuse top of stack $tag"
	    FdispPopupView $canvas $tag
	    return
	}
	for {set i 0} {$i <= $fdisp(poptop)} { incr i} {
	    if {$fdisp(popdown,$i) == $tag} {
		Exmh_Debug popdown already visible $tag
		FdispPopupView $canvas $tag
		return
	    }
	}
	incr fdisp(poptop)
    } else {
	for {set i $fdisp(poptop)} {$i >= 0} {incr i -1} {
	    Exmh_Debug remove popdown $fdisp(popdown,$i)
	    $canvas lower $fdisp(popdown,$i)
	}
	if {$pop == "remove"} {
	    FdispPopupResetView $can
	    set fdisp(poptop) -1
	    return
	}
	set fdisp(poptop) 0
    }

    if {[$canvas gettag $tag] != ""} {
	set fdisp(popdown,$fdisp(poptop)) $tag
	Exmh_Debug reuse popdown $tag
	$canvas raise $tag
	FdispPopupView $canvas $tag
	return
    }

    Exmh_Status "Building popdown display for $folder"

    set bid [FdispGetBmap $can $folder]
    if {$bid == ""} {
	set id [$canvas find closest $bx $by]
	Exmh_Debug CLOSEST: x=$bx y=$by is id=$id [$canvas type $id]

	if {[$canvas type $id] == "text"} {
	    set bid [$canvas find below $id]
	    Exmh_Debug bid=$bid [$canvas type $bid] @ [$canvas coo $bid]
	} else {
	    set bid $id
	}
    }

    set bbox [$canvas coords $bid]
    if {[string length $bbox] == 0} {
	Exmh_Status "No coords for box <$bid>" error
	return
    }

    # compute bounding coords of anchoring folder name/bitmap
    #    bx1,by1
    #       +-----------+
    #	    |folder name|
    #       +-----------+
    #		     bx2,by2

    set bx1 [lindex $bbox 0]
    set bx2 [lindex $bbox 2]
    set by1 [lindex $bbox 1]
    set by2 [lindex $bbox 3]

    # layout subfolder display
    #	will be centered around anchor with a width equal to 3/4 of canvas
    FdispLayoutInner $can 0 0 [expr ($width*3/4)] $folderSet $folder \
		FdispBindPopupLabel skipSelf $tag

    # compute bounding coords of subfolder display
    #	wid = width, hei = height
    #	lx = left x, rx = right x
    # lx/rx are adjusted to fit within width of canvas (wid is not updated)

    if [catch {
	set bbox1 $bbox
	set bbox [$canvas bbox $tag]
	set hei [expr $fdisp(ygap)/2 + [lindex $bbox 3] - [lindex $bbox 1]]
	set wid [expr $fdisp(xgap)/4 + [lindex $bbox 2] - [lindex $bbox 0]]
	set wid [expr {$wid - $bx2 + $bx1}]

	set lx [expr $bx1-$wid/2]
	set rx [expr $bx2+4+$wid/2]
    } err] {
	global errorInfo ; set savedInfo $errorInfo
	catch {set wid} w
	error $err "Bbox1=($bbox1) Bbox2=($bbox) wid=$w bx1=$bx1 bx2=$bx2\n$savedInfo"
    }
    if {$lx < 3} {
	set rx [expr {$rx - $lx + 3}]
	set lx 3
    }
    if {$rx > $width - 4} {
	set lx [expr {$width + $lx - $rx - 4}]
	set rx [expr $width-4]
    }

    if {$style} {
	set gap 4

	# Add a square decoration around subfolder display
	#
	#    bx1,by1
	#       +-----------+
	#       |folder name|
	#       +-----------+ bx2,by2         +
	# rx1,ry1                             | gap
	#    +-----------------+              +
	#    |subfolder display|
	#    +-----------------+ rx2,ry2

	set rx1 $lx
	set ry1 [expr $by2+$gap]
	set rx2 $rx
	set ry2 [expr {$ry1 + $fdisp(ygap)/4+$hei}]

	set loweredge [expr {$ry2 + 4}]

	set box [$canvas create rect $rx1 $ry1 $rx2 $ry2 -fill $fdisp(c_popup)]

	$canvas move $tag [expr {$rx1 + $fdisp(xgap)*3/4}] \
			[expr {$ry1 + $fdisp(ygap)/2}]
	$canvas raise $tag $box

	$canvas addtag $tag withtag $box
    } else {
	set gap 14

	# Add a trapezoidal decoration around subfolder display
	#
	#    bx1,by1
	#       +-----------+
	#       |folder name|
	#       +-----------+ bx2,by2         + +
	# px1,py1                             | | 2 pixels
	#       +-----------+ px2,py2         | +
	#      /             \                |
	#     /               \               | gap
	#    +px6,py6          + px3,py3      +
	#    |subfolder display|
	#    +-----------------+ px4,py4
	# px5,py5

	set px1 $bx1
	# +2 makes us overlap the lower black border
	set py1 [expr $by2+2]
	set px2 [expr $bx2+4]
	set py2 $py1
	set px3 $rx
	set py3 [expr $by2+$gap]
	set px4 $px3
	set py4 [expr {$py3 + $fdisp(ygap)/4+$hei}]
	set px5 $lx
	set py5 $py4
	set px6 $px5
	set py6 $py3

	set loweredge [expr {$py4 + 4}]

	set border [$canvas create poly $px1 $py1 $px2 $py2 \
			$px3 $py3 $px4 $py4 \
			$px5 $py5 $px6 $py6 -fill $fdisp(c_fg)]

	set box [$canvas create poly [expr $px1+1] [expr $py1+1] \
			[expr $px2-1] [expr $py2+1] \
			[expr $px3-1] [expr $py3+1] \
			[expr $px4-1] [expr $py4-1] \
			[expr $px5+1] [expr $py5-1] \
			[expr $px6+1] [expr $py6+1] \
			-fill $fdisp(c_popup)]

	$canvas move $tag [expr {$px6 + $fdisp(xgap)*3/4}] \
			[expr {$py6 + $fdisp(ygap)/2}]
	$canvas raise $tag $box

	# add a dividing line
	# (should just change above poly to be a poly and a rect)
	# set line [$canvas create line $px6 $py6 $px3 $py6]
	# $canvas raise $line
	# $canvas addtag $tag withtag $line

	$canvas addtag $tag withtag $border
	$canvas addtag $tag withtag $box
    }
    # Cannot bind to <Leave> because that triggers when you enter a label.
    $canvas bind $box <Double-$fdisp(navbutton)> \
	[list FdispDisplayPopdown {} remove]

    FdispSetCanvasSize $can $loweredge 1

    Exmh_Status ""
    set fdisp(popdown,$fdisp(poptop)) $tag
    FdispPopupView $canvas $tag
    # Highlight newly created labels
    Fdisp_HighlightCanvas canvas
}
proc FdispBindPopupLabel { can id ftype f } {
    global fdisp
    set canvas $fdisp($can)
    if {[string compare $ftype hasNested] == 0} {
	# This label has nested folders
	case $fdisp(popdownAction) {
	    redisplay {
		$canvas bind $id <$fdisp(navbutton)> \
		    [list FdispMain $f]
	    }
	    enter {
		$canvas bind $id <Any-Enter> \
		    [list FdispDisplayPopdown $f stack %x %y]
	    }
	    navbutton {
		$canvas bind $id <$fdisp(navbutton)> \
		    [list FdispDisplayPopdown $f stack %x %y]
	    }
	}
    }
    $canvas bind $id <$fdisp(curbutton)> [list Folder_Change $f]

    if {$fdisp(tarbuttonAction) == "select+move"} {
        $canvas bind $id <$fdisp(tarbutton)> \
                [list Folder_TargetMove $f]
    } elseif {$fdisp(tarbuttonAction) == "select+copy"} {
        $canvas bind $id <Shift-$fdisp(tarbutton)> \
                [list Folder_TargetCopy $f]
    } elseif {$fdisp(tarbuttonAction) == "select only"} {
        $canvas bind $id <$fdisp(tarbutton)> \
                [list Folder_Target $f]
    } else {
        $canvas bind $id <$fdisp(tarbutton)> \
                [list Folder_TargetMove $f]
    }
    $canvas bind $id <Shift-$fdisp(tarbutton)> 	[list Folder_TargetCopy $f]
    $canvas bind $id <Control-$fdisp(tarbutton)> \
		    [list Folder_TargetClear]
}
proc FdispPopupResetView { can } {
    global fdisp
    set canvas $fdisp($can)
    if {$fdisp(popdownRemove) == "navbutton" || \
        [$canvas canvasy 0] > $fdisp(maxy,$can)} {
	    $canvas yview moveto 0.
    }
}
proc FdispPopupView { canvas tag } {
    $canvas raise $tag
    set h [lindex [$canvas configure -height] 4]
    if [catch {$canvas cget -yscrollincrement} inc] {
	set inc [expr [$canvas cget -height]/10]
    }
    set ybot [$canvas canvasy $h]
    set bbox [$canvas bbox $tag]
    set popbot [lindex $bbox 3]
    if {$popbot <= $ybot} {return}

    # Bottom edge clipped
    set moveup [expr $popbot-$ybot]

    set ytop [$canvas canvasy 0]
    set poptop [lindex $bbox 1]
    set room [expr $poptop-$ytop]
    set moveup [expr {($moveup > $room || $poptop == $inc+1) ? $room-2*$inc : $moveup}]
    $canvas yview scroll [expr int($moveup/$inc)] units
}
