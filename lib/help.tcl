# help.tcl
#
# Help and color key.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Help_KeyDisplay {} {
    global fdisp

    if [Exwin_Toplevel .key "Exmh Key" Key] {
	set key .key
	set b .key.but

	set l [Widget_Label $b]
	if {[winfo depth .] > 4} {
	    $l configure -text "color"
	} else {
	    $l configure -text "monochrome"
	}

	set font $fdisp(font)

	set key [Widget_Frame .key rim Rim]
	$key configure -borderwidth 10
    
	set t [Widget_SimpleText $key t {top fillx} -width 34 -font $font -wrap none]
	$t configure -state normal
	$t delete 0.0 end

	set sequences [concat [option get . sequences {}] [option get . customsequences {}]]
	Exmh_Debug all: $sequences
	foreach sequence $sequences {
	    $t insert insert "$sequence\n"
	    $t tag add $sequence {insert - 1 line} insert
	    eval $t tag configure $sequence [option get . sequence_$sequence {}]
	}

	$t insert insert "\nFolder Label Bindings\n"
	$t insert insert "left          => change folder\n"
	$t insert insert "middle        => view subfolders\n"
	$t insert insert "right         => refile message(s)\n"
	$t insert insert "shift-right   => link message(s)\n"
	$t insert insert "shift-middle  => drag folder\n"
	$t insert insert "control-right => clear target"
	$t configure -state disabled
    
	set c [canvas $key.can -width 20 -height 30]
	pack append $key $c {top expand fill}
	set y [expr [lindex [$c configure -height] 4]/2]
	set x 4
	set x [HelpKeyLabel $c $x $y current $font curtext curbox]
	set x [HelpKeyLabel $c $x $y unseen $font unsntext unsnbox]
	set x [HelpKeyLabel $c $x $y moveTarget $font tartext tarbox]
	Fdisp_LabelConfigure $c
	set w [expr [lindex [$c bbox all] 2] + 5]
	set h [expr [lindex [$c bbox all] 3] + 5]
	$c config -width $w -height $h
    }
}
proc HelpKeyLabel { c x y text font texttag boxtag} {
    global fdisp
    set id [$c create text $x $y -text $text -anchor nw -font $font -tags $texttag]
    set box [Fdisp_Box $c $id leaf]
    $c addtag $boxtag withtag $box
    set bbox [$c bbox $box]
    incr x [expr [lindex $bbox 2]-[lindex $bbox 0]+$fdisp(xgap)]
    return $x
}

proc Help { {name {Intro}} {title {Help for exmh} }} {
    global exmh
    if [string match /* $name] {
	# absolute pathname
	set dir [file dirname $name]
	set file [file tail $name]
	set id help$file
	set topic $file
    } else {
	set dir $exmh(library)/html
	set file $dir/$name.html
	set id help$name
	set topic $name
    }
    if [string match *.html $file] {
	return [Html_Window file:$file]
    }
    regsub -all {\.} $id _ id
    if [Exwin_Toplevel .$id "Exmh $topic" Help] {
	Widget_Label .$id.but label {left fill} -text "  $title"

	set t [Widget_Text .$id 25 -setgrid true]
	bind $t <Key-Next> {%W yview scroll 1 page}
	bind $t <Key-Prior> {%W yview scroll -1 page}
	bind $t <Key-Home> {%W see 1.0}
	bind $t <Key-End> {%W see end}
	$t insert insert "EXMH Version: $exmh(version)\n"
	foreach d [list $dir .] {
	    if [catch {open $d/$file} in] {
		continue
	    }
	    $t insert insert [read $in]
	    close $in
	    # This is data-dependent..., but cute
	    if {$name == "Intro"} {
		set L 26
		$t tag add current $L.0 $L.end ; incr L
		$t tag add deleted $L.0 $L.end ; incr L
		$t tag add moved $L.0 $L.end ; incr L
		$t tag add unseen $L.0 $L.end ; incr L
	    }
	    $t configure -state disabled
	    scan [$t index end] %d height
	    if {$height < 25} {
		$t config -height $height
	    }
	    return $t
	}
	$t insert insert "Cannot find $file file to display"
	$t configure -state disabled
    }
    return .$id.t
}

