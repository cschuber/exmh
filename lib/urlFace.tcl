# urlFace.tcl
#
# Author: Ovidiu Predescu <ovidiu@aracnet.com>
#
# Retrieve an image giving an URL and use it as face.

set urlFace(width) 48
set urlFace(height) 48

# Some private procedures for this module

proc UrlGetCachedImageFileName { href } {
    global urlFace

    set extension [file extension $href]

    if [catch {exec echo $href | sed -e s^/^_^g} trhref] {
	UrlFaceLog "cannot process URL! ($trhref)"
	# Cannot process the URL; create a temp file to hold the image
	set trhref "temp.$extension"
    }
    set rootname [file rootname $trhref]

    # Handle image types not currently known by Tk. This requires the
    # PPM tools to work. We use a PPM conversion of the file instead
    # of the original file.

    switch -- $extension {
	.tiff - .tif - .jpeg - .jpg - .pbm - .xbm {
	    set trhref "$rootname.ppm"
	}

	.pnm - .ppm - .pgm - .gif - .xpm {
	    # Do nothing
	}

	default {
	    Exmh_Status "Image type $extension not supported!" red
	    UrlFaceLog "Image type $extension not supported!"
	    return ""
	}
    }

    set cachedImagesDir "[glob ~]/.exmh-images"
    if {![file exists $cachedImagesDir]} {
	exec mkdir $cachedImagesDir
    }
    set imageFile "$cachedImagesDir/$trhref"

    return $imageFile
}

# Transform unknown image file formats to PPM. All the images are
# converted to the size urlFace(width) x $urlFace(height).
proc UrlFaceGetNormalizedImage { filename } {
    global urlFace

    set extension [file extension $filename]
    set rootname [file rootname $filename]

    switch -- $extension {
	.tiff - .tif {
	    if [catch {exec tifftopnm <$filename 2>/dev/null \
			   | pnmscale -xysize $urlFace(width) $urlFace(height) \
			   >${rootname}.ppm} err] {
		Exmh_Status "cannot convert TIFF file! ($err)" red
		UrlFaceLog "cannot convert TIFF file! ($err)"
		return "";
	    } else {
		return ${rootname}.ppm
	    }
	}

	.jpeg - .jpg {
	    if [catch {exec djpeg -pnm $filename \
			   | pnmscale -xysize $urlFace(width) $urlFace(height) \
			   >${rootname}.ppm} err] {
		Exmh_Status "cannot convert JPEG file! ($err)" red
		UrlFaceLog "cannot convert JPEG file! ($err)"
		return "";
	    } else {
		return ${rootname}.ppm
	    }
	}

	.xbm {
	    if [catch {exec xbmtopbm <$filename \
			   | pnmscale -xysize $urlFace(width) $urlFace(height) >${rootname}.ppm 2>/dev/null} err] {
		Exmh_Status "cannot convert XBM file! ($err)" red
		UrlFaceLog "cannot convert XBM file! ($err)"
		return "";
	    } else {
		return ${rootname}.ppm
	    }
	}

	.pbm {
	    if [catch {exec pnmscale -xysize $urlFace(width) $urlFace(height) <$filename \
			   >${rootname}.ppm 2>/dev/null} err] {
		Exmh_Status "cannot scale PBM file! ($err)" red
		UrlFaceLog "cannot scale PBM file! ($err)"
		return "";
	    } else {
		return ${rootname}.ppm
	    }
	}


	.pnm - .ppm - .pgm {
	    set image [image create photo -file $filename]

	    # Scale the image if its different than
	    # $urlFace(width) x $urlFace(height)
	    set height [image height $image]
	    set width [image width $image]

	    if {($height != $urlFace(height) || $width != $urlFace(width))
		&& [catch {exec sh -c "pnmscale -xysize $urlFace(width) $urlFace(height) <$filename \
			       >${filename}.new \
			       && mv $filename.new ${filename}"} err]} {
		Exmh_Status "cannot scale PPM file! ($err)" red
		UrlFaceLog "cannot scale PPM file! ($err)"
	    }
	    return $filename;
	}

	.gif {
	    set image [image create photo -file $filename]

	    # Scale the image if its different than
	    # $urlFace(width) x $urlFace(height)
	    set height [image height $image]
	    set width [image width $image]

	    if {($height != $urlFace(height) || $width != $urlFace(width))
		&& [catch {exec sh -c "(giftopnm <$filename \
			       | pnmscale -xysize $urlFace(width) $urlFace(height) \
			       | ppmquant 256 \
			       | ppmtogif >${filename}.new \
			       && mv ${filename}.new ${filename}\
			       && exit 0)" 2>/dev/null} err]} {
		Exmh_Status "cannot scale GIF file! ($err)" red
		UrlFaceLog "cannot scale GIF file! ($err)"
	    }
	    return $filename
	}

	.xpm {
	    set image [image create photo -file $filename]

	    # Scale the image if its different than
	    # $urlFace(width) x $urlFace(height)
	    set height [image height $image]
	    set width [image width $image]

	    if {($height != $urlFace(height) || $width != $urlFace(width))
		&& [catch {exec sh -c "(xpmtoppm <$filename \
			       | pnmscale -xysize $urlFace(width) $urlFace(height) \
			       | ppmquant 256 \
			       | ppmtoxpm >${filename}.new \
			       && mv ${filename}.new ${filename})" 2>/dev/null} err]} {
		Exmh_Status "cannot scale XPM file! ($err)" red
		UrlFaceLog "cannot scale XPM file! ($err)"
	    }
	    return $filename;
	}

    }

    return $filename
}

proc UrlFaceQueryStatus {state count length} {
    global exmh urlFace failedURLs
    upvar url href

    if {![string compare $state "error"]} {
	# error reading from URL
	Exmh_Status "error reading $href! ($count)" red
	UrlFaceLog "error reading $href! ($count)"
	set urlFace($href,urlFailed) 1
	lappend failedURLs $href
	FaceShowFile $exmh(library)/loaderror.ppm $urlFace($href,pane)
	return
    } elseif {![string compare $state "body"]} {
	# The URL does not exist
	UrlFaceLog "URL $href does not exist!"
	FaceShowFile $exmh(library)/loaderror.ppm $urlFace($href,pane)
	set urlFace($href,urlFailed) 1
	lappend failedURLs $href
	return
    }

    if {$length} {
	Exmh_Status [format "%s... %.1f%% complete" \
			 $href [expr 100.0 * $count / $length]]
    } else {
	Exmh_Status [format "%s..." $href]
    }
}

proc UrlFaceQueryDone { href filename msgPath pane } {
    global exmh urlFace msg
    upvar #0 $href data

    unset urlFace($href,pane)

    if {[info exists urlFace($href,urlFailed)]} {
	unset urlFace($href,urlFailed)
    } else {
	UrlFaceLog "got image from $href in $data(file)"
	set normalized [UrlFaceGetNormalizedImage $data(file)]
	UrlFaceLog "normalized file is $normalized"

	UrlFaceLog "executing cp $normalized $filename"
	if [catch {exec cp $normalized $filename} err] {
	    Exmh_Status "cannot create face file in ~/.exmh-images! ($err)" red
	    UrlFaceLog "cannot create face file in ~/.exmh-images! ($err)"
	    FaceShowFile $exmh(library)/loaderror.ppm $pane
	    return
	}

	# Display the face if the current message is the same
	if {$msg(path) == $msgPath} {
	    Url_displayFace $href $filename $pane
	}
    }
}

proc Url_displayFace { href imageFile {pane {}} } {
    global exmh failedURLs

    Exmh_Status "Displaying face..."
    UrlFaceLog "displaying face from $imageFile"
    if ![FaceShowFile $imageFile $pane] {
	# Remove the cached image in case of errors
	catch {exec rm -f $imageFile}
	lappend failedURLs $href
	FaceShowFile $exmh(library)/loaderror.ppm $pane
	return 0
    } else {
	Exmh_Status "Displaying face...done"
	return 1
    }
}

# This is the public procedure in this file
proc UrlDisplayFace { href pane } {
    global urlFace msg failedURLs exmh

    set imageFile [UrlGetCachedImageFileName $href]

    # Check to see if the file is already cached
    if {[string compare $imageFile ""]
	&& ![file exists $imageFile]} {
	# The image is not cached, retrieve it. Since this may take a
	# while we simply return with the appropriate return code. The
	# face will be displayed when the loading of the image is
	# finished.

	set urlFace($href,pane) $pane
	FaceShowFile $exmh(library)/loading.ppm $pane

	Exmh_Status "getting image face from $href..."
	UrlFaceLog "getting image face from $href..."
	set ret [Http_get $href \
		 "UrlFaceQueryDone $href $imageFile $msg(path) $pane" \
		 UrlFaceQueryStatus]
	if {![string compare $ret ""]} {
	    # URL could not be reached. Disable the access to it
	    # during this session.
	    Exmh_Status "unable to display the X-Image-Url face!" red
	    UrlFaceLog "unable to display the X-Image-Url face!"
	    FaceShowFile $exmh(library)/loaderror.ppm $pane
	    lappend failedURLs $href
	}
	UrlFaceLog "delayed showing the image from $href"
	return 0
    } else {
	return [Url_displayFace $href $imageFile $pane]
    }
}

proc UrlFaceLog {args} {
#    puts $args
}
