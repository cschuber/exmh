# report.tcl
#
# Bug reporting and user registration
#
# Copyright (c) 1994 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Report_Bug {} {
    global mhProfile exmh tk_version

    set draft [Mh_Path $mhProfile(draft-folder) new]
    if [catch {open $draft w} out] {
	Exmh_Status "Cannot write $draft"
	return
    }
    Report_UseComp $out
    puts $out "To: $exmh(maintainer)"
    puts $out "Subject: exmh bug"
    puts $out "------"
    puts $out "$exmh(version)"
    catch {puts $out [exec uname -a]}
    puts $out "Tk $tk_version Tcl [info tclversion]"
    close $out
    Edit_DraftID [file tail $draft]
}
proc Report_Registration {} {
    global mhProfile exmh env tcl_version tcl_patchLevel

    set draft [Mh_Path $mhProfile(draft-folder) new]
    if [catch {open $draft w} out] {
	Exmh_Status "Cannot write $draft"
	return
    }
    Report_UseComp $out
    puts $out \
"To: welch@acm.org
Subject: Register exmh user
-----
$exmh(version) $env(USER)
[exec uname -a]
Tcl $tcl_patchLevel

>   Please register as an exmh user so I can more accurately
>   track the usage of exmh.  I will not use your email address
>   for any purpose other than to display a cool gif in my
>   exmh face canvas.  Any and all comments are appreciated.
>
>   If you have registered for an earlier release you need not
>   register again, unless you want to, of course.
>
>	Brent Welch <welch@acm.org>


Please comment on exmh:

I like exmh because...

I don't really like...
"
    close $out
    Edit_DraftID [file tail $draft]
}
proc Report_Subscribe {list what} {
    global mhProfile exmh

    set draft [Mh_Path $mhProfile(draft-folder) new]
    if [catch {open $draft w} out] {
	Exmh_Status "Cannot write $draft"
	return
    }
    Report_UseComp $out
    puts $out "To: $list-request@redhat.com"
    puts $out "Subject: $what"
    puts $out "------"
    puts $out "$what $list"
    puts $out "--"
    puts $out "$exmh(version)"
    close $out
    Edit_DraftID [file tail $draft]
}

proc Report_UseComp {out} {
    global mhProfile

    set cfile "components"
    if [info exists mhProfile(comp)] {
	# ugly regexp, but it works.
	if [regsub -- {.*-form[[:space:]]*([^[:space:]]*).*} $mhProfile(comp) {\1} profcomp] {
	    set cfile $profcomp
	}
    }
    set compfile "$mhProfile(path)/$cfile"
    if {![catch {open $compfile r} in]} {
	set comps [read $in]
	close $in
	# Now copy over the components, but swallow to/subject/cc....
	foreach line [split $comps \n] {
	    if ![regexp {^To:|^Subject:|^[Cc][Cc]:|^-----|^$} $line] {
		puts $out $line
	    }
	}
    }
}
