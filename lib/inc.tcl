# inc.tcl
#
# Incorporate new mail into folders.
# The routines here are prepared to be operating in a different
# interpreter than the main UI.  After they do the inc thing,
# they use BgRPC to invoke the UI-related routines in the
# correct interpreter.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Inc_Init {} {
    global exmh inc
    if {![info exist exmh(slocal)] || $exmh(slocal) == {}} {
	set exmh(slocal) slocal
    }
    if [info exists exmh(incStyle)] {
	# Backward compatibility
	set inc(style) $exmh(incStyle)
    }
    if [info exists exmh(incOnStart)] {
	# Backward compatibility
	set inc(onStartup) $exmh(incOnStart)
    }
    Preferences_Add "Incorporate Mail" \
"Exmh knows several ways to incorporate mail from your system's spool file into the MH folder hierarchy." {
	{inc(style) incStyle	{CHOICE inbox presort multidrop presortmulti custom none} {Ways to Inc}
"inbox - basic MH inc from your spool file to inbox folder.
presort - slocal filtering directly into various folders.
multidrop - slocal filtering or POP delivery into various drop boxes,
as specified by ~/.xmhcheck, that are in turn inc'ed into folders.
presortmulti - presort + multidrop.
custom - use an Inc_Custom procedure, which is user supplied.
none - you have an external agent that handles inc for you, so
don't bother trying it from within exmh."}
	{inc(onStartup) incOnStartup OFF	  {Inc at startup}
"Run your flavor of inc when exmh starts up."}
	{inc(onMapping) incOnMapping OFF	  {Inc on mapping}
"Run your flavor of inc when exmh is opened
after being iconic."}
	{inc(presortFeedback) incSortFeedback ON	  {Presort Inc feedback}
"This option causes a message to be generated each time a
new message is sorted into a folder.  There isn't much info,
it's just sort of a heart-beat feature..."}
	{inc(xnsgetmail) xnsGetMail OFF	  {Run xnsgetmail -k}
"Run xnsgetmail -k before inc in order to fetch your
XNS mail messages into your UNIX spool file."}
	{inc(startupflist) incStartupFlist {CHOICE default on off}      {Do a FList on startup}
"This option determines whether exmh performs an FList operation to find
all unread MH message on startup. On or off have the obvious effects;
default performs a FList if you're using multidrop or if you don't have
inc on startup on."}
	{inc(pophost) popHost {}	  {Mail host for POP3 protocol}
"If this is set, inc will try to use the POP3 protocol to
fetch your mail from a mail server.  This *requires* the
Expect program so exmh can automatically manage your POP3 password."}
	{exmh(incfilter) incfilter {CHOICE slocal procmail other} {Method used to filter incoming mail}
"Choose here between using slocal (and .maildelivery),
procmail (and procmailrc) and some other method" }
        {exmh(slocalArgs) slocalArgs {-verbose -maildelivery $env(HOME)/.maildelivery} {Additional arguments to slocal}
"Add any additional slocal arguments here." }
        {exmh(procmailArgs) procmailArgs {$env(HOME)/.procmailrc} {Additional arguments to procmail}
"Add any additional procmail arguments here."}
        {exmh(incfilterArgs) incfilterArgs {} {Generic incfilter arguments}
"Specify a command line for a generic inbox filter here." }
    }
}
proc Inc_Startup {} {
    global inc
    if {$inc(startupflist) == "on" ||
       ($inc(startupflist) == "default" &&
       (! $inc(onStartup) || $inc(style) == "multidrop"))} {
	Exmh_Status "Checking folders"
	Flist_FindSeqs
    }
    if {$inc(onStartup)} {
	set s [Sound_Off]
	Inc
	if {$s} { Sound_On }
    }
}
proc Inc_Mapped {} {
    global inc
    if {$inc(onMapping)} {
	Inc
    }
}

# Inc_Show is appropriate for the Inc button, but not for the
# background inc process.  It incs, changes to inbox, and shows
# the first unseen message in the folder.  (That may or may not
# be the first one just inc'ed.)

proc Inc_Show {} {
    global exmh mhProfile

    Inc
    if { $exmh(folder) != "inbox" } {
	Folder_Change inbox
    }
    Msg_Show $mhProfile(unseen-sequence)
}

proc Inc {} {
    BgAction "Inc" IncInner	;# Execute in the background process.
}
proc IncInner {} {
    # There are three different styles of inc'ing messages...
    global inc
    if $inc(xnsgetmail) {
	Xns_GetMail
    }
    if {[string length $inc(pophost)]} {
	# See if we know the password for this host
	Pop_GetPassword $inc(pophost)
    }
    case $inc(style) {
	{default inbox}	{ busy Inc_Inbox }
	presort		{ busy Inc_Presort }
	multidrop	{ busy Inc_All }
	presortmulti	{ busy Inc_PresortMultidrop }
	custom		{ busy Inc_Custom }
	none		{ return }
    }
}

proc Inc_PresortMultidrop {} {
    # Copy from drop boxes to folders.  Anything
    # that goes into MyIncTmp will get sorted later.
    global mhProfile
    if ![file isdirectory $mhProfile(path)/MyIncTmp] {
	file mkdir $mhProfile(path)/MyIncTmp
    }
    # Inc, but don't fiddle with scan listings
    Inc_All 0

    # Now do the Inc Presort on MyIncTmp and update scan listings
    Inc_Presort 0
}

proc Inc_Inbox {} {
    # Inc from the spool file to the inbox folder
    global exmh mhProfile ftoc inc
    if [info exists mhProfile(inbox)] {
	set inbox [string trimleft $mhProfile(inbox) +]
    } else {
	set inbox inbox
    }
    Exmh_Status "Inc ..."

    # Optionally wrap inc with an expect wrapper.

    set cmd [list exec inc +$inbox -truncate -nochangecur -width $ftoc(scanWidth)]
    set cmd [Inc_Expect $cmd]

    # Return value from 'inc' is 1 when there are no messages....
    if [catch $cmd incout] {
	Exmh_Debug Inc_Inbox $cmd: $incout
	set incout {}
    }	

    BgRPC Inc_InboxFinish $inbox $incout Flist_Done
}
proc Inc_Expect {cmd} {
    global inc exmh pop
    if {![info exist pop(password)]} {
	# No password implies no POP host
	return $cmd
    }

    # Drop the leading "exec", and splice in the -host argument

    set cmd [lrange $cmd 1 end]
    set cmd [concat [list exec inc.expect] $cmd]
    if {[lsearch -exact $cmd -host] < 0} {
	lappend cmd -host $inc(pophost)
    }
    if {[lsearch -exact $cmd -user] < 0
	&& [info exists pop($inc(pophost),login)]} {
	lappend cmd -user $pop($inc(pophost),login)
    }
    if {[lsearch -exact $cmd <<] < 0} {
	lappend cmd << $pop(password)
    }
    regsub <<.* $cmd {} clean
    Exmh_Debug Inc_Expect $clean
    
    return $cmd
}

proc Inc_InboxFinish { f incout {hook {}} } {
    global exmh mhProfile
    set msgids {}
    Scan_Iterate $incout line {
	set id [Ftoc_MsgNumberRaw $line]
	if {$id != {}} {
	    lappend msgids $id
	}
    }
    Exmh_Debug Inc_InboxFinish $f $msgids hook=$hook
    if {[llength $msgids] == 0} {
	Exmh_Status "No new messages in $f"
	return
    }
    Seq_Add $f $mhProfile(unseen-sequence) $msgids
    if {$hook != {}} {
	eval $hook
    }
    if {$exmh(folder) == $f} {
	Scan_Inc $f $incout
    } else {
	Exmh_Status "New messages in $f"
    }
}

proc Inc_Presort {{doinc 1}} {
    # Transfer from the mail spool file directly into folders
    global exmh mhProfile env inc pop
    # Use inc to copy stuff into a temp directory
    if ![file isdirectory $mhProfile(path)/MyIncTmp] {
	file mkdir $mhProfile(path)/MyIncTmp
    }
    if {$doinc} {
	set cmd [list exec inc +MyIncTmp -silent]
	set cmd [Inc_Expect $cmd]
	if {[catch $cmd err]} {
	    # Some versions of inc exit non-zero when they should not.
	    Exmh_Debug Inc_Presort +MyIncTmp: $err
	}
    }
    if [catch {set env(USER)} user] {
	if [catch {set env(LOGNAME)} user] {
	    Exmh_Status "No USER or LOGNAME envar"
	    set user ""
	}
    }
    if {[catch {lsort -dictionary [glob $mhProfile(path)/MyIncTmp/*]} files] == 0} {
	Exmh_Status "incfilter ..."
	foreach file $files {
	    if {![regexp {^[0-9]+$} [file tail $file]]} {
		Exmh_Status "Deleting stray file in MyIncTmp: [file tail $file]" warning
		File_Delete $file
		continue
	    }
	    if {$inc(presortFeedback)} {
		if [catch {exec grep -i "^Subject:" $file | head -1} \
		    subject] {
		    set subject ""
		}
	    }

	    #
	    # build up the pipe def based on the delivery agent:
	    #

	    switch $exmh(incfilter) {
		slocal {
		    set cmd [subst "$exmh(slocal) $exmh(slocalArgs)"]
		}
		procmail {
		    set cmd [subst "procmail $exmh(procmailArgs)"]
		}
		other {
		    set cmd [subst $exmh(incfilterArgs)]
		}
	    }

	    Exmh_Debug Inc_Presort: $cmd
	    set code [catch { exec sh -c "$cmd < $file 2>&1" } err]
	    if {$code} {
		# Move it out of MyIncTmp in case it really did
		# get filed somewhere.  Certain file system errors
		# (can't stat .) lead to this behavior
		Exmh_Status "$file - $err - check MyIncErrors"
		if ![file isdirectory $mhProfile(path)/MyIncErrors] {
		    file mkdir $mhProfile(path)/MyIncErrors
		}
		Mh_Refile MyIncTmp [file tail $file] MyIncErrors 
	    } else {
		#
		# print the messages we got
		#

		foreach line [split $err "\n"] {
		    Exmh_Status "incfilter: $line"
		}

		File_Delete $file
		if {$inc(presortFeedback)} {
		    if {[string length $subject] > 0} {
			regsub "^Subject: *" $subject "" subject
			Exmh_Status "[file tail $file]: $subject" warning
		    } else {
			Exmh_Status [file tail $file] warning
		    }
		}
	    }
	}
    }
    File_Delete $mhProfile(path)/MyIncTmp/$mhProfile(mh-sequences)
    catch {file delete $mhProfile(path)/MyIncTmp}

    Flist_FindSeqs		;# Needed to set new message state.
    # This after breaks a potential deadlock:
    # UI Inc button is pressed - registers outstanding Inc operation
    # PresortFinish notes new messages in the current folder and wants
    # to rescan the folder to pick up the changes.
    # The scan notes the outstanding operation and waits for it to complete.
    # Deadlock
    after 1 {BgRPC Inc_PresortFinish}
}
proc Inc_PresortFinish {} {
    global exmh ftoc mhProfile
    LOG Inc_PresortFinish
    Mh_FolderFast $exmh(folder)	;# presort inc has changed this to MyIncTmp
    if {$ftoc(displayValid) && [Seq_Count $exmh(folder) $mhProfile(unseen-sequence)] > 0} {
	Label_Folder $exmh(folder)
	Scan_Folder $exmh(folder) $ftoc(showNew)
    }
}

# The following are useful if you have lots of drop boxes
# because you use maildelivery to divert messages into dropboxes.
# This also works with POP hosts.

proc Inc_All {{updateScan 1}} {
    global exdrops exmh ftoc pop

    Exmh_Status "Checking dropboxes..." warning
    MhSetMailDrops	;# Update, if needed

    set hits {}
    foreach record [array names exdrops] {
        set fields [ scan $exdrops($record) "%s %s %s" folder dropname popname]
        Exmh_Status "dropbox... $dropname" warning
	if {[string first / $dropname] < 0} {

	    # Not a pathname, but a POP hostname

	    global pop

	    set host [lindex $dropname 0]
	    Pop_GetPassword $host
	    Exmh_Status "$popname @ $host"
	    if {$popname != ""} {
                set user $popname
		set cmd [list exec inc +$folder -host $host \
			-user $user -truncate -width $ftoc(scanWidth) \
			<< $pop(password)]
	    } else {
		set cmd [list exec inc +$folder -host $host \
			-truncate -width $ftoc(scanWidth) << $pop(password)]
	    }
	    set cmd [Inc_Expect $cmd]
	} else {
	    if { [file exists $dropname] && [file size $dropname] } {
		set cmd [list exec inc +$folder -file $dropname \
			-truncate -width $ftoc(scanWidth)]
	    } else {
		set cmd {}
	    }
	}
	if [llength $cmd] {
	    if {[catch $cmd incout] == 0} {
		lappend hits $folder
	        if $updateScan {
		    BgRPC Inc_InboxFinish $folder $incout
		}
	    } else {
		Exmh_Debug Inc_All +${folder}: $incout
	    }
	}
    }
    if {$updateScan && ([llength $hits] > 0)} {
	BgRPC Flist_Done
	Exmh_Status "New mail in: $hits"
    } else {
	Exmh_Status ""
    }
}
proc Inc_Pending {} {
    # Figure out which folders have stuff in their inbox
    global exdrops exwin
    set active {}
    foreach record [array names exdrops] {
        set fields [ scan $exdrops($record) "%s %s %s" folder dropfile popname]
	if {[file exists $dropfile] && [file size $dropfile]} {
	    lappend active $folder
	}
    }
    if [llength $active] {
	# Output the list of active folder
	Exmh_Status "Active: $active"
    } else {
	Exmh_Status "No active folders" warning
    }
    Flist_FindSeqs
}
