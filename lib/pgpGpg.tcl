# pgpGpg.tcl

# $Log$
# Revision 1.10  2000/02/07 13:23:34  gruber
# fixed run twice function to work with now short keyids
#
# Revision 1.9  1999/10/25 15:38:39  kchrist
# Added a dropKeys pattern to pgpGPG.tcl.
#
# Simplified PGP GUI by removing "detached" signature option. Problem
# was that MIME+standard includes a copy of the message being signed
# in the signature attachement. What really should be used is
# MIME+detached. Decided to overload the meaning of "standard". If
# the format is plain, standard means "binary". If the format is
# anything else, standard means "detached". Less flexibility but
# better chances of "doing the right thing".
#
# Revision 1.8  1999/09/30 03:51:07  kchrist
# pgp($v,cmd_Beauty) was getting in the way of pgp($v,cmd_User) for
# v=gpg so I had to rearrange things a bit.
#
# Revision 1.7  1999/09/27 23:18:45  kchrist
# More PGP changes. Consolidated passphrase entry to sedit field or
# pgpExec routine. Made the pgp-sedit field aware of pgp(keeppass)
# and pgp(echopass). Moved pgp(keeppass), pgp(echopass) and
# pgp(grabfocus) to PGP General Interface. Fixed a minor bug left
# over from my previous GUI changes. Made pgp-sedit field appear and
# disappear based on its enable preference setting.
#
# Revision 1.6  1999/08/24 15:51:07  bmah
# Patch from Kevin Christian to make email PGP key queries work, and
# to make key attachment RFC 2015 compliant.
#
# Revision 1.5  1999/08/13 15:10:06  bmah
# One more try at fixing the problems with 8-byte GPG keyIDs, with a
# patch from Kevin.Christian@lsil.com.
#
# Revision 1.4  1999/08/13 00:39:05  bmah
# Fix a number of key/passphrase management problems:  pgpsedit now
# manages PGP versions, keys, and passphrases on a per-window
# basis.  Decryption now works when no passphrases are cached.
# One timeout parameter controls passphrases for all PGP
# versions.  seditpgp UI slightly modified.
#
# Revision 1.3  1999/08/11 04:09:20  bmah
# Fix problems caused by GPG returning key IDs that are 8 bytes long,
# when exmh (and keyservers) like to work with 4-byte key IDs.
#
# Revision 1.2  1999/08/03 04:05:54  bmah
# Merge support for PGP2/PGP5/GPG from multipgp branch.
#
# Revision 1.1.4.1  1999/06/14 20:05:15  gruber
# updated multipgp interface
#
# Revision 1.1  1999/06/14 15:14:53  markus
# added files
#
# Revision 1.4  1998/12/14 19:22:42  markus
# modulepath, untrusted problem, toplevel
#
# Revision 1.3  1998/12/07 16:10:20  markus
# fixed compressalgo handling
#
# Revision 1.2  1998/12/06 16:23:44  markus
# DecryptExpect and subkey support
#
# Revision 1.1.1.1  1998/11/24 22:34:46  markus
# Initial revision
#

#######################################################################
# GNUPG CONFIG

proc Pgp_gpg_Init {} {
global pgp
###

# Yes, we need network keyfetching
Pgp_WWW_Init

set pgp(pref,HKPkeyserverUrl) { HKPkeyserverUrl HKPKeyServerUrl {keys.pgp.com}
{Horowitz Key Protocol Server}
"The hkp (Horowitz Key Protokol) is a subset of the http.
It´s used to tranfer keys to and from a keyserver.
Give here a hkp server name." }


# Needed for Preferences
set pgp(gpg,description) "GNUPG is a free GPLed PGP clone written by Werner Koch"
set pgp(gpg,prefs) [list rfc822 \
                         choosekey runtwice cacheids minmatch showinline \
                         shortmsgs autoextract \
                         keyserver keyquerymethod HKPkeyserverUrl keyserverUrl \
                         keyothermethod ]

# this is called when preferences are set
proc Pgp_gpg_Preferences {} {
    global exmh pgp
    # GnuPG algorithms and algorithm modules
    set label $pgp(gpg,fullName)
    Preferences_Add "$label interface" {} [list \
                [list pgp(gpg,comment) gpgComment \
"Exmh $exmh(version)" "GnuPG Comment" \
"Specify the comment GnuPG should put in the comment field
of encrypted or signed text."] \
                [list pgp(gpg,modulepath) gpgModulePath \
{/usr/local/lib/gnupg} "GnuPG Modules Path" \
"GnuPG is able to dynamically load cipher, digest, pubkey etc.
algorithm extension modules.
Specify a colon (:) separated list of directories, where exmh should
look for extension modules."] \
                [list pgp(gpg,ciphermods) gpgCipherMods \
{skipjack idea} "GnuPG Cipher Modules" \
"The Cipher Algorithm modules, exmh should look for
in the Modules Path."] \
                [list pgp(gpg,digestmods) gpgDigestMods \
{tiger} "GnuPG Digest Modules" \
"The Digest Algorithm modules, exmh should look for
in the Modules Path."] \
                [list pgp(gpg,pubkeymods) gpgPubkeyMods \
{rsa} "GnuPG PubKey Modules" \
"The Public Key Algorithm modules, exmh should look for
in the Modules Path."] \
                [list pgp(gpg,pgp5compatibility) gpgPgp5Compatibility \
ON "PGP 5.0 Compatibility" \
"You MUST have enabled this if you want that GnuPG produces
PGP 5.0 compatible messages.
Having this enabled, you don´t need PGP 5.0 any more." ] ]

    # Before we can build the algorithm choice preferences part
    # we need to examine, which modules are installed on the system
    # and build a complete list of algos
    Pgp_Gpg_Algorithms

    # preferences
    Preferences_Add "$label interface" {} [list \
                [list pgp(gpg,cipheralgo) gpgCipherAlgo \
[concat CHOICE $pgp(gpg,cipheralgos)] "Default Cipher Algo" \
"Your preferred cipher algorithm."] \
                [list pgp(gpg,digestalgo) gpgDigestAlgo \
[concat CHOICE $pgp(gpg,digestalgos)] "Default Digest Algo" \
"Your preferred digest algorithm."] \
                [list pgp(gpg,compressalgo) gpgCompressAlgo \
[concat CHOICE $pgp(gpg,compressalgos)] "Default Compress Algo" \
"The algorithm, GnuPG uses to compress the text before encrypting.
You have the choice between the ZIP (RFC1951)
and the ZLIB (RFC1950) algo. ZIP is used by PGP(2/5).
If you choose none, the text is left uncompressed." ] ]
    } 


#######################################################################
# GPG BASIC CONFIG
# builtin gpg algos
set pgp(gpg,cipheralgos) {3des cast5 blowfish twofish}
set pgp(gpg,digestalgos) {sha1 md5 ripemd160}
set pgp(gpg,compressalgos) {zip zlib none}
set pgp(gpg,pubkeyalgos) {}
# module files
set pgp(gpg,ciphermodfiles) {}
set pgp(gpg,digestmodfiles) {}
set pgp(gpg,pubkeymodfiles) {}
#######################################################################

# Searches Algorithms
proc Pgp_Gpg_Algorithms {} {
    global pgp
    set wd [pwd]
    foreach path [split $pgp(gpg,modulepath) :] {
        set path [string trim $path]
        catch {
            cd $path
            foreach file [glob -nocomplain *] {
	        if { ![file isdirectory $file] } {
		    if {[lsearch $pgp(gpg,ciphermods) $file] >= 0} {
		        lappend pgp(gpg,cipheralgos) $file
                        lappend pgp(gpg,ciphermodfiles) ${path}/$file
		    } elseif {[lsearch $pgp(gpg,digestmods) $file] >= 0} {
		        lappend pgp(gpg,digestalgos) $file
                        lappend pgp(gpg,digestmodfiles) ${path}/$file
		    } elseif {[lsearch $pgp(gpg,pubkeymods) $file] >= 0} {
		        lappend pgp(gpg,pubkeyalgos) $file
                        lappend pgp(gpg,pubkeymodfiles) ${path}/$file
                    }
                }
	    }
        }
    }
    cd $wd
}

# Simple Dialog Box to choose Algorithms
proc Pgp_gpg_ChooseAlgos {} {
    global pgp
    if [winfo exists .gregor] {
        return
    }
    set t [toplevel .gregor]
    wm title $t "Default Algorithms"
    wm resizable $t 0 0
    set m1 [frame $t.main1]
    pack $m1 -side left
    set m2 [frame $t.main2]
    pack $m2 -side left
    # Cipheralgo
    set f [frame $m2.frame1]
    pack $f -side top -expand 1 -fill x
    set l [label $m1.cipher -text "Default cipheralgo"]
    pack $l -side top
    foreach algo $pgp(gpg,cipheralgos) {
        set r [radiobutton $f.$algo -variable pgp(gpg,cipheralgo) \
                           -text $algo -value $algo]
        pack $r -side left
    }
    # Digestalgo
    set f [frame $m2.frame2]
    pack $f -side top -expand 1 -fill x
    set l [label $m1.digest -text "Default digestalgo"]
    pack $l -side top
    foreach algo $pgp(gpg,digestalgos) {
        set r [radiobutton $f.$algo -variable pgp(gpg,digestalgo) \
                           -text $algo -value $algo]
        pack $r -side left
    }
    # Compressalgo
    set f [frame $m2.frame3]
    pack $f -side top -expand 1 -fill x
    set l [label $m1.compress -text "Default compressalgo"]
    pack $l -side top
    foreach algo $pgp(gpg,compressalgos) {
        set r [radiobutton $f.$algo -variable pgp(gpg,compressalgo) \
                           -text $algo -value $algo]
        pack $r -side left
    }
    # OK
    set b [button $f.ok -text "OK" -command "destroy $t"]
    pack $b -side right
}

# Forms the standard flags and arguments of the commandline
proc Pgp_Gpg_Arglist {} {
    global pgp
    set modfiles \
         [concat $pgp(gpg,ciphermodfiles) \
                 $pgp(gpg,digestmodfiles) \
                 $pgp(gpg,pubkeymodfiles) ]
    ldelete modfiles {}
    set arglist [list --no-greeting --comment $pgp(gpg,comment)]
    # Take it
    if {$pgp(gpg,pgp5compatibility)} {
        lappend arglist --force-v3-sigs
        # default: cast5
        switch $pgp(gpg,cipheralgo) {
            3des  {}
            cast5 {}
            idea  {}
            default {set pgp(gpg,cipheralgo) cast5}
        }
        # default: sha1
        switch $pgp(gpg,digestalgo) {
            md5  {}
            sha1 {}
            default {set pgp(gpg,digestalgo) sha1}
        }
        switch $pgp(gpg,compressalgo) {
            zip {}
            default {set pgp(gpg,compressalgo) zip}
        }
    }
    foreach modfile $modfiles {
        set arglist [concat $arglist [list \
                     --load-extension $modfile] ]
    }
    set arglist [concat $arglist [list \
                     --cipher-algo $pgp(gpg,cipheralgo) \
                     --digest-algo $pgp(gpg,digestalgo) ] ]
    # compressalgo
    switch $pgp(gpg,compressalgo) {
        zip  { set arglist [concat $arglist --compress-algo 1] }
        zlib { set arglist [concat $arglist --compress-algo 2] }
        none { set arglist [concat $arglist -z 0] }
    }
    ldelete arglist {}
    return $arglist
}


#######################################################################
# Flags, Commands, Patterns, Settings
#

# Should config file be parsed
set pgp(gpg,parse_config) 0

#######
# Exec
#############
# Exec_Batch
# Batchmode flags
set pgp(gpg,flags_batch) {--batch --status-fd 2 [Pgp_Gpg_Arglist]}
#
proc Pgp_gpg_PassFdSet {} {
    upvar tclcmd tclcmd
    set tclcmd [linsert $tclcmd 2 --passphrase-fd 0]
}
#
proc Pgp_gpg_PassFdUnset {} {
}

###################
# Exec_Interactive
# Interactive flags
set pgp(gpg,flags_interactive) {[Pgp_Gpg_Arglist]}
# Cleanup output
set pgp(gpg,cmd_cleanOutput) { regsub -all "\[\x0d\x07]" $output {} output
                                   regexp "gpg:.*\$" $output output
                                   set output [string trim $output] }

###############
# Exec_KeyList
# List pubkeys args prototype
set pgp(gpg,args_listPub) {--with-colons --list-keys \"$pattern\"}
# List seckeys args prototype
set pgp(gpg,args_listSec) {--with-colons --list-secret-keys \"$pattern\"}
# Pattern that matches out revoked and nonvalid keys
set pgp(gpg,pat_dropKeys) {(^|\n)(pub|sub|sec|ssb|uid):[dren]:[^\n]+}
# Where to split up the listKeys raw output to form a list
set pgp(gpg,pat_splitKeys) \n
# Patterns that match out interesting keys
set pgp(gpg,pat_keySec) \
                {^(pub|sec):[^:]*:[^:]*:([^:]*):[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]([^:]+):[^:]*:[^:]*:[^:]*:[^:]*:([^:]+).*$}
set pgp(gpg,pat_keySec_sub) \
                {^(ssb):[^:]*:[^:]*:([^:]+):[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]([^:]+):[^:]*:[^:]*:[^:]*:[^:]*:[^:]*.*$}
set pgp(gpg,pat_keyPub) $pgp(gpg,pat_keySec)
set pgp(gpg,pat_keyPub_sub) \
                {^(sub):[^:]*:[^:]*:([^:]+):[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]([^:]+):[^:]*:[^:]*:[^:]*:[^:]*:[^:]*.*$}
set pgp(gpg,pat_uid) \
                {^(uid):[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:([^:]+).*$}
# TclCmd to match out userid and keyid
set pgp(gpg,cmd_keyMatch) { if [set match [regexp $keypattern $line {} {} algo keyid userid]] {
                                switch $algo {
                                    1  {set algo RSA}
                                    16 {set algo ELG}
                                    17 {set algo DSA}
                                    20 {set algo ELG}
                                }
                            }
                            set match }
set pgp(gpg,cmd_keyMatch_sub) { if [set match [regexp $subkeypattern $line {} {} algo keyid]] {
                                    switch $algo {
                                        1  {set algo RSA}
                                        16 {set algo ELG}
                                        17 {set algo DSA}
                                        20 {set algo ELG}
                                    }
                                }
                                set match }
set pgp(gpg,cmd_uidMatch) { regexp $uidpattern $line {} {} userid }

###############
# Exec_GetKeys
set pgp(gpg,args_exportKey) {--export --armor --textmode -o $file $keyid}

###############
# Exec_Encrypt
set pgp(gpg,args_encrypt) {[concat -eat -o $out [foreach id [Pgp_Misc_Map key {lindex $key 0} $tokeys] {lappend recips -r $id}; set recips] $in]}

###################
# Exec_EncryptSign
set pgp(gpg,args_encryptSign) {[concat -east -o $out -u $keyid [foreach id [Pgp_Misc_Map key {lindex $key 0} $tokeys] {lappend recips -r $id}; set recips] $in]}

############
# Exec_Sign
set pgp(gpg,args_signClear) {--clearsign --armor --textmode -u $keyid -o $out $in}
set pgp(gpg,args_signBinary) {--sign --armor --textmode -u $keyid -o $out $in}

####################
# Exec_SignDetached
set pgp(gpg,args_signDetached) {-abt -u $keyid -o $out $in}

#####################
# Exec_CheckPassword
set pgp(gpg,pat_checkError) "(BAD_PASSPHRASE\[^\n]+)\n"

#######################
# Exec_DetDecryptKeyid
set pgp(gpg,args_getDecryptKeyid) {--dry-run $in}
set pgp(gpg,pat_getDecryptKeyid) "NEED_PASSPHRASE ........(........)"
set pgp(gpg,pat_getDecryptSym) "NEED_PASSPHRASE_SYM"

###############
# Exec_Decrypt
set pgp(gpg,args_decrypt) {-o $out $in}

##################### >>>>>>>>>>>> DELETE
# Exec_DecryptExpect
#set pgp(gpg,expectpat,passprompt) "NEED_PASSPHRASE (\[^ \n]*)"
#set pgp(gpg,expectpat,conventional) {NEED_PASSPHRASE_SYM}
#set pgp(gpg,expectpat,publickey) "Do-Not-Match"
#set pgp(gpg,expectpat,secretmissing) "NO_SECKEY"
#set pgp(gpg,expectpat,nopgpfile) {BADARMOR|NODATA}
#set pgp(gpg,cmd_DecryptExpect) {gpg --no-greeting --status-fd 2 -o $outfile $infile}

##############
# Exec_Verify
set pgp(gpg,args_verifyOnly) {--verify $in}
set pgp(gpg,args_verifyOut) {-o $out $in}

######################
# Exec_VerifyDetached
set pgp(gpg,args_verifyDetached) {--verify $sig $text}

###################
# Exec_ExtractKeys
set pgp(gpg,args_importKey) {--import $file}

#########################
# ShowMessage keypattern
set pgp(gpg,pat_validKeys) "\n?(ssb|pub|sec|sub|uid)\[^\n]*"

##################
# InterpretOutput
# command that matches out keyid in pgp output
set pgp(gpg,cmd_Keyid) {
    if {[regexp {GOODSIG ([^ ]*)} $in {} pgpresult(keyid)]} {
    } elseif {[regexp {BADSIG ([^ ]*)} $in {} pgpresult(keyid)]} {
    } else {regexp {ERRSIG ([^ ]*)} $in {} pgpresult(keyid)}

    # Keyservers like only the last four octets of the keyid.
    if {[info exists pgpresult(keyid)]} {
	set keyidLength [string length $pgpresult(keyid)]
	set pgpresult(keyid) [string range $pgpresult(keyid) [expr $keyidLength-8] $keyidLength]
    }
}
# command that tailors output to be nice looking
set pgp(gpg,cmd_Beauty) {
    set pgpresult(msg) $in
    regsub -all "\\\[GNUPG:\\\]\[^\n\]*\n*" $pgpresult(msg) {} pgpresult(msg)
    regsub -all {gpg: } $pgpresult(msg) {} pgpresult(msg)
    set pgpresult(msg) [string trim $pgpresult(msg)]
}
# patterns for interpreting output
set pgp(gpg,pat_SecretMissing) {ENC_TO.*DECRYPTION_FAILED}
set pgp(gpg,pat_PublicMissing) {ERRSIG}
set pgp(gpg,pat_GoodSignature) {GOODSIG}
set pgp(gpg,pat_Untrusted) {(TRUST_UNDEFINED|TRUST_NEVER)}
set pgp(gpg,pat_BadSignature) {BADSIG}
set pgp(gpg,pat_UnknownError) {ERROR}
# command that matches out the Originator
set pgp(gpg,cmd_User) {
    regexp {(GOODSIG|BADSIG) [^ ]* ([^\n]*)} $in {} {} user
}

##################
# WWW_QueryHKPKey
set pgp(gpg,args_HKPimport) {--keyserver $server --recv-keys 0x$id}

###
}
