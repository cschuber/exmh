# pgpShared.tcl

# $Log$
# Revision 1.3  1999/08/03 18:32:02  bmah
# Cosmetic fixes:  PGP 2 is now specified explicitly in all prompts
# (instead of old "PGP").  The term "passphrase" is now used
# consistently.
#
# Revision 1.2  1999/08/03 04:05:56  bmah
# Merge support for PGP2/PGP5/GPG from multipgp branch.
#
# Revision 1.1.4.1  1999/06/14 20:05:17  gruber
# updated multipgp interface
#
# Revision 1.1  1999/06/14 15:14:55  markus
# added files
#
# Revision 1.2  1998/12/06 16:19:32  markus
# Updated for DecryptExpect
# Put pref(useexpectk) here
#
# Revision 1.1.1.1  1998/11/24 22:34:46  markus
# Initial revision
#

proc Pgp_Shared_Init {} {
global pgp
###

############
# Menutexts
set pgp(menutext,signclear) "Check the signature"
set pgp(menutext,signbinary) "Verify and show content"
set pgp(menutext,encrypt) "Decrypt"
set pgp(menutext,encryptsign) "Decrypt and verify"
set pgp(menutext,keys-only) "Extract keys"

#########
# Decode
set pgp(decode,none) 0
set pgp(decode,all) 1
set pgp(decode,keys) {$action == "keys-only"}
set pgp(decode,signed) {![regexp {encrypt} $action]}

#########################
# Set pgp message colors
if {[winfo depth .] > 4} {
    Preferences_Resource pgp(msgcolor,Bad) m_pgpBad \
             "-foreground red"
    Preferences_Resource pgp(msgcolor,GoodUntrustedSig) \
             m_pgpGoodUntrustedSig "-foreground blue"
    Preferences_Resource pgp(msgcolor,GoodTrustedSig) \
             m_pgpGoodTrustedSig "-foreground darkgreen"
    Preferences_Resource pgp(msgcolor,OtherMsg) \
             m_pgpOtherMsg {}
} else {
    Preferences_Resource pgp(msgcolor,Bad) m_pgpBad {}
    Preferences_Resource pgp(msgcolor,GoodUntrustedSig) \
             m_pgpGoodUntrustedSig {}
    Preferences_Resource pgp(msgcolor,GoodTrustedSig) \
             m_pgpGoodTrustedSig {}
    Preferences_Resource pgp(msgcolor,OtherMsg) m_pgpOtherMsg {}
}

#######################
# Standard Preferences
#
set pgp(pref,keeppass) { keeppass KeepPass ON {Keep <label> passphrase}
"Exmh tries to remember your <label> passphrase between pgp
invocations. But the passphrase is then kept in a global
variable, which is not safe, because of \"send\"'s power.
If you turn this feature off, exmh will use xterm to run
pgp so that it doesn't have to deal with the passphrase at all." }
#
set pgp(pref,echopass) { echopass EchoPass  ON {Echo '*' when typing pass}
"If you have pgpKeepPass on, Exmh will prompt for your <label> passphrase.
A * will be echoed for every character typed depending on this option." }
#
set pgp(pref,grabfocus) { grabfocus GrabFocus  ON {Passphrase dialog grabs input focus}
"When exmh prompts for the $label passphrase it will globally grab input 
focus if this is on.  Some users like it because they don't need to
select the popup dialog or because it lessens the risk they will type
their passphrase in the wrong window.  It annoys or does not work for
other people." }
#
set pgp(pref,passtimeout) { passtimeout PassTimeout  60
{Minutes to cache <label> passphrase}
"Exmh will clear its memory of the <label> passphrase after
this time period, in minutes, has elapesed.  If you use
different keys, they have their own timeout period." }
#
set pgp(pref,rfc822) { rfc822 Rfc822 OFF {Encrypt headers}
"Used to encrypt the whole message, instead of only encrypting
the body, so that the subject line (for instance) is also
safely transmitted." }
#
set pgp(pref,choosekey) { choosekey ChooseKey ON {Always choose the sign-key}
"When signing a message, sedit can either use the default key or ask
the user to choose which key he wants to use. Of course, if you only
have 1 private key this setting doesn't interest you much." }
#
set pgp(pref,useexpectk) { useexpectk UseExpectk OFF {Use expectk if available}
"Expectk is a utility that can communicate interactively with both
PGP and exmh.  With this option enabled, messages will take longer
to decrypt, but exmh will use the correct pass phrase.  Do not turn
this on unless you have \"Separate background process\" in
Preferences->Background Processing on.  This is recommended if you
have more than one secret key." }
#
set pgp(pref,runtwice) { runtwice RunTwice OFF {Run <label> twice for decryption}
"With this option enabled, exmh will run <label> twice to first
get out the keyid of the decryption key and then use the
right passphrase for decryption.
This is recommended if you have more than one secret key.
This is similar to the option \"Use expectk if available\", but faster." }
#
set pgp(pref,cacheids) { cacheids CacheIds {CHOICE persistent temporary none}
{Cache map from email to public-key}
"The way exmh figures out the public-key to use for an email address is
often slow. This option allows you to cache the result of the matching
so that it doesn't have to be done over and over. Furthermore the cache
can be saved in a file .matchcache.<label> in your pgp directory so as
to make it persistent accross exmh sessions." }
#
set pgp(pref,minmatch) { minmatch MinMatch 75 {Minimum match correlation (in percents)}
"When trying to find the key corresponding to an email address,
exmh tries to be 'smart' and does an approximate matching. If the 
match's quality is better than the specified percentage, exmh will
assume it's the right key. Else it will query the user. Hence, a
value greater than 100 will make exmh always query the user." }
#
set pgp(pref,showinline) { showinline ShowInline {CHOICE none keys signed all}
{Show pgp messages inline}
"controls which pgp parts get automatically decoded with <label>. Since
decoding generally takes time, and since clear signed messages can
be viewed without <label>, it makes sense to limit the decoding to rare
cases like key parts:
 - keys: only auto-decode key parts
 - signed: auto-decode key and signed parts" }
#
set pgp(pref,shortmsgs) { shortmsgs ShortMessages OFF "Short <label> reports"
{If this is selected Exmh tries to report PGP results in one line, 
otherwise more of the text from PGP itself is used.  For example:

Good signature from user "John Smith <jsmith@well.com>".
Signature made 1996/12/30 16:34 GMT

WARNING:  Because this public key is not certified with a trusted
signature, it is not known with high confidence that this public key
actually belongs to: "John Smith <jsmith@well.com>".

versus

Good untrusted signature from "John Smith <jsmith@well.com>" } }
#
set pgp(pref,autoextract) { autoextract AutoExtract ON {Extract keys automatically}
"When you receive a keys-only part, you can have its content
displayed and you can extract its content into your public
key ring. The extraction can be safely done automatically,
but you might prefer doing it manually, with a menu entry
on the keys-only part." }

########################
# Public Key Algorithms
set pgp(pubkeyalgo,1)  rsa
set pgp(pubkeyalgo,16) elgamal/s
set pgp(pubkeyalgo,17) dsa
set pgp(pubkeyalgo,20) elgamal/s+e

##############
# Preferences
proc Pgp_Preferences { v } {
    global pgp

    # The first insertion should contain the description of the package
    set prefs [set pgp($v,prefs)]
    set first [lindex $prefs 0]
    set label [set pgp($v,fullName)]
    Preferences_Add "$label interface" [set pgp($v,description)] \
       [list \
        [list pgp($v,[lindex [set pgp(pref,$first)] 0]) \
         ${v}[lindex [set pgp(pref,$first)] 1] \
         [lindex [set pgp(pref,$first)] 2] \
         [regsub -all <label> [lindex [set pgp(pref,$first)] 3] $label t; set t] \
         [regsub -all <label> [lindex [set pgp(pref,$first)] 4] $label t; set t] \
        ] \
       ]
    set prefs [lrange $prefs 1 end]
    # Now insert rest
    foreach pref $prefs {
      Preferences_Add "$label interface" {} \
       [list \
        [list pgp($v,[lindex [set pgp(pref,$pref)] 0]) \
        ${v}[lindex [set pgp(pref,$pref)] 1] \
        [lindex [set pgp(pref,$pref)] 2] \
        [regsub -all <label> [lindex [set pgp(pref,$pref)] 3] $label t; set t] \
        [regsub -all <label> [lindex [set pgp(pref,$pref)] 4] $label t; set t] \
       ] \
      ]
    }

    # Call the modules Preferences proc, which adds module specific Prefs
    Pgp_${v}_Preferences
}

###
}
