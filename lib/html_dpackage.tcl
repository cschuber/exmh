# Simple HTML display library by Stephen Uhler (stephen.uhler@sun.com)
# Copyright (c) 1995 by Sun Microsystems
# Version 0.3 Thu Aug 31 14:11:29 PDT 1995
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# To use this package,  create a text widget (say, .text)
# and set a variable full of html, (say $html), and issue:
#	HMinit_win .text
#	HMparse_html $html "HMrender .text"
# You also need to supply the routine:
#   proc HMlink_callback {win href} { ...}
#      win:  The name of the text widget
#      href  The name of the link
# which will be called anytime the user "clicks" on a link.
# The supplied version just prints the link to stdout.
# In addition, if you wish to use embedded images, you will need to write
#   proc HMset_image {handle src}
#      handle  an arbitrary handle (not really)
#      src     The name of the image
# Which calls
#	HMgot_image $handle $image
# with the TK image.
#
# To return a "used" text widget to its initialized state, call:
#   HMreset_win .text
# See "sample.tcl" for sample usage
##################################################################
############################################
# mapping of html tags to text tag properties
# properties beginning with "T" map directly to text tags

# These are Defined in HTML 2.0

array set HMtag_map {
	address {style i}
	b      {weight bold}
	big	{size 5}
	blockquote	{indent 1 Trindent rindent}
	bq		{indent 1 Trindent rindent}
	cite   {style i}
	code   {size 3 family courier}
	dfn    {style i}	
	dir    {indent 1}
	dl     {indent 1}
	em     {style i}
	h1     {size 6 weight bold Tspace hspacebig family times}
	h2     {size 5 weight bold Tspace hspacebig family times}		
	h3     {size 4 weight bold Tspace hspacemid family times}	
	h4     {size 3 weight bold Tspace hspacemid family times}
	h5     {size 2 weight bold Tspace hspacemid family times}
	h6     {size 1 Tspace hspacesml family times}
	i      {style i}
	kbd    {family courier weight bold}
	menu     {indent 1}
	ol     {indent 1}
	pre    {fill 0 family courier size 3 Tnowrap nowrap}
	samp   {size 3 family courier}		
	small {size 2}
	strong {weight bold}
	sup	{size 2 Tsup sup}
	sub	{size 2 Tsup sub}
	tt     {size 3 family courier}
	u	{Tunderline underline}
	ul     {indent 1}
	var    {style i}	
}

# This correspond to the Netscape font sizes 1 to 7

array set HMsize_map {
    "" ""
    1 10
    2 12
    3 14
    4 18
    5 20
    6 24
    7 36
}

# These are in common(?) use, but not defined in html2.0

array set HMtag_map {
	center {Tcenter center}
	strike {Tstrike strike}
	u	{Tunderline underline}
}

# initial values

set HMtag_map(hmstart) {
	family times   weight medium   style r   size 3
	Tcenter ""   Tlink ""   Tnowrap ""   Tunderline ""   list list
	fill 1   indent "" counter 0 adjust 0
	Tspace hspacep
}
proc HMdefault_font {win} {
    upvar #0 HM$win var
    global HMsize_map
    HMx_font times $HMsize_map(3) medium r $var(S_adjust_size)
}

############################################
# initialize the window and stack state

proc HMinit_win {win} {
	global window
	upvar #0 HM$win var
	
	HMinit_state $win
	$win tag configure underline -underline 1
	$win tag configure center -justify center
	$win tag configure left -justify left
	$win tag configure right -justify right
	$win tag configure nowrap -wrap none
	$win tag configure rindent -rmargin $var(S_tab)c
	$win tag configure strike -overstrike 1
	$win tag configure mark -foreground red			;# list markers
	if {$window(colorAnchor)} {
	    $win tag configure anchor -foreground purple
	}
	$win tag configure HTML -foreground #880 -background #d9d9d9    
	$win tag configure SHTML -foreground #800 -background #d9d9d9 \
		-relief ridge -borderwidth 2

	# Restore foreground/background 'cause <Body> tag can change it.
	$win config -background [lindex [$win config -background] 3]
	$win config -foreground [lindex [$win config -foreground] 3]

	$win tag configure hspacebig -spacing1 10p -spacing3 6p
	$win tag configure hspacemid -spacing1 6p -spacing3 3p
	$win tag configure hspacesml -spacing1 3p -spacing3 3p
	$win tag configure hspacep -spacing1 3p -spacing3 3p
	$win tag configure compact -spacing1 1p -spacing3 0p
	$win tag configure abovebr -spacing3 0p
	$win tag configure belowbr -spacing1 0p

	$win tag configure sup -offset 3	;# superscript
	$win tag configure sub -offset -3	;# subscript


	$win tag bind link <Button-1> [list Url_Hit? $win %x %y]
	$win tag bind link <Shift-Button-1> [list Url_HitNew $win %x %y]
	$win tag bind link <Double-Button-1> [list Url_Edit $win %x %y]

	HMset_indent $win $var(S_tab)
	$win configure -wrap word

	# configure the text insertion point
	$win mark set $var(S_insert) 1.0

	# for horizontal rules
	Hr_Init $win

	bind $win <Configure> {
	    %W tag configure last -spacing3 %h
	}
	bind TScroll <Key-Next> {%W yview scroll 1 page}
	bind TScroll <Key-Prior> {%W yview scroll -1 page}
	bind TScroll <Key-Home> {%W see 1.0}
	bind TScroll <Key-End> {%W see end}

}

# set the indent spacing (in cm) for lists
# TK uses a "weird" tabbing model that causes \t to insert a single
# space if the current line position is past the tab setting

proc HMset_indent {win cm} {
    $win configure -tabs [expr $cm / 2.0]c
    foreach i {1 2 3 4 5 6 7 8 9} {
	set indent [expr $i * $cm]
	$win tag configure indent$i -lmargin1 ${indent}c -lmargin2 ${indent}c \
	    -tabs "[expr $indent + $cm/2.0]c [expr $indent + $cm]c" \
	    -rmargin ${cm}c
    }
}

# reset the state of window - get ready for the next page
# remove all but the font tags, and remove all form state

proc HMreset_win {win {clear 1}} {
	upvar #0 HM$win var
	if $clear {
	    eval $win mark unset [$win mark names]
	    $win delete 0.0 end
	    # configure the text insertion point
	    $win mark set $var(S_insert) 1.0
	}
	$win tag configure hr -tabs [winfo width $win]

	Head_ResetColors $win
	Form_Reset $win
	catch {Table_Reset $win}
	Image_Reset $win
	HMinit_state $win
	return HM$win
}

# initialize the window's state array
# Parameters beginning with S_ are NOT reset
#  adjust_size:		global font size adjuster
#  unknown:		character to use for unknown entities
#  tab:			tab stop (in cm)
#  stop:		enabled to stop processing
#  update:		how many tags between update calls
#  tags:		number of tags processed so far
#  symbols:		Symbols to use on un-ordered lists

proc HMinit_state {win} {
	upvar #0 HM$win var
	array set tmp [array get var S_*]
	catch {unset var}
	array set var {
		stop 0
		tags 0
		fill 0
		list list
		listtags ""
		S_adjust_size 0
		S_tab 1.0
		S_unknown \xb7
		S_update 10
		S_symbols O*=+-o\xd7\xb0>:\xb7
		S_insert Insert
	}
	array set var [array get tmp]
}

# alter the parameters of the text state
# this allows an application to over-ride the default settings
# it is called as: HMset_state -param value -param value ...

array set HMparam_map {
	-update S_update
	-tab S_tab
	-unknown S_unknown
	-stop stop
	-size S_adjust_size
	-symbols S_symbols
    -insert S_insert
}

proc HMset_state {win args} {
	upvar #0 HM$win var
	global HMparam_map
	set bad 0
	if {[catch {array set params $args}]} {return 0}
	foreach i [array names params] {
		incr bad [catch {set var($HMparam_map($i)) $params($i)}]
	}
	return [expr $bad == 0]
}

############################################
# manage the display of html

# HMrender gets called for every html tag
#   win:   The name of the text widget to render into
#   tag:   The html tag (in arbitrary case)
#   not:   a "/" or the empty string
#   param: The un-interpreted parameter list
#   text:  The plain text until the next html tag

proc HMrender {win tag not param text} {
	global HMtag_map BreakMap
	upvar #0 HM$win var
	if {$var(stop)} return

	set tag [string tolower $tag]
	set text [HMmap_esc $text]
	incr var(tags)			;# Counter used for UID's

	# Divert table contents
	if [info exists var(tableHandler)] {
		if [catch {eval $var(tableHandler) {$tag $not $param text}} err] {
		    Stderr $err
		}
		return
	}

	# adjust (push or pop) tag state
	catch {HMstack$not $win $HMtag_map($tag)}

	# to fill or not to fill
	set fill [lindex $var(fill) end]
	if $fill {
		set text [HMzap_white $text]
	}
	# Break the line, if necessary
	if [info exists BreakMap($tag)] {
	    if $fill {
		set text [string trimleft $text]
	    }
	    if ![info exists var(newline)] {
		dputs "newline"
		Text_Insert $win $var(S_insert) \n "space $var(listtags)"
		set var(newline) 1
		set var(trimspace) 1
		catch {unset var(Tbr)}	;# br hack
	    }
	}

	# generic mark hook to support the editor
	if [catch {HMmark $win $tag $not $param text} err] {
	    dputs "HMmark $err"
	}

	# do any special tag processing

	if [catch {HMtag_$not$tag $win $param text} msg] {
	    if {[info command HMtag_$not$tag] != {}} {		;# dputs
		global errorInfo				;# dputs
		Exmh_Debug "HMtag_$not$tag: $errorInfo"	;# dputs
	    }							;# dputs
	}
	if {$fill && [info exists var(trimspace)]} {
	    set text [string trimleft $text]
	}
	if {[string compare $text ""] != 0} {
	    catch {unset var(trimspace)}
	    catch {unset var(newline)}
	}

	# HMcurrent_tags has side effects.  Call even if text is empty
	set tags [HMcurrent_tags $win]

	# Fix here to do something better with &nbsp; which is \0xa0

	Text_Insert $win $var(S_insert) $text $tags

	# We need to do an update every so often to insure interactive response.
	# This can cause us to re-enter the event loop, and cause recursive
	# invocations of HMrender, so we need to be careful.
	if {!($var(tags) % $var(S_update))} {
		update
	}
}

# html tags requiring special processing
# Procs of the form HMtag_<tag> or HMtag_</tag> get called just before
# the text for this tag is displayed.  These procs are called inside a 
# "catch" so it is OK to fail.
#   win:   The name of the text widget to render into
#   param: The un-interpreted parameter list
#   text:  A pass-by-reference name of the plain text until the next html tag
#          Tag commands may change this to affect what text will be inserted
#          next.

# A pair of pseudo tags are added automatically as the 1st and last html
# tags in the document.  The default is <HMstart> and </HMstart>.
# Append enough blank space at the end of the text widget while
# rendering so HMgoto can place the target near the top of the page,
# then remove the extra space when done rendering.

proc !HMtag_hmstart {win param text} {
	upvar #0 HM$win var
	$win mark gravity $var(S_insert) left
	$win insert end "\n " last
	$win mark gravity $var(S_insert) right
}

proc !HMtag_/hmstart {win param text} {
	$win delete last.first end
}

# put the document title in the window banner, and remove the title text
# from the document

proc !HMtag_title {win param text} {
	upvar $text data
	dputs $data
	wm title [winfo toplevel $win] $data
	set data ""
}


proc HMtag_br {win param text} {
	upvar #0 HM$win var
	# Insert the newline without the "space" tag to preserve
	# the surrounding node's tag range
	Text_Insert $win insert \n $var(inserttags)
	set var(newline) 1
	set var(trimspace) 1
	# Patch up the spacing tag on the previous line
	Text_TagAdd $win abovebr "$var(S_insert) -1 line linestart"  "$var(S_insert) -1 line lineend"
	# Set up spacing tag for the next line
	HMstack $win "Tbr belowbr"
}

# list element tags

# <ol type= start=>
# type is 1, A, a, i, I to indicate numbering style
# start is a number, always decimal, giving starting number of first <li>

proc HMtag_ol {win param text} {
    upvar #0 HM$win var
    set start 1
    if [HMextract_param $param start] {
	set var(count$var(level)) [incr start -1]
    } else {
	set var(count$var(level)) 0
    }
    set type 1
    if [HMextract_param $param type] {
	set var(oltype$var(level)) $type
    } else {
	catch {unset var(oltype$var(level)}
    }
    catch {unset var(menu$var(level))}
    HMlist_open $win $param ol $var(level)
}
proc HMtag_/ol {win param text} {
    catch {unset var(menu$var(level))}	;# See Mark_ReadTags ol hack
    HMlist_close $win
}
proc HMtag_ul {win param text} {
    upvar #0 HM$win var
    catch {unset var(count$var(level))}
    catch {unset var(menu$var(level))}
    HMlist_open $win $param ul $var(level)
}
proc HMtag_/ul {win param text} {
    HMlist_close $win
}

proc HMtag_menu {win param text} {
    upvar #0 HM$win var
    set var(menu$var(level)) ->
    HMlist_open $win $param menu $var(level)
}
proc HMtag_/menu {win param text} {
    upvar #0 HM$win var
    HMlist_close $win
}
	
proc HMtag_dir {win param text} {
    upvar #0 HM$win var
    catch {unset var(count$var(level))}
    catch {unset var(menu$var(level))}
    HMlist_open $win $param dir $var(level)
}
proc HMtag_/dir {win param text} {
    upvar #0 HM$win var
    HMlist_close $win
}
	
proc HMtag_dl {win param text} {
    upvar #0 HM$win var
    catch {unset var(count$var(level))}
    catch {unset var(menu$var(level))}
    HMlist_open $win $param dl $var(level)
    HMstack $win [list dlevel $var(level)]
}
proc HMtag_/dl {win param text} {
    upvar #0 HM$win var
    HMstack/ $win [list dlevel {}]
    HMlist_close $win
}
	
proc HMtag_dt {win param text} {
	upvar #0 HM$win var
	upvar $text data

	if ![info exists var(dlevel)] {
	    return	;# No <dl> tag
	}
	set dlevel [lindex $var(dlevel) end]
	if {$dlevel == {}} {
	    return
	}
	# Normally var(level) is 1 inside a list, but the out-dented terms
	# need to be at indent0

	if {$var(level) > $dlevel} {
	    set var(indent) [lreplace $var(indent) end end]
	    incr var(level) -1
	}
	Text_Insert $win $var(S_insert) "$data" \
		"indent$var(level) $var(font) $var(listtags)"
	catch {unset var(newline)}
	catch {unset var(trimspace)}
	set data {}
}
proc HMtag_dd {win param text} {
	upvar #0 HM$win var
	if ![info exists var(dlevel)] {
	    return	;# No <dl> tag
	}
	set dlevel [lindex $var(dlevel) end]
	if {$dlevel == {}} {
	    return
	}
	# assert var(level) is equal var(dlevel) because of tag_dt,
	# and that this is one-less than normal for lists
	if {$var(level) == $dlevel} {
	    lappend var(indent) 1
	    incr var(level)
	}
}

proc HMtag_li {win param text} {
	upvar #0 HM$win var
	set level $var(level)
	incr level -1
	set x [string index $var(S_symbols)+-+-+-+-" $level]
	catch {set x [incr var(count$level)]}
	catch {set x [HMol_number $var(oltype$level) $var(count$level)]}
	catch {set x $var(menu$level)}
	Text_Insert $win $var(S_insert) \t$x\t "mark indent$level $var(font) $var(listtags)"
	catch {unset var(newline)}
}
proc HMol_number {type count} {
	switch -- $type {
	    A -
	    a {
		# Count a, b, c, ..., z, aa, ab, ac, ..., az, ba, bb, bc
		# which is odd, because in the '1's position a means 0,
		# but in the '10's and '100's position a means 1...
		# (imagine lists count from 0: a => 0, but aa => 10) 
		scan $type %c A
		set result ""
		while {$count > 0} {
		    set result [format %c [expr $A + (($count-1) % 26)]]$result
		    set count [expr ($count-1) / 26]
		}
		return $result
	    }
	    i -
	    I {
		# Count with roman numbers
		# i, ii, iii, iv, v, vi, viii, ix, x
		set one I ; set five V ; set ten X
		set result ""
		while {$count > 0} {
		    set frac [expr $count % 10]
		    switch $frac {
			1 {set result $one$result}
			2 {set result $one$one$result}
			3 {set result $one$one$one$result}
			4 {set result $one$five$result}
			5 {set result $five$result}
			6 {set result $five$one$result}
			7 {set result $five$one$one$result}
			8 {set result $five$one$one$one$result}
			9 {set result $one$ten$result}
		    }
		    set count [expr $count / 10]
		    switch $one {
			I {set one X ; set five L ; set ten C}
			X {set one C ; set five D ; set ten M}
			C {set one M ; set five ? ; set ten !}
			default {set one ! ; set five # ; set ten @}
		    }
		}
		if {$type == "i"} {
		    return [string tolower $result]
		} else {
		    return $result
		}
	    }
	    1 -
	    default { 
		return $count
	    }
	}
}
array set HMromanI {
    I	1
    V	5
    X	10
    L	50
    C	100
    D	500
    M	1000
}
array set HMromani {
    i	1
    v	5
    x	10
    l	50
    c	100
    d	500
    m	1000
}

# The Tspace tag is used for inter-line spacing.
# The listtags variable is used to label newlines w/in lists

proc HMlist_open {win param ltag level} {
    if {[HMextract_param $param compact] ||
	[string compare $ltag "dl"] == 0} {
	set space compact
    } else {
	set space hspacep
    }
    set x [list Tspace $space listtags $space]
    lappend x listtags [string trim "H:$ltag=[incr level] $param"]
    HMstack $win $x
}
# The catch protects against extra close tags
proc HMlist_close {win} {
    if ![catch {HMstack/ $win {listtags {}}}] {
	catch {HMstack/ $win {Tspace {} listtags {}}}
    }
}

# Manage hypertext "anchor" links.  A link can be either a source (href)
# a destination (name) or both.  If its a source, register it via a callback,
# and set its default behavior.  If its a destination, check to see if we need
# to go there now, as a result of a previous HMgoto request.  If so, schedule
# it to happen with the closing </a> tag, so we can highlight the text up to
# the </a>.

proc HMtag_a {win param text} {
	upvar #0 HM$win var
	dputs $param

	# Clean up any state from unclosed <a> tags
	HMtag_/a $win {} {}

	# a source

	if {[HMextract_param $param href] && [info exists href]} {
		set var(Lref) $href
		HMlink_setup $win "a $param"
		set var(Tlink) link
	}

	# a frame specifier

	if {[HMextract_param $param target] && [info exists target]} {
		set var(Fref) $target
	}

	# a destination

	if {[HMextract_param $param name] && [info exists name]} {
		$win mark set N:$name "$var(S_insert) - 1 chars"
		$win mark gravity N:$name left
		set var(Tanchor) anchor
		if {[info exists var(goto)] && $var(goto) == $name} {
			dputs "scheduling move to target $name"
			unset var(goto)
			set var(going) $name
		}
	}
}

# The application should call here with the fragment name
# to cause the display to go to this spot.
# If the target exists, go there (and do the callback),
# otherwise schedule the goto to happen when we see the reference.

proc HMgoto {win where {callback HMwent_to}} {
	upvar #0 HM$win var
	dputs "looking to goto $where"
	if {![catch {$win index N:$where} ix]} {
		dputs "Found goto target - going there"
		scan $ix %d line
		scan [$win index end] %d lastline
		$win yview moveto [expr $line.0 / $lastline.0]
#		$win see N:$where
		update
		eval $callback $win [list $where]
		return 1
	} else {
		dputs "Target not found, queued"
		set var(goto) $where
		return 0
	}
}

# We actually got to the spot, so highlight it!
# This should/could be replaced by the application
# We'll flash it orange a couple of times.

proc HMwent_to {win where {count 0} {color orange}} {
	upvar #0 HM$win var
	if {$count > 5} return
	catch {$win tag configure N:$where -foreground $color}
	update
	after 200 [list HMwent_to $win $where [incr count] \
				[expr {$color=="orange" ? "" : "orange"}]]
}

proc HMtag_/a {win param text} {
	upvar #0 HM$win var
	catch {unset var(Lref)}
	catch {unset var(Fref)}
	catch {unset var(Tlink)}
	catch {unset var(Tanchor)}
	catch {unset var(T,a)}

	# goto this link, then invoke the call-back.

	if {[info exists var(going)]} {
		$win yview N:$var(going)
		update
		HMwent_to $win $var(going)
		unset var(going)
	}
}


# Sample hypertext link callback routine - should be replaced by app
# This proc is called once for each <A> tag.
# Applications can overwrite this procedure, as required, or
# replace the HMevents array
#   win:   The name of the text widget to render into
#   href:  The HREF link for this <a> tag.

array set HMevents {
	Enter	{-borderwidth 2 -relief raised }
	Leave	{-borderwidth 2 -relief flat }
	1		{-borderwidth 2 -relief sunken}
	ButtonRelease-1	{-borderwidth 2 -relief flat}
}

# extract a value from parameter list (this needs a re-do)
# returns "1" if the keyword is found, "0" otherwise
#   param:  A parameter list.  It should alredy have been processed to
#           remove any entity references
#   key:    The parameter name
#   val:    The variable to put the value into (use key as default)

proc HMextract_param {param key {val ""}} {

	if {$val == ""} {
		upvar $key result
	} else {
		upvar $val result
	}
	dputs looking for $key in <$param>
    set ws " \t\n\r"
 
    # look for name=value combinations.  Either (') or (") are valid delimeters
    if {
      [regsub -nocase [format {.*[%s'"]+%s[%s]*=[%s]*"([^"]*).*} $ws $key $ws $ws] " $param" {\1} value] ||
      [regsub -nocase [format {.*[%s'"]+%s[%s]*=[%s]*'([^']*).*} $ws $key $ws $ws] " $param" {\1} value] ||
      [regsub -nocase [format {.*[%s'"]+%s[%s]*=[%s]*([^%s]+).*} $ws $key $ws $ws $ws] " $param" {\1} value] } {
        set result $value
        dputs $key -> $value
        return 1
    }

	# now look for valueless names
	# I should strip out name=value pairs, so we don't end up with "name"
	# inside the "value" part of some other key word - some day
	
	set bad \[^a-zA-Z\]+
	if {[regexp -nocase  "$bad$key$bad" -$param-]} {
		dputs got $key
		return 1
	} else {
		dputs Nope
		return 0
	}
}

# These next two routines manage the display state of the page.

# Push or pop tags to/from stack.
# Each orthogonal text property has its own stack, stored as a list.
# The current (most recent) tag is the last item on the list.
# HMstack pushes, and HMstack/ pops

proc HMstack {win list} {
    upvar #0 HM$win var
    foreach {stack value} $list {
	lappend var($stack) $value
    }
}
proc HMstack/ {win list} {
    upvar #0 HM$win var
    foreach {stack value} $list {
	set var($stack) [lreplace $var($stack) end end]
    }
}

# extract set of current text tags
# tags starting with T map directly to text tags, all others are
# handled specially.  There is an application callback, HMset_font
# to allow the application to do font error handling

proc HMcurrent_tags {win} {
	global HMsize_map
	upvar #0 HM$win var
	set font font
	foreach i {family size weight style} {
		set $i [lindex $var($i) end]
		append font :[set $i]
	}
	set xfont [HMx_font $family $HMsize_map($size) $weight $style $var(S_adjust_size)]
	HMset_font $win $font $xfont
	set indent [llength $var(indent)]
	incr indent -1
#	if {$indent < 0} {
#	    set var(indent) {}
#	    set indent 0
#	}
	lappend tags $font indent$indent
	foreach tag [array names var T*] {
		set x [lindex $var($tag) end]
		if [string length $x] {
			lappend tags $x
		}
	}
	set var(font) $font
	set var(xfont) [$win tag cget $font -font]
	set var(level) $indent
	set var(inserttags) $tags
	return $tags
}

# allow the application to do do better font management
# by overriding this procedure

proc !HMset_font {win tag font} {
	catch {$win tag configure $tag -font $font} msg
}

# generate an X font name
proc HMx_font {family size weight style {adjust_size 0}} {
	catch {incr size $adjust_size}
	return "-*-$family-$weight-$style-normal-*-*-${size}0-*-*-*-*-*-*"
}

############################################
# Turn HTML into TCL commands
#   html    A string containing an html document
#   cmd		A command to run for each html tag found
#   start	The name of the dummy html start/stop tags

proc HMparse_html {html {cmd HMtest_parse} {start hmstart}} {
	regsub -all \{ $html {\&ob;} html
	regsub -all \} $html {\&cb;} html
	regsub -all {\\} $html {\&bsl;} html
	set w " \t\r\n"	;# white space
	proc HMcl x {return "\[$x\]"}
	set exp <(/?)([HMcl ^$w>]+)[HMcl $w]*([HMcl ^>]*)>
	set sub "\}\n$cmd {\\2} {\\1} {\\3} \{"
	regsub -all $exp $html $sub html
	eval "$cmd {$start} {} {} \{$html\}"
	eval "$cmd {$start} / {} {}"
}

proc HMtest_parse {command tag slash text_after_tag} {
	puts "==> $command $tag $slash $text_after_tag"
}

# Convert multiple white space into a single space

proc HMzap_white {data} {
	regsub -all "\[ \t\r\n\]+" $data " " data
	return $data
}

# find HTML escape characters of the form &xxx;

proc HMmap_esc {text} {
	if {![regexp & $text]} {return $text}
	regsub -all {([][$\\])} $text {\\\1} new
	regsub -all {&#([0-9][0-9]?[0-9]?);?} \
		$new {[format %c [scan \1 %d tmp;set tmp]]} new
	regsub -all {&([a-zA-Z]+)(;?)} $new {[HMdo_map \1 \\\2 ]} new
	return [subst $new]
}
# convert an HTML escape sequence into character
proc HMdo_map {text {semi {}}} {
	global HMesc_map
	set result &$text$semi
	catch {set result $HMesc_map($text)}
	return $result
}

# Encode special characters in the form &xxx;
proc HMmap_code {text} {
	if {![regexp \[<>&\x80-\xff\] $text]} {return $text}
	regsub -all {([][$\\])} $text {\\\1} new
	regsub -all (\[<>&\x80-\xff\]) $new {[HMdo_code \\\1]} new
	return [subst $new]
}
proc HMdo_code {text} {
	global HMcode_map
	if [info exists HMcode_map($text)] {
	    return &$HMcode_map($text)\;
	} else {
	    return $text
	}
}

# table of escape characters (ISO latin-1 esc's are in a different table)

array set HMesc_map {
   lt <   gt >   amp &   quot \"  bsl \\  
   ob \x7b   cb \x7d   nbsp \xa0
}
# Some folks like capitals, which are non-standard
array set HMesc_map {
   LT <   GT >   AMP &   QUOT \"   NBSP \xa0
}
#############################################################
# ISO Latin-1 escape codes

array set HMesc_map {
	nbsp \xa0 iexcl \xa1 cent \xa2 pound \xa3 curren \xa4
	yen \xa5 brvbar \xa6 sect \xa7 uml \xa8 copy \xa9
	ordf \xaa laquo \xab not \xac shy \xad reg \xae
	hibar \xaf deg \xb0 plusmn \xb1 sup2 \xb2 sup3 \xb3
	acute \xb4 micro \xb5 para \xb6 middot \xb7 cedil \xb8
	sup1 \xb9 ordm \xba raquo \xbb frac14 \xbc frac12 \xbd
	frac34 \xbe iquest \xbf Agrave \xc0 Aacute \xc1 Acirc \xc2
	Atilde \xc3 Auml \xc4 Aring \xc5 AElig \xc6 Ccedil \xc7
	Egrave \xc8 Eacute \xc9 Ecirc \xca Euml \xcb Igrave \xcc
	Iacute \xcd Icirc \xce Iuml \xcf ETH \xd0 Ntilde \xd1
	Ograve \xd2 Oacute \xd3 Ocirc \xd4 Otilde \xd5 Ouml \xd6
	times \xd7 Oslash \xd8 Ugrave \xd9 Uacute \xda Ucirc \xdb
	Uuml \xdc Yacute \xdd THORN \xde szlig \xdf agrave \xe0
	aacute \xe1 acirc \xe2 atilde \xe3 auml \xe4 aring \xe5
	aelig \xe6 ccedil \xe7 egrave \xe8 eacute \xe9 ecirc \xea
	euml \xeb igrave \xec iacute \xed icirc \xee iuml \xef
	eth \xf0 ntilde \xf1 ograve \xf2 oacute \xf3 ocirc \xf4
	otilde \xf5 ouml \xf6 divide \xf7 oslash \xf8 ugrave \xf9
	uacute \xfa ucirc \xfb uuml \xfc yacute \xfd thorn \xfe
	yuml \xff
}

foreach x [array names HMesc_map] {
    set HMcode_map($HMesc_map($x)) $x
}
set HMcode_map(\\) \\x5c


# do x-www-urlencoded character mapping
# The spec says: "non-alphanumeric characters are replaced by '%HH'"
 
set HMalphanumeric	a-zA-Z0-9	;# definition of alphanumeric character class
for {set i 1} {$i <= 256} {incr i} {
    set c [format %c $i]
    if {![string match \[$HMalphanumeric\] $c]} {
        set HMform_map($c) %[format %.2x $i]
    }
}

# These are handled specially
array set HMform_map {
    " " +   \n %0d%0a
}

# 1 leave alphanumerics characters alone
# 2 Convert every other character to an array lookup
# 3 Escape constructs that are "special" to the tcl parser
# 4 "subst" the result, doing all the array substitutions
 
proc HMmap_reply {string} {
    global HMform_map HMalphanumeric
    regsub -all \[^$HMalphanumeric\] $string {$HMform_map(&)} string
    regsub -all \n $string {\\n} string
    regsub -all \t $string {\\t} string
    regsub -all {[][{})\\]\)} $string {\\&} string
    return [subst $string]
}

# There is a bug in the tcl library focus routines that prevents focus
# from every reaching an un-viewable window.  Use our *own*
# version of the library routine, until the bug is fixed, make sure we
# over-ride the library version, and not the otherway around

auto_load tkFocusOK
 proc tkFocusOK w {
    set code [catch {$w cget -takefocus} value]
    if {($code == 0) && ($value != "")} {
    if {$value == 0} {
        return 0
    } elseif {$value == 1} {
        return 1
    } else {
        set value [uplevel #0 $value $w]
        if {$value != ""} {
        return $value
        }
    }
    }
    set code [catch {$w cget -state} value]
    if {($code == 0) && ($value == "disabled")} {
    return 0
    }
    regexp Key|Focus "[bind $w] [bind [winfo class $w]]"
}
# simple stuff to support interactive variable tracing
# Module prefix is T
#  - print value any time global variable changes

# Basic Usage:
#  T			print variables with traces
#  T <x>		put a write trace on variable <x>
#  X <x>		remove trace on variable <x>

# print traced variable (standard trace function)

proc Tprint {n1 n2 op} {
	upvar $n1 value

	set level [expr [info level] - 1]
	if {$level > 0} {
		set proc [lindex [info level $level] 0]
	} else {
		set proc Toplevel
	}
	if {$n2 == ""} {
		puts "TRACE: $n1 = $value (in $proc)"
	} else {
		puts "TRACE: ${n1}($n2) = $value($n2) (in $proc)"
	}
}

# set [or query] a global variable trace
proc T {{_x_ "?"} {op w} {function Tprint}} {
	global $_x_ Traces
	if {$_x_ == "?"} {
		Stderr "Current traces:"
		catch "parray Traces"
	} elseif {[info exists Traces($_x_)]} {
		Stderr "Replacing existing trace for $_x_"
	} else {
		Stderr "Setting trace for $_x_"
		set Traces($_x_) $op
	}
	trace variable $_x_ $op $function
}

# delete all traces on a variable

proc X {{_x_ ?}} {
	global $_x_ Traces
	if {$_x_ == "?"} {
		Stderr "Usage: X <var_name> (remove trace on var_name>"
		return ""
	}
	catch "unset Traces($_x_)"
	foreach trace [trace vinfo $_x_] {
		Stderr "Trace remove: $_x_ $trace"
		eval "trace vdelete $_x_ $trace"
	}
}
# simple puts style debugging support
# Module Prefix is "D"
# The array Dholds all of the state info for the debugger
# Interface:
#   Don:	turn on debugging
#     D(print): list of patterns that cause printing
#     D(break): list of patterns that cause break points
#   Doff:	turn off debugging

proc Dtrace { args } {
    global D
    eval lappend D(print) $args
}
proc Don {} {
	global D
	foreach x {print break} {
	    if ![info exists D($x)] {set D($x) {} }
	}
#	Stderr "Debugging enabled"
	proc dputs {args} {
		global D
		set level [expr [info level] - 1]
		set caller toplevel
		catch {set caller [lindex [info level $level] 0]}
		foreach i $D(print) {
			if {[string match $i $caller]} {
				Stderr "$caller: $args"
				break;
			}
		}
		if {[string match $D(break) $caller]} {
			Deval
		}
	}
}

proc Doff {} {
	global D
#	Stderr "Debugging disabled"
	proc dputs {args} {}
}

# read-print-eval loop for debugging

proc Deval {} {
	set maxlevel [expr [info level] -1]
	set level $maxlevel
	set ok 1
	Dshow $level
	while {$ok} {
		puts -nonewline stderr "#$level: "
		gets stdin line
		while {![info complete $line]} {
			puts -nonewline stderr "? "
			append line \n[gets stdin]
		}
		switch -- $line {
			+	{if {$level < $maxlevel} {Dshow [incr level]}}
			-	{if {$level > 0} {Dshow [incr level -1]}}
			C   {set ok 0}
			?   {Dshow $level}
			G	{
				catch { uplevel #0 [lrange $line 1 end]} result
				Stderr $result
			}
			W	{
				for {set l $level} {$l > 0} {incr l -1}  {
				    Dshow $l
				}
			}
			default {
				catch { uplevel #$level $line } result
				Stderr $result
			}
		}
	}
	Stderr "Resuming Execution"
}

# display state of this stack level

proc Dshow {level} {
	if {$level <=0} {
		Stderr "At top level"
		return
	}
	set info [info level $level]
	set proc [lindex $info 0]
	Stderr "Procedure $proc {[info args $proc]}"
	set index 0
	foreach arg [info args $proc] {
		Stderr "\t$arg = [lindex $info [incr index]]"
	}
	set locals [uplevel #$level "info locals"]
	set all [uplevel #$level "info vars"]
	Stderr "\tlocals: $locals"
	foreach i $locals {set local($i) 1}
	set globals ""
	foreach i $all {
		if {![info exists local($i)]} {lappend globals $i}
	}
	Stderr "\tglobals: $globals"
}

proc !Dshow {current} {
  if {$current > 0} {
    set info [info level $current]
    set proc [lindex $info 0]
    Stderr "$current: Procedure $proc {[info args $proc]}"
    set index 0
    foreach arg [info args $proc] {
      Stderr "\t$arg = [lindex $info [incr index]]"
    }
  } else {
    Stderr "Top level"
  }
}

# for convenience

proc ? {} {
	global errorInfo
	Stderr $errorInfo
}
if {[info commands dputs]  == ""} {
	Doff
}
