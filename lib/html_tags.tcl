# tags.tcl --
#	Support for random tags, and some new ones, too.
# Copyright (c) 1995 by Sun Microsystems
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#

foreach tag {p div h1 h2 h3 h4 h5 h6} {
    proc HMtag_$tag {win param text} {
	set align ""
	HMextract_param $param align
	HMstack $win [list Tcenter $align]
    }
    proc HMtag_/$tag {win param text} {
	catch {HMstack/ $win [list Tcenter {}]}
    }
}

# pre is used in all sorts of wierd contexts,
# and adding H:pre to the list tags preserves it across
# whitespace added by some tags (e.g., hr)
proc HMtag_pre {win param text} {
    HMstack $win [list listtags H:pre]
}
proc HMtag_/pre {win param text} {
    catch {HMstack/ $win [list listtags]}
}

# Handle base tags.  This affects link references in subsequent
# img SRC= and a HREF= tags.  Note that <base> tags are used in cut & paste
# to preserve (or adjust) relative links when possible (or necessary).

proc HMtag_base {win param text} {
    upvar #0 HM$win var
    if [HMextract_param $param href Url] {
	if [info exists var(pasteMode)] {
	    set var(base) $Url
	    Exmh_Debug "Paste/Base $Url"
	    Mark_RemoveLast $win 
	} else {
	    set var(S_url) $Url
	    Exmh_Debug "Base $Url"
	}
    }
}

# downloading fonts can take a long time.  We'll override the default
# font-setting routine to permit better user feedback on fonts.  We'll
# keep our own list of installed fonts on the side, to guess when delays
# are likely

proc HMset_font {win tag font} {
	global Fonts
	set label [StatusLabel $win]	;# This may not exist for msg dialogs
	if {![info exists Fonts($font)]} {
		set Fonts($font) 1
		catch {$label configure -fg blue}
		Status $win "downloading font $font"
		set status 1
	}
	catch {$win tag configure $tag -font $font}
	if [info exists status] {
	    StatusLazy $win {}
	    catch {$label configure -fg black}
	}
}

# Lets invent a new HTML tag, just for fun.
# Change the color of the text. Use html tags of the form:
# <color value=blue> ... </color>
# We can invent a new tag for the display stack.  If it starts with "T"
# it will automatically get mapped directly to a text widget tag.

proc HMtag_color {win param text} {
	set value bad_color
	HMextract_param $param value
	HMstack $win "Tcolor $value"
	if [catch {$win tag configure $value -foreground $value}] {
	    catch {$win tag configure $value -foreground #$value}
	}
}

proc HMtag_/color {win param text} {
	catch {HMstack/ $win "Tcolor {}"}
}

# Add a font size manipulation primitive, so we can use this sample program
# for on-line presentations.  sizes prefixed with + or - are relative.
#  <font size=[+-]3>  ..... </font>.
# This is an approximation of the NetScape font tag

proc HMtag_font {win param text} {
    upvar #0 HM$win var
    set size 0; set sign ""
    if [HMextract_param $param size] {
	regexp {([+-])? *([0-9]+)} $size dummy sign size
	if {$sign != ""} {
	    set base [lindex $var(size) end]
	    set size [eval expr $base $sign $size]
	}
	if {$size < 1} {set size 1}
	if {$size > 7} {set size 7}
	HMstack $win "size $size"
	set var(font_size) $size
    }
    set color bad_color
    if [HMextract_param $param color] {
	HMstack $win "Tcolor $color"
	if [catch {$win tag configure $color -foreground $color}] {
	    catch {$win tag configure $color -foreground #$color}
	}
	set var(font_color) $color
    }
}

proc HMtag_/font {win param text} {
	upvar #0 HM$win var
	if [info exists var(font_size)] {
	    catch {HMstack/ $win "size {}"}
	    unset var(font_size)
	}
	if [info exists var(font_color)] {
	    catch {HMstack/ $win "Tcolor {}"}
	    unset var(font_color)
	}
}

# Crude hack to make tables somewhat nicer to read until real stuff is in place

if {[info commands HMtag_/tr] == ""} {

    proc HMtag_/tr {win param textVar} {
	    upvar #0 HM$win var
	    upvar $textVar text
	    MarkUndefined $win /tr $param text
	    Text_Insert $win $var(S_insert) \n $var(inserttags)
    }
    proc HMtag_tr {win param textVar} {
	    upvar #0 HM$win var
	    upvar $textVar text
	    MarkUndefined $win tr $param text
    }
}

proc HMtag_Verify {t param} {
    global htmlverify

    Exmh_Debug HMtag_Verify $t $param
    if [catch {frame $t.verify -bd 4 -relief ridge -class Dialog} f] {
	# dialog already up
	SeditAbortConfirm $t.abort $t abort
	return
    }
    Widget_Message $f msg -justify center -text "Are you sure you want to execute\n\n$param\n\n?"
    pack $f.msg -padx 10 -pady 10
    frame $f.but -bd 10 -relief flat
    pack $f.but -expand true -fill both
    Widget_AddBut $f.but yes "Yes" [list HMtag_VerifyConfirm $f yes] {left filly}
    Widget_AddBut $f.but no "No" [list HMtag_VerifyConfirm $f No] {right filly}
    Widget_PlaceDialog $t $f
    focus $f.but
    tkwait window $f

    if {$htmlverify == "yes"} {
	Exmh_Debug Evaluating $param
	eval $param
    }
}

proc HMtag_VerifyConfirm {f yes} {
    global htmlverify
    set htmlverify $yes
    destroy $f
}

proc HMtag_Wrapped {win param} {
    Exmh_Debug HMtag_Wrapped $win $param

    upvar #0 HM$win var
    set url $var(S_url)
    Exmh_Debug URL=$url
    if {![regexp -nocase {^file:} $url] || [regexp -nocase {^file:/tmp} $url]} {
	set index [lsearch -exact $param -command]
	if {$index != -1} {
	    incr index
	    set param [lreplace $param $index $index [list HMtag_Verify $win [lindex $param $index]]]
	}
    }
    Exmh_Debug HMtag_Wrapped returning $param
    return $param
}

proc HMtag_button {win param textVar} {
    upvar #0 HM$win var
    upvar $textVar text
    set b [eval {button $win.button$var(tags) -text $text} [HMtag_Wrapped $win $param]]
    Win_Install $win $b
    set text {}
}
proc HMtag_checkbutton {win param textVar} {
    upvar #0 HM$win var
    upvar $textVar text
    set b [eval {checkbutton $win.button$var(tags) -text $text} [HMtag_Wrapped $win $param]]
    Win_Install $win $b
    set text {}
}

