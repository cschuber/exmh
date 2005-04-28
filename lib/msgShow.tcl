# msgShow.tcl
#
# Message display.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

set msg(maxsize) 50000

# This procedure allocates text tags used in message display.
# This is done once to avoid the cost of doing it on every message.
# Tag creation order is important - later tags have higher priority and
# appear "on top" of tags created earlier.

proc Msg_Setup { t } {
    global fdisp exmh
    foreach level {error warn normal background} {
	$t tag configure hdrlook=exmhColor$level -background $exmh(c_st_$level)
    }
    $t tag configure hdrlook=exmhColorPopup -background $fdisp(c_popup)
    # Tags for header looks
    global msg
    foreach tagname $msg(tagnames) {
	# Set up looks for different header lines
	set rval [option get . m_$tagname {}]
	if {$rval != {}} {
	    set msg(tag,$tagname) $rval
	    if [catch {
		eval {$t tag configure hdrlook=$tagname} $rval
	    } err] {
		unset msg(tag,$tagname)
	    }
	}
    }
    # More tags to pre-allocate darker mime backgrounds.
    if {[winfo depth .] > 4} {
	set color default
	foreach level {1 2 3 4 5 6} {
	    set color [MimeDarkerColor $t $color]
	    $t tag configure hdrlook=exmhColor$level -background $color
	}
    }

    # Create the part tags first so the highlight tags are higher priority

    set part 0
    set defaultTag [MimeLabel $part=1 part]
    $t tag configure $defaultTag -background [$t cget -background] \
	-foreground [$t cget -foreground]

    # Allocate active button colors, too
    TextButton_Init $t

    # Tags for text highlighting
    Msg_HighlightInit $t
        
    $t tag raise sel

    # HACK To cache font for graphics part separator.
    catch {
	label $t.fontlabel6 -font -*-*-*-*-*-*-6-*-*-*-*-*-iso8859-*
	label $t.fontlabel8 -font -*-*-*-*-*-*-8-*-*-*-*-*-iso8859-*
    }

}

proc Msg_HighlightInit { t } {
    foreach tagname {attrib_me quote_me attrib1 attrib2 attrib3 attrib4 \
			 attrib5 quote1 quote2 quote3 quote4 quote5 signature \
			 listsig msheader1 msheader2 udiffold udiffnew \
			 bugrpttok spamass embolded} {
        set rval [option get . b_$tagname {}]
        eval {$t tag configure $tagname} $rval
    }
}

proc Msg_Redisplay { draft } {
    global msg mhProfile exmh msg
    if {[string compare $draft $msg(path)] == 0} {
	set msg(dpy) {}
	MsgShow $msg(id)
    }
}


proc MsgShow { msgid } {
    # Display the current message in a text widget
    global msg exwin exmh mhProfile mimeHdr mime

    Exwin_SeeToplevelMsg
    if {$msg(dpy) == $msgid} {
	return
    }
    Html_Stop $exwin(mtext)
    Label_Message $exmh(folder):$msgid
    Audit "Show $exmh(folder) $msgid"
    if [MsgShowInText $exwin(mtext) $mhProfile(path)/$exmh(folder)/$msgid] {
	MsgSeen $msgid
	if {!$mime(stop)} {
	    set msg(dpy) $msgid
	}
	set msg(curclear) 0
	set mime(stop) 0
	update idletasks	;# Faces display can be slow

	Face_Show [MsgParseFrom $mimeHdr(0=1,hdr,from)] $mimeHdr(0=1,hdr,x-face) $mimeHdr(0=1,hdr,x-image-url) $mimeHdr(0=1,hdr,newsgroups)

	foreach cmd [info commands Hook_MsgShow*] {
	    $cmd $mhProfile(path)/$exmh(folder)/$msgid mimeHdr
	}
	Find_Reset
    }
}
proc MsgShowInText { win file } {
    global mhProfile msg mimeHdr exmh msg mhProfile mime
    $win configure -state normal
    $win delete 0.0 end
    $win mark set insert 1.0

    if [info exists mhProfile(exmhshowproc)] {
	Exmh_Debug MsgShowInText $mhProfile(exmhshowproc) $file
	set fileName [concat "|" $mhProfile(exmhshowproc) $file]
    } else {
	set fileName $file
    }
    Mime_Cleanup $win	;# tmp files from last message.
    set part 0
    set subpart 1

    set mimeHdr($part=$subpart,hdr,cur) {}
    set mimeHdr($part=$subpart,hdr,from) {}
    set mimeHdr($part=$subpart,hdr,date) {}
    set mimeHdr($part=$subpart,hdr,subject) {}
    set mimeHdr($part=$subpart,hdr,x-face) {}
    set mimeHdr($part=$subpart,hdr,x-image-url) {}
    set mimeHdr($part=$subpart,hdr,newsgroups) {}
    set mimeHdr($part=$subpart,fullHeaders) $mime(fullHeaders)
    set mimeHdr($part=$subpart,yview) 1.0

    set mimeHdr($part,decode) 1
    set mimeHdr($part,file) $fileName
    set mimeHdr($part,rawfile) $file
    set mimeHdr($part,color) [lindex [$win configure -background] 4]
    set mimeHdr($part,type) message/rfc822
    set mimeHdr($part,encoding) 7bit
    set mimeHdr($part,hdr,content-type) message/rfc822
    set mimeHdr($part,HeaderSize) 0
    set mimeHdr($part,display) 1

    global mimeFont mime
    if ![info exists mimeFont(default)] {
	set mimeFont(title) [Mime_GetFont $win bold r title $mime(titleSize) us-ascii]
	set mimeFont(note) [Mime_GetFont $win medium i title $mime(noteSize) us-ascii]
	set mimeFont(default) [Mime_GetFont $win medium r plain $mime(fontSize) us-ascii]

    }

    set partTag [MimeLabel $part part]
    set defaultTag [MimeLabel $part=1 part]
    $win tag configure $defaultTag -background [$win cget -background] \
	-foreground [$win cget -foreground]
    MimeSetPartVars desc displayedPart $win $part $partTag
    if {$mimeHdr($part,numParts) > 0} {
	$win config -cursor watch
	MimeSetStdMenuItems $win $part
	Mime_ShowRfc822 $win $part
    }
    $win config -cursor [option get $win cursor Text ]
    MimeInsertSeparator $win $part 6
    Widget_TextPad $win $mimeHdr(0=1,yview)
    $win yview $mimeHdr(0=1,yview)

    catch {unset mimeLastPoint}
    catch {unset mimeTagStack}

    Exmh_Status "$desc"

    $win configure -state disabled
    return 1
}

proc MsgParseFrom { fromline {setaddr setaddr} } {
    set line [string trim $fromline]
    if [regsub {\(.*\)} $line {} newline] {
	set line $newline
    }
    if [regexp {<.*@.*>} $line token] {
	set token [string trim $token <>]
    } elseif [regexp {[^ 	"]*@[^ 	"]*} $line token] {
	set token [string trim $token <>]
    } else {
	if [regexp {<.*>} $line token] {
	    set token [string trim $token <>]
	} else {
	    if [catch {lindex $line 0} token] {
		set token {}
		Exmh_Debug MsgParseFrom failed on: $fromline
	    }
	}
    }
    if {[string compare $setaddr "setaddr"] == 0} {
	# Link to alias interface
	global address
	set address $token
    }
    return $token
}

proc Hook_MsgShowListHeaders {msgPath headervar} {
    upvar $headervar header

    global exwin
    
    # From rfc2369:
  
    # The contents of the list header fields mostly consist of angle-
    # bracket ('<', '>') enclosed URLs, with internal whitespace being
    # ignored. MTAs MUST NOT insert whitespace within the brackets, but
    # client applications should treat any whitespace, that might be
    # inserted by poorly behaved MTAs, as characters to ignore.
    #
    # A list of multiple, alternate, URLs MAY be specified by a comma-
    # separated list of angle-bracket enclosed URLs. The URLs have order of
    # preference from left to right. The client application should use the
    # left most protocol that it supports, or knows how to access by a
    # separate application. 
    #
    # [...]
    #
    # To allow for future extension, client applications MUST follow the
    # following guidelines for handling the contents of the header fields
    # described in this document:
    #
    # 1) Except where noted for specific fields, if the content of the
    #    field (following any leading whitespace, including comments)
    #    begins with any character other than the opening angle bracket
    #    '<', the field SHOULD be ignored.
    #
    # 2) Any characters following an angle bracket enclosed URL SHOULD be
    #    ignored, unless a comma is the first non-whitespace/comment
    #    character after the closing angle bracket.
    #
    # 3) If a sub-item (comma-separated item) within the field is not an
    #    angle-bracket enclosed URL, the remainder of the field (the
    #    current, and all subsequent, sub-items) SHOULD be ignored.

    # Loop through the list- headers
    set menuitems {}
    foreach index [array names header 0=1,hdr,list-*] {
	# Get the suffix portion of the header name
	regsub {^.*,list-} $index {} name
	# Remove comments
	regsub -all {\([^()]*\)} $header($index) {} h
	# Remove whitespace
	regsub -all "\[ \n\t\]" $h {} h
	# Loop through the fields
	foreach f [split $h ,] {
	    # Stricture #1
	    if {[string index $f 0] == "<"} {
		# Stricture #2
		regexp "<(.*)>" $f match url
		regexp {^([^:]*)} $url match proto
		lappend menuitems $name $proto $url
	    } else {
		# Stricture #3
		break
	    }
	}
    }
    if {$menuitems != {}} {
	if [winfo exists $exwin(mopButtons).list] {
	    set menu $exwin(mopButtons).list.m
	} else {
	    set menu [Widget_AddMenuB $exwin(mopButtons) list "List..." {right padx 1 filly}]
	}
	$exwin(mopButtons).list.m delete 1 99
	foreach {name proto url} $menuitems {
	    Widget_AddMenuItem $menu "$name ($proto)" [list URI_StartViewer $url]
	}
    } else {
	catch {destroy $exwin(mopButtons).list}
    }
}

# Highlight text/plain regions of the message

proc Msg_TextHighlight {tkw start end} {
    Exmh_Debug Msg_TextHighlight $start $end
    foreach cmd [info commands Hook_MsgHighlight*] {
	$cmd $tkw $start $end
    }
}

# The original version of this file can always be found here:
#
#   ftp://ftp.kanga.nu/pub/users/claw/dot/tk/exmh/quote-colour.tcl
#
#
# Please send patches and bug reports to claw@kanga.nu and/or the
# exmh-users list at exmh-users@redhat.com
#
# A working set of surrounding configuration files can be found here:
# 
#   ftp://ftp.kanga.nu/pub/users/claw/dot/tk/
#   ftp://ftp.kanga.nu/pub/users/claw/dot/exmh
#
# Screenshots of the quote colourising code in action can be found
# here:
#
#   ftp://ftp.kanga.nu/pub/users/claw/screenshots/exmh/JCL.exmh.9.png
#   ftp://ftp.kanga.nu/pub/users/claw/screenshots/exmh/JCL.exmh.10.png
#   ftp://ftp.kanga.nu/pub/users/claw/screenshots/exmh/JCL.exmh.11.png

# Enable this with the "Highlight Message Quotes" under Mime preferences

# Contributors to the quote colouring code:
#
#   Anthony DeStefano <destefan@vaxcave.com>
#   J C Lawrence <claw@kanga.nu>
#   John Beck <jbeck@eng.sun.com>
#   John Klassa <klassa@ipass.net>
#   Joseph V Moss <jmoss@ichips.intel.com>
#   Iain MacDonnell <Iain.MacDonnell@Sun.COM>
#    
# Changelog:
#   Tue, 05 Jun 2001 23:25:38 -0700
#     Initial request to exmh-users list for quote colouring code
#     by J C Lawrence 
#   Thu, 21 Jun 2001 10:08:11 -0400
#     John Klasse posted his quote colouring code
#   Thu, 21 Jun 2001 23:58:17 -0700
#     J C Lawrence extended with support for multi-level quotes, MS
#     Outlook quoe headers, forwarded message headers, Mailman
#     footers, .signatures, etc
#   Mon, 25 Jun 2001 16:58:03 -0700 
#     John Beck did various clean ups, polishing etc
#   Mon, 25 Jun 2001 17:52:15 -0700 
#     Iain MacDonnell cleaned up and rewrote the cite handling, and 
#     added the seperate quote function and exported the configs to
#     exmh-defaults-colour
#
#     Iain MacDonnell re-worked the quote recognition part to
#     recognise various "quote things", such as ">", ":", "}", "+>" 
#     and "Iain>"
#
#     Joseph V Moss fixed above to work with older versions of tcl 
#     that don't support "fancy" regexps
#
#     John Beck added support for colour definitions as config options
#     rather than being hard-coded.
#   Tue, 26 Jun 2001 19:32:22 -0400 
#     Anthony DeStefano added documentation
#  

# To configure/customuise, add the following resources to
# ~/.exmh/exmh-defaults-colour, edited as per your colour
# preferences.  The following colours are intended for a black
# background.
#
# --<cut>--
#
# ! Colours to use for quotes of your text if emabled below.
# *b_attrib_me: -foreground magenta
# *b_quote_me:  -foreground purple
#
# ! Colours for the quote prefixes for different levels of quote
# *b_attrib1:   -foreground palegreen
# *b_attrib2:   -foreground lawngreen
# *b_attrib3:   -foreground limegreen
# *b_attrib4:   -foreground seagreen3
# *b_attrib5:   -foreground seagreen4
#
# ! Colours for the quoted text for different levesl of quote
# *b_quote1:    -foreground khaki
# *b_quote2:    -foreground tan
# *b_quote3:    -foreground darksalmon
# *b_quote4:    -foreground goldenrod
# *b_quote5:    -foreground gold
# 
# ! Colour of .signature blocks
# *b_signature: -foreground gold
# 
# ! Colour of Mailman list footers.
# *b_listsig:   -foreground cornflowerblue
#
# ! Colour of MS Outlook quoted header field names
# *b_msheader1: -foreground lightslateblue
#
# ! Colour of MS Outlook quoted header filed contents
# *b_msheader2: -foreground seagreen2
#
# ! Unified diff colours
# *b_udiffold:  -foreground red
# *b_udiffnew:  -foreground blue
#
# ! Sun bug report colours
# *b_bugrpttok: -foreground yellow

# This hook is called on a range of text that is a message body.

proc Hook_MsgHighlight_jcl-beautify {t {start 1.0} {end end}} {
    global mime

    if {!$mime(highlightText)} {
	return
    }
    $t tag remove attrib $start $end
    $t tag remove quote  $start $end
#    $t tag remove body   $start $end


    set in_signature 0
    set in_msheader 0
    set in_listsig 0
    set in_udiff 0
    set in_spamass 0

    set endx [$t index end]
    for {set idx [expr int($start)]} {$idx <= $endx} {incr idx} {
	set txt [$t get $idx.0 $idx.end]
	
	if {$txt == ""} {
	    set in_listsig 0
	    set in_msheader 0
	    set in_signature 0
	    set in_udiff 0
	    set in_spamass 0
	} 

	if {[regexp {^---------+$} $txt] || [regexp {^______+$} $txt]} {
	    set in_listsig 1
	    set in_msheader 0
	    set in_signature 0
	    set in_udiff 0
	    set in_spamass 0
	} 

	if {[regexp {^--* *Original Message *--*$} $txt] 
	    || [regexp {^[-]+ (Begin )?Forwarded Message *-*$} $txt]
	    || [regexp {^[-]+ *End of Forwarded Message *$} $txt]} {
	    set in_listsig 0
	    set in_msheader 1
	    set in_signature 0
	    set in_udiff 0
	    set in_spamass 0
	}

	if {[regexp {^-- ?$} $txt]} {
	    set in_listsig 0
	    set in_msheader 0
	    set in_signature 1
	    set in_udiff 0
	    set in_spamass 0
	} 

	if {[regexp {^@@.*@@$} $txt]} {
	    set in_listsig 0
	    set in_msheader 0
	    set in_signature 0
	    set in_udiff 1
	    set in_spamass 0
	} 

	if {[regexp {^ pts rule name              description$} $txt]} {
	    set in_listsig 0
	    set in_msheader 0
	    set in_signature 0
	    set in_udiff 0
	    set in_spamass 1
	}

	if {$in_udiff == 1} {
	    if {[regexp {^-} $txt d line]} {
		$t tag add udiffold $idx.0 $idx.end
	    } elseif {[regexp {^\+} $txt d line]} {
		$t tag add udiffnew $idx.0 $idx.end
	    } else {
#		$t tag add body $idx.0 $idx.end
	    }
	    continue
	}

	if {$in_msheader == 1 } {
            if {[regexp {^([^:]*:)} $txt d header]} {
		$t tag add msheader1 $idx.0 $idx.[expr [string length $header] - 1]
		$t tag add msheader2 $idx.[expr [string length $header] - 1] $idx.end
	    } else {
		$t tag add msheader2 $idx.0 $idx.end
	    }
	    continue
	} 

	if {[regexp {\*.+\*} $txt bolded]} {
	    if {[regexp {^[^*]*\*} $txt beforefirststar]} {
		set firstlen [expr [string length $beforefirststar]]
		set endpos [expr $firstlen + [string length $bolded] - 2]
		$t tag add embolded $idx.[expr $firstlen] $idx.[expr $endpos]
		$t tag raise embolded
	    }
	}

# Enable this block if you can recognise quotes of your (written by
# you) text.  This will then attempt to coloruise that text using
# the attrib_me and quote_me colour pair.

# Note: You'll have to edit the regexp lines to fit/match your
# quotes.

#	if {[regexp {^(\+>)} $txt d quote] 
#	    || [regexp {^(John>)} $txt d quote] 
#	    || [regexp {^(JBeck>)} $txt d quote]} {
#	    $t tag add attrib_me $idx.0 $idx.[string length $quote]
#	    $t tag add quote_me  $idx.[string length $quote] $idx.end
#	    continue
#	}

	lassign {qt_cnt qt_str} [MsgHighlightQuoteLevel $txt]
	if {$qt_cnt >= 5} {
	    set qt_cnt 5
	}

        if {$qt_cnt > 0} {
            $t tag add attrib$qt_cnt $idx.0 $idx.[string length $qt_str]
            $t tag add quote$qt_cnt $idx.[string length $qt_str] $idx.end
        }

	if {$in_listsig == 1} {
	    $t tag add listsig $idx.0 $idx.end
	    continue
	}
	
	if {$in_signature == 1} {
	    $t tag add signature $idx.0 $idx.end
	    continue
	}

	if {$in_spamass == 1} {
	    $t tag add spamass $idx.0 $idx.end
	    continue
	}

#	$t tag add body $idx.0 $idx.end
    }
}

# The bug reporting highlighting is done on the whole message
# because it must scan headers

proc Hook_MsgShow_BugReport {msg mimeHdr} {
   global exwin mime
    if {!$mime(highlightText)} {
	return
    }
   $exwin(mtext) configure -state normal
   MsgShow_BeautifyBugrpt $exwin(mtext)
   $exwin(mtext) configure -state disabled
}
proc MsgShow_BeautifyBugrpt {t {start 1.0} {end end}} {

    set in_bugrpt 0
    set in_header 1

    set endx [$t index end]
    for {set idx [expr int($start)]} {$idx <= $endx} {incr idx} {
	set txt [$t get $idx.0 $idx.end]
	
	if {$txt == "" && $in_header} {
	    # End of headers
	    set in_header 0
	    if {$in_bugrpt == 0} {
		return
	    }
	} 

	if {[regexp {^Subject: BugId [0-9].* Has been Updated .*$} $txt] ||\
	    [regexp {^Subject: BugId [0-9].* Priority value ch.*$} $txt] ||\
	    [regexp {^Subject: BugId [0-9].* New .* Created, .*$}  $txt] ||\
	    [regexp {^Subject: BugId [0-9].* Responsible .*er$}    $txt] ||\
	    [regexp {^Subject: CR [0-9].* responsible .*er}        $txt] ||\
	    [regexp {^Subject: CR [0-9].* Updated .*$}             $txt] ||\
	    [regexp {^Subject: CR [0-9].* Created .*$}             $txt] ||\
	    [regexp {^Subject: CR [0-9].* Redispatched .*$}        $txt] ||\
	    [regexp {^Subject: CR [0-9].* Has been .*$}            $txt]} {
	    set in_bugrpt 1
	}
	if {$in_bugrpt == 1} {
	    if {[regexp {^ ?\*?Synopsis\*?:} $txt d line]} {
		$t tag add bugrpttok $idx.0 $idx.end
	    } elseif {[regexp {^  ?\*?Description\*?:} $txt d line]} {
		$t tag add bugrpttok $idx.1 $idx.end
	    } elseif {[regexp {^  ?\*?Justification\*?:} $txt d line]} {
		$t tag add bugrpttok $idx.1 $idx.end
	    } elseif {[regexp {^  ?\*?Work ?around\*?:} $txt d line]} {
		$t tag add bugrpttok $idx.1 $idx.end
	    } elseif {[regexp {^  ?\*?Suggested [Ff]ix\*?:} $txt d line]} {
		$t tag add bugrpttok $idx.1 $idx.end
	    } elseif {[regexp {^(	|  )\*?Evaluation\*?:} $txt d line]} {
		$t tag add bugrpttok $idx.1 $idx.end
	    } elseif {[regexp {^ Interest list:} $txt d line]} {
		$t tag add bugrpttok $idx.1 $idx.15
	    } elseif {[regexp {^  \*?Interest List\*?:} $txt d line]} {
		$t tag add bugrpttok $idx.2 $idx.16
	    } elseif {[regexp {^  ?\*?Comments\*?:} $txt d line]} {
		$t tag add bugrpttok $idx.1 $idx.end
	    } elseif {[regexp {^ See also:} $txt d line]} {
		$t tag add bugrpttok $idx.1 $idx.10
	    } elseif {[regexp {^  \*?See Also\*?:} $txt d line]} {
		$t tag add bugrpttok $idx.2 $idx.11
	    } elseif {[regexp {^ \*?Public Summary\*?:} $txt d line]} {
		$t tag add bugrpttok $idx.1 $idx.end
	    }
	}
    }
}

proc MsgHighlightQuoteLevel { str } {
    # <token> such as in SGML
    if {[regexp {([^<]*)<(.+)>([^>]*)} $str d pre addr post]} {
	return [MsgHighlightQuoteLevel $pre]
    }
    # a->b such as C pointer deference
    if {[regexp {([a-zA-Z0-9_]+)->([a-zA-Z0-9_]+)} $str d pre post]} {
	return [MsgHighlightQuoteLevel $pre]
    }

    set qbits "\[ \t]*(\}|:|>|\\+>|\[A-Za-z0-9_-]+>)"
    set best 0; set mexp ""; set bestmatch $str

    foreach {i} {1 2 3 4 5} {
        append mexp $qbits
        if {[regexp -- "^($mexp)" $str d substr]} {
            set best $i 
            set bestmatch $substr 
        }
    }
    return [list $best $bestmatch]
}
