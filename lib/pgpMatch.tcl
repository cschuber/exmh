# pgpMatch.tcl -- 
# created by monnier@didec26.epfl.ch on Sat Nov 19 14:43:42 1994

# 
# for matching between email addresses and pgp key ids
# 

# $Log$
# Revision 1.8  1999/08/13 00:39:05  bmah
# Fix a number of key/passphrase management problems:  pgpsedit now
# manages PGP versions, keys, and passphrases on a per-window
# basis.  Decryption now works when no passphrases are cached.
# One timeout parameter controls passphrases for all PGP
# versions.  seditpgp UI slightly modified.
#
# Revision 1.7  1999/08/03 04:05:55  bmah
# Merge support for PGP2/PGP5/GPG from multipgp branch.
#
# Revision 1.6.2.1  1999/06/14 20:05:16  gruber
# updated multipgp interface
#
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
proc Pgp_Match_Whom { v draft {hasfcc 0} } {
    global pgp

    set ids {}

    # get the list of recipients with "whom" (does alias expansion)
#    catch {exec whom -nocheck $draft} recipients
    catch {exec whom $draft} recipients

    foreach id [split $recipients "\n"] {
	if [regexp "^ *-" $id] {
	    continue
	}
	set id [string trim $id]
	regsub { at } $id {@} id
	regsub {\.\.\.\ .*$} $id {} id
	# Match_Email return list of matched keys
	set ids [concat $ids [Pgp_Match_Email $v $id Pub]]
    }

    if $hasfcc {
	lappend ids [set pgp($v,myname)]
    }

    return $ids
}

# like a "grep id keyring". Returns the unique element of
# the keyring that matches $email. The returned value is actually a list
# of keys, in case someone needs the feature (?)
# keyringtype instead of keyring
proc Pgp_Match_Email { v email keyringtype } {
    global env pgp

    set email [string tolower [string trim $email]]

    # if there is info in cache, return it 
    if {([set pgp($v,cacheids)] != "none") && [info exists pgp($v,match,$email)]} {
	return [set pgp($v,match,$email)]
    }

    if {![regexp "@" $email]} {
        set id "$email@$env(LOCALHOST)"
    } else {
        set id $email
    }

    set sep "]\[{}<>()@\"|,;!' "

    # split into login, domain and comment
    if {![regexp "^(.*\[$sep])?(\[^$sep]+)@(\[^$sep]+)(.*)\$" $id {} comment1 login domain comment2]} {
	error "<[set pgp($v,fullName)]> meaningless recipient: '$email'"
    }
    set commentids [Pgp_Misc_Filter x {$x != {}} [split [string tolower "$comment1 $comment2"] ".$sep"]]
    set loginids [Pgp_Misc_Filter x {$x != {}} [split [string tolower "$login"] "."]]
    set domainids [Pgp_Misc_Filter x {$x != {}} [split [string tolower "$domain"] "."]]
    set pgpbestkeys [Pgp_Match_InitialKeyList $v $loginids $domainids $commentids $keyringtype]
    set pgpnextkeys {}
    set subids [concat \
      [Pgp_Misc_Map x {format "(^|\[$sep.])${x}(\\.\[^$sep]*)*@"} $loginids] \
      [Pgp_Misc_Map x {format "@(\[^$sep]*\\.)*${x}(\$|\[$sep.])"} [Pgp_Misc_Reverse $domainids]] \
      [Pgp_Misc_Map x {format "(^|\[$sep.])${x}(\$|\[$sep.])"} $commentids]]

    set bestmatches 0
    foreach subidindex [Pgp_Misc_IntList 0 [llength $subids]] {
       set subid [lindex $subids $subidindex]

       set next [Pgp_Misc_Segregate key {[regexp -nocase $subid $key]} $pgpnextkeys]
       set best [Pgp_Misc_Segregate key {[regexp -nocase $subid $key]} $pgpbestkeys]
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
    set pgpbestkeys [Pgp_Match_UnflattenKeyList $pgpbestkeys]
    set pgpnextkeys [Pgp_Match_UnflattenKeyList $pgpnextkeys]

    # check the match's quality
    if {([llength $pgpbestkeys] != 1) || \
	   ((100 * ($bestmatches + 1)) / ($maxmatches + 1) < [set pgp($v,minmatch)])} {
       set pgpbestkeys [concat $pgpbestkeys $pgpnextkeys]
       ExmhLog "<Pgp_Match_Email> $id is ambiguous: [join $pgpbestkeys ", "]"
       set result [Pgp_KeyBox $v "Please select a $pgp($v,fullName) key for $id" $keyringtype $pgpbestkeys]
    } else {
       set result $pgpbestkeys
    }
    while {$result == {}} {
	set result [Pgp_KeyBox $v "You didn't select a $pgp($v,fullName) key for $id" $keyringtype $pgpbestkeys]
    }
    set pgp($v,match,$email) $result
    foreach key $result {
	set pgp($v,simpleMatch,[string tolower [string trim [lindex $key 4]]]) $key
    }

    # The list of keys
    return [set pgp($v,match,$email)]
}

# returns the only key matching $name.
proc Pgp_Match_Simple { v name keyringtype } {
    global pgp

    set name [string tolower [string trim $name]]

    if {([set pgp($v,cacheids)] == "none") || ![info exists pgp($v,simpleMatch,$name)]} {
	set keylist [Pgp_Exec_KeyList $v $name $keyringtype]
        Exmh_Debug "<Pgp_Match_Simple>: Keylist: $keylist"
	if {[llength $keylist] == 1} {
	    set pgp($v,simpleMatch,$name) [lindex $keylist 0]
	} elseif {[llength $keylist] == 0} {
	    error "<[set pgp($v,fullName)]> no keys matching $name"
	} else {
	    error "<[set pgp($v,fullName)]> several keys matching $name"
	}
    }

    return [set pgp($v,simpleMatch,$name)]
}

# returns a list of keys where every entry only has one userid
# for instance rather than {0214 RSA 0132 RSA "monnier" "monnier@di"} it will give
# {0214 RSA 0132 RSA "monnier"} {0214 RSA 0132 RSA "monnier@di"}
proc Pgp_Match_FlatKeyList { v pattern keyringtype } {

    Exmh_Debug "Pgp_Match_FlatKeyList $v $pattern $keyringtype"
    set keys [Pgp_Exec_KeyList $v $pattern $keyringtype]
    Exmh_Debug "<Pgp_Match_FlatKeyList> Keys: $keys"
    set userids {}

    foreach key $keys {
	if {[llength $key] > 5} {
	    set keyids [lrange $key 0 3]
	    foreach userid [lrange $key 4 end] {
		lappend userids [concat $keyids [list $userid]]
	    }
	} else {
	    lappend userids $key
	}
    }

    return $userids
}

# kind of the opposite to Pgp_FlatKeyList
proc Pgp_Match_UnflattenKeyList { keylist } {
   
   if {"$keylist" == {}} {
      return {}
   }

   set result {}
   #
   set curKeyid [lrange [lindex $keylist 0] 0 3]
   set curKey [lindex $keylist 0]

   foreach key [lrange $keylist 1 end] {
      if {[string match [lrange $key 0 3] $curKeyid]} {
	 lappend curKey [lindex $key 4]
      } else {
	 lappend result $curKey
	 set curKey $key
	 set curKeyid [lrange $key 0 3]
      }
   }
   lappend result $curKey
   return $result
}

# returns a list of pgpkeys that should be as small as possible,
# while (hopefully) still containing the key matching the guy specified by
# $loginids $domainids and $commentids
proc Pgp_Match_InitialKeyList { v loginids domainids commentids keyringtype } {

    if {[llength $domainids] > 2} {
	set pattern [join [lrange $domainids 1 end] "."]  ;# The last 2
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
    #
    set keylist [Pgp_Match_FlatKeyList $v $pattern $keyringtype]
    return $keylist
}

proc Pgp_KeyBox { v label keyringtype keylist } {
    global pgpkeybox pgpkeyboxsel

    catch {unset pgpkeybox}
    #########
    # Config
    # <color>
    set pgpkeybox(text,color,normalbg) linen
    set pgpkeybox(text,color,selectedbg) yellow
    set pgpkeybox(text,color,mouseoverbg) lavender
    set pgpkeybox(text,color,keyfg) blue
    set pgpkeybox(text,color,subkeyfg) forestgreen
    set pgpkeybox(text,color,useridfg) black
    # <cursor>
    set pgpkeybox(text,cursor,normal) top_left_arrow
    set pgpkeybox(text,cursor,over) hand2

    if [winfo exists .fridolin] {
       destroy .fridolin
    }
    set t [toplevel .fridolin]
    wm title $t $label

    # the frame containing the buttons List and Ok
    set f1 [frame $t.f1]
    pack $f1 -fill x

    # the keylist
    set f0 [frame $t.f0]
    pack $f0 -fill both -expand 1
    set t1 [set pgpkeybox(t) [text $f0.t1 -background $pgpkeybox(text,color,normalbg) \
                                   -wrap none -cursor $pgpkeybox(text,cursor,normal)]]
    set s1 [scrollbar $f0.s1 -command [list $t1 yview]]
    set s2 [scrollbar $f0.s2 -orient horizontal -command [list $t1 xview]]
    $t1 configure -yscrollcommand [list $s1 set] -xscrollcommand [list $s2 set]
    grid $t1 $s1
    grid $t1 -sticky news
    grid $s1 -sticky ns
    grid $s2 -sticky we
    grid rowconfigure $f0 0 -weight 1
    grid columnconfigure $f0 0 -weight 1

    # the frame containing the label and entryfield
    set f2 [frame $t.f2]
    pack $f2 -fill x

    set l1 [label $f1.l -text $label]
    pack $l1 -side left
    set b0 [button $f1.ok -text Ok -command Pgp_KeyBox_Ok]
    pack $b0 -side right
    set b1 [button $f1.cancel -text Cancel -command Pgp_KeyBox_Cancel]
    pack $b1 -side right
    set b2 [button $f1.list -text List -command [list Pgp_KeyBox_List $v $keyringtype]]
    pack $b2 -side right

    set l [label $f2.l -text Pattern]
    pack $l -side left
    set pgpkeybox(e) [entry $f2.e -textvariable pgpkeybox(entry)]
    pack $pgpkeybox(e) -side left -fill x -expand 1
    bind $pgpkeybox(e) <Return> [list Pgp_KeyBox_List $v $keyringtype]
    set b3 [button $f2.b -text Clear -command Pgp_KeyBox_ClearEntry]
    pack $b3 -side left

    Pgp_KeyBox_ListKeys [set pgpkeybox(keylist) $keylist]

    wm protocol $t WM_DELETE_WINDOW Pgp_KeyBox_Ok

    tkwait variable pgpkeybox(ok)
    destroy $t

    Exmh_Debug "<Pgp_KeyBox> $pgpkeybox(keys)"
    return $pgpkeybox(keys)
}
proc Pgp_KeyBox_ListKeys {keylist} {
    global pgpkeybox pgpkeyboxsel

    $pgpkeybox(t) tag configure key -foreground $pgpkeybox(text,color,keyfg)
    $pgpkeybox(t) tag configure subkey -foreground $pgpkeybox(text,color,subkeyfg)
    $pgpkeybox(t) tag configure userid -foreground $pgpkeybox(text,color,useridfg)

    $pgpkeybox(t) configure -state normal
    $pgpkeybox(t) delete 1.0 end

    # fill up keylist
    catch {unset pgpkeyboxsel}
    set line -1
    foreach key $keylist {
        incr line
        $pgpkeybox(t) tag bind key($line) <Enter> [list Pgp_KeyBox_Enter $line]
        $pgpkeybox(t) tag bind key($line) <Leave> [list Pgp_KeyBox_Leave $line]
        $pgpkeybox(t) tag bind key($line) <ButtonPress-1> [list Pgp_KeyBox_Sel $line]
        $pgpkeybox(t) tag bind key($line) <Double-ButtonPress-1> [list Pgp_KeyBox_Sel $line]
        $pgpkeybox(t) tag bind key($line) <Double-ButtonPress-1> [list + Pgp_KeyBox_Sel $line 1]
        $pgpkeybox(t) tag bind key($line) <B1-Motion> [list Pgp_KeyBox_ExtendSel]
        $pgpkeybox(t) tag bind key($line) <ButtonPress-3> [list Pgp_KeyBox_Choose [lindex $key 4]]
        $pgpkeybox(t) tag configure key($line) -background $pgpkeybox(text,color,normalbg)
        $pgpkeybox(t) insert insert "[lindex $key 0] [lindex $key 1] " [list key($line) key]
        if {[string length [lindex $key 2]] != 0} {
          $pgpkeybox(t) insert insert "[lindex $key 2] [lindex $key 3] " [list key($line) subkey]
        }
        $pgpkeybox(t) insert insert "[lindex $key 4]\n" [list key($line) userid]
        update idletasks
        set pgpkeyboxsel(selected,$line) 0
        set pgpkeybox(bg,$line) $pgpkeybox(text,color,normalbg)
        set boundaries [$pgpkeybox(t) dlineinfo [expr $line + 1].0]
        set topline [lindex $boundaries 1]
        set baseline [expr [lindex $boundaries 1] + [lindex $boundaries 3] - 1]
        set pgpkeyboxsel(boundaries,$line) [list $topline $baseline]
    }
    $pgpkeybox(t) delete "[expr $line + 1].0 lineend" "[expr $line + 1].0 lineend + 1 char"
    $pgpkeybox(t) configure -state disabled
}
proc Pgp_KeyBox_Enter {line} {
    global pgpkeybox
    $pgpkeybox(t) tag configure key($line) -relief raised -borderwidth 2 \
                                           -background $pgpkeybox(text,color,mouseoverbg)
    $pgpkeybox(t) configure -cursor $pgpkeybox(text,cursor,over)
}
proc Pgp_KeyBox_Leave {line} {
    global pgpkeybox
    $pgpkeybox(t) tag configure key($line) -relief flat -background $pgpkeybox(bg,$line)
    $pgpkeybox(t) configure -cursor $pgpkeybox(text,cursor,normal)
}
proc Pgp_KeyBox_List {v keyringtype} {
    global pgpkeybox
    Pgp_KeyBox_ListKeys [set pgpkeybox(keylist) \
        [Pgp_Match_FlatKeyList $v [$pgpkeybox(e) get] $keyringtype]]
    after 1 [list set pgpkeybox(entry) [string trim $pgpkeybox(entry)]]
}
proc Pgp_KeyBox_Choose {userid} {
    global pgpkeybox
    set pgpkeybox(entry) $userid
}
proc Pgp_KeyBox_Sel {line {forceok 0}} {
    global pgpkeybox pgpkeyboxsel

    set pgpkeyboxsel(anchor) [expr [winfo pointery $pgpkeybox(t)] - [winfo rooty $pgpkeybox(t)]]
    set pgpkeyboxsel(currentline) $line

    if $forceok {
        set pgpkeyboxsel(selected,$line) 1
        Pgp_KeyBox_Ok
        return
    }
    Pgp_KeyBox_Select $line
}
proc Pgp_KeyBox_Select {line} {
    global pgpkeybox pgpkeyboxsel

    if {[set pgpkeyboxsel(selected,$line)]} {
        set pgpkeyboxsel(selected,$line) 0
        $pgpkeybox(t) tag configure key($line) \
                  -background [set pgpkeybox(bg,$line) $pgpkeybox(text,color,normalbg)]
    } else {
        set pgpkeyboxsel(selected,$line) 1
        $pgpkeybox(t) tag configure key($line) \
                  -background [set pgpkeybox(bg,$line) $pgpkeybox(text,color,selectedbg)]
    }
}
# Extend the selection from line
proc Pgp_KeyBox_ExtendSel {} {
    global pgpkeybox pgpkeyboxsel

    # mousepointer y-coord in text
    set pointery [expr [winfo pointery $pgpkeybox(t)] - [winfo rooty $pgpkeybox(t)]]

    if {$pointery > $pgpkeyboxsel(anchor)} {
        # below anchor
        if {$pointery < [lindex [set pgpkeyboxsel(boundaries,$pgpkeyboxsel(currentline))] 0]} {
            # enter cell above
            if {[info exists pgpkeyboxsel(boundaries,[expr $pgpkeyboxsel(currentline) - 1])]} {
              Pgp_KeyBox_Select $pgpkeyboxsel(currentline)
              incr pgpkeyboxsel(currentline) -1
            }
        } elseif {$pointery > [lindex [set pgpkeyboxsel(boundaries,$pgpkeyboxsel(currentline))] 1]} {
            # enter cell below
            if {[info exists pgpkeyboxsel(boundaries,[expr $pgpkeyboxsel(currentline) + 1])]} {
              incr pgpkeyboxsel(currentline)
              Pgp_KeyBox_Select $pgpkeyboxsel(currentline)
            }
        }
    } elseif {$pointery < $pgpkeyboxsel(anchor)} {
        # above anchor
        if {$pointery < [lindex [set pgpkeyboxsel(boundaries,$pgpkeyboxsel(currentline))] 0]} {
            # enter cell above
            if {[info exists pgpkeyboxsel(boundaries,[expr $pgpkeyboxsel(currentline) - 1])]} {
              incr pgpkeyboxsel(currentline) -1
              Pgp_KeyBox_Select $pgpkeyboxsel(currentline)
            }
        } elseif {$pointery > [lindex [set pgpkeyboxsel(boundaries,$pgpkeyboxsel(currentline))] 1]} {
            # enter cell below
            if {[info exists pgpkeyboxsel(boundaries,[expr $pgpkeyboxsel(currentline) + 1])]} {
              Pgp_KeyBox_Select $pgpkeyboxsel(currentline)
              incr pgpkeyboxsel(currentline)
            }
        }
    }
}
proc Pgp_KeyBox_Ok {} {
    global pgpkeybox pgpkeyboxsel
    set pgpkeybox(keys) {}
    foreach x [array names pgpkeyboxsel selected,*] {
        if {[set pgpkeyboxsel($x)]} {
            regexp {selected,(.*)} $x {} line
            lappend pgpkeybox(keys) [lindex $pgpkeybox(keylist) $line]
        }
    }
    set pgpkeybox(ok) ready
}
proc Pgp_KeyBox_Cancel {} {
    global pgpkeybox
    set pgpkeybox(keys) {}
    set pgpkeybox(ok) ready
}
proc Pgp_KeyBox_ClearEntry {} {
    global pgpkeybox
    $pgpkeybox(e) delete 0 end
}

################################################################# >>>>>>>>>> OLD
# based on fileselect.tcl
# asks the user for selection of keys.
proc Pgp_KeyBoxold { v label keyringtype keylist } {
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
                [list keybox.ok.cmd $w ] {left padx 1}
        Widget_AddBut $w.but cancel Cancel \
                [list keybox.cancel.cmd $w ] {right padx 1}
        Widget_AddBut $w.but list List \
                [list keybox.list.cmd $v $w $keyringtype] {right padx 1}

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
    $keybox(listbut) configure -command [list keybox.list.cmd $v $w $keyringtype]
    $keybox(sel) configure -textvariable keybox(filter)
    set keybox(state) ""
    set keybox(filter) {}
    set keybox(keylist) $keylist
    set keybox(result) {}
    $keybox(msg) configure -text $label
    $keybox(list) delete 0 end
    foreach i $keybox(keylist) {
	$keybox(list) insert end [lindex $i 4]
    }
    bind $keybox(list) <Double-ButtonPress-1> {
        %W select set [%W nearest %y]
        $keybox(ok) invoke
    }
    Widget_BindEntryCmd $keybox(sel) <Key-Return> [list $keybox(listbut) invoke]

    Exwin_ToplevelFocus $w $keybox(sel)
    update idletask
    grab $w
    tkwait variable keybox(result)
    grab release $w

    if {$keybox(state) == "cancel"} {
	error "cancel"
    }
    return [Pgp_Match_UnflattenKeyList $keybox(result)]
}
proc keybox.ok.cmd {w} {
    global keybox

    #if {[selection own] == $keybox(list)}
    
    set keybox(result) [Pgp_Misc_Map i {lindex $keybox(keylist) $i} [$keybox(list) curselection]]
    if {$keybox(result) == {} && [llength $keybox(keylist)] == 1} {
	set keybox(result) $keybox(keylist)
    }
    Exwin_Dismiss $w
}
#
proc keybox.cancel.cmd {w} {
    global keybox

    set keybox(state) "cancel"
    set keybox(result) {}
    Exwin_Dismiss $w
}
#
proc keybox.list.cmd { v w keyringtype } {
    global keybox

    $keybox(list) delete 0 end

    set keybox(keylist) [Pgp_Match_FlatKeyList $v [$keybox(sel) get] $keyringtype]

    foreach x $keybox(keylist) {
	$keybox(list) insert end [lindex $x 4]
    }
}
########################################################################## >>>>>>> OLD

# Store email/keyid matches if requested
proc Pgp_Match_CheckPoint {} {
    global pgp

    foreach v $pgp(supportedversions) {
	if { [set pgp($v,enabled)] } {
	    set path [set pgp($v,defaultPath)]
	    if {([set pgp($v,cacheids)] == "persistent") && \
                    ![catch {open $path/.matchcache.[set pgp($v,fullName)] w 0600} out]} {
                puts -nonewline $out [array get pgp $v,match,*]
                puts -nonewline $out "\x81"
	    	puts -nonewline $out [array get pgp $v,simpleMatch,*]
	    	close $out
	    }
    	}
    }
}


### Init ###

proc Pgp_Match_Init {} {
    global pgp

    foreach v $pgp(supportedversions) {
        if { [set pgp($v,enabled)] } {
	    set path [set pgp($v,defaultPath)]
            if {([set pgp($v,cacheids)] == "persistent") && \
                      ![catch {open $path/.matchcache.[set pgp($v,fullName)] r} in]} {
                set indata [string trim [read $in]]
                if {![catch {split $indata "\x81"} indata]} {
                    catch {array set pgp [lindex $indata 0]}
                    catch {array set pgp [lindex $indata 1]}
                }
                close $in
            }
        }
    }
}

