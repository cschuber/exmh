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

proc Msg_Setup { t } {
    # Tags to pre-allocate other important colors
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
    # Allocate active button colors, too
    TextButton_Init $t

    $t tag raise sel

    # HACK To cache font for graphics part separator.
    catch {
	label $t.fontlabel6 -font -*-*-*-*-*-*-6-*-*-*-*-*-iso8859-*
	label $t.fontlabel8 -font -*-*-*-*-*-*-8-*-*-*-*-*-iso8859-*
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

	Face_Show [MsgParseFrom $mimeHdr(0=1,hdr,from)] $mimeHdr(0=1,hdr,x-face) $mimeHdr(0=1,hdr,x-image-url)

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
    $win config -cursor xterm
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

