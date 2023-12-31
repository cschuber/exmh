# pop.tcl
# POP3 support for exmh

proc Pop_GetPassword {host} {
    global pop
    if {[info exist pop($host,password)]} {
	set pop(password) $pop($host,password)
	return
    }
    if {[file exists ~/.netrc]} {
	if {[catch {open ~/.netrc} in]} {
	    Exmh_Status "Warning - can't read ~/.netrc: $in"
	} else {
	    set X [read $in]
	    set tokens {}
	    foreach token [split $X] {
		if {[string length $token] == 0} {
		    continue
		}
		lappend tokens $token
	    }
	    set state nohost
	    foreach {key value} $tokens {
		switch $state {
		    nohost {
			if {[string compare $key machine] == 0 &&
				[string compare $value $host] == 0} {
			    set state gothost
			}
		    }
		    gothost {
			if {[string compare $key machine] == 0} {
			    break	;# Done with this host
			}
			set pop($host,$key) $value
		    }
		}
	    }
	}
	# See if the .netrc has values already
	if {[info exist pop($host,password)]} {
	    set pop(password) $pop($host,password)
	    return
	}
    }

    # Nothing in .netrc - prompt the user, and save the info if desired

    Pop_Dialog $host
}

proc Pop_Dialog {host} {
    global pop
    set t .pop
    set but .pop.but
    if {[Exwin_Toplevel $t "POP3 Mail Login [tk appname]" Pop]} {
	label $t.label -text "Enter your user ID and password for\nMail server $host"
	pack $t.label -side top -fill x
	Widget_BeginEntries
	Widget_LabeledEntry $t.user UserID pop($host,login)
	Widget_LabeledEntry $t.pass Password pop($host,password)
	$t.pass.entry config -show *
	# Focus on password as the common case, unless we don't know login
	if {[string length $pop($host,login)] == 0} {
	    focus $t.user.entry
	} else {
	    focus $t.pass.entry
	}
	Widget_AddBut $but ok "OK" {PopOK} {left padx 1 filly}
	bind $t <Destroy> {set pop(done) 0}
	bind $t.user.entry <Return> "focus $t.pass.entry ; break"
	bind $t.pass.entry <Return> "PopOK"
    }
    set pop(done) 0
    vwait pop(done)

    # Destroy this out because it is specific to a host, and they
    # might have multiple hosts.

    destroy $t

    set pop(password) $pop($host,password)
}

proc PopOK {} {
    global pop
    set pop(done) 1
    wm withdraw .pop
}
