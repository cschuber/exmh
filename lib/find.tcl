# find.tcl
#
# Find tool.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Find_Msg {} {
    global find
    set find(choice) Msg
    Find_Setup
}
proc Find_FTOC {} {
    global find
    set find(choice) FTOC
    Find_Setup
}
proc Find_Setup {} {
    global find

    Find_Reset
    if [Exwin_Toplevel .find "Exmh Find Tool" Find] {
	set t .find
	set f $t.but	;# from Exwin_Toplevel

	Widget_AddBut $f next "Next" {Find_It forw} {left padx 1 filly}
	Widget_AddBut $f prev "Prev" {Find_It prev} {left padx 1 filly}
	set find(allbut) [Widget_CheckBut $f all "All" find(all) {left padx 1}]
	Widget_RadioBut $f ftoc "FTOC" find(choice) {left padx 1}
	Widget_RadioBut $f msg "Msg" find(choice) {left padx 1}

	set f [Widget_Frame $t rim Rim]
	$f configure -bd 10
	set f [Widget_Frame $f rim LabelledEntry]
	Widget_Label $f label {left fill} -text "Pattern: "
	set find(entry) [Widget_Entry $f entry {right fill expand}]
	Bindings_Search $find(entry)

	if ![info exists find(choice)] {
	    set find(choice) FTOC
	}
	trace variable find(choice) w FindTraceChoice
	FindTraceChoice
	if ![info exists find(all)] {
	    set find(all) 0
	}
    } else {
	$find(entry) delete 0 end
    }
    focus $find(entry)
}
proc FindTraceChoice {args} {
    global find
    catch {
    if {$find(choice) == "FTOC"} {
	$find(allbut) config -state normal
    } else {
	$find(allbut) config -state disabled
    }
    }
}
proc Find_Reset {} {
    global find
    set find(dir) forw
    set find(line) 1
    set find(lasthit) {}
    set find(wrap) 0
    set find(wrapLine) 1
    catch {unset find(curline)}
}
proc FindDestroy {} {
    global find
    set find(geometry) [wm geometry .find]
    wm withdraw .find
    Exmh_Focus
}
proc Find_It { {dir _default_} } {
    global find
    if ![info exists find(entry)] {
	Find_Setup
	return
    }
    if [catch {$find(entry) configure}] {
	unset find(entry)
	Find_Setup
	return
    }
    if {[wm state .find] != "normal"} {
	global exwin
	catch {wm geometry .find $exwin(geometry,$path)}
	wm deiconify .find
	Find_Setup
	return
    } else {
	catch {raise .find}
    }
    if {$dir == "_default_"} {
	Find_Reset
	set dir forw
    }
    set find(dir) $dir
    if {$find(choice) == "FTOC"} {
	global ftoc
	if {$find(all)} {
	    Ftoc_FindAll [$find(entry) get]
	} else {
	    Find_Inner [$find(entry) get] $dir $ftoc(curLine) $ftoc(numMsgs) Ftoc_FindMatch
	}
	return
    }
    if {$find(choice) == "Msg"} {
        global exwin
	set last [lindex [split [$exwin(mtext) index end] .] 0]
	incr last -1
	Find_Inner [$find(entry) get] $dir $find(line) $last Msg_FindMatch
	return
    }
}
proc Find_Inner { string dir start max matchProc {feedback yes} } {
    global exwin find
    set verbose [expr {$feedback == "yes"}]
    if {[string length $string] == 0} {
	if {$verbose} {Exmh_Status "No search string" warn}
	return -1
    }
    if {$find(wrap)} {
	set find(line) $find(wrapLine)
    } else {
	set find(line) $start
    }
    if {$find(line) == {}} {
	set find(line) 1
    }
    set L $find(line)
    Exmh_Debug "Find_Inner line $L max $max wrap $find(wrap) wline $find(wrapLine)"
    if {$dir == "forw"} {
	for { } {$L <= $max} {incr L} {
	    switch -- [FindMatch $matchProc $L $string] {
		-1 { return 0 }
		1  {
		    set find(wrap) 0
		    return 1	;# find(line) has been updated
		}
	    }
	}
	if {! $find(wrap)} {
	    set find(wrap) 1
	    set find(wrapLine) 1
	    if {$verbose} {Exmh_Status "Find miss: <Control-s> to wrap" warn}
	    return 0
	}
	set find(wrap) 0
	for {set L 0} {$L < $find(line)} {incr L} {
	    switch -- [FindMatch $matchProc $L $string] {
		-1 { return 0 }
		1  {
		    set find(wrap) 0
		    return 1	;# find(line) has been updated
		}
	    }
	}
    } else {
	for { } {$L >= 1} {incr L -1} {
	    switch -- [FindMatch $matchProc $L $string] {
		-1 { return 0 }
		1  {
		    set find(wrap) 0
		    return 1	;# find(line) has been updated
		}
	    }
	}
	if {! $find(wrap)} {
	    set find(wrap) 1
	    set find(wrapLine) $max
	    if {$verbose} {Exmh_Status "Find miss: <Control-r> to wrap" warn}
	    return 0
	}
	set find(wrap) 0
	for {set L $max} {$L > $find(line)} {incr L -1} {
	    switch -- [FindMatch $matchProc $L $string] {
		-1 { return 0 }
		1  {
		    set find(wrap) 0
		    return 1	;# find(line) has been updated
		}
	    }
	}
    }
    if {$verbose} {Exmh_Status "No match" warn}
    return -1
}
proc FindMatch { hook L string } {
    global find
    if [catch {$hook $L $string} match] {
	Exmh_Status "$match"
	return -1
    }
    if {$match == 1} {
	set find(line) $L
	# HACK
	if {! [string match Sedit* $hook]} {
	    Exmh_Focus
	    Exmh_Status "Find hit: <Control-s> next, <Control-r> prev" 
	}
    }
    return $match
}
proc FindTextMatch {t L string} {
    global find
    if [$t compare $L.end >= end] {
	return -1
    }
    if [catch {$t get $L.0 $L.end} text] {
	return -1
    }
    if {$L == $find(lasthit)} {
	# Look for more strings on the same line
	# This behaves wrong during Previous searches...
	set text [string range $text $find(lastchar2) end]
    } else {
	set find(lastchar2) 0
    }
    if {[regexp -nocase -indices $string $text match]} {
	global msg
	set range [$t tag ranges sel]
	if {$range != {}} {
	    eval {$t tag remove sel} $range
	}
	set char1 [expr $find(lastchar2)+[lindex $match 0]]
	set char2 [expr $find(lastchar2)+[lindex $match 1]+1]
	$t tag add sel $L.$char1 $L.$char2
	$t tag raise sel
	WidgetTextYview $t -pickplace $L.$char1
	set find(lasthit) $L
	set find(lastchar2) $char2
	return 1
    }
    return 0
}

