# pgpMisc.tcl -- 
# created by monnier@didec26.epfl.ch on Sat Nov 26 11:06:33 1994

# 
# miscellanous functions used by pgp*.tcl
# 

# todo:

# $Log$
# Revision 1.4  1999/04/04 20:34:57  cwg
# Removed dead code which only ran in pre tk-4.1 versions.
#
# Revision 1.3  1999/04/01 15:38:10  cwg
# Bug fix.  Wasn't working for people with PGP disabled.
#
# Revision 1.2  1999/03/26 08:41:55  cwg
# Changes to PGP interface to use preferences variables instead of
# message headers.  Also, reorganize the "PGP..." menu and rename it
# "Crypt..."
#
# See the "PGP interface" preferences page for more info.
#
# Revision 1.1  1998/05/05 17:55:38  welch
# Initial revision
#
# Revision 1.1  1998/05/05 17:43:00  welch
# Initial revision
#
# Revision 1.8  1998/01/22  00:50:15  bwelch
#     Fixed handling of PGP header to deal with 4.0 better
#
# Revision 1.7  1997/06/03  18:45:54  bwelch
# Nuke PGP password window to avoid window manager bugs.
#
# Revision 1.6  1997/01/25  05:37:24  bwelch
# Added echo password * option
#
# Revision 1.5  1996/12/21  00:59:53  bwelch
# Wrap visibility calls
#
# Revision 1.4  1996/12/01  20:19:54  bwelch
# Cleanup
#
# Revision 1.3  1995/06/30  18:33:59  bwelch
# Added Pgp_FixHeader to update headers
#
# Revision 1.3  1995/06/30  18:33:59  bwelch
# Added Pgp_FixHeader to update headers
#
# Revision 1.2  1995/05/25  21:03:21  bwelch
# Added Widget_BindEntryCmd
#
# Revision 1.1  1995/05/24  23:01:46  bwelch
# Initial revision
#
# Revision 1.4  1995/04/15  18:39:12  welch
# Fixed handling of Shift key in PGP password entry.
#
# Revision 1.3  1995/03/22  19:20:54  welch
# More new code from Stefan
#
# Revision 1.2  1995/02/17  06:34:44  welch
# Split Misc_PostProcess into Misc_CheckAction and Misc_PostProcess
#
# Revision 1.1  1994/12/30  21:49:00  welch
# Initial revision
#
# Revision 1.1  1994/12/17  20:19:02  monnier
# Initial revision
#

# creates the file and put the string in it
proc Misc_StringFile { str filename } {
    set file [open $filename w 0600]
    puts -nonewline $file $str
    close $file
}

# returns a string containing the whole file's content
proc Misc_FileString { filename } {
    set file [open $filename r]
    set result [read $file]
    close $file
    return $result
}

# unsign a pgp clearsigned message (take the pgp stuff out)
proc Pgp_Unsign { text } {
    if {![regexp "^(.*\n)?-+BEGIN PGP SIGNED\[^\n]*\n(Hash:\[^\n]*\n)?\n(.*)\n-+BEGIN PGP SIGNATURE" $text {} {} {} text]} {
#	error "<Misc_Unsign> can't find the message"
# it is inconvenient and probably wrong to eat the message
	return "Error in stripping PGP armor:\n$text"
    }
    regsub "^- " $text {} text
    regsub -all "\n- " $text "\n" text
    return "$text"
}

# returns a list of integers from $x to $y-1
proc Misc_IntList { x y } {
    for {set result {}} {$y > $x} {set x [expr $x + 1]} {
	lappend result $x
    }
    return $result
}

# returns a list containing every element of $list that fulfills
# the requirement of cond(var)
proc Misc_Filter { var cond list } {
    upvar $var elem

    set result {}

    foreach elem $list {
	if [uplevel expr "{" $cond "}"] {
	    lappend result $elem
	}
    }
    return $result
}

# like filter, but returns a list of 2 lists. The first containing
# the elements fulfilling the requirement, the second those that don't
proc Misc_Segregate { var cond list } {
    upvar $var elem

    set fulfill {}
    set dont {}

    foreach elem $list {
	if [uplevel expr "{" $cond "}"] {
	    lappend fulfill $elem
	} else {
	    lappend dont $elem
	}
    }
    return [list $fulfill $dont]
}

# applies expr on each elem and returns the resulting list
proc Misc_Map { var expr list } {
    upvar $var elem

    set result {}

    foreach elem $list {
	lappend result [uplevel $expr]
    }
    return $result
}

# returns the list reversed
proc Misc_Reverse { list } {
    set result {}
    foreach elem $list {
	set result [linsert $result 0 $elem]
    }
    return $result
}

# asks for a password in a window called $title with a little note $label
proc Misc_GetPass { title label } {
    global getpass pgp
    set w .getpass

    if [Exwin_Toplevel $w $title Dialog no] {
	
	set getpass(entry) $w.pass.entry
	set getpass(ok) $w.but.ok
	set getpass(cancel) $w.but.cancel
	
	Widget_Frame $w but Menubar {top fill}
	Widget_AddBut $w.but ok OK {
	    set getpass(state) "ok"
	} {left padx 1}
	Widget_AddBut $w.but cancel Cancel {
	    set getpass(state) "cancel"
	} {right padx 1}
	Widget_Label $w label {filly}
	Widget_Frame $w pass sframe {expand fillx} -bd 10
	Widget_Entry $w.pass entry {expand fillx} \
		-state normal -relief sunken -width 64
    }
    $w.label configure -text $label
    $w.pass.entry delete 0 end
    set getpass(pass) {}

    Widget_BindEntryCmd $getpass(entry) <Return> {
	set getpass(state) "ok"
    }
    # Override bindtags done by Widget_BindEntryCmd
    bindtags $getpass(entry) $getpass(entry)
    SeditBind $getpass(entry) backspace {
	global getpass
	if $pgp(echopass) {
	    $getpass(entry) delete [expr [$getpass(entry) index end]-1] end
	}
	set getpass(pass) [string range $getpass(pass) 0 [expr [string length $getpass(pass)]-2]]
    }
    bind $getpass(entry) <Any-Key> {
	global getpass
	if {"%A" != "" && "%A" != "{}"} {
	    if $pgp(echopass) {
		$getpass(entry) insert insert "*"
	    }
	    append getpass(pass) "%A"
	}
    }
    bind $getpass(entry) <Control-U> {
	global getpass
	$w.pass.entry delete 0 end
	set getpass(pass) {}
    }
    Visibility_Wait $w
    update idletasks
    if $pgp(grabfocus)  {
	grab -global $w
    }
    focus $getpass(entry)
    tkwait variable getpass(state)
    Exmh_Focus
    # Forget window locaton  to avoid problems in virtual root window managers
    destroy $w	
    set password $getpass(pass)
    unset getpass(pass)
    
    if {$getpass(state) == "cancel"} {
	error "cancel"
    }
    
    return $password
}

#
proc Misc_DisplayText { title text {height 8}} {
    global mhProfile exmh msg exwin

    if ![info exists msg(tearid)] {
	set msg(tearid) 0
    } else {
	incr msg(tearid)
    }
    set self [Widget_Toplevel .tear$msg(tearid) $title Clip]

    Widget_Frame $self but Menubar {top fill}
    Widget_AddBut $self.but quit "Dismiss" [list destroy $self]
    #Widget_Label $self.but label {left fill} -text $exmh(folder)/$msg(id)
    set t [Widget_Text $self 8 -cursor xterm -setgrid true]
    $t configure -height $height
    $t insert 1.0 $text
}

# gets the whole header of the draft. Returns a list of strings.
# Each multi-line header is put back into a single string (with embedded \n)
proc Misc_GetHeader { in } {
    global miscRE

    set headers {}
    set hdr {}

    for {set len [gets $in line]} \
	    {($len >= 0) && (![regexp $miscRE(headerend) $line])} \
	    {set len [gets $in line]} {
	if [regexp "^\[ \t]+(.*)\$" $line {} content] {
	    append hdr "\n$line"
	} elseif [regexp {^([^ :]*):(.*)$} $line {} header content] {
	    lappend headers $hdr
	    set hdr "[string tolower $header]:$content"
	}
    }
    lappend headers $hdr
    return [lrange $headers 1 end]
}

#
proc Misc_PostProcess { srcfile } {
    global mhProfile pgp pgpPass

    set dstfile [Mh_Path $mhProfile(draft-folder) new]
    set curfile $srcfile

    # read the header to see what postprocessing has to be done
    set in [open $curfile r]
    set mailheader [Misc_GetHeader $in]
    close $in

    # call the pgp postprocesing if necessary
    if {$pgp(enabled) && $pgp(seditpgp)} {
	set keyid [lindex $pgp(myname) 0]
	Exmh_Debug keyid=$keyid
	Exmh_Debug pass=>$pgpPass($keyid)<
	if {($pgp(encrypt) || $pgp(sign)) && ([string length $pgpPass($keyid)] > 0)} {
	    Pgp_Process $curfile $dstfile
	    set curfile $dstfile
	}
    }

    return [file tail $curfile]
}

#
proc Misc_Send { to subject {bodyfile {}} {headers {}} } {
    global mhProfile

    MhExec comp -nowhatnowproc
    set msg [Mh_Cur $mhProfile(draft-folder)]

    # read the default mail header
    set in [open "$mhProfile(path)/$mhProfile(draft-folder)/$msg" r]
    set header [Misc_GetHeader $in]
    close $in

    # write it back with a new to and subject fields
    set out [open "$mhProfile(path)/$mhProfile(draft-folder)/$msg" w 0600]
    foreach line $header {
	if {![regexp -nocase {^(to|subject):} $line]} {
	    puts $out $line
	}
    }
    puts $out "To: $to\nSubject: $subject\nMime-Version: 1.0\n$headers\n"

    # add the body if any
    if {$bodyfile != {}} {
	set in [open $bodyfile r]
	puts -nonewline $out [read $in]
    }

    close $out

    Mh_Send $msg
}
proc Pgp_FixHeader { line } {
    if [regexp {^([^:]+):(.*)} $line x key value] {
	set newline {}
	while {[regexp {([^-]+)-(.*)} $key  x first rest]} {
	    append newline [string toupper [string index $first 0]] \
			    [string tolower [string range $first 1 end]] -
	    set key $rest
	}
	append newline [string toupper [string index $key 0]] \
			[string tolower [string range $key 1 end]] : $value
	return $newline
    } else {
	return $line
    }
}
