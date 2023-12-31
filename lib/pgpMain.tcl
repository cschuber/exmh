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

# Setup is invoked by the "Make Key" button on the PGP Setup Help page
# It searches for versions on the system, which are supported by exmh.
# Setup then configures the version found on your system.
#
# If there are more than one version found on the system,
# then a dialog box pops up and asks the user for the version, he/she wants
# to configure.
# She/He can choose her/his preferred version(s).
#
proc Pgp_Setup {} {
    global env pgp

    Pgp_SetPath

    foreach v $pgp(supportedversions) {
    	foreach path [split $env(PATH) ":"] {
	    if [file executable "$path/[set pgp($v,executable,key)]"] {
		lappend installed $v
		break
	    }
	}
    }

    # Nothing installed
    if {![info exists installed]} {
	tk_messageBox -type ok -title "PGP Setup" -icon error \
                      -message "A PGP executable is not in your PATH. You'll have to find it (or install it) before I can do anything for you."
        return
    }

    # dialog box, if more than one version found
    if { [llength $installed] >= 2 } {
        if [winfo exists .hugo] {
            return
        }
	set t [toplevel .hugo]
	wm title $t "Which version?"
	wm resizable $t 0 0
	set f [frame $t.frame1]
	pack $f -side top
	set l [label $f.pic -bitmap questhead]
	pack $l -side left -padx 5
	set m [message $f.msg -justify left -text \
"There are more than one versions installed on your system. Which version(s) do
you want to use to generate your key?"]
	pack $m -side left
	set f [frame $t.frame2]
	pack $f -side top
	global value
	foreach v $installed {
	    set value($v) 0
	    set c [checkbutton $f.$v -variable value($v) -text [set pgp($v,fullName)] ]
	    pack $c -side left
	}
	set b [button $f.ok -text OK -command [list destroy $t] ]
	pack $b -side left
	
	tkwait window $t
	
	foreach v $installed {
	    if {[set value($v)]} {
		lappend wantToInstall $v
	    }
	}
	if {![info exists wantToInstall]} {
	    return
	}
    } else {
	set wantToInstall $installed
    }

    foreach v $wantToInstall {
	# setup directory
	catch { file mkdir [set pgp($v,defaultPath)] }
	# setup config file
	catch { exec touch [set pgp($v,configFile)] }
	# make the key pair(s) and self sign it/them
	if [catch {
	    exec xterm -title "[set pgp($v,fullName)] Setup" -e sh \
                           -c [set pgp($v,keyGenCmd)] >& /dev/tty } error] {
	    tk_messageBox -title "[set pgp($v,fullName)] Setup Error" -type ok \
                          -icon error -message "An error occurred while trying to generate your key: \n$error\n please try these commands at your unix shell to generate your key and self sign it: \n[set pgp($v,keyGenCmd)]\n Then restart exmh to enable its [set pgp($v,fullName)] support."
            return
        }

	# init the support if necessary
    	if {![set pgp($v,enabled)]} {
	    Pgp_Init
    	} else {
	    set pgp($v,privatekeys) [Pgp_Exec_KeyList $v $pgp($v,ownPattern) Sec]
    	}

	# something todo after keygeneration, send to keyserver ?
	if {[info exists pgp($v,afterKeyGen)]} {
	    eval [set pgp($v,afterKeyGen)]
	}
    }
}

proc Pgp_Help {} {
    Help PGP	;# Make Key button is embedded in the HTML
}

proc Pgp_HelpOld {} {
    global exmh
    set label "Help about setting up PGP"
    if [Exwin_Toplevel .pgphelp "PGP Help" PgpHelp] {
	Widget_Label .pgphelp.but label {left fill} -text $label
	Widget_AddBut .pgphelp.but setup "Make Key" [list Pgp_Setup]
    
	set t [Widget_Text .pgphelp 30 -setgrid true]
	$t insert insert "EXMH Version: $exmh(version)\n\n"
	if [catch {open "$exmh(library)/help.PGP" r} in] {
	    $t insert insert "Cannot find file exmh.PGP.help to display"
	    $t configure -state disabled
	} else {
	    $t insert insert [read $in]
	}
    }
}


proc Pgp_SetPath {} {
    global env pgp

    foreach v $pgp(supportedversions) {
    	if {[info exists pgp($v,path)] && \
	    ([string length [string trim [set pgp($v,path)]]] > 0) && \
	    ([lsearch -exact [split $env(PATH) :] [set pgp($v,path)]] < 0)} {
		set env(PATH) [set pgp($v,path)]:$env(PATH)
	}
    }
}

# XXX Orphaned code, from exmh More->old PGP->encrypt menu
# encrypts the current message with the user's key
proc Pgp_ExmhEncrypt { v } {
    global exmh msg mhProfile pgp

    set file $msg(path)
    set tmpfile [Mime_TempFile "encrypt"]

    Exmh_Status "pgp -e $exmh(folder)/$msg(id)"

    set pgp(param,recipients) [lindex $pgp($v,myname) 0]
    set id [SeditId $file]
    set pgp(encrypt,$id) 1;
    set pgp(sign,$id) "none";
    set pgp(format,$id) "pm";
    set pgp(version,$id) $v

    Pgp_Process $v $file $tmpfile

    unset pgp(param,recipients)
    unset pgp(encrypt,$id)
    unset pgp(sign,$id)
    unset pgp(format,$id)
    unset pgp(version,$id)

    Mh_Rename $tmpfile $file

    set msg(dpy) {}
    Msg_Change $msg(id)

    return 1
}

# XXX Orphaned code (pgp-action headers no longer used)
# Removes any pgp-action header and inserts a brand new one
proc Pgp_SeditEncrypt { action v draft t } {
    global pgp

    SeditSave $draft $t

    # remove pgp-action header
    Pgp_Misc_RemovePgpActionHeader $t hasfcc

    # check, if pgp enabled
    if { ![set pgp($v,enabled)] } {
	SeditMsg $t "[set pgp($v,fullName)] not enabled"
	return
    }

    if {"$action" == "none"} {
        return
    }

    # Build header
    set pgpaction "Pgp-Action: $action"
    if [set pgp($v,rfc822)] {
	append pgpaction "; rfc822=on"
    } else {
	append pgpaction "; rfc822=off"
    }
    # # # # # #
    # S I G N
    if [regexp {sign} $action] {
       if { [set pgp($v,choosekey)] && [llength [set pgp($v,privatekeys)]] > 1} {
	  set signkey [Pgp_ChoosePrivateKey $v "Please select the key to use for signing"]
       } else {
# XXX fix this
	  set signkey [set pgp($v,myname)]
       }
       append pgpaction ";\n\toriginator=\"[lindex $signkey 0]\""
    }
    # # # # # # # # #
    # E N C R Y P T
    if [regexp {encrypt} $action] {
	if [catch { append pgpaction ";\n\trecipients=\"[join [Pgp_Misc_Map key {lindex $key 4} \
		  [Pgp_Match_Whom $v $draft $hasfcc]] ",\n\t\t    "]\"" } err] {
            Exmh_Debug "<PGP SeditEncrypt>: $err"
        }
    }
    append pgpaction ";\n\tpgp-version=$v"

    # insert it
    $t insert 1.0 "$pgpaction\n"
}

# XXX Orphaned code (from now-dead sedit Crypt...->PGP Preview menu item)
proc Pgp_EncryptDebug { srcfile } {
    global pgp env miscRE

    set orig [open $srcfile r]

    Exmh_Debug Pgp_EncryptDebug

    set id [SeditId $srcfile]
    set v $pgp(version,$id)

    # get the header of the draft and split it into mime and non-mime headers
    set allheaders [Pgp_Misc_Segregate line \
	    {[regexp $miscRE(mimeheaders) $line]} [Pgp_Misc_GetHeader $orig]]
    
    close $orig

    set mimeheaders [lindex $allheaders 0]
    set mailheaders [lindex $allheaders 1]
	
    if {[lsearch -glob $mimeheaders "content-type:*"] < 0} {
	lappend mimeheaders "content-type: text/plain; charset=us-ascii"
    }
    
    # if there is nothing to do, stop here
    if {!$pgp(encrypt,$id) && $pgp(sign,$id)=="none"} {
	Exmh_Debug "Pgp_EncryptDebug: No action"
    }

    # check originator (if necessary)
    if {$pgp(sign,$id) != "none"} {
	if [info exists pgp(param,originator)] {
	    set originator [PgpMatch_Simple $pgp(param,originator) $pgp(secring)]
	} else {
	    set originator $pgp($v,myname,$id)
	}
	Exmh_Debug "Pgp_EncryptDebug: Signed by: $originator"
    }

    # get the ids of the recipients (if necessary)
    if $pgp(encrypt,$id) {
	if [info exists pgp(param,recipients)] {
	    Exmh_Debug "Recipients from pgp(param,recipients): $pgp(param,recipients)"
	    set ids [Pgp_Misc_Map id {PgpMatch_Simple $id $pgp($v,pubring)} \
		    [split $pgp(param,recipients) ","]]

	} else {
	    set hasfcc [expr {[lsearch -glob $mailheaders "fcc:*"] >= 0}]

#	    catch {exec whom -nocheck $srcfile} recipients
	    catch {exec whom $srcfile} recipients
	    Exmh_Debug "Recipients from draft: $recipients"

	    set ids [Pgp_Match_Whom $v $srcfile $hasfcc]
	}
	Exmh_Debug "Pgp_EncryptDebug: Encrypt to: [join $ids ", "]"
    }

}

# Choose the private key to use. Default is 1st element of pgp($v,myname) 
# which is set by Pgp_Exec_Init.
proc Pgp_ChoosePrivateKey { v text } {
    global pgp

    set signkeys {}

    if [catch {Pgp_KeyBox $v $text Sec [set pgp($v,privatekeys)]} signkeys] {
	set signkeys [list [set pgp($v,myname)]]
	return [lindex $signkeys 0]
    } else {
	return $signkeys
    }
}

# Change pgp($v,myname,$id) variable and update pgp(cur,pass,$id) along 
# the way. Function is called from the Crypt... menu in Sedit and WhatNow.
proc Pgp_SetMyName { v id } {
   global pgp

Exmh_Debug In PGP_SetMyName $v $id
    # first, save old pgp passphrase if set
   if {[info exists pgp(cur,pass,$id)] && \
	   ([string length $pgp(cur,pass,$id)] > 0) && \
	   [info exists pgp($v,myname,$id)]} {
      set keyid [lindex $pgp($v,myname,$id) 0]
      set pgp($v,pass,$keyid) $pgp(cur,pass,$id)
      if {![info exists pgp(timeout,$keyid)]} {
	 Pgp_SetPassTimeout $v $keyid
      }
   }

   set newname [Pgp_ChoosePrivateKey $v \
	 "Please select a $pgp($v,fullName) key to use for signing"]
   if {[string length $newname]} {
       set pgp($v,myname,$id) [lindex $newname 0]

       Exmh_Debug "Pgp_SetMyName: myname now $pgp($v,myname,$id)"

       set keyid [lindex $pgp($v,myname,$id) 0]
       if [info exists pgp($v,pass,$keyid)] {
	   set pgp(cur,pass,$id) $pgp($v,pass,$keyid)
       } else {
	   set pgp(cur,pass,$id) {}
       }
       Pgp_SetSeditPgpName $pgp($v,myname,$id) $id
   }
}

# Set seditpgp labels (PGP key name gets set in multiple places
# so we should collapse them all here)
proc Pgp_SetSeditPgpName { myname id } {
    global pgp

    set keyid [lindex $myname 0]
    set keyalg [lindex $myname 1]
    set keyname [lindex $myname 4]
    set fullname $pgp($pgp(version,$id),fullName)
	
    set pgp(sedit_label,$id) "$keyname"
    set pgp(sedit_label2,$id) "$fullname KeyID: $keyid ($keyalg)"
}

# Update seditpgp PGP version
proc Pgp_SetSeditPgpVersion { v id } {
    global pgp

    # Get old PGP passphrase and save it away if it has content.
    set oldv $pgp(version,$id)
    if {[info exists pgp(cur,pass,$id)] && \
	    ([string length $pgp(cur,pass,$id)] > 0) && \
	    [info exists pgp($oldv,myname,$id)]} {
	set keyid [lindex $pgp($oldv,myname,$id) 0]
	set pgp($oldv,pass,$keyid) $pgp(cur,pass,$id)
	if {![info exists pgp(timeout,$keyid)]} {
	    Pgp_SetPassTimeout $oldv $keyid
	}
    }

    # If we didn't pick a key for this PGP version yet in this
    # window, then set one from the default.
    if {![info exists pgp($v,myname,$id)]} {
	set pgp($v,myname,$id) $pgp($v,myname)
    }

    Exmh_Debug "Pgp_SetSeditPgpVersion: myname now $pgp($v,myname,$id)"

    # Now behave as if we'd just chosen a new key (with new version $v)
    set keyid [lindex $pgp($v,myname,$id) 0]
    if [info exists pgp($v,pass,$keyid)] {
	set pgp(cur,pass,$id) $pgp($v,pass,$keyid)
    } else {
	set pgp(cur,pass,$id) {}
    }
    set pgp(version,$id) $v
    Pgp_SetSeditPgpName $pgp($v,myname,$id) $id

}

proc Pgp_Process { v srcfile dstfile } {
    global pgp env miscRE

    set orig [open $srcfile r]

    Exmh_Debug Pgp_Process

    set id [SeditId $srcfile]
    # get the header of the draft and split it into mime and non-mime headers
    set allheaders [Pgp_Misc_Segregate line \
	    {[regexp $miscRE(mimeheaders) $line]} [Pgp_Misc_GetHeader $orig]]
    
    set mimeheaders [lindex $allheaders 0]
    set mailheaders [lindex $allheaders 1]

    if {[lsearch -glob $mimeheaders "content-type:*"] < 0} {
	lappend mimeheaders "content-type: text/plain; charset=us-ascii"
        lappend mimeheaders "content-disposition: inline"
    }

    # if there is nothing to do, stop here
    if {!$pgp(encrypt,$id) && $pgp(sign,$id)=="none"} {
	close $orig
	error "no action"
    }

    if {$pgp(format,$id) == "app"} {
	Exmh_Debug app format
	if {$pgp(encrypt,$id)} {
	    set typeparams "; x-action=encrypt;"
	} else {
	    switch $pgp(sign,$id) {
		standard {set typeparams "; x-action=signbinary;"}
		clearsign {set typeparams "; x-action=signclear;"}
		encryptsign {set typeparams "; x-action=encryptsign;"}
	    }
	}
    }

    # setup rfc822
    if [info exists pgp(param,rfc822)] {
	set rfc822 [regexp -nocase $miscRE(true) $pgp(param,rfc822)]
    } else {
	set rfc822 $pgp($v,rfc822)
    }

    # setup the originator (if necessary)
    if {$pgp(sign,$id) != "none"} {
	Exmh_Debug PGP signing
	if { [set pgp($v,choosekey)] && [llength $pgp($v,privatekeys)]>1} {
	    set originator [lindex [Pgp_ChoosePrivateKey $v \
	        "Please select a $pgp($v,fullName) key to use for signing"] 0]
	    if {[string length $originator] == 0} {
		error "A valid key is required for signing."
	    }
	} else {
	    if [info exists pgp(param,originator)] {
		set originator [Pgp_Match_Simple $v $pgp(param,originator) $pgp(secring)]
	    } else {
		set originator $pgp($v,myname,$id)
	    }
	}
	if {$pgp(format,$id) == "app"} {
	    append typeparams "; x-originator=[string range [lindex $originator 0] 2 end]"
	}
    }

    # get the ids of the recipients (if necessary)
    if {$pgp(encrypt,$id) || $pgp(sign,$id) == "encryptsign"} {
	Exmh_Debug PGP encrypting
	if [info exists pgp(param,recipients)] {
	    set ids [Pgp_Misc_Map key {Pgp_Match_Simple $v $key $pgp($v,pubring)} \
		    [split $pgp(param,recipients) ","]]
	} else {
	    set hasfcc [expr {[lsearch -glob $mailheaders "fcc:*"] >= 0}]
	    set ids [Pgp_Match_Whom $v $srcfile $hasfcc]
	}
	ExmhLog "<Pgp_Process> Encrypting with public key(s): [join $ids ", "]"

	if {$pgp(format,$id) == "app"} {
	    append typeparams ";\n\tx-recipients=\"[join [Pgp_Misc_Map key {string range [lindex $key 0] 2 end} $ids] ", "]\""
	}
    }
      
    # remove pgp-action and mime-version headers
    set mailheaders [Pgp_Misc_Filter line \
	{![regexp "^(mime-version|pgp-action):" $line]} $mailheaders]

    # setup the header of the application/pgp subpart
    if $rfc822 {
	set pgpheaders [concat \
		[list "content-type: message/rfc822" ""] \
		[Pgp_Misc_Filter line {![string match {[bf]cc:*} $line]} $mailheaders] \
		[list "mime-version: 1.0"] \
		$mimeheaders]
    } else {
	if {$pgp(format,$id) == "pm"} {
	    set pgpheaders $mimeheaders
	} else {
	    set pgpheaders {}
	}
    }

    # write the message to be encrypted
    set msgfile [Mime_TempFile "msg"]
    set msg [open $msgfile w 0600]
    foreach line $pgpheaders { puts $msg [Pgp_Misc_FixHeader $line] }
    if {[llength $pgpheaders] > 0} { puts $msg "" }
    while {[gets $orig line] >= 0} {
	set trimmed [string trimright $line]
        puts $msg $trimmed
    }
    close $orig
    close $msg

    set pgpfile [Mime_TempFile "pgp"]
    if [catch {
	Exmh_Debug "encrypt=$pgp(encrypt,$id); sign=$pgp(sign,$id)"
	if {$pgp(encrypt,$id)} {
	    Pgp_Exec_Encrypt $pgp(version,$id) $msgfile $pgpfile $ids 
	} else {
	    switch $pgp(sign,$id) {
		standard {
		    # Depending on format standard may mean different
		    # things. It was decided to keep this ambiguity
		    # internal instead of exporting it via the GUI.
		    if {$pgp(format,$id) == "pm"} {
			Pgp_Exec_Sign $pgp(version,$id) $msgfile $pgpfile \
				$originator detached
		    } else {
			Pgp_Exec_Sign $pgp(version,$id) $msgfile $pgpfile \
				$originator standard
		    }
		}
		clearsign {
		    # There is only one correct way of signing 
		    # multipart/signed messages and that is "detached".
		    if {$pgp(format,$id) == "pm"} {
			Pgp_Exec_Sign $pgp(version,$id) $msgfile $pgpfile \
				$originator detached
		    } else {
			Pgp_Exec_Sign $pgp(version,$id) $msgfile $pgpfile \
			    $originator clearsign
		    }
		}
		encryptsign {
		    Pgp_Exec_EncryptSign $pgp(version,$id) $msgfile $pgpfile \
			    $originator $ids
		}
		none -
		default {error "<PGP> Message is neither signed, nor encrypted"}
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
	    Pgp_ProcessAP $v $dstfile $pgpfile $mailheaders $typeparams
        }
        pm { 
            Pgp_ProcessPM $v $dstfile $pgpfile $mailheaders $msgfile $id
        }
        plain { 
            Pgp_ProcessPlain $v $dstfile $pgpfile $mailheaders $msgfile
        }
    }
    
    File_Delete $msgfile $pgpfile
}

proc Pgp_ProcessAP {v dstfile pgpfile mailheaders typeparams} {
    global pgp

    lappend mailheaders \
                "mime-version: 1.0" \
                "content-type: application/pgp; format=mime$typeparams" \
                "content-transfer-encoding: 7bit"

    # write out the new mail file
    set dst [open $dstfile w 0600]
    foreach line $mailheaders { puts $dst [Pgp_Misc_FixHeader $line] }
    puts $dst ""
    set msg [open $pgpfile r]
    puts -nonewline $dst [read $msg]
    close $msg
    close $dst
}

proc Pgp_ProcessPM {v dstfile pgpfile mailheaders plainfile id} {

    global pgp

    set boundary [Mime_MakeBoundary P]
    set micalg [set pgp($v,digestalgo)]

    # Put in specified headers.  
    lappend mailheaders "mime-version: 1.0"
    if {$pgp(encrypt,$id)  || $pgp(sign,$id) == "encryptsign"} {
	lappend mailheaders "content-type: multipart/encrypted; boundary=\"$boundary\";\n\t protocol=\"application/pgp-encrypted\""
    } else {
	lappend mailheaders "content-type: multipart/signed; boundary=\"$boundary\";\n\t micalg=pgp-${micalg}; protocol=\"application/pgp-signature\""
    }
    lappend mailheaders "content-transfer-encoding: 7bit"

    # Write file
    set dst [open $dstfile w 0600]
    set pgpIO [open $pgpfile r]

    foreach line $mailheaders { puts $dst [Pgp_Misc_FixHeader $line] }
    puts $dst ""
    puts $dst "--$boundary"
    if {$pgp(encrypt,$id) || $pgp(sign,$id) == "encryptsign"} {
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

proc Pgp_ProcessPlain {v dstfile pgpfile mailheaders plainfile} {

    set dst [open $dstfile w 0600]
    set pgpIO [open $pgpfile r]

    foreach line $mailheaders { puts $dst [Pgp_Misc_FixHeader $line] }
    puts $dst ""

    puts $dst [read $pgpIO]

    close $dst
    close $pgpIO
}

# Simple version + blank line adding
proc Pgp_CheckVersion { pgpfile varReal varV } {
    upvar $varReal bestversion
    upvar $varV version
    global pgp

    Exmh_Debug "Pgp_CheckVersion $pgpfile $varReal $varV"

    set in [open $pgpfile r]
    set pgptext [read $in]
    close $in

    # Adding necessary blank lines;
    set pgptext [Pgp_CheckBlankLines $pgptext]
    set out [open $pgpfile w]
    puts $out $pgptext
    close $out

    # look, which supported versions pattern matches
    foreach v $pgp(supportedversions) {
        if {[regexp [set pgp($v,pat_Version)] $pgptext]} {
            set bestversion $v
            break
        }
    }
    if {![info exists bestversion]} {
        #error "No pattern matches version info in pgp text!"
	Exmh_Debug "No pattern matches version info in pgp text!"
	Exmh_Debug "Falling back to $pgp(noversion)"
	set bestversion $pgp(noversion)
    }

    # look, if the version is setup
    # else take the next enabled in the Alien list
    if {![set pgp($bestversion,enabled)]} {
        foreach v [set pgp($bestversion,list_Alien)] {
            if {[set pgp($v,enabled)]} {
                set version $v
                break
            }
        }
    } else { set version $bestversion }
    if {![info exists version]} {
        error "No pgp enabled"
    }
}		  

# Blank line checking and adding, if needed (e.g for some bad OLE messages)
proc Pgp_CheckBlankLines { pgptext } {
    switch -regexp -- $pgptext {
	{BEGIN PGP SIGNED MESSAGE} {
	    #####
	    # Blank line after
	    # -----BEGIN PGP SIGNED MESSAGE-----
	    # Hash: SHA1
	    #####
	    set a [regsub "^(-----BEGIN\[^\n]+MESSAGE-----\n)(\[^ \n\t:\]+: \[^\n\]+\n)?((\[^ :\t\n]+\[ \t]*)+\n)" $pgptext "\\1\\2\n\\3" pgptext]
	    #####
	    # Blank line after
	    # -----BEGIN PGP SIGNATURE-----
	    # Version: PGP
	    # Charset: noconv
	    # ...    : ...
	    #####
	    set b [regsub "^(-----BEGIN\[^\n]+SIGNATURE-----\n)((\[^ \n\t:\]+: \[^\n\]+\n)+)((\[^ :\t\n]+\[ \t]*)+\n)" $pgptext "\\1\\2\n\\4" pgptext]
	    Exmh_Debug "<Pgp_CheckBlankLines> Number of blank lines added: $a-$b"
	    }
	{BEGIN PGP MESSAGE} {
	    #####
	    # Blank line after
	    # -----BEGIN PGP MESSAGE-----
            # Version: PGP
            # Charset: noconv
            # ...    : ...
	    #####
	    set a [regsub "^(-----BEGIN\[^\n]+MESSAGE-----\n)((\[^ \n\t:\]+: \[^\n\]+\n)+)((\[^ :\t\n]+\[ \t]*)+\n)" $pgptext "\\1\\2\n\\4" pgptext]
	    Exmh_Debug "<Pgp_CheckBlankLines> Number of blank lines added: $a"
	    }
    }
    return $pgptext
}

# Show multipart/signed
proc Pgp_MimeShowMultipartSignedPgp {tkw part} {
    global mimeHdr mime pgp

    # do we have a signature part ?
    if {![info exists mimeHdr($part=2,file)]} {
	error "Missing signature"
    }

    # decide which version to use / implicitely checks for pgp enabled
    if { [catch {Pgp_CheckVersion $mimeHdr($part=2,file) real v} err] } {
        Exmh_Debug "<PGP MimeSigned> $err"
        Exmh_Status "Unknown PGP message version"
        set mimeHdr($part=1,color) $mimeHdr($part,color)
    } else {

        # Labels to display: "real" is the Version of the program 
        # which prepared the pgp text, "local" the version, which
        # will be used to decode the thing
	set real [set pgp($real,fullName)]
        set local [set pgp($v,fullName)]

	if {![info exists mimeHdr($part,pgpdecode)]} {
	    if {([set pgp($v,showinline)] == "all") ||
		([set pgp($v,showinline)] == "signed")} {
		set mimeHdr($part,pgpdecode) 1
	    } else { set mimeHdr($part,pgpdecode) 0 }
	}

	MimeMenuAdd $part checkbutton \
	    -label "$pgp(menutext,signclear) with $local" \
	    -command [list busy MimeRedisplayPart $tkw $part] \
	    -variable mimeHdr($part,pgpdecode)

	if $mimeHdr($part,pgpdecode) {
            if {[catch {Pgp_GetSignedText $tkw $part} res]} {
                Exmh_Debug "<PGP MimeSigned> $res"
                Exmh_Status "<PGP> Failed to parse out signed text."
                set mimeHdr($part=1,color) $mimeHdr($part,color)
                MimeShowPart $tkw $part=1 [MimeLabel $part part] 1
                return
            } else { set signedText $res }

            # prepare nice sigfile for royal pgp5
            file copy -force $mimeHdr($part=2,file) [set sigfile ${signedText}.asc]

	    # verify the thing
            Pgp_Exec_VerifyDetached $v $sigfile $signedText msg

            # clean up behind us
            File_Delete $sigfile

            # tune output
	    Pgp_InterpretOutput $v $msg pgpresult
	    if [info exists pgpresult(keyid)] {
		Exmh_Debug "<PGP MimeSigned> ID: $pgpresult(keyid)"
	    }
            # display it
	    Pgp_DisplayMsg $v $tkw $part pgpresult

            # set colors
	    set mimeHdr($part=1,color) [MimeDarkerColor $tkw $mimeHdr($part,color)]

	} else {
	    $tkw insert insert \
		"$real signed message - the signature hasn't been checked\n"
	    TextButton $tkw "$pgp(menutext,signclear) with $local" \
		"$mimeHdr($part,menu) invoke [join $pgp(menutext,signclear) {\ }]\\ with\\ [join $local {\ }]
                 \n$tkw config -cursor xterm"
	    $tkw insert insert "\n"
	    MimeInsertSeparator $tkw $part 6
	    set mimeHdr($part=1,color) $mimeHdr($part,color)
	}
    }
    MimeShowPart $tkw $part=1 [MimeLabel $part part] 1
}

# Show multipart/encrypted
proc Pgp_MimeShowMultipartEncryptedPgp {tkw part} {
    global mimeHdr exmh pgp

    # decide which version to use / implicitely checks for pgp enabled
    if { [catch {Pgp_CheckVersion $mimeHdr($part=2,file) real v} err] } {
        Exmh_Debug "<PGP MimeEncrypted> $err"
        Exmh_Status "Unknown PGP message version"
        Mime_ShowDefault $tkw $part
	return
    }

    # Labels to display: "real" is the Version of the program 
    # which prepared the pgp text, "local" the version, which
    # will be used to decode the thing
    set real [set pgp($real,fullName)]
    set local [set pgp($v,fullName)]

    if {![info exists mimeHdr($part,pgpdecode)]} {
	if {[set pgp($v,showinline)] == "all"} {
	    set mimeHdr($part,pgpdecode) 1
	} else { set mimeHdr($part,pgpdecode) 0 }
	
        MimeMenuAdd $part checkbutton \
	    -label "$pgp(menutext,encryptsign) with $local" \
	    -command [list busy MimeRedisplayPart $tkw $part] \
	    -variable mimeHdr($part,pgpdecode)
    }

    if {!$mimeHdr($part,pgpdecode)} {
        $tkw insert insert "This is a $real multipart/encrypted message\n"
	TextButton $tkw "$pgp(menutext,encryptsign) with $local" \
	    "$mimeHdr($part,menu) invoke [join $pgp(menutext,encryptsign) {\ }]\\ with\\ [join $local {\ }]
	     \n$tkw config -cursor xterm"
	$tkw insert insert "\n"
	Mime_ShowDefault $tkw $part
	return
    }
	
    set tmpfile [Mime_TempFile "decrypt"]

    # Decide whether or not to use expect
    set decrypt 1
    if {[info exists pgp($v,useexpectk)]} {
        if {[set pgp(keeppass)] && \
                    [info exists exmh(expectk)] && [set pgp($v,useexpectk)]} {
	    # Decrypt with expect
	    Pgp_Exec_DecryptExpect $v $mimeHdr($part=2,file) $tmpfile msg
            set decrypt 0
        }
    }
    if $decrypt {
	# Assume only recipient is primary secret key
	# Use expect to avoid this behavior
	set recipients [Pgp_Misc_Map elem {string trim $elem} \
             [split [string range [lindex [set pgp($v,myname)] 0] 2 end] ","]]
    	# Decrypt
	Pgp_Exec_Decrypt $v $mimeHdr($part=2,file) $tmpfile msg $recipients
    }

    # tune output
    Pgp_InterpretOutput $v $msg pgpresult
    # display it
    Pgp_DisplayMsg $v $tkw $part pgpresult

    # set color
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

# Show application/pgp-keys
proc Pgp_MimeShowPgpKeys {tkw part} {
    global mimeHdr pgp

    Exmh_Debug "<Pgp_MimeShowPgpKeys> part: $part"

    # decide which version to use / implicitely checks for pgp enabled
    if { [catch {Pgp_CheckVersion $mimeHdr($part,file) real v} err] } {
        Exmh_Debug "<PGP MimeShowPgpKeys> $err"
        Exmh_Status "Unknown PGP message version"
        Mime_ShowDefault $tkw $part
	return    
    }

    # Labels to display: "real" is the Version of the program 
    # which prepared the pgp text, "local" the version, which
    # will be used to decode the thing
    set real [set pgp($real,fullName)]
    set local [set pgp($v,fullName)]

    if {![info exists mimeHdr($part,pgpdecode)]} {
	if {([set pgp($v,showinline)] == "all") ||
	    ([set pgp($v,showinline)] == "keys")} {
	    set mimeHdr($part,pgpdecode) 1
	} else { set mimeHdr($part,pgpdecode) 0 }
    }

    set msg ""
    if [set pgp($v,autoextract)] {
	append msg "Automatic extraction of application/pgp-keys\n"
	Pgp_Exec_ExtractKeys $v $mimeHdr($part,file) out 0
	append msg $out "\n"
    } else {
	TextButton $tkw "Extract $real keys into $local keyring" \
		"Pgp_Exec_ExtractKeys $v $mimeHdr($part,file) out"
	$tkw insert insert "\n"
    }

    # Add a menu anyway to allow re-extracting
    MimeMenuAdd $part command \
	    -label "Extract $real keys into $local keyring..." \
	    -command "Pgp_Exec_ExtractKeys $v $mimeHdr($part,file) out"

    if $mimeHdr($part,pgpdecode) {
	Pgp_Exec $v key $mimeHdr($part,file) out
	# NEW
	regexp [set pgp($v,pat_validKeys)] $out out
	append msg $out "\n"
    } 

    Pgp_InterpretOutput $v $msg pgpresult
    Pgp_DisplayMsg $v $tkw $part pgpresult
}

# store the signed text in a file
proc Pgp_GetSignedText {tkw part} {
    global mimeHdr

    set boundary $mimeHdr($part,param,boundary)
    regsub -all {([\.\+\?\(\)])} $boundary {\\&} boundarypat
    
    set fileIO [open $mimeHdr($part,file) r]
    set raw [read $fileIO]
    close $fileIO

    if {![regexp -- "--${boundarypat}\n(.*)\n--${boundarypat}.*--${boundarypat}--" $raw match text]} {
        error "<Pgp_GetSignedText>: Wrong PGP/MIME multipart/signed format"
    }

    set tmpFilename [Mime_TempFile $part=1]
    set tmpFile [open $tmpFilename w 0600]

    # set <CR><LF> eol translation
    fconfigure $tmpFile -translation crlf

    puts -nonewline $tmpFile $text
    close $tmpFile

    return $tmpFilename
}

# Show application/pgp
proc Pgp_ShowMessage { tkw part } {
    global mimeHdr mime miscRE exmh pgp

    set in [open $mimeHdr($part,file) r]
    gets $in firstLine
    close $in

    #########
    # Prolog

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

    Exmh_Debug "<Pgp_ShowMessage>: format $format part $part"

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
	    # For signed messages we expect 'x-action=signclear' or 
	    # 'x-action=signbinary' but some mailers only use 
	    # 'x-action=sign'. Since application/pgp never made it 
	    # to a valid content-type is hard to tell who is right.
	    if {"$action" == "sign"} {
		if [regexp $miscRE(beginpgpclear) $firstLine] {
		    set action signclear
		    set mimeHdr($part,param,x-action) signclear
		} else {
		    set action signbinary
		    set mimeHdr($part,param,x-action) signbinary
		}		    
	    } elseif {"$action" == "pgp-signed"} {
		# Mutt propagates yet another x-action type
		set action signclear
		set mimeHdr($part,param,x-action) signclear
	    }
	}
    } else {
	set action "keys-only"
    }

    # decide which version to use / implicitely checks for pgp enabled
    if { [catch {Pgp_CheckVersion $mimeHdr($part,file) real v} err] } {
        Exmh_Debug "<Pgp_ShowMessage> $err"
        Exmh_Status "Unknown PGP message version"
        Mime_ShowDefault $tkw $part
	return
    }

    # Labels to display: "real" is the Version of the program 
    # which prepared the pgp text, "local" the version, which
    # will be used to decode the thing
    set real [set pgp($real,fullName)]
    set local [set pgp($v,fullName)]

    # get the recipients if necessary
    if [regexp {encrypt} $action] {
	if {![info exists mimeHdr($part,param,x-recipients)]} {
	    set recipients [string range [lindex [set pgp($v,myname)] 0] 2 end]
	} else {
	    set recipients $mimeHdr($part,param,x-recipients)
	}
	set recipients [Pgp_Misc_Map elem {string trim $elem} [split $recipients ","]]
    }

    # see if we should decode the thing
    if {![info exists mimeHdr($part,pgpdecode)]} {
	set mimeHdr($part,pgpdecode) \
            [expr {[set pgp($v,enabled)] && [expr [set pgp(decode,[set pgp($v,showinline)])]]}]
	if [set pgp($v,enabled)] {
	    MimeMenuAdd $part checkbutton \
		    -label "[set pgp(menutext,$action)] with ${local}..." \
		    -command [list busy MimeRedisplayPart $tkw $part] \
		    -variable mimeHdr($part,pgpdecode)
	}
    }

    ##########
    # Decode

    # # # #
    # Mime
    if {($format == "mime") || ($format == "text")} {
	if $mimeHdr($part,pgpdecode) {
	    set tmpfile [Mime_TempFile "decrypt"]

	    if [regexp "encrypt" $action] {
		
		# Decide whether or not to use expect
                set decrypt 1
                if {[info exists pgp($v,useexpectk)]} {
		    if {[set pgp(keeppass)] && [info exists exmh(expectk)] \
			&& [set pgp($v,useexpectk)]} {
		        Exmh_Debug "<Pgp_ShowMessage> Using expect"
		        Pgp_Exec_DecryptExpect $v $mimeHdr($part,file) $tmpfile msg
                        set decrypt 0
                    }
                }
		if $decrypt {
		    Pgp_Exec_Decrypt $v $mimeHdr($part,file) $tmpfile msg $recipients
		}
	    } else {
                # NEW
                Pgp_Exec_Verify $v $mimeHdr($part,file) msg $tmpfile
	    }

            # tune output
	    Pgp_InterpretOutput $v $msg pgpresult
            # display it
	    Pgp_DisplayMsg $v $tkw $part pgpresult

	    if {$pgpresult(ok)} {
		if [catch {set fileIO [open $tmpfile r]} err] {
		    Exmh_Debug "<Pgp_ShowMessage> $err"
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
		    "$real signed message - the signature hasn't been checked\n"
		TextButton $tkw "[set pgp(menutext,$action)] with $local" \
		    "$mimeHdr($part,menu) invoke \
                    [join [set pgp(menutext,$action)] {\ }]\\ with\\ [join $local {\ }]...
                    \n$tkw config -cursor xterm"
		$tkw insert insert "\n"
		MimeInsertSeparator $tkw $part 6
		if [catch {Pgp_Misc_Unsign [Pgp_Misc_FileString $mimeHdr($part,file)]} msg] {
		    $tkw insert insert "  can't find the signed message.\nPlease check it out: it might be suspicious !\n"
		    return
		}
		if {$format == "mime"} {
		    set tmpfile "$mimeHdr($part,file).msg"
		    Pgp_Misc_StringFile $msg $tmpfile
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
                if {$action == "encryptsign"} {
                    $tkw insert insert "This is a $real signed and encrypted message\n"
                } elseif {$action == "encrypt"} {
                    $tkw insert insert "This is a $real encrypted message\n"
                } elseif {$action == "signbinary"} {
                    $tkw insert insert "This is a $real binary signed message\n"
                }
		TextButton $tkw "[set pgp(menutext,$action)] with $local" \
		    "$mimeHdr($part,menu) invoke \
                    [join [set pgp(menutext,$action)] {\ }]\\ with\\ [join $local {\ }]...
                    \n$tkw config -cursor xterm"
		$tkw insert insert "\n"
		Mime_ShowDefault $tkw $part
	    }
	}
    # # # # # # #
    # keys-only
    } elseif {$format == "keys-only"} {
	if [set pgp($v,autoextract)] {
	    Pgp_Exec_ExtractKeys $v $mimeHdr($part,file) out 0
	} else {
	    MimeMenuAdd $part command \
		    -label "Extract $real keys into $local keyring..." \
		    -command "Pgp_Exec_ExtractKeys $v $mimeHdr($part,file) out"
	    TextButton $tkw "Extract $real keys into $local keyring" \
                "Pgp_Exec_ExtractKeys $v $mimeHdr($part,file) out"
	    $tkw insert insert "\n"
	}
	if $mimeHdr($part,pgpdecode) {
	    Pgp_Exec_Verify $v $mimeHdr($part,file) msg
            # NEW
	    regexp [set pgp($v,pat_validKeys)] $msg msg
	    $tkw insert insert "$msg\n"
	} else {
	    Mime_ShowDefault $tkw $part
	}
    # # # # # #
    # unknown
    } else {
	$tkw insert insert "PGP application format '$format' unknown\n"
	return
    }
}

# Attach keys
proc Pgp_InsertKeys { draft t } {
    global env pgp

    # Figure out PGP version from per-draft variable
    # multipgp originally had this passed in explicitly but this way
    # is a little cleaner (we think)
    set v $pgp(version,[SeditId $draft])

    if [catch {Pgp_KeyBox $v "Select the keys to be attached" Pub \
		[Pgp_Match_FlatKeyList $v "" Pub]} keys] {
	SeditMsg $t $keys
	return
    }
    # insert keys
    foreach key $keys {
	set keyid [lindex $key 0]
	if {![info exists done($keyid)]} {
	    set done($keyid) 1
	    set tmpfile [Mime_TempFile "insertkeys"]
            if [catch {Pgp_Exec_GetKeys $v $keyid $tmpfile} msg] {
                SeditMsg $t "[set pgp($v,fullName)] refuses to generate the key message"
		Exmh_Debug "<Pgp_InsertKeys> $msg"
		return
            }
	    # insert key file
	    SeditInsertFile $draft $t $tmpfile 1 7bit {application/pgp-keys} "keys of [lindex $key 4]"
	    File_Delete $tmpfile
	}
    }
}

proc Pgp_GetTextAttributes { summary } {
    global pgp

    switch $summary {
	GoodSignatureUntrusted {return $pgp(msgcolor,GoodUntrustedSig)}
	GoodSignatureTrusted   {return $pgp(msgcolor,GoodTrustedSig)}
	BadSignatureTrusted    {return $pgp(msgcolor,Bad)}
	BadSignatureUntrusted  {return $pgp(msgcolor,Bad)}
        SecretMissing          {return $pgp(msgcolor,Bad)}
        PublicMissing          {return $pgp(msgcolor,Bad)}
        default                {return $pgp(msgcolor,OtherMsg)}
    }
}

proc Pgp_DisplayMsg { v tkw part pgpresultvar } {
    upvar $pgpresultvar pgpresult
    global pgp

    Exmh_Debug "<Pgp_DisplayMsg> $pgpresult(msg)"

    if {[info exists pgpresult(keyid)]} {
	MimeMenuAdd $part command \
	    -label "Query keyserver for key $pgpresult(keyid)" \
	    -command "Pgp_WWW_QueryKey $v $pgpresult(keyid)"
	if {[regexp "PublicMissing" $pgpresult(summary)]} {
	    TextButton $tkw "Query keyserver for key $pgpresult(keyid)" \
		"Pgp_WWW_QueryKey $v $pgpresult(keyid)"
	} elseif {$pgpresult(expired) == 1} {
	    $tkw insert insert "Warning: Key has expired: "
	    TextButton $tkw "Query keyserver for key $pgpresult(keyid)" \
		"Pgp_WWW_QueryKey $v $pgpresult(keyid)"
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
    Exmh_Debug "pgpresult(ok): $pgpresult(ok)"
    if {$pgpresult(ok) == 0} {
	MimeInsertSeparator $tkw $part 6
	MimeWithDisplayHiding $tkw $part {
	    Mime_WithTextFile fileIO $tkw $part {
		set start [$tkw index insert]
		$tkw insert insert [read $fileIO]
		set end [$tkw index insert]
		Msg_TextHighlight $tkw $start $end
	    }
	}
    }
    MimeInsertSeparator $tkw $part 6
}

proc Pgp_InterpretOutput { v in outvar } {
    global pgp

    # This function is supposed to take the output given by the other
    # pgp exec procedures and writes different information to the
    # given array.  It is probably best to put all the code that
    # change from PGP version to version in a single place.

    upvar $outvar pgpresult

    Exmh_Debug "<Pgp_InterpretOutput> PGP Output:\n$in"
    regexp {(.*)child process exited abnormally} $in {} in
    set in [string trim $in]
    if {[string length $in] == 0} {
	set in "PGP execution produced no messages."
    }

    set pgpresult(ok) 1
    set pgpresult(expired) 0

    # get out the keyid
    eval [set pgp($v,cmd_Keyid)]

    if [info exists pgpresult(keyid)] {
	catch {Exmh_Debug "<Pgp_InterpretOutput> $pgpresult(keyid)"}
    }

    # interpret the output
    if { [info exists pgp($v,pat_Expired)] && \
       [regexp [set  pgp($v,pat_Expired)] $in redin]} {
       set pgpresult(expired) 1
    }
    if [regexp [set pgp($v,pat_SecretMissing)] $in redin] {
	set pgpresult(summary) "SecretMissing"
	set pgpresult(ok) 0
    } elseif [regexp [set pgp($v,pat_PublicMissing)] $in redin] {
	set pgpresult(summary) "PublicMissing"
	set pgpresult(ok) 1
    } elseif [regexp [set pgp($v,pat_GoodSignature)] $in redin] {
	if [regexp [set pgp($v,pat_Untrusted)] $in] {
	    set pgpresult(summary) "GoodSignatureUntrusted"
	} else {set pgpresult(summary) "GoodSignatureTrusted"}
    } elseif [regexp [set pgp($v,pat_BadSignature)] $in redin] {
	if [regexp [set pgp($v,pat_Untrusted)] $in] {
	    set pgpresult(summary) "BadSignatureUntrusted"
	} else {set pgpresult(summary) "BadSignatureTrusted"}
    } elseif [regexp [set pgp($v,pat_UnknownError)] $in redin] {
	set pgpresult(summary) "UnknownError"
	set pgpresult(ok) 0
    } else {
	set pgpresult(summary) "Other"
        set redin $in
    }

    # get out user (for ShortenOutput) now since beautify erases needed info
    eval [set pgp($v,cmd_User)]
    if {![info exists user]} {
	set user UNKNOWN
    }

    Exmh_Debug <TUNING>
    # An output tuning command
    # NOTE: pgpresult(msg) should also be set there
    # set pgpresult(msg) to
    #   in    (this is the complete original output from pgp)
    #   redin (this is the output matched out)
    if [info exists pgp($v,cmd_Beauty)] {
        eval [set pgp($v,cmd_Beauty)]
    }

    Exmh_Debug "<Pgp_InterpretOutput> beautiful output: $pgpresult(msg)"

    # DecryptExpect sometimes notifies the user that the
    # file is not encrypted.
    
    if [regexp {Note: File may not have been encrypted} $in] {
	set pgpresult(msg) \
	    "Note: File may not have been encrypted.\n\n$pgpresult(msg)"
    }

    Exmh_Debug OK=$pgpresult(ok) $pgpresult(summary)
    if [info exists pgpresult(keyid)] {
	set id $pgpresult(keyid)
    } else {
	set id {}
    }

    if [set pgp($v,shortmsgs)] {
	set pgpresult(msg) [Pgp_ShortenOutput $v $pgpresult(msg) $id \
				$pgpresult(summary) $user]
    }
}

proc Pgp_ShortenOutput { v pgpresult id summary user } {
    global pgp

    catch {Exmh_Debug "<PGP ShortenOutput> id = $id user = $user "}

    switch $summary {
       SecretMissing {return "Cannot decrypt, missing secret key."}
       PublicMissing {return "Missing public key for $id."}
       GoodSignatureUntrusted {return "Good untrusted signature from $user."}
       GoodSignatureTrusted {return "Good trusted signature from $user."}
       BadSignature {return "Bad signature from $user."}
       BadSignatureTrusted {return "WARNING: Bad trusted signature \
		from $user."}
       BadSignatureUntrusted {return "WARNING: Bad untrusted signature \
		from $user."}
       UnknownError {return "PGP Error while processing message:\n$pgpresult"}
       Other {return $pgpresult}
    }
}

