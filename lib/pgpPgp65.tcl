# pgpPgp65.tcl

# $Log$
# Revision 1.1  2000/06/09 03:45:23  valdis
# Adding PGP 6.5 support - new file
#
# Mostly cloned from pgpPgp2.tcl - V. Kletnieks

#######################################################################
# PGP6 CONFIG

proc Pgp_pgp6_Init {} {
global pgp exmh
# Yes, we need network keyfetching
Pgp_WWW_Init
###

set pgp(pref,keyquerymethod) { keyquerymethod KeyQueryMethod {CHOICE WWW email other}
{Method for querying <label> keys}
"PGP public keys can be queried using email servers
(offline) or using WWW servers (interactive).
A user-supplied proc (other) can also be given to fetch the key." }


# Needed for Preferences
set pgp(pgp6,description) "PGP 6.5 is the Pretty Good Privacy package from PGP Inc."
set pgp(pgp6,prefs) [list  rfc822 \
                         choosekey useexpectk cacheids minmatch showinline shortmsgs \
                         autoextract keyserver keyquerymethod keyserverUrl keyothermethod ]

# this is called when preferences are set
proc Pgp_pgp6_Preferences {} {
    global exmh pgp
    set label $pgp(pgp6,fullName)
    Preferences_Add "$label interface" {} [list \
	[list pgp(pgp6,comment) pgp6Comment \
	"Exmh $exmh(version)" "PGP 6.5 Comment" \
	"Specify the comment PGP 6.5 should put in the comment field
	of encrypted or signed text."]
	]
}

# digest algo
set pgp(pgp6,digestalgo) sha1


#######################################################################
# Flags, Commands, Patterns, Settings
#

# Should config file be parsed
set pgp(pgp6,parse_config) 1

#######
# Exec
#############
# Exec_Batch
# Batchmode flags
set pgp(pgp6,flags_batch) {+armorlines=0 "+comment=$pgp(pgp6,comment)" +batchmode=on +verbose=0 +pager=cat +compatible=on}
#
proc Pgp_pgp6_PassFdSet {} {
            global env
            set env(PGPPASSFD) 0
}
#
proc Pgp_pgp6_PassFdUnset {} {
    global env
    catch { unset env(PGPPASSFD) }
}

###################
# Exec_Interactive
# Interactive flags
set pgp(pgp6,flags_interactive) {+armorlines=0}
# Cleanup output
set pgp(pgp6,cmd_cleanOutput) { regsub -all "\[\x0d\x07]" $output {} output
                                   regsub "^.*\nEnter pass phrase:" $output {} output
                                   regsub "\nPlaintext filename:.*" $output {} output
                                   regsub "^.*Just a moment\\.\\.+" $output {} output
                                   regsub "^.*Public key is required \[^\n]*\n" $output {} output
                                   set output [string trim $output] }

###############
# Exec_KeyList
# List pubkeys args prototype
set pgp(pgp6,args_listPub) {-kv \"$pattern\" $pgp(pgp6,pubring)}
# List seckeys args prototype
set pgp(pgp6,args_listSec) {-kv \"$pattern\" $pgp(pgp6,secring)}
# Pattern that matches out revoked and nonvalid keys
set pgp(pgp6,pat_dropKeys) \
                "\n(pub|sec) \[^\n]+\\*\\*\\* KEY REVOKED \\*\\*\\*(\n\[\t ]\[^\n]+)+"
# Where to split up the listKeys raw output to form a list
set pgp(pgp6,pat_splitKeys) \n
# Patterns that match out interesting keys
set pgp(pgp6,pat_keySec) \
                {^.*(sec) +[0-9]+/+([0-9A-F]+) +[0-9]+/ ?[0-9]+/[0-9]+ +(.*)$}
set pgp(pgp6,pat_keyPub) \
                {^.*(pub) +[0-9]+/+([0-9A-F]+) +[0-9]+/ ?[0-9]+/[0-9]+ +(.*)$}
set pgp(pgp6,pat_uid) \
                {^ +(.+)$}
# TclCmd to match out userid and keyid
set pgp(pgp6,cmd_keyMatch) { set match [regexp $keypattern $line algo {}  keyid {}]
                            set match }
set pgp(pgp6,cmd_uidMatch) { regexp $uidpattern $line {} userid }

###############
# Exec_GetKeys
set pgp(pgp6,args_exportKey) {-akx $keyid $file}

###############
# Exec_Encrypt
set pgp(pgp6,args_encrypt) {-aet $in -o $out [Pgp_Misc_Map key {lindex $key 0} $tokeys]}

###################
# Exec_EncryptSign
set pgp(pgp6,args_encryptSign) {-aset $in -o $out -u $keyid [Pgp_Misc_Map key {lindex $key 0} $tokeys]}

############
# Exec_Sign
set pgp(pgp6,args_signClear) {+clearsig=on -ast $in -u $keyid -o $out}
set pgp(pgp6,args_signBinary) {+clearsig=off -ast $in -u $keyid -o $out}

####################
# Exec_SignDetached
set pgp(pgp6,args_signDetached) {-stab $in -u $keyid -o $out}

#####################
# Exec_CheckPassword
set pgp(pgp6,pat_checkError) {(Error:[^\.]*)\.}

###############
# Exec_Decrypt
set pgp(pgp6,args_decrypt) {$in -o $out}

#####################
# Exec_DecryptExpect
set pgp(pgp6,expectpat,passprompt) {Enter pass phrase: }
set pgp(pgp6,expectpat,conventional) {You need a passphrase to decrypt this file.}
set pgp(pgp6,expectpat,publickey) "Key for user ID: \[^\n\]*\n\[^\n]*key ID (\[A-F0-9\]+)\[^\n\]*"
set pgp(pgp6,expectpat,secretmissing) {(This message can only.*).(You.*this file.)}
set pgp(pgp6,expectpat,nopgpfile) {(Error: .*is not a ciphertext.*file.)}
set pgp(pgp6,cmd_DecryptExpect) {pgp +armorlines=0 +keepbinary=off +batchmode=off +verbose=0 +pager=cat $infile -o $outfile}

##############
# Exec_Verify
set pgp(pgp6,args_verifyOnly) {$in}
set pgp(pgp6,args_verifyOut) {$in -o $out}

######################
# Exec_VerifyDetached
set pgp(pgp6,args_verifyDetached) {$sig $text}

###################
# Exec_ExtractKeys
set pgp(pgp6,args_importKey) {-ka $file}

#########################
# ShowMessage keypattern
set pgp(pgp6,pat_validKeys) "\n(Type.*\n(sig|pub|sec)\[^\n]*)"

##################
# InterpretOutput
# command that matches out keyid in pgp output
set pgp(pgp6,cmd_Keyid) {if {![regexp -nocase {KeyID: ([0-9a-f]+)} $in {} pgpresult(keyid)]} {
		regexp {0x([0-9A-F]+)} $in {} pgpresult(keyid) } }


# command that tailors output to be nice looking
set pgp(pgp6,cmd_Beauty) {set pgpresult(msg) $redin}
# patterns for interpreting output
set pgp(pgp6,pat_SecretMissing) {This.*do not have the secret key.*file.}
set pgp(pgp6,pat_PublicMissing) {signature not checked.*key does not meet validity threshold.*}
set pgp(pgp6,pat_GoodSignature) {Good signature.*}
set pgp(pgp6,pat_Untrusted) {WARNING:.*confidence}
set pgp(pgp6,pat_BadSignature) {WARNING:.*doesn't match.*}
set pgp(pgp6,pat_UnknownError) {ERROR}
# command that matches out the Originator
set pgp(pgp6,cmd_User) {regexp  {KeyID: ("[0-9a-fA-F]*")} $in {} user}
#set pgp(pgp6,cmd_User) {regexp  {user ("[^"]*")} $in {} user}

###
}
