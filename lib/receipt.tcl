# receipt.tcl
#
# Handling of message disposition notifications 
#

# removes any disposition-notification-to header and puts a brand new one
proc MDNAskReceipt { draft t } {
    global miscRE mime env faces

    if {[info exists mime(mdnTo)] && $mime(mdnTo) != {}} {
	set mdnTo $mime(mdnTo)
    } else {
	set host [exec hostname]
	set domain $faces(defaultDomain)

	if {$domain == ""} {
	    catch {set domain [exec domainname]'}
	}
	if {$domain == ""} {
	    catch {set domain [exec grep domain /etc/resolv.conf | cut -f2 -d\ ]'}
	}
	if {$domain == ""} {
	    set domain "PLEASE CONFIGURE DISPOSITION NOTIFICATION UNDER PREFS/MIME"
	}
	set mdnTo $env(USER)@$host.$domain
    }

    SeditSave $draft $t

    set linenb 1
    set line [$t get $linenb.0 $linenb.end]

    while {![regexp $miscRE(headerend) $line]} {
	if [regexp -nocase {^disposition-notification-to:} $line] {
	    set line " dummy"
	    while {[regexp "^\[ \t]" $line]} {
		$t delete $linenb.0 [expr {$linenb + 1}].0
		set line [$t get $linenb.0 $linenb.end]
	    }
	} else {
	    set linenb [expr {$linenb + 1}]
	}
	set line [$t get $linenb.0 $linenb.end]
    }

    $t insert 1.0 "Disposition-Notification-To: $mdnTo\n"
}

proc MDNGenerate { file address choice mode } {
    global exwin mimeHdr

    if {$choice != "ignored"} {
	set mdnfile [MDNBuildDraft $file $address $choice $mode]
	if [catch {exec send -nopush $mdnfile} result] {
	  Exmh_Debug "send result: $result"
	  Exmh_Status "Could not send message disposition notification" error
	  return
	}
    }
    MDNAddHeaderToDraft $file "X-ExmhMDN: $choice"
    MsgShowInText $exwin(mtext) $mimeHdr(0,rawfile)
}


proc MDNAddHeaderToDraft { draft header } {
    if [catch {open $draft} in] {
	error "Cannot read draft to add header"
    }
    if [catch {open $draft.new w} out] {
	close $in
	error "Cannot add header"
    }
    set state header
    for {set len [gets $in line]} {! [eof $in]} {set len [gets $in line]} {
	if {$state == "header"} {
	    if {$len == 0 || [regexp ^-- $line]} {
		set state body
		puts $out $header
	    }
	}
	puts $out $line
    } 

    close $out
    close $in
    Mh_Rename $draft.new $draft
}

proc MDNAsk {tkw address explain} {
    global mimeHdr exmh

    $tkw insert insert "  The sender wants you to acknowledge that you have\
	seen this mail."
    if {[string compare $explain {}] != 0} {
	$tkw insert insert "\n\n  NOTE! For the reason(s) listed below, it may\
            be unsafe to send the disposition notification.  Please check the\
            message carefully.  Unless you are sure that it is safe to send\
            the notification, press \"Ignore silently\""
	$tkw insert insert $explain
    }

    $tkw insert insert "\n\n  Do you want to send a disposition notification\
        (receipt) to \n      $address?"
    $tkw insert insert "\n\n       "
    TextButton $tkw " Send confirmation " \
	[list MDNGenerate $mimeHdr(0,rawfile) \
	     $mimeHdr(0=1,hdr,disposition-notification-to) \
	     "displayed" "manual-action/MDN-sent-manually"]
    $tkw insert insert "    "
    TextButton $tkw " Send denial " \
	[list MDNGenerate $mimeHdr(0,rawfile) \
	     $mimeHdr(0=1,hdr,disposition-notification-to) \
	     "denied" "manual-action/MDN-sent-manually"]
    $tkw insert insert "    "
    TextButton $tkw " Ignore silently " \
	[list MDNGenerate $mimeHdr(0,rawfile) \
	$mimeHdr(0=1,hdr,disposition-notification-to) \
	     "ignored" {}]
    $tkw insert insert "\n"
    MimeInsertSeparator $tkw 0 6
}

proc MDNCheck { tkw } {
    global mimeHdr mime

    if {![info exists mimeHdr(0=1,hdr,x-exmhmdn)] && \
	    [info exists mimeHdr(0=1,hdr,disposition-notification-to)]} {
	if [info exists mime(mdnDone)] {
	    unset mime(mdnDone)
	} else {
	    set dnt $mimeHdr(0=1,hdr,disposition-notification-to)

	    switch $mime(mdnSend) {
		"never" {
		    set mdnAction1 "ignored"
		    set mdnAction2 "ignored"
		}
		"deny" {
		    set mdnAction1 "denied"
		    set mdnAction2 "ignored"
		}
		"ask user" {
		    set mdnAction1 "ask"
		    set mdnAction2 "ask"
		}
		"auto/ask" {
		    set mdnAction1 "displayed"
		    set mdnAction2 "ask"
		}
		"auto/ignore" {
		    set mdnAction1 "displayed"
		    set mdnAction2 "ignored"
		}
		default {
		    set mdnAction1 "ask"
		    set mdnAction2 "ask"
		}
	    }

	    set mdnExplain {}
	    
	    set line [string trim $dnt]
	    if [regsub {\(.*\)} $line {} newline] {
		set line $newline
	    }

	    if {[string first "|" $line] != -1} {
		set mdnAction1 "ignore"
		set mdnExplain "$mdnExplain 

 * The address(es) for the disposition notification contains a pipe symbol (|)
   *** THIS MAY BE A SERIOUS SECURITY HOLE."
	    }

	    if {[string first "," $line] != -1} {
		set mdnAction1 $mdnAction2
		set mdnExplain "$mdnExplain 

 * The sender appears to have requested a disposition notification to be
   sent to more than one address.  If you are not sure that there is a valid
   reason to send disposition notifications to each of these addresses,
   the request should be ignored and no disposition notifications sent."
	    }

	    if [info exists mimeHdr(0=1,hdr,return-path)] {
		if {[string compare \
			 [MsgParseFrom $mimeHdr(0=1,hdr,return-path) {}] \
			 [MsgParseFrom $line {}]] != 0} {
		    set mdnAction1 $mdnAction2
		    set mdnExplain "$mdnExplain

 * The disposition notification appears to be directed somewhere else than
   to the sender of the message.  If you are not sure that there is a valid
   reason for this, the request should be ignored and no disposition
   notifications sent."
		}
	    } else {
		set mdnAction1 $mdnAction2
		set mdnExplain "$mdnExplain

 * The message does not have a Return-path header field, and therefore it
   is not possible to verify that the disposition notification address(es)
   is valid."
	    }

	    if [info exists mimeHdr(0=1,hdr,disposition-notification-options)]\
	    {
		set mdnAction1 $mdnAction2
		set mdnExplain "$mdnExplain

 * The message has a Disposition-notification-options header requesting
   some special processing which exmh does not know about."
		if [regexp -nocase {=[ ]*required[ ]*,} \
			$mimeHdr(0=1,hdr,disposition-notification-options)] {
		    set mdnAction1 "ignored"
		    set mdnExplain "$mdnExplain

   Since one or more of the unknown options are required to be taken into
   account for generating a proper disposition notification, no disposition
   notification at all should be generated."
		}
	    }

	    if {[string compare $mdnAction1 "ask"] == 0} {
		MDNAsk $tkw $dnt $mdnExplain
	    } else {
		MDNGenerate $mimeHdr(0,rawfile) $dnt $mdnAction1 \
		    "manual-action/MDN-sent-automatically"
	    }
	}
    }
}

proc MDNExplainDisposition { tkw reportVar } {
    upvar $reportVar report

    set disp $report(disposition)

    $tkw insert insert "The disposition code is:
    $disp
which means:
"

    if [regsub -all {(\(.*\))|([ 	]+)} $disp {} newline] {
	set disp $newline
    }
    set disp [string tolower $disp]

    if [regexp {^([-a-z]+)/([-a-z]+);([-a-z]+)(/(.*))?$} $disp match \
	    action_mode sending_mode disp_type match2 disp_modifiers] {

	switch $action_mode {
	    "manual-action" {
		$tkw insert insert "
    The recipient acted manually on the message:\n"
	    }
	    "automatic-action" {
		$tkw insert insert "
    The recipient's computer system has been set up to act automatically
    on incoming messages:\n"
	    }
	    default {
		$tkw insert insert "
    Unable to tell whether the message was acted on manually or automatically.
    The code describing the action is:  $action_mode,
    which is not a valid code.\n"
	    }
	}

	switch $disp_type {
	    "displayed" {
		$tkw insert insert "
        The mail was displayed by the user agent to someone reading the
        recipient's mailbox.  (This does not guarantee that it is read
        or understood.)"
	    }
	    "denied" {
		$tkw insert insert "
        The recipient does not wish you to be informed of the message's
        disposition."
	    }
	    "dispatched" {
		$tkw insert insert "
        The mail has been sent somewhere (e.g. printed, faxed, forwarded)
        without being displayed to the user.  (The user may or may not see
        the message later.)"
            }
	    "processed" {
		$tkw insert insert "
        The message has been processed in some manner (i.e. by some sort of
        rules or server) without being displayed to the user.  (The user may
        or may not see the message later, or there may not even be a human
        user associated with the mailbox.)"
            }
            "failed" {
		$tkw insert insert "
        A failure occurred that prevented the proper generation of an MDN."
		if [info exists report(failure)] {
		    $tkw insert insert "

        The reason for the failure was:
             $report(failure)"
		}
            }
	    "deleted" {
		$tkw insert insert "
        The message has been deleted.  (The recipient may or may not have
        seen the message.  The recipient might \"undelete\" the message at a
        later time and read the message.)"
    	    }
            default {
		$tkw insert insert "
        Unknown disposition type $disp_type."
   	    }
        }

	while {[string length $disp_modifiers] > 0} {
	    set sep [string first "," $disp_modifiers]
	    if { $sep < 0 } {
		set modifier $disp_modifiers
		set disp_modifiers ""
	    } else {
		set modifier \
		    [string range $disp_modifiers 0 [expr $sep - 1]]
		set disp_modifiers \
		    [string range $disp_modifiers \
			 [expr $sep + 1] \
			 [string length $disp_modifiers]]
	    }
	    switch $modifier {
		"error" {
		    $tkw insert insert "

        An error of some sort occurred that prevented successful processing of
	the message.  "  
		    if [info exists report(error)] {
			$tkw insert insert "Error message:
            $report(error)"
		    } else {
			$tkw inser insert "(No error message given)"
		    }
		}
		"warning" {
		    $tkw insert insert "

        The message was successfully processed but some sort of exceptional
        condition occurred.  "
		    if [info exists report(warning)] {
			$tkw insert insert "Warning message:
            $report(warning)"
		    } else {
			$tkw inser insert "(No warning message given)"
		    }
		}
		"superseded" {
		    $tkw insert insert "

        The message has been automatically rendered obsolete by another 
        message received.  (The recipient may still access and read the
        message later.)"
		}
		"expired" {
		    $tkw insert insert "

        The message has reached its expiration date and has been automatically
        removed from the recipient's mailbox."
		}
		"mailbox-terminated" {
		    $tkw insert insert "

        The recipient's mailbox has been terminated and all messages in it 
        automatically removed."
		}
		default {
		}
	    }
	}

	switch $sending_mode {
	    "mdn-sent-manually" {
		$tkw insert insert "

    The recipient manually sent (or confirmed that the user agent could send)
    this MDN."
	    }
	    "mdn-sent-automatically" {
		$tkw insert insert "    \

    This MDN was generated automatically (with no explicit manual 
    confirmation by the recipient)."
	    }
	    default {
		$tkw insert insert "

    The way the MDN was sent is described as: $sending_mode
    (which is not a valid code)."
	    }
	}
    } else {
	switch $disp {
	    "displayed" {
		$tkw insert insert "
    The mail was displayed by the user agent to someone reading the 
    recipient's mailbox.  This does not guarantee that it is read or
    understood."
	    }
	    "denied" {
		$tkw insert insert "
    The recipient does not wish you to be informed of the message's 
    disposition."
	    }
	    "processed" {
		$tkw insert insert "
    The message has been processed in some manner (e.g. printed, faxed,
    forwarded) in response to a user command, without being displayed to the
    user.  The user may or may not see the message later."
	    }
	    "autoprocessed" {
		$tkw insert insert "
    The message has been processed automatically in some manner (e.g. printed,
    faxed, forwarded, gatewayed) in response to some user request made in
    advance, without being displayed to the user.  The user may or may not 
    see the message later."
	    }
	    "deleted" {
		$tkw insert insert "
    The message has manually been deleted.  The recipient may or may not have
    seen the message."
	    }
	    "autodeleded" {
		$tkw insert insert "
    The message has been automatically deleted without being displayed to the
    recipient."
	    }
	    "obsoleted" {
		$tkw insert insert "
    The message has been automatically rendered obsolete by another message
    received.  The recipient may still access and read the message later."
	    }
	    "terminated" {
		$tkw insert insert "
    The recipient's mailbox has been terminated and all messages in it
    automatically deleted."
	    }
	    "autodenied" {
		$tkw insert insert "
    The recipient does not wish the sender to be informed of the message's
    disposition, and has requested that this MDN be sent automatically."
	    }
	    default {
		$tkw insert insert "
    The format of the disposition code is not recognized, 
    cannot explain it further."
  	}
      }
    }
    $tkw insert insert "\n\n"
}

proc MDNBuildDraft { draft address doit choice} {
    global env mimeHdr faces exmh
    set host [exec hostname]

    # If /bin/hostname has a '.' in it, assume it's already a FQDN.
    if [ regexp {\.} $host ] {
        set sourcehost $host
    } else { #otherwise, try to find a domain from $faces or resolv.conf
        set domain $faces(defaultDomain)
        if {$domain == ""} {
	    catch {set domain [exec grep domain /etc/resolv.conf | cut -f2 -d\ ]'}
        }
	# Try this last, as YP domainname may not match actual DNS domain
	if {$domain == ""} {
	    catch {set domain [exec domainname]}
	}
        set sourcehost $host.$domain
    }
    set rcpt $env(USER)@$sourcehost

    if [catch {open $draft} in] {
	error "Cannot read original message"
    }
    set mdn [Mime_TempFile mdn]
    if [catch {open $mdn w} out] {
	close $in
	error "Cannot create mdn"
    }
    # Bug - someplace right here, we need to make 'post' generate
    # a 'MAIL FROM:<>' to be fully RFC compliant.,..
    puts $out "Subject: Disposition notification\nTo: $address"

    set bdry [FvMimeStartMulti $out \
	"multipart/report; report-type=disposition-notification" 0]

    FvMimeAddPart $out $bdry ""

    if {$doit == "displayed"} {
	puts $out "
The message below has been displayed to $rcpt.
This is no guarantee that it has been read or understood.
"
    } else {
	puts $out "
The recipient of the message below did not wish the sender to be informed
of the message's disposition.
"
    }
    FvMimeAddPart $out $bdry "message/disposition-notification"
    puts $out "\nReporting-UA: $sourcehost (Exmh $exmh(version))"
    if [info exists mimeHdr(0=1,hdr,original-recipient)] {
	puts $out "Original-Recipient: $mimeHdr(0=1,hdr,original-recipient)"
    }
    puts $out "Final-Recipient: rfc822; $rcpt"
    if [info exists mimeHdr(0=1,hdr,message-id)] {
	puts $out "Original-Message-ID: $mimeHdr(0=1,hdr,message-id)"
    }
    puts $out "Disposition: $choice; $doit\n"

    FvMimeAddPart $out $bdry "message/rfc822\n"

    for {gets $in line} {! [eof $in]} {gets $in line} {
	puts $out $line
    } 
    puts $out "--$bdry--"
    close $out
    close $in
    return $mdn
}

proc ExtractAddress { string } {
    if {[scan $string "%\[^<]%c%\[^>]" * * address] != 3} {
	return $string
    }
    return $address
}


#I use these procedures, which should become part of seditMime.tcl
#but are still part of something I use on the side -Brent

proc FvMimeStartMulti {out contentType level} {
    set boundary [SeditBoundary $out $level]
    puts $out "Mime-Version: 1.0"
    puts $out "Content-Type: $contentType;\n\tboundary=\"$boundary\""
    puts $out "\nMultipart\n"
    return $boundary
}
proc FvMimeAddPart {out boundary contentType} {
    puts $out "--$boundary"
    if {$contentType != ""} {
	puts $out "Content-Type: $contentType"
    } else {
	puts $out ""
    }
}
proc FvMimeEndMulti {out boundary} {
    puts $out "--$boundary--"
}
