# images.tcl
# Supply an image callback function
# Read in an image if we don't already have one
# callback to library for display
#           Inline Images
# This interface is subject to change
# Most of the work is getting around a limitation of TK that prevents
# setting the size of a label to a widthxheight in pixels
#
# Images have the following parameters:
#    align:  top,middle,bottom
#    alt:    alternate text
#    ismap:  A clickable image map
#    src:    The URL link
# Netscape supports (and so do we)
#    width:  A width hint (in pixels)
#    height:  A height hint (in pixels)
#    border: The size of the window border

set imagecachesize 25
proc Image_Reset {win} {
    global imagecache imagecachesize
    foreach image [array names imagecache] {
	ldelete imagecache($image) $win
    }
    set images [image names]
    set nuke [expr [llength $images] - $imagecachesize]
    if {$nuke > 0} {
	foreach image $images {
	    if {[info exists imagecache($image)] &&
		    [llength $imagecache($image)] == 0} {
		unset imagecache($image)
		image delete $image
		incr nuke -1
		if {$nuke <= 0} {
		    break
		}
	    }
	}
    }
}

proc HMtag_img {win param text} {
	upvar #0 HM$win var Head$win head

	# set imagemap callbacks
	set mark [Mark_Current $win]
	set target ""
	set url ""
	set islink 0
	set border 0
	catch {set target $var(Fref)}	;# target frame name
	if [info exists var(Lref)] {
	    set url $var(Lref)
	    set islink 1
	    set border 2
	    if {[HMextract_param $param ismap]} {
		append url ?%x,%y
	    }
	}

	# get alignment
	array set align_map {top top    middle center    bottom bottom}
	set align bottom ;# The spec isn't clear what the default should be
	HMextract_param $param align
	if ![info exists align_map([string tolower $align])] {
	    set align center
	} else {
	    set align $align_map([string tolower $align])
	}

	# get alternate text
	set alt "<image>"
	HMextract_param $param alt
	set alt [HMmap_esc $alt]

	# get the border width
	HMextract_param $param border
	if [regexp -nocase none $border] {
	    set border 0
	}

	# see if we have an image size hint
	# If so, make a frame the "hint" size to put the label in
	# otherwise just make the label
	set item $win.$var(tags)
	# catch {destroy $item}
	if {[HMextract_param $param width] && [HMextract_param $param height]} {
		catch {incr width $border}
		catch {incr height $border}
		frame $item -width $width -height $height
		Head_Color $win $item $islink
		pack propagate $item 0
		dputs got image size: $width x $height $alt
		set label $item.label
		label $label -bd 0
		pack $label -expand 1 -fill both
	} else {
		set label $item
		label $label -bd 0
		dputs got image $alt
	}

	bind $label <ButtonRelease> \
	    [list ImageHit $win $label $mark $url $target]
	if {$islink} {
	    $label config -cursor hand2
	}

	$label configure -relief ridge -fg orange -text $alt
	catch {$label configure -highlightthickness $border}
	Head_Color $win $label $islink
	Win_Install $win $item -padx 0 -pady 0 -align $align

	# now callback to the application
	set src ""
	HMextract_param $param src
	if [info exists var(base)] {
	    set src_orig $src
	    set param_orig $param
	    UrlResolve $var(base) src
	    UrlRelative $var(S_url) src
	    regsub $src_orig $param_orig $src param
	    # Update the mark that represents the HTML
	    Mark_Htag $win [Mark_Current $win] "img $param"
	}
	HMset_image $win $label $src
	return $label	;# used by the forms package for input_image types
}

# The app needs to supply one of these
#proc HMset_image {win handle src} {
#	dputs "Found an image <$src> to put in $handle"
#	HMgot_image $win $handle "can't get\n$src"
#}

# When the image is available, the application should call back here.
# If we have the image, put it in the label, otherwise display the error
# message.  If we don't get a callback, the "alt" text remains.
# if we have a clickable image, arrange for a callback

proc HMgot_image {win label image_error} {
    global imagecache
    # if we're in a frame turn on geometry propogation
    $label config -relief flat
    if {[winfo name $label] == "label"} {
	pack propagate [winfo parent $win] 1
    }
    if {[catch {$label configure -image $image_error}]} {
	$label configure -image {}
	$label configure -text $image_error
    } else {
	# Record which images are in use by this page
	set name [$label cget -image]
	set ix -1
	catch {set ix [lsearch $imagecache($name) $win]}
	if {$ix < 0} {
	    lappend imagecache($name) $win
	}
    }
}

# This is called by the HTML library when it hits an image
# We call HMgot_image when we have finished fetching the image

proc HMset_image {win label href} {
    upvar #0 HM$win var
    upvar #0 Image$win image

    set base $var(S_url)
    set type photo

    set mark [Mark_Current $win]
    if [info exists var(Lref)] {
	regsub -all % $var(Lref) %% url2
	bind $label <Enter> +[list Status $win $url2]
	bind $label <Leave> +[list Status $win ""]
    } else {
	set url2 {}
    }

    set protocol [UrlResolve $base href]	;# Side-effects href
    lappend image(widgets) $label
    switch -regexp -- $protocol {
	(http|ftp) {
	    if {[string first " $href " " [image names] "] >= 0} {
		HMgot_image $win $label $href
	    } else {
		set cache [Cache_GetFile $href]
		set ok 0
		if [file exists $cache] {
		    upvar #0 $href data
		    Status $win "cached image $href"
		    set data(what) file
		    set data(file) $cache
		    set ok [ImageFetched $win $label $href $mark]
		}
		if !$ok {
		    Status $win "fetching image $href"
		    FeedbackLoop $win "image"
		    Http_get $href [list ImageFetched $win $label $href $mark] \
				    [list Image_Progress $win $label $href]
		}
	    }
	}
	file {
	    upvar #0 $href data
	    regsub {(file:(//?localhost)?)} $href {} file
	    regsub {^/+} $file / file
	    if {![catch {image create $type $href -file $file} message]} {
		set data(what) file
		HMgot_image $win $label $href
	    } else {
		set data(what) error
		set data(message) $message
		Status $win $message
	    }
	}
    }
    return
}
# image fetch complete.  Make an image and do callback

proc ImageFetched {win label href mark} {
    upvar #0 $href data
    if {[string first " $href " " [image names] "] >= 0} {
	# Parallel requeusts may mean that this is already created.
	HMgot_image $win $label $href
	return
    }
    set palette ""
    set type image
    catch {set type $data(type)}
    switch -glob -- $type {
	*bitmap { set type bitmap }
	default { set type photo ; set palette "-palette 5/5/5" }
    }
    Exmh_Debug ImageFetched what $data(what) $href
    if {$data(what) == "file"} {
	Status_push $win "rendering image $href"
	global TRANSPARENT_GIF_COLOR	;# Backdoor into photo widget
	set TRANSPARENT_GIF_COLOR [$win cget -bg]
	if {![catch {eval {image create $type $href -file $data(file)} $palette} message]} {
	    HMgot_image $win $label $href
	    dputs ImageFetched $label $href
	    Status_pop $win
	    update
	    return 1
	} else {
	    dputs Image Create Failed $message $label $href
	    Status $win $message
	    return 0
	}
    } elseif {$data(what) == "error"} {
	upvar #0 Image$win img
	set img($label) $data(message)
	return 0
    }
}

proc Image_EditMode {win edit} {
    upvar #0 Image$win image
    if ![info exists image(widgets)] {
	return
    }
    foreach w $image(widgets) {
	if ![winfo exists $w] {
	    set ix [lsearch $image(widgets) $w]
	    set image(widgets) [lreplace $image(widgets) $ix $ix]
	    continue
	}
	if {$edit} {
	    bindtags $w [list ImageEdit $w]
	} else {
	    bindtags $w [list $w [winfo class $w] [winfo toplevel $w] all]
	}
    }

}

proc ImageHit {win label mark url target} {
    set win0 [Window_GetMaster $win]
    if {[winfo class [winfo parent $win0]] == "Msg"} {
	# exmh inline display
	URI_StartViewer $url
    } elseif {[Input_Edit $win]} {
	ImageEdit $win $label $mark
    } elseif {$url != {}} {
	Frame_Display $win $target $url
    }
}
#bind ImageEdit <Enter> {FormHighlightWidget %W}
#bind ImageEdit <Leave> {FormUnHighlightWidget %W}

# Copy an image to the local file system
proc Image_Save {win} {
    upvar #0 HM$win var

    set base $var(S_url)

    Log $win Image_Save
    # Get the selection and look for images in it.
    if [catch {Output_string $win sel.first sel.last} html] {
	Status $win "Select images first"
	return
    }
    set state(images) {}
    HMparse_html $html [list ImageScan $win state] {}

    foreach href $state(images) {
	set protocol [UrlResolve $base href]	;# Side-effects href
    
	switch -regexp -- $protocol {
	    (http|ftp) {
		# Should use the cache
		Status $win "fetching image $href"
		FeedbackLoop $win image
		Http_get $href [list ImageSave $win $href] \
				[list Url_Progress $win $href]
	    }
	    file {
		ImageSave $win $href
	    }
	}
    }
    return
}

proc ImageScan {win stateVar htag not param text} {
    upvar 2 $stateVar state	;# Image_Save -> HMparse_html -> ImageScan
    if {[regexp -nocase ^img $htag] &&
	[HMextract_param $param src] &&
	[info exists src]} {
	lappend state(images) $src
    }
}

proc ImageSave {win href} {
    upvar #0 $href data
    global image
    if {![info exists image(dir)] ||
	![file isdirectory $image(dir)]} {
	Image_SaveDir $win
    }
    if ![info exists data(file)] {
	return
    }
    set path [glob -nocomplain $image(dir)]/[file tail $href]
    if [catch {exec mv -f $data(file) $path} err] {
	Log $win ImageSave $data(file) $err
	Status $win $err
    } else {
	Log $win ImageSave $href $path
	Status $win "Saved $path"
    }
}
proc Image_SaveDir {win} {
    upvar #0 HM$win var
    global image
    if ![info exists image(dir)] {
	set image(dir) ~/public_html/images
    }
    DialogEntry $win .imagesave "Directory for saved images" \
	    [list ImageSaveDir $win] \
	    [list [list "Directory" $image(dir)]]
}
proc ImageSaveDir {win newdir} {
    global image
    set image(dir) $newdir
    if {[string length $image(dir)] && ![file exists $image(dir)]} {
	if [catch {
	    exec mkdir [glob [file dirname $image(dir)]]/[file tail $image(dir)]
	} err] {
	    Status $win $err
	}
    }
    Log $win "Image_SaveDir $image(dir)"
    Status $win "Image dir $image(dir)"
}
proc Image_Progress {win label href state current total} {

    if {$state == "queued"} return
    regsub -all {\.} $href {!} name
    dputs $current $total $href
    if {$state == "done"} {
	catch {destroy $label.bar}
	return
    }
    if ![winfo exists $label] {
	# Deleted out from under us.
	Http_kill $href
	return
    }
    if ![winfo exists $label.bar] {
	frame $label.bar -bg blue
    }

    if {$total > 0} {
	    place $label.bar -in $label \
		-x 0 -y 0 -anchor nw -relheight 1.0 \
		-relwidth [expr double($current) / $total.0]
    }
    update idletasks
}

proc Image_Create { win {htag {}} } {
    Log $win Image_Create
    set state [Dialog_Htag $win {img src=! alt= width= height= align= border=} {} \
	"Image specification" [list ImageDialogHook $win insert]]
    if [llength $state] {
	Undo_Mark $win ImageCreate
	ImageInsert $win [lindex $state 1]
	Undo_Mark $win ImageCreateEnd
    }
}
proc ImageInsert {win param} {
    if [HMextract_param $param href] {
	# Pseudo href attribute for links and ismaps
	regsub href=\"?$href\"? $param {} param
	set html "<a href=$href><img $param></a>"
    } else {
	set html "<img $param>"
    }
    Input_Html $win $html		;# results in Win_Install call
    Input_Dirty $win
}
proc ImageDialogHook { win mark f {dialogVar {}} } {
    upvar #0 $dialogVar dialog
    lappend dialog(_names) ismap
    set dialog(required,ismap) 0
#    set dialog(required,href) 0
    set g [frame $f.ismap -relief flat -bd 10]
    if [HMextract_param $dialog(_values) ismap] {
	set dialog(ismap) _SINGLETON_
    }
    checkbutton $g.ismap -text ISMAP -onvalue _SINGLETON_ -offvalue {} \
	-variable $dialogVar\(ismap)
    button $g.edit -text "Edit Map" \
	-command [list ImageMapStart $win $dialogVar\(ismap) $dialog(src)]
    button $g.href -text "Edit Link" -command [list ImageEditLink $win $mark]

    button $g.browse -text "Browse" -command [list ImageBrowse $win $dialogVar\(src)]
    pack $g
    pack $g.ismap $g.edit  $g.href $g.browse -side left -padx 5

}
proc ImageEditLink {win mark} {
    Text_MarkSet $win insert $mark
    Text_TagRemove $win sel 1.0 end
    Text_TagAdd $win sel insert "insert +1c"
    DialogHtagCancel $win
    after 1 [list Url_InsertLink $win]
}
proc ImageBrowse {win varname} {
    upvar #0 $varname src HM$win var

    set abs $src
    set default ""
    UrlResolve $var(S_url) abs
    if [regsub -nocase ^file: $abs {} abs] {
	set default $abs
    }
    set file [fileselect "Select Image File" $default file]
    if {[string length $file]} {
	set file file:$file
	UrlRelative $var(S_url) file
	set src $file
    }
}
proc ImageMapStart {win varName src} {
    upvar #0 $varName ismap HM$win var
    set proto [UrlResolve $var(S_url) src]
    if {[string compare $proto file] != 0} {
	upvar #0 $src data	;# Image fetch state
	if {[string compare $data(what) file] != 0} {
	    Status $win "Can't find the image"
	    return
	}
	set file $data(file)
    } else {
	regsub {(file:(//?localhost)?)} $src {} file
	regsub {^/+} $file / file
    }
    IME_Init .ime $file
    set ismap _SINGLETON_
    DialogHtagOK $win
}

proc ImageEdit { win label mark } {
    upvar #0 Image$win img HM$win var
    set htag [Mark_Htag $win $mark]
    dputs $label $htag
    Log $win ImageEdit $label $htag
    # check for label inside a frame
    if {[winfo class [winfo parent $label]] != "Text"} {
	set widget [winfo parent $label]
    } else {
	set widget $label
    }
    set W [set H {}]
    set msg "Edit image specification"
    if [HMextract_param $htag src] {
	UrlResolve $var(S_url) src
	upvar #0 $src data	;# http fetch state
	if ![info exists data(what)] {
	    append msg "\n$src"
	} else {
	    switch -- $data(what) {
		"file" -
		"done" {
		    # Compute size of real image
		    set W [winfo width $widget]
		    set H [winfo height $widget]
		}
		"connect" {
		    append msg "\n(no connection to src)"
		}
		"error" {
		    append msg "\n$data(message)"
		}
		"body" {
		    # Probably got an error message from the server
		    DialogHtmlError $data(html)
		    append msg "\n(note error popup)"
		}
	    }
	}
    }
    # Double check interaction between size and border specifications
    set spec "img src=! alt= width=$W height=$H align= border="
    set bd [$widget cget -highlightthickness]
    set color [$widget cget -highlightbackground]
    set image [$label cget -image]
    if {[string compare $color "red"] == 0} {
	$widget config -highlightbackground blue
    } else {
	$widget config -highlightbackground red
    }
    if {$bd == 0} {
	$widget config -highlightthickness 2
    }

    set state [Dialog_Htag $win $spec $htag $msg \
	    [list ImageDialogHook $win $widget]]
    if [llength $state] {
	global imagecache
	Undo_Mark $win Image_Edit
	Text_MarkSet $win  insert [$win index $widget]
	Mark_ReadTags $win insert force
	set html [Edit_CutRange $win $mark "$mark +1char"]
	ldelete imagecache($image) $win
	regsub {<img[^>]*>} $html "<img [lindex $state 1]>" html
	Input_Html $win $html
	Undo_Mark $win Image_EditEnd
    } else {
	$widget config -highlightthickness $bd -highlightbackground $color
    }
    LogEnd $win
}
