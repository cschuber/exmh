# pref.tcl
#
# User pref.  This uses a table-driven scheme to set a bunch
# of variables in the rest of the application.  The results are
# written out to a Xresources-style file that is read by Preferences_Init
# at startup.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

# A two-level scheme is used
# pref(panes) => list of preference windows
# pref($p,text) => explainatory text
# pref($p,prefs) => list of lists, each sublist looks like
#	{ varname xresname defaultValue Comment HelpMsg }
# The varname can be a simple variable or an array element
# The xresname is an Xresource specification
# The defaultValue can be a list, which turns into a set of radio buttons
# or it can be "ON" or "OFF", which turns into a check box
# or if it is a single string, it turns into an entry containing that string


proc PrefVar { item } { lindex $item 0 }
proc PrefXres { item } { lindex $item 1 }
proc PrefDefault { item } { lindex $item 2 }
proc PrefComment { item } { lindex $item 3 }
proc PrefHelp { item } { lindex $item 4 }

proc Preferences_Init { userDefaults appDefaults } {
    global pref

    set pref(uid) 0
    set pref(panes) {}
    set pref(userDefaults) $userDefaults
    set pref(appDefaults) $appDefaults
    set pref(localDefaults) \
	"[file dirname $appDefaults]/local.[file tail $appDefaults]"

    catch {exec mkdir -p [glob ~]/.exmh}

    if {[file exists [glob ~]/.exmh-defaults] 
	&& ![file exists $userDefaults]} { 
	PreferencesCopyToNewLocation
    }
    
    PreferencesReadFile $pref(appDefaults) startup
    PreferencesReadFile $pref(localDefaults) 50
    PreferencesReadFile $pref(userDefaults) user

    Preferences_Resource pref(helpInOneWindow) helpInOneWindow 1
}

proc PreferencesCopyToNewLocation {} {
    global pref

    Widget_Toplevel .newprefs "Copy User Preferences"
    Widget_Message .newprefs msg -aspect 1000 -text "
It appears you have not run Exmh since the [file tail $pref(userDefaults)] 
and other related files moved in to the ~/.exmh directory.

Is it ok if Exmh copies the files to your ~/.exmh directory?  Once you 
have verified that Exmh is functioning properly, you can delete the 
old files by hand.
"

    Widget_Frame .newprefs rim Pad {top expand fill}
    .newprefs.rim configure -bd 10
   
    Widget_Frame .newprefs.rim but Menubar {top fill}
    Widget_AddBut .newprefs.rim.but yes "Yes" PreferencesDoCopyFiles
    Widget_AddBut .newprefs.rim.but no "No, Exit" {destroy .newprefs ; exit }
    tkwait window .newprefs
}

proc PreferencesCopyDone { movedFiles } {
    Widget_Toplevel .filesmoved "Files Copied"
    Widget_Message .filesmoved msg -aspect 1000 -text "
The following files have been copied, and the copies have been renamed.  
Once you have verified that Exmh is working properly, you can delete 
these files.

$movedFiles
"

    Widget_Frame .filesmoved rim Pad {top expand fill}
    .filesmoved.rim configure -bd 10

    Widget_Frame .filesmoved.rim but Menubar {top fill}
    Widget_AddBut .filesmoved.rim.but ok "OK" {destroy .filesmoved }
    tkwait window .filesmoved
}

proc PreferencesDoCopyFiles { } {
    if {[file exists [glob ~]/.exmh-defaults] 
	&& ![file exists [glob ~]/.exmh/exmh-defaults]} {
	catch {exec cp -r [glob ~]/.exmh-defaults [glob ~]/.exmh/exmh-defaults}
	append movedList ".exmh-defaults\n"
    }
	
    if {[file exists [glob ~]/.exmh-defaults-mono]
        && ![file exists [glob ~]/.exmh/exmh-defaults-mono]} {
        catch {exec cp -r [glob ~]/.exmh-defaults-mono [glob ~]/.exmh/exmh-defaults-mono}
        append movedList ".exmh-defaults-mono\n"
    }

    if {[file exists [glob ~]/.exmh-defaults-color]
        && ![file exists [glob ~]/.exmh/exmh-defaults-color]} {
        catch {exec cp -r [glob ~]/.exmh-defaults-color [glob ~]/.exmh/exmh-defaults-color}
        append movedList ".exmh-defaults-color\n"
    }

    if {[file exists [glob ~]/.exmh_addrs] 
	&& ![file exists [glob ~]/.exmh/exmh_addrs]} {
	catch {exec cp -r [glob ~]/.exmh_addrs [glob ~]/.exmh/exmh_addrs}
        append movedList ".exmh_addrs\n"
    }

    if {[file exists [glob ~]/.exmh_addrs.bak] 
	&& ![file exists [glob ~]/.exmh/exmh_addrs.bak]} {
	catch { exec cp -r [glob ~]/.exmh_addrs.bak [glob ~]/.exmh/exmh_addrs.bak}
        append movedList ".exmh_addrs.bak\n"
    }
    
    if {[file exists [glob ~]/.exmh-images] 
	&& ![file exists [glob ~]/.exmh/exmh-images]} {
	catch { exec cp -r [glob ~]/.exmh-images [glob ~]/.exmh/exmh-images}
        append movedList ".exmh-images\n"
    }
    
    if {[file exists [glob ~]/.exmhbindings] 
	&& ![file exists [glob ~]/.exmh/exmhbindings]} {
	catch { exec cp -r [glob ~]/.exmhbindings [glob ~]/.exmh/exmhbindings}
        append movedList ".exmhbindings\n"
    }
    
    if {[file exists [glob ~]/.exmhsedit] 
	&& ![file exists [glob ~]/.exmh/exmhsedit]} {
	catch { exec cp -r [glob ~]/.exmhsedit [glob ~]/.exmh/exmhsedit}
        append movedList ".exmhsedit\n"
    }
    catch {destroy .newprefs}
    PreferencesCopyDone "$movedList"
}

proc PreferencesReadFile { basename level } {
    if [file exists $basename] {
	if [catch {option readfile $basename $level} err] {
	    Exmh_Status "Error reading '$basename': $err"
	}
    }

    if {[winfo depth .] > 4} {
	if [file exists $basename-color] {
	    if [catch {option readfile $basename-color $level} err] {
		Exmh_Status "Error in $basename-color: $err"
	    }
	}
    } else {
	if [file exists $basename-mono] {
	    if [catch {option readfile $basename-mono $level} err] {
		Exmh_Status "Error in $basename-mono: $err"
	    }
	}
    }
}
proc Preferences_Add { id text prefs } {
    global pref

    # Set up the table that drives the UI layout
    set ix [lsearch $pref(panes) $id]
    if {$ix < 0} {
	lappend pref(panes) $id
	set pref($id,prefs) $prefs
	set pref($id,text) $text
    } else {
	foreach p $prefs {
	    lappend pref($id,prefs) $p
	}
	if {[string length $text] > 0} {
	    append pref($id,text) \n$text
	}
    }

    # Initialize the global variable from the option database,
    # else the default value supplied.

    foreach item $prefs {
	set varName [PrefVar $item]
	set xresName [PrefXres $item]
	set value [PrefValue $varName $xresName]
	set default [PrefDefault $item]
	Exmh_Debug Pref_Add $varName $value
	if {$value == {}} {
	    # Set variables that are still not set
	    switch -regexp -- $default {
		^ON$		{PrefValueSet $varName 1}
		^OFF$		{PrefValueSet $varName 0}
		"^CHOICE "	{PrefValueSet $varName [lindex $default 1]}
		default		{PrefValueSet $varName $default}
	    }
	} else {
	    # Warp booleans to 0 or 1
	    if {$default == "OFF" || $default == "ON"} {
		switch -- $value {
		    0 -
		    1 		{ # ok as is }
		    true -
		    True -
		    TRUE 	{PrefValueSet $varName 1}
		    false -
		    False -
		    FALSE 	{PrefValueSet $varName 0}
		    default {
			catch {puts stderr "Bogus boolean value $value for Xresource $xresName"}
			PrefValueSet $varName 0
		    }
		}
	    } elseif {[regexp {^[0-9]+$} $default]} {
		# Clean up and validate integer values
	        PrefValueSet $varName [set value [string trim $value \ \t\n\r]]
		if [catch {expr int($value)}] {
		    PrefValueSet $varName $default
		}
	    }
	}
    }
}
# Return the value of the given variable,
# or the value from the xresource database,
# or {} if neither exist
proc PrefValue { _var _xres } {
    upvar #0 $_var var
    if [info exists var] {
	return $var
    }
    set var [option get . $_xres {}]
}
# set the value of the variable
proc PrefValueSet { _var _value } {
    upvar #0 $_var var
    if {[catch {
	set var $_value
    } err]} {
	# The above set sometimes breaks when traces on preference
	# variables have bugs in them.  This error lets us find out
	# what the variable is.

	error "Broken trace on [list set $_var $_value]: $err"
    }
}
proc PrefEntrySet { entry varName } {
    PrefValueSet $varName [$entry get]
}
proc PreferencesDismiss {{ix {}}} {
    global exwin pref
    Exwin_Dismiss .pref$ix
    catch {PreferencesNukeItemHelp .prefitemhelp}
    if {$ix == {}} {
	catch {Exwin_Dismiss .prefhelp}
	set ix 0
	foreach id $pref(panes) {
	    catch {Exwin_Dismiss .pref$ix}
	    incr ix
	}
    }
}
proc PreferencesDelete {} {
    global pref
    catch {PreferencesNukeItemHelp .prefitemhelp}
    catch {Exwin_Dismiss .prefhelp}
    set ix 0
    foreach id $pref(panes) {
	catch {Exwin_Dismiss .pref$ix}
	incr ix
    }
    Exwin_Dismiss .pref
}

proc PreferencesHelp {} {
    Help Preferences "Help for Preferences"
}

proc Preferences_Dialog {} {
    global pref
    if [Exwin_Toplevel .pref "Exmh Preferences" Pref] {
	set buttons .pref.but
	$buttons.quit configure -command {PreferencesDismiss}
	Widget_AddBut $buttons save Save {PreferencesSave}
	Widget_AddBut $buttons reset "Reset All" {Preferences_Reset}
	Widget_AddBut $buttons help Help {PreferencesHelp}

	set body [Widget_Frame .pref b Rim]
	$body configure -borderwidth 2 -relief raised
	set body [Widget_Frame $body b Pad]
	$body configure -borderwidth 10
	set body [Widget_Frame $body body Body]

	set maxWidth 0
	foreach id $pref(panes) {
	    set len [string length $id]
	    if {$len > $maxWidth} {
		set maxWidth $len
	    }
	}
	Widget_AddBut $body font Fonts Font_Dialog	{top}
	$body.font configure -width $maxWidth
	set i 0
	foreach id $pref(panes) {
	    Widget_AddBut $body but$i $id [list PreferencesSectionDialog $id] \
		{top}
	    $body.but$i configure -width $maxWidth
	    incr i
	}
	wm protocol .pref WM_DELETE_WINDOW PreferencesDelete
    }
}

proc PreferencesSectionDialog { id } {
    global pref env
    set ix [lsearch $pref(panes) $id]
    if {$ix < 0} {
	return
    }
    set buttons .pref$ix.but
    if [Exwin_Toplevel .pref$ix "Exmh Preferences - $id" Pref] {
	$buttons.quit configure -command [list PreferencesDismiss $ix]
	wm protocol .pref$ix WM_DELETE_WINDOW [list PreferencesDismiss $ix]
	wm minsize .pref$ix 25 2
	Widget_AddBut $buttons reset Reset [list Preferences_Reset $id]
	if $pref(helpInOneWindow) {
	    Widget_AddBut $buttons help Help [list PreferencesPaneHelp $id]
	}
	Widget_AddBut $buttons next Next [list PreferencesNext $ix] {left}
	Widget_AddBut $buttons prev Prev [list PreferencesNext $ix -1] {left}

	Widget_Label $buttons label {left fill} -text "Click labels for more details"

	set body [Widget_Frame .pref$ix b Rim]
	$body configure -borderwidth 2 -relief raised
	set body [Widget_Frame $body b Pad]
	$body configure -borderwidth 10
	set body [Widget_Frame $body body Body]

	if !$pref(helpInOneWindow) {
	    set txt [Widget_Text [Widget_Frame $body text] 4]
	    $txt insert 1.0 $pref($id,text)
	    $txt configure -state disabled
	}
	set maxWidth 0
	foreach item $pref($id,prefs) {
	    set len [string length [PrefComment $item]]
	    if {$len > $maxWidth} {
		set maxWidth $len
	    }
	}
	foreach item $pref($id,prefs) {
	    PreferencesDialogItem $body $id $item $maxWidth
	}
    }
    set pref(label) $buttons.label
}
proc PreferencesNext { ix {i 1}} {
    global pref
    global exwin
    set geo [string trimleft [wm geometry .pref$ix] -x0123456789]
    Exwin_Dismiss .pref$ix
    catch {PreferencesNukeItemHelp .prefitemhelp}
    incr ix $i
    set id [lindex $pref(panes) $ix]
    if {$id != {}} {
	PreferencesSectionDialog $id
	wm geometry .pref$ix $geo
    }
}

proc PreferencesDialogItem { frame id item width } {
    global pref
    incr pref(uid)
    set f [Widget_Frame $frame p$pref(uid) Preference {top fill}]
    Widget_Label $f label {left fill} \
	-text [PrefComment $item] -width $width
    
    if $pref(helpInOneWindow) {
	bind $f.label <1> [list PreferencesPaneHelp $id [PrefXres $item]]
    } else {
	bind $f.label <1> [list PreferencesItemHelp  %X %Y [PrefHelp $item]]
    }

    set default [PrefDefault $item]
    switch -regexp -- $default {
	^(ON|OFF)$	{
	    # This is a boolean
	    set varName [PrefVar $item]
	    Widget_CheckBut $f check "On" $varName {left}
	    $f.check config -command [list PrefBooleanFixup $f.check $varName]
	    PrefBooleanFixup $f.check $varName
	}
	"^CHOICE "	{
	    # This is a list of choices
	    foreach choice [lreplace $default 0 0] {
		incr pref(uid)
		Widget_RadioBut $f c$pref(uid) $choice [PrefVar $item] {left}
	    }
	}
	default	 {
	    # This is a string or numeric
	    global PrefEntry
	    Widget_Entry $f entry {left fill expand} -width 10
	    set PrefEntry([PrefVar $item]) $f.entry

	    set varName [PrefVar $item]
	    $f.entry insert 0 [uplevel #0 [list set $varName]]
	    Widget_BindEntryCmd $f.entry <Return> \
		[list PrefEntrySet %W $varName]
	}
    }
}
proc PrefBooleanFixup { check varName } {
    upvar #0 $varName var
    if {$var} {
	$check config -text On
    } else {
	$check config -text Off
    }
}
proc PreferencesItemHelp { x y text } {
    global pref
    catch {destroy .prefitemhelp}
    if {$text == {}} {
	return
    }
    set self [Widget_Toplevel .prefitemhelp "Item help" Itemhelp [expr $x+10] [expr $y+10]]
    wm transient .prefitemhelp .pref
    Widget_Message $self msg -text $text -aspect 1500
    bind $self.msg <1> {PreferencesNukeItemHelp .prefitemhelp}
    $pref(label) configure -text "Click on popup or another label"
    Visibility_Wait .prefitemhelp
}
proc PreferencesNukeItemHelp { t } {
    global pref
    $pref(label) configure -text ""
    destroy $t
}

proc PreferencesSave { {nodismiss {}} } {
    global pref PrefEntry
    set newstuff {}
    foreach id $pref(panes) {
	foreach item $pref($id,prefs) {
	    set varName [PrefVar $item]
	    set xresName [PrefXres $item]
	    if [info exists PrefEntry($varName)] {
		PrefValueSet $varName [$PrefEntry($varName) get]
	    }
	    set value [PrefValue $varName $xresName]
	    lappend newstuff [format "%s\t%s" *${xresName}: $value]
	}
    }
    Preferences_RewriteSection "Lines below here automatically added" "End Preferences State" $newstuff
    Preferences_Reset
    if {$nodismiss == {}} {
	PreferencesDismiss
    }
    Background_Preferences
}
proc Preferences_RewriteSection { boundary1 boundary2 newstuff } {
    global pref
    if [catch {
	set old [open $pref(userDefaults) r]
	set oldValues [split [string trimright [read $old] \n] \n]
	close $old
    }] {
	set oldValues {}
    }
    if [catch {open $pref(userDefaults).new w} out] {
	Exmh_Status "Cannot save in $pref(userDefaults).new: $out" warn
	return
    }
    set state "before"
    foreach line $oldValues {
	case $state {
	    "before" {
		if {[string compare $line "!!! $boundary1"] == 0} {
		    set state "inside"
		    puts $out "!!! $boundary1"
		    puts $out "!!! [exec date]"
		    puts $out "!!! Do not edit below here"
		    foreach item $newstuff {
			puts $out $item
		    }
		    puts $out "!!! $boundary2"
		} else {
		    puts $out $line
		}
	    }
	    "inside" {
		if {[string compare $line "!!! $boundary2"] == 0} {
		    set state "after"
		}
	    }
	    "after" {
		puts $out $line
	    }
	}
    }
    if {$state == "before"} {
	puts $out "!!! $boundary1"
	puts $out "!!! [exec date]"
	puts $out "!!! Do not edit below here"
	foreach item $newstuff {
	    puts $out $item
	}
	puts $out "!!! $boundary2"
    }
    close $out
    set new [glob $pref(userDefaults).new]
    set old [file root $new]
    if [catch {Mh_Rename $new $old} err] {
	Exmh_Status "Cannot install $new: $err"
	return
    }
}
proc Preferences_ReadSection { boundary1 boundary2 } {
    global pref
    if [catch {
	set old [open $pref(userDefaults) r]
	set oldValues [split [string trimright [read $old] \n] \n]
	close $old
    }] {
	set oldValues {}
    }
    set state "before"
    set results {}
    foreach line $oldValues {
	case $state {
	    "before" {
		if {[string compare $line "!!! $boundary1"] == 0} {
		    set state "inside"
		}
	    }
	    "inside" {
		if {![regexp {^!!!} $line]} {
		    lappend results $line
		}
		if {[string compare $line "!!! $boundary2"] == 0} {
		    break
		}
	    }
	}
    }
    return $results
}
proc Preferences_Reset { {id_in {}} } {
    global pref
    # Re-read user defaults
    option clear
    PreferencesReadFile $pref(appDefaults) startup
    PreferencesReadFile $pref(localDefaults) 50
    PreferencesReadFile $pref(userDefaults) user
    # Now set variables
    if {$id_in == {}} {
	set id_in $pref(panes)
    } else {
	set id_in [list $id_in]
    }
    foreach id $id_in {
	foreach item $pref($id,prefs) {
	    set varName [PrefVar $item]
	    set xresName [PrefXres $item]
	    set xresval [option get . $xresName {}]
	    if {$xresval != {}} {
		set default $xresval
	    } else {
		set default [PrefDefault $item]
	    }
	    switch -regexp -- $default {
		^ON$		{PrefValueSet $varName 1}
		^OFF$		{PrefValueSet $varName 0}
		"^CHOICE "	{PrefValueSet $varName [lindex $default 1]}
		default		{
				global PrefEntry
				if [info exists PrefEntry($varName)] {
				    set entry $PrefEntry($varName)
				    $entry delete 0 end
				    $entry insert 0 $default
				}
				PrefValueSet $varName $default
		}
	    }
	}
    }
}
proc Preferences_Tweak { _varName } {
    # Change a single setting in the preferences database.
    # This assumes a preference value has been changes from outside the
    # preferences UI.
    global pref PrefEntry
    set done 0
    foreach id $pref(panes) {
	foreach item $pref($id,prefs) {
	    set varName [PrefVar $item]
	    if {[string compare $varName $_varName] == 0} {
		set xresName [PrefXres $item]
		upvar #0 $varName x
		if [info exists PrefEntry($varName)] {
		    # Update the preferences user interface.
		    $PrefEntry($varName) delete 0 end
		    $PrefEntry($varName) insert 0 $x
		}
		set done 1
		break
	    }
	}
	if {$done} break
    }
    if {! $done} {
	error "No resource associated with $_varName"
    }
    # Change one line
    if [catch {open $pref(userDefaults) r} old] {
	# No existing preferences, better save all of them
	PreferencesSave nodismiss
	return
    }
    if [catch {open $pref(userDefaults).new w} out] {
	Exmh_Status "Cannot save in $pref(userDefaults).new: $out" warn
	close $old
	return
    }
    foreach line [split [read -nonewline $old] \n] {
	if [regexp "^\\*$xresName:" $line] {
	    puts $out "*$xresName: $x"
	    set done 1
	} else {
	    puts $out $line
	}
    }
    close $old
    close $out
    set new [glob $pref(userDefaults).new]
    set old [file root $new]
    if [catch {Mh_Rename $new $old} err] {
	Exmh_Status "Cannot install $new: $err"
	return
    }
}
proc Preferences_Resource { _varName _rname _default } {
    set _rval [option get . $_rname {}]
    if {$_rval != {}} {
	PrefValueSet $_varName $_rval
    } else {
	PrefValueSet $_varName $_default
    }
}

proc PreferencesPaneHelp { id {gotoxres {}} } {
    global pref
    set ix [lsearch $pref(panes) $id]
    set top .prefhelplong$ix
    set t $top.t
    set numLines 8

    if [Exwin_Toplevel $top "Exmh '$id' Preferences Help" Help] {
	wm group $top .pref$ix
	Widget_AddBut $top.but help Help {PreferencesHelp}
	Widget_Label  $top.but label {left fill} -text "Help for '$id' Preferences"
	Widget_Text $top $numLines -setgrid true
	$t tag configure headings -underline 1
	$t insert end $id\n\n
	$t tag add headings 1.0 "end -2c"
	$t insert end $pref($id,text)\n\n\n
	foreach item $pref($id,prefs) {
	    PreferencesPaneHelpText $t $item
	}
	$t mark set help4_ 1.0
	$t configure -state disabled
    }

    # make as much help text visible
    $t see end
    $t see help4_$gotoxres
}
proc PreferencesPaneHelpText { t item } {
    set res [PrefXres $item] 
    set var [PrefVar  $item] 
    $t insert end [PrefComment $item]\n\n
    $t tag add headings "insert -2 line" "insert -1c"
    $t mark set help4_$res "insert -2 line"
    foreach line [split [PrefHelp $item] \n] {
	$t insert end \t$line\n
    }
    $t insert end "\n\ttk resource:  $res\n\ttcl variable: $var\n\n"
}
