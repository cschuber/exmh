#
# $Id$
#
# Exmh drag&drop by John Robert LoVerso <john@loverso.southborough.ma.us>
# Selection export by Fred Douglis <douglis@research.att.com>
#

if {[info procs tlog-add] == ""} {proc tlog-add args {}}


set dragdrop(dragging) 0

#
# Attach routines
#

proc Drag_Attach {w selectfunc mod b} {
	if {$mod != ""} {append mod -}
	bind $w <$mod$b>		[list $selectfunc %W %X %Y %x %y]
	bind $w <${mod}B$b-Motion>	{DragMotion %X %Y}
	bind $w <Any-ButtonRelease-$b>	{Drop %X %Y}
}
proc Drop_Attach {w dropfunc} {
	global dragdrop
	set dragdrop($w,drop) $dropfunc
	lappend dragdrop(drops) $w
}

#
# Drag Source Initiation
#

#	set dragvar(source)	<source widget>
#	set dragvar(decorate)	<dragDecorationFunction>
#	set dragvar(callback)	<dropCallbackFunction>
#
# Data description:
#	set dragvar(types) {folder filename}
#		List of data types
#	set dragvar(data,folder) $folder
#	set dragvar(data,filename) $mhProfile(path)/$folder
#		One data variable for each type
#	set dragvar(formats) string
#	set dragvar(format,folder) string
#	set dragvar(format,filename) string
#		List of supported formats, one format per type
#	set dragvar(type,string) folder
#		Default or most appropriate type for given format
#
#	Drag_Source dragvar $x $y
#
# dragvar is linked to global dragging.  During drag, these are valid:
#	dragdrop(text)	text representation of data

proc Drag_Source {dragvar x y} {
	global dragdrop

	uplevel #0 "upvar #0 $dragvar dragging"
	global dragging

	#
	set dragdrop(text) $dragging(data,$dragging(type,string))
	set dragdrop(dragging) 1

tlog-add .t Drag_Start $dragdrop(text)

	set w [set dragdrop(w) .drag]
	if ![winfo exists $w] {
		toplevel $w -cursor hand2
	        wm group $w .
		wm transient $w .
		wm override $w 1
		wm withdraw $w
		update idletasks
	}

	set slaves [pack slaves $w]
	if {$slaves != {}} {
		eval pack forget $slaves
	}
	if [info exists dragging(decorate)] {
		$dragging(decorate) $w
	} else {
		DragDecorateSimple $w
	}

	# Allow geom to be updated
	update idletasks
	set dragdrop(yadj) [expr [winfo height $w] * 3 / 4]
	set dragdrop(xadj) [expr [winfo width $w] / 2]

	DragMotion $x $y
	wm deiconify $w
	wm override $w 1
	raise $w

	Drag_ExportString $dragdrop(text)
}

proc DragDecorateSimple {f} {
	global dragdrop

	set l $f.label
	if ![winfo exists $l] {
		label $l
	}
	pack $l
	$l config -text $dragdrop(text)
}

proc DragMotion {x y} {
	global dragdrop

	if !$dragdrop(dragging) return
	wm geom $dragdrop(w) \
		+[expr $x - $dragdrop(xadj)]+[expr $y - $dragdrop(yadj)]
}

proc Drop {x y} {
	global dragdrop

	if !$dragdrop(dragging) return
	set dragdrop(dragging) 0

	wm withdraw $dragdrop(w)
	set dropw [winfo containing $x $y]
	set func {}
	set w {}
	if {$dropw != {}} {
		foreach w [list $dropw [winfo toplevel $dropw]] {
			if [info exists dragdrop($w,drop)] {
				set func $dragdrop($w,drop)
				break;
			}
		}
		if {$func == {}} {
			foreach w $dragdrop(drops) {
				if [string match ${w}* $dropw] {
					set func $dragdrop($w,drop)
					break;
				}
			}
		}
	}

tlog-add .t Drop $dragdrop(text) on $x,$y --> $dropw ($func $w)

	if {$func != {}} {
		if [catch {$func $dropw $x $y} err] {
			tlog-add .t drop error $err
		}
	}

	global dragging
	if [info exists dragging(callback)] {
		if [catch {$dragging(callback) $dropw $x $y} err] {
			tlog-add .t callback error $err
		}
	}
}

#
# Interface to export selection
#

proc Drag_ExportString {s} {
    global dragdrop

    set dragdrop(exported) $s
    selection own $dragdrop(w) DragExportNothing
    selection handle $dragdrop(w) DragExportName
    Exmh_Status "$s is current selection"
}

proc DragExportName {offset maxBytes} {
    global dragdrop
    if [catch {set dragdrop(exported)} s] {
	return ""
    }
    return $s
}

proc DragExportNothing {} {
    global dragdrop
    if [catch {set dragdrop(exported)} s] return
    if [string match "$s is current selection" [Exmh_OldStatus]] {
	Exmh_Status ""
    }
    unset dragdrop(exported)
}
