############################################################################
# 
#  Insidious Mail DB
#
#-------------------
# Copyright 1996, Xerox Corporation.  All Rights Reserved.
# License is granted to copy, to use, and to make and to use derivative works for
# research and evaluation purposes, provided that the copyright notice and
# this license notice is included in all copies and any derivatives works and in
# all  related documentation.  Xerox grants no other licenses expressed or
# implied and the licensee acknowleges that Xerox have no liability for
# licensee's use or for any derivative works made by licensee. The Xerox
# names shall not be used in any advertising or the like without their written
# permission.
# This software is provided AS IS.
# XEROX CORPORATION DISCLAIMS AND LICENSEE
# AGREES THAT ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# NOTWITHSTANDING ANY OTHER PROVISION CONTAINED HEREIN, ANY LIABILITY FOR DAMAGES
# RESULTING FROM THE SOFTWARE OR ITS USE IS EXPRESSLY DISCLAIMED, INCLUDING
# CONSEQUENTIAL OR ANY OTHER INDIRECT DAMAGES, WHETHER ARISING IN CONTRACT, TORT
# (INCLUDING NEGLIGENCE) OR STRICT LIABILITY, EVEN IF XEROX CORPORATION
# IS ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
#---------
# This package saves the e-mail address of everyone you get mail from, and lets
# you send mail back with only a partial address.
#
# When you type part of an address in the To: or Cc: field, Ctrl-TAB will
# attempt to complete the address.
#
# The concept owes a lot to the Gnu Emacs package "BBDB" by Jamie Zawinski 
# (jwz@netscape.com) but this implementation is strictly my own.  Thanks, Jamie!
#
#
# A neat feature of the browser (and entry editor) is that you can pop up (a la Clip)
# the last message you got from that person.  Be careful, though; if that message was 
# deleted or the folder was packed since that message arrived, it will fail.
#
# I've been using this (or earlier versions) for about 2 years now and my database 
# is about 5000 entries; I find it EXTERMELY useful when I cannot quite remember the email
# address of that guy I got a message from 6 months ago and need to reply to, but
# I remember it was "Ted something".
#
# It takes a little while to load the browser window (at least for me, sorting 5000 
# strings and then inserting them into a listbox takes a while), but then it "stays"
# even if you dismiss it so it's not too painful.
#
# Enjoy; if you find this useful please let me know; if you make it better 
# please send me the code.
#
#   --Berry Kercheval, Xerox PARC, March 1996 (kerch@parc.xerox.com)
#########################################################################

#
# These variables control the setup
#
set addrVersion {$Revision$}

# Addr_debug, if ==1, enables printing messages while this stuff runs.
# Set Addr_debug 1 in your user.tcl before invoking Addr_Init to enable debug messages
if {0 == [info exists Addr_debug]} {
    set Addr_debug 0
}

#
# Addr_Init loads the database file at startup time, and arranges the 
# partial-address-expansion keybinding.
#
proc Addr_Init {} {
    global env
    global addrFile
    global homeDir
    global addr_list

    # addrFile is the name of the file the address database is kept in
    set addrFile "exmh_addrs"
    
    # homeDir is the directory the database is kept in.
    set homeDir "$env(HOME)/.exmh"

    # tell exmh about our preference items and initialize them
    Preferences_Add "Address Database" "These settings affect the behavior of the address database.
    See also the key binding for \"addrexpand\" that is set
    in the Bindings... dialog Simple Edit." {
        {
            addr_db(enabled)
            addressdbEnabled
            ON
            "Automatic address saving"
            "If set, From addresses are remembered and available in an address browser."
        }
        {
            addr_db(hideexcluded)
            addressdbHideExcluded
            ON
            "Hide excluded addresses"
            "If set, addresses excluded from the expansion process will not be displayed by the Address DB Browser."
        }
        {
            addr_db(checkpoint_on_folder_change) 
            addressdbFolderChangeCheckpoint
            ON
            "Checkpoint on Folder Change"
            "If set, Exmh will save your address file whenever you visit a new folder."
        }
        {
            addr_db(searchlist)
            addressdbSearchlist
            {Addr_FullNameMatch Addr_Lookup Alias_Lookup}
            "Expand methods to use"
            "A list of TCL procs, separated by spaces, which will be called sequentially to try to expand the address.  Valid choices are \"Addr_FullNameMatch\" to search full names, \"Addr_Lookup\" to search for mail addresses, and \"Alias_Lookup\" to search your MH/exmh alias list."
        }
        {
            addr_db(filter_regexp)
            addressdbFilterRegexp
            {}
            "Regular expression filter"
            "If set, addresses matching this regular expression pattern will not be saved in the database."
        }
        {
            addr_db(skip_folders)
            addressdbFoldersSkip
            {}
            "Folders to ignore"
            "A list of one or more folders separated by spaces.  Exmh will not save addresses from the mail in the folders in this list. An empty list will allow Exmh to add addresses from every folder.  Groups of folders may be specified using * as a wild card anywhere in a folder name."
        }
        {
            addr_db(filter_alternate_mailboxes) 
            addressdbFilterAltMailboxes
            ON
            "Ignore alternate mailboxes"
            "If set, addresses that match the names specified as \"Alternate mailboxes\" in your MH profile will not be saved."
        }
        {
            addr_db(key_force_save)
            addressdbForceSave 
            <Control-Tab>
            "Key to save an address"
            "Key which, if pressed, will cause the address from the current message to be stored regardless of any filtering specified.  This key is only active in the main exmh window so it may be the same as the \"Key to expand addresses\" without conflict.  Pressing this key stores an address in the database even if it would have been filtered (not stored) due to matching \"Regular expression filter\", \"Folders to ignore\", or one of your alternate mailboxes."
        }
        {
            addr_db(standard_address_format)
            addressdbStandardFormat
            ON
            "Use \"address (Full Name)\" Format"
            "If on, use \"address (Full Name)\" format for expanded addresses.  Otherwise, use \"Full Name <address>\" format."
        }
        {
            addr_db(remove_entries)
            addressdbRemoveEntries
            OFF
            "Remove Old Entries"
            "If on, remove old entries from the database"
        }
        {
            addr_db(remove_days)
            addressdbRemoveDays
            {}
            "Days Until Removal"
            "Number of days until inactive entry is removed"
        }
        {
            addr_db(remove_invalid_date)
            addressdbRemoveInvalidDate
            OFF
            "Remove Invalid Date"
            "If on, delete any entry with a non-null, but invalid date"
        }
    }

    #addr_db is an array used for keeping state.
    #make this an array from the get-go and set the default pref...
    global addr_db
    set addr_db(init) 1;  
    set addr_db(curmethod) 0
    set addr_db(laststring) ""
    set addr_db(lastfound) ""
    set addr_db(changed) 0
    set addr_db(filterstring) ""
    set addr_db(remove_entries) 0
    set addr_db(remove_days) ""
    set addr_db(remove_invalid_date) 0
    trace variable addr_db(hideexcluded) w Addr_Browse_Exclude_Change
    Addr_LoadDB
}
#
# Hook_MsgShow is called when exmh displays a message.  We parse out the 
# From: header and call Addr_Save to update the entry in the database.
#
proc Hook_MsgShowAddr {path headervar } {
    upvar $headervar header
    global addr_db

    set addr_db(last_seen) [list $path $header(0=1,hdr,from) $header(0=1,hdr,date)]
    if {! $addr_db(enabled)} {
        return
    }
    Addr_Save [MsgParseFrom $header(0=1,hdr,from)] $path \
            $header(0=1,hdr,from) 	$header(0=1,hdr,date)
}

#
# Hook_FolderChange is called when a new folder is visited.  Save the 
# database then too.
#
proc Hook_FolderChangeAddr {newfolder} {
    global addr_db

    if {$addr_db(changed) && $addr_db(checkpoint_on_folder_change)} {
		Addr_SaveFile
    }
}


#
# Hook_CheckPoint is called when exmh checkpoints its state.  Save the 
# database here.
#
proc Addr_CheckPoint {} {
	Addr_SaveFile
}

#####
#
# Address_Init and the address Hook procedures are moved to extrasInit.tcl
#
####

########################################################################
#
# This one is bound to a key of the user's choosing to force-save 
# the from address of the current message (info stored in last-seen by
# the Hook_MsgShow routine above.
#
proc Address_Save {} {
    global addr_db

    AddrDebug "Force save $addr_db(last_seen)"

    Addr_Save [MsgParseFrom [lindex $addr_db(last_seen) 1]] \
            [lindex $addr_db(last_seen) 0] \
            [lindex $addr_db(last_seen) 1] \
            [lindex $addr_db(last_seen) 2] \
            "force"
}
# SaveTo saves the current address on the to line
#
proc SaveTo { w } {
    global addr_db

    Exmh_Status "SaveTo: w=$w"
    set line [string trim [$w get {insert linestart} {insert lineend}]]
    ##  AddrDebug "  got line \"$line\""
    # Only allows expansion on addressable header lines.
    if [regexp -nocase {^(to: *|resent-to: *|cc: *|resent-cc: *|bcc: *|dcc: *)(.*)} $line t0 t1 t2] {
        ##  AddrDebug  "  matched! keep is \"$t1\", partial name=\"$t2\""
		if [regexp -indices ",?.*, *" $t2 t0] {
            set t0 [lindex $t0 end]
            ##  AddrDebug "got comma at $t0"
            set t3 [string range $t2 0 $t0]
            append t1 $t3
            set t2 [string range $t2 [expr $t0 + 1] end]
            ##  AddrDebug "  multi, will keep \"$t1\", new partial name=\"$t2\""
        }
        # Save address ($t2) 
        Addr_Save [MsgParseFrom $t2] "NEW" $t2 "NULL" "force"

    } else {
        Exmh_Status "Error in name expansion: not on To: field"
        return
    }
}

########################################################################
#
# These are the "real" database procs.
#

#
# This is "magically" executed when exmh is setting up 
# keystroke bindings for the main window
#
proc Addr_Bindings { w } {
    global addr_db
    if {$addr_db(key_force_save) != ""} {
        AddrDebug "binding for $w"
        Bind_Key $w $addr_db(key_force_save) {Address_Save ; break}
    }
}

#
# Addr_LoadDB does the real work to load the database file.
#
proc Addr_LoadDB { {ldmsg ""} } {
    global addr_db
    global addrFile
    global homeDir
    global addr_list

    AddrDebug "AddrDB: loading database..."
    catch {source $homeDir/$addrFile}
    set addr_db(changed) 0
    if {[array size addr_list] == 0} {
        set addr_list(noone@nowhere.nada.zip) 1; #null array, put in a dummy
    }
    AddrDebug "AddrDB: loading database...done."
    Addr_Browse_LoadListbox $ldmsg
}
#
# Addr_SaveFile saves the database into a unix file 
#
proc Addr_SaveFile { {force 0} } {
    global addr_list addr_db
    global addrFile
    global homeDir

    if {0 == $addr_db(changed) && 0 == $force} return

    Exmh_Status "Saving address database..."
    if {$addr_db(remove_days) == ""} {
        set expiration 0
     
    } else {
        set expiration [expr [clock seconds] - (60*60*24*$addr_db(remove_days))]
    }
    set fd [open "$homeDir/.exmh_addr_tmp" w]
    foreach i [array names addr_list] {
       if {[catch {if {$addr_db(remove_entries) == 1 &&
                       $addr_db(enabled) == 1 &&
                       $expiration > 0 &&
                       [lindex $addr_list($i) 1] != "" &&
                       [clock scan [lindex $addr_list($i) 1]] < $expiration} {
                      unset addr_list($i) 
                  } else {
                     puts $fd [list set addr_list($i) $addr_list($i)]
                  }}]!= 0} {
          if {$addr_db(remove_invalid_date)} {
             unset addr_list($i)
          } else {
             puts $fd [list set addr_list($i) $addr_list($i)]
          }
       }
    }
    close $fd
    #  the first time the address file won`t exist yet...
    if [file exists $homeDir/$addrFile] {
        Mh_Rename $homeDir/$addrFile $homeDir/$addrFile.bak
    }
    Mh_Rename $homeDir/.exmh_addr_tmp $homeDir/$addrFile 
    set addr_db(changed) 0
    Exmh_Status "Saving address database...done."
}

#
# Field level extract and set routines
#

proc Addr_Entry_IsExcluded {key} {
    global addr_list

    set excluded 0
    if [catch {set item $addr_list($key)} err] {
        Exmh_Status "Address DB: Addr_Entry_IsExcluded lookup error for $key"
    } else {
        if {1==[lindex $item 4]} { set excluded 1 }
    }
    return $excluded
}

proc Addr_Entry_SetExcluded {key} {
    global addr_list addr_db

    if [catch {set item $addr_list($key)} err] {
        Exmh_Status "Address DB: Addr_Entry_SetExcluded lookup error for $key"
    } else {
        if {5 == [llength $item]} {
            set addr_list($key) "[lrange $item 0 3] 1"
        } else {
            set addr_list($key) "$item 1"
        }
        set addr_db(changed) 1
    }
    return 
}

proc Addr_Entry_UnsetExcluded {key} {
    global addr_list addr_db

    if [catch {set item $addr_list($key)} err] {
        Exmh_Status "Address DB: Addr_Entry_UnsetExcluded lookup error for $key"
    } else {
        if {5 == [llength $item]} {
            set addr_list($key) [lrange $item 0 3]
            set addr_db(changed) 1
        }
    }
    return 
}

proc Addr_Entry_ToggleExcluded {key} {
    if [Addr_Entry_IsExcluded $key] {
        Addr_Entry_UnsetExcluded $key
    } else {
        Addr_Entry_SetExcluded $key
    }
}


# Format an address with full name.  The result may be either
#
#	address (full name)
# or
#	full name <address>
#
# depending on the state of the standard_address_format flag.
proc Addr_Entry_FormatForMail {key} {
    global addr_list addr_db

    if [catch {set item $addr_list($key)} err] {
        return $key
    }

    set fullname  [lindex $item 2]
    regsub ,$ $fullname {} fullname_less_comma
    if {0 == [string length "$fullname_less_comma" ]} {
        set formatted "$key"
    } else {
        if {$addr_db(standard_address_format)} {
            set formatted "$key ($fullname_less_comma)"
        } else {
            # If there are characters in the name that require quoting,
            # quote the string.
            if [string match {*[<>.,'*?]*} $fullname_less_comma] {
                set formatted "\"$fullname_less_comma\" <$key>"
            } else {
                set formatted "$fullname_less_comma <$key>"
            }
        }
    }
    
    return $formatted

}

proc Addr_Entry_FormatForListbox {key} {
    global addr_list

    if [catch {set item $addr_list($key)} err] {
        return $key
    }

    set fullname  [lindex $item 2]
    regsub ,$ $fullname {} fullname_less_comma
    if [Addr_Entry_IsExcluded $key] {
        set formatted [format "%-24.24s- <%s>" $fullname_less_comma $key ]
    } else {
        set formatted [format "%-25.25s <%s>" $fullname_less_comma $key ]
    }

    return $formatted
}

#
# Addr_Save updates the database entry when a new message is read.
#

proc Addr_Save {from path rawfrom date {forcesave "not"}} {
    global addr_db
    global addr_list
    global exmh
    global mhProfile

    if {[string compare $forcesave "force"] != 0} {
        if {$addr_db(skip_folders) != ""} {
            set filter_list [split $addr_db(skip_folders) " "]
            # AddrDebug "  folder filter list is \"$filter_list\""
            foreach i $filter_list {
                if {[string length $i] > 0} {
                    # AddrDebug "Matching \"$exmh(folder)\" for \"$i\""
                    if [string match $i $exmh(folder)] {
                        AddrDebug "  folder filter eliminated $exmh(folder)"
                        return
                    }
                }
            }
        }
        if {$addr_db(filter_alternate_mailboxes) != 0} {
            catch {unset filter_list}
            catch {
                set filter_list [split $mhProfile(alternate-mailboxes) ", "]
            }
            if [info exists filter_list] {
                # Filter out all of the user's alternate mailboxes
                # AddrDebug "alternate mailboxes \"$mhProfile(alternate-mailboxes)"
                set filter_list [split $mhProfile(alternate-mailboxes) ", "]
                # AddrDebug "  list \"$filter_list\""
                foreach i $filter_list {
                    if {[string length $i] > 0} {
                        if [string match $i $from] {
                            AddrDebug "  alternate mailbox filter eliminated $from"
                            return
                        }
                    }
                }
            }
        }
        if {$addr_db(filter_regexp) != ""} {
            # AddrDebug "filtering $addr_db(filter_regexp)"
            if [regexp -nocase -- $addr_db(filter_regexp) $from] {
                AddrDebug "  regexp filter eliminated $from"
                return
            }
        }
    }
    set addr_db(changed) 1
    set newentry 0
    if [info exists addr_list($from)] {
        Exmh_Status "Updating address \"$from\"."
        if {[string length [Addr_ParseFrom $rawfrom]] == 0} {
            set newone [list $path $date  \
					[lindex $addr_list($from) 2] $rawfrom [Addr_Entry_IsExcluded $from]]
        } else {
            set newone [list $path $date  \
					[Addr_ParseFrom $rawfrom] $rawfrom [Addr_Entry_IsExcluded $from]]
        }
    } else {
        Exmh_Status "Saving address \"$from\"."
        set newone [list $path $date  \
                [Addr_ParseFrom $rawfrom] $rawfrom] 
        set newentry 1
    }
    set addr_list($from) $newone
    if {$newentry} {
        # Gotta catch this in case there's no browser window
        catch {
            $addr_db(win) insert end [Addr_Entry_FormatForListbox $from]
        }
    }
}

#
# Addr_KeyExpand expands a partial address in response to a key binding
#
proc Addr_KeyExpand { w } {
    global addr_db

    AddrDebug "Addr_KeyExpand: w=$w $addr_db(searchlist)"
    set line [string trim [$w get {insert linestart} {insert lineend}]]
    ##  AddrDebug "  got line \"$line\""
    # Only allows expansion on addressable header lines.
    if [regexp -nocase {^(to: *|resent-to: *|cc: *|resent-cc: *|bcc: *|dcc: *)(.*)} $line t0 t1 t2] {
        # Save keyword that started the line for later
        set startline $t1
        ##  AddrDebug  "  matched! keep is \"$t1\", partial name=\"$t2\""
        if [regexp -indices ",?.*, *" $t2 t0] {
            set t0 [lindex $t0 end]
            ##  AddrDebug "got comma at $t0"
            set t3 [string range $t2 0 $t0]
            append t1 $t3
            set t2 [string range $t2 [expr $t0 + 1] end]
            ##  AddrDebug "  multi, will keep \"$t1\", new partial name=\"$t2\""
        }
        if {[string compare $addr_db(lastfound) $t2] != 0 \
                || $addr_db(curmethod) >= [llength $addr_db(searchlist)]} {
            Exmh_Status "Resetting start method"
            catch {destroy $w.addrs}
            set addr_db(expansion) {}
            set addr_db(curmethod) 0
            set addr_db(laststring) $t2
        } else {
            if {$addr_db(curmethod) != 0} {
            	set t2 $addr_db(laststring)
            }
        }
        foreach proc [lrange $addr_db(searchlist) $addr_db(curmethod) end] {
            incr addr_db(curmethod)
            Exmh_Status "$proc $t2"
			set result [busy $proc $t2]
			if {[string compare $result ""] == 0} continue
            if {[llength $result] == 1} {
                # unique match
                $w delete  {insert linestart} {insert lineend}
                $w insert insert [format "%s%s\n%s" $t1 [lindex $result 0] $startline]
                set addr_db(lastfound) [lindex $result 0]
                catch {destroy $w.addrs}
            } else {
                # must be multiple hits
                AddrDebug "  Multiple hits: $result"
                set addr_db(lastfound) $t2
                set new [AddrShowDialog $w $result]
                # if no selection is made, leave the string where it is
                if [ string compare $new "" ] {
                    set addr_db(lastfound) $new
                    $w delete  {insert linestart} {insert lineend}
                    $w insert insert [format "%s%s\n%s" $t1 $new $startline]
                }
            }
			break
        }
    } else {
        Exmh_Status "Error in name expansion: not on supported field"
        return
    }
}

proc Alias_Lookup {n} {
    global aliases
	Aliases_Load
	set t2 [string trim $n]
	if {[string length [array names aliases $t2]] == 0} {
		Exmh_Status "No match found for \"$t2\""
		return {}
	} {
		Exmh_Status "Found alias: \"$aliases($t2)\""
        if {1 == [llength $aliases($t2)] && \
            0 != [string compare "\{" [string range $aliases($t2) 0 0]] } {
            return [list [Addr_Entry_FormatForMail $aliases($t2)]]
        }
        # Note: cannot use Address_Entry_FormatForMail here since contents
        # of alias is too unpredicatble.  May be a list of names, may be 
        # a preformatted fullname and address.  So send it back as-is
		return $aliases($t2)
	}
}

proc Addr_FullNameMatch {n}  {
    global addr_list

    Exmh_Status "Matching on full names with $n..."
    set result {}
    set pat {}
    append pat [string trim $n]
    foreach i [ array names addr_list] {
        if {1 == [Addr_Entry_IsExcluded $i]} continue
        set elt $addr_list($i)
        set fn [lindex $elt 2]
        # puts stdout "matching against $fn (elt = $elt)"
        if [catch {set match [regexp -nocase -- $pat $fn t0]}] {
            Exmh_Status "Fullname expansion error: Invalid regexp \"$pat\""
            return {}
        }
        if {$match} {
            AddrDebug "   fullname match on $fn"
            lappend result "[Addr_Entry_FormatForMail $i]"
        }  
    }
    if {[llength $result] > 0} {
        return $result
    } else {
        Exmh_Status "Matching on full names with \"$pat\"...none found"
        return {}
    }
}

proc Addr_Lookup { n } {
    global addr_list

    AddrDebug "Addr_Lookup: looking for $n"
    if {[string compare $n ""] == 0} {
        Exmh_Status "Address expansion error: null string!"
        return {}
    }

    set result {}
    set pat {}
    append pat [string trim $n]
    AddrDebug "  using pattern \"$pat\""

    foreach i [array names addr_list] {
        if {1 == [Addr_Entry_IsExcluded $i]} continue
        set elt $addr_list($i)
        if [catch {set match [regexp -nocase -- $pat $i t0]}] {
            Exmh_Status "Address expansion error: Invalid regexp \"$pat\""
            return {}
        }
        if {$match} {
            AddrDebug "   match on $i"
            set fn [lindex $elt 2]
            lappend result "[Addr_Entry_FormatForMail $i]"
        }
    }

    AddrDebug "Addr_Lookup: result is $result"
    return $result
}


#
# Addr_ParseFrom takes a raw From: header and return the fullname.
# it should work on lines of the form:
#
## Berry Kercheval <kerch@parc.xerox.com>
## kerch@parc.xerox.com (Berry Kercheval)

proc Addr_ParseFrom { fromline } {
    #    AddrDebug "Addr_ParseFrom: working on $fromline"
    set line [string trim $fromline]

    # if it's "xxx <foo@bar>"...
    if [regexp {([^<]*)(<.*>)} $line t1 t2 t3] {
        #	AddrDebug "  Matched: ( $t1 )( $t2 )( $t3 )"
        set token [string trim $t2 ]
    } else {
        # nope, try foo@bar (xxx)
        #	AddrDebug "  Not xxx <foo@bar>, try foo@bar (xxx)"
        if [regexp {^([^\(]*)(\(.*\))[^\)]*$} $line t1 t2 t3] {
            #	    AddrDebug "  Matched: ( $t1 )( $t2 )( $t3 )"
            set token $t3
        } else {
            # none of the above, give up.
            set token {}
        }
    }
    
    #    AddrDebug "  result is $token"
    set token [string trim $token "\"()"]
    #    AddrDebug "  trimmed result is $token"
    return $token
}

#
# Debug support
#

proc AddrDebug { s {nonewline {}}} {
    global Addr_debug
    if {$Addr_debug == 1} {
        if {[string compare $nonewline ""] == 0} {
            puts stdout $s 
        } else {
            puts stdout $s nonewline
        }
    }
}

proc AddrShowDialog {w list} {
    global addr_db 

    catch {destroy $w.addrs}
    set f [frame $w.addrs -bd 4 -relief ridge]
    set l [listbox $f.lb -bd 4 -width 50 -height 10]
    bind $l <Any-Double-1> "\
            AddrShowDialogDone $f $l ;\
            break \
            "
    focus $w.addrs.lb
    foreach i $list {
        $l insert end $i
    }
    pack $f.lb -expand true -fill both
    frame $f.but -bd 10 -relief flat
    pack $f.but -expand true -fill both
    Widget_AddBut $f.but ok "Done" [list AddrShowDialogDone $f $l] {left filly}
    Widget_PlaceDialog $w $f
    tkwait window $f
    if [info exists addr_db(expansion)] {
    	Exmh_Status "returning $addr_db(expansion)"
    	return $addr_db(expansion)
    } else {
		return {}
    }
}

proc AddrShowDialogDone {f l} {
    global addr_db
    set result [$l curselection]
    if {[string compare $result ""] != 0} {
        set result [lindex $result 0]
        set name [$l get $result]
        AddrDebug "Selected: $result ($name)"
        set addr_db(expansion) $name
    } else {
        AddrDebug "Selected: <nothing>"
        set addr_db(expansion) ""
    }
    AddrDebug "selected $addr_db(expansion)"
    focus [winfo parent $f]
    catch {destroy $f}
}


proc Addr_Browse { {state normal} } {
    global exwin
    global addr_br 
    global addr_db 
    global addr_list
    global Addr_debug

    set t .addr_br
    set f .addr_br.but
    set ldmsg "Creating Address Browser..."
    if [Exwin_Toplevel .addr_br "Address DB Browser" Addr_Br] {
        # Reconfigure the Dismiss button created by Exwin_Toplevel
        $f.quit configure -takefocus {} -command {Exwin_Dismiss .addr_br}

        # Create the "Selected..." menu (initially disabled)
        set menu_sel [Widget_AddMenuB $f selmenu "Selected..." {right padx 1 filly} ]
        $f.selmenu configure -takefocus {} -state disabled
        set addr_db(selmenu) $f.selmenu
        Widget_AddMenuItem $menu_sel  "Mail To"           \
                { Addr_Browse_Selected MailTo } <Key-c>
        Widget_AddMenuItem $menu_sel  "Edit"           \
                { Addr_Browse_Selected Edit }
        Widget_AddMenuItem $menu_sel  "Delete"         \
                { Addr_Browse_Selected Delete } <Control-w>
        Widget_AddMenuItem $menu_sel  {Toggle Exclude} \
                { Addr_Browse_Selected Exclude } <Meta-x>
        Widget_AddMenuItem $menu_sel  {View Last Msg}  \
                { Addr_Browse_Selected ViewLastMsg }

        # Create the "Database..." menu
        set menu_db [Widget_AddMenuB $f dbmenu "Database..." {right padx 1 filly} ]
        $f.dbmenu configure -takefocus {}
        Widget_AddMenuItem $menu_db   "Save"   \
                { Addr_SaveFile 1 } <Meta-s>
        Widget_AddMenuItem $menu_db   "Reload" \
                { Addr_Browse_Reload } <Meta-r>
        Widget_AddMenuItem $menu_db   "Sort"   \
                { Addr_Browse_LoadListbox "Sorting database..." normal } <Meta-t>
        if { $Addr_debug == 1 }  {	Widget_AddBut $f ldsrc  "LdSrc"  { Addr_Load_Source } }

 	# Create the New button
        Widget_AddBut $f new   "New"   { Addr_Browse_New }

        # Finally, create the Help button
        Widget_AddBut $f help   "Help"   { Help AddrEdit }
        $f.help configure -takefocus {}

        # would be nice if the listbox was a set of coordinated list boxes,
        # one column for each field, with headings and options to pick which
        # to display and which to sort on.

        # Create the listbox and a scroll bar to help it
        set addr_db(win) [listbox $t.lb \
                -selectmode extended \
                -height 20 -width 65 \
                -relief sunken \
                -yscrollcommand [list $t.sb set] ]
        scrollbar $t.sb -orient vertical -command [list $addr_db(win) yview]

        # Create the filter/find entry field
        Addr_LabelledTextField $t.find Find 0  "set addr_db(filterstring) \[$t.find.entry get \]; Addr_Browse_LoadListbox {Finding...} normal"
        $t.find.entry insert 0 $addr_db(filterstring)

        # Mouse button bindings for the listbox
        bind $addr_db(win) <Any-Double-1>    {Addr_Browse_Selected Edit}
        bind $addr_db(win) <KeyRelease>      {Addr_Browse_TrackSel}
        bind $addr_db(win) <ButtonRelease>   {Addr_Browse_TrackSel}
        bind $addr_db(win) <Button-2>        {Addr_Browse_Selected Exclude}

        # Menu key accelerators for the toplevel, 
        # but don't do 'em if in the find entry field
        bind $t <Meta-x> {
            if {0 != [string compare "%W" ".addr_br.find.entry"]} {Addr_Browse_Selected Exclude}
        }
        bind $t <Key-c> {
            if {0 != [string compare "%W" ".addr_br.find.entry"]} {Addr_Browse_Selected MailTo}
        }
        bind $t <Control-w> {
            if {0 != [string compare "%W" ".addr_br.find.entry"]} {Addr_Browse_Selected Delete}
        }
        bind $t <Meta-s> {
            if {0 != [string compare "%W" ".addr_br.find.entry"]} {Addr_SaveFile 1}
        }
        bind $t <Meta-r> {
            if {0 != [string compare "%W" ".addr_br.find.entry"]} {Addr_Browse_Reload}
        }

        # Adjust packing and filling
        pack $t.find -side bottom -fill x
        pack $t.sb -side $exwin(scrollbarSide) -fill y
        pack $addr_db(win) -expand true -fill both
    }

    if {0 == [string compare "$state" "normal"]} { 
        Exmh_Status $ldmsg
    }

    # All built, now load up the listbox
    Addr_Browse_LoadListbox $ldmsg $state
    
    # Initial focus to the listbox so accelerators work.
    focus $addr_db(win)
    if {0 == [string compare "$state" "normal"]} { 
        Exmh_Status "$ldmsg done" 
    }
}

proc Addr_Browse_TrackSel {} {
    global addr_db

    catch {	;# windows may not exist
	if { 0 != [string length [$addr_db(win) curselection]] } {
	    $addr_db(selmenu) configure -state normal
	} else {
	    $addr_db(selmenu) configure -state disabled
	}
    }
}

proc Addr_Browse_LoadListbox { {ldmsg ""} {state normal}} {
    global addr_db addr_list

    if {![info exists addr_db(win)] ||
	![winfo exists $addr_db(win)]}  return

    if {[catch {regexp -nocase -- $addr_db(filterstring) {}} err]} {
	Exmh_Status $err	;# bad pattern
	return
    }

    $addr_db(win) delete 0 end

    if {0 == [string compare "$state" "normal"]} { 
        Exmh_Status "$ldmsg getting names..."
    }

    set l {}
    foreach i [array names addr_list] {
        if {$addr_db(hideexcluded) == 0 || [Addr_Entry_IsExcluded $i] == 0} {
            lappend l [Addr_Entry_FormatForListbox $i]
        }
    }

    if {[llength $l]} {
	if {0 == [string compare "$state" "normal"]} { 
	    Exmh_Status "$ldmsg sorting names..."
	}
	set l [lsort $l]
	set n 0
	set whiz [list | \\ - /]
	set w 0
	if {[string length $addr_db(filterstring)] > 0} {
	    foreach i $l {
		if [regexp -nocase -- $addr_db(filterstring) $i] {
			$addr_db(win) insert end $i
		}
		incr n
		if { 0==($n%100) } {
		    if {0 == [string compare "$state" "normal"]} { 
			Exmh_Status "$ldmsg inserting names... [lindex $whiz $w]"
		    }
		    set w [expr {($w+1)%4}]
		}
	    }    
	} else {
	    foreach i $l {
		$addr_db(win) insert end $i
		incr n
		if { 0==($n%100) } {
		    if {0 == [string compare "$state" "normal"]} { 
			Exmh_Status "$ldmsg inserting names... [lindex $whiz $w]"
		    }
		    set w [expr {($w+1)%4}]
		}
	    }    
	}
    }
    if {0 == [string compare "$state" "normal"]} { 
        Exmh_Status  "$ldmsg done"
        update idletasks 
    }
}

# Called by trace variable magic when user changes Show Excluded preference item
proc Addr_Browse_Exclude_Change {name element op} {
    global addr_db
    catch {Exmh_Debug Event addr_db win is $addr_db(win)}
    Addr_Browse_LoadListbox {} silently
    return
}

proc Addr_Browse_Clip {sel} {
	global addr_db addr_list mhProfile

    set victim [MsgParseFrom [$addr_db(win) get $sel]]
    set last [lindex $addr_list($victim) 0]

    # since there may be recursive folders, match the MH Path
    # off the front, the message number off the end and the rest must be the folder.
    set pat "($mhProfile(path))/(.+)/(\[0-9\]+)\$"

    if [regexp -- $pat $last match path folder msg] {
        Msg_Clip $folder $msg
    } else {
        Exmh_Status "ViewLastMsg cannot find $last"
    }
}

proc Addr_Browse_Reload {} {
    global addr_db addr_list

    set ldmsg "Reloading address database..."
    if $addr_db(changed) {

        if [Addr_Browse_ChangedDialog $addr_db(win)] {

            Exmh_Status $ldmsg
            unset addr_list
            Addr_LoadDB $ldmsg
            Exmh_Status "$ldmsg done."
        }  else {
            Exmh_Status "$ldmsg aborted."
        }
    } else { 
        Exmh_Status $ldmsg
        unset addr_list
        Addr_LoadDB $ldmsg
        Exmh_Status "$ldmsg done."
    }
}

proc Addr_Browse_ChangedDialog {w} {
    global addr_db
    set f [frame $w.addrch -bd 4 -relief ridge]
    Exmh_Status "$f"
    Widget_AddBut $f ok "Yes, this will lose all changes" "\
            set addr_db(changeresult) 1 ;\
            destroy $f " \
            left
    Widget_AddBut $f no "No, do not reload" "\
            set addr_db(changeresult) 0 ;\
            destroy $f " \
            right
    Widget_PlaceDialog $w $f
    tkwait window $f
    AddrDebug "Addr_Browse_ChangedDialog returns  $addr_db(changeresult)"
    return $addr_db(changeresult)
}

proc Addr_LabelledTextField { name label width command  } { 
    frame $name
    label $name.label -text $label -width $width -anchor w
    eval {entry $name.entry -relief sunken -width  50 } 
    pack $name.label -side left
    pack $name.entry -side right -fill x -expand true
    bind $name.entry <Return> "$command ; break"
    return $name.entry
}

# Interate across all selected items applying a command
proc Addr_Browse_Selected { { op Noop } } {
    global addr_db addr_list

    set to {} ; set sep ""

    foreach sel [lsort -decreasing -integer [$addr_db(win) curselection]] {

        switch $op {

	    MailTo {
		append to $sep[Addr_Entry_FormatForMail \
			[MsgParseFrom [$addr_db(win) get $sel]]]
		set sep ", "
	    }

            Edit {
                Addr_Browse_Edit $sel
            }

            Delete {
                set victim [MsgParseFrom [$addr_db(win) get $sel]]
                if [catch {unset addr_list($victim)} val] {
                    Exmh_Status "Address DB: can't delete: $val"
                } else {
                    set addr_db(changed) 1
                    # update browser window...
                    $addr_db(win) delete $sel
                    Exmh_Status "Address DB: Deleted $victim"
                }
            }

            Exclude {
                set victim [MsgParseFrom [$addr_db(win) get $sel]]
                Addr_Entry_ToggleExcluded $victim
                # update browser window...
                $addr_db(win) delete $sel
                if {$addr_db(hideexcluded) == 0 || [Addr_Entry_IsExcluded $victim] == 0} {
                    $addr_db(win) insert $sel [Addr_Entry_FormatForListbox $victim]
                }
            }

            ViewLastMsg {
                Addr_Browse_Clip $sel
            }

        }
    }
    if {[string length $to] > 0} {
	Msg_CompTo $to
    }

    Addr_Browse_TrackSel
}

proc Addr_Browse_Edit {sel} {
    global addr_db addr_list

    set victim [MsgParseFrom [$addr_db(win) get $sel]]
    if [catch {set item $addr_list($victim)} err] {
        Exmh_Status "Address DB: Addr_Browse_Edit lookup error for $victim"
        return
    }

    set name [lindex $item 2]
    set addr [lindex $item 3]
    set last [lindex $item 0]
    set date [lindex $item 1]
    set exclude [Addr_Entry_IsExcluded $victim]
    unset item

    set t .addr_ed
    set id 0
    for {set id 1} {$id < 21} {incr id} {
        AddrDebug "winfo exists $t$id is [winfo exists $t$id]"
        if [winfo exists $t$id] continue
        append t $id
        break
    }
    if [winfo exists $t] {
        Exmh_Status "Too many editors open, close one or more and try again"
        return
    }
    if [Exwin_Toplevel $t "Address DB editor" Addr_Ed] {

        set f $t.but

        $t.but.quit configure -text Cancel -command "Addr_Edit_Dismiss $t"
        $t configure -width 500

        Widget_AddBut $f save   "Save"            "Addr_Edit_Save $t $sel"
        Widget_AddBut $f delete "Delete"          "Addr_Edit_Delete $t $sel"
        Widget_AddBut $f last	"ViewLastMsg"	  "Addr_Browse_Clip $sel"
        set e [Widget_AddBut $f ignore	"Exclude" "Addr_Edit_Exclude $t $sel"]

        set n [Addr_LabelledTextField $t.name		"Full Name"	12 "Addr_Edit_Save $t $sel" ]
        set a [Addr_LabelledTextField $t.address	"Address"	12 "Addr_Edit_Save $t $sel" ]
        set l [Addr_LabelledTextField $t.lastMsg	"Last Message"	12 "Addr_Edit_Save $t $sel" ]
        set d [Addr_LabelledTextField $t.date		"Date"		12 "Addr_Edit_Save $t $sel" ]
        
        pack $t.name $t.address	 $t.lastMsg  $t.date

    }

    $n delete 0 end;    $n insert 0 $name
    $a delete 0 end;    $a insert 0 $addr
    $l delete 0 end;    $l insert 0 $last
    $d delete 0 end;    $d insert 0 $date
	
    if {$exclude == 1} {
       	$e config -text "Include"
        AddrDebug "$e config -text Include"
    } else {
       	$e config -text "Exclude"
        AddrDebug "$e config -text Exclude"
    }
}



proc Addr_Browse_New {} {
    global addr_db addr_list

    set t .addr_ed
    set id 0
    for {set id 1} {$id < 21} {incr id} {
        AddrDebug "winfo exists $t$id is [winfo exists $t$id]"
        if [winfo exists $t$id] continue
        append t $id
        break
    }
    if [winfo exists $t] {
        Exmh_Status "Too many editors open, close one or more and try again"
        return
    }
    if [Exwin_Toplevel $t "New DB address" Addr_Ed] {

        set f $t.but

        $t.but.quit configure -text Cancel -command "Addr_Edit_Dismiss $t"
        $t configure -width 500

        Widget_AddBut $f save "Save"      "Addr_New_Save $t"

        Addr_LabelledTextField $t.name    "Full Name" 12 "Addr_New_Save $t"
        Addr_LabelledTextField $t.address "Address"   12 "Addr_New_Save $t"

        pack $t.name $t.address
    }
}

proc Addr_New_Save {winname} {
    global addr_db addr_list

    set name [$winname.name.entry get]
    set addr [$winname.address.entry get]
    set last ""
    set date ""

    set index [MsgParseFrom $addr]
    # NEED TO STUFF new NAME into entry!
    set addr [format "%s <%s>" $name $index]
    Exmh_Status "Updating address \"$index\"."
    set addr_db(changed) 1
    set addr_list($index) [list $last $date  \
            [Addr_ParseFrom $addr] $addr] 

    # update browser window...
    $addr_db(win) insert end [Addr_Entry_FormatForListbox $index]

    # make it all go away so we can redo it next time.
    Addr_Edit_Dismiss $winname
}
  
  
proc Addr_Load_Source {}  {
    global env
    # HACK HACK HACK!!!
    source "~/.tk/exmh/addr.tcl"
}

########################################################################
#
# Address Editor Routines
#

proc Addr_Edit_Exclude {winname sel} {
    global addr_db addr_list

    set addr [$winname.address.entry get]

    set victim [MsgParseFrom $addr]
    Exmh_Status "Updating address \"$victim\"."
    Addr_Entry_ToggleExcluded $victim
    set exclude [Addr_Entry_IsExcluded $victim]

    # update browser window...
    $addr_db(win) delete $sel
    if {$addr_db(hideexcluded) == 0 || $exclude == 0} {
    	$addr_db(win) insert $sel [Addr_Entry_FormatForListbox $victim]
    }

    # make it all go away so we can redo it next time.
    Addr_Edit_Dismiss $winname
}

proc Addr_Edit_Save {winname sel} {
    global addr_db addr_list

    set name [$winname.name.entry get]
    set addr [$winname.address.entry get]
    set last [$winname.lastMsg.entry get]
    set date [$winname.date.entry get]

    set index [MsgParseFrom $addr]
    # NEED TO STUFF new NAME into entry!
    set addr [format "%s <%s>" $name $index]
	Exmh_Status "Updating address \"$index\"."
    set addr_db(changed) 1
    set addr_list($index) [list $last $date  \
            [Addr_ParseFrom $addr] $addr] 

    # update browser window...
    $addr_db(win) delete $sel
    $addr_db(win) insert $sel [Addr_Entry_FormatForListbox $index]

    # make it all go away so we can redo it next time.
    Addr_Edit_Dismiss $winname
}

proc Addr_Edit_Delete { winname sel } {
    global addr_db addr_list

    set addr [$winname.address.entry get]
    set index [MsgParseFrom $addr]
    $addr_db(win) delete $sel

    unset addr_list($index)
    Addr_Edit_Dismiss $winname
}

proc Addr_Edit_Abort {} {
    global addr_db
    Addr_Edit_Dismiss
}

proc Addr_Edit_Dismiss { winname } {
    Exwin_Dismiss $winname
    destroy $winname
}
########################################################################
#
# done loading...
#
if {$Addr_debug} { puts stdout "done." }


