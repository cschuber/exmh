# thread.tcl
#
#
# Display FTOC messages in a threaded manner
#
# Ignacio Martinez        <martinez@fundesco.es>
# Fundesco
# Madrid, April 1996
#
#    5/12/96    Axel Belinfante <Axel.Belinfante@cs.utwente.nl>
#        catch scan diagnostics sent to stderr (causes close to fail)
#

proc Thread_PrintReplies { msg minfo off mark {indent -1} } {
    upvar $minfo msginfo
    global exwin ftoc

    if {$indent < 0} {
	set indent 0
	set blank ""
    } else {
	incr indent [expr [string length $mark] + 1]
	set blank [format "%*s" $indent " "]
    }
    set maxoff [expr $ftoc(scanWidth) - 2]     ;# newline counted as well
    foreach m $msginfo(refs,$msg) {
        if {[lsearch $msginfo(out) $m] < 0} {
            set text $msginfo(text,$m)
            set tmplist [list [string range $text 0 $off] "$blank" "$mark " \
                              [string range $text [expr $off + 1] end]]
            set newtext [join $tmplist ""]
            if {[string length $newtext] > $maxoff} {
                set newtext [string range $newtext 0 $maxoff]
            }
            $exwin(ftext) insert end "$newtext\n"
            lappend msginfo(out) $m
            Thread_PrintReplies $m msginfo $off $mark $indent
        }
    }
}  

proc Thread_IsRel { minfo msg } {
    upvar $minfo msginfo

    if {[lsearch $msginfo(selm) $msg] >= 0} {
	return 1
    }
    foreach m $msginfo(refs,$msg) {
	if [Thread_IsRel msginfo $m] {
	  return 1
	}
    }

    return 0
}

proc Thread_Scan { folder minfo } {
    upvar $minfo msginfo

#
#  We only care about what is currently displayed into the FTOC.
#  New messages are ignored.
#
    set maxlines   $msginfo(maxl)
    set firstmsg   [Ftoc_MsgNumber 1]
    set lastmsg    [Ftoc_MsgNumber $maxlines]

    set scan_fmt   "%(msg) %{message-id}%{in-reply-to}%{references}"
    set scan_cmd   [list scan +$folder $firstmsg-$lastmsg \
                             -noheader -noclear -width 9999 -format $scan_fmt]

    if [catch {open "|$scan_cmd"} pipe] {
        Exmh_Status "scan failed: $pipe" purple
        return 1
    }

    set numline 0
    set status "Scanning $folder for cross-references ..."
    set pass [expr int($maxlines/10)]
    set msginfo(hits) 0
    set msginfo(tref) 0

    Exmh_Status $status blue
    while {[gets $pipe line] > 0} {
	set num {}
	if ![regexp {^ *([0-9]+) <([^>]*)>(.*)} $line x num mid newline] {
	    # no message-id?
	    regexp {^ *([0-9]+)} $line x num
	    set mid {}
	    set newline {}
	}
        if {$num != [lindex $msginfo(msgs) $numline]} {
            Exmh_Status "thread/scan message mismatch. Rescan?" purple
            return 1
        }
        incr numline
        if {$maxlines > 250 && [expr $numline%$pass] == 0} {
            set done [expr 10*$numline/$pass]
            Exmh_Status "$status $done% done" blue
        }
        set msginfo(refs,$num)  {}
        set msginfo(isref,$num) 0
        set msgnum($mid) $num
        set line $newline          
        while {[regexp {<([^>]*)>(.*)} $line x mid newline] == 1} {
            if [info exists msgnum($mid)] {
                set ref $msgnum($mid)
                lappend msginfo(refs,$ref) $num
                set msginfo(isref,$num) 1
                incr msginfo(hits)
            } else {
                if ![info exists unres($num)] {
                    set unres($num) {}
                }
                lappend unres($num) $mid
            }
            set line $newline
            incr msginfo(tref)
        }
    }
    if [catch {close $pipe} err] {
        Exmh_Status "scan diagnostic: $err" purple
        # we suppose that there were only diagnostics, no need to fail...
    }

#
# Second round. Disordered messages (i.e. replies received BEFORE their
# originals)
#
    foreach res [array names unres] {
        foreach mid $unres($res) {
           if [info exists msgnum($mid)] {
               set ref $msgnum($mid)
               lappend msginfo(refs,$ref) $res
               set msginfo(isref,$res) 1
               incr msginfo(hits)
           }
        }
    }

    return 0
}

proc Thread_Display { {breakoff 20} {mark "+->"} } {

    busy Thread_Ftoc 1 $breakoff $mark
}

proc Thread_DisplayAll { {breakoff 20} {mark "+->"} } {

    busy Thread_Ftoc 0 $breakoff $mark
}

proc Thread_Ftoc { {selected 0} {breakoff 20} {mark "+->"} } {
    global exwin exmh ftoc msg

#
#  Check that the current FTOC corresponds to a 'real folder' scan.
#
    if !$ftoc(displayValid) {
        Exmh_Status "Already threaded or not a valid display" warn
        return
    }

#
#  Selection activated and nothing selected, so do nothing
#
    if {$selected && [Ftoc_PickSize] < 1} {
	Exmh_Status "You must select at least one message first" warn
	return
    }

    set folder     $exmh(folder)          ;#  the real folder name
    set curmsg     {}                     ;#  the current message
    set show       noshow                 ;#  redisplay message?

#
#  Saving the current state
#
    if $ftoc(pickone) {
        set curmsg $msg(id)
        if {$msg(dpy) == $curmsg} {
            set show show
        }
	set sellines $ftoc(curLine)
    } else {
	set sellines $ftoc(lineset)
    }

#
#  Commit pending changes. We are sort of changing folders ...
#
    if {[Ftoc_Changes "Change folder"] > 0} {
        return
    }
    set maxlines   $ftoc(numMsgs)

#
# Get text ASAP to speed up the whole thing
#
    set numline 0
    set msginfo(msgs)  {}
    set msginfo(selm)  {}
    Exmh_Status "Getting text from the display ..." blue
    while {$numline < $maxlines} {
	incr numline
	set text [$exwin(ftext) get $numline.0 $numline.end]
	regexp {^ *([0-9]+)} $text x num
	set msginfo(text,$num) $text
        lappend msginfo(msgs) $num
	if {[lsearch $sellines $numline] >= 0} {
	    lappend msginfo(selm) $num
	}
    }

    set msginfo(maxl) $maxlines
    if {[Thread_Scan $folder msginfo] != 0} {
	return
    }

#
# Redisplay
#
    Ftoc_RangeUnHighlight
    Msg_CheckPoint
    Msg_Reset $maxlines $folder
    set ftoc(folder) {}
    set ftoc(displayValid) 0    ;#  don't cache this display now
    set ftoc(displayDirty) 0    ;#  but do it later if there are any changes

    set msginfo(out) {}

    Exmh_Status "Redisplaying FTOC ..." blue
    $exwin(ftext) configure -state normal
    $exwin(ftext) delete 0.0 end
    foreach m $msginfo(msgs) {
        if !$msginfo(isref,$m) {
	    if {!$selected || [Thread_IsRel msginfo $m]} {
		$exwin(ftext) insert end "$msginfo(text,$m)\n"
		lappend msginfo(out) $m
		Thread_PrintReplies $m msginfo $breakoff $mark
	    }
        }
    }
    $exwin(ftext) configure -state disabled

    set numseltext {}
    if $selected {
	set numsel [llength $msginfo(out)]
	set numseltext "$numsel/"
    } elseif {[llength $msginfo(out)] != $maxlines} {
        Exmh_Status "folder incorrectly threaded. line number mismatch" warn
    }

    Flist_ForgetUnseen $folder
    Ftoc_ShowUnseen $folder

    if {$curmsg != {}} {
        set msg(id) $curmsg
        set ftoc(curLine) [Ftoc_FindMsg $curmsg]
        Buttons_Current 1
        Msg_ShowCurrent $show
    } else {
	if $selected {
	    Buttons_Current 0
	    Buttons_Range
	    Ftoc_PickMsgs $msginfo(selm) 0
	} else {
	    Exmh_Status ok
	}
        Ftoc_Yview end
    }
    
    set eff 0
    if {$msginfo(tref) > 0} {
        set eff [expr int(100*$msginfo(hits)/$msginfo(tref))]
    }
    Label_Folder {} "$folder+ $numseltext$maxlines msgs $eff% threaded"
}
