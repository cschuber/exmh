#
# $Id$
#
# A text widget button that acts like a Button widget.
# - John Robert LoVerso
#
proc TextButton_Init { {t {}} } {
    global ::tk::Priv

    set ::tk::Priv(seed) 0
    if {[winfo depth .] > 4} {
	Preferences_Resource ::tk::Priv(background)	c_uri thistle
	Preferences_Resource ::tk::Priv(foreground)	c_uriFg black
	Preferences_Resource ::tk::Priv(activebackground)	c_uriAbg white
	Preferences_Resource ::tk::Priv(activeforeground)	c_uriAfg black
    } else {
	Preferences_Resource ::tk::Priv(background)	c_uri black
	Preferences_Resource ::tk::Priv(foreground)	c_uriFg white
	Preferences_Resource ::tk::Priv(activebackground)	c_uriAbg white
	Preferences_Resource ::tk::Priv(activeforeground)	c_uriAfg black
    }
    if {$t != {}} {
	# Hack - we know tags with names hdrlook=* are preserved.
	# These tags just serve to pre-allocate our colors
	$t tag configure hdrlook=TextButton1 -foreground $::tk::Priv(foreground) \
		-background $::tk::Priv(background)
	$t tag configure hdrlook=TextButton2 \
		-foreground $::tk::Priv(activeforeground) \
		-background $::tk::Priv(activebackground)
    }
}

proc TextButton { w text cmd } {

    $w insert insert { }
    set start [$w index insert]
    $w insert insert $text
    set end [$w index insert]
    $w insert insert { }

    set tag [TextButtonRange $w $start $end $cmd]
}

proc TextButtonRange { w start end cmd } {
    global ::tk::Priv

    incr ::tk::Priv(seed)
    set id ::tk::Priv$::tk::Priv(seed)
    $w tag add $id $start "$end +1 char"
    $w tag bind $id <Any-Enter> [concat TextButtonEnter $w $id]
    $w tag bind $id <Any-Leave> [concat TextButtonLeave $w $id]
    $w tag bind $id <1> [concat TextButtonDown $w $id]
    $w tag bind $id <ButtonRelease-1> [concat TextButtonUp $w $id [list $cmd]]
    $w tag configure $id -relief raised -borderwidth 2 \
	     -background $::tk::Priv(background) -foreground $::tk::Priv(foreground)
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
    global ::tk::Priv
    $w tag configure $id -background $::tk::Priv(activebackground) \
			-foreground $::tk::Priv(activeforeground)
    $w configure -cursor cross
    set ::tk::Priv(window) $w
    set ::tk::Priv(id) $id
}

# The procedure below is invoked when the mouse pointer leaves a
# button widget.  It changes the state of the button back to
# inactive.

proc TextButtonLeave {w id} {
    global ::tk::Priv
    #puts "Leave"
    $w tag configure $id -background $::tk::Priv(background) \
			-foreground $::tk::Priv(foreground)
    $w configure -cursor [option get $w cursor Text ]
    set ::tk::Priv(window) ""
    set ::tk::Priv(id) ""
    set ::tk::Priv(cmd) ""
}

# The procedure below is invoked when the mouse button is pressed in
# a button/radiobutton/checkbutton widget.  It records information
# (a) to indicate that the mouse is in the button, and
# (b) to save the button's relief so it can be restored later.

proc TextButtonDown {w id} {
    global ::tk::Priv
    set ::tk::Priv(relief) [lindex [$w tag config $id -relief] 4]
    set ::tk::Priv(buttonWindow) $w
    set ::tk::Priv(buttonId) $id
    $w tag configure $id -relief sunken
}

# The procedure below is invoked when the mouse button is released
# for a button/radiobutton/checkbutton widget.  It restores the
# button's relief and invokes the command as long as the mouse
# hasn't left the button.

proc TextButtonUp {w id {cmd {}}} {
    global ::tk::Priv
    #puts "Up"
    if {$w == $::tk::Priv(buttonWindow) && $id == $::tk::Priv(buttonId)} {
	$w tag config $id -relief $::tk::Priv(relief)
	if {$w == $::tk::Priv(window) && $id == $::tk::Priv(id)} {
	    set ::tk::Priv(cmd) $cmd
	    #puts "Primed"
	    after 1 TextButtonActivate $w $id
	}
	set ::tk::Priv(buttonWindow) ""
	set ::tk::Priv(buttonId) ""
    }
}
proc TextButtonActivate {w id} {
    global ::tk::Priv
    #puts "Activate cmd=$::tk::Priv(cmd)"
    eval $::tk::Priv(cmd)
}
