#
# pgp.tcl
#	PGP 2.6 support for exmh.
#	Orginally contributed by Allan Downey
#	Updated by Stefan Monnier, Anders Klemets, William Sproule,
#	Chris Garrigues and Ben Escoto
#

# future:
# - rewrite PGP decrypt, to deal with keys, mime stuff, etc...
# - encrypt pgp parts, similar to the automatic quote-printable
# - split big functions
# - drop misc_displaytext
# - add a "init PGP" command
# - add some key handling commands
# - keep track of who has your private key (for revocation purposes)

# Pgp_Init is in extrasInit.tcl
# to avoid auto-loading this whole file.

# $Log$
# Revision 1.6  1999/04/30 19:09:00  cwg
# Jan Peterson's multiple PGP key patch
#
# Revision 1.5  1999/04/20 21:46:17  cwg
# Is CVS working now?
#
# Revision 1.4  1999/04/15 23:41:59  cwg
# Make the crypt menu values be per-window instead of global.
#
# Revision 1.3  1999/03/29 20:49:20  cwg
# If doing a plain signature, disable usage of the pgp(mime) flag.
#
# Revision 1.2  1999/03/26 08:41:55  cwg
# Changes to PGP interface to use preferences variables instead of
# message headers.  Also, reorganize the "PGP..." menu and rename it
# "Crypt..."
#
# See the "PGP interface" preferences page for more info.
#
# Revision 1.1  1998/05/05 17:55:37  welch
# Initial revision
#
# Revision 1.1  1998/05/05 17:42:59  welch
# Initial revision
#
# Revision 1.16  1998/01/22  00:47:01  bwelch
#     Fixed Pgp_Setup to use /dev/tty instead of /dev/console
#
# Revision 1.15  1997/12/22  20:53:46  bwelch
# File_Delete
#
# Revision 1.14  1997/07/25  17:14:09  bwelch
# Trapped error messages from PGP xterms.
#
# Revision 1.13  1997/07/12  23:06:28  bwelch
#     Added expecttk support for PGP handling.
#     Fixed recursive failures with some PGP messages.
#
# Revision 1.12  1997/06/03  18:37:00  bwelch
# Added doinc flag to Inc_Presort
# Major cleanup
#
# Revision 1.11  1997/01/25  06:21:16  bwelch
# Added Quote module support
#
# Revision 1.10  1997/01/25  05:34:08  bwelch
#     Added Pgp_GetTextAttributes
# Changed display of PGP messages
#
# Revision 1.9  1996/12/21  00:58:08  bwelch
# Fixed PGP menu to support both email and www key fetching.
# Guard against missing signature parts in multipart/signed
#
# Revision 1.8  1996/12/02  21:11:11  bwelch
# Moved New Key button to be inside the help documents.
#
# Revision 1.7  1996/12/01  20:16:47  bwelch
# Added mutipart/security support.
# (Ben Escoto and Chris Garrigues)
#
# Revision 1.6  1996/03/22  18:44:34  bwelch
# Changed graphic part separator size in PGP from 5 to 6 to avoid
#     downloading a new font for this case.
#
# Revision 1.5  1995/09/28  04:11:10  bwelch
# Fixed "hasfcc" check in PGP.
#
# Revision 1.4  1995/06/30  18:32:40  bwelch
# Upcase PGP mail headers
#
# Revision 1.3  1995/06/09  20:57:06  bwelch
# Added ChoosePrivateKey
#
# Revision 1.2  1995/05/24  06:01:38  bwelch
# Added Pgp_SetMyName to choose private key name
#
# Revision 1.1  1995/05/24  01:48:03  bwelch
# Initial revision
#
# Revision 1.21  1995/04/15  18:17:01  welch
# Introduced msg(path)
#
# Revision 1.20  1995/03/22  22:17:30  welch
# Changed exmh.PGP.help to help.PGP
#
# Revision 1.19  1995/03/22  18:53:52  welch
# More new code from Stefan
#
# Revision 1.1  1994/12/17  20:18:49  monnier
# Initial revision
#

proc Pgp_Setup {  } {
    global pgp env

    PgpSetPath

    foreach path [split $env(PATH) ":"] {
	if [file executable "$path/pgp"] {
	    set pgpexec "$path/pgp"
	    break
	}
    }
    
    if {![info exists pgpexec]} {
	Misc_DisplayText "PGP Setup" \
"The PGP executable is not in your PATH.
You'll have to find it (or install it) before
I can do anything for you."
        return
    }

    # setup the directory
    set tmpfile [Mime_TempFile "pgp"]
    if {![info exists env(PGPPATH)]} {
	set env(PGPPATH) "$env(HOME)/.pgp"
    }
    catch { exec mkdir $env(PGPPATH) }
    exec touch "$env(PGPPATH)/config.txt"

    # make the key pair and self sign it
    if [catch {
	exec xterm -title "PGP Setup" -e sh -c {
	    cd ${PGPPATH}
	    rm -f pubring.bak
	    pgp -kg
	    rm -f pubring.bak
	    pgp +verbose=0 +force=on -ks "" -u ""
	} >& /dev/tty
    } error] {
	Misc_DisplayText "PGP Setup Error" \
"An error occurred while trying to generate your key:
$error
please try these commands at your unix shell
to generate your key and self sign it:
	pgp -kg
	pgp +verbose=0 +force=on -ks \"\" -u \"\"
Then restart exmh to enable its PGP support.
"
        return
    }

    if {![file exists "$env(PGPPATH)/pubring.bak"]} {
	return
    }

    # init the pgp support if necessary
    if {! $pgp(enabled)} {
	Pgp_Init
    } else {
	set pgp(secring) $pgp(pgppath)/secring.pgp
	set pgp(privatekeys) [PgpExec_KeyList "" $pgp(secring)]
    }

    # send the key to the keyservers
    PgpExec_GetKeys [lindex [lindex $pgp(privatekeys) 0] 0] $tmpfile
    Misc_Send $pgp(keyserver) ADD $tmpfile "content-type: application/pgp; format=keys-only"
    File_Delete $tmpfile
}

proc Pgp_Help {  } {
    Help PGP	;# Make Key button is embedded in the HTML
}
proc Pgp_HelpOld {} {
    global exmh
    set label "Help about setting up PGP"
    if [Exwin_Toplevel .pgphelp "PGP Help" PgpHelp] {
	Widget_Label .pgphelp.but label {left fill} -text $label
	Widget_AddBut .pgphelp.but setup "Make Key" [list Pgp_Setup]
    
	set t [Widget_Text .pgphelp 30 -setgrid true]
	Ftoc_ColorConfigure $t
	$t insert insert "EXMH Version: $exmh(version)\n\n"
	if [catch {open "$exmh(library)/help.PGP" r} in] {
	    $t insert insert "Cannot find file exmh.PGP.help to display"
	    $t configure -state disabled
	} else {
	    $t insert insert [read $in]
	}
    }
}

# display the message without keeping the decrypted form
proc Pgp_View { {file {}} } {
    global exmh msg exwin pgp

    if {$file == {}} { set file $msg(path) }

    if $pgp(keeppass) {
	PgpExec [list -m $file] message $pgp(myname)
	Misc_DisplayText "PGP view $exmh(folder)/$msg(id)" $message 40
    } else {
	PgpExec [list -m $file] message $pgp(myname)
    }

    return 1
}

# decrypt the current message
proc Pgp_Decrypt {  } {
    global exmh msg mhProfile exwin pgp

    set file $msg(path)
    set pgpfile [Mime_TempFile "decrypt"]

    Exmh_Status "pgp $exmh(folder)/$msg(id)"
    PgpExec [list $file -o $pgpfile] message $pgp(myname)
    if {$message != {}} {
	Misc_DisplayText "PGP decrypt $exmh(folder)/$msg(id)" $message
    }
    set t $exwin(mtext)

    set orig [open $file r]
    if [catch {
	set mess [open $pgpfile r]
    } err] {
	return 0
    }
    set outfile [Mime_TempFile "decypted"]
    set comb [open $outfile w 0600]

    while {[gets $orig line] != -1} {
	if {[regexp {^-+BEGIN PGP MESSAGE} $line]} {
	    puts -nonewline $comb [read $mess]
	    while {[gets $orig line] != -1} {
		if {[regexp {^-+END PGP MESSAGE} $line]} { break }
	    }
	} else {
	    puts $comb $line
	}
    }
    close $orig
    close $comb
    close $mess

    Mh_Rename $outfile $file
    File_Delete $pgpfile

    set msg(dpy) {}
    MsgChange $msg(id)

    return 1
}

# encrypts the current message with the user's key
proc Pgp_ExmhEncrypt {  } {
    global exmh msg mhProfile pgp

    set file $msg(path)
    set tmpfile [Mime_TempFile "encrypt"]

    Exmh_Status "pgp -e $exmh(folder)/$msg(id)"

    set pgp(param,recipients) [lindex $pgp(myname) 0]
    set id [SeditId $file]
    set pgp(encrypt,$id) 1;
    set pgp(sign,$id) 0;
    set pgp(format,$id) "pm";

    Pgp_Process $file $tmpfile 1
    Mh_Rename $tmpfile $file

    set msg(dpy) {}
    MsgChange $msg(id)

    return 1
}

proc Pgp_ChoosePrivateKey { text } {
   global pgp

   set signkeys {}
   while {[llength $signkeys] != 1} {
      if [catch {Pgp_KeyBox $text $pgp(secring) $pgp(privatekeys)} signkeys] {
	 set signkeys [list $pgp(myname)]
      }
   }
   return [lindex $signkeys 0]
}

proc Pgp_SetMyName {} {
   global pgp pgpPass

# first, save old pgpPass if set
   if {[info exists pgpPass(cur)] && [info exists pgp(myname)]} {
      set keyid [lindex $pgp(myname) 0]
      set pgpPass($keyid) $pgpPass(cur)
   }

   set pgp(myname) [Pgp_ChoosePrivateKey \
	 "Please select the default key to use for signing"]

   set keyid [lindex $pgp(myname) 0]
   set keyname [lindex $pgp(myname) 1]
   if [info exists pgpPass($keyid)] {
      set pgpPass(cur) $pgpPass($keyid)
   }
   set pgp(sedit_label) "PGP passphrase for $keyname:"
}

proc Pgp_Process { srcfile dstfile {pgpaction {}} } {
    global pgp env miscRE

    set orig [open $srcfile r]

    Exmh_Debug Pgp_Process

    set id [SeditId $srcfile]
    # get the header of the draft and split it into mime and non-mime headers
    set allheaders [Misc_Segregate line \
	    {[regexp $miscRE(mimeheaders) $line]} [Misc_GetHeader $orig]]
    
    set mimeheaders [lindex $allheaders 0]
    set mailheaders [lindex $allheaders 1]
	
    if {[lsearch -glob $mimeheaders "content-type:*"] < 0} {
	lappend mimeheaders "content-type: text/plain; charset=us-ascii"
    }
    
    # if there is nothing to do, stop here
    if {!$pgp(encrypt,$id) && !$pgp(sign,$id)} {
	close $orig
	error "no action"
    }

    if {$pgp(format,$id) == "app"} {
	Exmh_Debug app format
	if {$pgp(encrypt,$id)} {
	    if {$pgp(sign,$id)} {
		set typeparams "; x-action=encryptsign;"
	    } else {
		set typeparams "; x-action=encrypt;"
	    }
	} else {
	    if {$pgp(clearsign,$id)} {
		set typeparams "; x-action=signclear;"
	    } else {
		set typeparams "; x-action=signbinary;"
	    }
	}
    }

    # setup rfc822
    if [info exists pgp(param,rfc822)] {
	set rfc822 [regexp -nocase $miscRE(true) $pgp(param,rfc822)]
    } else {
	set rfc822 $pgp(rfc822)
  }

    # setup the originator (if necessary)
    if $pgp(sign,$id) {
	Exmh_Debug PGP signing
	if [info exists pgp(param,originator)] {
	    set originator [PgpMatch_Simple $pgp(param,originator) $pgp(secring)]
	} else {
	    set originator $pgp(myname)
	}
	if {$pgp(format,$id) == "app"} {
	    append typeparams "; x-originator=[string range [lindex $originator 0] 2 end]"
	}
    }

    # get the ids of the recipients (if necessary)
    if $pgp(encrypt,$id) {
	Exmh_Debug PGP encrypting
	if [info exists pgp(param,recipients)] {
	    set ids [Misc_Map id {PgpMatch_Simple $id $pgp(pubring)} \
		    [split $pgp(param,recipients) ","]]
	} else {
	    set hasfcc [expr {[lsearch -glob $mailheaders "fcc:*"] >= 0}]
	    set ids [PgpMatch_Whom $srcfile $hasfcc]
	}
	ExmhLog "<Pgp_Process> Encrypting with public key(s): [join $ids ", "]"

	if {$pgp(format,$id) == "app"} {
	    append typeparams ";\n\tx-recipients=\"[join [Misc_Map key {string range [lindex $key 0] 2 end} $ids] ", "]\""
	}
      }
      
    # setup the header of the application/pgp subpart
    if $rfc822 {
	set pgpheaders [concat \
		[list "content-type: message/rfc822" ""] \
		[Misc_Filter line {![string match {[bf]cc:*} $line]} $mailheaders] \
		[list "mime-version: 1.0"] \
		$mimeheaders]
    } else {
	set pgpheaders $mimeheaders
    }

    # write the message to be encrypted
    set msgfile [Mime_TempFile "msg"]
    set msg [open $msgfile w 0600]
    if {$pgp(format,$id) == "plain"} {
	set pgp(mime,$id) 0
    } else {
	foreach line $pgpheaders { puts $msg [Pgp_FixHeader $line] }
    }
    puts $msg ""
    puts -nonewline $msg [read $orig]
    close $orig
    close $msg

    set pgpfile [Mime_TempFile "pgp"]
    if [catch {
	Exmh_Debug "encrypt=$pgp(encrypt,$id); sign=$pgp(sign,$id); mime=$pgp(mime,$id); clearsign=$pgp(clearsign,$id)"
	if {$pgp(encrypt,$id)} {
	    if {$pgp(sign,$id)} {
		PgpExec_EncryptSign $msgfile $pgpfile $originator $ids 
	    } else {
		PgpExec_Encrypt $msgfile $pgpfile $ids 
	    }
	} else {
	    if {$pgp(sign,$id)} {
		if {$pgp(mime,$id)} {
		    PgpExec_SignPM $msgfile $pgpfile $originator 
		} else { 
		    PgpExec_Sign $msgfile $pgpfile $originator $pgp(clearsign,$id) 
		}
	    } else {
		error "<PGP> Message is neither signed, nor encrypted"
	    }
	}
    } err] {
	File_Delete $msgfile
	error $err
    }

    # complete mailheaders with the applcation/pgp content-type
    if {[info exists pgp(param,localaction)] && \
	    [regexp -nocase $miscRE(true) $pgp(param,localaction)]} { 
	set mailheaders {}
    }
	
    switch $pgp(format,$id) {
        app { 
            lappend mailheaders \
                "mime-version: 1.0" \
                "content-type: application/pgp; format=mime$typeparams" \
                "content-transfer-encoding: 7bit"

            # write out the new mail file
            set dst [open $dstfile w 0600]
            foreach line $mailheaders { puts $dst [Pgp_FixHeader $line] }
            puts $dst ""
            set msg [open $pgpfile r]
            puts -nonewline $dst [read $msg]
            close $msg
            close $dst
        }
        pm { 
            Pgp_ProcessPM $dstfile $pgpfile $mailheaders $msgfile $id
        }
        plain { 
            Pgp_ProcessPlain $dstfile $pgpfile $mailheaders $msgfile
        }
    }
    
    
    File_Delete $msgfile $pgpfile
}

proc Pgp_ProcessPM {dstfile pgpfile mailheaders plainfile id} {

    global pgp

    set boundary [Mime_MakeBoundary P]

    # Put in specified headers.  
    lappend mailheaders "mime-version: 1.0"
    if {$pgp(encrypt,$id)} {
	lappend mailheaders "content-type: multipart/encrypted; boundary=\"$boundary\";\n\t protocol=\"application/pgp-encrypted\""
    } else {
	lappend mailheaders "content-type: multipart/signed; boundary=\"$boundary\";\n\t micalg=pgp-md5; protocol=\"application/pgp-signature\""
    }
    lappend mailheaders "content-transfer-encoding: 7bit"

    # Write file
    set dst [open $dstfile w 0600]
    set pgpIO [open $pgpfile r]

    foreach line $mailheaders { puts $dst [Pgp_FixHeader $line] }
    puts $dst ""
    puts $dst "--$boundary"
    if {$pgp(encrypt,$id)} {
	puts $dst "Content-Type: application/pgp-encrypted"
	puts $dst ""
	puts $dst "Version: 1"
	puts $dst ""
	puts $dst "--$boundary"
	puts $dst "Content-Type: application/octet-stream"
	puts $dst ""
	puts $dst [read $pgpIO]
	puts $dst "--$boundary--"
    } else {
	set plain [open $plainfile r]
	puts $dst [read $plain]
	close $plain
	puts $dst "--$boundary"
	puts $dst "Content-Type: application/pgp-signature"
	puts $dst ""
	puts $dst [read $pgpIO]
	puts $dst "--$boundary--"
    }

    close $dst
    close $pgpIO

}

proc Pgp_ProcessPlain {dstfile pgpfile mailheaders plainfile} {

    set dst [open $dstfile w 0600]
    set pgpIO [open $pgpfile r]

    foreach line $mailheaders { puts $dst [Pgp_FixHeader $line] }
    puts $dst ""

    puts $dst [read $pgpIO]

    close $dst
    close $pgpIO
}

proc PgpExec_SignPM { in out sigkey } {

    PgpExec [list -stab $in -u [lindex $sigkey 0] -o $out] output $sigkey

    if {![file exists $out] && [file exists "$out.asc"]} {
	exec mv "$out.asc" $out
    }
    if {![file exists $out]} {
	error "PGP refused to generate the signed text:\n$output"
    } else {
	return {}
    }
}

proc MimeShowMultipartSignedPgp {tkw part} {
    global mimeHdr mime pgp

    if {$pgp(enabled)} {

	if {![info exists mimeHdr($part,pgpdecode)]} {
	    if {($pgp(showinline) == "all") ||
		($pgp(showinline) == "signed")} {
		set mimeHdr($part,pgpdecode) 1
	    } else { set mimeHdr($part,pgpdecode) 0 }
	}

	MimeMenuAdd $part checkbutton \
	    -label "Check signature with PGP" \
	    -command [list busy MimeRedisplayPart $tkw $part] \
	    -variable mimeHdr($part,pgpdecode)

	if $mimeHdr($part,pgpdecode) {
	    if [info exists mimeHdr($part=2,file)] {
		PgpExec [list $mimeHdr($part=2,file) [GetSignedText \
							  $tkw $part]] msg
    
		Pgp_InterpretOutput $msg pgpresult
		Pgp_DisplayMsg $tkw $part pgpresult
    
		set mimeHdr($part=1,color) \
		    [MimeDarkerColor $tkw $mimeHdr($part,color)]
	    } else {
		error "Missing signature"
	    }
	} else {
	    $tkw insert insert \
		"PGP signed message - the signature hasn't been checked\n"
	    TextButton $tkw "Check signature" \
		"$mimeHdr($part,menu) invoke {Check signature with PGP} \
                 \n$tkw config -cursor xterm"
	    $tkw insert insert "\n"
	    MimeInsertSeparator $tkw $part 6
	    set mimeHdr($part=1,color) $mimeHdr($part,color)
	}

    } else { set mimeHdr($part=1,color) $mimeHdr($part,color) }

    MimeShowPart $tkw $part=1 [MimeLabel $part part] 1
}


proc MimeShowMultipartEncryptedPgp {tkw part} {
    global mimeHdr pgp exmh

    if {!$pgp(enabled)} {
	Mime_ShowDefault $tkw $part
	return
    }

    if {![info exists mimeHdr($part,pgpdecode)]} {
	if {$pgp(showinline) == "all"} {
	    set mimeHdr($part,pgpdecode) 1
	} else { set mimeHdr($part,pgpdecode) 0 }
	
	MimeMenuAdd $part checkbutton \
	    -label "Decrypt with PGP" \
	    -command [list busy MimeRedisplayPart $tkw $part] \
	    -variable mimeHdr($part,pgpdecode)
    }  

    if {!$mimeHdr($part,pgpdecode)} {
	TextButton $tkw "Decrypt message" \
	    "$mimeHdr($part,menu) invoke {Decrypt with PGP} \
             \n$tkw config -cursor xterm"
	$tkw insert insert "\n"
	Mime_ShowDefault $tkw $part
	return
    }
	
    set tmpfile [Mime_TempFile "decrypt"]

    # Decide whether or not to use expect
    if {$pgp(keeppass) && [info exists exmh(expectk)] && $pgp(useexpectk)} {
	PgpExec_DecryptExpect $mimeHdr($part=2,file) $tmpfile msg
    } else {
	# Assume only recipient is primary secret key
	# Use expect to avoid this behavior
	set recipients [Misc_Map elem {string trim $elem} \
             [split [string range [lindex $pgp(myname) 0] 2 end] ","]]
    
	PgpExec_Decrypt $mimeHdr($part=2,file) $tmpfile msg $recipients
    }

    Pgp_InterpretOutput $msg pgpresult
    Pgp_DisplayMsg $tkw $part pgpresult

    set DarkerColor [MimeDarkerColor $tkw $mimeHdr($part,color)]
    
    # The following three lines would show the 
    # application/pgp-encrypted mime section.

    # set mimeHdr($part=1,color) $DarkerColor
    # MimeShowPart $tkw $part=1 [MimeLabel $part part] 1
    # MimeInsertSeparator $tkw $part 5
    
    set fileIO [open $tmpfile r]
    set mimeHdr($part=2,color) $DarkerColor
    set mimeHdr($part=2,numParts) [MimeParseSingle $tkw $part=2 $fileIO]
    close $fileIO
    
    MimeShowPart $tkw $part=2=1 [MimeLabel $part part] 1
}

proc GetSignedText {tkw part} {
    global mimeHdr

    set fileIO [open $mimeHdr($part,file) r]
    set boundary $mimeHdr($part,param,boundary)

    # Prolog
    while {([set numBytes [gets $fileIO line]] >= 0) &&
	   ([string compare --$boundary $line] != 0) &&
	   ([string compare --$boundary-- $line] != 0)} {}

    set tmpFilename [Mime_TempFile $part=1]
    set tmpFile [open $tmpFilename w 0600]

    # Body
    # Must not include the newline right before the boundary, that is
    # considered part of the boundary, not the subpart. (rfc1521?)

    # Also, LF should be converted to CRLF for checking.
    
    if {([set numBytes [gets $fileIO line]] >= 0) &&
	([string compare --$boundary $line] != 0) &&
	([string compare --$boundary-- $line] != 0)} {
	puts -nonewline $tmpFile $line
	while {([set numBytes [gets $fileIO line]] >= 0) &&
	       ([string compare --$boundary $line] != 0) &&
	       ([string compare --$boundary-- $line] != 0)} {
	    puts $tmpFile "\r"
	    puts -nonewline $tmpFile $line 
	}
    }
 
    close $fileIO
    close $tmpFile
    
return $tmpFilename
}

proc Pgp_ShowMessage { tkw part } {
    global mimeHdr mime pgp miscRE exmh

    set in [open $mimeHdr($part,file) r]
    gets $in firstLine
    close $in

    # let's get the format
    if {![info exists mimeHdr($part,param,format)]} {
	lappend mimeHdr($part,params) format
	if [regexp $miscRE(beginpgpkeys) $firstLine] {
	    set mimeHdr($part,param,format) keys-only
	} else {
	    set mimeHdr($part,param,format) text
	}
    }
    set format $mimeHdr($part,param,format)

    Exmh_Debug Pgp_ShowMessage format $format $part

    # the action pgp performed
    if {"$format" != "keys-only"} {
	if {![info exists mimeHdr($part,param,x-action)]} {
	    if [regexp $miscRE(beginpgpclear) $firstLine] {
		set action signclear
		set mimeHdr($part,param,x-action) signclear
	    } else {
		set action encryptsign
	    }
	} else {
	    set action $mimeHdr($part,param,x-action)
	}
    } else {
	set action "keys-only"
    }

    # short cut if you don't have PGP at all
    if {!$pgp(enabled) && ("$action" != "signclear")} {
	Mime_ShowDefault $tkw $part
	return
    }

    # get the recipients if necessary
    if [regexp {encrypt} $action] {
	if {![info exists mimeHdr($part,param,x-recipients)]} {
	    set recipients [string range [lindex $pgp(myname) 0] 2 end]
	} else {
	    set recipients $mimeHdr($part,param,x-recipients)
	}
	set recipients [Misc_Map elem {string trim $elem} [split $recipients ","]]
    }

    # see if we should decode the thing
    if {![info exists mimeHdr($part,pgpdecode)]} {
	set mimeHdr($part,pgpdecode) [expr {$pgp(enabled) && [expr $pgp(decode,$pgp(showinline))]}]
	if $pgp(enabled) {
	    MimeMenuAdd $part checkbutton \
		    -label "$pgp(menutext,$action) with pgp..." \
		    -command [list busy MimeRedisplayPart $tkw $part] \
		    -variable mimeHdr($part,pgpdecode)
	}
    }
    
    if {($format == "mime") || ($format == "text")} {
	if $mimeHdr($part,pgpdecode) {
	    set tmpfile [Mime_TempFile "decrypt"]
	    
	    if [regexp "encrypt" $action] {
		
		# Decide whether or not to use expect
		if {$pgp(keeppass) && [info exists exmh(expectk)] \
			&& $pgp(useexpectk)} {
		    Exmh_Debug "Using expect"
		    PgpExec_DecryptExpect $mimeHdr($part,file) \
			$tmpfile msg
		} else {
		    PgpExec_Decrypt $mimeHdr($part,file) \
			$tmpfile msg $recipients
		}
	    } else {
		PgpExec [list $mimeHdr($part,file) -o $tmpfile] msg
	    }

	    Pgp_InterpretOutput $msg pgpresult
	    Pgp_DisplayMsg $tkw $part pgpresult

	    if {$pgpresult(ok)} {
		if [catch {set fileIO [open $tmpfile r]} err] {
		    Exmh_Debug "Error: $err"
		    return
		}
		File_Delete $tmpfile
    
		if {![info exists mimeHdr($part,numParts)]} {
		    Exmh_Debug MimeParseSingle $part
		    set mimeHdr($part,numParts) \
			[MimeParseSingle $tkw $part $fileIO]
		    set mimeHdr($part=1,color) \
			[MimeDarkerColor $tkw $mimeHdr($part,color)]
		}
		MimeShowPart $tkw $part=1 [MimeLabel $part part] 1
		MimeClose $fileIO
	    }
	    
	} else {
	    if {$action == "signclear"} {
		$tkw insert insert \
		    "PGP signed message - the signature hasn't been checked\n"
		if $pgp(enabled) {
		    TextButton $tkw "Check signature" \
		    [list $mimeHdr($part,menu) invoke \
			 "$pgp(menutext,$action) with pgp..."]
		}
		$tkw insert insert "\n"
		MimeInsertSeparator $tkw $part 6
		
		if [catch {Pgp_Unsign [Misc_FileString $mimeHdr($part,file)]} msg] {
		    $tkw insert insert "  can't find the signed message.\nPlease check it out: it might be suspicious !\n"
		    return
		}
		if {$format == "mime"} {
		    set tmpfile "$mimeHdr($part,file).msg"
		    Misc_StringFile $msg $tmpfile
		    set fileIO [open $tmpfile r]
		    File_Delete $tmpfile
		    if {![info exists mimeHdr($part,numParts)]} {
			set mimeHdr($part,numParts) [MimeParseSingle $tkw $part $fileIO]
			set mimeHdr($part=1,color) [MimeDarkerColor $tkw $mimeHdr($part,color)]
		    }
		    MimeShowPart $tkw $part=1 [MimeLabel $part part] 1
		    MimeClose $fileIO
		} else {
		    $tkw insert insert $msg
		}
	    } else {
		TextButton $tkw "Show with PGP" \
		    [list $mimeHdr($part,menu) invoke \
			 "$pgp(menutext,$action) with pgp..."]
		$tkw insert insert "\n"
		Mime_ShowDefault $tkw $part
	    }
	}
    } elseif {$format == "keys-only"} {
	if $pgp(autoextract) {
	    PgpExec_ExtractKeys $mimeHdr($part,file) 0
	} else {
	    MimeMenuAdd $part command \
		    -label "Extract keys into keyring..." \
		    -command "PgpExec_ExtractKeys $mimeHdr($part,file)"
	    TextButton $tkw "Extract keys" "PgpExec_ExtractKeys $mimeHdr($part,file)"
	    $tkw insert insert "\n"
	}
	if $mimeHdr($part,pgpdecode) {
	    PgpExec [list $mimeHdr($part,file)] msg
	    regexp "\n(Type.*\n(sig|pub|sec)\[^\n]*)" $msg {} msg
	    $tkw insert insert "$msg\n"
	} else {
	    Mime_ShowDefault $tkw $part
	}
    } else {
	$tkw insert insert "PGP application format '$format' unknown\n"
	return
    }
}

#
proc Pgp_InsertKeys { draft t } {
    global env pgp

    if [catch {Pgp_KeyBox "select the keys you want to send" $pgp(pubring) [Pgp_FlatKeyList "" $pgp(secring)]} keys] {
	SeditMsg $t $keys
	return
    }

    foreach key $keys {
	set keyid [lindex $key 0]
	if {![info exists done($keyid)]} {
	    set done($keyid) 1
	    set tmpfile [Mime_TempFile "insertkeys"]
	    if [catch {PgpExec_GetKeys $keyid $tmpfile} msg] {
		SeditMsg $t "Pgp refuses to generate the key message"
		ExmhLog $msg
		return
	    }
	    
	    SeditInsertFile $draft $t $tmpfile 1 7bit {application/pgp; format=keys-only} "keys of [lindex $key 1]"
	    File_Delete $tmpfile
	}
    }
    Sedit_FixPgpFormat [SeditId $draft]
}

proc Pgp_GetTextAttributes { summary } {
    global pgp

    switch $summary {
	GoodSignatureUntrusted {return $pgp(GoodUntrustedSig)}
	GoodSignatureTrusted   {return $pgp(GoodTrustedSig)}
	BadSignatureTrusted    {return $pgp(BadSig)}
	BadSignatureUntrusted  {return $pgp(BadSig)}
        default                {return $pgp(OtherMsg)}
    }
}

proc Pgp_DisplayMsg { tkw part pgpresultvar } {
    global pgp
    upvar $pgpresultvar pgpresult

    Exmh_Debug "Pgp_DisplayMsg: $pgpresult(msg)"
    if {[info exists pgpresult(keyid)]} {
	MimeMenuAdd $part command \
	    -label "Query keyserver for key $pgpresult(keyid)" \
	    -command "PgpQueryKey $pgpresult(keyid)"
	if {[regexp "PublicMissing" $pgpresult(summary)]} {
	    TextButton $tkw "Query keyserver" \
		"PgpQueryKey $pgpresult(keyid)"
	}
	$tkw insert insert "\n"
    }

    set rval [Pgp_GetTextAttributes $pgpresult(summary)]
    if {$rval != {}} {
	if [catch {eval {$tkw tag configure PgpResults} $rval} err] {
	    Exmh_Debug tag configure PgpResults $rval: $err
	    $tkw insert insert "$pgpresult(msg)\n"
	} else {
	    $tkw insert insert "$pgpresult(msg)\n" PgpResults
	}
    } else {
	$tkw insert insert "$pgpresult(msg)\n"
    }
    MimeInsertSeparator $tkw $part 6
}
