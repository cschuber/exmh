# mime.tcl
#
# MIME message display.
#
# Thanks to Chris Garrigues who tested and improved this code.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Mime_Init {} {
    global mime env base64 mimeFont

    if [info exists mime(init)] {
	return
    }
    # Make sure Metamail is on the path
    set hit 0
    foreach dir [split $env(PATH) :] {
	if {[string compare $dir $mime(dir)] == 0} {
	    set hit 1
	    break
	}
    }
    if {! $hit} {
	set env(PATH) $mime(dir):$env(PATH)
    }
    set mime(encode) mimencode
    foreach dir [split $env(PATH) :] {
	if {[file executable $dir/mimencode]} {
	    set mime(encode) mimencode
	    break
	}
	if {[file executable $dir/mmencode]} {
	    set mime(encode) mmencode
	    break
	}
    }

    set mime(init) 1
    set mime(seed) 1
    set mime(junkfiles) {}
    set mime(stop) 0

    set types [concat [option get . mimeTypes {}] [option get . mimeUTypes {}]]
    Exmh_Debug MimeTypes $types
    set mime(showproc,default)			Mime_ShowDefault
    foreach type $types {
	set func [option get . mime_$type {}]
	if {[string length $func] != 0} {
	    set mime(showproc,$type) $func
	}
    }

    set accessMethods [concat [option get . mimeExtMethods {}] \
			      [option get . mimeUExtMethods {}]]
    foreach accessMethod $accessMethods {
	set func [option get . mime_$accessMethod {}]
	if {[string length $func] != 0} {
	    set mime(accessMethod,$accessMethod) $func
	}
    }

    # Make a try to load Img extention, ignore failures
    if [ catch { set img_version [package require Img] } ] {
	Exmh_Debug Unable to load Img
    } else {
	 Exmh_Debug Loaded Img version $img_version
    }

    set imageFilters [concat [option get . imageFilters {}] \
			      [option get . imageUFilters {}]]
    foreach imageFilter $imageFilters {
	set func [option get . image_$imageFilter {}]
	if {[string length $func] != 0} {
	    set mime(imageFilter,$imageFilter) $func
	}
    }

    set fontSets {plain title fixed proportional}

    set charsets [concat [option get . mimeCharsets {}] \
			 [option get . mimeUCharsets {}]]
    foreach charset $charsets {
	set mime(registry,$charset) \
	    [option get . mime_${charset}_registry {}]
	set mime(encoding,$charset) \
	    [option get . mime_${charset}_encoding {}]

	foreach fontSet $fontSets {
	    set families \
		[option get . mime_${charset}_${fontSet}_families {}]
	    set i 1
	    foreach family $families {
		set mime(family,$charset,$fontSet,$i) $family
		incr i
	    }
	    set mime(family,$charset,$fontSet,$i) *
	}
    }

    Preferences_Add "MIME" \
"MIME is the Multipurpose Internet Mail Extension that allows a variety of message types to be transfered and displayed for you." {
	{mime(enabled) mimeEnabled	ON {Enable MIME display}
"This controls whether or not MIME-format messages are parsed
and displayed.	If it is disabled, then the messages are
displayed as plain text."}
	{mime(showType) mimeShowType	OFF {Show MIME types}
"This controls whether or not the MIME type information for each
part of a multi-part message is displayed."}
	{mime(showPrelude) mimeShowPrelude	OFF {Show MIME prelude}
"This controls whether or not the information between the mail headers
and the official start of a multipart message is displayed.  Sometimes
this has useful information, while other times it has warnings about
the rest of the message being in MIME format."}
	{mime(fullHeaders) mimeFullHeaders	OFF {Show full headers}
"This controls whether full headers are shown for message/rfc822 items
inside MIME mail.  This prevents Folder-Display and Folder-Suppress
profile options from taking effect."}
	{mime(maxSubpartsDisplayed) mimeMaxSubpartsDisplayed	5 
	    {Maximum subparts to display}
"This is the maximum number of subparts to display without hiding complex
subparts (multipart or message) behind an ellipsis.  Undisplayed subparts
may be displayed by hand from the menu."}
	{msg(maxsize) mimeMaxSize	70000
	    {Maximum message size before warning}
"This is the maximum size of a message before exmh displays a
warning about a large message and STOP button."}
	{mime(ftpMethod) ftpMethod
        {CHOICE expect ftp {ftp -n} metamail {URI tool}}
	{FTP access method}
"Sometimes the automatic FTP transfer fails because of
problems logging into the remote host.	This option lets
you try a few different approachs to find the one that
works for you:
expect - use the ftp.expect script to download the file.
ftp - use ftp and feed user and password to it via a pipe.
ftp -n - use the ftp no-auto-login feature.
metamail - pass control to metamail and let it try.
URI tool - uses your favorite WWW browser to get the
           file.  See \"URI Preferences\"."}
	{mime(ftpCommand) ftpCommand	ftp {FTP command name}
"You may need to run a different command than \"ftp\" in
order to get out onto the internet from inside your company
network.  The command will be invoked with the site name as
the only argument, possibly with the -n flag, which depends on
your choice of the FTP access method.  If you use the expect
script, you'll have to tweak that by hand."}
	{mime(highlightText) highlightText ON {Highlight Message Quotes}
"If enabled, this colorizes in-lined replies in messages, signatures,
and other features of otherwise ordinary text messages."}
	{mime(showRichCmnds) showRichCmnds OFF {Show RichText Commands}
"If enabled, this allows the display of unknown richtext commands at
the bottom of the richtext display.  If disabled, unknown richtext
commands are simply ignored."}
	{mime(showSeparator) showSeparator ON {Show Graphic Part Separator}
"If enabled, MIME display uses a raised text bar to separate the
header and various body parts.  Otherwise a blank line is used."}
	{mime(showImage) showImage ON {Show Images}
"If enabled, Image parts will be displayed immediatly when you
view a message.  Otherwise you have to ask for them via the
background menu."}
	{mime(fontSize) mimeFontSize 120 {Default font point size}
"The default point size for fonts in MIME messages.
(Note: font family information is set via X resources not
exposed via preferences.  Check out app-defaults."}
	{mime(titleSize) mimeTitleSize 120 {Default title point size}
"The default point size for part titles in MIME messages.
(Note: font family information is set via X resources not
exposed via preferences.  Check out app-defaults."}
	{mime(noteSize) mimeNoteSize 100 {Default note point size}
"The default point size for notes in MIME messages.
(Note: font family information is set via X resources not
exposed via preferences.  Check out app-defaults."}
	{mime(eudora) mimeEudora ON {Enable Eudora attachment support}
"This controls whether or not the Content-Disposition: header will be added
to multipart messages so that Eudora can work out the original filename.
The full header is: Content-Disposition: attachment; filename=\"...\"."}
	{mime(dosname) mimeEudoraDos OFF {Map attachment name to 8.3 DOS}
"This controls whether or not attachement filename
will be translated into a suitable DOS 8.3 representation."}
	{mime(mdnTo) dispositionNotificationTo {} {Disposition Notification To}
"The address where you want MDN receipts to end up.  This normally your
own email address."}
	{mime(mdnSend) dispositionNotificationSend
         {CHOICE never deny {ask user} auto/ask auto/ignore } 
         {Send MDNs}
"This controls if and how to send MDNs (receipts).  The options are:
  - Never generate MDN, always ignore requests silently.
  - Automatically generate a \"denied\" MDN when a MDN is requested.
  - Ask user whether to generate a MDN when displaying the message.
  - Automatically when displaying the message, but ask user in 
    certain cases where it may not be appropriate to generate MDNs.
  - As above, but silently ignore potentially suspect MDN requests."}
	{mime(explainReport) explainReports OFF {Show report explanations}
"This controls whether human-readable explanations are presented along
with the machine-readable part (part 2) of multipart/report messages."}
    }
    set i 0
    foreach char {A B C D E F G H I J K L M N O P Q R S T U V W X Y Z \
		  a b c d e f g h i j k l m n o p q r s t u v w x y z \
		  0 1 2 3 4 5 6 7 8 9 + /} {
	set base64($char) $i
	incr i
    }
    mailcap_load
    MimeSunInit
}
proc Mime_Enabled {} {
    global mime
    return $mime(enabled)
}
proc Mime_Cleanup {{tkw default}} {
    global mime mimeHdr mimeContentId

    eval File_Delete $mime(junkfiles)
    set mime(junkfiles) {}

    catch {unset mimeHdr}
    catch {unset mimeContentId}
    if {[string compare $tkw default] != 0} {
	if 0 {
	foreach tag [$tkw tag names] {
	    if ![string match hdrlook=* $tag] {
		catch {$tkw tag delete $tag}
	    }
	}
	}
	foreach mark [$tkw mark names] {
	    catch {$tkw mark unset $mark}
	}
	foreach image [image names] {
	    if [string match ==image=* $image] {
		catch {image delete $image}
	    }
	}
    }
}
proc MimeColor { tkw color } {
    if {[string compare $color default] == 0} {
	set color [lindex [$tkw configure -background] 4]
    }
    set rgb [winfo rgb $tkw $color]
    return [format #%04x%04x%04x \
	[lindex $rgb 0] [lindex $rgb 1] [lindex $rgb 2]]
}
# mimeHdr contains state about nested body parts:
# mimeHdr($part,type)	Content-Type
# mimeHdr($part,typeDescr)	Textual description of the type
# mimeHdr($part,encoding)	Content-Transfer-Encoding
# mimeHdr($part,file)	Tmp file containing body
# mimeHdr($part,origFile)	if the body had to be decoded,
#				undecoded version of file
# mimeHdr($part,params)	Parameter names (e.g., boundary)
# mimeHdr($part,param,$key)	Parameter value
# mimeHdr($part,hdrs)	List of subpart mail headers
# mimeHdr($part,hdr,$key)	Subpart mail header value
# mimeHdr($part,display)	Flag determining if body is displayed
# mimeHdr($part,color)	Color to use as background
# mimeHdr($part,justDoIt)	Flag to execute body automatically
# mimeHdr($part,menu)	Menu for this section
# mimeHdr($part,HeaderSize)	The # of lines taken by the header
# mimeHdr($part,decode)	Boolean to decode message 
#
# multipart and message only:
# mimeHdr($part,numParts)	Number of subparts
#
# multipart/alternative only:
# mimeHdr($part,chosenPart)	Part to display
# mimeHdr($part,priorChosenPart)	Previous part displayed.
#
# message/rfc822 only:
# mimeHdr($part,fullHeaders)	Boolean to display full headers
#
# multipart/report part 2 only:
# mimeHdr($part,explainReport)  Display explanation of machine-readable part
#                               of report.
# mimeHdr($part,originalMessageDate)    Date of reported message, if known.
# mimeHdr($part,originalMessageEnclosed)   Indicates whether the reported
#                               message is enclosed as part 3 of multipart.
#
# images only:
# mimeHdr($part,photo)		The image itself

proc MimeHeader {part contentType encoding} {
    global mimeHdr

    set params [split $contentType \;]
    # add stuff from Content-Disposition:
    if {[info exists mimeHdr($part,hdr,content-disposition)]} {
      set disp [split $mimeHdr($part,hdr,content-disposition) \;]
      lappend params "disposition=[lindex $disp 0]"
      eval lappend params [lrange $disp 1 end]
    }
    set type [string tolower [string trim [lindex $params 0]]]
    if {[string compare $type "text"] == 0} {
	set type text/plain
    }
    set mimeHdr($part,hdr,content-type) $contentType
    set mimeHdr($part,type) $type
    set mimeHdr($part,encoding) $encoding
    set mimeHdr($part,params) {}
    foreach sub [lrange $params 1 end] {
	if [regexp {([^=]+)=(.+)} $sub match key val] {
	    set key [string trim [string tolower $key]]
	    set val [string trim $val]
	    # Allow single as well as double quotes
	    if [regexp {^[\"']} $val quote] {
		if [regexp ^${quote}(\[^$quote\]+)$quote $val x val2] {
		    # Trim quotes and any extra crap after close quote
		    set val $val2
		}
	    }
	    lappend mimeHdr($part,params) $key
	    set mimeHdr($part,param,$key) $val
	}
    }
    if [info exists mimeHdr($part,hdr,x-sun-charset)] {
	lappend mimeHdr($part,params) charset
	set mimeHdr($part,param,charset) \
		[string tolower $mimeHdr($part,hdr,x-sun-charset)]
    }
    # infer the name from the filename:
    if {[info exists mimeHdr($part,param,filename)] &&
      ![info exists mimeHdr($part,param,name)]} {
      set mimeHdr($part,param,name) $mimeHdr($part,param,filename)
    }
    return $type
}
proc MimeShowPart {tkw part overTag only} {
    global mimeHdr

    set partTag [MimeLabel $part part]
    if ![info exists mimeHdr($part,decode)] {
	# decode sub-parts by default, but not main body
	set mimeHdr($part,decode) [string compare $part 0=1]
    }
    MimeWithTagging $tkw $partTag $overTag \
		    {-background $mimeHdr($part,color) \
		     -foreground [$tkw cget -foreground]} {
	MimeSetPartVars desc displayedPart $tkw $part $partTag
	MimeSetStdMenuItems $tkw $part
	MimeShowPartHeader $tkw $part $partTag $only $displayedPart $desc
	MimeShowPartBody $tkw $part
    }
    Exmh_Status $desc
}
proc Mime_TypeDescr {part} {
    global mimeHdr

    if [info exists mimeHdr($part,typeDescr)] {
	return $mimeHdr($part,typeDescr)
    }
    if [catch {set typeDescr [MimeGetRule $part "description" atrib]}] {
	set typeDescr "a $mimeHdr($part,type)"
    }
    regsub -- "^A" $typeDescr "a" mimeHdr($part,typeDescr)
    return $mimeHdr($part,typeDescr)
}
proc MimeSetCharset {tkw part} {
    global mime mimeFont
    set charset [Mime_GetCharset $tkw $part]
    if ![info exists mimeFont(charset,$charset)] {
	set mime(fontSize) [string trim $mime(fontSize)]
	if [catch {Mime_GetFont $tkw medium r plain $mime(fontSize) $charset} \
		font] {
	    MimeInsertNote $tkw [MimeLabel $part charset] "Error: $font"
	    $tkw insert insert \n
	    set mimeFont(charset,$charset) $mimeFont(default)
	} else {
	    set mimeFont(charset,$charset) $font
	}
    }
    set partTag [MimeLabel $part charset]
    if [catch {$tkw tag configure $partTag -font $mimeFont(charset,$charset)} err] {
	MimeInsertNote $tkw [MimeLabel $part charset] "Error: $err"
	$tkw insert insert \n
	Exmh_Status "No good font for $charset character set"
	set mimeFont(charset,$charset) $mimeFont(default)
    }
    return $partTag
}
proc MimeSetStdMenuItems {tkw part} {
    global mimeHdr env
    set type $mimeHdr($part,type)

    if {[catch {set descr $mimeHdr($part,hdr,content-description)}] ||
        ($descr == {})} {
	set descr [Mime_TypeDescr $part]
    }
    if [info exists mimeHdr($part,file)] {
	MimeMenuAdd $part checkbutton \
		-label "Decode part as MIME" \
		-command [list busy MimeRedisplayPart $tkw $part] \
		-variable mimeHdr($part,decode)
	MimeMenuAdd $part command \
	    -label "Save $descr..." \
	    -command [list Mime_SavePiece $part $type]
	if [info exists mimeHdr($part,hdr,content-type)] {
	    set type $mimeHdr($part,hdr,content-type)
	} else {
	    set type $mimeHdr($part,type)
	}
	set subparts {}
	if [regexp {^multipart} $mimeHdr($part,type)] {
	    MimeChopPart $tkw $part
	    set numParts $mimeHdr($part,numParts)
	    for {set subpart 1} {$subpart <= $numParts} {incr subpart} {
		lappend subparts \
			[list $mimeHdr($part=$subpart,hdr,content-type) \
			      $mimeHdr($part=$subpart,file)]
	    }	
	}
	if [MimeCheckRule $part ""] {
	    MimeMenuAdd $part command \
		-label "View using mailcap rule..." \
		-command [list MimeMailcapView $part $subparts]
	}
	if [MimeCheckRule $part "print"] {
	    MimeMenuAdd $part command \
		-label "Print using mailcap rule..." \
		-command [list MimeMailcapPrint $part $subparts]
	} else {
	    MimeMenuAdd $part command \
		-label "Print $descr as text..." \
		-command [list Mime_PrintPiece $part $type]
	}
	if ![info exists env(NOMETAMAIL)] {
	    MimeMenuAdd $part command \
		-label "Pass [Mime_TypeDescr $part] to metamail..." \
		-command [list MimeMetaMail \
			       $type \
			       $mimeHdr($part,encoding) \
			       [MimeGetOrigFile $part]]
	}
    }
}
proc MimeShowPartBody {tkw part} {
    global mime mimeHdr

    MimeSetCharset $tkw $part

    if !$mimeHdr($part,decode) {
	Mime_WithTextFile fileIO $tkw $part {
	    $tkw insert insert [read $fileIO]
	}
    } elseif [info exists mimeHdr($part,file)] {
	set fileName $mimeHdr($part,file)
	set type $mimeHdr($part,type)

	foreach t [list $type [file dirname $type] default] {
	    if [info exists mime(showproc,$t)] {
		if [catch {$mime(showproc,$t) $tkw $part} err] {
		    Exmh_Status "$err in $mime(showproc,$t)"
		    Mime_ShowDefault $tkw $part  
		    #$mime(showproc,$t) $tkw $part
		}
		return
	    }
	}
    } else {
	$tkw insert insert "You have received a reference to a $mimeHdr($part,type)\n"
	MimeInsertInfo $tkw $part
    }
}
proc MimeWithDisplayHiding {tkw part body} {
    global mimeHdr

    MimeMenuAdd $part checkbutton \
	    -label "Display inline" \
	    -command [list busy MimeRedisplayPart $tkw $part] \
	    -variable mimeHdr($part,display)
    if {$mimeHdr($part,display)} {
	uplevel $body
    } else {
        $tkw insert insert ". . .\t\t\t\t\t\t"
        MimeInsertNote $tkw [MimeLabel $part part] \
                "Invoke menu with right button."
    }
}
proc MimeSetPartVars {descVar displayedPartVar tkw part partTag} {
    global mimeHdr msg
    upvar $descVar desc

    set desc {}
    MimeMapSunHeaders $tkw $part

    if ![info exists mimeHdr($part,type)] {
	set mimeHdr($part,type) text/plain
    }

    if {([string compare $mimeHdr($part,type) message/sample] == 0) ||
	([string compare $mimeHdr($part,type) message/news] == 0)} {
      set mimeHdr($part,type) message/rfc822
    }
    if {([string compare $mimeHdr($part,type) message/rfc822] == 0) && \
	![info exists mimeHdr($part,numParts)]} {
	#
	# This is the first pass over the message from ShowInText
	#
	set fileName $mimeHdr($part,file)

	if {![catch {file size $fileName} size] &&
	    $size > $msg(maxsize)} {
	    # Display stop button
	    MimeSizeDialog $tkw $size
	}
	if [catch {open $fileName r} fileIO] {
	    Exmh_Status "Cannot open body $fileName: $fileIO"
	    set mimeHdr($part,numParts) 0
	    return
	}
	set mimeHdr($part,numParts) [MimeParseSingle $tkw $part $fileIO]
	MimeClose $fileIO
	MimeSizeDialogCleanup $tkw
	if {$mimeHdr($part,numParts) == 0} {
	    set desc $mimeHdr(${part}=1,hdr,subject)
	    return;	# fastpath
	}
    }
    if {[string compare $mimeHdr($part,type) "application/octet-stream"] \
     == 0} {
	if [string length [set type [Mime_Magic \
	 [Mime_GetUnencodedFile $part]]]] {
	    set mimeHdr($part,hdr,content-description) $type
	    regsub octet-stream $mimeHdr($part,hdr,content-type) \
	     $type mimeHdr($part,hdr,content-type)
	    set mimeHdr($part,type) $type
	}
    }

    MimeSetDisplayFlag $part
    global mimeContentId
    upvar $displayedPartVar displayedPart


    # Cache content-id data.  Basically, if this part has a content-id
    # header that we've seen before, use the file that was associated
    # with the first reference to this content-id instead of the one
    # that we would otherwise use.  If this part is external, we cache
    # the first reference which is actually retrieved.  Except for not
    # redisplaying any other references to the same external part, I think
    # this'll do the right thing. 
    if [info exists mimeHdr($part,hdr,content-id)] {
	if [info exists mimeContentId($mimeHdr($part,hdr,content-id))] {
	    set mimeHdr($part,file) \
		$mimeContentId($mimeHdr($part,hdr,content-id)) 
	} elseif [info exists mimeHdr($part,file)] {
	    set mimeContentId($mimeHdr($part,hdr,content-id)) \
		$mimeHdr($part,file)
	}
    }

    foreach key [list $part,hdr,content-description \
		      $part,param,name \
		      $part=1,hdr,subject] {
        if ![catch {set desc $mimeHdr($key)}] {
	    break
	}
    }

    # Slight tweak because of TCL 7.0 regsub bug
    set displayedPart [string range "$part=" 4 end]
    regsub -all -- = $displayedPart . displayedPart

    if {[string length $desc] != 0} {
	MimeMakeMenu $tkw $partTag $part "$displayedPart $desc"
    } else {
	MimeMakeMenu $tkw $partTag $part $displayedPart
    }	 
}
proc MimeSizeDialog {t size} {
    global mime
    catch {destroy $t.size}
    set g [frame $t.size -bd 4 -relief raised]
    set f [frame $g.pad -bd 20]
    set msg [Widget_Message $f msg -text \
	"Very Large Message: $size bytes" -width 200]
    Widget_AddBut $f stop STOP {set mime(stop) 1} {top padx 2 pady 2 filly}
    bind $f.stop <Any-Key> {set mime(stop) 1; Exmh_Status Stop warn}
    pack $f
    Widget_PlaceDialog $t $g
    Visibility_Wait $f.stop
    catch {focus $f.stop}
    catch {grab $f.stop}
    set mime(grab) 1
    return $g
}
proc MimeSizeDialogCleanup {t} {
    global mime
    catch {destroy $t.size}
    set mime(grab) 0
    set mime(stop) 0
    Exmh_Focus
}
proc MimeClose { fileIO } {
    if [catch {close $fileIO} err] {
	Exmh_Status $err error
    }
}
proc MimeSetDisplayFlag {part} {
    global mime mimeHdr msg uri

    # Flag to determine if we display the part or not.	We display it
    # if it's a multipart (other than multipart/parallel).  We display 
    # it if it's an image (unless we aren't supposed to do that.  Otherwise,
    # we display it unless we've been told not to or it's too darn big.
    if {[info exists mimeHdr($part,file)]} {
	if [regexp {^multipart} $mimeHdr($part,type)] {
	    set mimeHdr($part,display) \
		[expr ![regexp {parallel$} $mimeHdr($part,type)]]
	    return
	} elseif [regexp {^image} $mimeHdr($part,type)] {
	    set mimeHdr($part,display) $mime(showImage)
	    return
	} elseif [regexp {text/html} $mimeHdr($part,type)] {
	    set mimeHdr($part,display) $uri(deferDisplaysInline)
	    return
	}
	if [regexp {^text.*vcard} $mimeHdr($part,type)] {
	    set mimeHdr($part,display) 0
	    Exmh_Debug "vcard: not displaying"
	    return
	}
	if {[info exists mimeHdr($part,hdr,content-disposition)]} {
	    set disp [split $mimeHdr($part,hdr,content-disposition) \;]
	    if [regexp {ancillary} [lindex $disp 0]] {
		set mimeHdr($part,display) 0
		return
	    }
	}
	if ![info exists mimeHdr($part,display)] {
	    set mimeHdr($part,display) \
		[expr {[file exists $mimeHdr($part,file)] && \
			([file size $mimeHdr($part,file)] < $msg(maxsize))}]
	}
    }
}
proc MimeShowPartHeader {tkw part partTag only displayedPart desc} {
    global mimeHdr mime mimeFont

    set mimeHdr($part,HeaderSize) 0

    if {(!$only) || ([string length $desc] != 0)} {
	MimeWithTagging $tkw titleTag $partTag {-font $mimeFont(title)} {
	    set triangle $tkw.[MimeLabel $part triangle]
	    if [winfo exists $triangle] {
		$triangle create rectangle 0 0 10 10 \
			-fill $mimeHdr($part,color) \
			-outline $mimeHdr($part,color)
	    } else {
		canvas $triangle -background $mimeHdr($part,color) \
			-height 10 -width 10 -cursor arrow
		bind $triangle <ButtonPress-1> \
			[list busy MimeTogglePartDisplay $tkw $part] 
		set menu $mimeHdr($part,menu)
		bind $triangle <ButtonPress-3> "tk_popup $menu %X %Y"
	    }
	    if $mimeHdr($part,display) {
		$triangle create line 5 0 5 10 -arrow last 
	    } else {
		$triangle create line 0 5 10 5 -arrow last 
	    }
	    $tkw window create insert -window $triangle -padx 0 -pady 0
	    $tkw insert insert "$displayedPart\t"
	    set mimeHdr($part,HeaderSize) 1
	    if {[string length $desc] != 0} {
		MimeWithTagging $tkw descTag titleTag {-underline 1} {
		    Mime_PrintEncodedHeader $tkw descTag $desc \
					    bold r title $mime(titleSize)
		}
		set mimeHdr($part,HeaderSize) 1
	    }
	}
    }

    if {$mime(showType)} {
	$tkw insert insert \t
	MimeInsertNote $tkw $partTag $mimeHdr($part,type) 0
	set mimeHdr($part,HeaderSize) 1
    }
    if $mimeHdr($part,HeaderSize) {
	$tkw insert insert \n
    }
}
proc MimeTogglePartDisplay {tkw part} {
    global mimeHdr

    set mimeHdr($part,display) [expr {!$mimeHdr($part,display)}]
    MimeRedisplayPart $tkw $part
}
proc MimeRedisplayPart {tkw part} {
    global mimeHdr


    if ![info exists mimeHdr($part,HeaderSize)] {
	# Text part with bogus MIME menu
	return
    }
    $tkw configure -state normal
    set partTag [MimeLabel $part part]
    set start [$tkw index "$partTag.first + $mimeHdr($part,HeaderSize) line"]
    set end [$tkw index $partTag.last]

    MimeClearHigherTags $tkw $partTag $start $end
    $tkw mark set insert $end

    MimeWithTagging $tkw $partTag {} {} {

	set triangle $tkw.[MimeLabel $part triangle]
	if { ![winfo exists $triangle]} {
                canvas $triangle -background $mimeHdr($part,color) \
                        -height 10 -width 10 -cursor arrow
                bind $triangle <ButtonPress-1> \
                        [list busy MimeTogglePartDisplay $tkw $part]
                set menu $mimeHdr($part,menu)
                bind $triangle <ButtonPress-3> "tk_popup $menu %X %Y"
        }                                 

	$triangle create rectangle 0 0 10 10 \
		-fill $mimeHdr($part,color) \
		-outline $mimeHdr($part,color)
	if $mimeHdr($part,display) {
	    $triangle create line 5 0 5 10 -arrow last 
	} else {
	    $triangle create line 0 5 10 5 -arrow last 
	}
	MimeShowPartBody $tkw $part

	if [$tkw compare insert != "insert linestart"] {
	    $tkw insert insert "\n"
	}
    }

    MimeCleanTag $tkw 1
    $tkw delete $start $end
    $tkw mark set insert end
    Exmh_Status "Redisplayed $part"

    $tkw configure -state disabled
}
proc MimeRedisplaySubpart {tkw part} {
    global mimeHdr

    set partTag [MimeLabel \
		    $part=$mimeHdr($part,priorChosenPart) \
		    part]
    if [catch {
	set start [$tkw index $partTag.first]
	set end [$tkw index $partTag.last]
    }] {
	return
    }

    $tkw configure -state normal
    MimeClearHigherTags $tkw $partTag $start $end
    $tkw mark set insert $end

    MimeWithTagging $tkw partTag {} {} {
	MimeShowPart $tkw $part=$mimeHdr($part,chosenPart) \
		     [MimeLabel $part part] 1
	set mimeHdr($part,priorChosenPart) \
	    $mimeHdr($part,chosenPart)
    }

    MimeCleanTag $tkw 1	 
    $tkw delete $start $end
    $tkw mark set insert end
    Exmh_Status "Redisplayed $part=$mimeHdr($part,chosenPart)"
    
    $tkw configure -state disabled
}
proc Mime_ShowImage {tkw part} {
    global mimeHdr mime
    MimeWithDisplayHiding $tkw $part {
	if [catch {
	    set subtype [file tail $mimeHdr($part,type)]
	    if [info exists mime(imageFilter,$subtype)] {
		set newFile [Mime_TempFile $part]
		Exmh_Status "Running $subtype filter: $mime(imageFilter,$subtype)"
		if [catch {eval exec $mime(imageFilter,$subtype) < $mimeHdr($part,file) > $newFile} err] {
		    Exmh_Debug "$err while running $mime(imageFilter,$subtype)"
		}
		set mimeHdr($part,origFile) mimeHdr($part,file)
		set mimeHdr($part,file) $newFile
		set mimeHdr($part,type) "image/x-ppm"
	    }
	    if ![info exists mimeHdr($part,photo)] {
		Exmh_Status "Creating tk photo"
		set mimeHdr($part,photo) \
			[image create photo [MimeLabel $part image] \
			-file $mimeHdr($part,file)]
		Exmh_Status "Created tk photo"
	    }
	    set photo $tkw.[MimeLabel $part photo]
	    canvas $photo -height [image height $mimeHdr($part,photo)] \
	                  -width [image width $mimeHdr($part,photo)]
	    $photo create image 0 0 -image $mimeHdr($part,photo) \
	                            -anchor "nw" 
	    $tkw window create insert -window $photo
	    set menu $mimeHdr($part,menu)
	    bind $photo <ButtonPress-3> "tk_popup $menu %X %Y"
	    $tkw insert insert "\n"
	} err] {
	    Exmh_Debug "$err while displaying photo"
	    if ![catch {MimeGetRule $part "" atrib} viewer] {
		MimeInsertInfo $tkw $part
		$tkw insert insert "Opening viewer with:\n"
		$tkw insert insert "$viewer\n"
		if [info exists atrib(needsterminal)] {
		    exec xterm -e sh -c $viewer &
		} else {
		    exec sh -c $viewer > /dev/null &
		}
	    } else {
		Mime_ShowDefault $tkw $part
	    }
	}
    }
}
proc Mime_ShowDefault {tkw part} {
    global mimeHdr env

    Mime_GetUnencodedFile $part
    if [regexp {^multipart} $mimeHdr($part,type)] {
	if ![info exists mimeHdr($part,showParts)] {
	    set mimeHdr($part,showParts) 0
	    MimeMenuAdd $part checkbutton \
		-label "Display Parts" \
		-command [list busy MimeRedisplayPart $tkw $part] \
		-variable mimeHdr($part,showParts)
	}
    }
    if {[regexp {^multipart} $mimeHdr($part,type)] && \
	     $mimeHdr($part,showParts)} {
	$tkw insert insert "This is [Mime_TypeDescr $part]\t\t"
	MimeInsertNote $tkw [MimeLabel $part part] \
		       "Invoke menu with right button."
	Mime_ShowMultipart $tkw $part
    } elseif {![catch {set viewer [MimeGetRule $part "" atrib]}] && 
	[info exists atrib(copiousoutput)] &&
	![info exists atrib(needsterminal)]} {
	if ![info exists mimeHdr($part,copiousOut)] {
	    set newFile [Mime_TempFile $part]
	    if [catch {exec sh -c $viewer > $newFile} err] {
		if ![catch {open $newFile w} x] {
		    puts $x $err
		    catch {close $x}
		}
	    }
	    set mimeHdr($part,copiousOut) $newFile
	}
	MimeWithDisplayHiding $tkw $part {
	    if [catch {open $mimeHdr($part,copiousOut) r} fileIO] {
		Exmh_Status "Cannot open body $mimeHdr($part,copiousOut): $fileIO"
		return 1
	    }
	    set start [$tkw index insert]
	    $tkw insert insert [read $fileIO]
	    MimeClose $fileIO
	    set end [$tkw index insert]
	    Msg_TextHighlight $tkw $start $end
	}
    } else {
	$tkw insert insert "This is [Mime_TypeDescr $part]\n"
	if [info exists viewer] {
	    if ![info exists atrib(copiousoutput)] {
		$tkw insert insert "It can be displayed with \"$viewer\".\t"
		MimeInsertNote $tkw [MimeLabel $part part] \
		    "Invoke menu with right button."
	    }
	} elseif ![info exists env(NOMETAMAIL)] {
	    $tkw insert insert "It might be displayable with metamail.\t"
	    MimeInsertNote $tkw [MimeLabel $part part] \
		"Invoke menu with right button."
	}
	if [regexp {^multipart} $mimeHdr($part,type)] {
	    $tkw insert insert "Its subparts may be displayed individually.\t"
	    MimeInsertNote $tkw [MimeLabel $part part] \
		"Invoke menu with right button."
        }
	if [regexp {^text} $mimeHdr($part,type)] {
	    Mime_ShowText $tkw $part
	} else {
	    MimeInsertInfo $tkw $part
	}
	if [info exists mimeHdr($part,justDoIt)] {
	    if [info exists viewer] {
		if ![info exists atrib(copiousoutput)] {
		    if [info exists atrib(needsterminal)] {
			exec xterm -e sh -c $viewer &
		    } else {
			exec sh -c $viewer &
		    }
		}
	    } elseif ![info exists env(NOMETAMAIL)] {
		MimeMetaMail $mimeHdr($part,hdr,content-type) \
			     $mimeHdr($part,encoding) \
			     [MimeGetOrigFile $part]
	    } else {
		Exmh_Status "Couldn't display part $part"
	    }
	}
    }
    return 0
}
proc MimeInsertInfo {tkw part} {
    global mimeHdr

    foreach key $mimeHdr($part,params) {
	$tkw insert insert "\t$key = $mimeHdr($part,param,$key)\n"
    }

    if ![info exists mimeHdr($part,param,URI)] {
        MimeAddURIInfo $tkw $part
    }
}
proc MimeAddURIInfo { tkw part } {
    global mimeHdr

    if [info exists mimeHdr($part,param,access-type)] {
        if [string compare ANON-FTP $mimeHdr($part,param,access-type)] {
           return
        }
    }

    set uri ftp:/
    foreach uripart {site directory name} {
        if ![info exists mimeHdr($part,param,$uripart)] return
        append uri /$mimeHdr($part,param,$uripart)
    }
    $tkw insert insert "\tURI = $uri\n"
}
proc MimeMetaMail {contentType encoding fileName} {
    global mimeHdr

    if [catch {
	Exmh_Status "metamail $fileName -c $contentType ..."
	set mcmd [list exec metamail -b\
		    -c $contentType \
		    -E $encoding \
		    -f [MsgParseFrom $mimeHdr(0=1,hdr,from)] \
		    -m exmh ]
	if [regexp -nocase {^audio|^image|^video} $contentType] {
	    lappend mcmd -B
	} else {
	    lappend mcmd -p
	}
	lappend mcmd $fileName < /dev/null > /dev/null &
	# recall that eval concats its arguments, thus exploding things for us
	Exmh_Debug MimeMetaMail $mcmd
	eval $mcmd
    } err] {
	 Exmh_Status "$err"
    }
}

proc Mime_ShowText {tkw part} {
    global mimeHdr mime miscRE pgp

    MimeWithDisplayHiding $tkw $part {
	set subtype [file tail $mimeHdr($part,type)]
	Mime_WithTextFile fileIO $tkw $part {
	    gets $fileIO firstLine
	    if {$pgp(enabled) && [regexp $miscRE(beginpgp) $firstLine]} {
		# convert from text/plain to application/pgp
		set mimeHdr($part,type) "application/pgp"
		catch { unset mimeHdr($part,typeDescr) }
                if {[info exists mimeHdr($part,param,format)]} {
                    unset mimeHdr($part,param,format)
                    set i [lsearch $mimeHdr($part,params) format]
                    set mimeHdr($part,params) \
                        [lreplace $mimeHdr($part,params) $i $i]
                }
		Pgp_ShowMessage $tkw $part
	    } else {
		set textStart [$tkw index insert]
		$tkw insert insert "$firstLine\n"
		$tkw insert insert [read $fileIO]
		set textEnd [$tkw index insert]
		Msg_TextHighlight $tkw $textStart $textEnd
	    }
	}
    }
    return 1
}
proc Mime_ShowMsWord { tkw part } {
    global mimeHdr mime miscRE
    
    MimeWithDisplayHiding $tkw $part {
	set subtype [file tail $mimeHdr($part,type)]
	Mime_WithTextFile fileIO $tkw $part {
	    gets $fileIO firstLine
	    if [regexp $miscRE(beginpgp) $firstLine] {
		set mimeHdr($part,type) "application/pgp"
		catch { unset mimeHdr($part,typeDescr) }
		Pgp_ShowMessage $tkw $part
	    } else {
		set fileName [Mime_GetUnencodedFile $part]
		if {[catch {open "| antiword $fileName" r} G] && \
                       [catch {open "| lhalw -F $fileName" r} G]} {
		    return 0
		}
		$tkw insert insert [read $G]
		close $G
	    }
	}
    }
    return 1
}

proc Mime_ShowRichText {tkw part} {
    global mimeHdr mime

    MimeWithDisplayHiding $tkw $part {
	set subtype [file tail $mimeHdr($part,type)]
	Mime_WithTextFile fileIO $tkw $part {
	    Rich_Display $tkw $fileIO $part $subtype
	}
    }
    return 1
}
proc Mime_WithTextFile {fileIOVar tkw part body} {
    upvar $fileIOVar fileIO

    set fileName [Mime_GetUnencodedFile $part]
    if {[string length $fileName] == 0} {
	return
    }
    if [catch {open $fileName r} fileIO] {
	Exmh_Status "Cannot open body $fileName: $fileIO"
	return 1
    }

    # Set the encoding for the file based on its character set

    Mime_SetFileEncoding $fileIO $part

    # Errors or "return" statements hit this catch

    set code [catch {uplevel $body} err]

    MimeClose $fileIO

    # Reflect errors or early returns like a true control structure

    return -code $code $err
}

proc Mime_SetFileEncoding {fileIO part} {
    global tcl_version
    if {$tcl_version >= 8.1} {
	set charset [Mime_GetCharset {} $part]
	regsub {^us-} $charset {} charset
	regsub {^(mac|iso)-} $charset {\1} charset
	if {[catch {fconfigure $fileIO -encoding $charset} err]} {
	    Exmh_Debug "Mime_SetFileEncoding: $err"
	}
    }
}

proc Mime_GetUnencodedFile {part} {
    global mimeHdr mime

    if ![info exists mimeHdr($part,file)] {
	return {}
    }
    set fileName $mimeHdr($part,file)
    if ![info exists mimeHdr($part,origFile)] {
	set encoding $mimeHdr($part,encoding)
	if [regexp {^([78]bit|binary)$} $encoding] {
	    set mimeHdr($part,origFile) $fileName
	} else {
	    # Generate a new name with a template
	    set newFile [Mime_TempFile $part]
	    if {![MimeDecode $mimeHdr($part,file) \
			    $newFile $encoding \
			    [regexp {^text} $mimeHdr($part,type)]] &&
		    !$mime(stop)} {
		set mimeHdr($part,origFile) $fileName
		Exmh_Status "Decode failed - raw text follows"
		set mimeHdr($part,type) text/plain
		set mimeHdr($part,encoding) 8bit
	    } else {
		set mimeHdr($part,origFile) $fileName
		set fileName $newFile
		set mimeHdr($part,file) $newFile
	    }
	}
    }
    return $fileName
}
proc Mime_GetCharset {tkw part} {
    global mimeHdr mime

    set charset us-ascii
    if [info exists mimeHdr($part,param,charset)] {
	set charset [string tolower $mimeHdr($part,param,charset)]

	# Limit the encodings to ones for which we have fonts.

	if ![info exists mime(registry,$charset)] {
	    if {[string length $tkw]} {

		MimeInsertNote $tkw [MimeLabel $part charset] \
			       "Unknown charset: <$charset>"
		$tkw insert insert \n
	    }
	    set charset us-ascii
	}
    }
    return $charset
}
proc Mime_ShowRfc822 {tkw part} {
    global mimeHdr mime mhProfile exmh 

    set mimeHdr($part=1,color) $mimeHdr($part,color)

    Mime_GetUnencodedFile $part=1

    MimeWithDisplayHiding $tkw $part {
	if ![info exists mimeHdr($part=1,fullHeaders)] {
	    set mimeHdr($part=1,fullHeaders) $mime(fullHeaders)
	}
	MimeShowHeaders $tkw $part=1 [MimeLabel $part part]
	MimeInsertSeparator $tkw $part 6
    	if {$part == 0} {
	    MDNCheck $tkw
        }

	MimeShowPart $tkw $part=1 [MimeLabel $part part] 1
    }
    if {[string compare $part "0"] != 0} {
	MimeMenuAdd $part checkbutton \
		-label "Show full message headers" \
		-command [list busy MimeRedisplayHeaders $tkw $part=1] \
		-variable mimeHdr($part=1,fullHeaders)
	MimeMenuAdd $part command \
		-label "Extract a message/rfc822 into current folder" \
		-command [list busy MimeExtractMessage $tkw $part]
    }
    return 1
}

proc MimeExtractMessage {tkw part} {
    global exmh mimeHdr

    Mh_RefileFile $exmh(folder) $mimeHdr($part,file)
    Scan_Folder $exmh(folder) 0
    Exmh_Status "Extraction of part $part...done"
}

proc Mime_ShowMDN {tkw part} {
    Mime_ShowReport $tkw $part report { Mime_ExplainMDN $tkw $part report }
}

proc Mime_ShowDSN {tkw part} {
    Mime_ShowReport $tkw $part report { Mime_ExplainDSN $tkw $part report }
}

proc Mime_ShowReport {tkw part reportVar body } {
    global mimeHdr mime
    upvar $reportVar report

    if ![info exists mimeHdr($part,explainReport)] {
	set mimeHdr($part,explainReport) $mime(explainReport)
    }

    if {[string compare $part "0"] != 0} {
	MimeMenuAdd $part checkbutton \
		-label "Show explanation" \
		-command [list busy MimeRedisplayPart $tkw $part] \
		-variable mimeHdr($part,explainReport)
    }

    if [Mime_ShowText $tkw $part] {
	if { $mimeHdr($part,explainReport) && $mimeHdr($part,display) } {
	    MimeInsertSeparator $tkw $part 6

	    ParseReport $part report

	    if [info exists report(original-recipient)] {
		set recipient $report(original-recipient)
	    } elseif [info exists report(final-recipient)] {
		set recipient $report(final-recipient)
	    } else {
		set recipient "(unknown)"
	    }

	    $tkw insert insert \
	        "This is a report concerning the message you sent\
		 \n  to:      $recipient"

	    if [info exists mimeHdr($part,originalMessageDate)] {
		$tkw insert insert \
		"\n  on date: $mimeHdr($part,originalMessageDate)"
	    }

	    if [info exists mimeHdr($part,originalMessageEnclosed)] {
		if { $mimeHdr($part,originalMessageEnclosed) } {
		    $tkw insert insert "\n(A copy of the\
                        message is included below.)"
		}
	    }

	    $tkw insert insert "\n\n"

	    uplevel $body
	} else {
	    return 1
	}
    } else {
	return 0
    }
}

proc MimeShowHeaders {tkw part overTag} {
    global mimeHdr

    set inlin [expr {[string compare $part "0=1"] == 0}]
    MimeWithTagging $tkw [MimeLabel $part headers] $overTag {} {
	if $mimeHdr($part,fullHeaders) {
	    MimeShowFullHeaders $tkw $part $inlin
	} else {
	    MimeShowMinHeaders $tkw $part $inlin
	}
    }
}
proc MimeShowFullHeaders {tkw part inlin} {
    global mimeHdr msg mime

    if {$inlin} {
	set mimeHdr($part,yview) 1.0
    }
    if [info exists mimeHdr($part,hdrs)] {
	foreach hdr $mimeHdr($part,hdrs) {
	    set start [$tkw index insert]
	    # Check for multiple headers
	    # Replied:
	    # :0:Replied:
	    # :1:Replied:
	    if ![regsub {^:[0-9]+:} $hdr {} truehdr] {
		set truehdr $hdr
	    }
	    $tkw insert insert [string toupper [string index $truehdr 0]]
	    $tkw insert insert "[string range $truehdr 1 end]: "
	    set tag [Mime_PrintEncodedHeader $tkw [MimeLabel $part headers] \
				    $mimeHdr($part,hdr,$hdr) \
				    medium r plain $mime(fontSize)]
	    if [regexp -nocase date $truehdr] {
		MimeShowTime $tkw $mimeHdr($part,hdr,$hdr)
	    }
	    $tkw insert insert \n
	    foreach key [list $truehdr default] {
		if [info exists msg(tag,$key)] {
		    $tkw tag add hdrlook=$key $start "insert -1 char"
		    if {[string length $tag] != 0} {
			$tkw tag lower hdrlook=$key $tag
		    }
		    break
		}
	    }
	}
    }
}

# Show local time if message from another tz
# e.g.
#      Mon, 18 May 1998 11:58:39 GMT
# is shown as
#      Mon, 18 May 1998 11:58:39 GMT (13:58 MET DST)
#

proc MimeShowTime { tkw time } {
    global mime

    catch {
	set msgtime   [clock scan $time]
	set localtime [clock format $msgtime -format " %T"]
	if { [string first $localtime $time] == -1 } {
	    Preferences_Resource mime(localTimeFormat) localTimeFormat \
		"%H:%M %Z"
	    set format $mime(localTimeFormat)
	    set day [clock format $msgtime -format %a]
	    if { [string first $day $time] == -1 } {
		set format "%a $format"
	    }
	    set msgtime [clock format $msgtime -format $format]
	    $tkw insert insert " ($msgtime)"
	}
    }
}

proc MimeSortHeaders { a b } {
    global mhProfile

   return [expr [lsearch -regexp $mhProfile(header-display) $a] - \
	[lsearch -regexp $mhProfile(header-display) $b]]
 
}
proc MimeShowMinHeaders {tkw part inlin} {
    global mimeHdr mhProfile msg mime
    
    if ![info exists mimeHdr($part,hdrs)] {
        return
    }
    set hideMark 1.0

    foreach hdr [lsort -command MimeSortHeaders $mimeHdr($part,hdrs)] {
        # Check for multiple headers
	# Replied:
	# :0:Replied:
	# :1:Replied:
	if ![regsub {^:[0-9]+:} $hdr {} truehdr] {
	    set truehdr $hdr
	}
	set show 1
	foreach item $mhProfile(header-suppress) {
	    if [regexp -nocase ^${item}\$ $truehdr] {
		set show 0
		break
	    }
	}
	foreach item $mhProfile(header-display) {
	    if [regexp -nocase ^${item}\$ $truehdr] {
		set show 1
		break
	    }
	}
	if {!$show || ([string length $mimeHdr($part,hdr,$hdr)] == 0)} {
	    if $inlin {
		$tkw mark set insert $hideMark
		set show 0
	    } else {
		continue
	    }
	}
	set start [$tkw index insert]
	$tkw insert insert [string toupper [string index $truehdr 0]]
	$tkw insert insert "[string range $truehdr 1 end]: "
	set tag [Mime_PrintEncodedHeader $tkw [MimeLabel $part headers] \
				$mimeHdr($part,hdr,$hdr) \
				medium r plain $mime(fontSize)]
	if [regexp -nocase date $truehdr] {
	    MimeShowTime $tkw $mimeHdr($part,hdr,$hdr)
	}
	$tkw insert insert \n
	foreach key [list $truehdr [expr {$show ? "default" : "hidden"}]] {
	    if [info exists msg(tag,$key)] {
		$tkw tag add hdrlook=$key $start "insert -1 char"
		if {[string length $tag] != 0} {
		    $tkw tag lower hdrlook=$key $tag
		}
		break
	    }
	}
	if {! $show} {
	    set hideMark [$tkw index insert]
	    $tkw mark set insert "end -1c"
	}
    }
    if {$inlin} {
	set mimeHdr($part,yview) $hideMark
    }
    return
}
proc MimeRedisplayHeaders {tkw part} {
    global mimeHdr

    $tkw configure -state normal
    set headerTag [MimeLabel $part headers]
    if ![catch {set start [$tkw index $headerTag.first]}] {
	set end [$tkw index $headerTag.last]

	MimeClearHigherTags $tkw $headerTag $start $end
	$tkw mark set insert $end

	MimeShowHeaders $tkw $part {}

	MimeCleanTag $tkw 1
	$tkw delete $start $end
	$tkw mark set insert end
    }
    Exmh_Status "Redisplayed headers for $part"

    $tkw configure -state disabled
}
proc MimeDecode {fileName name encoding text} {
    global mime
    set ok 1
    Exmh_Debug MimeDecode $fileName $name $encoding $text
    if [file exists $name] {
	if {! [FileExistsDialog $name]} {
	    Exmh_Status "Save canceled"
	    return 0
	}
    }
    if [catch {
	set out [open $name w 0600]
	switch -regexp -- $encoding {
	    (8|7)bit {
		Exmh_Debug "cat > $name"
		exec cat $fileName >@ $out
	    }
	    base64 {
		if $text {
		    Exmh_Debug "$mime(encode) -u -b -p > $name"
		    exec $mime(encode) -u -b -p $fileName >@ $out
		} else {
		    Exmh_Debug "$mime(encode) -u -b > $name"
		    exec $mime(encode) -u -b $fileName >@ $out
		}
	    }
	    quoted-printable {
		Exmh_Debug "$mime(encode) -u -q > $name"
		exec $mime(encode) -u -q $fileName >@ $out
	    }
	    .*uue.* {
		Exmh_Debug "uudecode -p > $name"
		close $out
		Mime_Uudecode $fileName $name
	    }
	    default {
		Exmh_Debug "cat > $name"
		exec cat $fileName >@ $out
	      }
	}
	catch {close $out}
    } err] {
	Exmh_Status "Decode failed: $err"
	catch {close $out}
	set ok 0
    }
    return $ok
}

proc Mime_ShowApplicationOctet {tkw part} {
    global mimeHdr

    $tkw insert insert "You have received an encoded file.\t\t"
    MimeInsertNote $tkw [MimeLabel $part part] \
		   "Invoke menu with right button."
    MimeInsertInfo $tkw $part
    $tkw insert insert \n
    TextButton $tkw "Decode and Save..." \
	[list Mime_SavePiece $part $mimeHdr($part,type)]
    return 0
}
proc Mime_ShowMessageExternal {tkw part} {
    global mimeHdr mime

    if ![info exists mimeHdr($part,param,access-type)] {
	return [Mime_ShowDefault $tkw $part]
    }

    MimeInsertInfo $tkw $part

    if ![info exists mimeHdr($part,numParts)] {
	set fileName $mimeHdr($part,file)
	if [catch {open $fileName r} fileIO] {
	    Exmh_Status "Cannot open body $fileName: $fileIO"
	    return 1
	}

	set mimeHdr($part,numParts) \
		[MimeParseSingle $tkw $part $fileIO]
	MimeClose $fileIO

	if [info exists mimeHdr($part=1,file)] {
	    set mimeHdr($part=1,phantom-body) \
		$mimeHdr($part=1,file)
	    unset mimeHdr($part=1,file)
	}

	set atype [string tolower $mimeHdr($part,param,access-type)]
	set type $mimeHdr($part=1,type)

	if [info exists mime(accessMethod,$atype)] {
	    # Special hack to not have to fetch a local-file
	    if {[string compare $atype "local-file"] == 0} {
		$mime(accessMethod,$atype) $tkw $part
	    } else {
		MimeMenuAdd $part command \
			-label "Get $type via $atype..." \
			-command [list MimeTransferFile $tkw $part]
		MimeMenuDelete $part Save*...
	    }
	}
    } else {
	set atype [string tolower $mimeHdr($part,param,access-type)]
	set type $mimeHdr($part=1,type)
    }
    if ![info exists mime(accessMethod,$atype)] {
	MimeInsertNote $tkw [MimeLabel $part part] \
		       "Use Metamail to access $type via '$atype'"
    }

    set color $mimeHdr($part,color)
    $tkw tag configure [MimeLabel $part part] -background \
	[MimeDarkerColor $tkw $mimeHdr($part,color)] \
	-foreground [$tkw cget -foreground]
    set mimeHdr($part=1,color) $color

    MimeInsertSeparator $tkw $part 6
    MimeShowPart $tkw $part=1 [MimeLabel $part part] 1

    return 0
}
proc MimeTransferFile {tkw part} {
    global mimeHdr mime

    $mime(accessMethod,[string tolower $mimeHdr($part,param,access-type)]) \
	$tkw $part

    MimeSetStdMenuItems $tkw $part

    MimeSetDisplayFlag $part
    MimeRedisplayPart $tkw $part
}
proc MimeLocalFileTransfer {tkw part} {
    global mime mimeHdr

    set name $mimeHdr($part,param,name)
    set dir $mimeHdr($part,param,directory)

    set mimeHdr($part=1,file) [file join $dir $name]
}
proc MimeFTPTransfer {tkw part} {
    global mime mimeHdr

    set site $mimeHdr($part,param,site)
    set directory $mimeHdr($part,param,directory)
    set theirname $mimeHdr($part,param,name)

    if ![string compare "URI tool" $mime(ftpMethod)] {
	busy URI_StartViewer "ftp://$site/$directory/$theirname"
	Exmh_Status "FTP request send to your WWW browser"
	return
    }

    set myname [Mime_TempFile $part=1]
    if [info exists mimeHdr($part,param,mode)] {
	set mode $mimeHdr($part,param,mode)
    } else {
	set mode binary
    }
    if {[string length $myname] != 0} {
	if [catch {
	    case $mime(ftpMethod) {
		expect {
		    Exmh_Status "ftp.expect $site ..."
		    busy exec ftp.expect $site $directory $theirname $myname $mode
		}
		ftp* {
		    Exmh_Status "$mime(ftpCommand) -n $site ..."
		    busy MimeFTPInner $site $directory $theirname $myname $mode
		}
		metamail {
		    MimeMetaMail $mimeHdr($part,hdr,content-type) \
			   $mimeHdr($part,encoding) \
			   $mimeHdr($part,file)
		}
		default {
		    error "Unknown ftpMethod $mime(ftpMethod)"
		}
	    }
	} err] {
	    if [Exwin_Toplevel .ftpmsg "FTP error"] {
		Widget_Text .ftpmsg 20
	    }
	    .ftpmsg.t delete 1.0 end
	    .ftpmsg.t insert 1.0 \
"Messages generated during FTP transfer:

$err
"
	} else {
	    Exmh_Status "FTP transfer complete"
	}
    }
    set mimeHdr($part=1,file) $myname
    set mimeHdr($part=1,param,name) $theirname
}
proc MimeFTPInner {site directory theirname myname mode} {
    global env mime

    if {[string compare $mime(ftpMethod) "ftp -n"] == 0} {
	set pipe [open "|$mime(ftpCommand) -n $site " w]
	puts $pipe "user anonymous $env(USER)@"
    } else {
	set pipe [open "|$mime(ftpCommand) $site" w]
	puts $pipe anonymous
	puts $pipe $env(USER)@
    }
    puts $pipe "cd $directory"
    puts $pipe "type $mode"
    puts $pipe "get $theirname $myname"
    puts $pipe "quit"
    MimeClose $pipe
}

proc Mime_ShowMultipart {tkw part} {
    global mimeHdr mime

    set mime(stop) 0
    set mime(grab) 0	;# Global state so there is only one grab
    set grab	   0	;# This level's state
    MimeWithDisplayHiding $tkw $part {
	if ![info exists mimeHdr($part,param,boundary)] {
	    $tkw insert insert "No <boundary> parameter for multipart message\n"
	    $tkw insert insert "Raw content follows...\n\n"
	    return [Mime_ShowText $tkw $part]
	}

	Exmh_Debug "Mime_ShowMultipart $part $mimeHdr($part,type)"

	set numParts $mimeHdr($part,numParts)
	if {$numParts > $mime(maxSubpartsDisplayed) && !$mime(grab)} {
	    global exwin
	    set g $exwin(mtext).mstop
	    if [winfo exists $g] {
		destroy $g
	    }
	    frame $g -bd 4 -relief raised
	    set f [frame $g.pad -bd 20]
	    set msg [Widget_Message $f msg -text "$numParts Parts" -width 200]
	    Widget_AddBut $f stop STOP {set mime(stop) 1} {top padx 2 pady 2 filly}
	    bind $f.stop <Any-Key> {set mime(stop) 1; Exmh_Status Stop warn}
	    pack $f
	    Widget_PlaceDialog $exwin(mtext) $g
	    Visibility_Wait $f.stop
	    focus $f.stop
	    catch {grab $f.stop}
	    set mime(grab) 1
	    set grab 1
	}

	if [catch {
	    for {set subpart 1} {$subpart <= $numParts} {incr subpart} {
    
		set mimeHdr($part=$subpart,color) \
		    [MimeDarkerColor $tkw $mimeHdr($part,color)]
		set mimeHdr($part=$subpart,display) \
		    [expr {($numParts <= $mime(maxSubpartsDisplayed)) || \
			   ![regexp -nocase "^multipart|^message" \
				 $mimeHdr($part=$subpart,type)]}]
		if {$subpart != 1} {
		    if [info exists msg] {
			$msg config -text "$subpart of $numParts parts"
		    }
		    MimeInsertSeparator $tkw $part 8
		}
		MimeShowPart $tkw $part=$subpart [MimeLabel $part part] 0
		if {$mime(grab)} {
		    update;	# Allow button hit
		}
		if {$mime(stop)} {
		    break
		}
	    }
	} err] {
	    Exmh_Status $err
	}
    }
    if {$grab} {
	catch {grab release $g.stop}
	Exmh_Focus
	destroy $g
	set mime(grab) 0
    }
    return 1
}
proc Mime_ShowMultipartParallel {tkw part} {
    global mimeHdr mime

    MimeWithDisplayHiding $tkw $part {
	if ![info exists mimeHdr($part,param,boundary)] {
	    $tkw insert insert "No <boundary> parameter for multipart message\n"
	    $tkw insert insert "Raw content follows...\n\n"
	    return [Mime_ShowText $tkw $part]
	}

	set numParts $mimeHdr($part,numParts)
	
	for {set subpart 1} {$subpart <= $numParts} {incr subpart} {
	    set mimeHdr($part=$subpart,color) \
		[MimeDarkerColor $tkw $mimeHdr($part,color)]
	    set mimeHdr($part=$subpart,justDoIt) 1
	    if {$subpart != 1} {
		MimeInsertSeparator $tkw $part 8
	    }
	    MimeShowPart $tkw $part=$subpart [MimeLabel $part part] 0
	}
    }
    return 1
}
proc Mime_ShowMultipartDigest {tkw part} {
    global mimeHdr mime

    MimeWithDisplayHiding $tkw $part {
	if ![info exists mimeHdr($part,param,boundary)] {
	    $tkw insert insert "No <boundary> parameter for multipart message\n"
	    $tkw insert insert "Raw content follows...\n\n"
	    return [Mime_ShowText $tkw $part]
	}

	set numParts $mimeHdr($part,numParts)
	
	Exmh_Debug DIGEST with $numParts parts
	for {set subpart 1} {$subpart <= $numParts} {incr subpart} {
	    Exmh_Debug digest $part $subpart 
	    set mimeHdr($part=$subpart,color) \
		[MimeDarkerColor $tkw $mimeHdr($part,color)]
	    set mimeHdr($part=$subpart,type) message/rfc822
	    set mimeHdr($part=$subpart,display) \
		[expr {$numParts <= $mime(maxSubpartsDisplayed)}]
	    if {$subpart != 1} {
		MimeInsertSeparator $tkw $part 8
	    }
	    MimeShowPart $tkw $part=$subpart [MimeLabel $part part] 0
	}
    }
    return 1
}
proc Mime_ShowMultipartAlternative {tkw part} {
    global mimeHdr mime

    if ![info exists mimeHdr($part,param,boundary)] {
	$tkw insert insert "No <boundary> parameter for multipart message\n"
	$tkw insert insert "Raw content follows...\n\n"
	return [Mime_ShowText $tkw $part]
    }

    set color $mimeHdr($part,color)
    $tkw tag configure [MimeLabel $part part] -background \
	[MimeDarkerColor $tkw [MimeDarkerColor $tkw $color]] \
	-foreground [$tkw cget -foreground]

    set numParts $mimeHdr($part,numParts)
	
    # If we can't read any parts, "display" the first one.
    set mimeHdr($part,chosenPart) 1

    for {set subpart 1} {$subpart <= $numParts} {incr subpart} {
	set mimeHdr($part=$subpart,color) $color
	set type $mimeHdr($part=$subpart,type)
	# Choose the last part that we understand
	foreach t [list $type [file dirname $type]] {
	    if [info exists mime(showproc,$t)] {
		set mimeHdr($part,chosenPart) $subpart
	    }
	}
	if [MimeCheckRule $part=$subpart ""] {
	    set mimeHdr($part,chosenPart) $subpart
  	}
	# Provide menu items to get to all parts
	MimeMenuAdd $part radiobutton \
		  -label "Show alternative $subpart: $type" \
		  -command [list busy MimeRedisplaySubpart $tkw \
				 $part] \
		  -variable mimeHdr($part,chosenPart) \
		  -value $subpart
    }

    # If we find a type we like, use that subpart instead
    # This is to support display of text/plain instead of text/html

    set preferred [option get . mime_alternative_prefs {}]
    set selected 0
    foreach preftype $preferred {
	for {set subpart 1} {$subpart <= $numParts} {incr subpart} {
	    set type $mimeHdr($part=$subpart,type)
	    if {$type == $preftype} {
		set mimeHdr($part,chosenPart) $subpart
		set selected 1
		break
	    }
	}
	if {$selected != 0} {break}
    }

    set mimeHdr($part,priorChosenPart) \
	$mimeHdr($part,chosenPart)

    $tkw insert insert "There are alternative views of the following:\t"
    MimeInsertNote $tkw [MimeLabel $part part] \
		   "Invoke menu with right button."
    MimeInsertSeparator $tkw $part 6
    MimeShowPart $tkw $part=$mimeHdr($part,chosenPart) \
		 [MimeLabel $part part] 1

    return 1
}

proc MimeShowReportPart {tkw part overTag only reportPart} {
    global mimeHdr

    set partTag [MimeLabel $part part]
    if ![info exists mimeHdr($part,decode)] {
	# decode sub-parts by default, but not main body
	set mimeHdr($part,decode) [string compare $part 0=1]
    }
    MimeWithTagging $tkw $partTag $overTag \
		    {-background $mimeHdr($part,color) \
		     -foreground [$tkw cget -foreground]} {
	MimeSetPartVars desc displayedPart $tkw $part $partTag
	MimeSetStdMenuItems $tkw $part
	MimeShowPartHeader $tkw $part $partTag $only $reportPart $desc
	MimeShowPartBody $tkw $part
    }
    Exmh_Status $desc
}

proc Mime_ShowMultipartReport {tkw part} {
    global mimeHdr mime

    MimeWithDisplayHiding $tkw $part {
	if ![info exists mimeHdr($part,param,boundary)] {
	    $tkw insert insert "No <boundary> parameter for multipart message\n"
	    $tkw insert insert "Raw content follows...\n\n"
	    return [Mime_ShowText $tkw $part]
	}

	set numParts $mimeHdr($part,numParts)

	if { $numParts < 2 || $numParts > 3 } {
	    $tkw insert insert "Incorrect number of parts in multipart/report\n"
	}

	if { $numParts >= 1 } {
	    set mimeHdr($part=1,color) \
		[MimeDarkerColor $tkw $mimeHdr($part,color)]
	    set mimeHdr($part=1,justDoIt) 1
	    MimeShowReportPart $tkw $part=1 [MimeLabel $part part] 0 \
		"Human-readable report  "
	}

	if { $numParts >= 2 } {
	    set mimeHdr($part=2,color) \
		[MimeDarkerColor $tkw $mimeHdr($part,color)]
	    set mimeHdr($part=2,justDoIt) 1
	    MimeInsertSeparator $tkw $part 8

	    if { $numParts >= 3 } {
		set mimeHdr($part=2,originalMessageEnclosed) 1

		if [catch {open $mimeHdr($part=3,file)} in] {
		    error "Cannot read original message file"
		} else {
		    while {! [eof $in]} {
			set len [gets $in line]
			if {[string match "date:*" [string tolower $line]]} {
			    set mimeHdr($part=2,originalMessageDate) \
				[string trim [string range $line 5 end]]
			}
		    }
		    close $in
		}

	    } else {
		set mimeHdr($part=2,originalMessageEnclosed) 0
	    }

	    MimeShowReportPart $tkw $part=2 [MimeLabel $part part] 0 \
		"Machine-readable report"
	}
	
	if { $numParts >= 3 } {
	    set mimeHdr($part=3,color) \
		[MimeDarkerColor $tkw $mimeHdr($part,color)]
	    set mimeHdr($part=3,justDoIt) 1
	    MimeInsertSeparator $tkw $part 8
	    MimeShowReportPart $tkw $part=3 [MimeLabel $part part] 0 \
		"Original message       "
	}

	for {set subpart 4} {$subpart <= $numParts} {incr subpart} {
	    set mimeHdr($part=$subpart,color) \
		[MimeDarkerColor $tkw $mimeHdr($part,color)]
	    set mimeHdr($part=$subpart,justDoIt) 1
	    MimeInsertSeparator $tkw $part 8
	    MimeShowPart $tkw $part=$subpart [MimeLabel $part part] 0
	}
    }
}

proc ParseReport {part reportVar} {

    global mimeHdr

    upvar $reportVar report
    set uniq 1
    set cur  " "

    if [catch {open $mimeHdr($part,file)} in] {
	error "Cannot read report body"
    }
    while {! [eof $in]} {
	gets $in line
Exmh_Status "Parse report: $line"
	if ![regexp {^[	 ]} $line] {
	    if [regexp -indices {^([^:]+):} $line match hdr] {
		set cur [string tolower [eval {string range $line} $hdr]]
		if [info exists report($cur)] {
		    # Duplicate header
		    set cur :$uniq:$cur
		    incr uniq
		}
		set report($cur) \
		    [string trim \
			 [string range $line \
			      [expr [lindex $match 1]+1] end]]
Exmh_Status "  header: $cur: $report($cur)"
	    }
	} elseif [regexp -indices {^[	 ]+} $line match] {
	    append report($cur) \n$line
	}
    }
    close $in
}

proc Mime_ExplainMDN {tkw part reportVar} {
    global mimeHdr mime
    upvar $reportVar report

    if [info exists report(disposition)] {
	$tkw insert insert \
"This report is a message disposition notification, which reports
details on how the recipient received the message.\n\n"
	MDNExplainDisposition $tkw report
    } else {
	$tkw insert insert \
"This report is a message disposition notification, which indicates that
the message probably was received by the recipient, but no further details 
are known.  There is no guarantee that the message actually was seen
or acted on by the recipient."
    }
    return 1
}

proc Mime_ExplainDSN {tkw part reportVar} {
    global mimeHdr mime
    upvar $reportVar report

    $tkw insert insert "\
This report is a delivery status notification, that reports actions taken
by the message transport system in delivering the message to the 
recipient."

    return 1
}

proc MimeChopPart {tkw part} {
    # Chop up the parts at this level if it hasn't already been done.
    global mimeHdr

    if ![info exists mimeHdr($part,numParts)] {
	set fileName $mimeHdr($part,file)
	if [catch {set mimeHdr($part,param,boundary)} boundary] {
	    # Not a valid multpart
	    Exmh_Status "Invalid MIME Multipart"
	    set mimeHdr($part,content-type) text/plain
	    set mimeHdr($part,numParts) 0
	    return
	}
	# spaces in boundarys can cause line breaks - cc-mail trash
	regsub -all "\n *" $boundary { } boundary
	set type $mimeHdr($part,type)
	if [catch {open $fileName r} fileIO] {
	    $tkw insert insert "Mime_ChopPart $fileName: $fileIO\n"
	    return 0
	}
	set mimeHdr($part,numParts) \
	    [MimeParseMulti $tkw $part $fileIO $boundary \
		[expr {($type == "multipart/digest") ? \
		    "message/rfc822" : "text/plain"}]]
	MimeClose $fileIO
    }
}
proc MimeParseMulti {tkw part fileIO boundary defType} {
    global mimeHdr mime

    set subpart 0

    # Prolog
    while {([set numBytes [gets $fileIO line]] >= 0) &&
	   ([string compare --$boundary $line] != 0) &&
	   ([string compare --$boundary-- $line] != 0)} {
	if {$mime(showPrelude)} {
	    $tkw insert insert $line\n
	}
    }

    while {($numBytes >= 0) && ([string compare --$boundary-- $line] != 0)} {
	incr subpart
	set mimeHdr($part=$subpart,file) \
	    [Mime_TempFile $part=$subpart]
	set tmpFile [open $mimeHdr($part=$subpart,file) w 0600]
	catch {unset contentType}

	# Header
	while {([set numBytes [gets $fileIO line]] > 0) &&
	       ([string compare --$boundary-- $line] != 0) &&
	       ([string compare --$boundary $line] != 0) &&
	       (! [regexp -- {^-*$} $line])} {
	    if ![regexp {^[	 ]} $line] {
		if [regexp -indices {^([^:]+):} $line match hdr] {
		    set cur [string tolower \
				[eval {string range $line} $hdr]]
		    set mimeHdr($part=$subpart,hdr,$cur) \
			[string trim \
				[string range $line \
				    [expr [lindex $match 1]+1] end]]
		    lappend mimeHdr($part=$subpart,hdrs) $cur
		}
	    } elseif [regexp -indices {^[	 ]+} $line match] {
		if {![info exists cur] || [regexp {^[	 ]+$} $line]} {
		    # No header!
		    puts $tmpFile $line
		    break
		}
		append mimeHdr($part=$subpart,hdr,$cur) \n$line
	    }
	}
	if {($numBytes >= 0) && ([string compare --$boundary-- $line] != 0)} {
	    MimeMapSunHeaders $tkw $part=$subpart
	    if [catch {set mimeHdr($part=$subpart,hdr,content-type)} contentType] {
		set contentType $defType
	    }
	    if [catch {set mimeHdr($part=$subpart,hdr,content-transfer-encoding)} encoding] {
		set encoding 7bit
	    }
	    set encoding [string trim [string tolower $encoding] \ \" ]
	    set type [MimeHeader $part=$subpart $contentType $encoding]

	    # Body
            set sep ""
	    while {([set numBytes [gets $fileIO line]] >= 0) &&
		   ([string compare --$boundary $line] != 0) &&
		   ([string compare --$boundary-- $line] != 0)} {
		puts -nonewline $tmpFile $sep$line
		set sep \n
		if $mime(stop) {
		    break
		}
	    }
	    catch {unset cur}
	}
	if ![info exists contentType] {
	    # Empty body part
	    incr subpart -1
	}
	close $tmpFile
    }
    return $subpart
}
proc MimeParseSingle {tkw part fileIO } {
    global mimeHdr mime miscRE msg

    set mimeHdr($part=1,color) $mimeHdr($part,color)
    set part $part=1
    set mimeHdr($part,hdrs) {}
    set uniq 0

    # Skip any blank lines or "ugly uucp-style From_ lines" at the frontend.
    while {([set numBytes [gets $fileIO line]] == 0) ||
	   [regexp {^(>?From |[	 ]+$)} $line]} {}

    # Read and parse headers
    # Display in-line if on the fastpath (first part)
    set fast [expr {[string compare $part "0=1"] == 0}]

    if [regexp {^([^: ]+):} $line] {
	while {$numBytes > 0} {
	    if {[regexp -- {^-*$} $line]} {
		# Drafts-folder message
		break
	    }
	    if ![regexp {^[	 ]} $line] {
		if [regexp -indices {^([^:]+):} $line match hdr] {
		    set cur [string tolower \
				[eval {string range $line} $hdr]]
		    if {[lsearch $mimeHdr($part,hdrs) $cur] >= 0} {
			# Duplicate header
			set cur :$uniq:$cur
			incr uniq
		    }
		    set mimeHdr($part,hdr,$cur) \
			    [string trim \
				[string range $line \
				    [expr [lindex $match 1]+1] end]]
		    lappend mimeHdr($part,hdrs) $cur
		}
	    } elseif [regexp -indices {^[	 ]+} $line match] {
		append mimeHdr($part,hdr,$cur) \n$line
	    }
	    set numBytes [gets $fileIO line]
	}
	if [catch {set mimeHdr($part,hdr,content-type)} contentType] {
	    set contentType text/plain
	}
	if [catch {set mimeHdr($part,hdr,content-transfer-encoding)} encoding] {
	    set encoding 7bit
	}
	if {[string compare $contentType X-sun-attachment] == 0} {
	    set contentType "multipart/x-sun-attachment; boundary=--------"
	    set mimeHdr(0=1,hdr,mime-version) x-sun-attachment
	}
	set encoding [string trim [string tolower $encoding] \ \" ]
	set type [MimeHeader $part $contentType $encoding]
	if {[string compare $part "0=1"] == 0} {
	    set mimeHdr($part,decode) \
		[expr {$mime(enabled) && 
		       [info exists mimeHdr(0=1,hdr,content-type)]}]
	}

    } else {
	Exmh_Status "Warning - no headers" warn
	set firstLine $line
	set mimeHdr($part,type) [set type text/plain]
	set mimeHdr($part,encoding) [set encoding 8bit]
	set mimeHdr($part,params) {}
    }
    if {![info exists firstLine]} {
	set firstLinePosition [tell $fileIO]
	gets $fileIO firstLine
	if [regexp $miscRE(beginpgp) $firstLine] { set mimeHdr($part,decode) 1 }
    }
    if {$numBytes >= 0} {
	if {$fast && [string compare $type text/plain] == 0 &&
	    [regexp {[78]bit} $encoding] &&
            ![regexp $miscRE(beginpgp) $firstLine]} {
	    Exmh_Debug FastPath part=$part
	    if $mimeHdr($part,fullHeaders) {
		MimeShowFullHeaders $tkw $part 1
	    } else {
		MimeShowMinHeaders $tkw $part 1
	    }
	    MimeInsertSeparator $tkw $part 6
	    MDNCheck $tkw
	    if [info exists mimeHdr($part,param,charset)] {
		set tag [MimeSetCharset $tkw $part]
		$tkw tag remove noteTag "insert -1line"  end
		$tkw tag add $tag insert end
		if [info exists firstLinePosition] {
		    seek $fileIO $firstLinePosition
		}
		Mime_SetFileEncoding $fileIO $part
		if [info exists firstLinePosition] {
		    gets $fileIO firstLine
		}
	    }  else {
		set tag {}
	    }
	    set start [$tkw index "end -1line"]
	    $tkw insert end $firstLine\n $tag
	    set size [expr $msg(maxsize) / 2]
	    while {1} {
		$tkw insert insert [read $fileIO $size] $tag
		if {! [eof $fileIO]} {
		    update
		} else {
		    break
		}
		if {$mime(stop)} {
		    break
		}
	    }
	    set end [$tkw index end]
	    Msg_TextHighlight $tkw $start $end
	    return 0
	} else {
	    # Copy message body to a temp file.
	    set mimeHdr($part,file) [Mime_TempFile $part]
	    set tmpFile [open $mimeHdr($part,file) w 0600]
	    if [info exists firstLine] {
		puts $tmpFile $firstLine
	    }
	    if [catch {
		while {1} {
		    puts -nonewline $tmpFile [read $fileIO $msg(maxsize)]
		    if {! [eof $fileIO]} {
			update
		    } else {
			break
		    }
		    if {$mime(stop)} {
			break
		    }
		}
		close $tmpFile
	    } err] {
		catch {close $tmpFile}
		Exmh_Status $err
		File_Delete $mimeHdr($part,file)
		set mimeHdr($part,file) {}
	    }
	}
    }
    return 1
}
proc MimeDarkerColor {tkw color} {
    set rgb [winfo rgb $tkw [MimeColor $tkw $color]]
    return [format "#%04x%04x%04x" \
	[expr int([lindex $rgb 0] * .95)] \
	[expr int([lindex $rgb 1] * .95)] \
	[expr int([lindex $rgb 2] * .95)]]
}
proc MimeLabel {part name} {
    regsub -all { } $name _ name
    return ==$name=$part==
}
proc MimeLabelFont {part name} {
    # create a label which may be used as either a tag or a mark.
    # Using the label in an index context doesn't work if there are
    # dashes in the name.
    regsub -all -- - ==$name=$part== = tagName
    # *'s screw up my tag raising routine
    regsub -all -- {\*} $tagName # tagName
    return $tagName
}
proc MimeMakeMenu {tkw tag part menuLabel} {
    global mimeHdr mime mimeFont

    set mimeHdr($part,menu) $tkw.$tag
    if [catch {menu $mimeHdr($part,menu)} err] {
	switch -regexp -- $err {
	    {already exists} {
		$mimeHdr($part,menu) delete 0 999
	    }
	    {font.*doesn't exist} {
		if [catch {menu $mimeHdr($part,menu) -font fixed} err2] {
		    Exmh_Status "MimeMakeMenu $err2"
		    return
		}
	    }
	    default {
		Exmh_Status "MimeMakeMenu $err"
		return
	    }
	}
    }

    $mimeHdr($part,menu) config -tearoff 0
    $mimeHdr($part,menu) configure -disabledforeground Black
    MimeMenuAdd $part command \
	-label $menuLabel \
	-state disabled \
	-font $mimeFont(title)
    MimeMenuAdd $part separator

    menu_bind $mimeHdr($part,menu) $tkw
    bind $tkw <ButtonPress-3> {text_menu_post %W %x %y %X %Y}
    bind $tkw <Any-ButtonRelease-3> {text_menu_unpost %W}
}
proc MimeMenuAdd {part args} {
    global mimeHdr

    # Only add the menu item if there isn't already something by this
    # name on the menu.	 We have to do this because we may be called
    # repeatedly by redisplay code.
    set ix [lsearch $args -label]
    if {$ix >= 0} {
	incr ix
	set l [lindex $args $ix]
	set l [string range $l 0 50]
	set args [lreplace $args $ix $ix $l]
    } else {
	set l {}
    }
    if [catch {$mimeHdr($part,menu) index $l}] {
	eval $mimeHdr($part,menu) add $args
    }
}
proc MimeMenuDelete {part what} {
    global mimeHdr

    if [catch {$mimeHdr($part,menu) delete $what} err] {
	Exmh_Debug $err
    }
}
proc Mime_SavePiece {part type} {
    global mimeHdr mhProfile

    set fileName [Mime_GetUnencodedFile $part]
    if {[catch {set default $mimeHdr($part,param,name)}] && \
	    [catch {set default $mimeHdr($part,hdr,content-description)}]} {
	set default ""
    }
    if {![file exists $fileName]} {
	Exmh_Status "Nothing to save!"
	return
    }
    Exmh_Status "Saving $type $fileName"
    set name [FSBox "Save $type to:" $default]
    if {$name != {}} {
	if [catch {
	    exec cp $fileName $name
	    exec chmod $mhProfile(msg-protect) $name
	} err] {
	    Exmh_Status $err
	}
    } else {
	Exmh_Status "Not saved"
    }
}
proc Mime_PrintPiece {part type} {
    global mimeHdr print

    set file [Mime_GetUnencodedFile $part]
    if {[catch {set default $mimeHdr($part,param,name)}] && \
	    [catch {set default $mimeHdr($part,hdr,content-description)}]} {
	set default ""
    }
    if {![file exists $file]} {
	Exmh_Status "Nothing to print!"
	return
    }
    Exmh_Status "Printing $default"
    # Because $print(cmd) embeds $file, extra levels of eval are required
    if {[catch {eval eval exec $print(cmd)} logvar]} {
	if [Exwin_Toplevel .printmsg "Print Messages"] {
	    Widget_Message .printmsg msg -aspect 1500 -relief raised 
	}
	.printmsg.msg configure -text \
"Messages generated when printing your message part:

$logvar
"

    }
    Exmh_Status ok
}
proc Mime_TempFile {part} {
    global mime mimeHdr

    set uid 0
    while {[file exists [set fn "[Env_Tmp]/$uid.$part.[pid].exmh"]]} {
	incr uid
    }
    lappend mime(junkfiles) $fn
    return $fn
}
proc Mime_Debug { args } {
    puts stderr $args
}

proc Mime_PrintEncodedHeader {w overTag string weight slant fontSet size} {
    global mime

    set firstTag ""
    while {[string length $string] > 0} {
	if [regexp -indices {=\?([^?]*)\?(.)\?([^?]*)\?=} $string match \
		charset encoding codedstuff] {
	    set x [expr [lindex $match 0] - 1]
	    set leader [string range $string 0 $x]
	    set charset [string tolower [eval {string range $string} $charset]]
	    set encoding [string tolower [eval {string range $string} $encoding]]
	    set codedstuff [eval {string range $string} $codedstuff]
	    if ![regexp {^[	 \r\n]*$} $string] {
		$w insert insert $leader
	    }

	    if [catch {set font [Mime_GetFont $w $weight $slant \
					      $fontSet $size $charset]}] {
		MimeInsertNote $w $overTag "Unknown charset: <$charset>" 0
		MimeWithTagging $w $overTag {} {} {
		    Mime_PrintEncoded $w $encoding $codedstuff $overTag
		}
	    } else {
		set tagName [MimeLabelFont $font font]
		MimeWithTagging $w $tagName $overTag {-font $font} {
		    Mime_PrintEncoded $w $encoding $codedstuff $tagName
		}
		if {[string length $firstTag] == 0} {
		    set firstTag $tagName
		}
	    }

	    set rest [expr [lindex $match 1]+1]
	    set string [string range $string $rest end]
	} else {
	    $w insert insert "$string"
	    break
	}
    }
    return $firstTag
}

proc Mime_PrintEncoded {w encoding string tagName} {
    switch $encoding {
	"q" {
	    Mime_PrintQuotedPrintable $w $string
	}
	"b" {
	    Mime_PrintBase64 $w $string
	}
	default {
	    MimeInsertNote $w $tagName \
		"Unknown coding of $encoding for \"$string\"" 0
	}
    }
}

proc Mime_PrintQuotedPrintable {w string} {
    while {[string length $string] > 0} {
	if [regexp -indices {^([^=_]*)\=(..)} $string match leader digits] {
	    set leader [eval {string range $string} $leader]
	    set digits [eval {string range $string} $digits]
	    if [string length $leader] {
		$w insert insert $leader
	    }
	    scan $digits "%2x" char
	    $w insert insert [format "%c" $char]
	    set rest [expr [lindex $match 1]+1]
	    set string [string range $string $rest end]
	} elseif [regexp -indices {^([^=_]*)_} $string match leader] {
	    set leader [eval {string range $string} $leader]
	    if [string length $leader] {
		$w insert insert $leader
	    }
	    $w insert insert " "
	    set rest [expr [lindex $match 1]+1]
	    set string [string range $string $rest end]
	} else {
	    $w insert insert $string
	    break
	}
    }
}

proc Mime_PrintBase64Old {w string} {
    global base64

    set i 0
    set end [string length $string]
    set charlist {}
    while {$i < $end} {
	set group 0
	for {set j 0} {$j < 4} {incr j} {
	    set char [string index $string [expr {$i + $j}]]
	    if {[string compare $char "="] != 0} {
		set bits $base64($char)
		set group [expr {$group | ($bits << ((3-$j) * 6))}]
	    }
	}
	for {set j 0} {$j < 3} {incr j} {
	    set byte [expr {($group >> ((2-$j) * 8)) & 255}]
#	    $w insert insert [format "%c" $byte]
	    lappend charlist [format "%c" $byte]
	}
	set i [expr $i+4]
    }
    $w insert insert [join $charlist ""]
}
proc Mime_PrintBase64 {w string} {
    global base64

    set output {}
    set group 0
    set j 18
    foreach char [split $string {}] {
	if [string compare $char "="] {
	    set bits $base64($char)
	    set group [expr {$group | ($bits << $j)}]
	}

	if {[incr j -6] < 0} {
		scan [format %06x $group] %2x%2x%2x a b c
		append output [format %c%c%c $a $b $c]
		set group 0
		set j 18
	}
    }
    $w insert insert $output
}


proc MimeInsertNote {w overTag text {newline 1}} {
    global mime mimeFont
    MimeWithTagging $w noteTag $overTag \
		    {-font $mimeFont(note)} {
	$w insert insert "($text)"
	if $newline {
	    $w insert insert \n
	}
    }
}
proc MimeWithTagging {tkw tag overTag configuration body} {
    if ![regexp $tag [$tkw tag names]] {
	# Create the tag, but don't mark anything with it.
	$tkw tag add $tag end
	# Push it down below everything else
	$tkw tag lower $tag
    }
    # If the tag is too low, bring it up as far as we want it, but no
    # farther.
    if {$overTag != {}} {
	MimeRaiseTag $tkw $tag $overTag
    }
    if {[string length $configuration] != 0} {
	if [catch {uplevel [list $tkw tag configure $tag] $configuration} err] {
	    set ix [lsearch $configuration -font]
	    if {$ix >= 0} {
		set configuration [lreplace $configuration $ix [expr $ix+1] -font fixed]
	    }
	    uplevel [list $tkw tag configure $tag] $configuration
	}
    }
    MimeCleanTag $tkw
    set start [$tkw index insert]

    if [catch {uplevel $body} err] {
	Exmh_Status $err
    }

    MimeRememberTag $tkw $tag
    $tkw tag add $tag $start insert
}
proc MimeRememberTag {w tag {place insert}} {
    global mimeTagStack mimeLastPoint

    MimeCleanTag $w 0 $place
    lappend mimeTagStack $tag
    set mimeLastPoint [$w index $place]
}
proc MimeCleanTag {w {nomatterwhat 0} {place insert}} {
    global mimeTagStack mimeLastPoint

    if [info exists mimeLastPoint] {
	if {[string compare $mimeLastPoint [$w index $place]] == 0} {
	    # I sure hope another MimeCleanTag is called later
	} else {
	    if [info exists mimeTagStack] {
		foreach tag $mimeTagStack {
		    $w tag remove $tag $mimeLastPoint $place
		}
		unset mimeTagStack
	    }
	    unset mimeLastPoint
	}
    }
    if {$nomatterwhat} {
	catch {unset mimeLastPoint}
	catch {unset mimeTagStack}
    }
}
proc MimeRaiseTag {w tag {overTag {}}} {
    if {[string length $overTag] == 0} {
	$w tag raise $tag
    } elseif [regexp "${tag}.*${overTag}" [$w tag names]] {
Exmh_Debug "RaiseTag $tag $overTag"
	$w tag raise $tag $overTag
    }
}
proc MimeInsertSeparator {tkw part width} {
    global mimeHdr mime

    if [$tkw compare insert != "insert linestart"] {
       $tkw insert insert "\n"
    }
    if {$mime(showSeparator)} {
	set looks {-relief sunken \
	  -borderwidth 2 \
	  -font -*-*-*-*-*-*-$width-*-*-*-*-*-iso8859-* \
	  -background $mimeHdr($part,color)}
	set sepLabel [MimeLabel $width separator]
	MimeWithTagging $tkw $sepLabel [MimeLabel $part part] $looks {
	    $tkw insert insert \n
	}
    } else {
	$tkw insert insert \n
    }
}
proc MimeClearHigherTags {w tag start end} {
    set tagList [$w tag names]
    regexp -indices "${tag}(.*)" $tagList match tagsOver
    set tagsOver [eval {string range $tagList} $tagsOver]
    foreach tag $tagsOver {
	$w tag remove $tag $start $end
    }
}
proc Mime_GetFont {w weight slant fontSet size charset} {
    global mime
    # weight = {bold medium}
    # slant = {i r}
    # fontSet = {plain title fixed proportional}
    # size = pts*10
    # charset = any valid mime charset

    if {[string match medium-r-plain-$mime(fontSize)-us-ascii \
	    $weight-$slant-$fontSet-$size-$charset] || \
	    [string match medium-r-plain-$mime(fontSize)-iso-8859-1 \
	    $weight-$slant-$fontSet-$size-$charset]} {
	# Special case the most common situation
	if ![info exists mime(defaultFont)] {
	    set mime(defaultFont) [option get $w font Font]
	    if {[string length $mime(defaultFont)] == 0} {
		set mime(defaultFont) fixed
	    }
	}
	return $mime(defaultFont)
    }
    if [regexp {^fixed$|^plain$} $fontSet] {
	set spacing "*"
	# someone tell me the difference between "m" and "c"
    } else {
#	set spacing "p"
	set spacing "*"
    }
    if {[info exists mime(registry,$charset)] &&
	($mime(registry,$charset) != {})} {
	set registry $mime(registry,$charset)
    } else {
	set registry "iso8859"
    }
    if {[info exists mime(encoding,$charset)] &&
	($mime(encoding,$charset) != {})} {
	set encoding $mime(encoding,$charset)
    } else {
	set encoding "*"
    }

    # Let's try and find a working font
    set i 1
    set family $mime(family,$charset,$fontSet,$i)
    set size [string trim $size]

    set font "-*-$family-$weight-$slant-*-*-*-$size-*-*-$spacing-*-$registry-$encoding"
    $w tag add dummyTag end
    while {[catch {$w tag configure dummyTag -font $font} err]} {
	# That one wasn't any good; let's look for another one
	incr i

	if [catch {set family $mime(family,$charset,$fontSet,$i)}] {
	    # No entry?	 Oh well, at least this will be the right size
	    # and will have the right encoding.  If it has a problem,
	    # we want to let the problem be handled outside this
	    # routine.
	    return "-*-*-*-*-*-*-*-$size-*-*-*-*-$registry-$encoding"
	} else {
	    set font "-*-$family-$weight-$slant-*-*-*-$size-*-*-$spacing-*-$registry-$encoding"
	}
    }
    return $font
}

proc MimeGetRule {part method atribVar \
		  {f_multipart_filenames {}} {m_multipart_filenames {}}} {
    upvar $atribVar atrib
    global mimeHdr

    foreach key $mimeHdr($part,params) {
	set contentParams($key) $mimeHdr($part,param,$key)
    }
    mailcap_getrule $mimeHdr($part,type) contentParams $method \
	atrib [Mime_GetUnencodedFile $part] $f_multipart_filenames \
	$m_multipart_filenames
}

proc MimeGetOrigFile {part} {
    global mimeHdr

    if ![info exists mimeHdr($part,origFile)] {
	Mime_GetUnencodedFile $part
    }
    return $mimeHdr($part,origFile)
}
proc MimeCheckRule {part method} {
    global mimeHdr

    if ![info exists mimeHdr($part,type)] {
	return 0
    }
    mailcap_checkrule $mimeHdr($part,type) contentParams $method
}
proc MimeMailcapView { part subparts } {
    global mimeHdr
    if [catch {MimeGetRule $part "" atrib $subparts} rule] {
	Exmh_Status $rule
	return
    }
    Exmh_Status $rule
    if [catch {
	if [info exists atrib(needsterminal)] {
	    exec xterm -e sh -c $rule &
	} else {
	    exec sh -c $rule &
	}
    } err] {
	Exmh_Status $err warn
    }
}
proc MimeMailcapPrint { part subparts } {
    global mimeHdr
    if [catch {MimeGetRule $part print atrib $subparts} rule] {
	Exmh_Status $rule
	return
    } else {
	Exmh_Status Printing...
	if [catch {exec sh -c $rule} err] {
	    Exmh_Status $err warn
	}
    }
}
proc Mime_ShowAudio { tkw part } {
    global mimeHdr
    TextButton $tkw "Play attached audio" [list MimeShowAudioNow $tkw $part]
    $tkw insert insert \n\n
    TextButton $tkw "Save audio file" [list Mime_SavePiece $part $mimeHdr($part,type)]
    $tkw insert insert \n
}
proc MimeShowAudioNow { tkw part } {
    global mimeHdr mime
    Mime_GetUnencodedFile $part
    if [catch {MimeGetRule $part "" atrib} audioCommand] {
	Exmh_Status $audioCommand
    } else { 
	Exmh_Status $audioCommand
	exec sh -c $audioCommand > /dev/null &
    }
}

proc Mime_Uudecode { infile outfile } {
    set tmpfile [Env_Tmp]/exmh.uud.[file tail $infile].[pid]
    if [catch {open $tmpfile w 0600} out] {
	Exmh_Status $out
    } else {
	if [catch {open $infile} in] {
	    Exmh_Status $in
	    close $out
	} else {
	    set print 0
	    while {[gets $in line] >= 0} {
		if [regexp {begin ([0-9]+) } $line x perm] {
		    puts $out "begin $perm $outfile"
		    set print 1
		} elseif {$print} {
		    puts $out $line
		}
	    }
	    close $out
	    close $in
	    Exmh_Status "uudecode [file tail $infile] > $outfile"
	    if [catch {exec uudecode < $tmpfile} err] {
		Exmh_Status $err error
	    }
	}
	File_Delete $tmpfile
    }
}

proc Mime_EudoraFilename {name} {
    set i [string last "/" $name]
    if {$i > -1} {
	set name [string range $name [expr $i + 1] end]
    }
    regsub -all {[^A-Za-z0-9_!#$&().~{}-]} $name "_" name
    set name [string toupper $name]
    set bits [split $name .]
    if {[llength $bits] == 1} {
	return [format "%.8s" $name]
    }
    set firstbit [lindex $bits 0]
    set bits [lrange $bits 1 end]
    while {[string length $firstbit] < 8 && [llength $bits] > 1} {
	append firstbit "_"
	append firstbit [lindex $bits 0]
	set bits [lrange $bits 1 end]
    }
    set lastbit [lindex $bits end]
    return [format "%.8s.%.3s" $firstbit $lastbit]
}

proc Mime_MakeBoundary { end } {

    # Old boundary was made by
    # regsub -all "\[ \x7f-\xff\]" [exec date] _ date
    # This way works at least with GNU date.

    regsub -all {[^0-9]|[0-9][0-9][0-9][0-9]} [exec date] {} boundary
    regsub {^0*} $boundary {} boundary	;# No octal interpretation, please
    set boundary [expr $boundary*[pid]]
    return "==_Exmh_$boundary$end"
}
proc Mime_Magic { fileName } {
    global exmh env
    Exmh_Debug Mime_Magic $fileName

    foreach m [list $exmh(userLibrary)/.magic \
	     $exmh(library)/local.magic" "" ] {
	# Avoid eval in this command to tolerate spaces in file names
	set cmd {exec file}
	if {[string length $m]} {
	    lappend cmd -m $m
	}
	lappend cmd $fileName
	if [catch $cmd result] {
	    continue
	}

	set result [string trim [lindex [split $result :] 1]] 

	foreach res { magic_u magic_l magic_ } {
	    set contentType [option get . $res$result {}]
	    if [string length $contentType] {
		return $contentType
	    }
	}
    }

    return
}
proc Mime_ShowXApp { tkw part } {
    global mimeHdr
    Exmh_Debug Mime_ShowXApp $part

    set descr [Mime_TypeDescr $part]
    if [MimeCheckRule $part ""] {
	$tkw insert insert \n
	TextButton $tkw "Open ${descr}..." [list MimeMailcapView $part ""]
    }
    if [MimeCheckRule $part "print"] {
	$tkw insert insert "  "
	TextButton $tkw "Print" [list MimeMailcapPrint $part ""]
    }
    $tkw insert insert "  "
    TextButton $tkw "Save..." \
     [list Mime_SavePiece $part $mimeHdr($part,type)]
    $tkw insert insert \n
}
