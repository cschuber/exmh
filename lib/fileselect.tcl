#
# fileselect.tcl --
# simple file selector.
#
# Mario Jorge Silva			          msilva@cs.Berkeley.EDU
# University of California Berkeley                 Ph:    +1(510)642-8248
# Computer Science Division, 571 Evans Hall         Fax:   +1(510)642-5775
# Berkeley CA 94720                                 
# 
#
# Copyright 1993 Regents of the University of California
# Permission to use, copy, modify, and distribute this
# software and its documentation for any purpose and without
# fee is hereby granted, provided that this copyright
# notice appears in all copies.  The University of California
# makes no representations about the suitability of this
# software for any purpose.  It is provided "as is" without
# express or implied warranty.
#


# names starting with "fileselect" are reserved by this module
# no other names used.
# Hack - FSBox is defined instead of fileselect for backwards compatibility


# this is the proc that creates the file selector box
# purpose - comment string
# defaultName - initial value for name
# cmd - command to eval upon OK
# errorHandler - command to eval upon Cancel
# If neither cmd or errorHandler are specified, the return value
# of the FSBox procedure is the selected file name.

# Added preferences support

proc fileselect_Init {} {
    global fileselect
    if [info exists fileselect(init)] {
	return
    }
    set fileselect(init) 1

    Preferences_Add "FS Box" \
"The file select box lets you scan the directory structure.
The FS box understands '~' and '~user' as shortcuts for your
or the 'user's home directory.  Furthermore it tries to
compelete a partial filename when you press the 'tab'." {
	{fileselect(bigDirHas) fileselectBigDirHas {32} {Suppress startup listing longer than} 
"FS box startup: Do not list a directory that has more than the here
given number of entries.  If the directory has more entries you could
press return to list them or enter a file/directory by hand."}
	{fileselect(dotsByDefault) fileselectDotsByDefault OFF {List .* files by default}
"Determines if dotfiles are listed by default. By default this is
OFF.  The file select box has a checkbutton 'List all' that allows
you to display the dotfiles if you want."}
	{fileselect(home) fileselectHome {} {Default startup directory}
"Defines which directory is listed on startup.  If empty the directory
exmh was started is used."}
    }
}

proc FSBox {{purpose "Select file:"} {defaultName ""} {cmd ""} {errorHandler ""}} {
    global fileselect
    global exwin

    regsub -all " +" $defaultName _ defaultName
    if $fileselect(dotsByDefault) {
	set fileselect(pattern) "{*,.*}"
    } else {
        set fileselect(pattern) "*"
    }
    if ![info exists fileselect(lastDir)] {
	if {$fileselect(home) == {}} {
	    set fileselect(lastDir) [pwd]
	} else {
	    set fileselect(lastDir) $fileselect(home)
	}
    }

    set w .fileSelect
    if [Exwin_Toplevel $w "Select File" FileSelect] {
	# path independent names for the widgets
	
	set fileselect(list) $w.file.sframe.list
	set fileselect(scroll) $w.file.sframe.scroll
	set fileselect(direntry) $w.file.f1.direntry
	set fileselect(entry) $w.file.f2.entry
	set fileselect(ok) $w.but.ok
	set fileselect(cancel) $w.but.quit
	set fileselect(msg) $w.label
	
	set fileselect(result) ""	;# value to return if no callback procedures
	
	# widgets
	Widget_Label $w label {top fillx pady 10 padx 20} -anchor w -width 24
	Widget_Frame $w file Dialog {left expand fill} -bd 10
	
	Widget_Frame $w.file f1 Exmh {top fillx}
	Widget_Label $w.file.f1 label {left} -text "Dir"
	Widget_Entry $w.file.f1 direntry {right fillx expand}  -width 30
	
	Widget_Frame $w.file sframe
	
	scrollbar $w.file.sframe.yscroll -relief sunken \
		-command [list $w.file.sframe.list yview]
	FontWidget listbox $w.file.sframe.list -relief sunken \
		-yscroll [list $w.file.sframe.yscroll set] -setgrid 1
        if {$exwin(scrollbarSide) == "left"} {
	    pack append $w.file.sframe \
		    $w.file.sframe.yscroll {left filly} \
		    $w.file.sframe.list {right expand fill} 
        } else {
	    pack append $w.file.sframe \
		    $w.file.sframe.yscroll {right filly} \
		    $w.file.sframe.list {left expand fill} 
	}
	Widget_Frame $w.file f2 Exmh {top fillx}
	Widget_Label $w.file.f2 label {left} -text Name
	Widget_Entry $w.file.f2 entry {right fillx expand}
	
	# buttons
	$w.but.quit configure -text Cancel \
		-command [list fileselect.cancel.cmd $w]
	
	Widget_AddBut $w.but ok OK \
		[list fileselect.ok.cmd $w $cmd $errorHandler] {left padx 1}
	
	Widget_AddBut $w.but list List \
		[list fileselect.list.cmd $w] {left padx 1}    
	Widget_CheckBut $w.but listall "List all" fileselect(pattern)
	$w.but.listall configure -onvalue "{*,.*}" -offvalue "*" \
		-command {fileselect.list.cmd $fileselect(direntry)}
	$w.but.listall deselect
	
	# Set up bindings for the browser.
	Widget_BindEntryCmd $fileselect(entry) <Return> \
		"$fileselect(ok) invoke"
	Widget_BindEntryCmd $fileselect(entry) <Control-c> \
		"$fileselect(cancel) invoke"
	Widget_BindEntryCmd $fileselect(direntry) <Return> \
		"fileselect.list.cmd %W"
	Widget_BindEntryCmd $fileselect(direntry) <space> \
		"fileselect.tab.dircmd"
	Widget_BindEntryCmd $fileselect(entry) <space> \
		"fileselect.tab.filecmd"
	Widget_BindEntryCmd $fileselect(direntry) <Tab> \
		"fileselect.tab.dircmd"
	Widget_BindEntryCmd $fileselect(entry) <Tab> \
		"fileselect.tab.filecmd"
	$fileselect(list) config -selectmode browse
	
	bind $fileselect(list) <Button-1> {
	    # puts stderr "button 1 release"
	    %W select set [%W nearest %y]
	    $fileselect(entry) delete 0 end
	    $fileselect(entry) insert 0 [%W get [%W nearest %y]]
	}
    
	bind $fileselect(list) <Key> {
	    %W select set [%W nearest %y]
	    $fileselect(entry) delete 0 end
	    $fileselect(entry) insert 0 [%W get [%W nearest %y]]
	}
    
	bind $fileselect(list) <Double-ButtonPress-1> {
	    # puts stderr "double button 1"
	    %W select set [%W nearest %y]
	    $fileselect(entry) delete 0 end
	    $fileselect(entry) insert 0 [%W get [%W nearest %y]]
	    $fileselect(ok) invoke
	}
    
	bind $fileselect(list) <Return> {
	    %W select set [%W nearest %y]
	    $fileselect(entry) delete 0 end
	    $fileselect(entry) insert 0 [%W get [%W nearest %y]]
	    $fileselect(ok) invoke
	}
    }
    set fileselect(text) $purpose
    $fileselect(msg) configure -text $purpose
    $fileselect(entry) delete 0 end
    $fileselect(entry) insert 0 [file tail $defaultName]

    set dir [file dirname $defaultName]
    if {"$dir" == "." && [info exists fileselect(lastDir)]} {
	set dir $fileselect(lastDir)
    }
    if [catch {pwd} fileselect(pwd)] {
	cd
	set fileselect(pwd) [pwd]
    }
    fileselect.cd $dir
    $fileselect(direntry) delete 0 end
    $fileselect(direntry) insert 0 $dir/

    $fileselect(list) delete 0 end
    $fileselect(list) insert 0 "Big directory:"
    $fileselect(list) insert 1 $dir
    $fileselect(list) insert 2 "Press Return for Listing"

    fileselect.list.cmd $fileselect(direntry) startup

    # set kbd focus to entry widget

    Exwin_ToplevelFocus $w $fileselect(entry)

    # Wait for button hits if no callbacks are defined

    if {"$cmd" == "" && "$errorHandler" == ""} {
	# wait for the box to be destroyed
	tkwait variable fileselect(result)

	set path $fileselect(result)
	set dir [file dirname $fileselect(result)]
	if {$dir == "."} {
	    set dir [pwd]
	}
	set fileselect(lastDir) $dir
	fileselect.cd $fileselect(pwd)
	return [string trimright [string trim $path] /]
    }
    fileselect.cd $fileselect(pwd)
    return ""
}

proc fileselect.cd { dir } {
    global fileselect
    if [catch {cd $dir} err] {
	fileselect.yck $dir
	cd
    }
}
# auxiliary button procedures

proc fileselect.yck { {tag {}} } {
    global fileselect
    $fileselect(msg) configure -text "Yck! $tag"
}
proc fileselect.ok {} {
    global fileselect
    $fileselect(msg) configure -text $fileselect(text)
}

proc fileselect.cancel.cmd {w} {
    global fileselect
    set fileselect(result) {}
    Exwin_Dismiss $w
}

proc fileselect.list.cmd {w {state normal}} {
    global fileselect
    set seldir [$fileselect(direntry) get]
    if {[catch {glob $seldir} dir]} {
	fileselect.yck "glob failed"
	return
    }
    if {[llength $dir] > 1} {
	set dir [file dirname $seldir]
	set pat [file tail $seldir]
    } else {
	set pat $fileselect(pattern)
	set dir [lindex $dir 0]
    }
    fileselect.ok
    update idletasks
    if [file isdirectory $dir] {
	fileselect.getfiles $dir $pat $state
	focus $fileselect(entry)
    } else {
	fileselect.yck "not a dir"
    }
}

proc fileselect.ok.cmd {w cmd errorHandler} {
    global fileselect
    set selname [$fileselect(entry) get]
    set seldir [$fileselect(direntry) get]

    if [string match /* $selname] {
	set selected $selname
    } else {
	if [string match ~* $selname] {
	    set selected $selname
	} else {
	    set selected [string trimright $seldir /]/$selname
	}
    }

    # some nasty file names may cause "file isdirectory" to return an error
    if [catch {file isdirectory $selected} isdir] {
	fileselect.yck "isdirectory failed"
	return
    }
    if [catch {glob $selected} globlist] {
	if ![file isdirectory [file dirname $selected]] {
	    fileselect.yck "bad pathname"
	    return
	}
	set globlist [list $selected]
    }
    fileselect.ok
    update idletasks

    if {[llength $globlist] > 1} {
	set dir [file dirname $selected]
	set pat [file tail $selected]
	fileselect.getfiles $dir $pat
	return
    } else {
	set selected [lindex $globlist 0]
    }
    if [file isdirectory $selected] {
	fileselect.getfiles $selected $fileselect(pattern)
	$fileselect(entry) delete 0 end
	return
    }

    if {$cmd != {}} {
	$cmd $selected
    } else {
	set fileselect(result) $selected
    }
    Exwin_Dismiss $w
}

proc fileselect.getfiles { dir {pat *} {state normal} } {
    global fileselect
    $fileselect(msg) configure -text Listing...
    update idletasks

    fileselect.cd $dir
    if [catch {set files [lsort [glob -nocomplain $pat]]} err] {
	$fileselect(msg) configure -text $err
	$fileselect(list) delete 0 end
	update idletasks
	return
    }
    switch -- $state {
	normal {
	    # Normal case - show current directory
	    $fileselect(direntry) delete 0 end
	    $fileselect(direntry) insert 0 [pwd]/
	}
	opt {
	    # Directory already OK (tab related)
	}
	newdir {
	    # Changing directory (tab related)
	    fileselect.cd $fileselect(lastDir)
	}
	startup {
	    # Avoid listing huge directories upon startup.
	    $fileselect(direntry) delete 0 end
	    $fileselect(direntry) insert 0 [pwd]/
	    if {[llength $files] > $fileselect(bigDirHas)} {
		fileselect.ok
		return
	    }
	}
    }

    # build a reordered list of the files: directories are displayed first
    # and marked with a trailing "/"
    if [string compare $dir /] {
	fileselect.putfiles $files [expr {($pat == "*") ? 1 : 0}]
    } else {
	fileselect.putfiles $files
    }
    fileselect.ok
}

proc fileselect.putfiles {files {dotdot 0} } {
    global fileselect

    $fileselect(list) delete 0 end
    if {$dotdot} {
	$fileselect(list) insert end "../"
	set dirnum 1
    } else {
        set dirnum 0
    }
    foreach i $files {
	catch {
	    if {[file isdirectory $i]} {
		if {"x$i" == "x."} continue
		$fileselect(list) insert $dirnum $i/
		incr dirnum
	    } else {
		$fileselect(list) insert end $i
	    }
	}
    }
}

proc FileExistsDialog { name } {
    set w .fileExists
    global fileExists
    set fileExists(ok) 0
    if [Exwin_Toplevel $w "File Exists"] {
	message $w.msg -aspect 1000
	pack $w.msg -side top -fill both -padx 20 -pady 20
	$w.but.quit config -text Cancel -command {FileExistsCancel}
	button $w.but.ok -text OK -command {FileExistsOK}
	pack $w.but.ok -side left
	bind $w.msg <Return> {FileExistsOK}
    }
    $w.msg config -text "Warning: file exists
$name
OK to overwrite it?"

    set fileExists(focus) [focus]
    focus $w.msg
    grab $w
    tkwait variable fileExists(ok)
    grab release $w
    Exwin_Dismiss $w
    return $fileExists(ok)
}
proc FileExistsCancel {} {
    global fileExists
    set fileExists(ok) 0
}
proc FileExistsOK {} {
    global fileExists
    set fileExists(ok) 1
}

proc fileselect.getfiledir { dir {basedir [pwd]} } {
    global fileselect

    set path [$fileselect(direntry) get]
    set returnList {}

    if {$dir != 0} {
	if {[string index $path 0] == "~"} {
	    set path $path/
	}
    } else {
	set path [$fileselect(entry) get]
    }
    if [catch {set listFile [glob -nocomplain $path*]}] {
	return  $returnList
    }
    set newdir "."
    foreach el $listFile {
	if {$dir != 0} {
	    if [file isdirectory $el] {
		lappend returnList [file tail $el]
	    }
	} elseif ![file isdirectory $el] {
	    lappend returnList [file tail $el]
	    set newdir [file dirname $el]
	}	    
    }
    if {[string compare $newdir "."] != 0} {
	$fileselect(direntry) delete 0 end
	$fileselect(direntry) insert 0 $newdir
    }
    
    return $returnList
}

proc fileselect.gethead { list } {
    set returnHead ""

    for {set i 0} {[string length [lindex $list 0]] > $i}\
	{incr i; set returnHead $returnHead$thisChar} {
	    set thisChar [string index [lindex $list 0] $i]
	    foreach el $list {
		if {[string length $el] < $i} {
		    return $returnHead
		}
		if {$thisChar != [string index $el $i]} {
		    return $returnHead
		}
	    }
	}
    return $returnHead
}
	
proc fileselect.expand.tilde { } {
    global fileselect

    set entry [$fileselect(direntry) get]
    set dir [string range $entry 1 [string length $entry]]

    if {$dir == ""} {
	return
    }

    set listmatch {}

    ## look in /etc/passwd
    if [file exists /etc/passwd] {
	if [catch {set users [exec cat /etc/passwd | sed s/:.*//]} err] {
	    puts "Error\#1 $err"
	    return
	}
	set list [split $users "\n"]
    }
    if {[lsearch -exact $list "+"] != -1} {
	if [catch {set users [exec ypcat passwd | sed s/:.*//]} err] {
	    puts "Error\#2 $err"
	    return
	}
	set list [concat $list [split $users "\n"]]
    }
    $fileselect(list) delete 0 end
    foreach el $list {
	if [string match $dir* $el] {
	    lappend listmatch $el
	    $fileselect(list) insert end $el
	}
    }
    set addings [fileselect.gethead $listmatch]
    if {$addings == ""} {
	return
    }
    $fileselect(direntry) delete 0 end
    if {[llength $listmatch] == 1} {
	$fileselect(direntry) insert 0 [file dirname ~$addings/]
	fileselect.getfiles [$fileselect(direntry) get]
    } else {
	$fileselect(direntry) insert 0 ~$addings
    }
}

proc fileselect.tab.dircmd { } {
    global fileselect

    set dir [$fileselect(direntry) get]
    if {$dir == ""} {
	$fileselect(direntry) delete 0 end
	    $fileselect(direntry) insert 0 [pwd]
	if [string compare [pwd] "/"] {
	    $fileselect(direntry) insert end /
	}
	return
    }

    if [catch {set tmp [file isdirectory [file dirname $dir]]}] {
	if {[string index $dir 0] == "~"} {
	    fileselect.expand.tilde
	}
	return
    }
    if {!$tmp} {
	return
    }
    set dirFile [fileselect.getfiledir 1 $dir]
    if ![llength $dirFile] {
	return
    }
    if {[llength $dirFile] == 1} {
	$fileselect(direntry) delete 0 end
	$fileselect(direntry) insert 0 [file dirname $dir]
	if [string compare [file dirname $dir] /] {
	    $fileselect(direntry) insert end /[lindex $dirFile 0]/
	} else {
	    $fileselect(direntry) insert end [lindex $dirFile 0]/
	}
	fileselect.getfiles [$fileselect(direntry) get] \
	    "[file tail [$fileselect(direntry) get]]$fileselect(pattern)" opt
	return
    }
    set headFile [fileselect.gethead $dirFile]
    $fileselect(direntry) delete 0 end
    $fileselect(direntry) insert 0 [file dirname $dir]
    if [string compare [file dirname $dir] /] {
	$fileselect(direntry) insert end /$headFile
    } else {
	$fileselect(direntry) insert end $headFile
    }
    if {$headFile == "" && [file isdirectory $dir]} {
	fileselect.getfiles $dir\
	    "[file tail [$fileselect(direntry) get]]$fileselect(pattern)" opt
    } else {
	fileselect.getfiles [file dirname $dir]\
	    "[file tail [$fileselect(direntry) get]]*" newdir
    }
}

proc fileselect.tab.filecmd { } {
    global fileselect

    set dir [$fileselect(direntry) get]
    if {$dir == ""} {
	set dir [pwd]
    }
    if {![file isdirectory $dir]} {
	error "dir $dir doesn't exist"
    }
    set listFile [fileselect.getfiledir 0 $dir]
#    puts $listFile
    if ![llength $listFile] {
	return
    }
    if {[llength $listFile] == 1} {
	$fileselect(entry) delete 0 end
	$fileselect(entry) insert 0 [lindex $listFile 0]
	return
    }
    set headFile [fileselect.gethead $listFile]
    $fileselect(entry) delete 0 end
    $fileselect(entry) insert 0 $headFile
    fileselect.getfiles $dir "[$fileselect(entry) get]$fileselect(pattern)" opt
}
