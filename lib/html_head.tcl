# head.tcl --
# Manage the information in the HTML header.
# This is not displayed and editted like the HTML body.
# Instead, it is maintained as a property sheet so users cannot
# screw up the header when editting the body.

proc Head_Reset {win} {
    upvar #0 Head$win head
    global env
    if [catch {set head(author)} author] {
	if [catch {set env(USER)} author] {
	    if [catch {set env(LOGUSER)} autor] {
		set author ""
	    }
	}
    }
    catch {unset head}
    array set head [list	\
	author	$author		\
	title	(untitled)	\
	bodyparam {}		\
    ]
}
proc Head_New {win} {
    upvar #0 Head$win head
    return [list \
	{title (untitled)}		\
	[list author $head(author)]	\
	{comment {}}			\
    ]

}
# Save the title text
proc HMtag_title {win param textVar} {
    upvar $textVar text
    HeadTitle $win [string trim $text]
    WinHistoryAdd $win [string trim $text]
    set text ""	;# Prevent text display
}
proc HeadTitle {win title} {
    upvar #0  Head$win head
    set head(title) $title
    set top [winfo toplevel $win]
    if {[winfo class $top] == "Html"} {
	wm title [winfo toplevel $win] $title
    }
}

proc HMtag_/title {win param textVar} {
    upvar $textVar text ; set text [string trimleft $text]
}
proc HMtag_html {win param textVar} {
    upvar $textVar text ; set text [string trimleft $text]
}
proc HMtag_/html {win param textVar} {
    upvar $textVar text ; set text ""
}
proc HMtag_head {win param textVar} {
    upvar $textVar text ; set text [string trimleft $text]
    upvar #0 Head$win head
    set head(inBody) 0
}
proc HMtag_/head {win param textVar} {
    upvar #0 Head$win head
    upvar $textVar text ; set text [string trimleft $text]
    set head(inBody) 1
}
proc HMtag_body {win param textVar} {
    upvar #0 Head$win head
    upvar #0 HM$win var
    HMextract_param $param bgcolor head(bgcolor)
    HMextract_param $param text head(foreground)
    HMextract_param $param link head(c_link)
    HMextract_param $param alink head(c_alink)
    # Ignoring vlink, background
    set head(bodyparam) $param
    if {[info exists var(S_exmhpart)]} {
	Head_ColorPart $win [MimeLabel $var(S_exmhpart) part]
    } else {
	Head_SetColors $win $win
    }
    upvar $textVar text ; set text [string trimleft $text]
    set head(inBody) 1
}
proc Head_ResetColors {win} {
    $win tag configure link -foreground [Widget_ColorDefault $win c_link] \
	-underline 1
    $win config -background [Widget_ColorDefault $win background]
    $win config -highlightbackground \
	[Widget_ColorDefault $win highlightBackground]
    $win config -foreground [Widget_ColorDefault $win foreground]
}
proc Head_SetColors {win w} {
    upvar #0 Head$win head

    if {([winfo class $w] == "Entry") || ([winfo class $w] == "Dialog") ||
	    (([winfo class $w] == "Text") &&
	     ([winfo class [winfo parent $w]] == "Textarea"))} {
	return	;# Keep input form elements the original color...
    }
    if {[catch {$w config -background $head(bgcolor)}] &&
	    [catch {$w config -background #$head(bgcolor)}]} {
	# do nothing
    }
    if {[catch {$w config -highlightbackground $head(bgcolor)}] &&
	    [catch {$w config -highlightbackground #$head(bgcolor)}]} {
	# do nothing
    }
    if {[catch {$w config -foreground $head(foreground)}] &&
	    [catch {$w config -foreground #$head(foreground)}]} {
	# do nothing
    }
    if {[catch {$w tag configure link -foreground $head(c_link)}] &&
	    [catch {$w tag configure link -foreground #$head(c_link)}]} {
	# do nothing
    }
    foreach child [winfo children $w] {
	Head_SetColors $win $child
    }
}
proc Head_ColorPart {w tag} {
    upvar #0 Head$w head

    if {[catch {$w tag config $tag -background $head(bgcolor)}] &&
	    [catch {$w tag config $tag -background #$head(bgcolor)}]} {
	# do nothing
    }
    if {[catch {$w tag config $tag -foreground $head(foreground)}] &&
	    [catch {$w tag config $tag -foreground #$head(foreground)}]} {
	# do nothing
    }
    if {[catch {$w tag configure link -foreground $head(c_link)}] &&
	    [catch {$w tag configure link -foreground #$head(c_link)}]} {
	# do nothing
    }
}
proc Head_Color {win w islink} {
    upvar #0 Head$win head
    if {[catch {$w config -background $head(bgcolor)}] &&
	    [catch {$w config -background #$head(bgcolor)}]} {
	# do nothing
    }
    if $islink {
	if {[catch {$w config -highlightbackground $head(c_link)}] &&
		[catch {$w config -highlightbackground #$head(c_link)}]} {
	    $w config -highlightbackground blue
	}
    } else {
	if {[catch {$w config -highlightbackground $head(bgcolor)}] &&
		[catch {$w config -highlightbackground #$head(bgcolor)}]} {
	    # do nothing
	}
    }
}
proc HMtag_/body {win param textVar} {
    upvar $textVar text ; set text ""
}
proc Head_BodyEdit {win} {
    upvar #0 Head$win head
    set new [Dialog_Htag $win {body bgcolor= text= background= alink= vlink= link=} $head(bodyparam) \
	"These parameters affect the overall page display"]
    if [string length $new] {
	set text ""
	Head_ResetColors $win
	HMtag_body $win [lindex $new 1] text
    }
}
proc HMtag_meta {win param textVar} {
    upvar #0 Head$win head
    upvar $textVar text ; set text [string trimleft $text]
    lappend head(meta) $param
}
proc HMtag_link {win param textVar} {
    upvar #0 Head$win head
    lappend head(link) $param
}
proc HMtag_!doctype {win param textVar} {
    upvar #0 Head$win head
    upvar $textVar text ; set text [string trimleft $text]
    set head(doctype) $param
}

# A pair of pseudo tags are added automatically as the 1st and last html
# tags in the document.  The default is <HMstart> and </HMstart>.
# Append enough blank space at the end of the text widget while
# rendering so HMgoto can place the target near the top of the page,
# then remove the extra space when done rendering.

proc HMtag_hmstart {win param textVar} {
    upvar #0 HM$win var
    upvar $textVar text ; set text [string trimleft $text]
    $win mark gravity $var(S_insert) left
    $win insert end "\n " last
    $win mark gravity $var(S_insert) right
}

proc HMtag_/hmstart {win param textVar} {
    upvar $textVar text ; set text ""
    $win delete last.first end
}

# Output wrapper for file output

proc Head_Output {win {frameset 0}} {
    upvar #0 Head$win head
    set s ""
    if [info exists head(doctype)] {
	append s "<!Doctype $head(doctype)>\n"
    }
    append s <Html>\n<Head>\n<Title>$head(title)</Title>\n
    set author 0
    if [info exists head(comments)] {
	foreach item $head(comments) {
	    regsub -- -+$ $item {} item
	    set item [string trim $item]
	    if {[string length $item] == 0} {
		continue
	    }
	    if [regexp -nocase {author:} $item] {
		append s "<!-- Author: $head(author) -->\n"
		set author 1
	    } else {
		append s "<!-- $item -->\n"
	    }
	}
    }
    if {! $author && [info exists head(author)]} {
	set author [string trim $head(author)]
	if {[string length $author] > 0} {
	    append s "<!-- Author: $head(author) -->\n"
	}
    }
    foreach {key label} {meta META link LINK} {
	if [info exists head($key)] {
	    foreach item $head($key) {
		append s "<$label $item>\n"
	    }
	}
    }
    if {!$frameset} {
	append s </Head>\n
	append s <[string trim "Body $head(bodyparam)"]>\n
    }
    return $s
}

proc Head_OutputTail {win} {
    return \n</Body>\n</Html>\n
}
proc Head_Display {win} {
    upvar #0 Head$win head

    set entryList [list [list title $head(title)]]
    lappend entryList [list author $head(author)]
    if [info exists head(doctype)] {
	lappend entryList [list doctype $head(doctype)]
    }

    if [info exists head(comments)] {
	set i ""
	foreach item $head(comments) {
	    if ![regexp -nocase author: $item] {
		lappend entryList [list Comment$i $item]
		if {$i == {}} {set i 1} else {incr i}
	    }
	}
    }
    if [info exists head(meta)] {
	set i ""
	foreach item $head(meta) {
	    lappend entryList [list Meta$i $item]
	    if {$i == {}} {set i 1} else {incr i}
	}
    }
    DialogEntry $win .head "HTML Head Information" [list Head_Update $win] $entryList [list HeadDialogHook $win .head]
}
proc HeadDialogHook { win frame f } {
    upvar #0  Head$win head
    set b $f.b
    button $b.meta -text "Add meta" -command [list HeadAddMeta $win $frame]
    pack $b.meta -side right
    button $b.comment -text "Add comment" -command [list HeadAddComment $win $frame]
    pack $b.comment -side right
}

proc Head_Update {win values} {
    upvar #0  Head$win head
    array set head $values
    foreach {key pat} {comments Comment* meta Meta*} {
	set head($key) {}
	foreach ix [lsort [array names head $pat]] {
	    if {[string length [string trim $head($ix)]]} {
		lappend head($key) $head($ix)
	    }
	}
    }
    HeadTitle $win $head(title)
}

proc HeadAddMeta {win frame} {
    upvar #0  Head$win head
    set i {}
    catch {set i [llength $head(meta)]}
    DialogEntryAdd $win $frame Meta$i "New"
}
proc HeadAddComment {win frame} {
    upvar #0  Head$win head
    set i {}
    catch {set i [llength $head(comments)]}
    DialogEntryAdd $win $frame Comment$i "New"
}
