# pgpInterface.tcl -- 
# created by monnier@didec26.epfl.ch on Mon Dec 12 17:34:38 1994

# 
# 
# 

# $Log$
# Revision 1.13  2000/06/15 17:03:11  valdis
# Add X-Mailer: change, fix PGP Comment: line...
#
# Revision 1.12  2000/04/18 18:38:33  valdis
# Fix quote character to use ascii rather than iso8859-ish one
#
# Revision 1.11  1999/09/27 23:18:45  kchrist
# More PGP changes. Consolidated passphrase entry to sedit field or
# pgpExec routine. Made the pgp-sedit field aware of pgp(keeppass)
# and pgp(echopass). Moved pgp(keeppass), pgp(echopass) and
# pgp(grabfocus) to PGP General Interface. Fixed a minor bug left
# over from my previous GUI changes. Made pgp-sedit field appear and
# disappear based on its enable preference setting.
#
# Revision 1.10  1999/09/22 16:36:44  kchrist
# Changes made to support a different structure under the PGP Crypt... button.
# Instead of an ON/OFF pgp($v,sign) variable now we use it to specify
# the form of the signature (none, standard, detached, clear, or w/encrypt).
# Code changed in several places to support this new variable definition.
#
# Updated Sedit.html to include a description of the new interface.
#
# Revision 1.9  1999/08/22 18:57:36  bmah
# Sanitize PGP debugging entries before writing via Exmh_Debug.
#
# Revision 1.8  1999/08/13 00:39:05  bmah
# Fix a number of key/passphrase management problems:  pgpsedit now
# manages PGP versions, keys, and passphrases on a per-window
# basis.  Decryption now works when no passphrases are cached.
# One timeout parameter controls passphrases for all PGP
# versions.  seditpgp UI slightly modified.
#
# Revision 1.7  1999/08/04 22:43:39  cwg
# Got passphrase timeout to work yet again
#
# Revision 1.6  1999/08/04 16:30:17  cwg
# Don't prompt for a passphrase when we shouldn't.
#
# Revision 1.5  1999/08/03 04:05:54  bmah
# Merge support for PGP2/PGP5/GPG from multipgp branch.
#
# Revision 1.4.2.1  1999/06/14 20:05:15  gruber
# updated multipgp interface
#
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
proc Pgp_Exec { v exectype arglist outvar {privatekey {}} {interactive 0} } {
    global pgp env
    upvar $outvar output

    Exmh_Debug "Pgp_Exec $v $exectype $arglist $outvar $privatekey $interactive"

    if {![set pgp($v,enabled)]} {
	error "<[set pgp($v,fullName)]> isn't enabled"
    }

    set output {}
    if {![set pgp(keeppass)]} {
	Pgp_ClearPassword $v
    }
    if {$interactive || !([set pgp(keeppass)] || ($privatekey == {}))} {
        Exmh_Debug "<Pgp_Exec> Pgp_Exec_Interactive $v $exectype $arglist output"
	return [Pgp_Exec_Interactive $v $exectype $arglist output]
    } else {
	if {$privatekey == {}} {
            Exmh_Debug "<PGP Pgp_Exec> Pgp_Exec_Batch $v $exectype $arglist output"
	    return [Pgp_Exec_Batch $v $exectype $arglist output]
	} else {
	    Exmh_Debug v=$v

	    set keyid [lindex $privatekey 0]
	    Exmh_Debug keyid=$keyid
	    # Check for passphrase. Pgp_GetPass is cache and expire aware!
	    set p [Pgp_GetPass $v $privatekey]
	    #Exmh_Debug "<Pgp_Exec> got passwd >$p<"

	    if {[string length $p] == 0} {
		return 0
	    }
            Exmh_Debug "<Pgp_Exec> Pgp_Exec_Batch $v $exectype $arglist output \(password\)"
	    return [Pgp_Exec_Batch $v $exectype $arglist output $p]
	}
    }
}

# batch mode
proc Pgp_Exec_Batch { v exectype arglist outvar {password {}} } {
    global pgp exmh
    upvar $outvar output

    Exmh_Debug "Pgp_Exec_Batch $v $exectype $arglist $outvar \(password\)"

    set tclcmd [concat exec [set pgp($v,executable,$exectype)] \
                              [subst [set pgp($v,flags_batch)]] $arglist]

    Exmh_Debug "<Pgp_Exec_Batch> $tclcmd"

    # Set file descriptor for passphrase on stdin
    if {$password == {}} {
        Pgp_${v}_PassFdUnset
    } else {
        lappend tclcmd << $password
        Pgp_${v}_PassFdSet
    }

    set result [catch {eval $tclcmd} output]
    Exmh_Debug "<Pgp_Exec_Batch>: Exit status: $result"

    # Unset file descriptor for passphrase
    Pgp_${v}_PassFdUnset

    regsub -all "\x07" $output "" output
    return $result
}

# interactive mode
proc Pgp_Exec_Interactive { v exectype arglist outvar } {
    global tcl_platform pgp
    upvar $outvar output

    Exmh_Debug "Pgp_Exec_Interactive $v $exectype $arglist $outvar"

    set pgpcmd [set pgp($v,executable,$exectype)]
    set args [concat [subst [set pgp($v,flags_interactive)]] $arglist]

    # Be sure, that passphrase isn't read from stdin
    Pgp_${v}_PassFdUnset

    # Build shellcommand
    set shcmd "
        $pgpcmd \"[join [Pgp_Misc_Map x {
	    regsub {([$\"\`])} $x {\\1} x
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

    # Hint: XFree86 xterm does not support output logging (Markus)
    # -l and -lf not supported

    set tclcmd {exec $xterm -l -lf $logfile -title [set pgp($v,fullName)] -e sh -c $shcmd}
    Exmh_Debug "<Pgp_Exec_Interactive> $tclcmd"
    set result [catch $tclcmd]
    if [catch {open $logfile r} log] {
	set output {}
    } else {
	set output [read $log]
	close $log
    }

    eval [set pgp($v,cmd_cleanOutput)]

    return $result
}

proc Pgp_Exec_CheckPassword { v password key } {
    global pgp

    Exmh_Debug "Pgp_Exec_CheckPassword $v \(password\) $key"

    set in [Mime_TempFile "pwdin"]
    set out [Mime_TempFile "pwdout"]
    set filio [open $in w 0600]
    puts $filio "salut"
    close $filio
    set keyid [lindex $key 0]

    Pgp_Exec_Batch $v sign [subst [set pgp($v,args_signClear)]] err $password

    File_Delete $in

    # pgp thinks he knows better how to name files !
    if {![file exists $out] && [file exists "$out.asc"]} {
	Mh_Rename "$out.asc" $out
    }
    if {![file exists $out]} {
        if [regexp [set pgp($v,pat_checkError)] $err x match] {
            Exmh_Status ?${match}?
        }
        Exmh_Debug "<Pgp_Exec_CheckPassword> $err"
	return 0
    } else {
	File_Delete $out
	return 1
    }
}

# returns a list of keys. Each "key" is a list whose first four elements are
# keyid algo subkeyid algo
# and the next ones are the corresponding userids
# {keyid algo subkeyid algo userid userid userid ...}
proc Pgp_Exec_KeyList { v pattern keyringtype } {
    global pgp

    Exmh_Debug "Pgp_Exec_Keylist $v $pattern $keyringtype"

    set pattern [string trimleft $pattern "<>|2"]
    set arglist [subst [set pgp($v,args_list$keyringtype)]]
    ldelete arglist {}

    Pgp_Exec_Batch $v key $arglist keylist

    Exmh_Debug "<Pgp_Exec_Keylist>: $keylist"

    # drop revoked and noninteresting keys
    regsub -all [set pgp($v,pat_dropKeys)] $keylist {} keylist

    # Form a list of keys
    regsub -all [set pgp($v,pat_splitKeys)] $keylist \x81 keylist
    set keylist [split $keylist \x81]

    Exmh_Debug "<Pgp_Exec_Keylist>: Splitted keylist: $keylist"

    # Match out interesting keys
    set keypattern [set pgp($v,pat_key$keyringtype)]

    # subkeyparsing
    if [info exists pgp($v,pat_key${keyringtype}_sub)] {
        set subkeypattern [set pgp($v,pat_key${keyringtype}_sub)]
    }

    # uid parsing
    set uidpattern [set pgp($v,pat_uid)]

    # grep keys
    set AllowedToFollow 0
    set keys {}
    foreach line $keylist {
        catch {unset userid}
        catch {unset keyid}
        set goodline 0
        #
        if {[eval [set pgp($v,cmd_keyMatch)]]} {
            if {[info exists userids] && [info exists keyids]} {
                if {[llength $keyids] < 4} {
                    lappend keyids {} {}
                }
                lappend keys [concat $keyids $userids]
                unset keyids
                unset userids
            }
            lappend keyids "0x$keyid" $algo
            catch {lappend userids $userid}
            set AllowedToFollow 1
            set goodline 1
        }    
        if [info exists subkeypattern] {
            if {[eval [set pgp($v,cmd_keyMatch_sub)]] && $AllowedToFollow} {
                lappend keyids "0x$keyid" $algo
                set goodline 1
            }
        }
        if {[eval [set pgp($v,cmd_uidMatch)]] && $AllowedToFollow} {
            lappend userids $userid
            set goodline 1
        }
        if {!$goodline} {
            set AllowedToFollow 0
        }
    }
    if {[info exists userids] && [info exists keyids]} {
        if {[llength $keyids] < 4} {
            lappend keyids {} {}
        }
        lappend keys [concat $keyids $userids]
    }

    # keys is of the format { {keyid algo subkeyid algo userid userid} {} {}...}
    return $keys
}

# parse config file
# this is only needed to set pgp($v,myname)
proc Pgp_Exec_ParseConfigTxt { v file } {
    global pgp

    Exmh_Debug "Pgp_Exec_ParseConfigTxt $file"

    if [catch {open $file r} in] {
	return
    }
    for {set len [gets $in line]} {$len >= 0} {set len [gets $in line]} {
	if [regexp -nocase "^\[ \t]*(\[a-z]+)\[ \t]*=(\[^#]*)" $line {} option value] {
	    set pgp($v,config,[string tolower $option]) [string trim $value " \t\""]
	}
    }
    close $in
}


###############
# Encrypt/Sign

proc Pgp_Exec_Encrypt { v in out tokeys } {
    global pgp

    Exmh_Debug "Pgp_Exec_Encrypt $v $in $out $tokeys"

    Pgp_Exec_Batch $v encrypt [subst [set pgp($v,args_encrypt)]] output
    if {[Pgp_Exec_CheckSuccess $v $out $output "encrypted text"]} {
        # pgp refuses to generate an encrypted message
        # if a key was untrusted
        # interactively proceed
        Pgp_Exec_Interactive $v encrypt [subst [set pgp($v,args_encrypt)]] output
    }
}

proc Pgp_Exec_EncryptSign { v in out sigkey tokeys } {
    global pgp

    Exmh_Debug "Pgp_Exec_EncryptSign $v $in $out $tokeys"

    set keyid [lindex $sigkey 0]
    Pgp_Exec $v encrypt [subst [set pgp($v,args_encryptSign)]] output $sigkey
    if {[Pgp_Exec_CheckSuccess $v $out $output "signed and encrypted text"]} {
        # pgp refuses to generate an encrypted/signed message
        # if a key was untrusted
        # interactively proceed
        Pgp_Exec $v encrypt [subst [set pgp($v,args_encryptSign)]] output $sigkey 1
    }
}
 
proc Pgp_Exec_Sign { v in out sigkey opt } {
    global pgp

    Exmh_Debug "Pgp_Exec_Sign $v $in $out $sigkey $opt"

    set keyid [lindex $sigkey 0]
    switch $opt {
	standard {Pgp_Exec $v sign [subst [set pgp($v,args_signBinary)]] output $sigkey}
	detached {Pgp_Exec $v sign [subst [set pgp($v,args_signDetached)]] output $sigkey}
	clearsign {Pgp_Exec $v sign [subst [set pgp($v,args_signClear)]] output $sigkey}
	default {set output "Pgp_Exec_Sign error. Unknown option."}
    }
    Pgp_Exec_CheckSuccess $v $out $output "signed text"
}
    
# Look if pgp generated pgp code
proc Pgp_Exec_CheckSuccess {v out output object} {
    global pgp

    Exmh_Debug "Pgp_Exec_CheckSuccess $v $out $output $object"

    # pgp thinks he knows better how to name files !
    if {![file exists $out] && [file exists "$out.asc"]} {
	Mh_Rename "$out.asc" $out
    }
    if {![file exists $out]} {
        # pgp5 refuses to generate ciphertext in batchmode if tokey is untrusted
        if {[regexp [set pgp($v,pat_Untrusted)] $output]} {
            return 1
        } else {
	    error "[set pgp($v,fullName)] refused to generate the ${object}:\n$output"
        }
    } else {
	return 0
    }
}    


#################
# Decrypt/Verify

# get the key to use for decryption
proc Pgp_Exec_GetDecryptKey {v in recipients} {
    global pgp

    Exmh_Debug "Pgp_Exec_GetDecryptKey $v $in $recipients"

    # If the user has time (this doesn't consume more than a half second)
    # and has set preferences to run pgp twice,
    # run pgp a first time to get out the decryption keyid
    set runtwice 0
    if {[info exists pgp($v,runtwice)] && [set pgp($v,runtwice)]} {
        set runtwice 1
    }
    if {$runtwice} {
      Exmh_Debug "<Pgp_Exec_GetDecryptKey> Pgp_Exec_GetDecryptKeyid $v $in"
      set keyid [Pgp_Exec_GetDecryptKeyid $v $in]
      if {$keyid == {}} {
        return {}
      } elseif {[string match $keyid SYM]} {
        # SYMMETRIC ENCRYPTION
        set key [list SYM {} {} {} "symmetrically encrypted message"]
      } else {
	  # One of user's private keys?  If so, than use it.
        foreach key [set pgp($v,privatekeys)] {
          if {[regexp $keyid [lindex $key 0]]} {
            return $key
          } elseif {[regexp $keyid [lindex $key 2]]} {
            return $key
          }
        }
      }
    } else {
      set recipients [string tolower $recipients]
      # Messages get encrypted with the subkey for dsa/elg
      # I don't know if there are subkeyids in the recipients list if dsa/elg
      # Lets search for mainkeys
      set useablekeys [Pgp_Misc_Filter key \
         {[string first [string tolower [string range [lindex $key 0] 2 end]] $recipients] >= 0} \
         [set pgp($v,privatekeys)]]
      # If no mainkeys were found, search for subkeys
      if {[llength $useablekeys] == 0} {
        set useablekeys [Pgp_Misc_Filter key \
         {[string first [string tolower [string range [lindex $key 2] 2 end]] $recipients] >= 0} \
         [set pgp($v,privatekeys)]]
      }
      set knownkeys [Pgp_Misc_Filter key \
         {[info exists pgp($v,pass,[lindex $key 0])]} $useablekeys]

      if {[llength $knownkeys] > 0} {
        set key [lindex $knownkeys 0]
      } elseif {[llength $useablekeys] > 0} {
        set key [lindex $useablekeys 0]
      } else {
        set key {}
      }
    }
    return $key
}

proc Pgp_Exec_GetDecryptKeyid {v in} {
    global pgp

    Exmh_Debug "Pgp_Exec_GetDecryptKeyid $v $in"

    Pgp_Exec_Batch $v verify [subst [set pgp($v,args_getDecryptKeyid)]] output
    if {[regexp [set pgp($v,pat_getDecryptKeyid)] $output {} keyid]} {
    } elseif {[regexp [set pgp($v,pat_getDecryptSym)] $output]} {
      set keyid SYM
    } else {
      Exmh_Debug "<Pgp_Exec_GetDecryptKeyid> No key matches"
      return {}
    }
    Exmh_Debug "<Pgp_Exec_GetDecryptKeyid> keyid $keyid"
    return $keyid
}

proc Pgp_Exec_Decrypt { v in out outvar recipients } {
    global pgp
    upvar $outvar output

    Exmh_Debug "Pgp_Exec_Decrypt $v $in $out $outvar $recipients"

    set key [Pgp_Exec_GetDecryptKey $v $in $recipients]
    Exmh_Debug "<Pgp_Exec_Decrypt> $key"
    
    Pgp_Exec $v verify [subst [set pgp($v,args_decrypt)]] output $key
}

proc Pgp_Exec_Verify { v in outvar {out {}}} {
    upvar $outvar output
    global pgp

    Exmh_Debug "Pgp_Exec_Verify $v $in $outvar $out"

    if {$out == {}} {
        Exmh_Debug "<Pgp_Exec_VerifyOnly>: Pgp_Exec_Verify $v $in $outvar $out"
        Pgp_Exec $v verify [subst [set pgp($v,args_verifyOnly)]] output
    } else {
        Exmh_Debug "<Pgp_Exec_VerifyOut>: Pgp_Exec_Verify $v $in $outvar $out"
        Pgp_Exec $v verify [subst [set pgp($v,args_verifyOut)]] output
    }
}

proc Pgp_Exec_VerifyDetached { v sig text outvar } {
    upvar $outvar output
    global pgp

    Exmh_Debug "Pgp_Exec_VerifyDetached $v $sig $text $outvar"

    Pgp_Exec $v verify [subst [set pgp($v,args_verifyDetached)]] output
}

##################
# NOT WITH GNUPG
#
# This is called if expectk is enabled.  It seemed the best (easiest
# for me) way to do it was to have this proc terminate when the
# message is finished displaying just as Exec_Decrypt would do.
# However, this is a problem for the the expectk script
# (PgpDecryptExpect), which may need to communicate with exmh to ask
# for passwords, etc.  

# My slow and inelegant solution was to tell exmh-bg all the necessary
# information and let PgpDecryptExpect communicate with exmh-bg,
# exiting when done.
#
proc Pgp_Exec_DecryptExpect { v infile outfile msgvar } {
    global exmh exwin sedit pgp
    upvar $msgvar msg

    # First update exmh-bg arrays.  I hope that pgp, getpass,
    # and exwin will be enough.  For exwin seems we have
    # to temporarily change the mtext error to avoid an error when
    # the password window is closed and focus is returned to .msg.t

    send $exmh(bgInterp) [list array set pgp [array get pgp]]
    send $exmh(bgInterp) [list array set getpass [array get getpass]]
    send $exmh(bgInterp) [list array set sedit [array get sedit]]
    send $exmh(bgInterp) [list array set exwin [array get exwin]]
    send $exmh(bgInterp) [list set exwin(mtext) .]

    if [catch {exec $exmh(expectk) -f $exmh(library)/PgpDecryptExpect \
                        $v $infile $outfile $exmh(bgInterp)} error] {
        Exmh_Debug "<PGP Exec_DecryptExpect> error: $error"
        Exmh_Status "Error executing expect process" warn
    }

    set msg [lindex [send $exmh(bgInterp) {list $pgpmsg}] 0]
    send $exmh(bgInterp) [list unset pgpmsg]

    # Now reload pass and exwin from exmh-bg
    foreach index [send $exmh(bgInterp) [list array names pgp $v,pass,*]] {
        set pgp($index) [send $exmh(bgInterp) [list set pgp($index)]]
        send $exmh(bgInterp) [list unset pgp($index)]
    }
    # The following appears no longer to be necessary, but now I don't see
    # how to change the position of the getpass window
    #
    #    set exwin(geometry,.getpass) \
    #    [send $exmh(bgInterp) list {$exwin(geometry,.getpass)}]
}

####################

proc Pgp_Exec_ExtractKeys { v file outvar {interactive 1} } {
    global env pgp
    upvar $outvar output

    Exmh_Debug "Pgp_Exec_ExtractKeys $v $file $outvar $interactive"

    set output {}
    if [Pgp_Exec $v key [subst [set pgp($v,args_importKey)]] output {} $interactive] {
        Exmh_Status "Key extract failed"
        Exmh_Debug "<Pgp_Exec_ExtractKeys> $output"
        return 0
    } else {
        Exmh_Debug "<Pgp_Exec_ExtractKeys> $output"
        return 1
    }
}

# Get the passphrase for keyinstance key. We also take care of setting
# passphrase timeouts. Return a stored passphrase when possible.
proc Pgp_GetPass { v key } {
    global pgp

    Exmh_Debug "Pgp_GetPass $v $key"

    if {[lsearch -glob [set pgp($v,privatekeys)] "[lindex $key 0]*"] < 0} {
        return {}
    }

    # Search the passphrase "cache". Need to set-timeout here in case
    # the pass phrase was created via the seditpgp entry field.
    # Because of DecryptExpects asymmetric passphrase storage
    # we need to look for both mainkey and subkey separately
    set keyid [lindex $key 0]
    set subkeyid [lindex $key 2]
    if {([info exists pgp($v,pass,$keyid)]) && \
	    ([string length $pgp($v,pass,$keyid)] > 0)} {
	Pgp_SetPassTimeout $v $keyid
	if {[string length $subkeyid] > 0} {
	    Pgp_SetPassTimeout $v $subkeyid
	}
        return [set pgp($v,pass,$keyid)]
    } elseif {([string length $subkeyid] > 0) && \
	    ([info exists pgp($v,pass,$subkeyid)]) && \
	    ([string length $pgp($v,pass,$subkeyid)] > 0)} {
	Pgp_SetPassTimeout $v $subkeyid
        return [set pgp($v,pass,$subkeyid)]
    }

    # Not in "cache" (or expired) go ask for it.
    while 1 {
	Exmh_Debug "Attempt to get passphrase for [lindex $key 0] [lindex $key 1] [lindex $key 4]"
        if [catch {Pgp_Misc_GetPass $v "Enter [set pgp($v,fullName)] passphrase" \
                                   "Passphrase for [lindex $key 0] [lindex $key 1] [lindex $key 4]"} password] {
            return {}
        } elseif {[string match $keyid SYM]} {
            # SYMMETRIC ENCRYPTION
            return $password
        } elseif {[Pgp_Exec_CheckPassword $v $password $key]} {
            if [set pgp(keeppass)] {
                set pgp($v,pass,$keyid) $password
		Pgp_SetPassTimeout $v $keyid
                # Because of DecryptExpect we need to store passphrase
                # for mainkey and subkey
                if {[string length $subkeyid] > 0} {
                    set pgp($v,pass,$subkeyid) $password
		    Pgp_SetPassTimeout $v $subkeyid
                }
            }
            return $password
        }
    }
}

proc Pgp_SetPassTimeout {v keyid} {
    global pgp

    if [info exists pgp(timeout,$keyid)] {
	Exmh_Debug "Cancelling previous timeout for $keyid"
	after cancel $pgp(timeout,$keyid)
	unset pgp(timeout,$keyid)
    }
    Exmh_Debug "Setting timeout for $keyid ($v) in $pgp(passtimeout) minutes"
    set pgp(timeout,$keyid) \
	    [after [expr $pgp(passtimeout) * 60 * 1000] \
	           [list Pgp_ClearPassword $v $keyid]]
}

# wipe password away
proc Pgp_ClearPassword { v {keyid {}} } {
    global pgp

    if {[string length $keyid] == 0} {
        foreach index [array names pgp $v,pass*] {
	    Exmh_Debug "Clearing pgp($index)"
            set pgp($index) {}
        }
        set pgp($v,pass,) {}
    } else {
	catch {Exmh_Debug "Clearing only pgp($v,pass,$keyid)"}
        catch {set pgp($v,pass,$keyid) {}}
    }
}

proc Pgp_Exec_GetKeys { v keyid file } {
    global pgp

    Exmh_Debug "Pgp_Exec_GetKeys $v $keyid $file"

    set arglist [subst [set pgp($v,args_exportKey)]]
    ldelete arglist {}
    if [Pgp_Exec $v key $arglist msg] {
        error $msg
    } else {
        Pgp_Exec_CheckSuccess $v $file $msg "key block for $keyid"
    }
}

# Shutdown Cleanup
proc Pgp_CheckPoint {} {
    foreach cmd { Pgp_Match_CheckPoint } {
        if {[info command $cmd] != {}} {
            if [catch {$cmd} err] {
                puts stderr "$cmd: $err"
            }
        }
    }
}


### Init ###

proc Pgp_Exec_Init {} {
    global env pgp

    Pgp_SetPath

    # needed in pgpMatch
    if {![info exists env(LOCALHOST)]} {
        if [catch {exec uname -n} env(LOCALHOST)] {
            set env(LOCALHOST) localhost
        }
    }

    foreach v $pgp(supportedversions) {
        if {[set pgp($v,enabled)]} {
            set pgp($v,pass,) {}
            # Parse config file
            if { [set pgp($v,parse_config)] } {
                Pgp_Exec_ParseConfigTxt $v [set pgp($v,configFile)]
            }
            if {![file exists [set pgp($v,secring)]]} {
                set pgp($v,secring) {}
            }
            set pgp($v,privatekeys) [Pgp_Exec_KeyList $v "" Sec]
            #
            if [info exists pgp($v,config,myname)] {
                set myname [string tolower [set pgp($v,config,myname)]]
                foreach key [set pgp($v,privatekeys)] {
                    if {[string first $myname [string tolower $key]] >= 0} {
			# pgp($v,myname) holds the default key to use
			# for each version of PGP.  It will be used
			# to initialize pgp($v,myname,$id) in each
			# sedit window.
                        set pgp($v,myname) $key
                        break
                    }
                }
                if {![info exists pgp($v,myname)]} {
                    if [catch {Pgp_Match_Simple $v [set pgp($v,config,myname)] Sec} key] {
                        tk_messageBox -type ok -icon warning \
                                      -title "[set pgp($v,fullName)] Init" \
                                      -message "The name specified in your [set pgp($v,fullName)] config file couldn't be unambiguously found in your key rings !"
                        set pgp($v,myname) {}
                    } else {
                        set pgp($v,myname) $key
                    }
                }
            } else {
                set pgp($v,myname) [lindex [set pgp($v,privatekeys)] 0]
            }
        }
    }
}
