#
# getnews.tcl  -  NNTP retrieve client for exmh
# Needs tcl7.5/tk4.1 or above.
# 
# Chris Keane (Chris.Keane@comlab.ox.ac.uk)
# 26-Feb-97


proc GetNews {} {

    global NNTP

    if {![llength $NNTP(groups)]} {
	Exmh_Status "No groups specified to retrieve"
	return
    }

    BgAction "News" GetNewsBg
}

proc GetNewsBg {} {
    busy Exmh_Status "Retrieve news: [GetNewsInt]"
}

proc GetNewsInt {} {

    global NNTP mhProfile env

    if {![llength $NNTP(newsrc)]} {
	set newsrc {~/.newsrc}
    } else {
	set newsrc $NNTP(newsrc)
    }

    if {[file exists $newsrc]} {
	if {[catch {open $newsrc} rcfile]} {
	    return "cannot open file $newsrc\n$rcfile"
	}
    } else {
	set rcfile {}
    }
    Exmh_Status "Connecting to server $NNTP(host)..."
    if {[catch {socket $NNTP(host) $NNTP(port)} nntpskt]} {
	if {[string length $rcfile]} {
	    close $rcfile
	}
	return $nntpskt
    }

    set line [NNTPReply $nntpskt]
    if {[string first 200 $line] && [string first 201 $line]} {
	NNTPClose $nntpskt $rcfile
	return $line
    }

    # Open the .newsrc file and extract the lines relating to the groups
    # we're going to retrieve

    set gcount 0
    set grps $NNTP(groups)
    while {[string length $rcfile] && [llength $grps] && [gets $rcfile line] != -1} {
	if {![regexp {^([0-9A-Za-z+&-\._]+)[:!][ 	]*([0-9,-]+)} $line match group articles]} {
	    continue
	}
	set indx [lsearch -exact $grps $group]
	if {$indx != -1} {
	    set thegrps($gcount) $group
	    set thearts($gcount) $articles
	    incr gcount
	    set grps [lreplace $grps $indx $indx]
	}
    }

    # If there are any groups which weren't in the .newsrc file, set their
    # "articles which have been read" list to {}
    foreach group $grps {
	set thegrps($gcount) $group
	set thearts($gcount) {}
	incr gcount
    }

    # make a temp directory for putting articles in while we work
    if {![file isdirectory $mhProfile(path)/MyIncTmp]} {
	exec mkdir $mhProfile(path)/MyIncTmp
    }

    # Now get the articles from the server
    set thisg 0
    set acount 0
    set ecount [file tail [Mh_Path MyIncTmp new]]
    Exmh_Status "Retrieving articles..."
    while {$thisg < $gcount} {
	NNTPCommand $nntpskt "GROUP $thegrps($thisg)"
	set line [NNTPReply $nntpskt]
	if ![string first 480 $line] {
	    set ok [NNTPAutenticate $nntpskt]
	    if $ok {
		NNTPCommand $nntpskt "GROUP $thegrps($thisg)"
		set line [NNTPReply $nntpskt]
	    }
	}	
	if {[string first 211 $line]} {
	    Exmh_Status "Cannot select newsgroup $thegrps($thisg)"
	    Exmh_Debug "Line: $line"
	    set thearts($thisg) "X"
	    incr thisg
	    continue
	}

	if {![regexp {^211 ([0-9]+) ([0-9]+) ([0-9]+)} $line match num first last]} {
	    NNTPClose $nntpskt $rcfile
	    return "cannot parse server response"
	}

	if {$num == 0} {
	    incr thisg
	    continue
	}

	# start reading at the next unread article in this group
	if {[regexp {^([0-9]+[,-])*([0-9]+)$} $thearts($thisg) match num tlast]
	    && $tlast >= $first} {
	    set first [expr $tlast + 1]
	}

	set line 423
	while {![string first 423 $line] || ![string first 430 $line]} {
	    if {$first > $last} {
		break
	    }
	    NNTPCommand $nntpskt "STAT $first"
	    set line [NNTPReply $nntpskt]
	    if {![string first 223 $line]} {
		break
	    }
	    if {[string first 423 $line] && [string first 430 $line]} {
		NNTPClose $nntpskt $rcfile
		return $line
	    }
	    incr first
	}

	# if we get a 423 or 430 back, there were no further articles anyway
	if {![string first 423 $line] || ![string first 430 $line]} {
	    incr thisg
	    continue
	}

	# otherwise we must have got a 223, i.e. the article is selected
	Exmh_Status "Reading group $thegrps($thisg) (max [expr $last-$first+1] articles)..."
	while {![string first 223 $line]} {
	    NNTPCommand $nntpskt "ARTICLE"
	    set line [NNTPReply $nntpskt]
	    if {[string first 220 $line]} {
		NNTPClose $nntpskt $rcfile
		return "unexpected server response"
	    }
	    if {![regexp {^220 ([0-9]+)} $line match anum]} {
		NNTPClose $nntpskt $rcfile
		return "cannot parse server response"
	    }
	    if {[catch {open $mhProfile(path)/MyIncTmp/[expr $ecount+$acount] {WRONLY CREAT EXCL}} afile]} {
		NNTPClose $nntpskt $rcfile
		return "cannot write temp article file\n$afile"
	    }
	    set line [gets $nntpskt]
	    while {![regexp {^\.$} $line]} {
		# two leading .'s should be compressed into one
		regexp {^\.(\..*)} $line match line
		puts $afile $line
		set line [gets $nntpskt]
	    }
	    close $afile

	    NNTPCommand $nntpskt "NEXT"
	    set line [NNTPReply $nntpskt]
	    if {[string first 223 $line] && [string first 421 $line]} {
		NNTPClose $nntpskt $rcfile
		return $line
	    }
	    incr acount
	}
	# update the article references for the new .newsrc file
	set thearts($thisg) [AL_Update $thearts($thisg) $anum]
	incr thisg
    }

    if {$acount} {
	Inc_Presort 0
	Exmh_Status "Writing .newsrc file..."
	if {[string length $rcfile]} {
	    seek $rcfile 0
	    set oldrc [glob $newsrc]
	    set newsrc $newsrc.exmh
	}
	if {[catch {open $newsrc w} nrcfile]} {
	    NNTPClose $nntpskt $rcfile
	    return "cannot write new .newsrc file\n$nrcfile"
	}

	# re-parse the old .newsrc file, replacing the relevant article numbers
	# with their new values

	set thisg 0
	while {[string length $rcfile] && [gets $rcfile line] != -1} {
	    if {$thisg >= $gcount || ![regexp {^([0-9A-Za-z+&-\._]+)([:!][ 	]*)([0-9]+[,-])*[0-9]+$} $line match group chaff first] || [string compare $group $thegrps($thisg)]} {
		puts $nrcfile $line
		continue
	    }
	    if {[string match X $thearts($thisg)]} {
		# we didn't manage to select this group
		puts $nrcfile $line
	    } else {
		puts $nrcfile "$group$chaff$thearts($thisg)"
	    }
	    incr thisg
	}
	while {$thisg < $gcount} {
	    if {![string match X $thearts($thisg)]} {
		puts $nrcfile "$thegrps($thisg): $thearts($thisg)"
	    }
	    incr thisg
	}
    } else {
	set nrcfile {}
    }

    NNTPClose $nntpskt [list $rcfile $nrcfile]
    if {[string length $rcfile] && [string length $nrcfile] && [catch {
	    exec mv -f $oldrc $oldrc.old
	    exec mv -f [glob $newsrc] $oldrc
	    } err]} {
	return "failed to rename .newsrc files\n$err"
    }
    return "$acount new articles retrieved"
}

# parse the existing .newsrc entry and update it with new values
proc AL_Update {rcentry next} {

    # a few different cases here; first, if the existing entry is empty
    if {![string length $rcentry]} {
	set rcentry 1
    }

    # if the last part of the existing entry is a single number
    if {[regexp {^([0-9]+(-[0-9]+)?,)*([0-9]+)$} $rcentry match fst snd last]} {
	if {$next == $last} {
	    return $rcentry
	} else {
	    return "$rcentry-$next"
	}

    # otherwise the last part of the existing entry must be a range mmm-nnn
    } else {
	regexp {^(([0-9]+(-[0-9]+)?,)*[0-9]+-)([0-9]+)$} $rcentry match fst snd thd last
	if {$next == $last} {
	    # this case shouldn't actually ever happen, but just in case... 8-)
	    return $rcentry
	} else {
	    return "$fst$next"
	}
    }
}

proc NNTPCommand {nntpskt cmd} {
    puts $nntpskt $cmd
    regsub {pass.*$} $cmd {pass *****} cmd
    Exmh_Debug NNTPCommand: $cmd
    flush $nntpskt
}

proc NNTPReply {nntpskt} {
    set line [gets $nntpskt]
    Exmh_Debug NNTPReply: $line
    return $line
}

proc NNTPClose {nntpskt rcfiles} {
    global mhProfile

    puts $nntpskt QUIT
    close $nntpskt
    foreach rcf $rcfiles {
	if {[string length $rcf]} {
	    close $rcf
	}
    }
    File_Delete $mhProfile(path)/MyIncTmp/$mhProfile(mh-sequences)
    catch {exec rmdir $mhProfile(path)/MyIncTmp}
}

#
# 'Original' AUTHINFO implementation
# i.e., not AUTHINFO SIMPLE or AUTHINFO GENERIC
# see 'Common NNTP extensions'
#
proc NNTPAutenticate {sock} {

    global NNTP

    if {$NNTP(user)==""} {
	tk_messageBox -message {News server requires authentication.
	    Check username and password in NNTP preferences} -type ok
	return 0
    }

    NNTPCommand $sock "authinfo user $NNTP(user)"
    set line [NNTPReply $sock]
    NNTPCommand $sock "authinfo pass $NNTP(pass)"
    set line [NNTPReply $sock]
    if [string first 281 $line] {
	tk_messageBox -message {Authentication to NNTP server failed.
	    Check username and password in NNTP preferences} -type ok
	return 0
    } else {
	return 1
    }
}
