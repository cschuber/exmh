#
# rich2tk.tcl
#
# Written by Chris Garrigues <cwg@mcc.com> to be integrated into exmh
#

proc Rich_Init {} {
    global richCommands

    if [info exists richCommands] {
	return
    }

    set commands [concat [option get . richCommands {}] \
			 [option get . richUCommands {}]]
    Exmh_Debug RichCommands $commands
    if {[llength $commands] == 0} {
	set commands {bold italic fixed smaller bigger underline
		      indent verbatim param excerpt center nl lt}
    }

    set richCommands(vars) {}
    foreach command $commands {
	set func [option get . rich_$command {}]
	if {$func != {}} {
	    set richCommands(command,$command) $func
	}
	set var [option get . richVar_$command {}]
	    if {$var != {}} {
		set richCommands(var,$command) $var
		if ![regexp $var $richCommands(vars)] {
		    lappend richCommands(vars) $var
	    }
	}
	set inc [option get . richInc_$command {}]
	if {$inc != {}} {
	    set richCommands(inc,$command) $inc
	}
    }
    if {$richCommands(vars) != {}} {
	foreach var $richCommands(vars) {
	    set init [option get . richInit_$var {}]
	    if {$init != {}} {
		set richCommands(init,$var) $init
	    }
	}
    } else {
	set richCommands(vars)	{boldDepth italicDepth fixedDepth size \
				 underDepth indent verbatim paramDepth \
				 excerptDepth center}

	set richCommands(command,bold)		Rich_FontChange
	set richCommands(var,bold)		boldDepth
	set richCommands(command,italic)	Rich_FontChange
	set richCommands(var,italic)		italicDepth
	set richCommands(command,fixed)		Rich_FontChange
	set richCommands(var,fixed)		fixedDepth
	set richCommands(init,size)		120
	set richCommands(command,smaller)	Rich_FontChange
	set richCommands(var,smaller)		size
	set richCommands(inc,smaller)		-20
	set richCommands(command,bigger)	Rich_FontChange
	set richCommands(var,bigger)		size
	set richCommands(inc,bigger)		20

	set richCommands(var,underline)		underDepth
	set richCommands(command,underline)	Rich_UnderlineChange

	set richCommands(var,indent)		indent
	set richCommands(inc,indent)		4

	set richCommands(var,verbatim)		verbatim

	set richCommands(var,param)		paramDepth

	set richCommands(var,excerpt)		excerptDepth
	set richCommands(command,excerpt)	Rich_ExcerptChange

	# We don't really do centering; 	we just indent a bunch
	set richCommands(var,center)		center

	# These are here for richtext compatibility
	set richCommands(command,nl)		Rich_NewLine
	set richCommands(command,lt)		Rich_LessThan
    }
    # Hack to get MIME preferences
    global mime
    if [info exists mime(fontSize)] {
	set richCommands(init,size) $mime(fontSize)
    }
}

proc Rich_Display {w fileIO part type} {
    global rich

    Rich_Init
    catch {unset rich}
    set rich(part) $part
    Rich_DisplayString $w [read $fileIO] $type
}
proc Rich_DisplayString {w string type} { 
    global rich richCommands mime

    set unknown {}
    foreach var $richCommands(vars) {
	if [info exists richCommands(init,$var)] {
	    set rich($var) $richCommands(init,$var)
	} else {
	    set rich($var) 0
	}
    }
    set rich(depth) 0
    Rich_FontChange $w 1
    while {[string length $string] > 0} {
	if [regexp "^(\[^\n<]*)<<(.*)" $string \
		    match hdr tail] {
	    if $rich(paramDepth) {
		append rich(param,[expr {$rich(depth) - 1}]) "$hdr<"
	    } else {
		$w insert insert "$hdr<"
		if {$rich(verbatim) || ($type == "richtext")} {
		    $w insert insert "<"
		}
	    }
	    set string $tail
	} else {
	    if [regexp "^(\[^\n<]*)<(\[^<>]*)>(.*)" $string \
		       match hdr command tail] {
		set command [string tolower $command]
		if $rich(paramDepth) {
		    append rich(param,[expr {$rich(depth) - 1}]) $hdr
		} else {
		    $w insert insert $hdr
		}
		if $rich(verbatim) {
		    if {$command == {/verbatim}} {
			set rich(verbatim) 0
		    } elseif $rich(paramDepth) {
			$w append rich(param,[expr {$rich(depth) - 1}]) "<$command>"
		    } else {
			$w insert insert "<$command>"
		    }
		} else {		
		    set in [expr {[string index $command 0] != "/"}]
		    if $in {
			incr rich(depth)
			set rich(param,$rich(depth)) {}
		    } else {
			incr rich(depth) -1
			set command [string range $command 1 end]
		    }
		    if [info exists richCommands(var,$command)] {
			if [info exists richCommands(inc,$command)] {
			    set inc $richCommands(inc,$command)
			} else {
			    set inc 1
			}
			if !$in {
			    set inc [expr -$inc]
			}
			incr rich($richCommands(var,$command)) $inc
		    }
		    if [info exists richCommands(command,$command)] {
			$richCommands(command,$command) $w $in
		    } elseif ![info exists richCommands(var,$command)] {
			lappend unknown $command
		    }
		}
		set string $tail
	    } else {
		if [regexp "^(\[^\n<]*)\n(\n*)(.*)" $string \
			   match hdr crlfs tail] {
		    if $rich(paramDepth) {
			append rich(param,[expr {$rich(depth) - 1}]) $hdr$crlfs
		    } else {
			$w insert insert $hdr
			if $rich(verbatim) {
			    $w insert insert "\n$crlfs"
			} elseif {$crlfs == ""} {
			    $w insert insert " "
			} else {
			    if {$type == "richtext"} {
				for {set i 0} {$i < [string length $crlfs]} {incr i} {
				    $w insert insert " "
				}
			    } else {
				$w insert insert $crlfs
				Rich_Indentation $w
			    }
			}
		    }
		    set string $tail
		} else {
		    if [regexp "^(\[^\n<]*<)(.*)" $string \
			       match hdr tail] {
			if $rich(paramDepth) {
			    append rich(param,[expr {$rich(depth) - 1}]) $hdr
			} else {
			    $w insert insert $hdr
			}
			set string $tail
		    } else {
			if $rich(paramDepth) {
			    append rich(param,[expr {$rich(depth) - 1}]) $string
			} else {
			    $w insert insert $string
			}
			set string ""
		    }
		}
	    }
	}
    }

    Rich_ClearColor $w
    Rich_ClearExcerpt $w
    set rich(boldDepth) 0
    set rich(italicDepth) 0
    set rich(fixedDepth) 1
    set rich(size) 120
    Rich_FontChange $w 0
    Rich_ClearUnderline $w
    $w insert insert \n
    if {([string length $unknown] != 0) && $mime(showRichCmnds)} {
	$w insert insert "Unknown richtext commands: $unknown\n"
    }
    Rich_ClearFontChanges $w
}

proc Rich_NewLine {w in} {
    $w insert insert \n
    Rich_Indentation $w
}

proc Rich_Indentation {w} {
    global rich

    if $rich(center) {
	$w insert insert "\t\t"
    } else {
	for {set i 0} {$i < $rich(indent)} {incr i} {
	    $w insert insert " "
	}
    }
}

proc Rich_LessThan {w in} {
    $w insert insert "<"
}

proc Rich_FontChange {w in} {
    global rich

    set newFont [Rich_GetFont $w $rich(boldDepth) $rich(italicDepth) \
			      $rich(fixedDepth) $rich(size) \
			      [Mime_GetCharset $w $rich(part)]]
    if {![info exists rich(font,current)] ||
	($newFont != $rich(font,current))} {
        if ![info exists rich(font,lastChange)] {
	    set rich(font,lastChange) 1.0
        }
        if {$rich(font,lastChange) != [$w index insert]} {
	    if [info exists rich(font,current)] {
	        set tagName [MimeLabel $rich(font,current) font]
	        MimeRememberTag $w $tagName
	        $w tag add $tagName $rich(font,lastChange) insert
	    }
        }
	set rich(font,current) $newFont
	set tagName [MimeLabel $newFont font]
	$w tag add $tagName end
	$w tag configure $tagName -font $rich(font,current)
	set rich(font,lastChange) [$w index insert]
	MimeRaiseTag $w $tagName [MimeLabel $rich(part) part]
    }
}

proc Rich_ClearFontChanges {w} {
    global rich

    if {$rich(font,lastChange) != [$w index insert]} {
	if [info exists rich(font,current)] {
	    $w tag add Font=$rich(font,current) $rich(font,lastChange) insert
	    MimeRememberTag $w Font=$rich(font,current)
	}
    }
    catch {unset rich(font,current)}
    catch {unset rich(font,lastChange)}
}

proc Rich_UnderlineChange {w in} {
    global rich

    Rich_ClearUnderline $w
    if {($rich(under,on) && ($rich(underDepth) == 0)) ||
	(!$rich(under,on) && ($rich(underDepth) > 0))} {
	set rich(under,lastChange) [$w index insert]
	set rich(under,on) [expr !$rich(under,on)]
    }
}

proc Rich_ClearUnderline {w} {
    global rich

    if ![info exists rich(under,on)] {
	set rich(under,on) 0
    }
    if {[info exists rich(under,lastChange)] &&
	($rich(under,lastChange) != [$w index insert])} {
	if $rich(under,on) {
	    $w tag add Underline $rich(under,lastChange) insert
	    $w tag configure Underline -underline 1
	    MimeRaiseTag $w Underline [MimeLabel $rich(part) part]
	} else {
	    $w tag remove Underline $rich(under,lastChange) insert
	}
    }
}

proc Rich_Color {w in} {
    global rich

    if $in {
	set depth $rich(colorDepth)
	Rich_ClearColor $w $depth
	set rich(colorStart,$depth) [$w index insert]
	$w tag add colorDummy=$rich(depth) end
	if {$depth == 1} {
	    MimeRaiseTag $w colorDummy=$depth [MimeLabel $rich(part) part]
	} else {
	    MimeRaiseTag $w colorDummy=$depth colorDummy=[expr {$depth - 1}]
	}
    } else {
	set color $rich(param,[expr {$rich(depth) + 1}])
	regsub -nocase {^([0-9A-F][0-9A-F][0-9A-F][0-9A-F]),([0-9A-F][0-9A-F][0-9A-F][0-9A-F]),([0-9A-F][0-9A-F][0-9A-F][0-9A-F])$} $color {#\1\2\3} color
	set depth [expr {$rich(colorDepth) + 1}]
	set rich(colorTag,$depth) Color=$color

	$w tag add $rich(colorTag,$depth) end
	$w tag lower $rich(colorTag,$depth)
	$w tag add $rich(colorTag,$depth) $rich(colorStart,$depth) insert
	$w tag configure $rich(colorTag,$depth) -foreground $color
	MimeRaiseTag $w $rich(colorTag,$depth) dummy=$depth
	$w tag delete dummy=$depth
	Rich_ClearColor $w [expr {$depth + 1}]
	set rich(colorEnd,$depth) [$w index insert]
    }
}

proc Rich_ClearColor {w {depth default}} {
    global rich

    if [info exists rich(colorDepth)] {
	if [regexp {default} $depth] {
	    set depth [expr {$rich(colorDepth) + 1}]
	}
	if [info exists rich(colorTag,$depth)] {	
	    $w tag remove $rich(colorTag,$depth) $rich(colorEnd,$depth) insert
	    unset rich(colorEnd,$depth) 
	    unset rich(colorTag,$depth)
	}
    }
}

proc Rich_ExcerptChange {w in} {
    global mimeHdr rich

    if $in {
	set depth $rich(excerptDepth)
	Rich_ClearExcerpt $w $depth
	set rich(excerptStart,$depth) [$w index insert]
	set color $mimeHdr($rich(part),color)
	for {set i 0} {$i < $depth} {incr i} {
	    set color [MimeDarkerColor $w $color]
	}
	set rich(excerptTag,$depth) Background=$color
	if ![regexp $rich(excerptTag,$depth) [$w tag names]] {
	    $w tag add $rich(excerptTag,$depth) end
	    $w tag lower $rich(excerptTag,$depth)
	}
	if {$depth == 1} {
	    MimeRaiseTag $w $rich(excerptTag,$depth) \
			 [MimeLabel $rich(part) part]
	} else {
	    MimeRaiseTag $w $rich(excerptTag,$depth) \
			 $rich(excerptTag,[expr {$depth - 1}])
	}
	$w tag configure $rich(excerptTag,$depth) -background $color
    } else {
	set depth [expr {$rich(excerptDepth) + 1}]
	$w tag add $rich(excerptTag,$depth) $rich(excerptStart,$depth) insert
	set rich(excerptEnd,$depth) [$w index insert]
	Rich_ClearExcerpt $w [expr {$depth + 1}]
	unset rich(excerptStart,$depth)
    }
}

proc Rich_ClearExcerpt {w {depth default}} {
    global rich

    if [regexp {default} $depth] {
	set depth [expr {$rich(excerptDepth) + 1}]
    }
    if [info exists rich(excerptTag,$depth)] {
	$w tag remove $rich(excerptTag,$depth) $rich(excerptEnd,$depth) insert
	unset rich(excerptTag,$depth)
	unset rich(excerptEnd,$depth)
    }
}

proc Rich_GetFont {w bold italic fixed size charset} {
    if {$bold > 0} {
	set weight bold
    } else {
	set weight medium
    }
    if {$italic > 0} {
	set slant i
    } else {
	set slant r
    }
    if {$fixed > 0} {
	set fontSet fixed
    } else {
	set fontSet proportional
    }
    Mime_GetFont $w $weight $slant $fontSet $size $charset
}
