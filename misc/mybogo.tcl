proc Bogo_Init {} {
    global bogo
    Preferences_Add "Bayesian Spam Filter" \
"Parameters for Bayesian spam filters that have to be told if they marked messages incorrectly. Your usage of this feature will depend on how you call it from procmail. See your program's man page for details." {
    {bogo(progname) bogoProgName {CHOICE bogofilter spamoracle other} {Spam Program}
"Which spam program you use. If it is not in your $PATH, 
select other and give the full path name."}
    {bogo(mismarked) bogoMismarked ON {Is spam mismarked?}
"When you run the filter from procmail, does it add the tokens?
If it does, then spam that makes it through is mismarked, and you
want this flag on. This only matters for bogofilter: On means 
it uses -Sn and -Ns; for off it uses -s and -n."}
    {bogo(otherspam) bogoOtherSpam {} {Other--Spam}
"How the program is invoked, flags included, for spam."}
    {bogo(otherham) bogoOtherHam {} {Other--Non-Spam}
"How the other program is invoked, flags included, for non-spam."}
    {bogo(spammessage) bogoSpamMessage {CHOICE nothing rmm refile} {Spam Procedure}
"What to do with a spam message."}
    {bogo(spamfolder) bogoSpamRefile bogus {Spam Folder}
"If you selected 'refile' for spam messages, 
this is the destination folder."}
    {bogo(hammessage) bogoHamMessage {CHOICE nothing refile} {Ham Procedure}
"What to do with a ham message."}
    {bogo(hamfolder) bogoHamRefile inbox {Ham Folder}
"If you selected 'refile' for ham messages,
this is the destination folder."}
    }
    case $bogo(progname) {
	"bogofilter" {
	    if {$bogo(mismarked)} {
		set bogo(spamprog) {bogofilter -Ns}
		set bogo(hamprog) {bogofilter -Sn}
	    } else {
		set bogo(spamprog) {bogofilter -s}
		set bogo(hamprog) {bogofilter -n}
	    }
	}
	"spamoracle" {
	    set bogo(spamprog) {spamoracle add -good}
	    set bogo(hamprog) {spamoracle add -spam}
	}
	"other" {
	    set bogo(spamprog) $bogo(otherspam)
	    set bogo(hamprog) $bogo(otherham)
	}
    }		
}

proc MyBogoFilter {{spam spam}} {
    global exmh msg bogo
    Exmh_Debug Bogo $spam
    if {$spam == "spam"} {
        Exmh_Debug Bogo spamprog="$bogo(spamprog)", message="$msg(path)", action="$bogo(spammessage)"
	if [catch "exec $bogo(spamprog) <$msg(path)" in] {
	    Exmh_Status $in
	    return
	}
	if {$bogo(spammessage) == "rmm"} {
	    Msg_Remove Ftoc_RemoveMark show
	}
	if {$bogo(spammessage) == "refile"} {
            set oldtarget $exmh(target)
	    set exmh(target) $bogo(spamfolder)
            Exmh_Debug Bogo refile spam to $exmh(target)
	    Msg_Move Ftoc_MoveMark 1 noshow
            set exmh(target) $oldtarget
	}
	return
    } elseif {$spam == "ham"} {
        Exmh_Debug Bogo hamprog="$bogo(hamprog)", message="$msg(path)", action="$bogo(hammessage)"
	if [catch "exec $bogo(hamprog) <$msg(path)" in] {
	    Exmh_Status $in
	    return
	}
	if {$bogo(hammessage) == "refile"} {
            set oldtarget $exmh(target)
	    set exmh(target) $bogo(hamfolder)
            Exmh_Debug Bogo refile ham to $exmh(target)
	    Msg_Move Ftoc_MoveMark 1 noshow
            set exmh(target) $oldtarget
	}
	return
    } else {
	Exmh_Status "Spam button config error."
	return
    }
}
