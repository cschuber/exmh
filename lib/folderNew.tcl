# folderNew.tcl
#
# New folder dialog
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc FolderDialogInner {path label cancelProc okProc message} {
    global mhProfile exwin exmh

   set t $path
   if [Exwin_Toplevel $path $label FolderDialog nomenu] {
	wm transient $t

	Widget_Message $t msg -aspect 400 -text $message
	set f [Widget_Frame $t name Rim]
	$f configure -bd 10
	set f [Widget_Frame $f rim LabeledEntry]
	Widget_Label $f label {left} -text "Folder Name:"
	set e [Widget_Entry $f name {right fill}]
	Widget_BindEntryCmd $e <Return> "$okProc $path $e"

	set f [Widget_Frame $t but Rim]
	$f configure -bd 10
	Widget_AddBut $f cancel "Cancel" [list $cancelProc $path] left
	Widget_AddBut $f ok "OK" [list $okProc $path $e] right
    } else {
	$t.msg config -text $message
	set e $path.name.rim.name
    }
    focus $e
}

proc Folder_New {} {
    global mhProfile exmh

    FolderDialogInner .newf "Create Folder" Exwin_Dismiss FolderNewCommit \
"Creating a new folder results in a new directory under $mhProfile(path).
Nested folders are allowed.
You need NOT put a + before the folder name.
@ is shorthand for the current folder, so
@foo => $exmh(folder)/foo"
}

proc FolderNewCommit { top entry } {
    global mhProfile exmh
    set name [string trim [$entry get]]
    if {[string length $name] == 0} {
	Exmh_Status "Please enter a folder name"
	return
    }
    if [regexp { } $name] {
	Exmh_Status "NO SPACES in folder names" error
	return
    }
    if [regexp {^[0-9]+$} $name] {
	Exmh_Status "No pure NUMBERS for folder names" error
	return	
    }
    if [regexp {^@(.*)} $name all newname] {
	set name $exmh(folder)
	if {[string length $newname] > 0} {
	    set name $name/$newname
	}
    }
    set components [split $name /]
    set path $mhProfile(path)
    foreach comp $components {
	append path /$comp
	if [file isdirectory $path] {
	    continue
	}
	if [file exists $path] {
	    Exmh_Status "Non-directory $path already exists" red
	    Exwin_Dismiss $top
	    return
	}
	if [catch {exec mkdir $path} msg] {
	    Exmh_Status "mkdir $path: $msg"
	    Exwin_Dismiss $top
	    return
	}
	if [info exists mhProfile(folder-protect)] {
	    exec chmod $mhProfile(folder-protect) $path
	}
    }
    Exmh_Status "Created folder $name" blue
    Flist_AddFolder $name
    Fcache_Folder $name
    Exwin_Dismiss $top
    return
}

proc Folder_Delete {} {
    global mhProfile exmh

    FolderDialogInner .delf "Delete Folder" Exwin_Dismiss FolderDelCommit \
"Only folders with no messages can be deleted.
You need NOT put a + before the folder name.
@ is shorthand for the current folder, so
@foo => $exmh(folder)/foo"
}

proc FolderDelCommit { top entry } {
    global mhProfile exmh
    set name [string trim [$entry get]]
    if {[string length $name] == 0} {
	Exmh_Status "Please enter a folder name"
	return
    }
    if [regexp {^@(.*)} $name all newname] {
	set name $exmh(folder)
	if {[string length $newname] > 0} {
	    set name $name/$newname
	}
    }
    set path $mhProfile(path)
    if [catch {Mh_Path $name new} nextid] {
	Exmh_Status "Cleaning up folder $name" blue
	Flist_DelFolder $name
	Fcache_FolderDiscard $name
	Glimpse_Delete $name
	Exwin_Dismiss $top
	return
    }
    if {[file tail $nextid] == 1} {
	File_Delete $path/$name/.xmhcache
	foreach nfsjunk [glob -nocomplain $path/$name/.nfs*] {
	    File_Delete $nfsjunk
	}
	if [catch {exec rmf +$name -nointeractive} err] {
	    Exmh_Status $err
	} else {
	    Exmh_Status "Deleted folder $name" blue
	    Flist_DelFolder $name
	    Fcache_FolderDiscard $name
	    Glimpse_Delete $name
	}
    } else {
	Exmh_Status "Still messages in +$name"
    }
    Exwin_Dismiss $top
    return
}

