#
# $Id$
#
# A text widget button that acts like a Button widget.
# - John Robert LoVerso
#
proc TextButton_Init { {t {}} } {
    global tkPriv

    set tkPriv(seed) 0
    if {[tk colormodel .] == "color"} {
	Preferences_Resource tkPriv(background)	c_uri thistle
	Preferences_Resource tkPriv(foreground)	c_uriFg black
	Preferences_Resource tkPriv(activebackground)	c_uriAbg white
	Preferences_Resource tkPriv(activeforeground)	c_uriAfg black
    } else {
	Preferences_Resource tkPriv(background)	c_uri black
	Preferences_Resource tkPriv(foreground)	c_uriFg white
	Preferences_Resource tkPriv(activebackground)	c_uriAbg white
	Preferences_Resource tkPriv(activeforeground)	c_uriAfg black
    }
    if {$t != {}} {
	# Hack - we know tags with names hdrlook=* are preserved.
	# These tags just serve to pre-allocate our colors
	$t tag configure hdrlook=TextButton1 -foreground $tkPriv(foreground) \
		-background $tkPriv(background)
	$t tag configure hdrlook=TextButton2 \
		-foreground $tkPriv(activeforeground) \
		-background $tkPriv(activebackground)
    }
}

proc TextButton { w text cmd } {

    $w insert insert { }
    set start [$w index insert]
    $w insert insert $text
    set end [$w index insert]
    $w insert insert { }

    set tag [TextButtonRange $w $start $end $cmd]
    global tk_version
    if {$tk_version < 4.0} {
	$w insert insert { }
	$w tag remove $tag $end insert
    }
}

proc TextButtonRange { w start end cmd } {
    global tkPriv tk_version

    incr tkPriv(seed)
    set id tkPriv$tkPriv(seed)
    $w tag add $id $start "$end +1 char"
    $w tag bind $id <Any-Enter> [concat TextButtonEnter $w $id]
    $w tag bind $id <Any-Leave> [concat TextButtonLeave $w $id]
    $w tag bind $id <1> [concat TextButtonDown $w $id]
    $w tag bind $id <ButtonRelease-1> [concat TextButtonUp $w $id [list $cmd]]
    if {$tk_version < 4.0} {
	$w tag bind $id <Any-ButtonRelease-1> [concat TextButtonUp $w $id]
    }
    $w tag configure $id -relief raised -borderwidth 2 \
	     -background $tkPriv(background) -foreground $tkPriv(foreground)
    return $id
}

#
#
# from button.tcl --
#

# The procedure below is invoked when the mouse pointer enters a
# button widget.  It records the button we're in and changes the
# state of the button to active unless the button is disabled.

proc TextButtonEnter {w id} {
    global tkPriv
    $w tag configure $id -background $tkPriv(activebackground) \
			-foreground $tkPriv(activeforeground)
    $w configure -cursor cross
    set tkPriv(window) $w
    set tkPriv(id) $id
}

# The procedure below is invoked when the mouse pointer leaves a
# button widget.  It changes the state of the button back to
# inactive.

proc TextButtonLeave {w id} {
    global tkPriv
    #puts "Leave"
    $w tag configure $id -background $tkPriv(background) \
			-foreground $tkPriv(foreground)
    $w configure -cursor xterm
    set tkPriv(window) ""
    set tkPriv(id) ""
    set tkPriv(cmd) ""
}

# The procedure below is invoked when the mouse button is pressed in
# a button/radiobutton/checkbutton widget.  It records information
# (a) to indicate that the mouse is in the button, and
# (b) to save the button's relief so it can be restored later.

proc TextButtonDown {w id} {
    global tkPriv
    set tkPriv(relief) [lindex [$w tag config $id -relief] 4]
    set tkPriv(buttonWindow) $w
    set tkPriv(buttonId) $id
    $w tag configure $id -relief sunken
}

# The procedure below is invoked when the mouse button is released
# for a button/radiobutton/checkbutton widget.  It restores the
# button's relief and invokes the command as long as the mouse
# hasn't left the button.

proc TextButtonUp {w id {cmd {}}} {
    global tkPriv
    #puts "Up"
    if {$w == $tkPriv(buttonWindow) && $id == $tkPriv(buttonId)} {
	$w tag config $id -relief $tkPriv(relief)
	if {$w == $tkPriv(window) && $id == $tkPriv(id)} {
	    set tkPriv(cmd) $cmd
	    #puts "Primed"
	    after 1 TextButtonActivate $w $id
	}
	set tkPriv(buttonWindow) ""
	set tkPriv(buttonId) ""
    }
}
proc TextButtonActivate {w id} {
    global tkPriv
    #puts "Activate cmd=$tkPriv(cmd)"
    eval $tkPriv(cmd)
}
