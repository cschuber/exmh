#
# exmh_background.tcl --
#	Periodic background processing
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

# Background processing

proc Background_Init {} {
    global exmh env background

    if ![info exists env(MAIL)] {
	set spool /usr/spool/mail/$env(USER)
    } else {
	set spool $env(MAIL)
    }
    Preferences_Add "Background Processing" \
"A second process is used to perform various background tasks for Exmh.  These options control its behavior." \
    [list \
	{ exmh(bgAsync) bgAsync ON {Separate background process}
"This setting determines whether or not the background
processing is done in a separate process or not.  A
separate process causes less interference with the user
interface, but might take up more machine resources."} \
	{ exmh(sendHack) sendHack ON {Keep xhost list clear}
"The Tk send command will stop working if hosts are added to
your xhost list, even if you are using Xauthority.  This option
replaces the send command with a version that clears out the
xhost list if hosts are found on it."} \
	{ exmh(background) bgAction {CHOICE off count msgchk flist inc hook} {Background processing}
"exmh can periodically do some things for you:
count - count new messages sitting in your spool file.
msgchk - run the MH msgchk program.
flist - check for new mail in all folders.
inc - just like clicking the Inc button yourself.
hook - suppply your own Hook_Background procedure.
off - do nothing in the background."} \
	{ exmh(bgPeriod) bgPeriod 10 {Period (minutes)}
"How often to do background task"} \
	{exmh(bgNews) bgNews OFF {Background News Retrieval}
"Retrieve News via NNTP in the background.  See the Preferences for 
NNTP support for more information"} \
	{ exmh(bgNewsPeriod) bgNewsPeriod 60 {Period (minutes)}
"How often to do background News Retrieval"} \
	[list exmh(spool) bgSpool $spool {Mail spool pathname} \
"Pathname for the mail spool file that gets new messages."] \
    ]
    # due to a TK bug I cannot trace the radio button variable directly.
    # I can hack around it by tracing the bgPeriod, which is always
    # set by Preferences because it is an entry
    trace variable exmh(bgPeriod) w BackgroundFixup
    if {$exmh(background) <= 0} {
        set exmh(background) 10
    }
    set exmh(lastBackground) $exmh(background)

    set exmh(timeSinceBgNews) -1

    set background(lastMsgChk) {}
    set exmh(sendErrors) 0
    if {$exmh(sendHack)} {
	source $exmh(library)/send.tcl
    }
}
proc Background_Startup {} {
    global exmh inc

    if [info exists exmh(interp)] {
	# Already in the background interpreter.
	# Invoked because the style of background processing changed
	Background_DoPeriodic
	return
    }
    if [info exists exmh(bgInterp)] {
	if {[catch {send $exmh(bgInterp) {Background_Startup}}] == 0} {
	    # Background interp already running
	    return
	}
    }
    Background_Cleanup	;# In case the bg process is really there anyway

    if {! $exmh(bgAsync) } {
	# Do not run a separate process
	Background_DoPeriodic
	return
    }
    global mh_path argv0 wish
    set prog ${argv0}-bg
    Exmh_Status "Starting: $prog"
    set cmd [list exec $wish -f $prog [winfo name .] $exmh(library) $mh_path &]
    if [catch {
	set pid [eval $cmd]
	set exmh(bgPid) $pid
	Exmh_Debug Background_Startup $exmh(background) pid $pid
	after [expr 10*1000*60] BackgroundCheckup
    } err] {
	Exmh_Status "exmh-bg error: $err"
	Background_DoPeriodic
    }
}
proc BackgroundCheckup {} {
    global exmh
    Exmh_Debug BackgroundCheckup
    if [BgLostPid $exmh(bgPid) exmh-bg] {
	catch {unset exmh(bgInterp)}
	Exmh_Debug Restarting exmh-bg
	Background_Startup
    } else {
	after [expr 10*1000*60] BackgroundCheckup
    }
}
proc Background_Register { bgInterp {bgPid junk} } {
    # Invoked by the background interpreter so we can talk back to it
    global exmh
    set exmh(bgInterp) $bgInterp
    if {$bgPid != "junk"} {
	set exmh(bgPid) $bgPid
    }
    Exmh_Debug "Background interp is $bgInterp, pid $exmh(bgPid)"

    # Bundle up some parameters that could be overridden on the
    # command line and so won't get picked up from the Xresources
    set exmh(pid) [pid]		;# TCL 7.* dependent
    foreach varname {exmh(background) exmh(bgPeriod) exmh(pid)} {
	lappend results [list $varname [set $varname]]
    }
    return $results
}
proc Background_Cleanup {} {
    global exmh bgaction
    if [catch {send $exmh(bgInterp) Exmhbg_Done [winfo name .]}] {
	catch {exec kill $exmh(bgPid)}
    }
    catch {
	foreach action [array names bgaction] {
	    BackgroundComplete $action
	}
    }
    foreach interp [winfo interps] {
	if {[string match $exmh(name)-bg* $interp]} {
	    catch {send $interp Exmhbg_Done [winfo name .]}
	}
    }
}
proc Background_DoPeriodic {} {
    global exmh
    Exmh_Debug Background_DoPeriodic $exmh(background)
    switch -- $exmh(background) {
	"count"  { set bgProc BackgroundCount }
	"msgchk" { set bgProc BackgroundMsgChk }
	"inc"    { set bgProc BackgroundInc }
	"flist"  { set bgProc BackgroundFlist }
	"hook"	 {
	    set bgProc [info commands Hook_Background]
	    if {[string length $bgProc] == 0} {
		Exmh_Status "Hook_Background undefined (hook background option)"
		set exmh(background) off
	    }
	}
	default { set bgProc {} }
    }
    if {[string length $bgProc] != 0} {
	if [catch $bgProc err] {
	    Exmh_Debug $bgProc $err
	}
    }

    if {$exmh(bgNews)} {
	if {(($exmh(timeSinceBgNews) == -1) ||
	($exmh(timeSinceBgNews) > ($exmh(bgNewsPeriod) * 60)))} {
	    GetNews
	    set exmh(timeSinceBgNews) 0
	} 
	
	incr exmh(timeSinceBgNews) [expr int($exmh(bgPeriod) * 60)]
    }

    after [expr int($exmh(bgPeriod)*1000*60)] Background_DoPeriodic
}
proc Background_Off {} {
    global exmh
    set exmh(background) {}
}
proc BackgroundFixup { args } {
    global exmh
    Exmh_Debug BackgroundFixup $exmh(lastBackground) $exmh(background)
    if {[catch {expr $exmh(bgPeriod)*1000*60}] ||
	 ($exmh(bgPeriod) <= 0)} {
	set exmh(bgPeriod) 10
    }
    if {$exmh(background) != $exmh(lastBackground)} {
	Background_Startup
	set exmh(lastBackground) $exmh(background)
    }
}

proc BackgroundMsgChk {} {
    global exmh env background
    set result [Mh_MsgChk]
    if {$result != $background(lastMsgChk)} {
	BgRPC BackgroundMsgChkInner $result
	Exmh_Status $result
	set background(lastMsgChk) $result
    }
}
proc BackgroundMsgChkInner {result} {
    global background exmh
    Exmh_Status $result
    set background(lastMsgChk) $result
    switch -glob -- $result {
	"You have*" {set exmh(numUnInced) "Some"; Flag_Spooled}
	"You don't*" {set exmh(numUnInced) 0; Flag_NoSpooled}
    }
}
proc BackgroundCount {} {
    global exmh env
    if ![catch {Mh_MsgCount $exmh(spool)} newmsgs] {
	BgRPC BackgroundNewMsgs [string trim $newmsgs]
    }
}

proc BackgroundNewMsgs { N } {
    global exmh
    if ![info exists exmh(numUnInced)] {
	set exmh(numUnInced) 0
    }
    if {$N > 0} {
	if {$N == 1} {
	    set msg "msg"
	} else {
	    set msg "msgs"
	}
	set exmh(numUnInced) $N
	Exmh_Status "You have $N spooled $msg" blue
	Flag_Spooled
    } else {
	Flag_NoSpooled
	if {$exmh(numUnInced) > 0} {
	    Exmh_Status ""
	}
	set exmh(numUnInced) $N
    }
}
proc BackgroundInc {} {
    Inc
}

proc BackgroundFlist {} {
    Flist_FindUnseen		;# Update folder highlights
    BgRPC Inc_PresortFinish	;# Update scan listing
}

# Invoke something in the background interpreter, if it exists
proc BgAction { tag args } {
    global exmh
    Exmh_Debug BgAction $tag $args
    Audit "$tag $args"
    if [info exists exmh(bgInterp)] {
	BackgroundPending $tag	;# Register outstanding request
	if ![catch {
	    send $exmh(bgInterp) [list after 1 [list BgProcess $tag $args]]
	} err] {
	    return
	}
	BackgroundComplete $tag
	Exmh_Debug BgAction $err
    }
    eval $args
    foreach cmd [info commands Hook_Bg$tag*] {
	$cmd
    }
}
# Run something in the background and report back to the front end
proc BgProcess { tag cmd } {
    global exmh
    if [catch $cmd err] {
	Exmh_Status $err
    }
    if [catch {send $exmh(interp) [list BackgroundComplete $tag]} err ] {
	catch {puts stderr "exmh-bg: BackgroundComplete($tag) failed: $err"}
	Exmh_Status $err
    }
}

# Invoke a routine in the UI interpreter, if it exists, else ourselves.
# If there is no separate background process, then
# exmh(interp) does not exist, and we just eval the command
# in the current process, which is already the UI.
proc BgRPC { args } {
    global exmh
    if [info exists exmh(dead)] {
	return
    }
    set check [info exists exmh(pid)]
    if [info exists exmh(interp)] {
	# Send command to main, front-end interpreter
	set fail {}
#	if {$check && [BgLostPid $exmh(pid) exmh]} {
#	    # Front-end died or may have restarted - bail out
#	    set fail "process $exmh(pid)"
#	} else {
	    if [catch {send $exmh(interp) $args} err] {
		switch -- $err {
		    {remote\ interpreter\ did\ not\ respond} {
			if {$check && [BgLostPid $exmh(pid) exmh]} {
			    set fail "process $exmh(pid)"
			}
		    }
		    {no\ registered\ interpeter*} {
			set fail "interp $exmh(interp)"
		    }
		    {no\ application\ named*} {
			set fail "interp $exmh(interp)"
		    }
		    {} {
			set fail "interp $exmh(interp)"
		    }
		    default {
			#puts stderr "BgRPC: $args: $err"
		    }
		}
	    } else {
		return $err
	    }
#	}
	if {"$fail" != ""} {
	    unset exmh(interp)
	    catch {puts stderr "exmh-bg: lost UI $fail"}
	    exit
	}
    } else {
	# Eval in main, front-end interpreter
	uplevel #0 $args
    }
}
proc BgLostPid { pid {name notused} } {
    global exmh ps
    if [catch {PsByID $pid} err] {
	catch {puts stderr "BgLostPid $ps(cmd) $ps(pflag) $pid: $err"}
	return 1
    } else {
	foreach line [split $err \n] {
	    if {[string compare [lindex $line 0] $pid] == 0} {
		return 0
	    }
	}
	catch {puts stderr "BgLostPid pid $pid: cannot find in ps output"}
	return 1
    }
}
proc BgLostPidOld { pid {name notused} } {
    if [catch {exec ps $pid} err] {
	if [string match {[Uu]sage:*} $err] {
	    return [catch {exec ps -p $pid}]
	} else {
	    return 1
	}
    } else {
	foreach line [split $err \n] {
	    if {[string compare [lindex $line 0] $pid] == 0} {
		return 0
	    }
	}
	return 1
    }
}
# Improved version of BgLostPid thanks to Scott Hammond
if {0} {
    set ps ps
    set ps_opt ""
    proc BgLostPidClever { pid {name notused} } {
	global ps ps_opt
	if [catch "exec $ps $ps_opt $pid" err] {
	    #puts stderr "ps error: $err"
	    if [string match {[Uu]sage:*} $err] {
		# got usage, so ps must be right, -p should also be right
		set ps_opt "-p"
		return [catch {exec $ps -p $pid}]
	    } elseif [string match {*can't find controlling terminal} $err] {
		if {"$ps" == "ps"} {
		    set ps "/bin/ps"
		} elseif {"$ps" == "/bin/ps"} {
		    set ps "/usr/ucb/ps"
		} else {
		    return 1
		}
		return [BgLostPid $pid $name]
	    } else {
		return 1
	    }
	} else {
	    foreach line [split $err \n] {
		if {[string compare [lindex $line 0] $pid] == 0} {
		    return 0
		}
	    }
	    return 1
	}
    }
}

proc Background_Preferences {} {
    # Tell the background interpreter to update its per-user settings
    global exmh
    if [info exists exmh(bgInterp)] {
	catch {send $exmh(bgInterp) [list Preferences_Reset]}
    }
}

proc BackgroundPending { action } {
    global bgaction
    set bgaction($action) 1
    Exmh_Debug BackgroundPending $action
}
proc BackgroundComplete { action } {
    global bgaction
    catch {unset bgaction($action)}
    Exmh_Debug BackgroundComplete $action
    if [regexp {Refile (.*)} $action x folder] {
	global exmh
	if {[string compare $exmh(folder) $folder] == 0} {
	    Exmh_Status "Updating scan listing"
	    Scan_FolderUpdate $folder
	}
    }
    if {[Background_Outstanding] == {}} {
	Exmh_Status "background actions complete"
    }
    foreach cmd [info commands Hook_Bg$action*] {
	$cmd
    }
}
proc Background_Outstanding {} {
    global bgaction background
    if [catch {array names bgaction} actions] {
	set actions {}
    }
    if {$actions == {}} {
	set background(complete) 1
	catch {destroy .ftoc.t.abort}
    }
    return $actions
}
proc Background_Wait {} {
    global background
    set background(complete) 0
    set pending [Background_Outstanding]
    if {$pending != {}} {
	Exmh_Status "waiting... $pending"
	catch {
	button .ftoc.t.abort -text "Don't Wait" -command Background_Reset
	place .ftoc.t.abort -relx .5 -rely .5 -anchor c
	}
	tkwait variable background(complete)
	catch {destroy .ftoc.t.abort}
    }
}

proc Background_Reset {} {
    global bgaction
    foreach act [array names bgaction] {
	Exmh_Status "Clearing $act"
    }
    unset bgaction
    Background_Outstanding
}
