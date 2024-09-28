proc Recoll_Startup {} {
    global recoll exwin

    set w .recoll
    if ![Exwin_Toplevel $w "Full Text Searching with Recoll" Recoll] {
        return
    }

    # build the gui
    wm minsize $w 200 200
    wm iconname $w "exmh Recoll"

    # add a link to the query expression manual
    set f $w.but
    Widget_AddBut $f manual "Manual" { URI_StartViewer "https://www.recoll.org/usermanual/usermanual.html#RCL.SEARCH.LANG" }
    pack $f.quit -side right -padx 2 -fill y
    Widget_Label $f info {top fillx} -textvariable recoll(info) -anchor w

    set f [Widget_Frame $w g Menubar {top fillx}]
    Widget_AddBut $f recoll "Search" Recoll_Search {left padx 2 filly}
    set recoll(searchButton) $f.recoll
    $f.recoll config -width 6

    # start with the default: all folders
    set recoll(searchrng) "all"

    Widget_Entry $f e {left fillx expand padx 2}  -textvariable recoll(search)
    Widget_BindEntryCmd $f.e <Key-Return> "$f.recoll invoke"
    Widget_RadioBut $f all "all" recoll(searchrng)
    Widget_RadioBut $f sub "subtree" recoll(searchrng)
    Widget_RadioBut $f cur "current" recoll(searchrng)

    # results list
    Widget_Frame $w results
    set t [Widget_Text $w.results 20 \
      -relief raised -borderwidth 2]
    # Set up tag for hyper link
    if {[winfo depth .] > 4} {
        # Colors as in Mosaic: blue3 and ?violetred3?
        Preferences_Resource recoll(anchorColor) anchorColor blue
        Preferences_Resource recoll(visitedAnchorColor) visitedAnchorColor "violet red"
        set recoll(hyper) [list -underline 1 -foreground $recoll(anchorColor)]
    } else {
        set fg [option get $t foreground Foreground]
        set bg [option get $t background Background]
        set recoll(hyper) [list -foreground $bg -background $fg]
    }
    append recoll(hyper) " -lmargin2 1i"  ;# wrap indent
    $t tag configure indent -lmargin2 10m -lmargin1 5m
    eval {$t tag configure hyper} $recoll(hyper)
    $t tag bind hyper <ButtonRelease-1> {
        Recoll_Hyper [%W get "@%x,%y linestart" "@%x,%y lineend"]
    }
    $t tag bind hyper <Enter> {set recoll(cursor) [lindex [%W config -cursor] 4] ; %W config -cursor tcross}
    $t tag bind hyper <Leave> {%W config -cursor $recoll(cursor)}

    bind $t <Destroy> {catch unset recoll(results)}
    set recoll(results) $t
}

proc Recoll_Search {} {
    global recoll mhProfile flist exmh env

    if [regexp -- "^\[  \]*\$" $recoll(search)] {
        set recoll(info) "Empty search string specified"
        bell
        return
    }

    set t $recoll(results)
    $t configure -state normal
    $t delete 1.0 end
    $t mark set insert 1.0
    $t configure -state disabled

    # mhprofile path is absolute, but recoll prefers relative for dir:xyz
    set relprefix $mhProfile(path)
    regsub "^$env(HOME)/" $mhProfile(path) "" relprefix

    set opts "-S mtime -NF \"url mtime title abstract author recipient filename mtype\" "
    if {$recoll(searchrng) == "all"} {
        append opts "dir:$relprefix"
    } elseif {$recoll(searchrng) == "subtree"} {
        append opts " dir:$relprefix/$exmh(folder)"
    } elseif {$recoll(searchrng) == "current"} {
        append opts " dir:$relprefix/$exmh(folder) -dir:$relprefix/$exmh(folder)/*"
    }
    set recoll(info) "Searching..."

    Exmh_Debug "recollq $opts $recoll(search)"
    if [catch {
        open "|$recoll(path)/recollq $opts $recoll(search)" r
    } x] {
        Exmh_Debug Recoll error $x
        set result $x
    } else {
        set recoll(result) {}
        fileevent $x readable [list RecollRead $x]
        set recoll(channel) $x
        tkwait variable recoll(eof)
        set result $recoll(result)
    }
    $t configure -state normal

    # recoll produces two lines of fixed headings; not sure where
    # the two trailing blank lines come from...
    set manylines [ lrange [split $result "\n"] 2 end-2 ]
    set rcount [llength $manylines ]

    if { $rcount > 0 } {
        for { set ridx 0 } { $ridx < [ llength $manylines ] } { incr ridx } {
            set oneres [split [string trim [ lindex $manylines $ridx ] ] " " ]
            for {set tidx 1} {$tidx < [llength $oneres]} {incr tidx 2} {
                lset oneres $tidx [string trim \
                                       [ encoding convertfrom utf-8 \
                                             [ binary decode base64 [ lindex $oneres $tidx ] ] ] ]
            }
            array set thisresult $oneres
            # date, please...and don't get confused by leading zeros or ,123456789, inputs...
            if { [ info exists thisresult(mtime) ] } {
                set thisresult(mtime) [ regsub -all {[^[:digit:]]} $thisresult(mtime) "" ]
                set thisresult(date) [clock format [ scan $thisresult(mtime) %d ]];
            }
            # report the filename only if it's not an email
            if { [ info exists thisresult(mtype) ] \
                     && ! [ string compare $thisresult(mtype) "message/rfc822" ] } {
                array unset thisresult "filename"
            }
            # and display the goodies
            regsub "^file://.*$mhProfile(path)/" $thisresult(url) "" justfolder
            $t insert end $justfolder
            $t tag add hyper "insert linestart" "insert lineend"
            $t insert end "\n"
            set showthese { date title abstract filename author recipient }
            foreach item $showthese {
                if [ info exists thisresult($item) ] {
                    $t insert end [ format "%s\t%s\n" "$item:" $thisresult($item) ];
                }
            }
            $t insert end "\n";
        }
    }
    $t yview 1.0
    $t configure -state disabled
    set recoll(info) "$rcount results"
}

proc RecollRead {in} {
    global recoll
    if [eof $in] {
        catch {close $in}
        set recoll(eof) 1
    } else {
        append recoll(result) [gets $in]\n
    }
}


proc Recoll_Hyper {hyper} {
    global recoll exmh

    if {![regexp {([^ ]+)/([0-9]+)} $hyper all folder msg]} return

    # show message
    if {[string compare $folder $exmh(folder)] != 0} {
        Folder_Change $folder [list Msg_Change $msg]
    } else {
        Msg_Change $msg
    }
}
