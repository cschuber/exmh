# html.tcl
# Use the HTML library from WebTk to display html documenation
set WebTk(version) "Exmh HTML Browser 1.0"

proc Html_Init {} {
    global window
    Preferences_Add "Html Viewer" \
"Exmh has a simple HTML viewer for its on-line documentation." {

    {window(fontsize) htmlFontAdjust {CHOICE 0 4 8} {Font size adjustment}
"This setting adds to the font size used for HTML display."}
    {Http(server) httpProxy {} {HTTP Proxy Server}
"This sets the proxy used to make HTTP requests through a firewall.
Leave this blank if you have no proxy."}
    {Http(port) httpProxyPort 8080 {HTTP Proxy Port}
"This is the port number for the proxy server."}
    {WebTk(cache) htmlCacheDir /tmp/.webtkcache {Image Cache Directory}
"This directory holds image data that is used for long term
caching, such as between runs of the browser."}
    {cachesize(max) htmlCacheSize 1000000 {Max Bytes in Cache Directory}
"This limits the data stored in the image cache directory."}
    {imagecachesize imageCacheSize 10 {Max Images Cached in Memory}
"This limits the number of images saved in main memory.
A setting of 0 minimizes memory use."}
    {window(imagesEnabled) imageEnable ON {Enable display of in-line images}
"Use this to enable or disable images in your HTML messages."}
    {window(skipImagesInFolder) skipImagesInFolder spam {Disable display of in-line images in folder(s)}
"Set this to the list of folders for which in-line images should not
be fetched nor be displayed. Elements of the list don't have to be
actual folders: they can be patterns, using *, ?, \[a-z] (and \\ to
quote those special chars). For instance
*/spam will disable images in foo/spam as well as bar/spam."}
}
    HtmlInitVars
}
proc HtmlInitVars {} {
    global window
    set window(colorAnchor) 0
    if {![info exists window(fontsize)] ||
	[string length $window(fontsize)] == 0} {
	set window(fontsize) 0			;# Magnifiy factor
    }
    if {![info exists window(indentsize)] ||
	[string length $window(indentsize)] == 0} {
	set window(indentsize) 0.6		;# Indent width
    }
    Map_Init
    trace variable window(fontsize) w HtmlFontSizeUpdate
    trace variable cachesize(max) w CachePrefTrace
    auto_load Content_text/html
    # For installer
    global WebTk
    if ![info exists WebTk(cache)] {
	set WebTk(cache) /tmp/.webtkcache
    }
    Cache_Init
}
proc HtmlFontSizeUpdate {args} {
    global window html exwin
    if {![info exists window(fontsize)] ||
	[string length $window(fontsize)] == 0} {
	set window(fontsize) 0			;# Magnifiy factor
    }
    if [info exists html(win)] {
	HMset_state $html(win) -size $window(fontsize)
    }
    HMset_state $exwin(mtext) -size $window(fontsize)
}
proc HtmlWindow {t} {
    global window
    if {[Exwin_Toplevel $t "Html Docs" Html] } {

	set f [frame $t.body]
	set win [Widget_Text $f 30]
	pack $f -side top -fill both -expand true
	upvar #0 HM$win var

	set url $t.but
	label $url.status -textvariable HM$win\(S_stat1) -width 6 \
	    -relief ridge -bd 2 -padx 9 -pady 3 -foreground blue
	set var(S_feedback) $url.status

	entry $url.entry  -textvariable HM$win\(S_urlDisplay) -width 35
	pack $url.status $url.entry -side left
	pack $url.entry -expand true -fill x
	bind $url.entry <Return> "HtmlOpen $win ; break"

	foreach b [Widget_GetButDef $url] {
	    Widget_AddButDef $url $b
	}
	foreach M [Widget_GetMenuBDef $url] {
	    set menu [Widget_AddMenuBDef $url $M {right padx 1 filly}]
	    ButtonMenuInner $menu
	}
	global window
	if ![info exists window(colorAnchor)] {
	    HtmlInitVars
	}
	set var(S_stat2) ""				;# message line
	set var(S_url) file:[pwd]
	HMinit_win $win
	HMset_state $win -insert insert		;# We use the "insert" mark
	HMset_indent $win $window(indentsize)
	HMset_state $win -size $window(fontsize)

    } else {
	set win $t.body.t
	wm deiconify $t
	raise $t
    }
    focus $win
    Frame_Reset $win
    return $win
}
proc Window_Frame {win0 parent scrolling padx pady} {
    global window
    # make the interface

    set win [text $parent.text -padx $padx -pady $pady -takefocus 1 \
	-width 0 -height 0]	;# Let grid allocate all the space
    if {[string compare $scrolling none] != 0} {
	scrollbar $parent.scrollbar  -command "$parent.text yview"  -orient v
	$win config -yscrollcommand "$parent.scrollbar set"
	pack $parent.scrollbar -in $parent -side right -expand 0 -fill y
    }
    pack $win -in $parent -side left -fill both -expand 1 -padx 0 -pady 0

    upvar #0 HM$win var HM$win0 var0

    HMinit_win $win				;# Reset display engine
    HMreset_win $win
    Head_SetColors $win0 $win
    HMset_state $win -insert insert		;# We use the "insert" mark
    HMset_state $win -size $window(fontsize)
    HMset_indent $win $window(indentsize)
    Edit_Reset $win
    Frame_Reset $win
    Input_Reset $win

    set var(S_url) $var0(S_url)		;# So relative src works.
    # Keep a pointer to the main text widget for the page.
    Window_SetMaster $win $win0

    return $win
}
proc Html_Window {href} {
    global html
    set html(win) [HtmlWindow .html]
    Html_HistoryAdd $html(win) $href
    HMlink_callback $html(win) $href
    return $html(win)
}
proc Html_Display {markup base} {
    global html
    set html(win) [HtmlWindow .html]
    upvar #0 HM$html(win) var
    set var(S_url) $base
    # Do this *after* the environment is complete.
    after 1 [list Url_DisplayHtml $html(win) $base $markup]
    return $html(win)
}
proc Html_MimeShow {win part} {
    upvar #0 HM$win var
    global mimeHdr window

    if {![info exists var]} {
	Map_Init
	HMinit_win $win
	HMset_state $win -insert insert		;# We use the "insert" mark
	HMset_indent $win $window(indentsize)
	HMset_state $win -size $window(fontsize)
	# Change URL hits to display in new window
	$win tag bind link <Button-1> [list HtmlHit $win %x %y]
	$win tag bind link <Shift-Button-1> ""
	$win tag bind link <Double-Button-1> ""

    }
    set var(S_exmhpart) $part
    if [info exists mimeHdr($part,hdr,content-base)] {
	set var(S_url) $mimeHdr($part,hdr,content-base)
    } else {
	set var(S_url) file:$mimeHdr($part,file)
    }
    if [catch {open $mimeHdr($part,file)} in] {
	$win insert insert "Cannot open temp file: $in\n"
    } else {
	set html [read $in]
	close $in
	# Avoid showing frames in the main message area
	if [regexp -nocase <frameset $html] {
	    $win insert insert "Showing frames in external viewer\n"
	    URI_StartViewer $var(S_url)
	} else {
	    $win config -wrap word
	    Html_DisplayInline $win $var(S_url) $html
	}
    }
}
proc Html_Stop {win} {
    upvar #0 HM$win var
    if [info exists var] {
	HMset_state $win -stop 1
    }
    Http_stop
    Head_ResetColors $win	;# reset window
    Head_Reset $win		;# clear memory
    $win configure -tabs {}
    $win config -wrap [option get $win wrap Text]
}
proc HtmlHit {win x y} {
    upvar #0 HM$win var
    lassign [UrlGetLink $win $x $y] href name
    UrlResolve $var(S_url) href
    URI_StartViewer $href
}
proc Html_DisplayInline {win url html} {
    upvar #0 HM$win var
    global window

    $win config -cursor watch -state normal
    set var(S_urlDisplay) $url
    catch {unset var(S_urlPending)}
    HMreset_win $win 0			;# Set display state
    HMset_indent $win $window(indentsize) ;# Restore tab stops
    HMset_state $win -insert insert	;# We use the "insert" mark
    Embed_Reset $win			;# Nuke applets
    Feedback $win busy
    HMset_state $win -update 10		;# Frequent updates during 1st display
    HMparse_html $html [list HMrender $win]
    Feedback $win ready
    $win config -cursor [option get $win cursor Text]
}

proc HtmlOpen {win} {
    upvar #0 HM$win var
    Html_HistoryAdd $win $var(S_urlDisplay)
    HMlink_callback $win $var(S_urlDisplay)
}
proc Html_HistoryAdd {win url} {
    upvar #0 HM$win var
    UrlResolve $var(S_url) url
    lappend var(S_history) $url
    set var(S_origin) [expr [llength $var(S_history)] -1]
}
proc Html_Back {} {
    global html
    upvar #0 HM$html(win) var
    if {$var(S_origin) > 0} {
	incr var(S_origin) -1
	set url [lindex $var(S_history) $var(S_origin)]
	HMlink_callback $html(win) $url
    }
}
proc Html_Forward {} {
    global html
     upvar #0 HM$html(win) var
    if ![info exists var(S_origin)] {
	return
    }
    if {$var(S_origin) < [llength $var(S_history)]-1} {
	incr var(S_origin)
	set url [lindex $var(S_history) $var(S_origin)]
	HMlink_callback $html(win) $url
    }
}
# win is an embedded window inside masterwin.  win displays a frame or table.
proc Window_SetMaster {win masterwin} {
    upvar #0 HM$masterwin var
    upvar #0 HM$win var2
    if [info exists var(S_mainwin)] {
	set var2(S_mainwin) $var(S_mainwin)
    } else {
	set var2(S_mainwin) $masterwin
    }
}
proc Window_GetMaster {win} {
    upvar #0 HM$win var
    if [info exists var(S_mainwin)] {
	# Level of indirection to support nested text widgets for tables
	return $var(S_mainwin)
    } else {
	return $win
    }
}

proc Status {win string} {
    Exmh_Status $string
}
proc Status_push {win string} {
    Exmh_Status $string
}
proc Status_pop {win} {
    Exmh_Status " "
}
proc Feedback { win word } {
    upvar #0 HM$win var
    set var(S_stat1) $word
    catch {after cancel $var(S_after)}
    catch {
	set bg [lindex [$var(S_feedback) config -background] 3]
	$var(S_feedback) config -bg $bg  -fg blue
    }
    update idletasks
}

proc FeedbackLoop { win word } {
    upvar #0 HM$win var
    set var(S_stat1) $word
    catch {after cancel $var(S_after)}
    catch {
	set bg [$var(S_feedback) cget -bg]
	set def [lindex [$var(S_feedback) config -background] 3]
	if {[string compare $bg $def] == 0} {
	    $var(S_feedback) config -bg white
	} else {
	    $var(S_feedback) config -bg $def
	}
	set var(S_after) [after 200 [list FeedbackLoop $win $word]]
    }
    update idletasks
}

