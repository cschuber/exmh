# seditEnriched.tcl
#
# Support for text/enriched display
#
# Copyright (c) 1994 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc SeditMimeEnriched {look {draft {}} {t {}} } {
    # Add text looks to the current selection
    global mimeFont mime sedit
    if {$draft == {}} {
	set draft $sedit(draft)
    }
    if {$t == {}} {
	set t $sedit(t)
    }
    if {$sedit($t,format) == "Never"} {
	# Needed to get text/enriched output
	set sedit($t,format) OnSend
    }

    if [catch {$t tag names sel.first} tags] {
	SeditMsg $t "No selection?"
	return
    }
    if [$t compare [$t index header] > sel.first] {
	SeditMsg $t "No looks in headers"
	return
    }
    if {[lsearch $tags type=text/enriched] < 0} {
	# First enriched text use - promote to text/enriched MIME type
	SeditMimeType text/enriched promote
    }
    if {[string compare $look "x-plain"] == 0} {
	Sedit_TagClear $t sel.first sel.last
    } else {
	Sedit_TagRange $t sel.first sel.last $look enriched
    }
}

proc SeditEnrichedExpand { t } {
    # now quote nonstandard tags (if still unquoted)
    set startpos [$t index header]
    for {set tbq [$t search "<" $startpos "end"]} {$tbq!=""} {set tbq [$t search "<" $startpos "end"]} {
	if {[$t get "$tbq +1c" "$tbq +2c"] == "<"} {
	    # already quoted -> ignore
	    set startpos "$tbq +2c"
	} elseif [regexp -nocase {^</?(param|bold|italic|underline|fixed|fontfamily|color|smaller|bigger|center|flushleft|flushright|flushboth|paraindent|nofill|except|lang|x-[a-z-]+)>} [$t get "$tbq" "$tbq lineend"]] {
	    # or known command -> ignore
	    set startpos "$tbq +1c"
	} else {
	    # neither? then quote!
	    $t insert $tbq "<"
	    set startpos "$tbq +2c"
	}
    }

    # Add text/enriched formatting commands
    set tags {}	;# enriched text tags
    foreach tag [$t tag names] {
	if [regexp {Mime[0-9]+=(.+)} $tag] {
	    lappend tags $tag
	}
	if [regexp {Look[0-9]+} $tag] {
	    $t tag delete $tag
	}
    }
    foreach mimetag $tags {
	regexp {Mime[0-9]+=(.+)} $mimetag match tag
	if {$tag == "x-plain"} {
	    continue
	}
	set range [$t tag nextrange $mimetag 1.0]
	while {$range != {}} {
	    set first [lindex $range 0]
	    set last [lindex $range 1]
	    $t mark set first $first	;# need a floating mark
	    $t tag remove $mimetag $first $last
	    $t insert $last </$tag>
	    $t insert $first <$tag>
	    foreach tag2 [$t tag names first] {
		if [regexp {Mime[0-9]+=(.+)} $tag2 match tagName] {
		    # bleed the other mark backwards, over <tag> just inserted
		    set len [string length <$tag>]
		    $t tag add $match "first - $len chars" first
		}
	    }
	    set range [$t tag nextrange $mimetag 1.0]
	}
    }
}

proc Sedit_TagRange { t start end key type } {
    global rich
    #
    # Called from a composer to set looks in a text widget.
    #
    SeditMimeTag $t $start $end $key
    SeditRichReset $t
    #
    # The Looks for the range are a function of existing looks within
    # the range.  So, this new range will break up pre-existing looks
    # ranges and modify them.  The Looks tag includes the formatting
    # stack needed to compute the proper looks.
    #
    set end [$t index $end]
    set start [$t index $start]
    set rich($t,lookMark) $start
    set curStack $key
    set forwMark {}
    Exmh_Debug Sedit_TagRange $start $end $key
    Exmh_Debug Stack := $curStack
    for {set ix $start} {[$t compare $ix < $end]} {set ix [$t index "$ix +1c"]} {
	foreach tag [$t tag names $ix] {
	    if [regexp {Look=(.+)} $tag match stack] {
		Exmh_Debug $tag | $rich($t,lookMark) $ix cur=$curStack new=$stack
		SeditRichLooks $t $rich($t,lookMark) $ix $curStack
		set rich($t,lookMark) $ix
		set curStack $stack
		lappend curStack $key
		Exmh_Debug Stack => $curStack
		set range [$t tag nextrange $tag $ix]
		if {$range != {}} {
		    Exmh_Debug $t tag remove $tag $range
		    eval {$t tag remove $tag} $range
		    set forwMark [lindex $range 1]
		}
		continue
	    }
	    if {$ix == $forwMark} {
		# end of previously found range
		Exmh_Debug <forw> | $rich($t,lookMark) $ix $curStack
		SeditRichLooks $t $rich($t,lookMark) $ix $curStack
		set rich($t,lookMark) $ix
		# Assert, only get here if no Looks ahead, so stack is just $key
		set curStack $key
		Exmh_Debug Stack => $curStack
	    }
	}
    }
    Exmh_Debug Stack := $curStack
    Exmh_Debug <end> | $rich($t,lookMark) $ix $curStack
    SeditRichLooks $t $rich($t,lookMark) $end $curStack
}
proc Sedit_TagClear { t start end } {
    global rich
    #
    # Called from a composer to clear looks in a text widget.
    #
    SeditRichReset $t
    #
    # The Looks for the range are a function of existing looks within
    # the range.  So, this new range will break up pre-existing looks
    # ranges and modify them.  The Looks tag includes the formatting
    # stack needed to compute the proper looks.
    #
    set end [$t index $end]
    set start [$t index $start]
    set rich($t,lookMark) $start
    set forwMark {}
    Exmh_Debug Sedit_TagClear $start $end
    for {set ix $start} {[$t compare $ix < $end]} {set ix [$t index "$ix +1c"]} {
	foreach tag [$t tag names $ix] {
	    if [regexp {Look=(.+)} $tag match stack] {
		$t tag remove $tag $ix $end
	    }
	    if [regexp {Mime[0-9]+=(.+)} $tag match stack] {
		$t tag remove $tag $ix $end
	    }
	}
    }
}

proc SeditRichReset { t } {
    global rich
    set rich($t,family) times
    set rich($t,sizes) {60 80 100 120 140 180 240}
    set rich($t,size) 120
    set rich($t,weight) medium
    set rich($t,slant) r
    set rich($t,underline) 0
    set rich($t,color) [option get $t foreground {}]
    if ![info exists rich($t,stack)] {
	set rich($t,stack) {}
    }
}
proc SeditMimeTag { t start end key } {
    global rich
    #
    # The Mime=foo tag is used when generating enriched text output.
    # They simply delimit the range to which a single look applies.
    # Used by SeditEnrichedExpand
    #
    if [info exists rich($t,mimetagcnt)] {
	set rich($t,mimetagcnt) [incr rich($t,mimetagcnt)]
    } else {
	set rich($t,mimetagcnt) 1
    }
    if [info exists rich($t,lastmark)] {
	if [$t compare $start > "$rich($t,lastmark) +1 c"] {
	    #
	    # Undo the tag in gaps between commands so that
	    # formatting does not "bleed" with inserted characters
	    #
	    $t tag remove $rich($t,lasttag) "$rich($t,lastmark) +1 c" $start
	}
	set rich($t,lastmark) $end
	set rich($t,lasttag) Mime$rich($t,mimetagcnt)=$key
    }
    $t tag add Mime$rich($t,mimetagcnt)=$key $start $end
}
proc SeditRichLooks { t start end stack } {
    global rich
    if {$start == $end} {
	return
    }
    SeditLooksFromStack $t $stack
    set font *-$rich($t,family)-$rich($t,weight)-$rich($t,slant)-*-*-*-$rich($t,size)-*-*-*-*-iso8859-*
    $t tag configure Look=$stack -underline $rich($t,underline)
    if [catch {
	$t tag configure Look=$stack -font $font 
    } err] {
	$t tag configure Look=$stack -font fixed \
	    -foreground black -background white
    }
    if [catch {
	$t tag configure Look=$stack -foreground $rich($t,color)
    } err] {
	$t tag configure Look=$stack -foreground black -background white
    }
    $t tag add Look=$stack $start $end
    #
    # This is used to undo look "bleeding" into subsequently inserted chars.
    #
    set rich($t,lastLook) Look=$stack
    set rich($t,lastLookEnd) $end
}
proc SeditLooksFromStack { t stack } {
    global rich
    set ignore 0
    SeditRichReset $t
    foreach look $stack {
	case $look {
	    default { incr ignore }
	    =* {
		set paramval [string range $look 1 end]
		set needsParam $paramval
	    }
	    x-plain { SeditRichReset $t }
	    x-color { set needsParam rich($t,color) }
	    fixed { set rich($t,family) courier }
	    underline { set rich($t,underline) 1 }
	    bold { set rich($t,weight) bold }
	    italic { set rich($t,slant) i }
	    smaller {
		set ix [lsearch $rich($t,sizes) $rich($t,size)]
		if {$ix > 0} {
		    incr ix -1
		    set rich($t,size) [lindex $rich($t,sizes) $ix]
		}
	    }
	    bigger {
		set ix [lsearch $rich($t,sizes) $rich($t,size)]
		incr ix
		if {$ix < [llength $rich($t,sizes)]} {
		    set rich($t,size) [lindex $rich($t,sizes) $ix]
		}
	    }
	}
    }
    return ignore
}
