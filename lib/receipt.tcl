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

proc MDNGenerate { file address choice } {
    global exwin mimeHdr

    if {$choice != "ignored"} {
	set mdnfile [MDNBuildDraft $file $address $choice]
	exec send -nopush $mdnfile
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

proc MDNAsk {tkw address} {
    global mimeHdr exmh

    $tkw insert insert "  The sender wants you to acknowledge that you have \
	seen this mail.  Do you want to send a receipt to $address?\n"
    $tkw insert insert "       "
    TextButton $tkw "Confirm now" \
	[list MDNGenerate $mimeHdr(0,rawfile) \
	$mimeHdr(0=1,hdr,disposition-notification-to) "displayed"]
    $tkw insert insert "    "
    TextButton $tkw "Send denial" \
	[list MDNGenerate $mimeHdr(0,rawfile) \
	$mimeHdr(0=1,hdr,disposition-notification-to) "denied"]
    $tkw insert insert "    "
    TextButton $tkw "Ignore silently" \
	[list MDNGenerate $mimeHdr(0,rawfile) \
	$mimeHdr(0=1,hdr,disposition-notification-to) "ignored"]
    $tkw insert insert "\n"
    MimeInsertSeparator $tkw 0 6
}

proc MDNReportDialog { tkw from date disp parts } {
    if {$parts == 2} {
	$tkw insert insert "This mail contains a message disposition \
		notification, regarding the message to $from.\n\n"
    } else {
	$tkw insert insert "This mail contains a message disposition \
		notification, regarding the message to $from on $date.\n\n"
    }
    switch [string tolower $disp] {
	"displayed" {
	    set jtext \
"The mail was displayed by the user agent to someone reading the recipient's \
mailbox.  This does not guarantee that it is read or understood."
	}
	"denied" {
	    set jtext \
"The recipient does not wish you to be informed of the message's disposition."
	}
	"processed" {
	    set jtext \
"The message has been processed in some manner (e.g. printed, faxed, \
forwarded) in response to a user command, without being displayed to the \
user.  The user may or may not see the message later."
	}
	"autoprocessed" {
	    set jtext \
"The message has been processed automatically in some manner (e.g. printed, \
faxed, forwarded, gatewayed) in response to some user request made in \
advance, without being displayed to the user.  The user may or may not see the \
message later."
	}
	"deleted" {
	    set jtext \
"The message has manually been deleted.  The recipient may or may not have \
seen the message."
	}
	"autodeleded" {
	    set jtext \
"The message has been automatically deleted without being displayed to the \
recipient."
	}
	"obsoleted" {
	    set jtext \
"The message has been automatically rendered obsolete by another message \
received.  The recipient may still access and read the message later."
	}
	"terminated" {
	    set jtext \
"The recipient's mailbox has been terminated and all messagess in it \
automatically deleted."
	}
	"autodenied" {
	    set jtext \
"The recipient does not wish the sender to be informed of the message's \
disposition, and has requested that this MDN be sent automatically."
	}
	default {
	    set jtext "The reciept type is $disp."
	}
    }
    $tkw insert insert $jtext\n\n
    if {$parts != 2} {
	$tkw insert insert "       "
	TextButton $tkw "View requesting message" \
		[list MDNShowAction $tkw msgonly]
    }
    $tkw insert insert "    "
    TextButton $tkw "View raw report" \
	[list MDNShowAction $tkw whole]
    $tkw insert insert "\n\n"
}

proc MDNShowAction { tkw mode } {
    global exwin mimeHdr mime
    set part "0=1"

    set mime(mdnDone) 1
    if {$mode == "whole"} {
	MsgShowInText $exwin(mtext) $mimeHdr(0,rawfile)
    } else {
	MsgShowInText $exwin(mtext) $mimeHdr($part=3,file)
    }
}

proc MDNBuildDraft { draft address doit } {
    global env mimeHdr faces exmh
    set host [exec hostname]

    set domain $faces(defaultDomain)
    if {$domain == ""} {
	catch {set domain [exec grep domain /etc/resolv.conf | cut -f2 -d\ ]'}
    }
    set rcpt $env(USER)@$host.$domain

    if [catch {open $draft} in] {
	error "Cannot read original message"
    }
    set mdn [Mime_TempFile mdn]
    if [catch {open $mdn w} out] {
	close $in
	error "Cannot create mdn"
    }
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
    puts $out "\nReporting-UA: $host.$domain (Exmh $exmh(version))"
    if [info exists mimeHdr(0=1,hdr,original-recipient)] {
	puts $out "Original-Recipient: $mimeHdr(0=1,hdr,original-recipient)"
    }
    puts $out "Final-Recipient: $rcpt"
    if [info exists mimeHdr(0=1,hdr,message-id)] {
	puts $out "Original-Message-ID: $mimeHdr(0=1,hdr,message-id)"
    }
    puts $out "Disposition: $doit"

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
