# seditMime.tcl
#
# Support for composing MIME-compliant messages in sedit
#
# The basic strategy for composing multipart messages is to maintain a set
# of marks in the text that delimit the various parts and their headers.
# In addition, a tag giving the type covers a given part.  The mark names
# are kept in  sedit($t,marks)
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc SeditMimeReset { t } {
    global sedit
    Exmh_Debug SeditMimeReset
    set sedit($t,multi) 0	;# Not yet a multipart message
    set sedit($t,mime) 0	;# No MIME type yet
    set sedit($t,dash) 0	;# 1 if ---- header separator
    foreach item [array names sedit] {
	if [regexp "^$t,boundary" $item] {
	    unset sedit($item)
	}
    }
    foreach tag [$t tag names] {
	catch {$t tag delete $tag}
    }
    foreach mark [$t mark names] {
	catch {$t mark unset $mark}
    }
}
proc SeditMimeParse { t } {

    # This attempts to rebuild the mark and tag structure from a draft.
    # It does not build up everything, just the
    # type=<type> tags for leaf parts (not multi's)
    # part=<index> tags
    # multi<level>.next for appending parts.
    # Charset for fixing character sets

    global sedit
    Exmh_Debug SeditMimeParse $t
    set state header
    set type text/plain
    set level {}
    set part 0
    set boundaries {}
    set key {}		;# current header key
    set content-type {}	;# Content-Type line
    for {set i 1} {[$t compare $i.0 < end]} {incr i} {
	set line [$t get $i.0 $i.end]
	set len [string length $line]
	if {$state == "header"} {
	    if {[regexp {^[ 	]+} $line]} {
		if [regexp -nocase content-type $key] {
		    append content-type $line
		}
	    } elseif {[regexp -nocase {^([^:]+):(.*)$} $line match key value]} {
		if [regexp -nocase content-type $key] {
		    $t mark set beginpart $i.0
		    set sedit($t,mime) 1
		    set sedit($t,part) 0
		    set content-type $value
		}
	    } elseif {$len == 0 || [regexp ^-- $line]} {
		set state body
		# Decode content-type
		if {[string length ${content-type}] != 0} {
		    set params [split ${content-type} \;]
		    Exmh_Debug SeditMimeParse MIME $params
		    set type [string tolower [string trim [lindex $params 0]]]
		    if {[string match multipart/* $type]} {
			set sedit($t,multi) 1
			set sedit($t,level,0) 0
			if {[string length $level] == 0} {
			    set level 0
			} else {
			    global sedit
			    incr sedit($t,level,$level)
			    set level ${level}.$sedit($t,level,$level)
			    set sedit($t,level,$level) 0
			}
			$t mark set level=$level $i.0
			$t mark set multi${level}.next end
		    }
		    if {[string match text/* $type]} {
			$t tag add Charset beginpart "beginpart lineend"
		    }
		    foreach sub [lrange $params 1 end] {
			if [regexp {([^=]+)=(.+)} $sub match key val] {
			    set key [string trim [string tolower $key]]
			    set val [string trim $val \ \"]
			    if {[string compare $key boundary] == 0} {
				# push new boundary onto the stack
				set sedit($t,boundary,$level) $val
				set boundaries [linsert $boundaries 0 $val]
			    }
			}
		    }
		}
	    }
	} else {
	    if [regexp "\[\x80-\xff\]" $line] {
		set sedit($t,8bit) 1
	    }
	    foreach b $boundaries {
		if [regexp ^--$b\(--\)?\$ $line match alldone] {
		    if {![string match multipart/* $type]} {
			$t tag add type=$type beginpart $i.0
			$t tag add part=$part beginpart $i.0
		    }
		    set type text/plain
		    incr part
		    if {[string compare $alldone --] == 0} {
			$t tag add level=${level} level=${level} $i.0
			$t mark set multi${level}.next $i.0
			set level [file root $level]
			set boundaries [lrange $boundaries 1 end]
			set done 1
		    } else {
			set state header
			set done 0
		    }
		    break
		}
	    }
	}
    }
    if {$sedit($t,mime)} {
	$t tag delete Body
	if {!$sedit($t,multi)} {
	    $t tag add part=0 beginpart end
	    $t tag add type=$type beginpart end
	    $t tag add level= beginpart end
	    $t mark set headerOrig beginpart
	    $t mark unset beginpart
	}
    }
}

proc SeditMimeType { type {promote {}} } {
    # 
    # Called from the user menu to define or add a type to a message.
    # This returns a text mark at which to insert the body.
    #
    global sedit
    set t $sedit(t)				;# active text widget
    set promote [string length $promote]	;# Promote existing body

    Exmh_Debug SeditMimeType $type promote=$promote

    if {! $sedit($t,mime)} {
	#
	# No type information yet.
	#
	if {$promote} {
	    set keep 1		;# Keep existing body
	} else {
	    SeditBodyDialog $t $type
	    set keep $sedit($t,body)
	}
	return [SeditMimeFirstPart $t $type $promote $keep]
    } elseif {! $sedit($t,multi) && !$promote} {
	#
	# Adding another part and not yet multipart structured
	#
	$t mark set header headerOrig
	if {![string match multipart/* $type]} {
	    SeditStartMulti $t multipart/mixed
	    return [SeditBoundary&Type $t $type 0]
	} else {
	    return [SeditStartMulti $t $type]
	}
    } else {
	#
	# Figure out where we are and ask the user what to do.
	#
	set oldtype {}
	set level {}
	set part {}
	if {[$t compare insert <= header]} {
	    set spot [$t index "header + 1 line"]
	} else {
	    set spot [$t index insert]
	}
	foreach tag [$t tag names $spot] {
	    regexp {level=(.+)} $tag match level
	    regexp {type=(.+)} $tag match oldtype
	    regexp {part=(.+)} $tag match part
	}
	if {$promote && [string match {text/*} $type]} {
	    if {$part == ""} {
		# lost part headers? 
		set sedit($t,newpart) 1
	    } else {
		# change existing part
		set sedit($t,newpart) 0
	    }
	} else {
	    SeditPartDialog $t $oldtype $type $level $part
	}
	if {$sedit($t,newpart) < 0} {
	    # Abort
	    return
	}
	set promote [expr $sedit($t,newpart) == 0]
	return [SeditMimePart $t $type $promote $oldtype $part $level]
    }
}
proc SeditMimeFirstPart { t type promote keep} {
    global sedit
    set sedit($t,part) 0		;# Part index
    set sedit($t,mime) 1		;# Have Mime header
    #
    # Initial type specification from untyped body
    # header mark is at the end of the last header line.
    # Upon return, headerOrig is set to the beginning of the first
    # new header line inserted.  This is used later when promoting
    # a simple typed body to a multipart structure.
    #
    if {!$keep} {
	# Delete body, if any - tag range may return null
	catch {eval {$t delete} [$t tag range Body]}
    }
    $t tag delete Body

    Exmh_Debug SeditMimeFirstPart $type

    # Position the header mark at the begining of the line where
    # we will be inserting new headers (Content-Type, etc.)
    if [catch {$t index header}] {
	SeditMsg $t "No message?"
	$t mark set header end
    }
    $t insert header "\nMime-Version: 1.0"
    global tk_version
    if {(($tk_version >= 4.0) && [$t compare header == "end -1c"]) ||
	(($tk_version < 4.0) && [$t compare header == "end"])} {
	# Nothing left after deleting the body
	$t insert header "\n"
    } else {
	$t mark set header "header + 1c"
    }
    set h [$t index header]		;# for headerOrig

    if {! $promote} {
	if {! $keep} {
	    #
	    # Initialize empty part type
	    #
	    if [string match multipart/* $type] {
		set mark [SeditStartMulti $t $type empty]
	    } else {
		set mark [SeditContentType $t $type {} header]
	    }
	} else {
	    #
	    # Initialize multipart with existing body as first part
	    #
	    set mark [SeditStartMulti $t multipart/mixed]
	    SeditContentType $t text/plain 0 $mark end

	    if {![string match multipart/* $type]} {
		#
		# Now do second part (if not already multi)
		#
		set mark [SeditBoundary&Type $t $type 0]
	    }
	}
    } else {
	#
	# Promoting text/plain body
	#
	SeditContentType $t $type {} header end
	set mark header
    }
    $t mark set headerOrig $h
    return $mark		;# Just after new headers
}
proc SeditAppendPart { type } {
    global sedit
    set t $sedit(t)

    Exmh_Debug SeditAppendPart $type

    if {! $sedit($t,multi)} {
	#
	# Adding another part and not yet multipart structured
	#
	$t mark set header headerOrig
	if {![string match multipart/* $type]} {
	    SeditStartMulti $t multipart/mixed
	    return [SeditBoundary&Type $t $type 0]
	} else {
	    return [SeditStartMulti $t $type]
	}
    }
    set promote 0
    set oldtype {}
    set level {}
    set part {}
    set spot [$t index end]
    foreach tag [$t tag names $spot] {
	regexp {level=(.+)} $tag match level
	regexp {type=(.+)} $tag match oldtype
	regexp {part=(.+)} $tag match part
    }
    SeditMimePart $t $type $promote $oldtype $part $level
}
proc SeditMimePart { t type promote oldtype part level} {
    #
    # Add another part to the message.
    # Multipart structure is already defined at this point.
    #
    if {$promote} {
	#
	# Works for text/plain -> text/enriched
	#
	set range [$t tag ranges part=$part]
	Exmh_Debug SeditMimePart promote part=$part level=$level range=$range
	$t mark set first [lindex $range 0]
	$t mark set last [lindex $range 1]

	# Preserve headerOrig in case not multi yet
	# Tk 4.0 tag gravity will be a blessing!
	global sedit
	if {! $sedit($t,multi)} {
	    set save [$t index headerOrig]
	}
	$t delete "first linestart" "first lineend + 1c"	;# nuke old Content-Type
	set mark [SeditContentType $t $type $level first last]
	if [info exists save] {
	    $t mark set headerOrig $save
	}
	return $mark
    } elseif {[string match multipart/* $oldtype] ||
	    ([string length $part] == 0)} {
	# Just append the part at the current level
	Exmh_Debug Appending part at level $level
	return [SeditBoundary&Type $t $type $level]
    } else {
	set index [lindex [$t tag ranges part=$part] 1]
	$t mark set addpart $index
	Exmh_Debug Inserting after part $part, level $level at [$t index addpart]
	return [SeditBoundary&Type $t $type $level addpart]
    }
}
proc SeditStartMulti {t type {empty {}} } {
    global sedit
    set sedit($t,multi) 1
    set sedit($t,level,0) 0
    set sedit($t,mhn) 0			;# Don't try MHN

    Exmh_Debug SeditStartMulti

    set h [SeditMultiInner $t $type {} header end]
    $t mark set start $h

    if {$sedit($t,dash)} {
	set dash "start lineend + 1c"
	# Insert copy of dashed line into outer body
	$t insert start [$t get $dash "$dash lineend"]
	# Remove dashed line from inner body, replacing it with blank line
	$t delete $dash "$dash lineend"
    }

    $t insert start "\nThis is a multipart MIME message.\n\n"
    if {$empty == {}} {
	# Wrapping up an existing part - insert boundary and tag part
	set origin [$t index start]
	$t insert start --[SeditBoundary $t 0]\n
	Text_TagRangeOverride $t $origin start type=boundary
    }
    $t mark set header $h	;# Restore header, but probably not used
    return start
}
proc SeditMultiInner {t type level mark mark2} {
    #
    # Wrap up text between mark and mark2 in a multipart structure.
    # Return the text index just after the new Content-Type header
    #
    Exmh_Debug SeditMultiInner level=$level $mark [$t index $mark] $mark2
    if {[string length $level] == 0} {
	set level 0
    } else {
	global sedit
	incr sedit($t,level,$level)
	set level ${level}.$sedit($t,level,$level)
	set sedit($t,level,$level) 0
    }
    set boundary [SeditBoundary $t $level]

    set origin [$t index $mark]
    $t insert $mark "Content-Type: $type ;\n\tboundary=\"$boundary\"\n"
    set h [$t index $mark]
    Exmh_Debug SeditMultiInner origin at $origin $mark at $h

    # Insert the terminating --boundary-- line and set multiN.next to be
    # just before that --boundary-- line.

    global tk_version
    $t insert $mark2 \n
    if {$tk_version >= 4.0 && ([string compare $mark2 end] == 0)} {
	set save [$t index "end -1 line"]
    } else {
	set save [$t index $mark2]
    }
    $t insert $mark2 \n--${boundary}--\n
    $t mark set multi${level}.next $save

    # Tag the text.  No part is needed.
    if {[string compare $mark $mark2] == 0} {
	# Empty multipart - override type tags
	Text_TagRangeOverride $t $origin $mark2 type=$type
    } else {
	# Give type a low priority in comparison to body being wrapped up.
	Text_TagRangeLow $t $origin $mark2 type=$type
    }
    Text_TagRangeOverride $t $origin $mark2 level=$level
    return $h
}

proc SeditBoundary {t level} {
    global sedit
    if ![info exists sedit($t,boundary,$level)] {
	set sedit($t,boundary,$level) [Mime_MakeBoundary $level]
    }
    return $sedit($t,boundary,$level)
}
proc SeditBoundary&Type {t type level {mark {}} {mark2 {}} } {
    global sedit
    Exmh_Debug SeditBoundary&Type $type $level $mark $mark2
    incr sedit($t,part)
    if {[string length $level] == 0} {
	set level 0
    }
    if {[string length $mark] == 0} {
	set mark multi${level}.next
    }
    if [catch {$t index $mark}] {
	$t mark set $mark end
    }
    set boundary [SeditBoundary $t $level]
    scan [$t index $mark] "%d.%d" line char
    if {$char != 0} {
	$t insert $mark \n
    }
    set m [$t index $mark]
    $t insert $mark "\n--$boundary\n"
    Text_TagRangeOverride $t $m $mark type=boundary part=
    return [SeditContentType $t $type $level $mark $mark2]
}
proc SeditContentType { t type level mark {mark2 {}} } {
    global sedit

    Exmh_Debug SeditContentType $type mark=$mark mark2=$mark2

    if {[string length $mark2] == 0} {
	set mark2 $mark
    }
    if [string match multipart/* $type] {
	return [SeditMultiInner $t $type $level $mark $mark2]
    }
    if {! [regexp {(text|audio|image|message|application|video|x-.+)/} $type]} {
	SeditMsg $t "Unsupported type $type"
	return ""
    }
    set start [$t index $mark]
    $t insert $mark "Content-Type: $type\n"
    if {[regexp ^text $type]} {
	$t tag add Charset $start "$start lineend"
#	$t tag configure Charset -background red
	Exmh_Debug Charset $start [$t index "$start lineend"]
    }
    Exmh_Debug type=$type $start $mark2
    Text_TagRangeOverride $t $start $mark2 part=$sedit($t,part) type=$type level=$level
    if {[string compare header $mark] == 0} {
	$t mark set addpart header
	$t mark set header "header -1 char"
	set mark addpart
    }
    set save [$t index $mark]
    if {$sedit(colorize) && ([tk colormodel .] == "color")} {
	catch {
	    switch -glob -- $type {
		text/enriched* {
		    $t tag configure type=$type -background $sedit(c_enrichedBg)
		    $t tag configure type=$type -foreground $sedit(c_enrichedFg)
		}
		text/* {
		    $t tag configure type=$type -background $sedit(c_textBg)
		    $t tag configure type=$type -foreground $sedit(c_textFg)
		}
		audio/* {
		    $t tag configure type=$type -background $sedit(c_audioBg)
		    $t tag configure type=$type -foreground $sedit(c_audioFg)
		}
		image/* {
		    $t tag configure type=$type -background $sedit(c_imageBg)
		    $t tag configure type=$type -foreground $sedit(c_imageFg)
		}
		message/* {
		    $t tag configure type=$type -background $sedit(c_messageBg)
		    $t tag configure type=$type -foreground $sedit(c_messageFg)
		}
		application/* {
		    $t tag configure type=$type -background $sedit(c_applicationBg)
		    $t tag configure type=$type -foreground $sedit(c_applicationFg)
		}
		video/* {
		    $t tag configure type=$type -background $sedit(c_videoBg)
		    $t tag configure type=$type -foreground $sedit(c_videoFg)
		}
	    }
	}
    }
    Exmh_Debug SeditContentType $type returns $save
    return $save	;# end of headers mark
}
proc SeditFixupCharset { draft t } {
    global sedit
    if {$sedit($t,8bit)} {
	set charset $sedit(charset)
    } elseif {$sedit($t,Acharset) != {}} {
        set charset $sedit($t,Acharset)   ;# set in SeditKinput_start
    } else {
	set charset us-ascii
    }
    Exmh_Debug SeditFixupCharset $charset
    foreach range [FtocMakePairs [$t tag ranges Charset]] {
	set start [lindex $range 0]
	set end [$t index "$start lineend"]
	set line [$t get $start $end]
	if ![regexp -nocase charset $line] {
	    set line "[string trimright $line {; }]; charset=$charset"
	} elseif [regexp -nocase {^(.*charset)=(.+)$} $line match first xchar] {
	    Exmh_Debug Existing charset $xchar
	    if {[regexp -nocase {(us-ascii|7bit)} $xchar] && $sedit($t,8bit)} {
		set line "$first=$charset"
	    }
	} else {
	    Exmh_Debug "SeditFixupCharset failed <$line>"
	}
	$t delete $start $end
	$t insert $start $line
	$t tag add Charset $start "$start lineend"
    }
}
proc SeditPartDelete { part } {
    global sedit
    set t $sedit(t)
    set range [$t tag range $part]
    catch {$t delete [lindex $range 0] [lindex $range 1]}
}
proc SeditBodyDialog { t type} {
    global sedit
    set f [frame $t.body -bd 2 -relief ridge]
    message $f.msg -aspect 1000 -text \
"What should be done with the existing message body?
Delete it, or preserve it as a part?"
    pack $f.msg -side top -fill both
    set b [frame $f.but -bd 10 -relief flat]
    set sedit($t,body) 0
    button $b.replace -text "Delete" -command "set sedit($t,body) 0 ; destroy $f"
    button $b.save -text "Make into part" -command "set sedit($t,body) 1 ; destroy $f"
    pack $b.replace $b.save -side left -padx 5
    pack $b
    Widget_PlaceDialog $t $f
    tkwait window $f
    return $sedit($t,body)
}
proc SeditPartDialog { t oldtype type level part } {
    global sedit
    set f [frame $t.part -bd 2 -relief ridge]
    message $f.msg -aspect 1000 -text \
"Change the type of the current part,
currently $oldtype,
or add a new part at level #$level,
type $type,
after the current part #${part}?"
    pack $f.msg -side top -fill both
    set b [frame $f.but -bd 10 -relief flat]
    set sedit($t,newpart) 0
    button $b.replace -text "Change type" -command "set sedit($t,newpart) 0 ; destroy $f"
    $b.replace configure -state disabled
    button $b.save -text "Add new part" -command "set sedit($t,newpart) 1 ; destroy $f"
    button $b.abort -text "Cancel" -command "set sedit($t,newpart) -1 ; destroy $f"
    pack $b.replace $b.save $b.abort -side left
    pack $b
    Widget_PlaceDialog $t $f
    tkwait window $f
    return $sedit($t,newpart)
}
proc SeditFormatMail { t out isigw } {
    global sedit exmh
    set tag [$t tag names]
    Exmh_Debug FormatMail tags $tag
    set ix [lsearch -regexp $tag text/enriched]
    if {$ix >= 0} {
	SeditEnrichedExpand $t
	set ranges [$t tag ranges [lindex $tag $ix]]
	set quote 1
	set L1 [lindex $ranges 0]
	set L2 [lindex $ranges 1]
	set ranges [lrange $ranges 2 end]
    } else {
	set ranges {}
	set quote 0
    }
    set id $sedit($t,id)
    SeditCheckForIsigHeaders $t
    if {$sedit($t,format) == "OnType"} {
	# Prevent duplicate X-Mailer or X-Exmh-Isig-* headers
	if {[catch {set end [$t index hlimit]}] &&
	    [catch {set end [$t index header]}]} {
		set end end
	}
	set X1 [$t get 1.0 $end]
	set X2 [$t get $end end]
	regsub -all -nocase "(^|\n)(x-mailer:\[^\n\]*\n)+" $X1 {\1} X1
	regsub -all -nocase "(^|\n)(x-exmh-isig-(comptype|folder):\[^\n\]*\n)+" $X1 {\1} X1
	# No X-Mailer on redistributed messages
	if {[string compare $exmh($id,action) dist] != 0} {
	    puts $out "X-Mailer: exmh $exmh(version)"
	}
	# Replace X-Exmh-Isig-* headers if necessary
	if {$isigw} {
	    puts $out "X-Exmh-Isig-CompType: $sedit($t,isigc)"
	    puts $out "X-Exmh-Isig-Folder: $sedit($t,isigf)"
	}
	puts $out "$X1$X2"
	return
    }
    # Try not to butcher non-text parts
    set breakrange {}
    foreach tg $tag {
	if [regexp ^type=text/ $tg] {
	    set breakrange "$breakrange [$t tag ranges $tg]"
	}
	if {[string compare Body $tg] == 0} {
	    # no mime information
	    set breakrange "1.0 [$t index end]"
	    break
	}
    }
    set breakrange [eval concat [SeditSortRanges $breakrange]]
    Exmh_Debug FormatMail breakrange $breakrange
    set F1 [lindex $breakrange 0]
    set F2 [lindex $breakrange 1]
    set breakrange [lrange $breakrange 2 end]
    if {[string length $F1] == 0} {
	set F1 -1
	set break 0
    } else {
	set break 1
    }

    set xmailer 0
    set inheaders 1
    scan [$t index end] "%d"  last
    set plen [string length $sedit(pref,replPrefix)]

    # No X-Mailer on redistributed messages
    if {[string compare $exmh($id,action) dist] != 0} {
	puts $out "X-Mailer: exmh $exmh(version)"
    }
    # Output X-Exmh-Isig-* headers if necessary
    if {$isigw} {
	puts $out "X-Exmh-Isig-CompType: $sedit($t,isigc)"
	puts $out "X-Exmh-Isig-Folder: $sedit($t,isigf)"
    }
    for {set L 1} {$L <= $last} {incr L} {
	set line [$t get $L.0 $L.end]
	if {$inheaders} {
	    # Blank or empty line terminates headers
	    # Leading --- terminates headers
	    if {[regexp {^[ 	]*$} $line] || [regexp {^--+} $line]} {
		set inheaders 0
	    }
	    if {[regexp -nocase {^x-mailer:} $line] ||
		[regexp -nocase {^x-exmh-isig-(comptype|folder):} $line]} {
		continue
	    }
	}
	if $inheaders {
	    set limit $sedit(lineLength)
	} else {
	    set limit $sedit(lineLength)

	    # Decide whether or not to break the body line

	    if {$plen > 0} {
		if {[string first $sedit(pref,replPrefix) $line] == 0} {
		    # This is quoted text from previous message, don't reformat
		    puts $out $line
		    if {$quote && !$inheaders} {
			# Fix from <sarr@umich.edu> to handle text/enriched
			if {$L > $L1 && $L < $L2 && $line != {}} {
			    # enriched requires two newlines for each one.
			    puts $out ""
			} elseif {$L > $L2} {
			    set L1 [lindex $ranges 0]
			    set L2 [lindex $ranges 1]
			    set ranges [lrange $ranges 2 end]
			    set quote [llength $L1]
			}
		    }
		    continue
		}
	    }
	    if {$F1 < 0} {
		# Nothing left to format
		puts $out $line
		continue
	    } elseif {$L < $F1} {
		# Not yet to formatted block
		puts $out $line
		continue
	    } elseif {$L > $F2} {
		# Past formatted block
		set F1 [lindex $breakrange 0]
		set F2 [lindex $breakrange 1]
		set breakrange [lrange $breakrange 2 end]
		puts $out $line
		if {[string length $F1] == 0} {
		    set F1 -1
		}
		continue
	    }
	}
	set climit [expr $limit-1]
	set cutoff 50
	set continuation 0

	while {[string length $line] > $limit} {
	    for {set c [expr $limit-1]} {$c >= $cutoff} {incr c -1} {
		set char [string index $line $c]
		if {$char == " " || $char == "\t"} {
		    break
		}
		if {$char == ">"} {	;# Hack for enriched formatting
		    break
		}
	    }
	    if {$c < $cutoff} {
		if {! $inheaders} {
		    set c [expr $limit-1]
		} else {
		    set c [string length $line]
		}
	    }
	    set newline [string range $line 0 $c]
	    if {! $continuation} {
		puts $out $newline
	    } else {
		puts $out \ $newline
	    }
	    incr c
	    set line [string trimright [string range $line $c end]]
	    if {$inheaders} {
		set continuation 1
		set limit $climit
	    }
	}
	if {$continuation} {
	    if {[string length $line] != 0} {
		puts $out \ $line
	    }
	} else {
	    puts $out $line
	    if {$quote && !$inheaders} {
		if {$L > $L1 && $L < $L2 && $line != {}} {
		    # enriched requires two newlines for each one.
		    puts $out ""
		} elseif {$L > $L2} {
		    set L1 [lindex $ranges 0]
		    set L2 [lindex $ranges 1]
		    set ranges [lrange $ranges 2 end]
		    set quote [llength $L1]
		}
	    }
	}
    }
}
proc SeditSortRanges { ranges } {
    return [lsort -command SeditRangeCompare [FtocMakePairs $ranges]]
}
proc SeditRangeCompare {r1 r2} {
    set a [lindex $r1 0]
    set b [lindex $r2 0]
    return [expr {$a > $b}]
}

# SeditTest1 and SeditAppendPart can be used to insert structure
# without any user dialogs.
proc SeditMimeDebug {} {
    SeditMimeShowMarks
    SeditMimeShowTags
}
proc SeditMimeShowMarks { {t {}} } {
    global sedit
    if {$t == {}} {
	set t $sedit(t)
    }
    Exmh_Debug SeditMimeShowMarks $t
    foreach mark [$t mark names] {
	Exmh_Debug $mark\t[$t index $mark]
    }
}
proc SeditMimeShowTags { {t {}} } {
    global sedit
    if {$t == {}} {
	set t $sedit(t)
    }
    Exmh_Debug SeditMimeShowTags
    foreach tag [$t tag names] {
	Exmh_Debug [format "%-25s %s" $tag [$t tag range $tag]]
    }
}
proc SeditTestFirst { type {keep 1} {promote 0} } {
    global sedit
    set t $sedit(t)
    SeditMimeFirstPart $t $type $promote $keep
}
proc SeditTestInsert { file {newpart 1} {encoding {}} {type text/plain} {desc {}}} {
    global sedit
    set t $sedit(t)
    SeditInsertFile {} $t $file $newpart
}
proc SeditTestInit { {charset 0} } {
    global sedit
    set sedit(colorize) 1
    set sedit(iso) $charset
}
proc SeditTest1 {} {
    global sedit
    Msg_Compose
    SeditTestInsert /tmp/part1
    SeditMarkClean $sedit(t)
}
proc SeditTest1b {} {
    global sedit
    Msg_Compose
    Text_MoveInsert $sedit(t) hlimit+1line
    SeditTestInsert /tmp/part1
    SeditMarkClean $sedit(t)
}
proc SeditTest2 {} {
    global sedit
    Msg_Compose
    Text_MoveInsert $sedit(t) hlimit+1line
    SeditMimeType text/enriched promote
    SeditMarkClean $sedit(t)
}
proc SeditTest2b {} {
    global sedit
    SeditTest2
    SeditTestInsert /tmp/sedit.patch
    SeditMarkClean $sedit(t)
}
proc SeditTest3 {} {
    global sedit
    Msg_Compose
    SeditMimeType audio/basic
    SeditAppendPart video/basic
    SeditMarkClean $sedit(t)
}
proc SeditTest3b {} {
    global sedit
    Msg_Compose
    Text_MoveInsert $sedit(t) hlimit+1line
    SeditMimeType audio/basic
    SeditAppendPart video/basic
    SeditMarkClean $sedit(t)
}
proc SeditTest4 {} {
    global sedit
    Msg_Compose
    Text_MoveInsert $sedit(t) hlimit+1line
    SeditTestInsert /tmp/part1
    set ranges [$sedit(t) tag ranges part=1]
    catch {Text_MoveInsert $sedit(t) "[lindex $ranges 0] + 1 line"}
    SeditMimeType text/enriched promote
    SeditMarkClean $sedit(t)
}
proc SeditTest4b {} {
    global sedit
    SeditTest4
    SeditTestInsert /tmp/part2
    SeditMarkClean $sedit(t)
}
proc SeditTest4c {} {
    global sedit
    SeditTest4b
    SeditTestInsert /tmp/part1
    SeditMarkClean $sedit(t)
}
proc SeditTest5 {} {
    global sedit
    Msg_Compose
    Text_MoveInsert $sedit(t) hlimit+1line
    SeditTestInsert /tmp/part1
    SeditAppendPart multipart/mixed
    SeditMarkClean $sedit(t)
}
proc SeditTest5b {} {
    global sedit
    SeditTest5
    set ranges [$sedit(t) tag ranges level=0.1]
    Text_MoveInsert $sedit(t) "[lindex $ranges 0] + 1 line"
    SeditTestInsert /tmp/part2
    SeditMarkClean $sedit(t)
}
proc SeditTest5c {} {
    global sedit
    SeditTest5b
    Text_MoveInsert $sedit(t) "insert + 3 line"
    SeditTestInsert /tmp/part1
    SeditMarkClean $sedit(t)
}
proc SeditTest5d {} {
    global sedit
    SeditTest5b
    Text_MoveInsert $sedit(t) "insert + 3 line"
    SeditMimeType multipart/alternative
    SeditMarkClean $sedit(t)
}
proc SeditTestFOO {} {
    global sedit
    Text_MoveInsert $sedit(t) hlimit+1line
    SeditTestInsert /tmp/part1
    SeditAppendPart multipart/mixed
    set ranges [$sedit(t) tag ranges level=0.1]
    Text_MoveInsert $sedit(t) "[lindex $ranges 0] + 1 line"
    SeditTestInsert /tmp/part2
    Text_MoveInsert $sedit(t) "insert + 3 line"
    SeditTestInsert /tmp/part1
    SeditMarkClean $sedit(t)

}
