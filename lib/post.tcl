#
# post.tcl  -  news posting client for exmh
# Needs tcl7.5/tk4.1 or above.
# 
# Gareth Owen (g.owen@aston.ac.uk)
# 20-Dec-96


proc Post_Init {} {

    global NNTP

    Preferences_Add "NNTP Support" \
"Post a mail message to a Usenet news server via NNTP
(mainly intended to take the grind out of moderating newsgroups),
and retrieve new articles from selected newsgroups." {
    {NNTP(host) nntpHost {news} {News Server}
"The name of your usenet news server. Very often 'news'. "}
    {NNTP(port) nntpPort {119}  {NNTP port}
"Port on which the news server listens for nntp connections. 
119 unless your site is weird"}
    {NNTP(emailaddr) nntpEmailAddr {}  {My address when posting}
"E-mail address to use when posting to newsgroups.
Typically: First Last <login@domain>"}
    {NNTP(moderated) nntpModerated {} {Groups you moderate}
"A list of groups which you moderate separated by whitespace.
If one of these is in the Newsgroups header then an Approved
header will be added to the posting"}
    {NNTP(moderator) nntpModerator {} {Moderator's address}
"Address to put in the Approved: field for moderated groups.
Not needed if the moderated list is empty"}
    {NNTP(groups) nntpNewsGroups {} {Groups to retrieve}
"A list of groups which you wish to be retrieved when the
\"News\" button is clicked on"}
    {NNTP(newsrc) nntpDotnewsrc {~/.newsrc} {.newsrc file}
"Pathname of your .newsrc file (or equivalent).  If it does not
exist, it will be created.  Defaults to ~/.newsrc"}}
}

#
#  Parse mail and sort out what we need
#
proc Post {} {

    global NNTP msg env

    if [string length $msg(path)] {
 	    set art [open $msg(path) r]
	    set text [read $art]
	    close $art
    } else {
	Exmh_Status "Post - no message selected"
	Post_Dismiss
	return
    }

    # Headers to throw away since they'll be added anew by INN
    # and CNews which get upset when they can't do it
    set header_throwAway \
	{{return-path:} {received:} {path:} {date:} {message-id:} {to:} \
	     {lines:} {x-exmh-isig-} {cc:}}

    # Headers INN wants to add  itself get X-original- shoved in front
    # if we want to keep them
    # else MUST be in above else INN will reject post
    # (but NNTP/Cnews doesn't complain about following)
    set header_Xify \
	{{nntp-posting-host:}}

    #  split header from body
    set sp [string first "\n\n" $text]
    set spmh [string first "\n--------\n" $text]
    if {$sp < 0 || ($spmh > 0 && $spmh < $sp)} {
	set sp $spmh
	set hdr [string range $text 0 [incr sp -1]]
	set NNTP(body) [string range $text [incr sp 11] end]
    } else {
	set hdr [string range $text 0 [incr sp -1]]
	set NNTP(body) [string range $text [incr sp 3] end]
    }

    set headerin [split $hdr \n]
    set NNTP(headers) {}
    set flag 0
    set NNTP(post_groups) $NNTP(groups)
    set NNTP(sender) $NNTP(emailaddr)
    set organization 0

    # parse headers and dispose of as necessary
    foreach h $headerin {
	if {$flag} {
	    set fstch [string index $h 0]
	    if {$fstch == { } || $fstch == {	}} {
		continue
	    }
	}
	set lh [string tolower $h]
	set flag 0
	foreach t $header_throwAway {
	    if {[string first [string tolower $t] $lh]==0} {
		set flag 1
		break
	    }
	}
	if {$flag==0} {
	    foreach t $header_Xify {
		if {[string first [string tolower $t] $lh]==0} {
		    set h "X-original-$h"
		    break
		}
	    }
	}
	if {$flag} {
	    continue
	} elseif {[string first from: $lh]==0} {
	    set NNTP(sender) [string trim [string range $h 5 end]]
	} elseif {[string first newsgroups: $lh]==0} {
	    set NNTP(post_groups) [string trim [string range $h 11 end]]
	} elseif {[string first subject: $lh]==0} {
	    set NNTP(subject) [string trim [string range $h 8 end]]
	} elseif {[string first organization: $lh]==0} {
	    set organization 1
	} else {
		lappend NNTP(headers) $h
	}
    }
    if {$organization==0 && [info exists env(ORGANIZATION)]} {
	set org_hdr "Organization: $env(ORGANIZATION)"
	lappend NNTP(headers) $org_hdr
    }

    Post_Widget

}


#
# Create the widget
#
proc Post_Widget {} {

    global NNTP

    if [Exwin_Toplevel .exmh_post "Post Article to NewsGroup" PostNews] {

	.exmh_post.but.quit config -command Post_Dismiss

	wm protocol .exmh_post WM_DELETE_WINDOW Post_Dismiss
        Widget_AddBut .exmh_post.but post "Post" Post_Article

	frame .exmh_post.ng  -borderwidth 2
	label .exmh_post.ng.l -text Newsgroups: -width 12
	entry .exmh_post.ng.e -textvariable NNTP(post_groups) \
	    -relief sunken -width 60
	pack .exmh_post.ng.l -side left -fill both
	pack .exmh_post.ng.e -side left -fill both -expand 1
	pack .exmh_post.ng -expand 1 -fill both
	frame .exmh_post.f -borderwidth 2
	label .exmh_post.f.l -text From: -width 12
	entry .exmh_post.f.e -textvariable NNTP(sender)
	pack .exmh_post.f.l -side left -fill both
	pack .exmh_post.f.e -side left -expand 1 -fill both
	pack .exmh_post.f -side top -expand 1 -fill both
	frame .exmh_post.s -borderwidth 2
	label .exmh_post.s.l -text Subject: -width 12
	entry .exmh_post.s.e -textvariable NNTP(subject)
	pack .exmh_post.s.l -side left -fill both
	pack .exmh_post.s.e -side left -fill both -expand 1
	pack .exmh_post.s -side top -expand 1 -fill both
    
    }
}




#
# Construct the article to be posted and invoke poster
#
proc Post_Article {} {

    global NNTP

# Have we got the essentials ?
    if {! [expr \
      "[string length $NNTP(sender)] && [string length $NNTP(subject)] && [string length $NNTP(post_groups)]"\
	      ] } {
	Exmh_Status "Newsgroups , Subject  and From fields are NOT optional"
	return
    }

    set head [list "From: $NNTP(sender)" "Subject: $NNTP(subject)" \
		  "Newsgroups: $NNTP(post_groups)"]

# Is there a moderated group in the list of those we're posting to ?
    set postingTo [split $NNTP(post_groups) ,]
    foreach i $NNTP(moderated) {
	if {[lsearch $postingTo $i]>-1} {
	    lappend head "Approved: $NNTP(moderator)"
	    break
	}
    }

# Join them all up
    regsub "\[ \t\n\]*\$" $NNTP(body) {} body
    set article "[join [concat $head $NNTP(headers)] \n]\n\n$body"

# And off we go
    Exmh_Status "Post Article : [busy PostIt $article]"

    if [winfo exists .exmh_post] {
    	Exwin_Dismiss .exmh_post
    }
}


#
# NNTP posting client
#
proc PostIt {article} {
    
    global NNTP
    
    if { [catch {socket $NNTP(host) $NNTP(port)} conn] } {
	return $conn
    }

    set line [gets $conn]
    if {[string first 200 $line]} {
	puts $conn QUIT
	close $conn
	return $line
    }

    puts $conn POST
    flush $conn

    set line [gets $conn]
    if {[string first 340 $line]} {
	puts $conn QUIT
	close $conn
	return $line
    }

    puts $conn "$article\n.\n"
    flush $conn
    set line [gets $conn]
    if {[string first 240 $line]} {
	puts $conn QUIT
	close $conn
	return $line
    }
    
    puts $conn QUIT
    flush $conn
    set line [gets $conn]
    if {[string first 205 $line]} {
	puts $conn QUIT
	close $conn
	return $line
    }
    
    close $conn
    return "Posted Successfully"

}

proc Post_Dismiss {} {
    if [winfo exists .exmh_post] {
	Exwin_Dismiss .exmh_post
    }
}

