proc Bogo_Init {} {
    global bogo
    Preferences_Add "Bayesian Spam Filter" \
"Parameters for Bayesian spam filters that have to be told if they marked messages incorrectly. Your usage of this feature will depend on how you call it from procmail. See your program's man page for details." {
    {bogo(inUse) bogoinUse OFF {Use a Bayesian spam filter}
"Enables support for the 'learn' mode for training various
popular Bayesian spam filters"}
    {bogo(progname) bogoProgName {CHOICE bogofilter spamoracle spamassassin other} {Spam Program}
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
	"spamassassin" {
	    set bogo(spamprog) {sa-learn --spam}
	    set bogo(hamprog) {sa-learn --ham}
	}
	"other" {
	    set bogo(spamprog) $bogo(otherspam)
	    set bogo(hamprog) $bogo(otherham)
	}
    }		
}

proc Bogo_Filter {{spam spam}} {
    global exmh msg bogo mhProfile
    Exmh_Debug Bogo $spam
    if {!$bogo(inUse)} {
        Exmh_Status "Bayesian filter not enabled in Preferences"
	return
    }
    if {$spam == "spam"} {
        set msgs [Ftoc_CurMsgs]
        Exmh_Status "Marking [llength $msgs] msg[expr {[llength $msgs] > 1 ? "s" : ""}] as SPAM"
        Exmh_Debug Bogo spamprog="$bogo(spamprog)", message="$msgs", action="$bogo(spammessage)"
	Ftoc_MsgIterate msgid {
	    if [catch "exec $bogo(spamprog) <$mhProfile(path)/$exmh(folder)/$msgid" in] {
	        Exmh_Status $in
	        return
	    }
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
        set msgs [Ftoc_CurMsgs]
        Exmh_Status "Marking [llength $msgs] msg[expr {[llength $msgs] > 1 ? "s" : ""}] as HAM"
        Exmh_Debug Bogo hamprog="$bogo(hamprog)", message="$msgs", action="$bogo(hammessage)"
	Ftoc_MsgIterate msgid {
	    if [catch "exec $bogo(hamprog) <$mhProfile(path)/$exmh(folder)/$msgid" in] {
	        Exmh_Status $in
	        return
	    }
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
proc Bogo_FilterFolder {{spam spam}} {
  global exmh bogo
  global mhProfile
  set folder $exmh(folder)

  if {!$bogo(inUse)} {
    Exmh_Status "Bayesian filter not enabled in Preferences"
    return
  }
  Exmh_Status "Learning $exmh(folder) as $spam"
  if {$bogo(progname) != "spamassassin"} {
    Exmh_Status "Only sa-learn is currently supported for learning a folder"
    return
  }
  set pipe [open "|sa-learn --$spam $mhProfile(path)/$exmh(folder)"]
  fileevent $pipe readable [list BogoFilterReader $pipe $exmh(folder) $spam]
}
proc BogoFilterReader {pipe folder spam} {
  if {[eof $pipe]} {
    Exmh_Status "Learned $folder as $spam"
    if {[catch {close $pipe} err]} {
      Exmh_Debug "sa-learn $folder: $err"
    }
  } else {
    gets $pipe line
    Exmh_Debug "BogoFilterReader: $line"
  }
}
