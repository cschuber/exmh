# env.tcl
#
# Grab things from the environment
#
# Copyright (c) 199 Sun Microsystems
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Sun Microsystems
# makes no warranty about the software, its performance or its conformity to
# any specification.

# Env_Init sets up:
#	MHCONTEXT	to give exmh a private MH context file
#	USER		to avoid dealing with LOGNAME
#	TMPDIR		to allow retargeting /tmp
#	PATH		to make sure the MH programs are on the path

proc Env_Init {} {
    global env

    # Use an alternate context to avoid conflict with command line MH
    # This has to be the same as used by exmh so that private sequences work
    # right.
    set env(MHCONTEXT) .exmhcontext

    # Merge LOGNAME into USER so we only need to look for one later
    if [catch {set env(USER)} user] {
	if [catch {set env(LOGNAME)} user] {
	    puts stderr "No USER or LOGNAME envar"
	    set user ""
	}
	set env(USER) $user
    }

    # Init TMPDIR

    if {[info exists env(EXMHTMPDIR)]} {
	set env(TMPDIR) $env(EXMHTMPDIR)
    }
    if {![info exists env(TMPDIR)]} {
	set env(TMPDIR) /tmp/$env(USER)
    }

    # Make sure MH is on the path
    global mh_path
    set hit 0
    foreach dir [split $env(PATH) :] {
	if {[string compare $dir $mh_path] == 0} {
	    set hit 1
	    break
	}
    }
    if {! $hit} {
	set env(PATH) $mh_path:$env(PATH)
    }

}

proc Env_Tmp {} {
    global env

    # Doing this every time we use the temp file directory ensures
    # no-one steals it without the user knowing it.

    if {[catch {
	file mkdir $env(TMPDIR)
	file attributes $env(TMPDIR) -permissions 0700
    } err]} {
	puts $err
	catch {puts stderr "WARNING: exmh using unsafe /tmp directory"}
	Exmh_Status "WARNING: exmh using unsafe /tmp directory" red
	set env(TMPDIR) /tmp
    }

    return $env(TMPDIR)
}

