# aliases.tcl
# Original contributed by Scott Stanton, sstanton@eng.sun.com
# Tweaked for exmh integration by Brent Welch
#

#
# Aliases_Pref:
#
# This procedure displays a dialog box for editing the MH aliases
# file.  
#
proc Aliases_Pref { {nalias {}} } {
    global mhProfile
    if ![info exists mhProfile(aliasfile)] {
	if {![AliasesInitProfile]} {
	    return
	}
    }
    set filename [Mh_Pathname $mhProfile(aliasfile)]
    if ![file exists $filename] {
	if [catch {open $filename w} it] {
	    Exmh_Status "Cannot create $filename\n$it"
	    return
	}
	close $it
    }
    if [Exwin_Toplevel .aliaspref "Alias Browser" Alias] {
	.aliaspref.but.quit config -command {AliasesDismiss}
	wm protocol .aliaspref WM_DELETE_WINDOW AliasesDismiss
	Widget_AddBut .aliaspref.but save "Save" \
	    {Aliases_Save; Exwin_Dismiss .aliaspref}
	Widget_AddBut .aliaspref.but import "Import" \
	    {Aliases_Import}
	Widget_AddBut .aliaspref.but help "Help" \
	    {Aliases_Help}
	Widget_Label .aliaspref.but label {left fill} -text \
"MH Alias Definitions"
	frame .aliaspref.alias
	frame .aliaspref.addr
	pack .aliaspref.alias .aliaspref.addr -side left -fill both -padx 5 -pady 5
	pack .aliaspref.addr -expand 1 
	Widget_ListEditor .aliaspref.alias Aliases alias \
	    Aliases_Insert Aliases_Change Aliases_Delete Address_Rebuild
	Widget_ListEditor .aliaspref.addr Addresses address \
	    Address_Insert Address_Change Address_Delete

	# Asymetric, but users can paste out of the Alias list,
	# and paste into the Address entry.
	.aliaspref.addr.listbox config -exportselection 0

	# Create search bindings in the entries.
	global tk_version
	if {$tk_version < 4.0} {
	    # Need to suck up the class bindings for Entry first
	    foreach seq [bind Entry] {
		bind .aliaspref.alias.entry $seq [bind Entry $seq]
		bind .aliaspref.addr.entry $seq [bind Entry $seq]
	    }
	    bind .aliaspref.alias.entry <Any-Tab> { focus .aliaspref.addr.entry }
	    bind .aliaspref.alias.entry <Any-Key> \
		"[bind Entry <Any-Key>] ; Widget_ListSearch .aliaspref.alias"
	    bind .aliaspref.alias.entry <Any-space> \
		{set alias [AliasesComplete .aliaspref.alias]
		 Aliases_Insert}
	    bind .aliaspref.alias.entry <Control-c> \
		{Aliases_Delete}
	    bind .aliaspref.addr.entry <Any-Tab> { focus .aliaspref.alias.entry }
	    bind .aliaspref.addr.entry <Any-Key>\
		"[bind Entry <Any-Key>] ; Widget_ListSearch .aliaspref.addr"
	    bind .aliaspref.addr.entry <Control-space> {
		set address [AliasesComplete .aliaspref.addr]
	    }
	} else {
	    bindtags .aliaspref.alias.entry \
		[list .aliaspref.alias.entry Entry SearchAlias]
	    bind SearchAlias <KeyPress> \
		 {Widget_ListSearch .aliaspref.alias}
	    bind .aliaspref.alias.entry <space> {
		set alias [AliasesComplete .aliaspref.alias]
		Aliases_Insert
		break
	    }
	    bind .aliaspref.alias.entry <Control-c> \
		{Aliases_Delete ; break}

	    bindtags .aliaspref.addr.entry \
		[list .aliaspref.addr.entry Entry SearchAddress]
	    bind SearchAddress <KeyPress> \
		 {Widget_ListSearch .aliaspref.addr}
	    bind .aliaspref.addr.entry <Control-space> {
		set address [AliasesComplete .aliaspref.addr]
		break
	    }
	    foreach e {.aliaspref.alias.entry .aliaspref.addr.entry} {
		Exmh_Debug bindtags $e [bindtags $e]
	    }
	}
	wm minsize .aliaspref 1 1

    }
    Exwin_ToplevelFocus .aliaspref .aliaspref.alias.entry
    # The following command foils a spontaneous <Destroy> event
    # that otherwise kills the dialog in the special case that we
    # just created/destroyed the .aliasfile toplevel
    Visibility_Wait .aliaspref
    Aliases_Load
    Aliases_Rebuild $nalias
}
proc AliasesComplete { parent } {
    # Fetch the selected entry from the aliases listbox, if any
    Exmh_Status AliasesComplete
    set i [$parent.listbox curselection]
    if {$i != {}} {
	return [$parent.listbox get [lindex $i 0]]
    } else {
	return [$parent.entry get]
    }
}
proc Aliases_Help {} {
    Help Aliases "Tips for the Aliases interface"
}

#
# AliasesInitProfile
#
# Create the MH profile entry that names the alias file.
#
proc AliasesInitProfile {} {
    global mhProfile aliasOK
    if [winfo exists .aliasfile] {
	return
    }
    Widget_Toplevel .aliasfile "Setup Alias File"
    Widget_Message .aliasfile msg -aspect 1000 -text "
The MH aliases are kept in a file (you choose the name)
and this file is named in the AliasFile profile entry.

Should Exmh set that up for you now?"

    Widget_Frame .aliasfile rim Pad {top expand fill}
    .aliasfile.rim configure -bd 10

    Widget_Label .aliasfile.rim l {left} -text "Alias file name: "
    Widget_Entry .aliasfile.rim e {left fill}  -width 30
    .aliasfile.rim.e insert 0 [glob ~]/.mh_aliases

    set aliasOK 0
    Widget_Frame .aliasfile.rim but Menubar {top fill}
    Widget_AddBut .aliasfile.rim.but yes "Yes" [list AliasesSetupCommit .aliasfile .aliasfile.rim.e]
    Widget_AddBut .aliasfile.rim.but no "No" {destroy .aliasfile}
    tkwait window .aliasfile
    return $aliasOK
}

proc AliasesSetupCommit {top entry} {
    global mhProfile aliasOK

    set filename [$entry get]
    regsub -all "\[ \t\n\]" $filename {} filename

    if ![file exists $filename] {
	if [catch {open $filename w} it] {
	    .aliasfile.msg config -text "Cannot create $filename\n$it"
	    return
	}
	close $it
    }
    set mhProfile(aliasfile) $filename
    if [catch {open ~/.mh_profile a} out] {
	Exmh_Status "Cannot open ~/.mh_profile: $out" purple
	unset mhProfile(aliasfile)
	destroy .aliasfile
	return
    }
    puts $out "AliasFile: $filename"
    Exmh_Status "AliasFile: $filename"
    close $out

    set aliasOK 1
    destroy $top
}

#
# Aliases_Rebuild:
#
# Load the aliases list into the alias listbox.  If item is specified,
# then that element of the list will be selected, otherwise no element
# will be selected.
#
proc Aliases_Rebuild {{item {}}} {
    global aliases alias
    set top [.aliaspref.alias.listbox nearest 0]
    .aliaspref.alias.listbox delete 0 end
    set names [AliasesList]
    eval .aliaspref.alias.listbox insert end $names
    if {$item == {}} {
	Widget_ListboxClear .aliaspref.alias.listbox
	Widget_ListboxYview .aliaspref.alias.listbox $top
	set alias {}
    } else {
	set index [lsearch -exact $names $item]
	Widget_ListboxSelect .aliaspref.alias.listbox  $index
	Widget_ListboxYview .aliaspref.alias.listbox $index
	set alias $item
    }
    Address_Rebuild
}
proc AliasesList {} {
    global aliasesOrder
    set res {}
    foreach a $aliasesOrder {
	if [regexp {^[ 	]*[;#]} $a] {
	    continue
	}
	if [regexp {^[ 	]*$} $a] {
	    continue
	}
	if [regexp {^[ 	]*<} $a] {
	    continue
	}
	lappend res $a
    }
    return $res
}
#
# Address_Rebuild:
#
# Display addresses from currently selected alias in the address listbox.
# If item is specified, then that element of the list will be selected,
# otherwise no element will be selected.
#
proc Address_Rebuild {{item {}}} {
    global aliases address alias

    # rebuild the address list based on the current alias selected
    if {([string length $alias] > 0) && [info exists aliases($alias)]} {
	.aliaspref.addr.listbox delete 0 end
	set names [lsort $aliases($alias)]
	eval .aliaspref.addr.listbox insert end $names
    } else {
	.aliaspref.addr.listbox delete 0 end
	set item {}
    }

    # now select appropriate item from the list
    if {$item == {}} {
	Widget_ListboxClear .aliaspref.addr.listbox
    } else {
	set index [lsearch -exact $names $item]
	Widget_ListboxSelect .aliaspref.addr.listbox $index
	Widget_ListboxYview .aliaspref.addr.listbox $index
	set address [.aliaspref.addr.listbox get $index]
    }
}
#
# Aliases_New:
#
#	Create a new alias. For use with message display window (maybe...)
#	Instead, what currently happens is that MsgShowInText side-effects
#	our address variable so the Aliases_Pref UI is updated.
#
proc Aliases_New { nalias naddress } {
    global aliases alias address
    if [info exists aliases($nalias)] {
	# Existing alias - invoke user interface
	Aliases_Pref $nalias
	set address $naddress
	set alias $nalias
    } else {
	AliasesDirty
	set aliases($alias) $naddress
	catch {Aliases_Rebuild $alias}
    }
}

#
# Aliases_Insert:
#
# Add the specified entry to the alias list, if it is unique.
#
proc Aliases_Insert {} {
    global aliases alias address aliasesOrder
    if ![info exist aliases($alias)] {
	AliasesDirty
	lappend aliases($alias) $address
	lappend aliasesOrder $alias
    } else {
	# error, alias already exists
    }
    Aliases_Rebuild $alias
}

#
# Aliases_Change:
#
# Change the name of specified alias.  If the new name is already taken,
# nothing changes.
#
proc Aliases_Change {} {
    global aliases alias aliasesOrder
    set current [.aliaspref.alias.listbox curselection]
    if {[llength $current] == 1} {
	set item [.aliaspref.alias.listbox get $current]
	if {![info exists aliases($alias)]} {
	    set aliases($alias) $aliases($item)
	    unset aliases($item)
	    set ix [lsearch $aliasesOrder $item]
	    set aliasesOrder [lreplace $aliasesOrder $ix $ix $alias]
	    AliasesDirty
	    Aliases_Rebuild $alias
	}
    }
}

#
# Aliases_Delete:
#
# Delete the current selection from the list of aliases
#
proc Aliases_Delete {} {
    global aliases alias aliasesOrder
    if {[string length $alias] > 0} {
	set ix [lsearch $aliasesOrder $alias]
	if {$ix >= 0} {
	    AliasesDirty
	    set aliasesOrder [lreplace $aliasesOrder $ix $ix]
	    catch {unset aliases($alias)}
	    Aliases_Rebuild
	}
    }
}


#
# Address_Insert:
#
# Add the specified entry to the address list.  Duplicates are allowed.
#
proc Address_Insert {} {
    global aliases address alias
    if {[string length $alias] > 0} {
	set exists [info exists aliases($alias)]
	AliasesDirty
	lappend aliases($alias) $address
	if {! $exists} {
	    Aliases_Rebuild $alias
	}
	Address_Rebuild $address
    }
}

#
# Address_Change:
#
# Change the current address.
#
proc Address_Change {} {
    global aliases address alias
    set current [.aliaspref.addr.listbox curselection]
    if {([llength $current] == 1) &&
	([string length $alias] > 0) && ([string length $address] > 0)} {
	set oldaddr [.aliaspref.addr.listbox get $current]
	if ![info exists aliases($alias)] {
	    AliasesDirty
	    set aliases($alias) $address
	    Aliases_Rebuild $alias
	    Address_Rebuild $address
	} else {
	    set pos [lsearch $aliases($alias) $oldaddr]
	    if {$pos >= 0} {
		AliasesDirty
		set aliases($alias) \
		    [lreplace $aliases($alias) $pos $pos $address]
		Address_Rebuild $address
	    }
	}
    }
}

#
# Address_Delete:
#
# Delete the current selection from the list of addresses
#
proc Address_Delete {} {
    global aliases alias address
    if {([string length $address] > 0) && 
	([string length $alias] > 0) &&
	[info exists aliases($alias)]} {
	set pos [lsearch $aliases($alias) $address]
	if {$pos >= 0} {
	    set aliases($alias) \
		[lreplace $aliases($alias) $pos $pos]
	    AliasesDirty
	    Address_Rebuild
	}
    }
}
#
# AliasesDismiss:
#
# See if the database has been modified before quiting.
#
proc AliasesDirty {} {
    global aliasesDirty
    set aliasesDirty 1
}
proc AliasesIsDirty {} {
    global aliasesDirty
    if ![info exists aliasesDirty] {
	return 0
    } else {
	return $aliasesDirty
    }
}
proc AliasesClean {} {
    global aliasesDirty
    set aliasesDirty 0
}
proc AliasesIsClean {} {
    global aliasesDirty
    return [expr ! $aliasesDirty]
}

proc AliasesDismiss {} {
    set ok 0
    if [AliasesIsDirty] {
	if [AliasesDirtyDialog] {
	    set ok 1
	}
    } else {
	set ok 1
    }
    if {$ok} {
	catch {destroy .aliashelp}
	Exwin_Dismiss .aliaspref
    }
}
proc AliasesDirtyDialog {} {
    if [catch {frame .aliaspref.dirty -bd 4 -relief ridge} t] {
	Aliases_Save
	destroy .aliaspref.dirty
	return 1
    }
    message $t.msg -aspect 1000 -text "Save changes to aliases?"
    pack $t.msg -padx 20 -pady 20
    FontWidget button $t.yes -text OK -command {
	Aliases_Save
	destroy .aliaspref.dirty
    }
    FontWidget button $t.no -text Cancel -command {
	destroy .aliaspref.dirty
    }
    FontWidget button $t.reset -text Reset -command {
	Aliases_Load
	Aliases_Rebuild
	Exmh_Status "Reset aliases"
	destroy .aliaspref.dirty
    }
    pack $t.yes $t.no $t.reset -padx 20 -side right
    Widget_PlaceDialog .aliaspref .aliaspref.dirty
    tkwait window .aliaspref.dirty
    return [AliasesIsClean]
}
proc Aliases_CheckPoint {} {
    if [AliasesIsDirty] {
	Aliases_Save
    }
}
#
# Aliases_Load:
#
# This procedure attempts to load the MH alias file indicated in the
# MH profile, creating it if necessary.  The contents of the alias
# file will be stored in the global aliases array.
#
proc Aliases_Load {} {
    global aliases mhProfile aliasesOrder aliases_sep

    AliasesClean
    catch {unset aliases} ; set aliases(foo) foo ; unset aliases(foo)
    set aliasesOrder {}
    if ![info exists mhProfile(aliasfile)] {
	return
    }
    if [catch {open [Mh_Pathname $mhProfile(aliasfile)]} input] {
	Exmh_Status "Cannot open [Mh_Pathname $mhProfile(aliasfile)]: $input"
	return
    }
    # clear the old aliases array and load the new one
    set continue 0
    while {[gets $input line] >= 0} {
	set cont $continue
	if [regexp {\\$} $line] {
	    set continue 1
	    set line [string trimright $line \\]
	} else {
	    set continue 0
	}
	if {$cont} {
#	    append aliases($key) $line
	    regsub -all {[ 	]*,[ 	]*} $line , value
	    set aliases($key) \
		[concat $aliases($key) [split [string trim $value "\t ,"] ,]]
	} else {
	    if [regexp {^[ 	]*[;#:]} $line] {
		lappend aliasesOrder $line
	    } elseif [regexp "^\[ \t\]*$" $line] {
		lappend aliasesOrder $line
	    } elseif [regexp "^\[ \t\]*<" $line] {
		lappend aliasesOrder $line
	    } else {
	        regexp {([^;:]+)([:;])(.*)} $line match key sep other
		lappend aliasesOrder [string trim $key]
#		set aliases($key) $other
		regsub -all {[ 	]*,[ 	]*} $other , value
		set aliases($key) [split [string trim $value "\t ,"] ,]
		set aliases_sep($key) $sep

	    }
	}
    }
#   foreach key [array names aliases] {
#	set aliases($key) [AliasesChop $aliases($key)]
#   }
    close $input
}
proc AliasesChop { rawline } {
    # Doomed to failure.
    set list {}
    Exmh_Debug AliasesChop $rawline
    while {[string length $rawline] > 0} {
	if [regexp -indices {^[ 	]*("[^"]+"[ 	]*<[^>]+>)[ 	]*,?} \
		$rawline match addr] {
	    Exmh_Debug [eval {string range $rawline} $addr]
	    lappend list [eval {string range $rawline} $addr]
	    set next [expr [lindex $match 1]+1]
	    set rawline [string range $rawline $next end]
	} elseif [regexp -indices {^[ 	]*(\([^\)]+\)[ 	]*<[^>]+>)[ 	]*,?}\
		$rawline match addr] {
	    Exmh_Debug [eval {string range $rawline} $addr]
	    lappend list [eval {string range $rawline} $addr]
	    set next [expr [lindex $match 1]+1]
	    set rawline [string range $rawline $next end]
	} elseif [regexp -indices {^[ 	]*(<[^>]+>)[ 	]*,?}\
		$rawline match addr] {
	    Exmh_Debug [eval {string range $rawline} $addr]
	    lappend list [eval {string range $rawline} $addr]
	    set next [expr [lindex $match 1]+1]
	    set rawline [string range $rawline $next end]
	} elseif [regexp -indices {^[ 	]*([^ 	]+)[ 	]*,?}\
		$rawline match addr] {
	    Exmh_Debug [eval {string range $rawline} $addr]
	    lappend list [eval {string range $rawline} $addr]
	    set next [expr [lindex $match 1]+1]
	    set rawline [string range $rawline $next end]
	} else {
	    Exmh_Debug "miss"
	    break
	}
    }
}
#
# Aliases_Save:
#
# This procedure writes the contents of the aliases array to the MH
# alias file indicated in the MH profile.
#
proc Aliases_Save {} {
    global aliases mhProfile aliasesOrder aliases_sep

    if [info exists aliases] {
	if [catch {open [Mh_Pathname $mhProfile(aliasfile)] w} output] {
	    puts stderr "Cannot write [Mh_Pathname $mhProfile(aliasfile)]: $output"
	    return
	}

	foreach alias $aliasesOrder {
	    if [regexp {^[ 	]*[;#]} $alias] {
		puts $output $alias
	    } elseif [regexp {^[ 	]*$} $alias] {
		puts $output $alias
	    } elseif [regexp {^[ 	]*<} $alias] {
		puts $output $alias
	    } elseif [info exists aliases($alias)] {
		if [catch {set aliases_sep($alias)} sep] {
		    set sep :
		}
		puts -nonewline $output "$alias$sep "
		set col [string length "$alias: "]
		set first 1
		foreach a $aliases($alias) {
		    if {! $first} {
			puts -nonewline $output ", "
			incr col 2
		    } else {
			set first 0
		    }
		    set l [string length $a]
		    if {($col + $l > 77)} {
			puts $output \\
			puts -nonewline $output \t
			set col 8
		    }
		    puts -nonewline $output $a
		    incr col $l
		}
		puts $output ""
	    }
	}
	close $output
	AliasesClean
	Exmh_Status "Saved aliases"
    }
}
proc Aliases_Import {} {
    global  mhProfile
    if [AliasesIsDirty] {
	if ![AliasesDirtyDialog] {
	    return
	}
    }
    if ![info exists mhProfile(aliasfile)] {
	if ![AliasesInitProfile] {
	    return
	}
    }
    set f [frame .aliaspref.import -bd 4 -relief ridge]
    Widget_Message $f msg -aspect 1000 -text "
Exmh knows how to import aliases from .mailrc-like files.
The format it expects is
alias Foo Bar@xyz
Enter the file name and hit OK"
    Widget_Frame $f rim Pad {top expand fill}
    $f.rim configure -bd 10

    Widget_Label $f.rim l {left} -text "mailrc file name: "
    Widget_Entry $f.rim e {left fill} -width 30
    $f.rim.e insert 0 [glob ~]/.mailrc

    set aliasOK 0
    Widget_Frame $f.rim but Menubar {top fill}
    Widget_AddBut $f.rim.but yes "OK" [list AliasesImportOK $f.rim.e $f]
    Widget_AddBut $f.rim.but no "Cancel" [list destroy $f]
    Widget_PlaceDialog .aliaspref $f 
    tkwait window $f
}

proc AliasesImportOK { entry dialog } {
    if [Aliases_ImportFile [$entry get]] {
	Aliases_Load
	Aliases_Rebuild
	destroy $dialog
    } else {
	lower $dialog
	update idletasks
	raise $dialog
    }
}
proc Aliases_ImportFile { f } {
    global mhProfile aliases
    if [catch {glob $f} file] {
	Exmh_Status $file
	return 0
    }
    if ![info exists mhProfile(aliasfile)] {
	Exmh_Status "No AliasFile MH profile"
	return 0
    }
    if [catch {exec egrep {^[ 	]*alias} $file} new_aliases] {
	Exmh_Status "No aliases in $file"
	return 0
    }
    set out [open [Mh_Pathname $mhProfile(aliasfile)] {WRONLY CREAT APPEND}]
    foreach a [split $new_aliases \n] {
	if [regexp {^alias ([^ 	]+)[ 	](.*)$} $a match key value] {
	    regsub -all { +} $value {, } value
	    if ![info exists aliases($key)] {
		puts $out "$key: $value"
	    }
	} else {
	    Exmh_Status "Cannot regexp $a"
	}
    }
    close $out
    return 1
}


