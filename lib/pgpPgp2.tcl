# pgpPgp2.tcl

# $Log$
# Revision 1.4  1999/09/27 23:18:46  kchrist
# More PGP changes. Consolidated passphrase entry to sedit field or
# pgpExec routine. Made the pgp-sedit field aware of pgp(keeppass)
# and pgp(echopass). Moved pgp(keeppass), pgp(echopass) and
# pgp(grabfocus) to PGP General Interface. Fixed a minor bug left
# over from my previous GUI changes. Made pgp-sedit field appear and
# disappear based on its enable preference setting.
#
# Revision 1.3  1999/08/13 00:39:05  bmah
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
# Revision 1.2  1998/12/06 16:27:02  markus
# Modifications for new DecryptExpect support
#
# Revision 1.1.1.1  1998/11/24 22:34:44  markus
# Initial revision
#

#######################################################################
# PGP2 CONFIG

proc Pgp_pgp_Init {} {
global pgp
# Yes, we need network keyfetching
Pgp_WWW_Init
###

set pgp(pref,keyquerymethod) { keyquerymethod KeyQueryMethod {CHOICE WWW email other}
{Method for querying <label> keys}
"PGP public keys can be queried using email servers
(offline) or using WWW servers (interactive).
A user-supplied proc (other) can also be given to fetch the key." }


# Needed for Preferences
set pgp(pgp,description) "PGP is the Pretty Good Privacy package from Zimmerman."
set pgp(pgp,prefs) [list  rfc822 \
                         choosekey useexpectk cacheids minmatch showinline shortmsgs \
                         autoextract keyserver keyquerymethod keyserverUrl keyothermethod ]

# this is called when preferences are set
proc Pgp_pgp_Preferences {} {
}

# digest algo
set pgp(pgp,digestalgo) md5


#######################################################################
# Flags, Commands, Patterns, Settings
#

# Should config file be parsed
set pgp(pgp,parse_config) 1

#######
# Exec
#############
# Exec_Batch
# Batchmode flags
set pgp(pgp,flags_batch) {+armorlines=0 +batchmode=on +verbose=0 +pager=cat}
#
proc Pgp_pgp_PassFdSet {} {
            global env
            set env(PGPPASSFD) 0
}
#
proc Pgp_pgp_PassFdUnset {} {
    global env
    catch { unset env(PGPPASSFD) }
}

###################
# Exec_Interactive
# Interactive flags
set pgp(pgp,flags_interactive) {+armorlines=0}
# Cleanup output
set pgp(pgp,cmd_cleanOutput) { regsub -all "\[\x0d\x07]" $output {} output
                                   regsub "^.*\nEnter pass phrase:" $output {} output
                                   regsub "\nPlaintext filename:.*" $output {} output
                                   regsub "^.*Just a moment\\.\\.+" $output {} output
                                   regsub "^.*Public key is required \[^\n]*\n" $output {} output
                                   set output [string trim $output] }

###############
# Exec_KeyList
# List pubkeys args prototype
set pgp(pgp,args_listPub) {-kv \"$pattern\" $pgp(pgp,pubring)}
# List seckeys args prototype
set pgp(pgp,args_listSec) {-kv \"$pattern\" $pgp(pgp,secring)}
# Pattern that matches out revoked and nonvalid keys
set pgp(pgp,pat_dropKeys) \
                "\n(pub|sec) \[^\n]+\\*\\*\\* KEY REVOKED \\*\\*\\*(\n\[\t ]\[^\n]+)+"
# Where to split up the listKeys raw output to form a list
set pgp(pgp,pat_splitKeys) \n
# Patterns that match out interesting keys
set pgp(pgp,pat_keySec) \
                {^.*(sec) +[0-9]+(/| +)([0-9A-F]+) +[0-9]+/ ?[0-9]+/[0-9]+ +(.*)$}
set pgp(pgp,pat_keyPub) \
                {^.*(pub) +[0-9]+(/| +)([0-9A-F]+) +[0-9]+/ ?[0-9]+/[0-9]+ +(.*)$}
set pgp(pgp,pat_uid) \
                {^ +(.+)$}
# TclCmd to match out userid and keyid
set pgp(pgp,cmd_keyMatch) { set match [regexp $keypattern $line {} {} {} keyid userid]
                            set algo RSA
                            set match }
set pgp(pgp,cmd_uidMatch) { regexp $uidpattern $line {} userid }

###############
# Exec_GetKeys
set pgp(pgp,args_exportKey) {-akx $keyid $file}

###############
# Exec_Encrypt
set pgp(pgp,args_encrypt) {-aet $in -o $out [Pgp_Misc_Map key {lindex $key 0} $tokeys]}

###################
# Exec_EncryptSign
set pgp(pgp,args_encryptSign) {-aset $in -o $out -u $keyid [Pgp_Misc_Map key {lindex $key 0} $tokeys]}

############
# Exec_Sign
set pgp(pgp,args_signClear) {+clearsig=on -ast $in -u $keyid -o $out}
set pgp(pgp,args_signBinary) {+clearsig=off -ast $in -u $keyid -o $out}

####################
# Exec_SignDetached
set pgp(pgp,args_signDetached) {-stab $in -u $keyid -o $out}

#####################
# Exec_CheckPassword
set pgp(pgp,pat_checkError) {(Error:[^\.]*)\.}

###############
# Exec_Decrypt
set pgp(pgp,args_decrypt) {$in -o $out}

#####################
# Exec_DecryptExpect
set pgp(pgp,expectpat,passprompt) {Enter pass phrase: }
set pgp(pgp,expectpat,conventional) {You need a passphrase to decrypt this file.}
set pgp(pgp,expectpat,publickey) "Key for user ID: \[^\n\]*\n\[^\n]*key ID (\[A-F0-9\]+)\[^\n\]*"
set pgp(pgp,expectpat,secretmissing) {(This message can only.*).(You.*this file.)}
set pgp(pgp,expectpat,nopgpfile) {(Error: .*is not a ciphertext.*file.)}
set pgp(pgp,cmd_DecryptExpect) {pgp +armorlines=0 +keepbinary=off +batchmode=off +verbose=0 +pager=cat $infile -o $outfile}

##############
# Exec_Verify
set pgp(pgp,args_verifyOnly) {$in}
set pgp(pgp,args_verifyOut) {$in -o $out}

######################
# Exec_VerifyDetached
set pgp(pgp,args_verifyDetached) {$sig $text}

###################
# Exec_ExtractKeys
set pgp(pgp,args_importKey) {-ka $file}

#########################
# ShowMessage keypattern
set pgp(pgp,pat_validKeys) "\n(Type.*\n(sig|pub|sec)\[^\n]*)"

##################
# InterpretOutput
# command that matches out keyid in pgp output
set pgp(pgp,cmd_Keyid) {regexp -nocase {key id ([0-9a-f]+)} $in {} pgpresult(keyid)}
# command that tailors output to be nice looking
set pgp(pgp,cmd_Beauty) {set pgpresult(msg) $redin}
# patterns for interpreting output
set pgp(pgp,pat_SecretMissing) {This.*do not have the secret key.*file.}
set pgp(pgp,pat_PublicMissing) {Can't.*can't check signature integrity.*}
set pgp(pgp,pat_GoodSignature) {Good signature.*}
set pgp(pgp,pat_Untrusted) {WARNING:.*confidence}
set pgp(pgp,pat_BadSignature) {WARNING:.*doesn't match.*}
set pgp(pgp,pat_UnknownError) {ERROR}

################
# ShortenOutput
# command that matches out the Originator
set pgp(pgp,cmd_User) {regexp {user ("[^"]*")} $pgpresult {} user}

###
}
