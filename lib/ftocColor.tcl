# 
# ftocColor.tcl
#
# Color and Monochrome feedback for the ftoc display.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Ftoc_ColorConfigure { text } {
    global exmh ftoc
    if [catch {
	if {[tk colormodel .] == "monochrome"} {
	    set fg [option get $text foreground Foreground]
	    set bg [option get $text background Background]
	    $text tag configure currentBg \
		-bgstipple {}
	    $text tag configure current \
		-foreground $bg -background $fg
	    $text tag configure deleted \
		-bgstipple @$exmh(library)/linethru.bitmap \
		-foreground $fg -background $fg
	    $text tag configure moved \
		-bgstipple gray25 -foreground $fg -background $fg
	    $text tag configure range \
		-foreground $fg -background $bg \
		-relief raised -borderwidth 2
	    $text tag configure mrange \
		-bgstipple gray25 -background $fg -background $fg \
		-relief raised -borderwidth 2
	    $text tag configure drange \
		-bgstipple @$exmh(library)/linethru.bitmap \
		-foreground $fg -background $fg \
		-relief raised -borderwidth 2
	    $text tag configure unseen -underline true
	} else {
	    set bg [lindex [$text configure -background] 4]
	    set fg [lindex [$text configure -foreground] 4]
	    Preferences_Resource ftoc(c_current) 	c_current red
	    Preferences_Resource ftoc(c_currentBg) 	c_currentBg $bg
	    Preferences_Resource ftoc(c_unseen) 	c_unseen  blue
	    Preferences_Resource ftoc(c_unseenBg) 	c_unseenBg $bg
	    Preferences_Resource ftoc(c_moved) 	c_moved   yellow
	    Preferences_Resource ftoc(c_movedFg) 	c_movedFg   $fg
	    Preferences_Resource ftoc(c_deleted) 	c_deleted grey75
	    Preferences_Resource ftoc(c_deletedFg) 	c_deletedFg $fg
            Preferences_Resource ftoc(c_selectedFg)     c_selectedFg $fg
            Preferences_Resource ftoc(c_selectedBg)     c_selectedBg #ececec
	    $text tag configure unseen \
		-foreground $ftoc(c_unseen) -background $ftoc(c_unseenBg)
	    $text tag configure currentBg \
		-background $ftoc(c_currentBg)
	    $text tag configure deleted \
		-background $ftoc(c_deleted)  -foreground $ftoc(c_deletedFg)
	    $text tag configure moved \
		-background $ftoc(c_moved) -foreground $ftoc(c_movedFg)
	    $text tag configure range \
                -foreground $ftoc(c_selectedFg) \
                -background $ftoc(c_selectedBg) \
		-relief raised -borderwidth 2
	    $text tag configure mrange \
		    -background $ftoc(c_moved) -foreground $ftoc(c_movedFg) \
		    -relief raised -borderwidth 2
	    $text tag configure drange \
		    -background $ftoc(c_deleted) -foreground $ftoc(c_deletedFg) \
		    -relief raised -borderwidth 2
	    $text tag configure current \
		-foreground $ftoc(c_current)
	}
    } err] {
	catch {puts stderr "Ftoc_ColorConfigure: $err"}
	Exmh_Debug Ftoc_ColorConfigure: $err
    }
}

