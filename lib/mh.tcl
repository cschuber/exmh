#
# mh.tcl --
#	MH support. This is divided into two parts:
#		Thin layers on the MH commands
#		Parsing and setting up the mhProfile
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Mh_Init {} {
    global exmh nmh
    MhParseProfile

    catch {MhExec repl -help} output
    set nmh [string match *group* $output]

    # set $exmh(mh_vers) to a pretty-printable string...
    set exmh(mh_vers) "unknown"
    if { $nmh } {
	# 'repl -- version [compiled etc etc]' - catch version
	catch {MhExec repl -version} d
	regexp {.*-- *([^ ]*)[ ]} $d {} exmh(mh_vers) 
    } else {
	# UCI MH - 'version: .*'
	# weirdness - 6.8 puts 'version (build on ...)', 6.6 (blech) doesnt.
	catch {MhExec repl -help} d
	set d1 [ split $d "\n"]
	foreach line $d1 {
	    regexp {^version:[ ]*([^(]*)} $line d2
	    if [info exists d2] { set exmh(mh_vers) [string trim $d2] }
	}
    }
}

proc Mh_Preferences {} {
    global mhProfile
    Preferences_Add "MH Tweaks" \
"Note that most of MH is parameterized by your [file tail $mhProfile(profile)] file.
These options just affect a few things particular to exmh." [list \
	{mhProfile(scan-proc) scanProc {scan -noheader} {Scan program}
"If you have a custom scan program, name it here."} \
	{mhProfile(sendType) sendType {CHOICE wait async xterm} {How to send messages}
"There are three ways exmh can send a message for you:
wait: exmh waits until the message is successfully posted.
It displayes any error messages and lets you retry after a failure.
async: exmh does not wait for the message to be posted.
If there are errors, they are mailed back to you.
xterm: exmh runs send in an xterm.  Exmh does not wait for
your interaction with send to complete."} \
	{mhProfile(xtermcmd) xtermCmd {xterm -g 80x5} {xterm command parameters}
"When \"Send in xterm window\" is selected,
this option controls extra parameters provided
to the xterm program to control how it is started."} \
	{mhProfile(forwtweak) forwTweak ON {Tweak subject lines of forwarded messages}
"If this option is enabled, the subject line of forwarded messages
will be tweaked, in a similar manner to the prefixing of \"Re:\" to
the subject of replies.  This is only performed if the draft message
does not already contain a subject line (or if it is empty), as given
in your forwcomps file."} \
	{mhProfile(forwsubj) forwSubj {$subj (fwd)} {Subject line for forwarded messages}
"When \"Tweak subject lines of forwarded messages\" is enabled, this
option specifies the particular tweak to perform.  This usually consists
of suffixing \"(fwd)\" or prefixing \"Fw:\" (both of which are removed
if present in the original subject line).  The variable \$subj here is
replaced with the subject of the original message."} \
	[list mhProfile(delprefix) delPrefix [MhBackup] {Prefix of rmm'd files} \
"The Delete operation in MH really only renames a message file to have
a prefix like # or , (comma).  This prefernce setting is used to
set that prefix if you have a custom remove proc. The default setting is
correct for your version of MH."] \
	{mhProfile(purgeage) purgeAge 7 {Age, in days of files to purge}
"The Purge operation will remove deleted messages that are older
than this number of days."} \
    ]
    #
    # Backwards compatibility.  Nuke when 1.6alpha and 1.5.3 are dead.
    #
    set async [option get . sendAsync {}]
    if {[string length $async]} {
	set mhProfile(sendType) [expr {$async ? "async" : "wait"}]
    }
}

proc MhBackup {} {
    set sbackup {}
    catch {set sbackup [exec mhparam sbackup]}
    if {[string length $sbackup] == 0} {
	catch {exec mhparam -help} x
	regexp {SBACKUP="\"([^\"]+)\""} $x match sbackup
    }
    if {[string length $sbackup] == 0} {
	set sbackup #
    }
    return $sbackup
}

# Run an MH program and check for errors.
# If the context file gets corrupted, just remove it and try again.
proc MhExec { args } {
    global mhProfile
    Audit $args
    if {[catch {eval exec $args} result]} {
	global errorInfo
	if {[regexp {exmhcontext is poorly formatted} $result]} {
	    Exmh_Status "Resetting .exmhcontext" error
	    exec cat /dev/null > $mhProfile(path)/.exmhcontext
	    return [eval exec $args]
	} else {
	    error $result $errorInfo
	}
    } else {
#	These Exmh_Debug calls break up the atomicity of commit actions
#	by the background process because of Tk send and timer handling.
#	The periodic maintenence task can sneak in on us.
#	Exmh_Debug MhExec $args
	return $result
    }
}

# The following are default comp, repl, and forw setup procedures
# passed to Msg_Comp, Msg_Reply, and Msg_Forward, respectively.
proc Mh_CompSetup {} {
    global exmh mhProfile msg
    set indrafts [expr \
	{[string compare $exmh(folder) $mhProfile(draft-folder)] == 0}]
    if {$indrafts && ([string length $msg(id)] != 0)} {
	Exmh_Status "comp -use $msg(id)"
	Mh_SetCur $mhProfile(draft-folder) $msg(id)
    } else {
        set path [Mh_FindFile "components"]
	if {0 != [string length $path]} {
	    Exmh_Status "comp -form $path/components"
	    MhExec comp -nowhatnowproc -form $path/components
	} else {
	    Exmh_Status "comp"
	    MhExec comp -nowhatnowproc
	}
	if {$indrafts} {
	    # In drafts with no previously current message
	    Scan_Folder $exmh(folder)
	    Msg_Change [Seq_Msgs $exmh(folder) cur]
	}
    }
    set exmh([Mh_Cur $mhProfile(draft-folder)],action) comp
}
proc Mh_CompUseSetup {} {
    global exmh msg
    if {$msg(id) != {}} {
	Exmh_Status "comp -use $msg(id)"
	MhExec comp +$exmh(folder) $msg(id) -nowhatnowproc
    } else {
	Exmh_Status "No current message" warn
    }
    set exmh([Mh_Cur $mhProfile(draft-folder)],action) comp
}
proc Mh_ReplySetup { folder msg } {
    global mhProfile exmh
    set path [Mh_FindFile "replcomps"]
    if {0 != [string length $path]} {
	Exmh_Status "repl +$folder $msg -form $path/replcomps"
	MhExec repl +$folder $msg -nowhatnowproc -nocc cc -nocc to -form $path/replcomps
    } else {
	Exmh_Status "repl +$folder $msg"
	MhExec repl +$folder $msg -nowhatnowproc -nocc cc -nocc to
    }
    MhAnnoSetup $folder $msg repl
}
proc Mh_ReplyAllSetup { folder msg } {
    global mhProfile exmh
    set path [Mh_FindFile "replcomps"]
    if {0 != [string length $path]} {
	Exmh_Status "repl +$folder $msg -form $path/replcomps"
	MhExec repl +$folder $msg -nowhatnowproc -cc cc -cc to -form $path/replcomps
    } else {
	Exmh_Status "repl +$folder $msg"
	MhExec repl +$folder $msg -nowhatnowproc -cc cc -cc to
    }
    MhAnnoSetup $folder $msg repl
}
proc Mh_Forw_MungeSubj { folder msgs } {
    global mhProfile
    set draftID [Mh_Cur $mhProfile(draft-folder)]
    if {![catch {eval exec scan +$folder -noheader -format "%{subject}" $msgs} subj]} {
	# just take the first line of $subj (in case of >1 messages)
	set subj [lindex [split $subj "\n"] 0]
	# strip off leading and trailing "fw:", "(fwd)", "<fwd>" and whitespace
	regsub -nocase "^(\[ 	\]*((fwd?:)|(\\(fwd?\\))|(<fwd?>)))*" $subj {} subj
	regsub -nocase "(((\\(fwd?\\))|(<fwd?>))\[ 	\]*)*$" $subj {} subj
	set subj [string trim $subj]
	# quote any rogue \'s or &'s in the subject line
	regsub -all {\\} $subj {\\\\} subj
	regsub -all {&} $subj {\\\&} subj
	# now do the required munging, and quote \'s and &'s again
	regsub -all {\$subj} $mhProfile(forwsubj) $subj subj
	regsub -all {\\} $subj {\\\\} subj
	regsub -all {&} $subj {\\\&} subj
	catch {
	    set fd [open $mhProfile(path)/$mhProfile(draft-folder)/$draftID r]
	    set msgtxt [read $fd]
	    close $fd
	    if {[regexp -indices "\n(--+)?(\n|\$)" $msgtxt posn]} {
		set cpos [lindex $posn 0]
		set hdrtxt [string range $msgtxt 0 [expr {$cpos-1}]]
		set bodytxt [string range $msgtxt $cpos end]
	    } else {
		set hdrtxt $msgtxt
		set bodytxt {}
	    }
	    unset msgtxt
	    if {[regexp "^|\n\[Ss\]ubject:" $hdrtxt]} {
		regsub "(^|\n)(\[Ss\]ubject:)\[ 	\]*(\n|\$)" $hdrtxt "\\1\\2 $subj\\3" nhdrtxt
	    } else {
		set nhdrtxt "$hdrtxt\nSubject: $subj"
	    }
	    set fd [open $mhProfile(path)/$mhProfile(draft-folder)/$draftID w]
	    puts -nonewline $fd $nhdrtxt
	    puts -nonewline $fd $bodytxt
	    close $fd
	}
    }
}
proc Mh_ForwSetup { folder msgs } {
    global mhProfile exmh
    set path [Mh_FindFile "forwcomps"]
    if {0 != [string length $path]} {
	Exmh_Status "forw +$folder $msgs -form $path/forwcomps"
	eval {MhExec forw +$folder} $msgs -nowhatnowproc -form $path/forwcomps
    } else {
	Exmh_Status "forw +$folder $msgs"
	eval {MhExec forw +$folder} $msgs -nowhatnowproc
    }
    MhAnnoSetup $folder $msgs forw
    if {$mhProfile(forwtweak)} {
	Mh_Forw_MungeSubj $folder $msgs
    }
}
proc Mh_DistSetup { folder msg } {
    global exmh mhProfile
    set path [Mh_FindFile "distcomps"]
    if {0 != [string length $path]} {
	Exmh_Status "dist +$folder $msg -form $path/distcomps"
        MhExec dist +$folder $msg -nowhatnowproc -form $path/distcomps
    } else {
        Exmh_Status "dist +$folder $msg"
        MhExec dist +$folder $msg -nowhatnowproc
    }
    MhAnnoSetup $folder $msg dist
}
proc MhAnnoSetup { folder msg key args } {
    global mhProfile exmh
    set draftID [Mh_Cur $mhProfile(draft-folder)]
    set exmh($draftID,mhaltmsg) $mhProfile(path)/$folder/$msg
    set exmh($draftID,mhfolder) $mhProfile(path)/$folder
    set exmh($draftID,folder) $folder
    set exmh($draftID,mhmessages) $msg
    set exmh($draftID,action) $key
    Exmh_Debug MhAnnoSetup action $key for $draftID

	# I don't assume both alternative options will be set together
	set noannoIX [lsearch $args -noannotate]
	set annoIX [lsearch $args -annotate]
	if { ($exmh(anno,$key) || ($annoIX >= 0)) &&  ($noannoIX < 0) } {
		set exmh($draftID,mhanno$key) 1
	}

	set noinplaceIX [lsearch $args -noinplace]
	set inplaceIX [lsearch $args -inplace]
    if { ($exmh(inplace,$key) || ($inplaceIX >= 0)) && \
		 ($noinplaceIX < 0) } {
			set exmh($draftID,mhinplace$key) 1
    }
}
proc Mh_AnnoEnviron { draftID } {
    global exmh env
    if {![info exists exmh($draftID,mhaltmsg)]} {
	return 0
    }
    set env(mhaltmsg) $exmh($draftID,mhaltmsg)
    set env(mhfolder) $exmh($draftID,mhfolder)
    set env(mhmessages) $exmh($draftID,mhmessages)
    if {[info exists exmh($draftID,mhinplace)]} {
      set env(mhinplace) 1
    }
    if {$exmh($draftID,action) == "dist"} {
	# dist requires annotation; it just does.
	set env(mhdist) 1
	set env(mhannodist) 1
	set env(mhannotate) "Resent"
	return [info exists exmh($draftID,mhannodist)]
    }
    if {[info exists exmh($draftID,mhannorepl)]} {
	set env(mhannorepl) 1
	set env(mhannotate) "Replied"
	return $exmh($draftID,mhannorepl)
    }
    if {[info exists exmh($draftID,mhannoforw)]} {
	set env(mhannoforw) 1
	set env(mhannotate) "Forwarded"
	return $exmh($draftID,mhannoforw)
    }
    return 0
}
proc Mh_AnnoCleanup { draftID } {
    global exmh env
    
    foreach key {mhannoforw mhannorepl mhannodist mhannotate mhdist
		 mhaltmsg mhfolder mhmessages mhinplace folder action} {
	if {[info exist exmh($draftID,$key)]} {
	    unset exmh($draftID,$key)	;# Faster than catch-unset
	}
	if {[regexp ^mh $key]} {
	    catch {unset env($key)}
	}
    }
}

proc Mh_Folder { f } {
    if {[catch {MhExec folder +$f < /dev/null} info]} {
	Exmh_Debug Mh_Folder caught $info
	return {}
    } else {
	if {[regexp {\+[^0-9]+ ([0-9]+) [^(]*\(([^)]+)\)} $info x total range]} {
	    regsub -all { } $range {} range
	    return "$f+ $total msgs ($range)"
	} else {
	    return $info
	}
    }
}
proc Mh_FolderNew { f } {
    Mh_SetContext Current-Folder $f
}
proc Mh_SetContext { key value } {
    global mhProfile
    set in [open $mhProfile(context) r]
    if {[catch {open $mhProfile(context).new w} out] == 0} {
	while {[gets $in line] >= 0} {
	    if {[regexp -nocase "^$key: (.*)$" $line match oldvalue]} {
		puts $out "$key: $value"
	    } else {
		if {$line != {}} {
		    puts $out $line
		}
	    }
	}
	close $in
	close $out
	frename $mhProfile(context).new $mhProfile(context)
	return $value
    } else {
	close $in
	Exmh_Status "Cannot write $mhProfile(context).new" error
    }
}
proc Mh_MsgChk {} {
    global inc pop
    
    if {[string length $inc(pophost)]} {
	# See if we know the password for this host
	Pop_GetPassword $inc(pophost)
	catch {exec msgchk -nodate -notify mail -host $inc(pophost) << $pop(password)} result
	Exmh_Debug Mh_MsgChk $result
	# Remove 'Password (host:user):' prompt from result string, and
	# msgchk returned 1 because no messages were waiting, remove the
	# error message left by 'exec'
	regsub {.*\):} $result {} result
	regsub "\n.*" $result {} result
    } else {
	catch {MhExec msgchk -nodate -notify mail} result
    }

    return $result
}
proc Mh_MsgCount { spool } {
    return [exec egrep "^From " $spool | wc -l]
}
proc Mh_CurSafe { folder } {
    MhExec folder +$folder -push < /dev/null
    if {[catch {MhExec pick +$folder -list cur} cur]} {
	set cur {}
    }
    MhExec folder -pop < /dev/null
    return $cur
}

proc Mh_SetCur { folder msgid } {
    global mhPriv
    if {[info exists mhPriv(cur,$folder)] &&
	($mhPriv(cur,$folder) == $msgid)} {
	return
    }
    Mh_SequenceUpdate $folder replace cur $msgid
    Seq_Set $folder cur $msgid
    set mhPriv(cur,$folder) $msgid
}
proc Mh_Cur { folder } {
    global mhPriv
    if {[catch {MhCur $folder} cur]} {
	set cur [Mh_CurSafe $folder]
    }
    set mhPriv(cur,$folder) $cur
    return $mhPriv(cur,$folder)
}
proc MhCur { folder } {
    # pick +folder cur changes the context, so we access the files directly
    global mhProfile
    if {$folder == {}} {
	return {}
    }
    set cur [Seq_Msgs $folder cur]
    if {[file exists $mhProfile(path)/$folder/$cur]} {
	return $cur
    } else {
	return {}
    }
}
proc MhReadSeqs {folder seqsvar} {
    global mhProfile mhPriv
    upvar $seqsvar seqs
    # First read the private sequence
    set mhPriv(changed,private) 0
    set filename $mhProfile(context)
    if [file exists $filename] {
	set mtime [file mtime $filename]
	if {![info exists mhPriv(privmtime)] || ($mtime != $mhPriv(privmtime))} {
	    foreach elem [array names mhPriv] {
		set indices [split $elem ,]
		if {[lindex $indices 0] == {privseq}} {
		    if {[lindex $indices 1] == $folder} {
			unset mhPriv($elem)
		    }
		}
	    }
	    if {[catch {open $filename r} in] == 0} {
		Exmh_Debug MhReadSeqs Reading $filename
		set old [read $in]
		close $in
		set mhPriv(otherpriv) {}
		foreach line [split $old \n] {
		    if {$line != {}} {
			if {[regexp {^([^:]*):\s*(.*)$} $line foo tag msgids]} {
			    if {[regexp "atr-(.*)-$mhProfile(path)/(.*)" $tag foo seq thisfolder]} {
				set mhPriv(privseq,$thisfolder,$seq) [MhSeqExpand $thisfolder $msgids]
				set mhPriv(mode,$seq) private
			    } else {
				lappend mhPriv(otherpriv) "$line"
			    }
			} else {
			    Exmh_Status "Bad line in $filename: $line"
			}
		    }
		}
		set mhPriv(privmtime) $mtime
	    }
	}
    }
    foreach elem [array names mhPriv] {
	set indices [split $elem ,]
	if {[lindex $indices 0] == {privseq}} {
	    if {[lindex $indices 1] == $folder} {
		set seqs([lindex $indices 2]) $mhPriv($elem)
	    }
	}
    }
    # Then read the public sequence
    set mhPriv(changed,public) 0
    set filename "$mhProfile(path)/$folder/$mhProfile(mh-sequences)"
    if [file exists $filename] {
	set mtime [file mtime $filename]
	if {![info exists mhPriv(seqmtime,$folder)] || ($mtime != $mhPriv(seqmtime,$folder))} {
	    foreach elem [array names mhPriv] {
		set indices [split $elem ,]
		if {[lindex $indices 0] == {pubseq}} {
		    if {[lindex $indices 1] == $folder} {
			unset mhPriv($elem)
		    }
		}
	    }
	    if {[catch {open $filename r} in] == 0} {
		Exmh_Debug MhReadSeq Reading $filename
		set old [read $in]
		close $in
		foreach line [split $old \n] {
		    if {$line != {}} {
			if {[regexp {^([^:]*):\s*(.*)$} $line foo seq msgids]} {
			    if {[info exists mhPriv(mode,$seq)] && $mhPriv(mode,$seq) == "private" && [info exists mhPriv(pubseq,$folder,$seq)]} {
				# If this was also in the private file, merge the two
				# and move to the public file.
				set mhPriv(changed,private) 1
				lappend mhPriv(pubseq,$folder,$seq) [MhSeq $folder $seq add $mhPriv(pubseq,$folder,$seq) [MhSeqExpand $folder $msgids]]
			    } else {
				set mhPriv(pubseq,$folder,$seq) [MhSeqExpand $folder $msgids]
			    }
			    set mhPriv(mode,$seq) public
			} else {
			    Exmh_Status "Bad line in $filename: $line"
			}
		    }
		}
		set mhPriv(seqmtime,$folder) $mtime
	    }
	}
    }
    foreach elem [array names mhPriv] {
	set indices [split $elem ,]
	if {[lindex $indices 0] == {pubseq}} {
	    if {[lindex $indices 1] == $folder} {
		set seqs([lindex $indices 2]) $mhPriv($elem)
	    }
	}
    }
}

proc MhGetSeqCache {folder seq } {
    global mhPriv
    set seqlist ""
    if {[info exists mhPriv(pubseq,$folder,$seq)]} {
        set seqlist $mhPriv(pubseq,$folder,$seq)
    }
    if {[info exists mhPriv(privseq,$folder,$seq)]} {
        lappend seqlist $mhPriv(privseq,$folder,$seq)
    }
    return $seqlist
}

proc Mh_Sequences { folder } {
    MhReadSeqs $folder seqs
    return [array names seqs]
}
proc Mh_Sequence { folder seq } {
    # pick +folder cur changes the context, so we access the files directly
    MhReadSeqs $folder seqs
    if [info exists seqs($seq)] {
	return [MhSeqExpand $folder $seqs($seq)]
    } else {
	return {}
    }
}
proc MhSeqExpand { folder sequence } {
    global mhProfile
    # Explode a sequence into a list of message numbers
    set seq {}
    set rseq {}
    foreach range [split [string trim $sequence]] {
	if ![regexp {^[0-9]+(-[0-9]+)?$} $range] {
	    # just ignore anything bogus
	    continue;
	}
	set parts [split [string trim $range] -]
	if {[llength $parts] == 1} {
	    lappend seq $parts
	    set rseq [concat $parts $rseq]
	} else {
	    for {set m [lindex $parts 0]} {$m <= [lindex $parts 1]} {incr m} {
		lappend seq $m
		set rseq [concat $m $rseq]
	    }
	}
    }
    # Hack to weed out sequence numbers for messages that don't exist
    foreach m $rseq {
	if ![file exists $mhProfile(path)/$folder/$m] {
	    Exmh_Debug $mhProfile(path)/$folder/$m not found
	    set ix [lsearch $seq $m]
	    set seq [lreplace $seq $ix $ix]
	} else {
	    # Real hack
	    break
	}
    }
    return $seq
}

# Directly modify the context files to add/remove/clear messages
# from a sequence
proc Mh_SequenceUpdate { folder how seq {msgids {}} {which public}} {
    global mhProfile mhPriv
    if {0} {
	Exmh_Debug Mh_SequenceUpdate $folder $how $seq $msgids $which
	set l [info level]
	while {[incr l -1] > 0} {
	    Exmh_Debug "    : [info level $l]"
	}
    }
    if {[info exist seqs]} {
      unset seqs
    }
    foreach elem [array names mhPriv] {
	set indices [split $elem ,]
	if {[lindex $indices 0] == {mode}} {
	    if {[lindex $indices 1] == $folder} {
		unset mhPriv($elem)
	    }
	}
    }
    MhReadSeqs $folder seqs
    # Set the value for the sequence we're updating
    if [catch {set seqs($seq)} oldmsgids] {
	set oldmsgids {}
    }
    set seqs($seq) [MhSeq $folder $seq $how $oldmsgids $msgids]
    if {![catch {set mhPriv(mode,$seq)}] && ($mhPriv(mode,$seq) != $which)} {
	set mhPriv(changed,$mhPriv(mode,$seq)) 1
    }
    set mhPriv(mode,$seq) $which
    set oldseq [MhSeqMake $oldmsgids]
    if {$seqs($seq) != $oldseq} {
	Exmh_Debug "$seq: $oldseq => $seqs($seq)"
	set mhPriv(changed,$which) 1
    }
    if {$mhPriv(changed,public) == 1} {
	set mhPriv(pubseq,$folder,$seq) [MhSeqExpand $folder $seqs($seq)]
	set filename $mhProfile(path)/$folder/$mhProfile(mh-sequences)
	if {[catch {open $filename.new w} out] == 0} {
	    Exmh_Debug Writing $filename
	    foreach thisseq [array names seqs] {
		if {![info exists mhPriv(mode,$thisseq)]} {
		    set mhPriv(mode,$thisseq) public
		}
		if {$mhPriv(mode,$thisseq) == "public"} {
		    if {![regexp {^ *$} $seqs($thisseq)]} {
			if [regexp -- {-} $seqs($thisseq)] {
			    set realseq $seqs($thisseq)
			} else {
			    set realseq [MhSeqMake $seqs($thisseq)]
			}
			puts $out "$thisseq: $realseq"
		    }
		}
	    }
	    close $out
	    Mh_Rename $filename.new $filename
	    set mhPriv(seqmtime,$folder) [file mtime $filename]
	} else {
	    Exmh_Status "Couldn't write to $mhProfile(path)/$folder/$mhProfile(mh-sequences).new"
	    set mhPriv(changed,private) 1
	    foreach thisseq [array names seqs] {
		set mhPriv(mode,$thisseq) "private"
	    }
	}
    }
    if {$mhPriv(changed,private) == 1} {
	set mhPriv(privseq,$folder,$seq) [MhSeqExpand $folder $seqs($seq)]
	set filename $mhProfile(context)
	if {[catch {open $filename.new w} out] == 0} {
	    Exmh_Debug Writing $filename
	    puts $out [join $mhPriv(otherpriv) "\n"]
	    foreach thisseq [array names seqs] {
		if {[string compare $mhPriv(mode,$thisseq) "private"] == 0} {
		    if {![regexp {^ *$} $seqs($thisseq)]} {
			if [regexp -- {-} $seqs($thisseq)] {
			    set realseq $seqs($thisseq)
			} else {
			    set realseq [MhSeqMake $seqs($thisseq)]
			}
			puts $out "atr-$thisseq-$mhProfile(path)/$folder: $realseq"
		    }
		}
	    }
	    close $out
	    Mh_Rename $filename.new $filename
	    set mhPriv(privmtime) [file mtime $filename]
	}
    }
}
proc MhSeq { folder seq how oldmsgids msgids } {
    set new [MhSeqExpand $folder $msgids]
    set old [MhSeqExpand $folder $oldmsgids]
    if {[string compare $how "add"] == 0} {
	set merge [lsort -integer -increasing [concat $old $new]]
	set seq [MhSeqMake $merge]
	return $seq
    } elseif {[string compare $how "del"] == 0} {
	set ix 0
	set new [lsort -integer -increasing $new]
	set next [lindex $new 0]
	set merge {}
	foreach id [lsort -integer -increasing $old] {
	    while {$id > $next} {
		incr ix
		set next [lindex $new $ix]
		if {[string length $next] == 0} {
		    incr ix -1
		    set next [lindex $new $ix]
		    break
		}
	    }
	    if {$id == $next} {
		incr ix
		set next [lindex $new $ix]
	    } else {
		lappend merge $id
	    }
	}
	return [MhSeqMake $merge]
    } elseif {[string compare $how "replace"] == 0} {
	# replace
	return [MhSeqMake $msgids]
    } else {
	return {}
    }
}
proc MhSeqMakeOld { msgs } {
    set result [lindex $msgs 0]
    set first $result
    set last $result
    set id {}
    foreach id [lrange $msgs 1 end] {
	if {$id != $last} {
	    if {$id == $last + 1} {
		set last $id
	    } else {
		if {$last != $first} {
		    append result -$last
		}
		set first $id
		set last $id
		append result " $first"
	    }
	}
    }
    if {$id == $last && [string length $msgs]} {
	append result -$last
    }
    return $result
}
proc MhSeqMake { msgids } {
    set result {}
    set first {}
    set last {}
    foreach id $msgids {
	if {$id == $last} {
	    # Skipit
	} elseif {($last != {}) && ($id == $last + 1)} {
	    if {$first == {}} {
		set first $last
	    }
	} else {
	    if {$first != {}} {
		lappend result "$first-$last"
	    } elseif {$last != {}} {
		lappend result $last
	    } 
	    set first {}
	}
	set last $id
    }
    if {$first != {}} {
	lappend result "$first-$last"
    } elseif {$last != {}} {
	lappend result $last
    }
    return $result
}

proc Mh_Path { folder msg } {
    global mhProfile
    if {[regexp {^[0-9]+$} $msg]} {
	return $mhProfile(path)/$folder/$msg
    } else {
	return [MhExec mhpath +$folder $msg]
    }
}

# Note - do not put Exmh_Debug calls into Mh_Refile, Mh_Copy, or Mh_Rmm
# because that seems to open a window that allows the periodic background
# tasks to run.  This causes a race between commit actions and background
# inc/flist actions.

proc Mh_Refile {srcFolder msgids folder} {
    while {[llength $msgids] > 0} {
	set chunk [lrange $msgids 0 19]
	set msgids [lrange $msgids 20 end]
	eval {MhExec refile} $chunk {-src +$srcFolder +$folder}
    }
}
proc Mh_RefileFile {folder file} {
    Exmh_Debug exec refile -link -file $file +$folder
    eval {exec refile -link -file $file +$folder}
}
proc Mh_Copy {srcFolder msgids folder} {
    while {[llength $msgids] > 0} {
	set chunk [lrange $msgids 0 19]
	set msgids [lrange $msgids 20 end]
	eval {MhExec refile} $chunk {-link -src +$srcFolder +$folder}
    }
}
proc Mh_Rmm { folder msgids } {
    while {[llength $msgids] > 0} {
	set chunk [lrange $msgids 0 19]
	set msgids [lrange $msgids 20 end]
	eval {MhExec rmm +$folder} $chunk
    }
}
proc Mh_Send { msgid } {
    global mhProfile
    
    set path $mhProfile(path)/$mhProfile(draft-folder)/$msgid
    set dst [Misc_PostProcess $path]
    
    switch -- $mhProfile(sendType) {
	"async" {
	    MhExec $mhProfile(sendproc) -draftf +$mhProfile(draft-folder) \
		-draftm $dst -push -forward < /dev/null
	}
	"wait" {
	    MhExec $mhProfile(sendproc) -draftf +$mhProfile(draft-folder) \
		-draftm $dst < /dev/null
	}
	"xterm" {
	    eval exec $mhProfile(xtermcmd) { \
		-title "Sending $mhProfile(draft-folder)/$msgid ..." \
		-e sh -c "$mhProfile(sendproc) -draftf +$mhProfile(draft-folder) -draftm $dst || whatnow -draftf +$mhProfile(draft-folder) -draftm $dst" &}
	}
    }
    if {$msgid != $dst} {
	# In case we made a copy during post processing.
	Mh_Rmm $mhProfile(draft-folder) $msgid
    }
}
proc Mh_Whom { msgid } {
    global mhProfile
    if {![regexp {^[0-9]+$} $msgid]} {
	MhExec whom $msgid
    } else {
	MhExec whom -draftf +$mhProfile(draft-folder) -draftm $msgid
    }
}

proc Mh_Sort { f args } {
    if {[catch {eval {MhExec sortm +$f} $args} err]} {
	Exmh_Status $err error
    }
}
proc Mh_Pack { f } {
    if {[catch {MhExec folder +$f -pack} err]} {
	Exmh_Status $err error
    }
}

proc MhParseProfile {} {
    global mhProfile env
    if {[info exists env(MH)]} {
	set mhProfile(profile) $env(MH)
    } else {
	set mhProfile(profile) $env(HOME)/.mh_profile
    }
    if {[catch {open $mhProfile(profile) "r"} input]} {
	if {[info exists mhProfile(FAIL)]} {
	    puts stderr "Cannot open $mhProfile(profile): $input"
	    exit 1
	} else {
	    set mhProfile(FAIL) 1
	    MhSetupNewUser
	    MhParseProfile
	    unset mhProfile(FAIL)
	    return
	}
    }
    while {![eof $input]} {
	set numBytes [gets $input line]
	if {$numBytes > 0} {
	    if {[regexp {^\s+(.*)$} $line foo other]} {
		# handle continued lines
		if {[info exists key]} {
		    append mhProfile($key) " [string trim $other]"
		}
		continue
	    }
	    set parts [split $line :]
	    set key [string tolower [lindex $parts 0]]
	    set other [lindex $parts 1]
	    set value [string trim $other]
	    set mhProfile($key) $value
	}
    }
    close $input
    if {![info exists mhProfile(path)]} {
	if {[info exists mhProfile(FAIL)]} {
	    puts stderr "No Path entry in your [file tail $mhProfile(profile)] file."
	    puts stderr "Run the \"inc\" command to get your"
	    puts stderr "MH environment initialized right."
	    exit 1
	} else {
	    set mhProfile(FAIL) 1
	    MhSetupNewUser
	    MhParseProfile
	    unset mhProfile(FAIL)
	    return
	}
    } else {
	if {[string index $mhProfile(path) 0] != "/"} {
	    set mhProfile(path) [glob ~]/$mhProfile(path)
	}
	if {![file isdirectory $mhProfile(path)]} {
	    MhSetupNewUserInner
	}
    }
    if {[info exists env(MHCONTEXT)]} {
	set mhProfile(context) $env(MHCONTEXT)
    }
    if {![info exists mhProfile(context)]} {
	set mhProfile(context) context
    }
    set mhProfile(context) [Mh_Pathname $mhProfile(context)]
    if {![file exists $mhProfile(context)]} {
	close [open $mhProfile(context) w]
    }
    
    if {![info exists mhProfile(mh-sequences)]} {
	set mhProfile(mh-sequences) .mh_sequences
    }
    if {$mhProfile(mh-sequences) == {}} {
	set mhProfile(mh-sequences) .mh_sequences
    }
    if {![info exists mhProfile(editor)]} {
	if {[info exists env(EDITOR)]} {
	    set mhProfile(editor) $env(EDITOR)
	} else {
	    set mhProfile(editor) sedit
	}
    }
    if {![info exists mhProfile(draft-folder)]} {
	MhSetupDraftFolder
    } else {
	set mhProfile(draft-folder) [string trim $mhProfile(draft-folder) +]
	if {![file isdirectory $mhProfile(path)/$mhProfile(draft-folder)]} {
	    Exmh_Status "Creating drafts folder"
	    if {[catch {exec mkdir $mhProfile(path)/$mhProfile(draft-folder)} msgid]} {
		catch {
		    puts stderr "Cannot create drafts folder $mhProfile(path)/$mhProfile(draft-folder)"
		}
	    }
	}
    }
    if {![info exists mhProfile(unseen-sequence)]} {
	MhSetupUnseenSequence
    }
    if {![info exists mhProfile(header-suppress)]} {
	set mhProfile(header-suppress) {.*}
    } else {
	set suppress {}
	foreach item $mhProfile(header-suppress) {
	    lappend suppress [string tolower $item]
	}
	set mhProfile(header-suppress) $suppress
    }
    if {![info exists mhProfile(header-display)]} {
	set mhProfile(header-display) {subject from date to cc newsgroups}
    } else {
	set display {}
	foreach item $mhProfile(header-display) {
	    lappend display [string tolower $item]
	}
	set mhProfile(header-display) $display
    }
    if {![info exists mhProfile(folder-order)]} {
	set mhProfile(folder-order) {inbox *}
    }
    if {![info exists mhProfile(folder-unseen)]} {
	set mhProfile(folder-unseen) {*}
    }
    if {![info exists mhProfile(folder-ignore)]} {
	set mhProfile(folder-ignore) {.* */.* */*/.* */*/*/.*}
    }
    foreach key {dist forw repl} {
	global exmh
	set exmh(anno,$key) 0
	set exmh(inplace,$key) 0
	if {[info exists mhProfile($key)]} {
	    if {[lsearch $mhProfile($key) -annotate] >= 0} {
		set exmh(anno,$key) 1
		Exmh_Debug "MH anno $key"
	    }
	    if {[lsearch $mhProfile($key) -inplace] >= 0} {
		set exmh(inplace,$key) 1
		Exmh_Debug "MH inplace $key"
	    }
	}
    }
    if {![info exists mhProfile(sendproc)]} {
	set mhProfile(sendproc) send
    }
    if {![info exists mhProfile(msg-protect)]} {
	set mhProfile(msg-protect) 0644
    }
}
proc MhSetupNewUser {} {
    global mhProfile
    Widget_Toplevel .newuser "Setup MH environment"
    Widget_Message .newuser msg -aspect 1000 -text "
Exmh is a front end to the MH mail handling system.
Feel free to send comments and bug reports to
	Brent.Welch@acm.org

It appears you have not used the MH mail system before.
(Your [file tail $mhProfile(profile)] is missing or incomplete.)
Normally MH creates a directory named ~/Mail and puts
its mail folders and some other files under there.
If you want your folders elsewhere, you will have to
exit Exmh and run the program install-mh by hand.

Is it ok if Exmh sets up your MH environment for you?
"

    Widget_Frame .newuser rim Pad {top expand fill}
    .newuser.rim configure -bd 10
    
    Widget_Frame .newuser.rim but Menubar {top fill}
    Widget_AddBut .newuser.rim.but yes "Yes" MhSetupNewUserInner
    Widget_AddBut .newuser.rim.but no "No, Exit" { destroy .newuser ; exit }
    tkwait window .newuser
}
proc MhSetupNewUserInner {} {
    global mhProfile exmh
    set exmh(newuser) 1
    catch {exec mkdir [glob ~]/Mail}
    if {![file exists $mhProfile(profile)]} {
	set out [open $mhProfile(profile) w]
	puts $out "Path: Mail"
	close $out
    }
    catch {MhExec inc < /dev/null} result
    Exmh_Status $result
    catch {destroy .newuser}
}
proc MhSetupDraftFolder {} {
    global mhProfile
    Widget_Toplevel .draft "Setup Draft Folder"
    Widget_Message .draft msg -aspect 1000 -text "
For the Compose, Reply, and Forward operations to work,
you need to have an MH drafts folder.  Creating one
requires making a directory (you choose the name)
and adding a draft-folder: entry
to your [file tail $mhProfile(profile)].

Should Exmh help you do that now?"
    
    Widget_Frame .draft rim Pad {top expand fill}
    .draft.rim configure -bd 10
    
    Widget_Label .draft.rim l {left} -text "Folder name: "
    Widget_Entry .draft.rim e {left fill}  -bg white
    .draft.rim.e insert 0 drafts
    
    Widget_Frame .draft.rim but Menubar {top fill}
    Widget_AddBut .draft.rim.but yes "Yes" MhSetupDraftFolderInner
    Widget_AddBut .draft.rim.but no "Exit" { exit }
    update
    tkwait window .draft
}
proc MhSetupDraftFolderInner {} {
    global mhProfile
    
    set dirname [.draft.rim.e get]
    set mhProfile(draft-folder) $dirname
    
    set dir $mhProfile(path)/$mhProfile(draft-folder)
    if {![file isdirectory $dir]} {
	if {[catch {
	    exec mkdir $dir
	    Exmh_Status "Created drafts folder \"+drafts\""
	} err]} {
	    Exmh_Status "Cannot create a drafts folder! $err" error
	    unset mhProfile(draft-folder)
	    destroy .draft
	    return
	}
    }
    if {[catch {open $mhProfile(profile) a} out]} {
	Exmh_Status "Cannot open $mhProfile(profile): $out" error
	unset mhProfile(draft-folder)
	destroy .draft
	return
    }
    puts $out "draft-folder: $dirname"
    Exmh_Status "draft-folder: $dirname"
    close $out
    
    destroy .draft
}
proc MhSetupUnseenSequence {} {
    global mhProfile
    set mhProfile(unseen-sequence) unseen
    
    if {[catch {open $mhProfile(profile) a} out]} {
	Exmh_Status "Cannot open $mhProfile(profile): $out" error
	unset mhProfile(unseen-sequence)
	exit
    }
    catch {puts $out "unseen-sequence: $mhProfile(unseen-sequence)"}
    close $out
    Exmh_Status "Added unseen-sequence to [file tail $mhProfile(profile)]"
}
proc MhSetMailDrops {} {
    global exdrops env mhProfile exdropMtime
    
    global inc
    if {![regexp multi $inc(style)]} {
	return
    }
    if {[file exists $env(HOME)/.exmhdrop]} {
	catch {puts stderr ".exmhdrop should be named .xmhcheck"}
	set name .exmhdrop
    } else {
	set name .xmhcheck
    }
    
    if {[file exists $env(HOME)/$name]} then {
	set mtime [file mtime $env(HOME)/$name]
	if {[info exists exdropMtime]} {
	    if {$mtime <= $exdropMtime} {
		return
	    }
	}
	set exdropMtime $mtime
    }
    set exdrops(foo) bar	;# Ensure empty array variable
    foreach unique [array names exdrops] {
	unset exdrops($unique)
    }
    if {[file exists $env(HOME)/$name]} then {
	set df [open $env(HOME)/$name]
	while {![eof $df]} {
	    # The second field is either a dropbox pathname
	    # (absolute or env(HOME) relative), or it is
	    # a POP hostname followed by an optional POP username
	    gets $df line
	    set fields [scan $line "%s %s %s" f d u]
	    if {$fields < 2} {
		Exmh_Status "Invalid .xmhcheck: $line"
	    } else {
		Exmh_Status "Found dropbox $d to folder $f"
		if {[string first / $d] > 0} {
		    # hostnames ought not to have /'s
		    set d "$env(HOME)/$d"
		}
		set folderDirectory "$mhProfile(path)/$f"
		if {![file isdirectory $folderDirectory]} {
		    Exmh_Status "No directory for folder $f ($name)"
		    continue
		}
		# Setup $unique as a unique identifier for this maildrop
		# avoids clashes when you have 2 drops going to one folder
		if {$fields == 2} {
		    set u "local"
		} 
		set unique "$f-$d-$u"
		set exdrops($unique) [list $f $d $u]
	    }
	}
	close $df
    } else {
	catch {puts stderr "Multidrop needs $name mapping file"}
    }
}
proc Mhn_DeleteOrig { msgid } {
    global mhProfile
    set path $mhProfile(path)/$mhProfile(draft-folder)/$mhProfile(delprefix)$msgid
    if {[file exists $path.orig]} {
	Exmh_Debug Mhn_DeleteOrig deleting $path.orig
	File_Delete $path.orig
    }
}

proc Mhn_RenameOrig { msgid } {
    global mhProfile
    set path $mhProfile(path)/$mhProfile(draft-folder)/$mhProfile(delprefix)$msgid
    if {[file exists $path.orig]} {
	Exmh_Debug Edit_Done moving $path.orig to $path
	catch {Mh_Rename $path.orig $path}
    }
}
# Map from a pathname in the MH profile to an absolute pathname.
proc Mh_Pathname { profile } {
    global mhProfile
    if {[string match /* $profile]} {
	return $profile
    }
    if {[regexp {^~/(.*)} $profile match relative]} {
	return [glob ~]/$relative
    } elseif {[regexp {^~([^/]+)/(.*)} $profile match user relative]} {
	return [glob ~$user]/$relative
    }
    return $mhProfile(path)/$profile
}

set mh_mv_flag -f
proc Mh_Rename { old new } {
    global mh_mv_flag tk_version
    if {$tk_version >= 4.2} {
	file rename -force $old $new
    } else {
	eval exec mv $mh_mv_flag {$old $new} < /dev/null
    }
}

# find a *comp* file going up from the current folder
proc Mh_FindFile { filename } {
    global mhProfile exmh
    if {[file exists [file join $mhProfile(path) $exmh(folder) $filename]]} {
	return $exmh(folder)
    }
    set path $exmh(folder)
    while {[string compare [set path [file dirname $path]] "."] != 0} {
	if {[file exists [file join $mhProfile(path) $path $filename]]} {
	    return $path
	}
    }
    # Not found until got to $mhProfile(path), return null string
    return ""
    
}
# exmh-2.5 APIs
# Mh_ClearCur 
# Mh_Unseen 

proc Mh_MarkSeen {folder ids} {
    global mhProfile
    Seq_Del $folder $mhProfile(unseen-sequence) $ids
}
proc Mh_MarkUnseen {folder ids} {
    Seq_Add $folder $mhProfile(unseen-sequence) $ids
}
