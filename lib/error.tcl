# error.tcl
#
# tkerror for exmh
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

#
# tkerror --
#	This is the handler for background errors that arise
#	from commands bound to keystrokes and menus.  A
#	toplevel message widget is used to display $errorInfo

set ErrorIgnore {
    {^grab failed}
}

proc tkerror { msg } {
    global errorInfo exmh ErrorIgnore

    foreach pat $ErrorIgnore {
	if [regexp $pat $msg] {
	    Exmh_Status $msg
	    return
	}
    }
    set font fixed
    set base ".errorInfo"
    set title "Error Info"
    if [info exists errorInfo] {
	set savedErrorInfo $errorInfo
    } else {
	set savedErrorInfo {no errorInfo}
    }
    # Create a toplevel to contain the error trace back
    if [catch {
	# Choose a unique name
	for {set x 1} {$x<10} {set x [expr $x+1]} {
	    if {! [winfo exists $base-$x]} {
		break
	    }
	}
	set title $title-$x
	set name $base-$x

	set wx [expr ($x%20)*10]
	Widget_Toplevel $name Error $wx $wx

	wm title $name $title
	wm minsize $name 20 5
    
	frame $name.buttons
	pack $name.buttons -side top -fill x
    
	button $name.buttons.quit -text "Dismiss" -command [list destroy $name]
	pack append $name.buttons $name.buttons.quit {left}
	if [info exists exmh(maintainer)] {
	    button $name.buttons.mailto -text "Mail to $exmh(maintainer)" -command [list ExmhMailError $name $errorInfo]
	    pack append $name.buttons $name.buttons.mailto {right}
	}
	global widgetText TextType

	message $name.ex -font $font -aspect 1000 -text \
"Please type a few words of explanation before
pressing the Mail to button, or just Dismiss me."
	pack $name.ex -side top -fill x
	text $name.user -font $font -width 60 -bd 2 -relief raised
	$name.user configure -height 5
	$name.user insert end "What happened: "
	$name.user tag add sel 1.0 1.14
	focus $name.user
	pack $name.user -side top -fill both -expand true
	$name.user mark set hlimit 1.0
	set widgetText($name.user,extend) 0
	set widgetText($name.user,geo) {}
	set TextType($name.user) text

	frame $name.msg
	pack $name.msg -side top -fill both -expand true

	text $name.msg.t -font $font -width 60 -bd 2 -relief raised \
		-setgrid true -yscrollcommand [list $name.msg.sy set]
	scrollbar $name.msg.sy -orient vertical -command [list $name.msg.t yview]
	set numLines [llength [split $errorInfo \n]]
	if {$numLines > 20} {
	    set numLines 20
	}
	$name.msg.t configure -height $numLines
	$name.msg.t insert end $errorInfo
	pack $name.msg.sy -side right -fill y
	pack $name.msg.t -side left -fill both -expand true
	set widgetText($name.msg.t,extend) 0
	set widgetText($name.msg.t,geo) {}
	set TextType($name.msg.t) text

	Visibility_Wait $name

    } oops] {
	set msg [concat $msg "($name: " $oops ")" ]
   }

    if {[string length $msg] > 20} {
	set msg [concat [string range $msg 0 30] ...]
    }
    if [catch {Exmh_Status "tkerror: $msg" purple}] {
	puts stderr "tkrror: $msg"
	puts stderr "*** TCL Trace ***"
	puts stderr $savedErrorInfo
    }
}
proc bgerror [info args tkerror] [info body tkerror]

proc ExmhMailError { w errInfo } {
    global exmh
    if [catch {open [Env_Tmp]/exmhErrorMsg w} out] {
	Exmh_Status "Cannot open [Env_Tmp]/exmhErrorMsg" purple
	return
    }
    if [catch {
	global env tk_version tk_patchLevel tcl_version tcl_patchLevel
	puts $out "To: $exmh(maintainer)"
	puts $out "Subject: error exmh [lrange $exmh(version) 1 end]"
	puts $out ""
	set line [$w.user get 1.0 1.end]
	if [regexp {^What happened:} $line] {
	    puts $out [string range $line 14 end]
	} else {
	    puts $out $line
	}
	puts $out [$w.user get 2.0 end]
	puts $out ""
	puts $out "[exec date]"
	if [info exists env(USER)] {
	    puts $out "$env(USER) got an error"
	}
	puts $out "Exmh $exmh(version)"
	if [info exists tk_patchLevel] {
	    set v $tk_patchLevel
	} else {
	    set v $tk_version
	}
	puts $out "TK version $v"
	if [info exists tcl_patchLevel] {
	    set v $tcl_patchLevel
	} else {
	    set v $tcl_version
	}
	puts $out "TCL version $v"
	catch {exec uname -a} uname
	puts $out "$uname"
	puts $out ""
	puts $out $errInfo
	close $out
    } msg] {
	Exmh_Status "[Env_Tmp]/exmhErrorMsg $msg" purple
	return
    }
    if [catch {
	exec send [Env_Tmp]/exmhErrorMsg
    } msg] {
	Exmh_Status "Send error: $msg" purple
	return
    } else {
	Exmh_Status "Mailed report to $exmh(maintainer)"
	destroy $w
    }
}

proc Exmh_Error { msg } {
    global errorInfo
    set errorInfo {}
    set level [info level]
    for {set l 0} {$l <= $level} {incr l} {
	append errorInfo [info level $l]
	append errorInfo \n
    }
    tkerror $msg
}

# Contributed by Jim Fulton
proc Send_Error { msg draftID } {
    global exmh

    set font fixed
    set base ".errorSend"
    set title "Address or Header Error"

    # Choose a unique name by testing for the associated error variable
    # Use the string ".errorSend-N" as the name of the toplevel
    # and as the name of a variable holding the current errorSend
    for {set x 1} {$x<10} {set x [expr $x+1]} {
	global $base-$x
	if {! [info exists $base-$x]} {
	    break
	}
    }

    set title $title-$x
    set name $base-$x
    set $name $draftID

    set wx [expr ($x%20)*10]
    Widget_Toplevel $name Error $wx $wx

    wm title $name $title
    
    frame $name.buttons
    pack append $name $name.buttons {top fill expand}
    
    button $name.buttons.quit -text "Dismiss" -command "
	    destroy $name
            unset $name
        "            
    pack append $name.buttons $name.buttons.quit {left}
    button $name.buttons.edit -text "Re-edit draft" -command "
	    destroy $name
            unset $name
	    EditWhatNow $draftID
	"
    pack append $name.buttons $name.buttons.edit {right}

    button $name.buttons.retry -text "Retry Send" -command "
	    destroy $name
            unset $name
	    Edit_Done send $draftID
	"
    pack append $name.buttons $name.buttons.retry {right}
    global widgetText TextType

    text $name.msg -font $font -width 60 -bd 2 -relief raised
    set numLines 10
    $name.msg configure -height $numLines
    $name.msg insert end $msg
    pack append $name $name.msg {top expand}
    set widgetText($name.msg,extend) 0
    set widgetText($name.msg,geo) {}
    set TextType($name.msg) text
}

