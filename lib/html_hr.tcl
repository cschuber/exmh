proc Hr_Init {win} {
	upvar #0 HM$win var
	$win tag configure hrShade -relief sunken -borderwidth 2
	$win tag configure hrNoShade -relief flat -borderwidth 2 \
	    -background black -foreground white
	$win tag bind hrShade <ButtonRelease-1> {Hr_Edit %W %x %y}
	$win tag bind hrNoShade <ButtonRelease-1> {Hr_Edit %W %x %y}
	set var(S_hrWidth) {}
	set var(S_hrSize) {}
	bind $win <Configure> {
	    HrConfig %W
	}
}
proc HMtag_hr {win param text} {
	upvar #0 HM$win var
	set size 2
	HMextract_param $param size
	if {[lsearch $var(S_hrSize) hrSize$size] < 0} {
	    foreach font [list [HMx_font times $size * *] \
				[HMx_font courier $size * *] \
				fixed] {
		if ![catch {$win tag configure hrSize$size -font $font}] {
		    lappend var(S_hrSize) hrSize$size
		    break
		}
	    }
	}
	set align center
	HMextract_param $param align
	set align [string toupper $align]
	set width 100%
	HMextract_param $param width
	if {[lsearch $var(S_hrWidth) hr$align$width] < 0} {
	    lappend var(S_hrWidth) hr$align$width
	    HrConfig $win	;# Config tag for width/alignment combination
	}
	if [HMextract_param $param noshade] {
	    set shade hrNoShade
	} else {
	    set shade hrShade
	}
	set tags "hrSize$size space"

	Text_Insert $win  $var(S_insert) "\n" "$tags $var(listtags)"
	Text_Insert $win  $var(S_insert) "\t" "$tags $shade hr$align$width $var(listtags)"
	Text_Insert $win  $var(S_insert) "\n" "$tags $var(listtags)"
}
# Called in response to configure events to adjust the size of hr rules.
proc HrConfig {win} {
	upvar #0 HM$win var
	foreach name $var(S_hrWidth) {
	    set width 100%
	    set align CENTER
	    regexp hr(LEFT|RIGHT|CENTER)(.+) $name x align width
	    set W [winfo width $win]
	    if [regexp (.+)% $width x relw] {
		set width [expr $W*$relw/100]
	    }
	    switch $align {
		LEFT	{$win tag configure $name -tabs $width}
		RIGHT	{
		    $win tag configure $name -lmargin1 [expr $W-$width]
		    $win tag configure $name -tabs $width
		}
		CENTER -
		default	{
		    set offset [expr ($W-$width)/2]
		    $win tag configure $name -lmargin1 $offset
		    $win tag configure $name -tabs [expr $width+$offset]
		}
	    }
	}
}

proc Hr_Edit {win x y} {
    upvar HM$win var

    set mark [$win mark prev @$x,$y]
    while {[string length $mark]} {
	set htag [Mark_Htag $win $mark]
	if {[string length $htag]} {
	    return [HrEdit $win $mark $htag]
	}
	set mark [$win mark prev $mark]
    }
}
proc HrEdit {win mark htag} {
    Mark_SplitTag $htag tag param
    set info [Dialog_Htag $win {hr width= align= shade=} $param "Horizontal Rule"]
    if {[llength $info] > 0} {
	set param [lindex $info 1]
	Text_MarkSet $win insert $mark
	Mark_ReadTags $win insert force
	Text_Delete $win insert "insert +2lines"
	Mark_Remove $win $mark
	Input_Html $win <[string trim "hr $param"]>
    }
}
