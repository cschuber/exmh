# pgpMatch.tcl -- 
# created by monnier@didec26.epfl.ch on Sat Nov 19 14:43:42 1994

# 
# for matching between email addresses and pgp key ids
# 

# $Log$
# Revision 1.6  1999/05/04 16:23:37  cwg
# Should have used filly, not fill in the last patch.
#
# Revision 1.5  1999/05/04 16:08:48  cwg
# A bunch of places that override the change that I just made in widgets.tcl
#
# Revision 1.4  1999/04/16 00:22:40  cwg
# Code cleanup.  Removed some dead code
#
# Revision 1.3  1999/04/04 20:34:57  cwg
# Removed dead code which only ran in pre tk-4.1 versions.
#
# Revision 1.2  1999/03/26 08:41:55  cwg
# Changes to PGP interface to use preferences variables instead of
# message headers.  Also, reorganize the "PGP..." menu and rename it
# "Crypt..."
#
# See the "PGP interface" preferences page for more info.
#
# Revision 1.1  1998/05/05 17:55:38  welch
# Initial revision
#
# Revision 1.1  1998/05/05 17:43:00  welch
# Initial revision
#
# Revision 1.6  1997/06/03  18:32:52  bwelch
#   Added PgpMatch_PrivateExact
#
# Revision 1.5  1995/12/07  22:00:11  bwelch
# New PGP key name matching algorithm from Stefan Monnier
#
# Revision 1.4  1995/06/09  20:56:42  bwelch
# Fixed 3.6'ism
#
# Revision 1.3  1995/05/25  21:02:59  bwelch
# Added Widget_BindEntryCmd
#  .
#
# Revision 1.2  1995/05/24  05:59:31  bwelch
# Improved key matching algorithm
#
# Revision 1.1  1995/05/19  17:36:46  bwelch
# Initial revision
#
# Revision 1.3  1995/04/07  21:43:00  welch
# Updated listbox to handle Tk 4.0
#
# Revision 1.2  1995/03/24  02:14:58  welch
# Added FontWidget to listbox creation
#
# Revision 1.1  1994/12/30  21:49:00  welch
# Initial revision
#
# Revision 1.1  1994/12/30  21:49:00  welch
# Initial revision
#
# Revision 1.1  1994/12/17  20:19:08  monnier
# Initial revision
#

# returns the list of keys of the recipients of the draft
proc PgpMatch_Whom { draft {hasfcc 0} } {
    global pgp

    set ids {}

    # get the list of recipients with "whom" (does alias expansion)
    catch {exec whom -nocheck $draft} recipients
    foreach id [split $recipients "\n"] {
	if [regexp "^ *-" $id] {
	    continue
	}
	set id [string trim $id]
	regsub { at } $id {@} id
	regsub {\[.*\]} $id {} id
	set ids [concat $ids [PgpMatch_Email $id $pgp(pubring)]]
    }
    if $hasfcc {
	lappend ids $pgp(myname)
    }

    return $ids
}

# like a "grep id keyring". Returns the unique element of
# the keyring that matches $email. The returned value is actually a list
# of keys, in case someone needs the feature (?)
proc PgpMatch_Email { email keyring } {
    global pgp env pgpMatch pgpSimpleMatch

    set email [string tolower [string trim $email]]

    if {($pgp(cacheids) != "none") && [info exists pgpMatch($email)]} {
	return $pgpMatch($email)
    }

    set id $email

    set sep "]\[{}<>()@\"|,;!' "

    # split into login, domain and comment
    if {![regexp "^(.*\[$sep])?(\[^$sep]+)@(\[^$sep]+)(.*)\$" $id {} comment1 login domain comment2]} {
	error "<PGP> meaningless recipient: '$email'"
    }
    set commentids [Misc_Filter x {$x != {}} [split [string tolower "$comment1 $comment2"] ".$sep"]]
    set loginids [Misc_Filter x {$x != {}} [split [string tolower "$login"] "."]]
    set domainids [Misc_Filter x {$x != {}} [split [string tolower "$domain"] "."]]

    set pgpbestkeys [PgpMatch_InitialKeyList $loginids $domainids $commentids $keyring]
    set pgpnextkeys {}
    set subids [concat \
	    [Misc_Map x {format "(^|\[$sep.])${x}(\\.\[^$sep]*)*@"} $loginids] \
	    [Misc_Map x {format "@(\[^$sep]*\\.)*${x}(\$|\[$sep.])"} [Misc_Reverse $domainids]] \
	    [Misc_Map x {format "(^|\[$sep.])${x}(\$|\[$sep.])"} $commentids]]

    set bestmatches 0
    foreach subidindex [Misc_IntList 0 [llength $subids]] {
       set subid [lindex $subids $subidindex]

       set next [Misc_Segregate key {[regexp -nocase $subid $key]} $pgpnextkeys]
       set best [Misc_Segregate key {[regexp -nocase $subid $key]} $pgpbestkeys]
       set top [lindex $best 0]
       if {$top == {}} {
	  set pgpbestkeys [concat [lindex $best 1] [lindex $next 0]]
	  set pgpnextkeys [lindex $next 1]
       } else {
	  set bestmatches [expr $bestmatches + 1]
	  set pgpbestkeys $top
	  set pgpnextkeys [concat [lindex $best 1] [lindex $next 0]]
       }
    }

    set maxmatches [llength $subids]
    set pgpbestkeys [PgpMatch_UnflattenKeyList $pgpbestkeys]
    set pgpnextkeys [PgpMatch_UnflattenKeyList $pgpnextkeys]

    # check the match's quality
    if {([llength $pgpbestkeys] != 1) || \
	   ((100 * ($bestmatches + 1)) / ($maxmatches + 1) < $pgp(minmatch))} {
       set pgpbestkeys [concat $pgpbestkeys $pgpnextkeys]
       ExmhLog "<PgpMatch_Email> $id is ambiguous: [join $pgpbestkeys ", "]"
       set result [Pgp_KeyBox "Please select the key of $id" $keyring $pgpbestkeys]
    } else {
       set result $pgpbestkeys
    }
    while {$result == {}} {
	set result [Pgp_KeyBox "You didn't select a key for $id" $keyring $pgpbestkeys]
    }
    set pgpMatch($email) $result
    foreach key $result {
	set pgpSimpleMatch([string tolower [string trim [lindex $key 1]]]) $key
    }
    return $pgpMatch($email)
}

# returns the only key matching $name.
proc PgpMatch_Simple { name keyring } {
    global pgp pgpSimpleMatch

    set name [string tolower [string trim $name]]

    if {($pgp(cacheids) == "no") || ![info exists pgpSimpleMatch($name)]} {
	set keylist [PgpExec_KeyList $name $keyring]

	if {[llength $keylist] == 1} {
	    set pgpSimpleMatch($name) [lindex $keylist 0]
	} elseif {[llength $keylist] == 0} {
	    error "<PGP> no keys matching $name"
	} else {
	    error "<PGP> several keys matching $name"
	}
    }
    return $pgpSimpleMatch($name)
}

# search $pgp(privatekeys) for the keyid exactly matching keydesc
# returns keyid or {}
proc PgpMatch_PrivateExact { keydesc } {
    global pgp

    foreach elem $pgp(privatekeys) {
	if {[string compare [lindex $elem 1] $keydesc] == 0} {
	    return [lindex $elem 0]
	}
    }
}

# returns a list of keys where every entry only has one userid
# for instance rather than {0214 "monnier" "monnier@di"} it will give
# {0214 "monnier"} {0214 "monnier@di"}
proc Pgp_FlatKeyList { pattern keyring } {
    global pgp

    Exmh_Debug Pgp_FlatKeyList $pattern $keyring
    set keys [PgpExec_KeyList $pattern $keyring]
    Exmh_Debug Keys $keys
    set userids {}
    foreach key $keys {
	if {[llength $key] > 2} {
	    set keyid [lindex $key 0]
	    foreach userid [lrange $key 1 end] {
		lappend userids [list $keyid $userid]
	    }
	} else {
	    lappend userids $key
	}
    }
    return $userids
}

# kind of the opposite to Pgp_FlatKeyList
proc PgpMatch_UnflattenKeyList { keylist } {
   
   if {"$keylist" == {}} {
      return {}
   }

   set result {}
   set curKeyid [lindex [lindex $keylist 0] 0]
   set curKey [list $curKeyid]

   foreach key $keylist {
      if {[lindex $key 0] == $curKeyid} {
	 lappend curKey [lindex $key 1]
      } else {
	 lappend result $curKey
	 set curKey $key
	 set curKeyid [lindex $key 0]
      }
   }
   lappend result $curKey
   return $result
}

# returns a list of pgpkeys that should be as small as possible,
# while (hopefully) still containing the key matching the guy specified by
# $loginids $domainids and $commentids
proc PgpMatch_InitialKeyList { loginids domainids commentids keyring } {
    global pgp
#    puts "<PgpMatch_InitialKeyList> $loginids $domainids $commentids"

    if {[llength $domainids] > 2} {
	set pattern [join [lrange $domainids 1 end] "."]
    } elseif {[llength $domainids] > 1} {
	set pattern [join $domainids "."]
    } elseif {[llength $loginids] > 0} {
	set pattern [lindex $loginids 0]
    } elseif {[llength $commentids] > 0} {
	set pattern [lindex $commentids 0]
    } else {
	set pattern [join $domainids "."]
    }

    # get the list of pgp userids of the public ring and
    # remove all the uninteresting part of the listing displayed by pgp -kv
    # and change the long string into a list of userids
    set keylist [Pgp_FlatKeyList $pattern $keyring]
#    if {($keylist == {}) && $pgp(fullkeyring)} {
#	ExmhLog "<PgpMatch_InitialKeyList> no match on $pattern, trying full keyring"
#	set keylist [Pgp_FlatKeyList "" $keyring]
#	if {$keylist == {}} {
#	    ExmhLog "<PgpMatch_InitialKeyList> can't find keys in pgp's output"
#	    error "<PGP> can't get the pubring list, probable install problem"
#	}
#    }
    return $keylist
}

# based on fileselect.tcl
# asks the user for selection of keys.
proc Pgp_KeyBox { label keyring keylist } {
    global keybox
    set w .keybox

    if [Exwin_Toplevel $w "Choose key" Dialog no] {
	# path independent names for the widgets
	
	set keybox(list) $w.key.sframe.list
	set keybox(scroll) $w.key.sframe.scroll
	set keybox(ok) $w.but.ok
	set keybox(listbut) $w.but.list
	set keybox(cancel) $w.but.cancel
	set keybox(msg) $w.label
	set keybox(sel) $w.key.sel
	
	# widgets
	Widget_Frame $w but Menubar {top fillx}
	Widget_Label $w label {top fillx pady 10 padx 20}
	Widget_Frame $w key Dialog {bottom expand fill} -bd 10
	Widget_Entry $w.key sel {bottom fillx pady 10}

	Widget_AddBut $w.but ok OK \
		[list keybox.ok.cmd $w ] {left padx 1 filly}
	Widget_AddBut $w.but cancel Cancel \
		[list keybox.cancel.cmd $w ] {right padx 1 filly}
	Widget_AddBut $w.but list List \
		[list keybox.list.cmd $w $keyring] {right padx 1 filly}

	Widget_Frame $w.key sframe

	scrollbar $w.key.sframe.yscroll -relief sunken \
		-command [list $w.key.sframe.list yview]
	FontWidget listbox $w.key.sframe.list -relief sunken \
		-yscroll [list $w.key.sframe.yscroll set] -setgrid 1
	$w.key.sframe.list config -width 48 -height 16
	pack append $w.key.sframe \
		$w.key.sframe.yscroll {right filly} \
		$w.key.sframe.list {left expand fill}
    }
    # Make sure keyring is correct - it can vary from use to use of the keybox
    $keybox(listbut) configure -command [list keybox.list.cmd $w $keyring]
    $keybox(sel) configure -textvariable keybox(filter)
    set keybox(state) ""
    set keybox(filter) {}
    set keybox(keylist) $keylist
    set keybox(result) {}
    $keybox(msg) configure -text $label
    $keybox(list) delete 0 end
    foreach i $keybox(keylist) {
	$keybox(list) insert end [lindex $i 1]
    }
    bind $keybox(list) <Double-ButtonPress-1> {
	%W select set [%W nearest %y]
	$keybox(ok) invoke
    }
    Widget_BindEntryCmd $keybox(sel) <Key-Return> [list $keybox(listbut) invoke]

    focus $keybox(sel)
    update idletask
    grab $w
    tkwait variable keybox(result)
    grab release $w

    if {$keybox(state) == "cancel"} {
	error "cancel"
    }
    return [PgpMatch_UnflattenKeyList $keybox(result)]
}

proc keybox.ok.cmd {w} {
    global keybox

    #    if {[selection own] == $keybox(list)}
    
    set keybox(result) [Misc_Map i {lindex $keybox(keylist) $i} [$keybox(list) curselection]]
    if {$keybox(result) == {} && [llength $keybox(keylist)] == 1} {
	set keybox(result) $keybox(keylist)
    }
    Exwin_Dismiss $w
}

proc keybox.cancel.cmd {w} {
    global keybox
    set keybox(state) "cancel"
    set keybox(result) {}
    Exwin_Dismiss $w
}

proc keybox.list.cmd { w keyring } {
    global keybox

    $keybox(list) delete 0 end
    set keybox(keylist) [Pgp_FlatKeyList [$keybox(sel) get] $keyring]
    foreach x $keybox(keylist) {
	$keybox(list) insert end [lindex $x 1]
    }
}

#
proc PgpMatch_CheckPoint {  } {
    global pgp pgpMatch pgpSimpleMatch
    if {($pgp(cacheids) == "persistent") && ![catch {open $pgp(pgppath)/.matchcache w 0600} out]} {
	foreach email [array names pgpMatch] {
	    puts $out [linsert $pgpMatch($email) 0 $email]
	}
	puts $out ""
	foreach email [array names pgpSimpleMatch] {
	    puts $out [linsert $pgpSimpleMatch($email) 0 $email]
	}
	close $out
    }
}


# proc PgpMatch_Init {  }
if {($pgp(cacheids) == "persistent") && ![catch {open $pgp(pgppath)/.matchcache r} in]} {
    for {set len [gets $in line]} {$len > 0} {set len [gets $in line]} {
	set pgpMatch([lindex $line 0]) [lrange $line 1 end]
    }
    for {set len [gets $in line]} {$len >= 0} {set len [gets $in line]} {
	set pgpSimpleMatch([lindex $line 0]) [lrange $line 1 end]
    }
    close $in
}
