# frame.tcl
# Display HTML frames.
# See license.terms for copyright info.

# These two arrays are used to parameterize placement algorithms
# An upvar is used to alias one of them to the variable F.  For example,
# F(d) is the coordinate that changes for each row(col)
array set Frame_rows {
    args0	"-anchor n -relw 1.0 -relx 0.5"
    barargs	"-anchor sw -relw 1.0 -relx 0.0"
    boxargs	"-anchor s -relx 0.5"
    footargs	"-relx 1.0 -y 0 -relh 1.0 -anchor ne -x -1"
    butargs	"-relx 0.2 -rely 0.5 -anchor w"
    size	height
    osize	width
    relsize	relh
    d		y
    D		Y
    dd		x
    DD		X
    other	cols
}
array set Frame_cols {
    args0	"-anchor w -relh 1.0 -rely 0.5"
    barargs	"-anchor ne -relh 1.0 -rely 0.0"
    boxargs	"-anchor e -rely 0.5"
    footargs	"-x 0 -rely 1.0 -relw 1.0 -anchor sw"
    butargs	"-rely 0.2 -relx 0.5 -anchor n"
    size	width
    osize	height
    relsize	relw
    d		x
    D		X
    dd		y
    DD		Y
    other	rows
}


proc Frame_Reset {win} {
    upvar #0 HM$win var Frame$win frame
    FrameTweakUI $win on
    catch {unset frame}
    catch {unset var(S_targets)}
    catch {unset var(S_outproc)}
}

# FrameTweakUI does two things.  First it fiddle with the Edit button
# in the main control panel to turn it into a menu when displaying frames.
# Second, it places a frame over the regular display that holds all the frames.
proc FrameTweakUI {win how} {
    upvar #0 Frame$win frame
    set parent [winfo parent $win]
    set top [winfo toplevel $win]
    if {[string compare $top .] == 0} {
	set dot ""
    } else {
	set dot .
    }
    set edit $top${dot}url.edit
    set menu $top${dot}url.edit.frame.m
    if {[string compare $parent .] == 0} {
	set dot ""
    } else {
	set dot .
    }
    set main $parent${dot}main
    if ![winfo exists $main] {
	# Embedded frames
	set main $parent
    }
    set f $parent${dot}frame
    if {$how == "on"} {
	if {$top == $parent} {
	    pack forget $edit.frame
	    pack $edit.normal
	    catch {$menu delete 0 end}
	    catch {$menu add command -label Frameset \
		    -command [list Frameset_Edit $win]}
	}
	catch {destroy $frame(master)}
    } else {
	if {$top == $parent} {
	    pack propagate $edit off
	    pack forget $edit.normal
	    pack $edit.frame
	}
	set frame(master) [frame $f]
	set frame(menu) $menu
	place $f -in $main -anchor nw -x 0 -y 0 -relw 1.0 -relh 1.0
    }
    return $f
}
proc HMtag_frameset {win param text} {
    upvar #0 HM$win var Frame$win frame
    if ![info exists frame(level)] {
	set frame(do_display) 1
	set frame(level) 0
	set frame(color) FF
	set frame(frameset) {}
	set frame(display) {}
	set parent [FrameTweakUI $win off]
	set var(S_outproc) Frameset_Output
    } else {
	incr frame(level)
	set frameset [lindex $frame(frameset) end]
	set parent [lindex $frameset 0]
	set frameset [lreplace $frameset 0 0]
	set frame(frameset) [lreplace $frame(frameset) end end $frameset]
    }
    HMextract_param $param rows
    HMextract_param $param cols
    if {![info exists rows] && ![info exists cols]} {
	set spec *
	set key rows
    } elseif {[info exists rows] && [info exists cols]} {
	# oops - both rows and columns specified.
	# Figure out which one to ignore.
	set spec *
	set key rows
	foreach x [split $rows ,] {
	    if ![regexp {^(100%|\*)$} $x] {
		set key rows
		set spec $rows
	    }
	}
	foreach x [split $cols ,] {
	    if ![regexp {^(100%|\*)$} $x] {
		set key cols
		set spec $cols
	    }
	}
    } elseif {[info exists rows]} {
	set spec $rows
	set key rows
    } else {
	set spec $cols
	set key cols
    }
    set frame($key,$parent) $spec
    set i 0
    set frameset {}
    foreach x [split $spec ,] {
	set f [frame $parent.$key$i -class Frame]
	place $f -in $parent	;# true parameters set later
	lappend frame(frames) $f
	lappend frameset $f
	set frame($key,$parent,$i,frame) $f
	incr i
    }
    bind $parent <Configure> +[list FrameSize $win $parent $key]
    lappend frame(frameset) $frameset	;# Push a frameset
    return $parent
}
proc FrameSize {win parent key} {
    upvar #0 Frame$win frame
    upvar #0 Frame_$key F
    set spec $frame($key,$parent)
    set max [winfo $F(size) $parent]
    set i 0
    set total 0
    set expand 0
    foreach x [split $spec ,] {
	if {[regexp {^([0-9]+)$} $x _ pixels]} {
	    incr total $pixels
	    set frame($key,$parent,$i,size) $pixels
	} elseif {[regexp {^([0-9]+)%$} $x _ percent]} {
	    set ratio [expr double($percent)/100.0]
	    set frame($key,$parent,$i,relsize) $ratio
	    incr total [expr int($ratio * double($max))]
	} elseif {[regexp {([0-9]*)\*} $x _ mult]} {
	    if {[string length $mult] == 0} {
		set mult 1
	    }
	    incr expand $mult
	    set frame($key,$parent,$i,mult) $mult
	} else {
	    set frame($key,$parent,$i,size) 0
	}
	incr i
    }
    if {($expand > 0)} {
	set frame(expand,$parent) $expand
	set frame(total,$parent) $total
	set frame(max,$parent) $max
	if {($total < $max)} {
	    set share [expr (double($max) - double($total)) / \
				double($expand) / double($max)]
	} else {
	    set share 0
	}
	set frame(share,$parent) $share
   }
    set i 0
    set offset 0
    set reloff 0.0
    foreach x [split $spec ,] {
	set args $F(args0)
	lappend args -$F(d) $offset -rel$F(d) $reloff
        if {[info exists frame($key,$parent,$i,mult)]} {
	    set ratio [expr $frame($key,$parent,$i,mult) * $share]
	    set frame($key,$parent,$i,relsize) $ratio
	}
        if {[info exists frame($key,$parent,$i,relsize)]} {
	    lappend args -$F(relsize) $frame($key,$parent,$i,relsize)
	    set reloff [expr $reloff + $frame($key,$parent,$i,relsize)]
	}
        if {[info exists frame($key,$parent,$i,size)]} {
	    lappend args -$F(size) $frame($key,$parent,$i,size)
	    incr offset $frame($key,$parent,$i,size)
	}
	set f $frame($key,$parent,$i,frame)
	eval place $f $args
	incr i
    }
}
proc HMtag_/frameset {win param text} {
    upvar #0 HM$win var Frame$win frame
    if [info exists frame(level)] {
	incr frame(level) -1
	if {$frame(level) < 0} {
	    unset frame(level)
	    if {$frame(do_display)} {
		foreach cmd $frame(display) {
		    eval $cmd
		}
		set frame(display) {}
	    }
	}
    }
    if [info exists frame(frameset)] {
	set frame(frameset) [lreplace $frame(frameset) end end]
    }
    return {}
}
proc HMtag_frame {win param text} {
    upvar #0 HM$win var Frame$win frame
    set mainwin [Window_GetMaster $win]
    upvar #0 Frame$mainwin frame0

    set frameset [lindex $frame(frameset) end]
    set parent [lindex $frameset 0]
    set frameset [lreplace $frameset 0 0]
    set frame(frameset) [lreplace $frame(frameset) end end $frameset]
    set frame(html,$parent) [list frame $param]

    set scrolling auto
    HMextract_param $param scrolling
    set scrolling [string tolower $scrolling]

    set pady 2
    HMextract_param $param marginheight pady
    set padx 2
    HMextract_param $param marginwidth padx

    set newwin [Window_Frame $win $parent $scrolling $padx $pady]
    set name (noname)
    if [HMextract_param $param name] {
	# target of a href
	set frame0(target,$name) $newwin
    }
    if [HMextract_param $param src url] {
	set frame0(url,$name) $url
	set frame0(src,$parent) $url
	lappend frame(display) [list Url_DisplayFrame $newwin $url]
    }
    catch {
	$frame(menu) add command -label $name \
	    -command [list Frame_Edit $win $name]
    }
    return $parent
}
proc Frame_Display {win name href} {
    set mainwin [Window_GetMaster $win]
    upvar #0 Frame$mainwin frame
    if [info exists frame(target,$name)] {
	set frame(url,$name) $href
	Url_DisplayFrame $frame(target,$name) $href
    } else {
	Url_Display $win $href
    }
}
proc Frame_Edit {win name} {
    upvar #0 Frame[Window_GetMaster $win] frame
    set newwin [Url_DisplayNew $frame(url,$name) $win]
    Input_Mode $newwin Edit
}
proc HMtag_/frame {win param text} {
    return {}
}
proc HMtag_noframes {win param text} {
    upvar #0 HM$win var
    set var(S_stop) 1
    return {}
}
proc HMtag_/noframes {win param text} {
    return {}
}

