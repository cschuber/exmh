# main.tcl
#
# Main body of the application.  Note that system-dependent global
# variable settings have been defined in the exmh script.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Exmh {} {
    global exmh argv nmh

    set nmh 0
    catch {string match *group* [exec repl -help] } nmh

    Mh_Init		;# Defines mhProfile

    Preferences_Init "~/.exmh/exmh-defaults" "$exmh(library)/app-defaults"

    TopTenPreferences

    # Add this preference to initialize exmh(userLibrary) and exmh(logEnabled)
    Preferences_Add "Hacking Support" \
"These items support the extension of Exmh by User code." {
	{exmh(userLibrary)	userLibrary ~/.tk/exmh	{User library directory}
"You can override modules of the exmh implementation
by putting your versions into a private library directory.
Remember to update the tclIndex file with auto_mkindex
after you add things to that directory."}
	{exmh(sourceHook)	sourceHook OFF	{Enable source hook}
"The source hook lets you keep a set of patches in your exmh user library.
These files are sourced right after the associated file from the main
script library is sourced.  This lets you override parts of a file.
If the main script is flist.tcl, then your patch should be flist.patch.
NOTE: You must restart exmh for this change to take effect."}
	{exmh(logEnabled)	logEnabled OFF	{Debug log enabled}
"Debug information is recorded in a log that you can view
from within exmh.  Turning off the log may save some
memory usage.  You can enable the log temporarily."}
	{exmh(logLines)	logLines 1000	{Max lines in debug log}
"The log is implemented in a text widget.  This setting limits
the number of lines kept in the log."}
	{flist(debug)		flistDebug OFF	{Debug flist}
"A listbox that displays the unseen and unvisited folder state
is displayed to debug the flist module."}
    }

    ExmhArgv		;# snarf up command-line arguments
    ExmhResources	;# and some resources we need soon

    # Support per-user customization
    if [info exists exmh(userLibrary)] {
	auto_path_update $exmh(userLibrary)	;# library for new modules
	SourceHook_Init				;# patches for old modules
    }

    Exec_Init		;# Wrapper around exec
    Mh_Preferences
    Sedit_BindInit	;# Text, Entry class bindings
    Widget_TextInit	;# Text scrolling
    ExmhLogInit		;# Enables debug loging

    if [catch {User_Init} err] {
	puts stderr "User_Init: $err"
    }

    catch {exec date} d
    Audit "Startup $d $argv"

    # The order of the following mainly determines the way
    # their associated items appear in the Preferences dialog
    Sedit_Init		;# built in editor
    Ispell_Preferences
    Signature_Init
    Edit_Init		;# interface to external editors
    SlowDisplay_Init	;# See if we're on a slow display
    Print_Init
    Buttons_Init
    Ftoc_Init
    Msg_Init		;# Depends on Ftoc_Init, Buttons_Init
    Mime_Init
    URI_Init
    Html_Init
    Folder_Init		;# Sets exmh(folder)
    Inc_Init
    Exwin_Init
    Flist_Init
    UnseenWin_Init
    Fcache_Init
    Fdisp_Init		;# After Flist and Fcache
    Sound_Init
    Faces_Init
    Crypt_Init
    Pgp_Init
    Glimpse_Init
    Addr_Init
    Background_Init
    fileselect_Init
    Busy_Init
    Post_Init
    Quote_Init

    wm protocol . WM_DELETE_WINDOW Exmh_Done
    wm protocol . WM_SAVE_YOURSELF [list Exmh_Done 0]
    Exwin_Layout
    if [catch {User_Layout} err] {
	puts stderr "User_Layout: $err"
    }
    Exmh_Status $exmh(version)
    if {! $exmh(iconic)} {
	wm deiconify .
    } else {
	wm iconify .
    }
    update
    bind . <Unmap> {ExmhUnmapped %W}
    bind . <Map> {ExmhMapped %W}

    Folder_Change $exmh(folder)
    busy ExmhJunk
}
proc ExmhJunk {} {
    Inc_Startup
    Exmh_Focus
    Background_Startup
}

proc ExmhArgv {} {
    global argc argv exmh editor faces
    set extra {}
    set geo [option get . geometry Geometry]
    set icon [option get . iconposition IconPosition]
    set iconic [option get . iconic Iconic]
    set editor(sedit!) 0	;# defeat accidental saving of override
    set faces(enabled!) 0	;# defeat accidental saving of override
    set bg_action {}
    for {set i 0} {$i < $argc} {incr i} {
	set arg [lindex $argv $i]
	case $arg {
	    "-geo*" {
		incr i
		set geo [lindex $argv $i]
	    }
	    "-iconposition" {
		incr i
		set icon [lindex $argv $i]
	    }
	    "-iconic" {
		set iconic 1
		option add *Fltop.iconic 1
	    }
	    "-bgAction" {
		incr i
		set exmh(background) [lindex $argv $i]
	    }
	    "-bgPeriod" {
		incr i
		set exmh(bgPeriod) [lindex $argv $i]
	    }
	    "-sedit" {
		set editor(sedit!) 1
	    }
	    "-nofaces" {
		set faces(enabled!) 1
	    }
	    "-*" {
		catch {puts stderr "Unknown flag argument $arg"}
	    }
	    default {
		lappend extra $arg
	    }
	}
    }
    # wish snarfs up -geometry and puts it into "geometry"
    global geometry
    if [info exists geometry] {
	set geo $geometry
    }
    if {$geo != {}} {
	if [catch {wm geometry . $geo} err] {
	    catch {puts stderr "-geometry $geo: $err"}
	}
    }
    switch $iconic {
	""	{set exmh(iconic) 0}
	True	-
	TRUE	-
	true	-
	Yes	-
	YES	-
	yes	-
	1	{set exmh(iconic) 1}
	False	-
	FALSE	-
	false	-
	no	-
	NO	-
	No	-
	0	{set exmh(iconic) 0}
    }
    if {$icon != {}} {
	Exwin_IconPosition . $icon
    }

    set argv $extra
    set argc [llength $extra]
}
proc Exmh_Focus {} {
    global exwin
    focus $exwin(mtext)
}
proc ExmhResources {} {
    global exmh
    if {[winfo depth .] > 4} {
	Preferences_Resource exmh(c_st_normal) c_st_normal blue
	Preferences_Resource exmh(c_st_error) c_st_error purple
	Preferences_Resource exmh(c_st_warn) c_st_warn red
	Preferences_Resource exmh(c_st_background) c_st_background black
    } else {
	Preferences_Resource exmh(c_st_normal) c_st_normal black
	if {$exmh(c_st_normal) != "white" && $exmh(c_st_normal) != "black"} {
	    set exmh(c_st_normal) black
	}
	set exmh(c_st_error) $exmh(c_st_normal)
	set exmh(c_st_warn) $exmh(c_st_normal)
	set exmh(c_st_background) $exmh(c_st_normal)
    }
}

proc Exmh_Status {string { level normal } } {
    global exmh exwin
    if {[string compare $string 0] == 0 } { set string $exmh(version) }
    if [info exists exwin(status)] {
	switch -- $level {
	    warn	-
	    error	-
	    background	-
	    normal	{ # do nothing }
	    red		{set level warn}
	    blue	{set level normal}
	    purple	{set level error}
	    "medium sea green" {set level background}
	    default	{set level normal}
	}
	if ![info exists exmh(c_st_$level)] {
	    set exmh(c_st_$level) black
	}
	$exwin(status) configure -state normal
	catch {$exwin(status) configure -fg $exmh(c_st_$level)}
	$exwin(status) delete 0 end
	$exwin(status) insert 0 $string
	$exwin(status) configure -state disabled
	ExmhLog $string
	update idletasks
    } else {
	catch {puts stderr "exmh: $string"}
    }
}
proc Exmh_OldStatus {} {
    global exwin
    if [info exists exwin(status)] {
	return [$exwin(status) get]
    } else {
	return ""
    }
}

proc Exmh_CheckPoint {} {
    # This is really "folder change" CheckPoint
    Exmh_Debug Scan_CacheUpdate [time Scan_CacheUpdate]
    Msg_CheckPoint
}

proc Exmh_Done {{exit 1}} {
    global exmh exwin

    if { !$exit || ([Ftoc_Changes "exit"] == 0)} then {
	if $exit {
	    $exwin(mainButtons).quit config -state disabled
	    catch {exec date} d
	    Audit "Quit $d"
	}
	Exmh_Status "Checkpointing state" red
	if [info exists exmh(newuser)] {
	    PreferencesSave nodismiss	;# Save tuned parameters
	    unset exmh(newuser)
	}
	# The following is done in response to WM_SAVE_YOURSELF
	foreach cmd {Msg_CheckPoint Sedit_CheckPoint Aliases_CheckPoint
		    Exmh_CheckPoint Fcache_CheckPoint	    
		    Exwin_CheckPoint } {
	    if {[info command $cmd] != {}} {
		Exmh_Status $cmd
		if [catch $cmd err] {
		    catch {puts stderr "$cmd: $err"}
		}
	    }
	}
	if {$exit} { 
	    # This only happens when we quit.
	    Background_Wait
	    set cmds [concat {Scan_CacheUpdate Background_Cleanup
			Audit_CheckPoint Addr_CheckPoint Mime_Cleanup
			Pgp_CheckPoint Cache_Cleanup} \
			[info commands Hook_CheckPoint*]]

	    foreach cmd $cmds {
		if {[info command $cmd] != {}} {
		    Exmh_Status $cmd
		    if [catch $cmd err] {
			catch {puts stderr "$cmd: $err"}
		    }
		}
	    }
	    destroy .
	} else {
	    # Tell the session manager we are done saving state
	    global argv0 argv
	    wm command . [concat $argv0 $argv]
	    wm group . .
	}
    }
}
proc Exmh_Abort {} {
    Background_Cleanup
    destroy .
}

proc ExmhUnmapped {w} {
    # This triggers auto-commit
    if {$w == "."} {
	Ftoc_Changes iconified
    }
}
proc ExmhMapped {w} {
    if {$w == "."} {
	Inc_Mapped
    }
}

#### Exmh_Debugging

proc Exmh_Debug { args } {
    global exmhDebug
    if ![info exists exmhDebug] {
	set exmhDebug 0
    }
    if {$exmhDebug} {
	puts stderr $args
    }
    ExmhLog $args
}

proc ExmhLogInit {} {
    global exmh
    set exmh(logInit) 1
    set exmh(logButton) 0
    set exmh(logWindow) 0
}
proc ExmhLog { stuff } {
    global exmh
    if {![info exists exmh(logInit)]} {
	return
    }
    if {! $exmh(logEnabled)} {
	return
    }
    if {! $exmh(logButton)} {
	global exwin
	if [info exists exwin(mainButtons)] {
	    Widget_AddBut $exwin(mainButtons) log "Log" { ExmhLogShow }
	    set exmh(logButton) 1
	}
    }
    if {! $exmh(logWindow)} {
	ExmhLogCreate
	wm withdraw $exmh(logTop)
    }
    if [info exists exmh(log)] {
	catch {
#	    $exmh(log) insert end " [bw_delta] "
	    $exmh(log) insert end $stuff
	    $exmh(log) insert end \n
	    if {$exmh(logYview)} {
		$exmh(log) yview -pickplace "end - 1 lines"
	    }
	    scan [$exmh(log) index end] %d numlines
	    if {$numlines > $exmh(logLines)} {
		set numlines [expr {$numlines - $exmh(logLines)}]
		$exmh(log) delete 1.0 $numlines.0
	    }
	}
    }
}
proc ExmhLogCreate {} {
    global exmh
    set exmh(logWindow) 1
    Exwin_Toplevel .log "Exmh Log" Log
    set exmh(logTop) .log
    Widget_AddBut $exmh(logTop).but trunc "Truncate" ExmhLogTrunc
    Widget_AddBut $exmh(logTop).but save "Save To File" ExmhLogSave
    set exmh(logYview) 1
    Widget_CheckBut $exmh(logTop).but yview "View Tail" exmh(logYview)
    set exmh(log) [Widget_Text $exmh(logTop) 20 \
	    -setgrid true -yscroll {.log.sv set} ]
    #
    # Set up Tcl command type-in
    #
    Widget_BindEntryCmd $exmh(log) <Control-c>  \
	"focus $exmh(logTop).cmd.entry"
    bindtags $exmh(log) [list $exmh(log) Text $exmh(logTop) all]
    Widget_BeginEntries 4 80 Exmh_DoCommand
    Widget_LabeledEntry $exmh(logTop).cmd Tcl: exmh(command)
}

proc LOG { what } {
    if {[info commands log_dump] == "log_dump"} {
	log $what	;# in-memory logging
    }
}
proc ExmhLogShow {} {
    global exmh
    if [Exwin_Toplevel .log "Exmh Log" Log] {
	ExmhLogCreate
    } else {
	# Exwin_Toplevel raises the window with saved geometry
    }
}
proc ExmhLogTrunc {} {
    global exmh
    $exmh(log) delete 1.0 end
}
proc ExmhLogSave {} {
    global exmh
    for {set id 0} {$id < 100} {incr id} {
	set name [Env_Tmp]/exmhlog.$id
	if ![file exists $name] {
	    if ![catch {open $name w} logfile] {
		break
	    }
	}
    }
    if [catch {
	puts $logfile [$exmh(log) get 1.0 end]
	close $logfile
	Exmh_Status "Saved log in [Env_Tmp]/exmhlog.$id" blue
    } msg] {
	Exmh_Status "Cannot save log: $msg" purple
    }
}
#### Misc

proc DoNothing { args } {
    return ""
}
proc Exmh_DoCommand {} {
    global exmh
    if {[string length $exmh(command)] == 0} {
	return
    }
    set t $exmh(log)
    $t insert end $exmh(command)\n
    update idletasks
    if [catch {uplevel #0 $exmh(command)} result] {
	global errorInfo
	$t insert end "ERROR\n$errorInfo\n\n"
    } else {
	$t insert end $result\n\n
    }
    $t see end
}
