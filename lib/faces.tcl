# 
# faces.tcl
#
# facesaver support (bitmap display of who sent a message).
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

#### Faces support

set faces(debug) 0
proc Dputs args { global faces; if $faces(debug) {puts $args} }
set faces(timing) 0
proc Tputs args { global faces; if $faces(timing) {puts $args} }

# Compute faces search path
proc Face_SetPath {} {
    global faces env faceCache

    catch {unset faceCache}

    if ![info exists faces(sets)] {
	if [info exists faces(set)] {
	    # backwards compatibility with old "exmh" script
	    set faces(set,user) $faces(set)
	    set faces(set,unknown) $faces(set)
	    set faces(set,news) $faces(set)
	}
	set faces(sets) {user unknown}
    }

    # tail component for each set
    set faces(name,user) {$user}
    set faces(name,unknown) unknown
    set faces(name,news) unknown

    set faces(defaultDomain) [string tolower \
	[string trim $faces(defaultDomain) ". "]]
    # Build search path
    foreach set $faces(sets) {
	set faces(path,$set) {}
    }
    set faces(path,news) {}
    if [info exists env(FACEPATH)] {
	set faces(base) ""
	foreach dir [split $env(FACEPATH) :] {
	    foreach set $faces(sets) {
		if ![file isdirectory $dir] continue
		if {[lsearch -exact $faces(set,$set) [file tail $dir]] >= 0} {
		    FaceAddPath $set $dir
		} else {
		    FaceAddPath user $dir
		    FaceAddPath unknown $dir
		    FaceAddPath news $dir
		}
	    }
	}
    } else {
	set faces(base) $faces(dir)/
	foreach set $faces(sets) {
	    foreach dir $faces(set,$set) {
		if ![file isdirectory $faces(base)$dir] continue
		FaceAddPath $set $dir
	    }
	}
	if [info exists faces(set,news)] {
	    foreach dir $faces(set,news) {
		if ![file isdirectory $faces(base)$dir] continue
		FaceAddPath news $dir
	    }
	}
    }
}
proc FaceAddPath {set dir} {
    global faces
    lappend faces(path,$set) $dir
    set mmap [file exists $faces(base)$dir/machine.tab]
    set pmap [file exists $faces(base)$dir/people.tab]
    set faces(map,$dir) [expr ($mmap<<1) + $pmap]
    if [file isdirectory $faces(base)$dir/MISC] {
	lappend faces(path,$set) $dir/MISC
	set faces(map,$dir/MISC) 0
    }
}


proc Face_Show { fromwho {xface {}} {ximageurl {}} {newsgrps {}} } {
    global faces faceCache failedURLs exmh

    set xfaceAvail 0
    set ximageurlAvail 0

    # Don't do any of this if we're on a slow display
    if {!$exmh(slowDispShowFaces)} {
      return 0
    }

    Face_Delete

    # Honor X-Face even if faces is disabled
    if {$faces(xFaceEnabled) && \
	[string compare "" $xface] && \
	[string compare "" $faces(xfaceProg)]} {

	if {$faces(rowEnabled) && $faces(defer)} {
	    DeferWork faces(work) [list FaceXFace $xface [FaceAlloc]]
	} elseif {[FaceXFace $xface] && !$faces(rowEnabled)} {
	    set xfaceAvail 1
	}
    }

    # Honor X-Image-URL even if X-Face was displayed or the faces are
    # disabled
    if {$faces(xImageUrl) && [string compare "" $ximageurl]} {
	if {![info exists failedURLs]
	    || ([info exists failedURLs]
		&& [lsearch $failedURLs $ximageurl] == -1)} {
 	    if {$faces(rowEnabled) && $faces(defer)} {
 		DeferWork faces(work) \
		    [list UrlDisplayFace $ximageurl [FaceAlloc]]
 	    } elseif {[UrlDisplayFace $ximageurl [FaceAlloc]]
		      && !$faces(rowEnabled)} {
		set ximageurlAvail 1
	    }
	}
    }

    if {$xfaceAvail || $ximageurlAvail} {
	return 1
    }

    if {$faces(enabled!) || !$faces(enabled)} {
	return 0
    }

    # Check for cached lookup result
    if [info exists faceCache($fromwho,$newsgrps)] {
	if [Face_ShowFace $faceCache($fromwho,$newsgrps)] {
		return 1
	}
	unset faceCache($fromwho,$newsgrps)
	Face_Delete
    }

    set msg [Exmh_OldStatus]
    Exmh_Status "Looking up face of $fromwho ..."

    set parts [string tolower [split $fromwho @]]
    set user [lindex $parts 0]
    set machine [lindex $parts 1]
    if {[string length $machine] == 0} {
	set machine [string tolower $faces(defaultDomain)]
    } elseif {[string first . $machine] == -1} {
      append machine . $faces(defaultDomain)
    }

    set from [split $machine .]
    set pathlist [FacePathlist $from]

#Exmh_Debug \n$user ==> $pathlist

    set pathlistngfull {}
    if {[string compare "" $newsgrps]} {
	set newsgrplist [string tolower [split $newsgrps ,]]
	foreach ng $newsgrplist {
	    set ngparts [split $ng .]
	    set pathlistng [FacePathNGlist $ngparts]
	    set pathlistngfull [concat $pathlistng $pathlistngfull]
	}
    }

    # Loop through Face path
#Tputs lookup: [time {
    set matches {}
    foreach set $faces(sets) {
	eval set tail $faces(name,$set)
        foreach dir $faces(path,$set) {
	    set name $tail
	    set map {}
	    if $faces(map,$dir) {
		if {$faces(map,$dir) & 2} {
		    set map [FacePathlist [split \
			    [FaceMap $dir/machine.tab $machine] .]]
#		    Exmh_Debug $machine => $map
		}
		if {$faces(map,$dir) & 1} {
		    set x [FaceMap $dir/people.tab $machine/$name]
#		    Exmh_Debug $machine/$name =>  $x
		    if [string compare "" $x] {
			set name $x
		    }
		}
	    }
	    foreach part [concat $map $pathlist] {
	    	if {([string match unknown* $dir] || [string match misc* $dir])
		     && [llength $matches]} {
		    break
		}
		set path $dir/$part/$name
#		Exmh_Debug $path
		# skip non-existent directories
		if ![file exists $faces(base)$path] continue

		foreach suf $faces(suffix) {
		    if [file exists $faces(base)$path/face.$suf] {
			lappend matches $path/face.$suf
			break
		    }
		}
	    }
	}
    }
#   }]
    eval set tail $faces(name,news)
    foreach dir $faces(path,news) {
	set name $tail
	set map {}
	foreach part [concat $map $pathlistngfull] {
#	    if {([string match unknown* $dir] || [string match misc* $dir])
#		 && [llength $matches]} {
#		break
#	    }
	    set path $dir/$part/$name
#	    Exmh_Debug $path
	    # skip non-existent directories
	    if ![file exists $faces(base)$path] continue

	    foreach suf $faces(suffix) {
		if [file exists $faces(base)$path/face.$suf] {
		    lappend matches $path/face.$suf
		    break
	        }
	    }
	}
    }

#    Exmh_Debug Faces matches $matches

    if !$faces(rowEnabled) {
	foreach face $matches {
	    if [Face_ShowFile $face] {
		set faceCache($fromwho,$newsgrps) $face
		Exmh_Status $msg
		return 1
	    }
	}
    # braces around cmdsubst NECESSARY!
    } elseif {[Face_ShowFace $matches]} {
	set faceCache($fromwho,$newsgrps) $matches
	Exmh_Status $msg
	return 1
    }

    if [llength $matches] {
	Exmh_Status "(no working face found)"
    } else {
	Exmh_Status "(no face found)"
    }
    return 0
}

proc FacePathlist { from } {
    set path {}
    set prefix {}
    set pathlist {}
    for {set i [expr [llength $from]-1]} {$i>=0} {incr i -1} {
	append path $prefix [lindex $from $i]
	set prefix /
	set pathlist [linsert $pathlist 0 $path]
    }
    lappend pathlist {}
    return $pathlist
}

proc FacePathNGlist { ng } {
    set path {}
    set prefix {}
    set pathlist {}
    for {set i 0} {$i <= [expr [llength $ng]-1]} {incr i 1} {
	append path $prefix [lindex $ng $i]
	set prefix /
	set pathlist [concat $path $pathlist]
    }
    lappend pathlist {}
    return $pathlist
}

proc Face_Delete {} {
    global faces

    if [info exists faces(work)] {
	DeferWorkCancel faces(work)
    }

    for {set f $faces(avail)} {$f > 0} {incr f -1} {
	catch {
	    set image [$faces(frame).l$f cget -image]
	    if [string compare "" $image] {
		$faces(frame).l$f config -image {}
		image delete $image
	    }
	}
	$faces(frame).l$f config -bitmap {}
	if {$faces(rowEnabled) && [info exists faces(rowbg)]} {
	    $faces(frame).l$f config -bg $faces(rowbg)
	}
    }
    set faces(avail) 0

    if !$faces(rowEnabled) {
	raise $faces(default)
    }
}

proc FaceAlloc {} {
    global faces

    set new 0
    if {!$faces(rowEnabled) && $faces(avail)} {
        catch {
            set image [$faces(frame).l$faces(avail) cget -image]
            if [string compare "" $image] {
                $faces(frame).l$faces(avail) config -image {}
                image delete $image
            }
        }
	incr faces(avail) -1	;# make us alloc same label
    }
    if {$faces(avail) == $faces(alloc)} {
	Widget_Label $faces(frame) l[incr faces(alloc)] {left fill}
        set new 1
    }
    set label $faces(frame).l[incr faces(avail)]

    if !$faces(rowEnabled) {
	if $new {		;# once ever
	    pack forget $label
	    place $label -in $faces(default)
	}
    } elseif !$new {
	$label config -bg $faces(facebg)
    }

    return $label
}
proc Face_BusyParent {} {
    global faces
    return $faces(frame)
}
proc Face_BusyPlace {busy} {
    global faces
    place $busy -in $faces(frame) -anchor c -relx 0.5 -rely 0.5
    raise $busy
    update idletasks
}
proc Face_BusyDestroy {busy} {
    global faces
    catch {
	destroy $busy
	# This hack forces the underlying labels to redisplay immediatly
	$faces(default) config -fg [lindex [$faces(default) config -fg] 4]
	$faces(frame).l1 config -fg [lindex [$faces(frame).l1 config -fg] 4]
    }
}
proc Face_ShowFace facelist {
    foreach face $facelist {
	if ![FaceShowFile $face [FaceAlloc]] {
	    return 0
	}
    }
    return 1
}
proc Face_ShowFile facefile {
    set pane [FaceAlloc]
    if ![FaceShowFile $facefile $pane] {
	$pane config -bitmap error
	return 0
    }
    return 1
}
proc FaceShowFile {facefile pane} {
    global faces

    if ![string match /* $facefile] {
	set facefile $faces(base)$facefile
    }
    switch -- [file extension $facefile] {
	.ppm - .pgm - .pbm - .gif - .xpm {
	    if [catch {
# Tputs image create: [time {
		set image [image create photo -file $facefile -palette $faces(palette)]
# }]
		if $faces(defer) {
		    DeferWork faces(work) [list $pane config -image $image] \
			      [list image delete $image]

		} else {
# Tputs image display: [time {
		    $pane config -image $image
# }]
		}
	    } id] {
		Exmh_Debug $id
		return 0
	    }
	}
	.xbm {
	    if [catch {
		$pane config -bitmap @$facefile
	    } id] {
		Exmh_Debug $id
		return 0
	    }
	}
    }
    if !$faces(rowEnabled) {
    	raise $pane
    }
    return 1
}

proc FaceXFace { xface {pane {}}} {
    global faces
    Exmh_Status "$faces(xfaceProg)" warning
# Tputs decode x-face: [time {
    if [catch {open "| $faces(xfaceProg) > [Env_Tmp]/FACE.[pid].xbm" w} fid] {
	Exmh_Status $fid error
	return 0
    } else {
	Exmh_Status "$faces(xfaceProg)"
    }
    puts $fid $xface
    if [catch {close $fid} err] {
	Exmh_Status $err error
	return 0
    }
# }]
    if [string match "" $pane] {
	set pane [FaceAlloc]
    }
# Tputs show x-face: [time {
    set ret [FaceShowFile [Env_Tmp]/FACE.[pid].xbm $pane]
# }]
    File_Delete [Env_Tmp]/FACE.[pid].xbm
    Exmh_Status ok
    return $ret
}

#
# Hook for button in faces area
#
proc Faces_Button {{cmd ""} {label ""} {pack {left fill}}} {
    global faces
    catch {destroy $faces(button)}
    set faces(button) [Widget_AddBut $faces(frame) b $label $cmd $pack]
    $faces(button) config -padx 0 -pady 0
    pack $faces(button) -after $faces(default)
    return $faces(button)
}
proc Faces_ClearButton {} {
    global faces
    catch {destroy $faces(button)}
}


# Faces information used to be administered by a pair of ASCII files
# in the faces directory that associate related machines and faces.
# EXMH still supports this mechanism, although it's use is discouraged.
# The machine table machine.tab attaches machines to communities; the line
#	stard=sunaus
# puts the machine stard in community sunaus.  The machine
# table may be used to alias entire communities; the line
#	wseng.sun.com=eng.sun.com
# will cause the wseng.sun.com domain to be mapped to the
# eng.sun.com community.  The people table associates a
# community/alias pair, with a real username.
#	sunaus/rburridge=richb
# causes the alias rburridge to be translated into the real
# username richb for the community sunaus

proc FaceMachine {dir machine} {
    global faces
    if $faces(mapsEnabled) {
	set map [FaceMap $dir/machine.tab $machine]
	if [string compare "" $map] {
	    return $map
	}
    }
    return $machine
}
proc FacePeople {dir machine people} {
    global faces
    if $faces(mapsEnabled) {
	set map [FaceMap $dir/people.tab $machine/$people]
	switch -- [llength $map] {
	0	{}
	1	{return [list $machine $map]}
	default	{return $map}
	}
    }
    return [list $machine $people]
}
proc FaceMap {file item} {
    global faceMap faces
    if [info exists faceMap($file,$item)] {
	return $faceMap($file,$item)
    }
    if { [info exists faceMap(modtime,$file)] &&
	([file mtime $faces(base)$file]  <= $faceMap(modtime,$file)) } {
	return {}
    }
#    Exmh_Debug FaceMap $file $item
    if ![catch {open $faces(base)$file} in] {
	set faceMap(modtime,$file) [file mtime $faces(base)$file]
	while {[gets $in input] >= 0} {
	    set parts [string tolower [split $input =]]
	    set lhs [string trim [lindex $parts 0]]
	    set rhs [split [string trim [lindex $parts 1]] /]
	    set faceMap($file,$lhs) $rhs
	}
	close $in
	if [info exists faceMap($file,$item)] {
	    return $faceMap($file,$item)
	}
    }
    return {}
}

proc Face_FlushCache {} {
    global faceMap faceCache
    catch {unset faceMap}
    catch {unset faceCache}
}

#
# Defer work to an after handler [this code should be elsewhere]
#

proc DeferWork {name work {cancel {}}} {
    upvar #0 $name queue

    lappend queue [list $work $cancel]
    if {[llength $queue] == 1} {
	after 50 DeferWorkProc $name
    }
}
proc DeferWorkCancel name {
    upvar #0 $name queue

    if [info exists queue] {
	after cancel [list DeferWorkProc $name]
	foreach w $queue {
	    catch [lindex $w 1]
	}
	unset queue
    }
}
proc DeferWorkProc name {
    upvar #0 $name queue

    set this [lindex $queue 0]
    set queue [lrange $queue 1 end]
    catch [lindex $this 0]
    if [llength $queue] {
	after 20 DeferWorkProc $name
    }
}
