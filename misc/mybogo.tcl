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
    if {$spam == "spam"} {
	if [catch "exec $bogo(spamprog) <$msg(path)" in] {
	    Exmh_Status $in
	    return
	}
	if {$bogo(spammessage) == "rmm"} {
	    Msg_Remove Ftoc_RemoveMark show
	}
	if {$bogo(spammessage) == "refile"} {
	    set exmh(target) $bogo(spamfolder)
	    Msg_Move Ftoc_MoveMark 1 show
	}
	return
    } elseif {$spam == "ham"} {
	if [catch "exec $bogo(hamprog) <$msg(path)" in] {
	    Exmh_Status $in
	    return
	}
	if {$bogo(hammessage) == "refile"} {
	    set exmh(target) $bogo(hamfolder)
	    Msg_Move Ftoc_MoveMark 1 noshow
	}
	return
    } else {
	Exmh_Status "Spam button config error."
	return
    }
}

