# pgpInterface.tcl -- 
# created by monnier@didec26.epfl.ch on Mon Dec 12 17:34:38 1994

# 
# 
# 

# $Log$
# Revision 1.4  1999/06/10 16:59:18  cwg
# Re-enabled the timeout of PGP passwords
#
# Revision 1.3  1999/05/04 06:35:38  cwg
# Fixed crash when aborting out of PGP Password window
#
# Revision 1.2  1999/04/10 04:20:08  cwg
# Do the right thing if pgp(seditpgp) is not enabled.
#
# Revision 1.1  1998/05/05 17:55:37  welch
# Initial revision
#
# Revision 1.1  1998/05/05 17:42:59  welch
# Initial revision
#
# Revision 1.11  1998/01/22  00:45:06  bwelch
#     Hack to use aixterm for PGP.
#
# Revision 1.10  1997/12/22  20:52:00  bwelch
# file delete
#
# Revision 1.9  1997/07/25  17:13:23  bwelch
# Fixed pattern match to handle PGP 5.0 date format.
#
# Revision 1.8  1997/07/12  23:05:12  bwelch
#     Fixed PGP key extraction from the web servers.
#     Fixed handling of failed signatures so you still see the message.
#
# Revision 1.7  1997/06/03  18:29:55  bwelch
# Added PGP grab-focus and use-expecttk options.
# Removed +keepbinary=off flag from PGP uses.
# PGP bin directory is added to the front of PATH, if necessary
#
# Revision 1.6  1997/01/25  05:29:23  bwelch
#     Tweaked PgpExec_KeyList that returns a list of keys.
#     Tweaked patterns on PGP output.
#     Added Pgp_ShortenOutput
#
# Revision 1.5  1996/12/21  00:57:12  bwelch
# Log errors from PGP key extraction
#
# Revision 1.4  1996/12/01  20:13:59  bwelch
# Added Pgp_InterpretOutput
# Added timeouts on password caching.
#
# Revision 1.3  1996/03/22  18:42:54  bwelch
# Added Mh_Rename
# .
#
# Revision 1.2  1995/05/24  05:58:04  bwelch
# Updates from Stefan
#
# Revision 1.1  1995/05/19  17:36:16  bwelch
# Initial revision
#
# Revision 1.2  1995/03/22  19:14:21  welch
# More new code from Stefan
#
# Revision 1.1  1994/12/30  21:49:00  welch
# Initial revision
#
# Revision 1.1  1994/12/17  20:19:16  monnier
# Initial revision
#

# execs pgp with the usual flags
proc PgpExec { arglist outvar {privatekey {}} {interactive 0} } {
    upvar $outvar output
    global pgp env

    #puts "<PgpExec> $arglist $outvar $privatekey $interactive"
    
    if {! $pgp(enabled)} {
	error "<PGP> pgp isn't enabled"
    }
    set output {}

    if {!$pgp(keeppass)} {
	Pgp_ClearPassword
    }

    if {$interactive || !($pgp(keeppass) || ($privatekey == {}))} {
	return [PgpExec_Interactive $arglist output]
    } else {
	if {$privatekey == {}} {
	    return [PgpExec_Batch $arglist output]
	} else {
	    set p [Pgp_GetPass $privatekey]
	    if {[string length $p] == 0} {
		return 0
	    }
	    return [PgpExec_Batch $arglist output $p]
	}
    }
}

#
proc PgpExec_Batch { arglist outvar {password {}} } {
    upvar $outvar output
    global pgp env

    # pgp 4.0 command doesn't like the +keepbinary=off option
    set tclcmd [concat \
	    [list exec pgp +armorlines=0 +batchmode=on +verbose=0 +pager=cat] \
	    $arglist]

    if {$password == {}} {
	catch { unset env(PGPPASSFD) }
    } else {
	lappend tclcmd << $password
	set env(PGPPASSFD) 0
    }
    Exmh_Debug $tclcmd
    set result [catch $tclcmd output]
    regsub -all "\x07" $output "" output

    catch { unset env(PGPPASSFD) }

    return $result
}

#
proc PgpExec_Interactive { arglist outvar } {
    global tcl_platform
    upvar $outvar output
    
    set args [concat [list +armorlines=0 +keepbinary=off] $arglist]
    set shcmd "unset PGPPASSFD;
        pgp \"[join [Misc_Map x {
	    regsub {([$"\`])} $x {\\1} x
	    set dummy $x
        } $args] {" "}]\";
	echo
	echo press Return...;
        read dummy"

    set logfile [Mime_TempFile "xterm"]
    if { ( $tcl_platform(os) == "AIX" ) && [ file executable "/usr/bin/X11/aixterm" ] } {
        set xterm "aixterm"
    } else {
        set xterm "xterm"
    }
    set tclcmd {exec $xterm -l -lf $logfile -title PGP -e sh -c $shcmd}
    Exmh_Debug $tclcmd
    set result [catch $tclcmd]
    if [catch {open $logfile r} log] {
	set output {}
    } else {
	set output [read $log]
	close $log
    }

    # clean up the output
    regsub -all "\[\x0d\x07]" $output {} output
    regsub "^.*\nEnter pass phrase:" $output {} output
    regsub "\nPlaintext filename:.*" $output {} output
    regsub "^.*Just a moment\\.\\.+" $output {} output
    regsub "^.*Public key is required \[^\n]*\n" $output {} output
    set output [string trim $output]

    return $result
}

#
proc PgpExec_CheckPassword { password key } {

    set tmpfile [Mime_TempFile "pwdin"]
    set outfile [Mime_TempFile "pwdout"]

    set out [open $tmpfile w 0600]
    puts $out "salut"
    close $out
    
    PgpExec_Batch [list -as $tmpfile -o $outfile -u [lindex $key 0]] err $password
    File_Delete $tmpfile

    # pgp thinks he knows better how to name files !
    if {![file exists $outfile] && [file exists "$outfile.asc"]} {
	Mh_Rename "$outfile.asc" $outfile
    }
    if {![file exists $outfile]} {
	if {![regexp "PGP" $err]} {
	    # Probably cannot find pgp to execute.
	    Exmh_Status !${err}!
	    error "<PGP> can't find pgp"
	} else {
	    if [regexp {(Error:[^\.]*)\.} $err x match] {
		Exmh_Status ?${match}?
	    }
	    ExmhLog "<Pgp_GetPass> $err"
	}
	return 0
    } else {
	File_Delete $outfile
	return 1
    }
}

# wrapper for 'pgp -kv $pattern $keyring'
# returns a list of keys. Each "key" is a list whose first element is the keyID
# and the next ones are the corresponding userids
proc PgpExec_KeyList { pattern keyring } {

    set pattern [string trimleft $pattern "<>|2"]
    PgpExec_Batch [list -kv $pattern $keyring] keylist

    # drop the revoked keys
    regsub -all "\n(pub|sec) \[^\n]+\\*\\*\\* KEY REVOKED \\*\\*\\*(\n\[\t ]\[^\n]+)+" $keylist "" keylist

    if { ![regexp {.*(pub|sec) +[0-9]+(/| +)([0-9A-F]+) +[0-9]+/ ?[0-9]+/ ?[0-9]+ +(.*)} $keylist]} {
	return {}
    } else {
	set keylist [split $keylist "\n"]
	set keys {}
	set key {}
	foreach line $keylist {
            if [regexp {^ *(pub|sec) +[0-9]+(/| +)([0-9A-F]+) +[0-9]+/ ?[0-9]+/[0-9]+ +(.*)$} $line {} {} {} keyid userid] {
		set key [list "0x$keyid" [string trim $userid]]
		lappend keys $key
	    }
	}
	return $keys
    }
}

proc PgpSetPath {} {
    global pgp env
    if {[info exists pgp(path)] && \
	    ([string length [string trim $pgp(path)]] > 0) && \
	    ([lsearch -exact [split $env(PATH) :] $pgp(path)] < 0)} {
	set env(PATH) $pgp(path):$env(PATH)
    }
}

proc PgpExec_Init {  } {
    global pgp pgpConfig pgpPass env

    PgpSetPath

    if {![info exists env(LOCALHOST)]} {
	if [catch {exec uname -n} env(LOCALHOST)] {
	    set env(LOCALHOST) localhost
	}
    }

    set pgpPass() {}

    PgpExec_ParseConfigTxt $pgp(pgppath)/config.txt pgpConfig
    
    set pgp(secring) $pgp(pgppath)/secring.pgp
    if {![file exists $pgp(secring)]} { set pgp(secring) {} }

    set pgp(privatekeys) [PgpExec_KeyList "" $pgp(secring)]
    
    if [info exists pgpConfig(myname)] {
	set myname [string tolower $pgpConfig(myname)]
	foreach key $pgp(privatekeys) {
	    if {[string first $myname [string tolower $key]] >= 0} {
		set pgp(myname) $key
		break
	    }
	}
	if {![info exists pgp(myname)]} {
	    if [catch {PgpMatch_Simple $pgpConfig(myname) $pgp(pubring)} key] {
		Misc_DisplayText "PGP Init" "the name specified in your config.txt file\ncouldn't be unambiguously found in your key rings !"
		set pgp(myname) {}
	    } else {
		set pgp(myname) [lindex $key 0]
	    }
	}
    } else {
	set pgp(myname) [lindex $pgp(privatekeys) 0]
    }
#    PgpMatch_Init
}

#
proc PgpExec_ParseConfigTxt { file configarray } {
    upvar $configarray config

    if [catch {open $file r} in] {
	return
    }

    for {set len [gets $in line]} {$len >= 0} {set len [gets $in line]} {
	if [regexp -nocase "^\[ \t]*(\[a-z]+)\[ \t]*=(\[^#]*)" $line {} option value] {
	    set config([string tolower $option]) [string trim $value " \t\""]
	}
    }
    close $in
}

#
proc PgpExec_Encrypt { in out tokeys } {

    PgpExec_Batch [concat [list -aet $in -o $out] [Misc_Map key {lindex $key 0} $tokeys]] output

    # pgp thinks he knows better how to name files !
    if {![file exists $out] && [file exists "$out.asc"]} {
	Mh_Rename "$out.asc" $out
    }
    if {![file exists $out]} {
	error "PGP refused to generate the encrypted text:\n$output"
    } else {
	return {}
    }
}

#
proc PgpExec_EncryptSign { in out sigkey tokeys } {

    PgpExec [concat [list -aset $in -o $out -u [lindex $sigkey 0]] [Misc_Map key {lindex $key 0} $tokeys]] output $sigkey

    # pgp thinks he knows better how to name files !
    if {![file exists $out] && [file exists "$out.asc"]} {
	Mh_Rename "$out.asc" $out
    }
    if {![file exists $out]} {
	error "PGP refused to generate the encrypted signed text:\n$output"
    } else {
	return {}
    }
}

#
proc PgpExec_Sign { in out sigkey clear } {

    if $clear {
	set clear "+clearsig=on"
    } else {
	set clear "+clearsig=off"
    }
    PgpExec [list $clear -ast $in -u [lindex $sigkey 0] -o $out] output $sigkey

    # pgp thinks he knows better how to name files !
    if {![file exists $out] && [file exists "$out.asc"]} {
	Mh_Rename "$out.asc" $out
    }
    if {![file exists $out]} {
	error "PGP refused to generate the signed text:\n$output"
    } else {
	return {}
    }
}

#
proc PgpExec_Decrypt { in out outvar recipients } {
    global pgp pgpPass
    upvar $outvar output

    set recipients [string tolower $recipients]
    set useablekeys [Misc_Filter key {[string first [string tolower [string range [lindex $key 0] 2 end]] $recipients] >= 0} $pgp(privatekeys)]
    set knownkeys [Misc_Filter key {[info exists pgpPass([lindex $key 0])]} $useablekeys]

    if {[llength $knownkeys] > 0} {
	set key [lindex $knownkeys 0]
    } elseif {[llength $useablekeys] > 0} {
	set key [lindex $useablekeys 0]
    } else {
	set key {}
    }
    PgpExec [list $in -o $out] output $key
}

# This is called if expectk is enabled.  It seemed the best (easiest
# for me) way to do it was to have this proc terminate when the
# message is finished displaying just as PgpExec_Decrypt would do.
# However, this is a problem for the the expectk script
# (PgpDecryptExpect), which may need to communicate with exmh to ask
# for passwords, etc.  

# My slow and inelegant solution was to tell exmh-bg all the necessary
# information and let PgpDecryptExpect communicate with exmh-bg,
# exiting when done.

proc PgpExec_DecryptExpect { infile outfile msgvar } {
    global exmh pgp getpass exwin pgpPass sedit
    upvar $msgvar msg

    # First update exmh-bg arrays.  I hope that pgp, getpass, 
    # pgpPass, and exwin will be enough.  For exwin seems we have
    # to temporarily change the mtext error to avoid an error when
    # the password window is closed and focus is returned to .msg.t

    send $exmh(bgInterp) [list array set pgp [array get pgp]]
    send $exmh(bgInterp) [list array set getpass [array get getpass]]
    send $exmh(bgInterp) [list array set sedit [array get sedit]]
    send $exmh(bgInterp) [list array set pgpPass [array get pgpPass]]
    send $exmh(bgInterp) [list array set exwin [array get exwin]]
    send $exmh(bgInterp) [list set exwin(mtext) .]

    if [catch {exec $exmh(expectk) -f $exmh(library)/PgpDecryptExpect \
		   $infile $outfile $exmh(bgInterp)}] {
	Exmh_Status "Error executing expect process" warn
    }

    set msg [lindex [send $exmh(bgInterp) {list $pgpmsg}] 0]
    send $exmh(bgInterp) [list unset pgpmsg]

    # Now reload pgpPass and exwin from exmh-bg
    array set pgpPass [send $exmh(bgInterp) array get pgpPass]

    # The following appears no longer to be necessary, but now I don't see
    # how to change the position of the getpass window
    #
    #    set exwin(geometry,.getpass) \
    #	   [send $exmh(bgInterp) list {$exwin(geometry,.getpass)}]

    send $exmh(bgInterp) [list unset pgpPass]
}

#
proc Pgp_GetPass { key } {
    global pgp pgpPass

    if {[lsearch -glob $pgp(privatekeys) "[lindex $key 0]*"] < 0} {
	return {}
    }

    set keyid [lindex $key 0]
    if {[info exists pgpPass($keyid)] && [string length $pgpPass($keyid)]} {
	return $pgpPass($keyid)
    }
    while 1 {
	if [catch {Misc_GetPass "Enter PGP password" "password for [lindex $key 1]"} password] {
	    Exmh_Debug "Aborting out of Misc_GetPass: $password"
	    return {}
	} elseif {[PgpExec_CheckPassword $password $key]} {
	    if $pgp(keeppass) {
		set pgpPass($keyid) $password
		Pgp_SetPassTimeout $keyid
	    }
	    return $password
	}
    }
}

proc Pgp_SetPassTimeout {keyid} {
    global pgp pgpPass

    if [info exists pgp(timeout,$keyid)] {
	Exmh_Debug "Cancelling previous timeout for $keyid"
	after cancel $pgp(timeout,$keyid)
	unset pgp(timeout,$keyid)
    }
    Exmh_Debug "Setting timeout for $keyid in $pgp(passtimeout) minutes"
    set pgp(timeout,$keyid) \
	    [after [expr $pgp(passtimeout) * 60 * 1000] \
	           [list Pgp_ClearPassword $keyid]]
}

proc Pgp_ClearPassword {{keyid {}}} {
    global pgpPass
    Exmh_Debug "Clearing password for $keyid"
    if {[string length $keyid] == 0} {
	catch {unset pgpPass}
	set pgpPass() {}
    } else {
	set pgpPass($keyid) {}
    }
}
#
proc PgpExec_ExtractKeys { file {interactive 1} } {
    global env

    set output {}
    if [PgpExec [list -ka $file] output {} $interactive] {
	Exmh_Status "Key extract failed"
	Exmh_Debug $output
	return 0
    } else {
	Exmh_Debug $output
	return 1
    }
}

#
proc PgpExec_GetKeys { keyid file } {
    if [PgpExec [list -akx $keyid $file] msg] {
	error $msg
    } else {
	# pgp thinks he knows better how to name files !
	if {![file exists $file] && [file exists "$file.asc"]} {
	    Mh_Rename "$file.asc" $file
	}
	if {![file exists $file]} {
	    error "PGP refused to generate the key block for $keyid"
	}
    }
}

proc Pgp_InterpretOutput { in outvar } {

    # This function is supposed to take the output given by the other
    # pgp exec procedures and writes different information to the
    # given array.  It is probably best to put all the code that
    # change from PGP version to version in a single place.  This is
    # based on 2.6.2

    global pgp
    upvar $outvar pgpresult

    Exmh_Debug "PGP Output:\n$in"
    regexp {(.*)child process exited abnormally} $in {} in
    set in [string trim $in]

    set pgpresult(ok) 1
    regexp -nocase {key id ([0-9a-f]+)} $in {} pgpresult(keyid)
    if [regexp {This.*do not have the secret key.*file.} $in \
	    pgpresult(msg)] {
	set pgpresult(summary) "SecretMissing"
	set pgpresult(ok) 0
    } elseif [regexp {Can't.*can't check signature integrity.*} $in \
		  pgpresult(msg)] {
	set pgpresult(summary) "PublicMissing"
	set pgpresult(ok) 1
    } elseif [regexp {Good signature.*} $in pgpresult(msg)] {
	if [regexp {WARNING:.*confidence} $pgpresult(msg)] {
	    set pgpresult(summary) "GoodSignatureUntrusted"
	} else {set pgpresult(summary) "GoodSignatureTrusted"}
    } elseif [regexp {WARNING:.*doesn't match.*} $in \
		  pgpresult(msg)] {
	if [regexp {WARNING:.*confidence.*} $pgpresult(msg)] {
	    set pgpresult(summary) "BadSignatureUntrusted"
	} else {set pgpresult(summary) "BadSignatureTrusted"}
    } elseif [regexp {ERROR} $in \
		  pgpresult(msg)] {
	set pgpresult(summary) "UnknownError"
	set pgpresult(msg) $in
	set pgpresult(ok) 0
    } else {
	set pgpresult(summary) "Other"
	set pgpresult(msg) $in
    } 

    # DecryptExpect sometimes notifies the user that the
    # file is not encrypted.
    
    if [regexp {Note: File may not have been encrypted} $in] {
	set pgpresult(msg) \
	    "Note: File may not have been encrypted.\n\n$pgpresult(msg)"
    }

    Exmh_Debug OK=$pgpresult(ok) $pgpresult(summary)

    if $pgp(shortmsgs) {
	set pgpresult(msg) [Pgp_ShortenOutput $pgpresult(msg) \
				$pgpresult(summary)]
    }
}

proc Pgp_ShortenOutput { pgpresult summary } {
    
    regexp {user ("[^"]*")} $pgpresult {} user

    switch $summary {
       SecretMissing {return "Cannot decrypt, missing secret key."}
       PublicMissing {return "Missing public key."}
       GoodSignatureUntrusted {return "Good untrusted signature from $user."}
       GoodSignatureTrusted {return "Good trusted signature from $user."}
       BadSignatureTrusted {return "WARNING: Bad trusted signature \
		from $user."}
       BadSignatureUntrusted {return "WARNING: Bad untrusted signature \
		from $user."}
       UnknownError {return "PGP Error while processing message:\n$pgpresult"}
       Other {return $pgpresult}
    }
}

proc Pgp_CheckPoint {  } {
    foreach cmd { PgpMatch_CheckPoint } {
	if {[info command $cmd] != {}} {
	    if [catch {$cmd} err] {
		puts stderr "$cmd: $err"
	    }
	}
    }
}
