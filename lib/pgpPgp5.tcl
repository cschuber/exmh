# pgpPgp5.tcl

# $Log$
# Revision 1.8  2005/01/01 20:16:20  welch
# Based on patches from Alexander Zangerl
# lib/pgpGpg.tcl:
# lib/pgpPgp5.tcl:
#   fix of an old pgp problem where recipients were duplicated when
#   pgp is run in interactive mode
# lib/extrasInit.tcl: a small documentation improvement for the
#   pgp(getextcmd) functionality.
#   faces(xfaceProg) gains a default (uncompface -X)
# lib/pgpExec.tcl: fix for http://bugs.debian.org/164210: multiple gpg
#   subkeys and passphrases.  exmh would not ask for the right passphrase.
# lib/addr.tcl: ldap options gain defaults that are compatible with
#   debian's openldap config
# lib/mh.tcl: add Msg-Protect and Folder-Protect to the default .mh_profile
#   that is generated when setting up new users.
#
# (These changes are inspired by a patch from Alexander, but not the same)
# lib/inc.tcl: use $install(dir,bin) to specify an absolute path to
#   the inc.expect script
# lib/seditExtras.tcl: use $install(dir,bin) to specify an absolute path to
#   the exmh-async script
# lib/mime.tcl: use $install(dir,bin) to specify an absolute path to
#   the ftp.expect script.
#   Also changed MimeMakeBoundary to use [clock seconds] instead of
#   re-writing the output of [exec date].
#
# Revision 1.5  2001/02/04 15:45:40  iko
# gpg fixes + icon position
#
# Revision 1.4  2001/02/01 23:01:32  iko
# Misc. fixes
#
# Revision 1.1.1.3  2001/02/01 15:02:58  iko
# upstream 2.3.1
#
# Revision 1.7  2001/01/04 02:24:46  bmah
# Add +force to PGP5 flags.  This fixes
# a bug where PGP5 couldn't verify clearsigned messages under some
# circumstances.  In my testing I was only able to make this happen
# with clearsigned messages and multipart/mime, which produces some
# rather strange output anyways.  But this doesn't seem to hurt
# anything.
#
# Submitted-by:	Dave Tweten <tweten@nas.nasa.gov>, via the FreeBSD
# 		Project
#
# Revision 1.6  2000/04/18 18:38:33  valdis
# Fix quote character to use ascii rather than iso8859-ish one
#
# Revision 1.5  1999/09/30 03:51:07  kchrist
# pgp($v,cmd_Beauty) was getting in the way of pgp($v,cmd_User) for
# v=gpg so I had to rearrange things a bit.
#
# Revision 1.4  1999/09/27 23:18:46  kchrist
# More PGP changes. Consolidated passphrase entry to sedit field or
# pgpExec routine. Made the pgp-sedit field aware of pgp(keeppass)
# and pgp(echopass). Moved pgp(keeppass), pgp(echopass) and
# pgp(grabfocus) to PGP General Interface. Fixed a minor bug left
# over from my previous GUI changes. Made pgp-sedit field appear and
# disappear based on its enable preference setting.
#
# Revision 1.3  1999/08/13 00:39:06  bmah
# Fix a number of key/passphrase management problems:  pgpsedit now
# manages PGP versions, keys, and passphrases on a per-window
# basis.  Decryption now works when no passphrases are cached.
# One timeout parameter controls passphrases for all PGP
# versions.  seditpgp UI slightly modified.
#
# Revision 1.2  1999/08/03 04:05:56  bmah
# Merge support for PGP2/PGP5/GPG from multipgp branch.
#
# Revision 1.1.4.1  1999/06/14 20:05:16  gruber
# updated multipgp interface
#
# Revision 1.1  1999/06/14 15:14:55  markus
# added files
#
# Revision 1.4  1998/12/08 15:04:46  markus
# modified cmd_cleanOutput
#
# Revision 1.3  1998/12/06 16:27:22  markus
# Added DecryptExpect and subkey support
#
# Revision 1.2  1998/12/02 20:06:33  markus
# Few fixes in cmd_cleanOutput
#
# Revision 1.1.1.1  1998/11/24 22:34:46  markus
# Initial revision
#

#######################################################################
# PGP5 CONFIG

proc Pgp_pgp5_Init {} {
global pgp
###

# Yes, we need network keyfetching
Pgp_WWW_Init

set pgp(pref,HKPkeyserverUrl) { HKPkeyserverUrl HKPKeyServerUrl {keys.pgp.com}
{Horowitz Key Protocol Server}
"The hkp (Horowitz Key Protokol) is a subset of the http.
It's used to transfer keys to and from a keyserver.
Give here a hkp server name." }


# Needed for Preferences
set pgp(pgp5,description) "PGP5 is the new Pretty Good Privacy Package from Zimmermann."
set pgp(pgp5,prefs) [list rfc822 \
                          choosekey useexpectk cacheids minmatch showinline \
                          shortmsgs autoextract \
                          keyserver keyquerymethod HKPkeyserverUrl keyserverUrl keyothermethod ]

# this is called when preferences are set
proc Pgp_pgp5_Preferences {} {
}

# digest algo
set pgp(pgp5,digestalgo) sha1


#######################################################################
# Flags, Commands, Patterns, Settings
#
# Should config file be parsed
set pgp(pgp5,parse_config) 1

#######
# Exec
#############
# Exec_Batch
# Batchmode flags
set pgp(pgp5,flags_batch) {+armorlines=0 +batchmode=on +force +verbose=0}
#
proc Pgp_pgp5_PassFdSet {} {
    global env
    set env(PGPPASSFD) 0
}
#
proc Pgp_pgp5_PassFdUnset {} {
    global env
    catch { unset env(PGPPASSFD) }
}

###################
# Exec_Interactive
# Interactive flags
set pgp(pgp5,flags_interactive) {+armorlines=0}
# Cleanup output
set pgp(pgp5,cmd_cleanOutput) { regsub -all "\[\x0d\x07]" $output {} output
                                regsub "^.*\nEnter pass phrase:" $output {} output
                                regsub "^.*\nPass phrase is good." $output {} output
                                regsub "^.*Opening file\[^\n\]*\n" $output {} output
                                regsub -all "\nOpening file\[^\n\]*" $output {} output
                                set output [string trim $output] }

###############
# Exec_KeyList
# List pubkeys args prototype
set pgp(pgp5,args_listPub) {-l \"$pattern\"}
# List seckeys args prototype
set pgp(pgp5,args_listSec) $pgp(pgp5,args_listPub)
# Pattern that matches out revoked and nonvalid keys
set pgp(pgp5,pat_dropKeys) \
         "((\n(pub|sec)\[\\?!\\*]? \[^\n]+\\*REVOKED\\*\[^\n]+(\n(sub) \[^\n]+)?(\n(uid) \[^\n]+)+)"
append pgp(pgp5,pat_dropKeys) \
         "(\n(pub@|pub%|sec@|ret) \[^\n]+(\n(sub) \[^n]+)?(\n(uid) \[^n]+)+))"
# Where to split up the listKeys raw output to form a list
set pgp(pgp5,pat_splitKeys) "\n"
# Patterns that match out interesting keys
set pgp(pgp5,pat_keySec) {^.*(sec)[\?!\*\+]? +[0-9]+ +0x([0-9A-F]+) +[0-9]+-[0-9]+-[0-9]+ +[^ ]+ +([^ ]+).*$}
set pgp(pgp5,pat_keySec_sub) {^.*(sub)[\?!\*\+]? +[0-9]+ +0x([0-9A-F]+) +[0-9]+-[0-9]+-[0-9]+ +[^ ]+ +([^ ]+).*$}
set pgp(pgp5,pat_keyPub) {^.*(sec|pub)[\?!\*\+]? +[0-9]+ +0x([0-9A-F]+) +[0-9]+-[0-9]+-[0-9]+ +[^ ]+ +([^ ]+).*$}
set pgp(pgp5,pat_keyPub_sub) $pgp(pgp5,pat_keySec_sub)
set pgp(pgp5,pat_uid) {^.*uid +(.*)$}
# TclCmd to match out userid and keyid
set pgp(pgp5,cmd_keyMatch) { regexp $keypattern $line {} {} keyid algo }
set pgp(pgp5,cmd_keyMatch_sub) { regexp $subkeypattern $line {} {} keyid algo }
set pgp(pgp5,cmd_uidMatch) { regexp $uidpattern $line {} userid }

###############
# Exec_GetKeys
set pgp(pgp5,args_exportKey) {-x $keyid -o $file}

###############
# Exec_Encrypt
set pgp(pgp5,args_encrypt) {[concat -at $in -o $out [set recips {}; foreach id [Pgp_Misc_Map key {lindex $key 0} $tokeys] {lappend recips -r $id}; set recips]]}

###################
# Exec_EncryptSign
set pgp(pgp5,args_encryptSign) {[concat -ast $in -o $out -u $keyid [set recips {}; foreach id [Pgp_Misc_Map key {lindex $key 0} $tokeys] {lappend recips -r $id}; set recips]]}

############
# Exec_Sign
set pgp(pgp5,args_signClear) {+clearsig=on -at $in -u $keyid -o $out}
set pgp(pgp5,args_signBinary) {+clearsig=off -at $in -u $keyid -o $out}

####################
# Exec_SignDetached
set pgp(pgp5,args_signDetached) {-abt $in -u $keyid -o $out}

#####################
# Exec_CheckPassword
set pgp(pgp5,pat_checkError) "(Cannot\[^\n]*)\n"

###############
# Exec_Decrypt
set pgp(pgp5,args_decrypt) {$in -o $out}

#####################
# Exec_DecryptExpect
set pgp(pgp5,expectpat,passprompt) {Enter pass phrase: }
set pgp(pgp5,expectpat,conventional) {Message is conventionally encrypted.} ;# matches nothing
set pgp(pgp5,expectpat,publickey) "Need a pass phrase\[^\n\]*\n\[^\n\]*Key ID (\[A-F0-9\]+), \[^\n\]*"
set pgp(pgp5,expectpat,secretmissing) {(Cannot decrypt.*).(It can only be decrypted by:.*)}
set pgp(pgp5,expectpat,nopgpfile) {(This is no ciphertext file.)} ;# matches nothing
set pgp(pgp5,cmd_DecryptExpect) {pgpv +armorlines=0 +batchmode=off +verbose=0 $infile -o $outfile}

##############
# Exec_Verify
set pgp(pgp5,args_verifyOnly) {$in}
set pgp(pgp5,args_verifyOut) {$in -o $out}

######################
# Exec_VerifyDetached
set pgp(pgp5,args_verifyDetached) {$sig}

###################
# Exec_ExtractKeys
set pgp(pgp5,args_importKey) {-a $file}

#########################
# ShowMessage keypattern
set pgp(pgp5,pat_validKeys) "\n(Type.*\n(sig|pub|sec|sub|SIG|ret|uid)\[^\n]*)"

##################
# InterpretOutput
# command that matches out keyid in pgp output
set pgp(pgp5,cmd_Keyid) {if {![regexp -nocase {key id ([0-9a-f]+)} $in {} pgpresult(keyid)]} {
                                regexp {0x([0-9A-F]+)} $in {} pgpresult(keyid) } }
# command that tailors output to be nice looking
set pgp(pgp5,cmd_Beauty) {
     set pgpresult(msg) $redin
     regsub -all "(\nOpening file \"\[^\"\]*\" type text\\.)|(Opening file \"\[^\"\]*\" type text\\.\n)" $pgpresult(msg) {} pgpresult(msg)
     regsub -all "Pass phrase is good\\.\n?" $pgpresult(msg) {} pgpresult(msg)
     regsub -all "Message is encrypted\\.\n?" $pgpresult(msg) {} pgpresult(msg)
     set pgpresult(msg) [string trim $pgpresult(msg)]
}
# patterns for interpreting output
set pgp(pgp5,pat_SecretMissing) {Cannot decrypt.*can only be decrypted by.*}
set pgp(pgp5,pat_PublicMissing) {Signature by unknown keyid.*}
set pgp(pgp5,pat_GoodSignature) {Good signature.*}
set pgp(pgp5,pat_Untrusted) {WARNING:.*is not trusted.*}
set pgp(pgp5,pat_BadSignature) {BAD signature.*}
set pgp(pgp5,pat_UnknownError) {ERROR}
# command that matches out the Originator
set pgp(pgp5,cmd_User) {regexp {by key[^"]*("[^"]*")} $in {} user}

##################
# WWW_QueryHKPKey
set pgp(pgp5,args_HKPimport) {-a hkp://${server}/0x$id}

###
}
