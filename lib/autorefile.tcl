# autorefile.tcl
#This is the 'auto-refile' feature; this emulates the mh-utility that
#I've used for years, which takes an existing message, and figures out an
#appropriate folder to file it in, i.e., a message with an address of
#host1!host2!someluser%host3@host4 should go in the folder +someluser .
#To avoid the problems associated with the foldername generated by an address
#of some-insipid-corporate-mailing-alias@big.corp.com, I personally use a
#'zoo' subdirectory, and ~/Mail/zoo/some-insipid-corporate-mailing-alias
#will be (soft) linked to something like ~/Mail/charlie; my auto-refile places
#the message in +zoo/some-insipid-corporate-mailing-alias, but I can still get
#to it via +charlie -- anyway, that's why the code below checks for a folder
#under ~/Mail/zoo as well as under ~/Mail; if you really wanted to use this,
#I suppose I should expand it so that it actually searches all subfolders rather
#than just 'zoo'.

# Credit: John Carroll <carroll@cs.sdsu.edu>

proc FolderAutoFind {pattern} {
    global exwin

    scan [$exwin(mtext) index end] %d numLines
    for {set i 1} {$i < $numLines} {incr i} {
	$exwin(mtext) mark set last $i.0
	if {[regexp -indices $pattern \
		[$exwin(mtext) get last "last lineend"] indices]} {
	    $exwin(mtext) mark set first "last + [lindex $indices 0] chars"
	    $exwin(mtext) mark set last "last + 1 chars + [lindex $indices 1] chars"
	    return [$exwin(mtext) get [$exwin(mtext) index first] \
		    [$exwin(mtext) index "first lineend"]]
	}
    }
}

proc FolderAutoParse {adrline} {
    # extract a username from a 'Return-path', 'From', or 'To' line.
    # the following also handles 'some cruft <real.address> more cruft'
    # turn 'From: a!B!C%d@e (some name)' into just 'a!b!c%d@e (some name)' :
    regsub -nocase {^To:[ 	]*|^From:[ 	]*|^Return-path:[ 	]*} \
	[string tolower $adrline] {} adrline0
    # turn 'a!b!c%d@e' (some name) into just 'a!b!c%d@e' :
    regsub -all "\\(.*\\)" $adrline0 {} adrline1
    # turn 'a!b!c%d@e' into just 'a!b!c' :
    regsub -all "\[%@>\].*" $adrline1 {} adrline2
    # turn 'a!b!c' into just 'c' :
    regsub -all ".*\[<!\]" $adrline2 {} adrline3
    # a 'To:' address might still be 'name1, name2, name3'; resolve to 'name1' :
    regsub -all {[/ ,].*} $adrline3 {} target
    return $target
}

proc Folder_AutoRefile {} {
    global env msg
    # find a header line with a username (that isn't our own username).

    Exmh_Status "Auto-refiling $msg(id)..."
    set target [FolderAutoParse [FolderAutoFind ^Return-path:] ]
    if [expr [string match $env(USER) $target]||[string match $target {}]] {
	set target [FolderAutoParse [FolderAutoFind ^From:] ]
    }
    if [expr [string match $env(USER) $target]||[string match $target {}]] {
	set target [FolderAutoParse [FolderAutoFind ^To:] ]
    }
    if [Folder_Target $target] {
	Msg_Move
    } else {
	if [Folder_Target zoo/$target] {Msg_Move}
    }
}

proc Folder_AutoTrash {m f} {
    global exmh msg
    if [expr [string match $msg(id) $m] && [string match $f $exmh(folder)] ] {
	set savetarget $exmh(target)
	set exmh(target) trash
	Msg_Move
	set exmh(target) $savetarget
    } else {
	Exmh_Status "replied-to $f/$m NOT moved (not current)" warn
    }
}
