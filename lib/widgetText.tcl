# widgetText.tcl
#
# Layer over the TK text widget that provides contrained scrolling
# and 1-to-1 draging.
#
# Based on code contributed by John Robert Loverso
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Widget_TextInit {} {
    # Preferences stuff moved to exwin.tcl
    # for the sake of the user interface.
}
proc Widget_TextInitText {t} {
    global widgetText		;# Constrained scrolling module
    set widgetText($t,geo) {}
    global TextType		;# Text bindings module
    set TextType($t) text
}
proc Widget_Text {frame height args} {
    # Create the text widget used to display messages
    global exwin
    if ![info exists exwin(scrollbarSide)] {
	set side right
    } else {
	set side $exwin(scrollbarSide)
    }
    if ![info exists exwin(hscrollbarSide)] {
	set hside none
    } else {
	set hside $exwin(hscrollbarSide)
    }
    if { $hside == "none" } {
        set cmd [list text $frame.t -relief raised -bd 2  \
		-yscroll [list WidgetScrollSet $frame.sv $frame.t]]
    } else {
	set cmd [list text $frame.t -relief raised -bd 2  \
		-yscroll [list WidgetScrollSet $frame.sv $frame.t] \
		-xscroll [list WidgetScrollSet $frame.sh $frame.t]]
    }
    if [catch [concat $cmd $args] t] {
	puts stderr "Widget_Text (warning) $t"
	set t [eval $cmd $args {-font fixed}]
    }
    if {[option get $frame.t width Width] == {}} {
	$frame.t configure -width 80
    }
    if {[option get $frame.t height Height] == {}} {
	$frame.t configure -height $height
    }
    scrollbar $frame.sv -command [list WidgetTextYview $t]

    if { $hside != "none" } {
	scrollbar $frame.sh -command "$frame.t xview" -orient horizontal
	pack append $frame $frame.sv [list $side filly] \
		$frame.sh [list $hside fillx] $t {expand fill}
    } else {
	pack append $frame $frame.sv [list $side filly] $t {expand fill}
    }

    $t mark set insert 0.0

    Widget_TextInitText $t	;# Init state variables

    if [regexp {setgrid} $args] {
	wm minsize [winfo toplevel $frame] 10 1
    }

    return $t
}
proc Widget_TextPageOrNext {t {implied implied}} {
    global widgetText
    set next 0
    set bottom [lindex [$t yview] 1]
    set next [expr $bottom >= 1]
    if {$next && $widgetText(autoNext) } {
	Ftoc_NextImplied show $implied
    } else {
	Widget_TextPageDown $t
    }
}
proc Widget_TextPageDown {t} {
    global widgetText
    WidgetTextYview $t scroll 1 pages
    $t mark set insert @1,1
}
proc Widget_TextPageUp {t} {
    global widgetText
    WidgetTextYview $t scroll -1 pages
    $t mark set insert @1,1
}
proc Widget_TextLineDown {t} {
    global widgetText
    $t yview scroll 1 units
}
proc Widget_TextLineUp {t} {
    global widgetText
    $t yview scroll -1 units
}
proc Widget_TextTop {t} {
    $t see 1.0
}
proc Widget_TextBottom {t} {
    $t see end
}
proc WidgetTextYview4.0 {w args} {
    global widgetText
    set dir [lindex $args 1]
    set op  [lindex $args 0]
    set units  [lindex $args 2]
    set view [$w yview]
    set next [expr 1 - [lindex $view 1]]
    set prev [lindex $view 0]
    set span [expr 1. - $next - $prev]
    if {!$widgetText(smoothScroll) ||
	($op != "scroll") ||
	($units != "pages") ||
        ($dir > 0 && $next >= $span) ||
        ($dir < 0 && $prev >= $span)} {
        eval $w yview $args
    } else {
        while {($dir > 0 && $next > 0) ||
                ($dir < 0 && $prev > 0)} {
            $w yview scroll [expr ($dir > 0) ? 2 : -2] unit
            update idletasks
            set view [$w yview]
            set next [expr 1 - [lindex $view 1]]
            set prev [lindex $view 0]
        }
    }
}
proc WidgetTextYview {t args} {
    global widgetText
    return [eval WidgetTextYview4.0 $t $args]
    if {!$widgetText(constrained) &&
	 !($widgetText(constrainFtoc) && [string match *.ftoc.* $t])} {
	eval {$t yview} $args
	return
    }
    set mark $args
    if {([llength $args] == 1) && ([scan $args %d line] == 1)} {
	if {[string compare $line $args] == 0} {
	    # Being invoked as a scrollcommand, in which lines are
	    # counted from 0.  incr to get back to mark coordinates.
	    incr line
	    set mark $line.0
	}
    }
    if {[lindex $args 0] == "-pickplace"} {
	set pick -pickplace
	set mark [lrange $args 1 end]
    } else {
	set pick {}
    }
    if [$t compare $mark > end] {
	set mark end
    }
    eval {$t yview} $pick {$mark}
    set height [lindex [split [winfo geometry $t] +x] 1]
    set bot [$t index @0,$height]
    set end [$t index end]
    if {$bot != $end} {
	return
    }
    set max [lindex [$t config -height] 4]
    set i 0
    while {$bot == $end} {
	set mark [$t index [list $mark -1 lines]]
	$t yview $mark
	set bot [$t index @0,$height]
	incr i
	if {$i > $max} {
	    return	;# message smaller than window
	}
    }
    set mark [$t index [list $mark +1 lines]]
    $t yview $mark
}
proc WidgetScrollSet {s t args} {
    global widgetText
    set widgetText($t,view) $args
    if {$s != {}} {
	if [catch {eval {$s set} $args} err] {
	    Exmh_Debug WidgetScrollSet $err
	}
    }
}
proc WidgetTextMark {t y} {
    global widgetText
#    Exmh_Debug WidgetTextMark $t $y
    set widgetText($t,mark) $y			;# Remember mark point
    scan [$t index @1,1] %d widgetText($t,top)	;# and starting top line
}
proc WidgetTextDragto {t y speed} {
    global widgetText
    if ![info exists widgetText($t,mark)] {
	return
    }
    if {$y == $widgetText($t,mark)} {
	return
    }
#    Exmh_Debug WidgetTextDragto $t $y
    set gridy [WidgetTextGridY $t]
    set dy [expr {($widgetText($t,mark)-$y)*$speed}]
    set dlines [expr $dy/$gridy]
    set rem [expr $dy%$gridy]
    if {$dy < 0} {
	incr dlines
	set rem [expr $rem-$gridy]
    }
    if {$dlines >= 1.0 || $dlines <= -1.0} {
	set widgetText($t,mark) [expr $y+$rem]
	set newtopline [expr $widgetText($t,top)+$dlines]
	WidgetTextYview $t $newtopline.0
	set widgetText($t,top) $newtopline
    }
}
proc WidgetTextGridY {t} {
    global widgetText
    set geo [split [winfo geometry $t] +x]
    if ![info exists widgetText($t,geo)] {
	set widgetText($t,geo) 0
    }
    if { [string compare $geo $widgetText($t,geo)] != 0 } {
	# Reverse engineer grid size - broken for windows that get resized.
	set widgetText($t,geo) $geo
	set h [lindex $geo 1]
	set nlines [lindex [$t config -height] 4]
	set widgetText($t,gridY) [expr $h/$nlines]
	Exmh_Debug widgetText($t,gridY) $widgetText($t,gridY)
    }
    return $widgetText($t,gridY)
}
proc WidgetTextSelBegin {w x y how} {
    WidgetTextSelStart $w @$x,$y $how
}
proc WidgetTextSelStart {w mark how} {
    global widgetText
    set widgetText($w,extend) 0
    switch -- $how {
	char {Text_SetInsert $w $mark}
	word {Text_WordSelect $w $mark}
	line {Text_LineSelect $w $mark}
    }
}
proc WidgetTextSelAgain {w x y} {
    global widgetText
    set widgetText($w,extend) 0
    tk_textResetAnchor $w @$x,$y
    Text_SelectTo $w @$x,$y
}
proc WidgetTextSelMotion {w x y} {
    global widgetText

    if ![info exists widgetText($w,extend)] {
	return
    }
    set active $widgetText($w,extend)

    set h [winfo height $w]
    if {$y > $h} {
	set widgetText($w,extend) [expr $y-$h]
    } else {
	if {$y < 0} {
	    set widgetText($w,extend) $y
	} else {
	    set widgetText($w,extend) 0
	}
    }
    
    if {$widgetText($w,extend) == 0} {
	Text_SelectTo $w @$x,$y
    } else {
	if {! $active} {
	    set widgetText($w,lastmark) [$w index @$x,$y]
	    after $widgetText(selectDelay) [list WidgetTextSelExtend $w]
	}
    }
}
proc WidgetTextSelExtend {w} {
    global widgetText

    if {![info exists widgetText($w,extend)] ||
	($widgetText($w,extend) == 0)} {
	    return
    }
    set delta [expr {$widgetText($w,extend) / 16}]
    if {$delta == 0} {
	set delta [expr { ($widgetText($w,extend) < 0) ? -1 : 1 }]
    }
    set sign [expr {($delta > 0) ? "+" : ""}]
    catch {
	if [$w compare $widgetText($w,lastmark) <= sel.first] {
	    set mark "sel.first $sign $delta lines"
	} else {
	    set mark "sel.last $sign $delta lines"
	}
	set widgetText($w,lastmark) [$w index $mark]
	Text_SelectTo $w $mark
	$w yview -pickplace $mark
	after $widgetText(selectDelay) [list WidgetTextSelExtend $w]
    }
}
proc WidgetTextSelDone {w} {
    global widgetText
    catch {unset widgetText($w,extend)}
    Text_SelectionEnd $w 1
}
proc Widget_TextEnd {w} {
    scan [$w index end] %d i
    incr i -2
}

proc tk_textResetAnchor {args} {
    eval ::tk::TextResetAnchor $args
}

# Fill out the text widget with enough blanks to allow the
# given line to appear at the top.
proc Widget_TextPad {w top} {
    # Assume -height is ok, even though can be wrong after resize
    # set height [$w cget -height]
    #
    # The above replaced by the following, thanks to 
    # Harvey Thompson <harveyt@sco.com> and
    # John Haxby <J.Haxby@isode.com>

    # Add newlines so that text in all window
    set limit 100
    while {[$w bbox "end -1c"] != ""} {
	$w insert end \n
	if {[incr limit -1] < 0} {
	    break
	}
    }
    # Compute height even if using different fonts
    set height [expr int([$w index @0,65535]) - int([$w index @0,0]) + 1] 
    set last [$w index "end -1c"]
    Exmh_Debug Widget_TextPad h=$height last=$last top=$top
    for {} {$last - $top < $height+1} {set last [expr $last + 1.0]} {
	$w insert end \n
    }
}
