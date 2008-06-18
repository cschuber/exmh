# links.tcl
# Suport for links and anchors

# Override HMlink_setup from the HTML library.
# Mainly this is because we use the whole HTML tag to identify the
# text range (not just L:$href).  We also improve the user feedback.
# Note that the bindings on the "link" text tag are used to follow links.

proc HMlink_setup {win htag} {
    upvar #0 HM$win var

    if {[info exists var(base)] && [HMextract_param $htag href] &&
	    [info exists href]} {
	# Cut&Paste Hack
	# Map from the inserted <base>+<link> to a relative link, if possible
	set href_orig $href
	set htag_orig $htag
	UrlResolve $var(base) href
	UrlRelative $var(S_url) href
	regsub $href_orig $htag_orig $href htag
	# This variable results in a text tag that represents the link
    }
    set var(T,a) [list H:$htag]	;# Usually done by HMmark
    set tag H:$htag

    HMextract_param $htag href
    regsub -all % $href %% href2
    $win tag configure $tag -foreground [Widget_ColorDefault $win c_link] -underline 1
    $win tag bind $tag <Enter> \
	    [list HMlink_feedback $win hand2 "X-URL:\t$href2" $tag c_alink]
    $win tag bind $tag <Leave> \
	    [list HMlink_feedback $win [option get $win cursor Text] "" $tag c_link]
    # make the link clickable
    $win tag bind $tag <ButtonRelease-1> [list URI_StartViewer $href2 ]

    # Add to history so it shows up in URL chooser dialog
    global History
    if ![info exists History(href)] {
	set History(href) $href		;# Ought to be the title
    }
}
proc HMlink_feedback {win cursor message tag colorName} {
    upvar #0 Head$win head
    $win config -cursor $cursor
    Status $win $message

    if {[catch {$win tag configure $tag -foreground $head($colorName)}] &&
	    [catch {$win tag configure $tag -foreground #$head($colorName)}]} {
	$win tag configure $tag -foreground blue
    }
}
proc Url_AnchorColor {win varName} {
    upvar #0 $varName colorize
    if $colorize {
	$win tag configure anchor -foreground purple
    } else {
	# Doesn't handle Body foreground text color right
	$win tag configure anchor -foreground [$win cget -foreground]
    }
}
proc UrlGetLink {win x y} {
    set tags [$win tag names @$x,$y]
    set ix [lsearch -glob $tags H:a*]
    if {$ix < 0} {
	return {}
    }
    regsub ^H: [lindex $tags $ix] {} htag
    set href ""
    HMextract_param $htag href
    set target ""
    HMextract_param $htag target
    return [list $href $target]
}
# Url_Hit? is bound to <Button-1> on the link tag, which is shared by all links.

proc Url_Hit? {win x y} {
    dputs Url_Hit? $x $y
    if ![Input_Edit $win] {
	Url_Hit $win $x $y
    }
}
proc Url_Hit {win x y} {
    dputs Url_Hit $x $y
    lassign {href name} [UrlGetLink $win $x $y]
    Html_HistoryAdd $win $href
    Frame_Display $win $name $href
}
# This is like Url_Hit for regular hits, but it opens a new window.
proc Url_HitNew {win x y} {
    lassign {href target} [UrlGetLink $win $x $y]
    Url_DisplayNew $href $win
}

# Called from Double-Click
proc Url_Edit {win x y} {
    set tags [$win tag names @$x,$y]
    set ix [lsearch -glob $tags H:a*]
    if {$ix < 0} {
	set htag {}
    } else {
	regsub ^H: [lindex $tags $ix] {} htag
    }
    UrlEditLink $win $htag [$win index @$x,$y]
}
# Called from Html Menu
proc Url_EditLink {win} {
    set tags [$win tag names insert]
    set ix [lsearch -glob $tags H:a*]
    if {$ix < 0} {
	DialogInfo $win "You must first click on the link you want to edit."
	return
    }
    Undo_Mark $win Url_EditLink
    regsub ^H: [lindex $tags $ix] {} htag
    UrlEditLink $win $htag insert
    Undo_Mark $win Url_EditLinkEnd
}

# Remote is called by exmh when we emulate "hippo" browser
proc Remote {href interp} {
    after 1 [list Url_DisplayNew $href]
}

# Create a new window to display the href
proc Url_DisplayNew {href {winorig {}}} {
    if {$winorig != {}} {
	upvar #0 HM$winorig varorig
	set base $varorig(S_url)
	Log $winorig Url_DisplayNew $href
    }
    set win [Window_New]
    if [info exists base] {
	upvar #0 HM$win var
	set var(S_url) $base
    }
    Url_Display $win $href
    return $win
}

proc Url_Display {win href} {
    if ![winfo exists $win] {
	return
    }
    set win [Window_GetMaster $win]
    set mode [Input_Edit $win]
    Input_Mode $win 0
    HMlink_callback $win $href
    Input_Mode $win $mode
}

proc Url_DisplayFrame {win href} {
    set win0 [Window_GetMaster $win]
    set mode [Input_Edit $win0]
    Input_Mode $win 0
    HMlink_callback $win $href
    Input_Mode $win $mode
}

# The following hook is called when a link is selected by the user
proc HMlink_callback {win href {query ""}} {
    global Busy
    upvar #0 HM$win var
    set base $var(S_url)

    if [Input_Edit $win] {
	return	;# Don't follow links in edit mode
    }
    if {[Input_IsDirty $win] && ![regexp ^# $href]} {
	set x [DialogChoice [winfo toplevel $win] .dialog "Save Changes First?" \
		[list Cancel "Save" "Save As..." "Do Not Save"] \
		[list <Control-c> <Return> <Control-s> <Escape>]]
	switch -- $x {
	    0 { return }
	    1 { File_Save $win }
	    2 { File_SaveAs $win }
	    3 { #do nothing }
	}
    }
    Exmh_Debug base=$base href=$href query=$query
    if ![info exists Busy($win)] {
	set Busy($win) {}
    }
    catch {Http_kill $Busy($win)}
    set Busy($win) {}

    if {[string length $base] && [string match #* $href]} {
	# internal to this document
	HMgoto $win [string trimleft $href #]
	return
    }

    # it's a out-of-page link

    if [catch {
	set protocol [UrlResolve $base href]
	Exmh_Debug resolved=$href protocol=$protocol
	switch -regexp -- $protocol {
	    (http|ftp) {
		regsub {#.*$} $href {} url
		set Busy($win) $url
		Status $win "Connecting to $url"
		FeedbackLoop $win fetch
		# For stop button
		set var(S_urlPending) $url
		if {$query != ""} {
		    dputs stderr "Query: $query"
		    Http_post $url $query [list UrlDisplay $win $url] \
					  [list Url_Progress $win $href]
		} else {
		    Http_get $url [list UrlDisplay $win $url] \
				   [list Url_Progress $win $href]
		}
	    }
	    file {
		regsub {(file:(//?localhost)?)} $href {} file
		regsub {#.*$} $file {} file
		if [catch {UrlGetFile $file} html] {
		    Status $win "Error: $html"
		    set var(S_urlDisplay) $href
		} else {
		    regsub {\?.*} $href {} url
		    set var(S_url) $url
		    Status $win "Displaying $var(S_url)"
		    Url_DisplayHtml $win $var(S_url) $html
		}
	    }
	    mailto {
		if {[string match exmh* [tk appname]]} {
		    Msg_Mailto $href
		} else {
		    set interps [winfo interps]
		    set ix [lsearch -regexp $interps {exmh( #.)?$}]
		    if {$ix >= 0} {
			set exmh [lindex $interps $ix]
			Status $win "Using $exmh to send mail"
			send $exmh [list Msg_Mailto $href]
		    } else {
			regsub mailto: $href {} address
			Status $win "Please send mail to $address"
		    }
		}
	    }
	}
    } err] {
	Status $win $err
	set Busy($win) {}
    }
}
proc Url_Progress { win href state current total} {
    set parent [winfo parent $win]

    dputs $href $state $current $total

    if {"$parent" == "."} {set parent ""}
    if {"$state" == "error"} {
	Status $win $current
	return
    }
    set bar $parent.status.msg.bar
    if {$total > 0} {
	set fract [expr double($current)/$total]
	place $bar -relw $fract -height 2 -anchor sw -x 0 -rely 1.0
    } else {
	set fract 0
	place $bar -relw 0.0 -height 2 -anchor sw -x 0 -rely 1.0
    }
    Status $win "$href $state [expr round(100.0*$fract)]%"
}

proc Url_Validate {base href how callback} {
    if {[string length $base] && [string match #* $href]} {
	# internal to this document
	return [list localanchor [string trimleft $href #]]
    }
    # it's a out-of-page link
    set hreforig $href
    set protocol [UrlResolve $base href]
    switch -regexp -- $protocol {
	http {
	    upvar #0 $href data
	    if {$how == "HEAD"} {
		Http_head $href [list UrlValidateDone $href $callback]
	    } else {
		# prefetch
		Http_get $href [list UrlValidateDone $href $callback]
	    }
	}
	file {
	    regsub {(file:(//?localhost)?)} $href {} file
	    regsub {^/+} $file / file
	    set ok 1
	    if ![file exists $file] {
		set ok 0
		set status "no such file: $file"
	    }
	    if [file isdirectory $file] {
		set status "$hreforig <code>directory</code>"
	    } else {
		set status "$hreforig <code>file</code>"
	    }
	    eval $callback {$hreforig $ok $status}
	}
	ftp -
	gopher -
	wais -
	mailto -
	default {
	    eval $callback {$hreforig 1 $protocol}
	}
    }
}
proc UrlValidateDone {href callback} {
    upvar #0 $href data
    set ok 1
    if ![info exists data] {
	set ok 0
	set result "$href killed"
    } else {
	set result $href
	if [info exists data(type)] {
	    append result " <code>($data(type))</code>"
	}
	if ![string match 200* $data(http)] {
	    append result <br>$data(http)
	    switch -glob -- $data(http) {
		30* {
		    set location ""
		    foreach {key value} $data(mime) {
			if [regexp -nocase location $key] {
			    set location $value
			}
		    }
		    append result "<br>Redirect to: $location"
		    set ok 0
		}
		default {
		    set ok 0
		}
	    }
	}
    }
    if [catch {
     eval $callback {$href $ok $result}
    } err] {
	Stderr "UrlValidateCallback: $err"
    }
}
proc UrlValidateTimeout {href} {
    upvar #0 $href data
    if [info exists data] {
	set data(valid) timeout
    }
}
# Display a page.  We have to make sure we don't display one page while
# still  displaying the previous one.  If we get here from a recursive 
# invocation of the event loop, cancel whatever we were displaying when
# we were called.
# If we have a fragment name, try to go there.

proc UrlDisplay {win url} {
    upvar #0 HM$win var
    global Home
    set fragment ""
    regexp {([^#]*)#(.+)} $url dummy url fragment
    upvar #0 $url data

    if {[info exists data(link)]} {
	# Indirect link
	Url_Display $win $data(link)
	return
    }

    Feedback $win ready
    if {[scan $data(http) %d code] == 1} {
	switch -glob -- $code {
	    2* { # ok }
	    4* { # Error document follows
		DialogHtmlInfo $win "<code>$url</code><hr>$data(html)"
		return
	    }
	    default {
		DialogHtmlInfo $win "$url\n\n$data(http)"
		return
	    }
	}
    }

    if {$url == "" && $fragment != ""} {
	HMgoto $win $fragment
	return
    }
    if {"$data(what)" == "error"} {
	Status $win $data(message)
	global Busy
	set Busy($win) {}
	HMset_state $win -stop 1	;# stop displaying previous page if busy
	return
    }

    # was a link - switch to target

    Feedback $win busy
    Status $win "Displaying $url"
    if {$fragment != ""} {
	    HMgoto $win $fragment
    }
    if ![info exists data(type)] {
	set data(type) {}
    }

    # Call a content handler based on mime type
    # E.g., Content_image/gif, then Content_image, then Content_default
    foreach type [list $data(type) [Url_Parent $data(type)] default] {
	if ![catch {Content_$type $win $url} stop] {
	    if {$stop} {
		# Stop displaying previous page, if any
	        global Busy
		set Busy($win) {}
		Feedback $win ready
		HMset_state $win -stop 1
		Status $win ""
	    }
	    return
	} else {
	    if ![string match "invalid command*" $stop] {
		error "Content_$type failed" -errorInfo $errorInfo
	    }
	}
    }
}
proc Url_DisplayHtmlBegin {win url html} { 
    Url_DisplayHtml $win $url $html "" 0
}
proc Url_DisplayHtml {win url html {saveundo ""} {setInsert 1}} {
    upvar #0 HM$win var

    $win config -cursor watch -state normal
    set var(S_urlDisplay) $url
    catch {unset var(S_urlPending)}
    wm iconname [winfo toplevel $win] [file tail $url]
    if {$saveundo == ""} {
	Undo_Reset $win			;# Clear undo log
    } else {
	Undo_Mark $win Display		;# This is part of refresh, save undo
    }
    HMreset_win $win $setInsert		;# Set display state
    Embed_Reset $win			;# Nuke applets
    Edit_Reset $win			;# Set edit state
    bindtags $win [list TScroll all]	;# Disable input to the widget
    Feedback $win busy
    HMset_state $win -update 10		;# Frequent updates during 1st display
    set href [string first # $url]
    if $href {
	HMgoto $win [string range $url [expr {$href + 1}] end]
    }
    HMparse_html $html [list HMrender $win]
    Input_Mode $win			;# Restore edit or browse mode
    HMset_state $win -update 1000	;# Rare updates during editting
    if {$setInsert} {
	HMset_state $win -stop 1	;# stop displaying previous page if busy
	$win mark set insert 1.0
	Input_Adjust $win			;# In case we start with a  list
	Mark_ReadTags $win insert		;# Prime the display engine
	Undo_Mark $win DisplayDone
    }
    if {$saveundo == ""} {
	Undo_Init $win			;# Reset the undo log
    } else {
	Undo_Mark $win DisplayDone
    }
    Toolbar_Update $win
    Feedback $win ready
    $win config -cursor xterm
}

# given a file name, return its html, or invent some html if the file can't
# be opened.

proc UrlGetFile {file} {
    global Home
    if [regexp ^http: $file] {
	error "UrlGetFile $file"
    }
    regsub {^/+} $file / file
    set fd [open $file]
    set result [read $fd]
    close $fd
    return $result
}

# resolve a SRC or HREF link into an absolute url
# This side-effects the reference variable to do the conversion,
# and it returns the protocol (.e.g, http, ftp, or file)

proc UrlResolve {base refVar} {
    upvar $refVar ref
    set ref [string trim $ref]
    if {[regexp {^([^ :]+):(.+)} $ref x protocol rest]} {
	if {[regexp -nocase (file|mail) $protocol] || [regexp ^// $rest]} {
	    return [string tolower $protocol]
	}
	regsub ^$protocol: $ref {} ref
    }
    # Original pattern: {([^:]+):(//[^/]*)(.*)}
    if [regexp {^([^:]+):(/+[^/]*)(.*)$} $base dummy protocol server ext] {
	set protocol [string tolower $protocol]
	if {$protocol == "file"} {
	    set ext $server$ext
	    set server /
	}
	if [string match */ $ext] { 
	    set dir $ext
	} else {
	    set dir [Url_Parent $ext]
	}
	if {$dir == "."} {set dir /}
	while {[regsub {^\.\./} $ref {} ref] == 1} {
	    set dir [Url_Parent $dir]
	}
	if {[string match /* $ref]} {
	    set ref $protocol:$server$ref
	} elseif {$dir == "/"} {
	    set ref $protocol:$server/$ref
	} else {
	    set ref $protocol:$server/[string trim $dir /]/$ref
	}
	dputs $ref
	return $protocol
    }
    if [regsub -nocase ^file: $base {} filebase] {
	# dos names like file:c:, and file direname breaks with
	# file:c:/, transforming that to file:c: no slash
	set ref file:[file join [file dirname $filebase] [string trim $ref /]]
	return file
    }
    set ref [Url_Parent $base]/[string trim $ref /]
    if ![regexp {^([^:]+):} $ref x protocol] {
	if [regexp {^www\.} $ref] {
	    set protocol http
	    set ref http://$ref
	} else {
	    set protocol file
	    set ref file:$ref
	}
    }
    dputs $ref
    return [string tolower $protocol]
}

# refVar points to an absolute URL.
# This URL will be reduced to a URL relative to base.

proc UrlRelative {base refVar {absolute 1}} {
    upvar $refVar ref
    if [regexp -nocase ^mailto: $ref] {
	return 0
    }
    if {[string length $base] == 0} {
	return 0
    }
    if ![regexp {([^:]+):/+([^/]+)(.*)} $base dummy proto server ext] {
	# Native file pathname URL
	regexp {([^:]+):(.*)} $base dummy proto ext
	set server {}
    }
    if ![regexp {([^:]+):/+([^/]+)(.*)} $ref dummy proto2 server2 ext2] {
	regexp {([^:]+):(.*)} $base dummy proto2 ext2
	set server2 {}
    }
    foreach var {proto proto2 server server2} {
	set $var [string tolower [set $var]]
    }
    if {[string compare $server $server2] || [string compare $proto $proto2]} {
	return 0
    }
    if ![string match */ $ext] {
	set dir [Url_Parent $ext]		;# Base directory to start at
    } else {
	set dir $ext
    }
    set prefix {}
    while {! [string match $dir* $ext2]} {
	set dir [Url_Parent $dir]
	if {[string compare $dir "/"] == 0} {
	    if $absolute {
		set ref $ext2		;# No common parent directory
		return 0
	    } else {
		break
	    }
	}
	append prefix ../
    }
    regsub ^$dir $ext2 $prefix ext2
    if !$absolute {
	set ext2 [string trimleft $ext2 /]
    }
    set ref $ext2
    return 1
}
proc Url_IsChild {base url} {
    UrlResolve $base url
    set url1 $url

    if {![UrlRelative $base url1]} {
	return ""	;# Not on the same server
    }
    # Worry about url1 as parent of project(base)
    if [regexp {^\.\.} $url1] {
	return ""
    }
    return $url		;# Return absolute URL
}
# This is like "file dirname", but doesn't screw with the slashes
# 	file dirname http://www.sun.com/a
# 	=> http:/www.sun.com
proc Url_Parent {url} {
    set url [string trimright $url /]
    regsub {[^/]+$} $url {} url
    return $url
}
