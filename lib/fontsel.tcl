# Font selection interface
# Font chapter

proc Font_Dialog {} {
    # The menus are big, so position the window
    # near the upper-left corner of the display
    global font fontreslist

    set t .fontsel
    if [Exwin_Toplevel .fontsel "Font Selection"] {

	$t.but.quit config -command Font_Dismiss

	button $t.but.reset -text "Clear Current" -command Font_Reset
	pack $t.but.reset -side right

	button $t.but.help -text "Help" -command {Help Font "Font Help"}
	pack $t.but.help -side right

	menubutton $t.but.widgets -text "Widget..." -menu $t.but.widgets.m
	set m [menu $t.but.widgets.m]

	set fontreslist {
	    *font
	    *Button.font
	    *Entry.font	
	    *Label.font	
	    *Message.font
	    *Listbox.font
	    *Text.font	
	    *fl_font	
	    *Ftoc*Text.font
	    *Msg*Text.font
	    *Sedit*Text.font
	} 
	foreach resource $fontreslist {
	    $m add command -label $resource -command "FontSetResource $resource \$font(current)"
	}
	pack $t.but.widgets -side left
	button $t.but.save -text "Save" -command Font_Save
	pack $t.but.save -side left

	button $t.but.clear -text "Reset All" -command Font_Clear
	pack $t.but.clear -side left

	label $t.but.warning -text "Listing Fonts..."
	pack $t.but.warning -side left
	
	# Set up a set of menus.  There is one for each
	# component of a font name, except that the two resolutions
	# are combined and the avgWidth is supressed.
	frame $t.menubar
	option add *$t.menubar*highlightThickness 0
	set font(comps) {foundry family weight slant swidth \
		adstyle pixels points res res2 \
		space avgWidth registry encoding}
	foreach x $font(comps) {
		# font lists all possible component values
		# current keeps the current component values
		set font(cur,$x) *
		set font($x) {}
		# Trim out the second resolution and the average width
		if {$x == "res2" || $x == "avgWidth"} {
		    continue
		}
		# The border and highlight thickness are set to 0 so the 
		# button texts run together into one long string.
		menubutton $t.menubar.$x -menu $t.menubar.$x.m -text -$x \
			-padx 0 -bd 0 -font fixed
		menu $t.menubar.$x.m
		pack $t.menubar.$x -side left
		# Create the initial wild card entry for the component
		$t.menubar.$x.m add radio -label * \
			-variable font(cur,$x) \
			-value * \
			-command [list FontList]
	}
	# Use traces to patch up the supressed font(comps)
	trace variable font(cur,res2) r FontTraceRes2
	trace variable font(cur,avgWidth) r FontTraceWidth
	# Mostly, but not always, the points are 10x the pixels
	trace variable font(cur,pixels) w FontTracePixels
	
	# Create a listbox to hold all the font names
	frame $t.body
	set font(list) [listbox $t.body.list \
		-setgrid true  \
		-yscrollcommand "$t.body.scroll set"]
	$font(list) config -selectmode browse
	scrollbar $t.body.scroll -command "$t.body.list yview"
	pack $t.body.scroll -side right -fill y
	pack $t.body.list -side left -fill both -expand true
	
	# Clicking on an item displays the font
	bind $font(list) <ButtonRelease-1> [list FontSelect $font(list) %y]
	  # This label displays the current font
	label $t.font -textvar font(current) -bd 5 -font fixed
	# A message displays a string in the font.
	set font(msg) [message $t.font2 -aspect 1000 -borderwidth 10]

    } else {
	# Delete existing menus
	foreach x $font(comps) {
	    if {$x == "res2" || $x == "avgWidth"} {
		continue
	    }
	    set first 1
	    catch {set first [$t.menubar.$x.m index {\*}]}
	    incr first
	    $t.menubar.$x.m delete $first end
	}
    }
    # Save the current font preferences.
    global fontOrig
    foreach line [Preferences_ReadSection "Font Resources" "End Fonts"] {
	if [regexp {^([^:]+): *(.+)$} $line x resource value] {
	    set fontOrig($resource) $value
	}
    }
    # Use the xlsfonts program to generate a
    # list of all fonts known to the server.
    $t.but.warning config -text "Querying fonts..."
    Exmh_Status "Listing fonts..."
    if [catch {open "|xlsfonts *"} in] {
	    puts stderr "xlsfonts failed $in"
	    exit 1
    }
    $t.but.warning config -text ""
    set font(num) 0
    set numAliases 0
    set font(N) 0
    while {[gets $in line] >= 0} {
	    $font(list) insert end $line
	    # fonts(all,$i) is the master list of existing fonts
	    # This is used to avoid potenially expensive
	    # searches for fonts on the server, and to
	    # highlight the matching font in the listbox
	    # when a pattern is specified.
	    set font(all,$font(N)) $line
	    incr font(N)
	
	    set parts [split $line -]
	    if {[llength $parts] < 14} {
		    # Aliases do not have the full information
		    lappend aliases $line
		    incr numAliases
	    } else {
		    incr font(num)
		    # Chop up the font name and record the
		    # unique font(comps) in the font array.
		    # The leading - in font names means that
		    # parts has a leading null element and we
		    # start at element 1 (not zero).
		    set i 1
		    foreach x $font(comps) {
			    set value [string trim [lindex $parts $i]]
			    incr i
			    if {[string length $value] &&
				[lsearch $font($x) $value] < 0} {
				    # Missing this entry, so add it
				    lappend font($x) $value
			    }
		    }
	    }
    }
    # Fill out the menus
    foreach x $font(comps) {
	    if {$x == "res2" || $x == "avgWidth"} {
		continue
	    }
	    set first 1
	    catch {set first [$t.menubar.$x.m index {\*}]}
	    incr first
	    set last [$t.menubar.$x.m index end]
	    if {$last > $first} {
		$t.menubar.$x.m delete $first end
	    }
	    if {$x == "pixels" || $x == "points"} {
		set vlist [lsort -command FontSizeSort $font($x)]
	    } else {
		set vlist [lsort $font($x)]
	    }
	    foreach value $vlist {
		    if {[string length $value] == 0} {
			    set label (nil)
		    } else {
			    set label $value
		    }
		    $t.menubar.$x.m  add radio -label $label \
			    -variable font(cur,$x) \
			    -value $value \
			    -command FontList
	    }
    }
    Exmh_Status "Found $font(num) fonts and $numAliases aliases"
    catch {unset fontres}
    
    set font(sampler) "
    ABCDEFGHIJKLMNOPQRSTUVWXYZ
    abcdefghijklmnopqrstuvwxyz
    0123456789
    !@#$%^&*()_+-=[]{};:'\"`~,.<>/?\\|
    "
    set font(errormsg) "
    
    (No matching font)
    
    
    "
    # Now pack the main display
    pack $t.menubar -side top -fill x
    pack $t.body -side top -fill both -expand true
    pack $t.font $font(msg) -side top

    Font_Reset
}
proc FontSizeSort {a b} {
    if {[string compare $a $b] == 0} {
	return 0
    }
    if {[string compare $a *] == 0} {
	return -1
    }
    if {[string compare $b *] == 0} {
	return -1
    }
    return [expr $a - $b]
}
proc FontTraceRes2 { args } {
	global font
	set font(cur,res2) $font(cur,res)
}
proc FontTraceWidth { args } {
	global font
	set font(cur,avgWidth) *
}
proc FontTracePixels { args } {
	global font
	catch {
	    # Might not be a number
	    set font(cur,points) [expr 10*$font(cur,pixels)]
	}
}

proc FontList {  } {
	global font
	set font(current) {}
	foreach x $font(comps) {
	    append font(current) -$font(cur,$x)
	}
	FontSet
}
proc FontSelect { list y } {
	# Extract a font name from the listbox
	global font
	set ix [$font(list) nearest $y]
	set font(current) [$font(list) get $ix]
	set parts [split $font(current) -]
	if {[llength $parts] < 14} {
		foreach x $font(comps) {
			set font(cur,$x) {}
		}
	} else {
		set i 1
		foreach x $font(comps) {
			set value [lindex $parts $i]
			incr i
			set font(cur,$x) $value
		}
	}
	FontSet
}
proc FontSet {} {
	global font
	# Generate a regular expresson from the font pattern
	regsub -all -- {\(nil\)} $font(current) {} font(current)
	regsub -all -- {\*} $font(current) {[^-]*} pattern
	for {set n 0} {$n < $font(N)} {incr n} {
		if [regexp -- $pattern $font(all,$n)] {
		    if ![catch {
			$font(msg) config -font $font(current) \
				-text $font(sampler)
			}] {
			    catch {$font(list) select clear \
				    [$font(list) curselection]}
			    $font(list) select set $n
			    $font(list) see $n
			    return
			}
		}
	}
	$font(msg) config -text $font(errormsg)
}

proc Font_Reset {} {
	global font
	foreach x $font(comps) {
		set font(cur,$x) *
	}
	FontList
	Exmh_Status "$font(num) fonts"
}

proc FontSetResource {resource {value fixed} {whom .} {classlist {}}} {
    global fontres
    # Special case folder display labels with their pseudo-resource
    if [regexp {^(\*fl_font|\*font)$} $resource] {
	global fdisp
	set fdisp(font) $value 
	set fontres(*fl_font) $value
	if [regexp {^(\*fl_font)$} $resource] {
	    return
	}
    }
    set reslist [split $resource .*]
    set n [llength $reslist] ; incr n -1
    set attr [lindex $reslist $n] ; incr n -1
    set newlist {}
    foreach r [lrange $reslist 1 $n] {
	lappend newlist [string tolower $r]
    }
    .fontsel.but.warning config -text "Setting font..."
    FontSetResourceInner $attr $resource $newlist $value $whom $classlist
    .fontsel.but.warning config -text ""

}
proc FontSetResourceInner {attr resource reslist value whom classlist} {
    global font fontres

    lappend classlist [string tolower [winfo class $whom]]
#    Exmh_Status "$attr: $reslist $whom $classlist"

    set hit 1
    foreach class $reslist {
	if {[lsearch -glob $classlist *$class] < 0} {
	    set hit 0
	    break
	}
    }
    if {$hit} {
	Exmh_Status "$whom => $value"
	catch {
	    $whom config -[string tolower $attr] $value
	    option add $resource $value
	    set fontres($resource) $value
	    if {$resource == "*Button.font"} {
		foreach r {Menubutton Checkbutton Radiobutton Menu} {
		    option add *$r.font $value
		    set fontres(*$r.font) $value
		}
	    }
	}
    }
    foreach child [winfo children $whom] {
	FontSetResourceInner $attr $resource $reslist $value $child $classlist
    }
}
proc Font_Save {} {
    global font fontres fontreslist fontOrig
    foreach resource [concat $fontreslist *Menubutton.font *Checkbutton.font *Radiobutton.font *Menu.font] {
	if [info exists fontres($resource)] {
	    set fontOrig($resource) $fontres($resource)
	}
	if [info exists fontOrig($resource)] {
	    lappend newstuff [format "%s\t%s" ${resource}: $fontOrig($resource)]
	}
    }
    if [info exists newstuff] {
	Preferences_RewriteSection "Font Resources" "End Fonts" $newstuff
	catch {unset fontres}
    }
}
proc Font_Clear {} { 
    global font fontres fontreslist fontOrig exmh
    Preferences_RewriteSection "Font Resources" "End Fonts" {}
    catch {unset fontres}
    catch {unset fontOrig}
    Preferences_Reset
    foreach child [winfo children .] {
	FontClear $child
    }
    global fdisp
    set fdispFont [option get . fl_font {}]
    if [catch { set fdisp(font) $fdispFont} ] {	;# error in trace proc
	set fdisp(font) fixed
    }
}
proc FontClear {w} {
    set default [option get $w font {}]
    if {[string length $default] == 0} {
	catch {lindex [$w config -font] 3} default
    }
    if [catch {$w config -font $default}] {
	catch {$w config -font fixed}
    }
    foreach child [winfo children $w] {
	FontClear $child
    }
}
proc Font_Dismiss {} {
    global fontres
    if [info exists fontres] {
	Font_Save 
    }
    Exwin_Dismiss .fontsel
}
