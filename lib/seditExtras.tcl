# seditExtras
#
# Extra functions for the edit
#
# Copyright (c) 1994 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.
#
#  Version 1.3
#
#  7/5/96 tlm
#  -	Replaced 1.1's code which checked "local" and system magic files
#	with code to check "local.magic," only.  ("file" doesn't set a
#	return code if it doesn't get match - it returns "data," which
#	lead to problems.)
#  -	Added application/x-interleaf.
#  7/11/96 tlm
#  -	Replaced "hostname" with "uname -n".
#  -	Added "filenameOrig" argument to "SeditTweakContentType".  Without
#	it, "exmh" appeared to strip the path from external file reference 
#	attachments when attempting to figure out content type.
#

proc SeditWhom { draft f t } {
    global tk_version sedit
    set parent [file root $f]
    if {[winfo exists $parent.whom]} {
	destroy $parent.whom
	return
    }
    # Do an unformatted save so Mh_Whom gets the right info
    set format $sedit($t,format)
    set sedit($t,format) Never
    if [catch {
	SeditSave $draft $t
	SeditDirty $t
    } err] {
	set sedit($t,format) $format
	SeditMsg $t $err
	return
    }
    set sedit($t,format) $format

    set id [file tail $draft]
    catch {Mh_Whom $id} result
    set lines [llength [split $result \n]]
    set f2 [Widget_Frame $parent whom {top fill}]
    set height [expr {$lines > 8 ? 8 : $lines}]
    set t2 [Widget_Text $f2 $height]
    $t2 configure -height $height	;# Widget_Text broken
    $t2 insert 1.0 $result
    $t2 config -state disabled
    if {$tk_version >= 3.3} {
	pack $f2 -before $f -side top
    } else {
	pack before $f $f2 top
    }
}
proc SeditSign { draft t {f ~/.signature} } {
    global sedit
    if {[catch {glob $f} sig] || [string length $f]==0} {
	return
    }
    set exec 0
    if [file executable $sig] {
	set sig "|$sig $sedit($t,isigc) $sedit($t,isigf) $draft"
	set exec 1
    } else {
	if ![file readable $sig] {
	    return
	}
    }
    global sedit
    if [catch {
	set in [open $sig]
	set signature [read $in]
	# check for 8bit characters in the signature
	set 8bit 0
	if [regexp "\[\x80-\xff\]" $signature] {
	    set 8bit 1
	}
	if {!$sedit($t,multi)} {
	    if ($sedit(sigDashes)) {
		$t insert $sedit(sigPosition) "\n-- \n"
	    } else {
		$t insert $sedit(sigPosition) \n\n
	    }
	    # check for 8bit characters in the signature
	    if $8bit {
		set sedit($t,8bit) 1
	    }
	    $t insert $sedit(sigPosition) $signature
	} else {
	    set type text/plain
	    if $8bit {
		append type "; charset=iso-8859-1"
	    }
	    $t mark set fileinsert [SeditAppendPart $type]
	    $t insert fileinsert \n
	    $t insert fileinsert $signature
	}
	close $in
    } err] {
	if $exec {
	    SeditMsg $t "Bogus execute permission on signature file?"
	    Exmh_Status "Check execute bit on signature file"
	} else {
	    SeditMsg $t $err
	    Exmh_Status $err
	}
    }
}
proc SeditSignIntelligent { draft t {f ~/.signature} } {
    global sedit intelligentSign
    global mhProfile

    set tmp_fmt $sedit($t,format)
    set sedit($t,format) Never
    set saveokay [SeditSave $draft $t {} 0]
    set sedit($t,format) $tmp_fmt

    set cmd {exec whom $draft}

    if {!$saveokay || [catch {eval $cmd} rcpts]} {
	Exmh_Status "Error finding recipients; using default signature $f"
    } else {
	regsub -all " at " $rcpts "@" rcpts
	regsub -all "(^|\n)(\[^@\n\]+(\n|\$))+" $rcpts "\\1" rcpts

	foreach domn $intelligentSign(domain) {
	    regsub -all "(^|\n)(\[^\n\]+$domn\[^\n\]*(\n|\$))+" $rcpts {} rcpts
	}

	if {[regexp {[a-zA-Z0-9]} $rcpts]} {
	    set f $intelligentSign(external)
	    Exmh_Status "Using external signature $f"
	} else {
	    set f $intelligentSign(internal)
	    Exmh_Status "Using internal signature $f"
	}
    }
    SeditSign $draft $t $f
}
proc SeditInsertFile { draft t file {newpart 0} {encoding {}} {type text/plain} {desc {}}} {
    global sedit mime quote
    if {$newpart < 0} {
	return
    }
    Exmh_Status "SeditInsertFile $file $type $desc"
    if ![file readable $file] {
	SeditMsg $t "Cannot read $file"
    } else {
	if {[regexp ^text $type]} {
	    if [catch {open $file r} in] {
		SeditMsg $t $in
		return
	    }
	    if [regexp "\[\x80-\xff\]" [read $in]] {
		set sedit($t,8bit) 1
	    }
	    close $in
	}
	set cmd ""
	set uuname [file tail $file]
	if ![regexp name= $type] {
	    append type " ; name=\"$uuname\""
	}
	switch -- $encoding {
	    base64 {   append cmd "| $mime(encode) -b " }
	    quoted-printable {   append cmd "| $mime(encode) -q " }
	    none {set encoding {}}
	    x-uuencode {   append cmd "| uuencode $uuname " }
	}
	if {[string length $cmd] == 0} {
	    set in [open $file]
	} else {
	    append cmd " < $file"
	    Exmh_Status $cmd
	    set in [open $cmd r]
	}
	if [$t compare insert <= hlimit] {
	    $t mark set insert "hlimit +1c"
	}
	if {$file == $quote(filename)} {
	    set inheaders 1
	    set quoted 0
	    while {[gets $in line] > -1} {
		if {! $inheaders} {
		    $t insert insert $sedit(pref,replPrefix)$line\n
		} else {
		    # This simple hack doesn't work for multiparts.
		    if [regexp -nocase {^content-transfer-encoding:.*quoted-printable} $line] {
			set quoted 1
			set sedit($t,8bit) 1
			if {$sedit($t,quote) < 0} {
			    set sedit($t,quote) 1
			}
		    }
		    if {[string length $line] == 0} {
			set inheaders 0
			if {$quoted} {
			    set tfile [Mime_TempFile decode]
			    if [catch {open $tfile w} out] {
				$t insert insert "Error: $out"
			    } else {
				puts -nonewline $out [read $in]
				close $out
				close $in
				if [catch {open "|$mime(encode) -q -u < $tfile"} in] {
				    $t insert insert "Error: $in"
				    focus $t
				    return
				}
			    }
			}
		    }
		}
	    }
	} else {
	    if {$newpart} {
		set ix [SeditMimeType $type]
		if {[string length $ix] == 0} {
		    return
		}
		set mark fileinsert
		$t mark set $mark $ix
		if {$desc != {}} {
		    $t insert $mark "Content-Description: "
		    set sel1 [$t index $mark]
		    $t insert $mark "$desc\n"
		    set sel2 [$t index "$mark -1 char"]
		    $t tag add sel $sel1 $sel2
		}
		if {$encoding != {}} {
		    $t insert $mark "Content-Transfer-Encoding: $encoding\n"
		}
		if {$mime(eudora)} {
		    if $mime(dosname) {
			set filename [Mime_EudoraFilename $file]
		    } else {
			set filename [file tail $file]
		    }
		    $t insert $mark \
		    "Content-Disposition: attachment; filename=\"$filename\"\n"
		}
		$t insert $mark \n
	    } else {
		set mark insert
	    }
	    $t insert $mark [read $in]
	}
	catch {close $in}
	catch {close $filein}
	if [info exists tfile] {
	    File_Delete $tfile
	}
	focus $t
	SeditDirty $t
    }
}
proc SeditCiteSelection { draft t } {
    global sedit address
    if [catch {selection get} line] {
	SeditMsg $t "No selection"
	return
    }

    # check for 8bit characters in the selection
    if [regexp "\[\x80-\xff\]" $line] {
	set sedit($t,8bit) 1
    }

    $t insert insert "\n$address said:\n"

    # Divide selection into groups separated by blank lines
    # Control-A is used as a pseudo-newline
    regsub -all "\n\n+" $line \x01 line

    set space ""
    set limit 70
    set cutoff 50

    regsub -all {]|[.^$*+|()\[\\]} $sedit(pref,replPrefix) {\\&} pattern
    foreach line [split $line \x01] {
	# Preserve line breaks that start with white space or the replPrefix
	regsub -all "\n(\[\ \t\n\]+)" $line \x01\\1 line
	regsub -all "\n$pattern" $line \x01 line
	# Eliminate leading replPrefix
	regsub  "^$pattern" $line "" line
	# Eliminate other line breaks
	regsub -all \n $line " " line

	foreach line [split $line \x01] {
	    while {[string length $line] > $limit} {
		set hit 0
		for {set c $limit} {$c >= $cutoff} {incr c -1} {
		    set char [string index $line $c]
		    if [regexp \[\ \t\n>/\] $char] {
			set hit 1
			break
		    }
		}
		if !$hit {
		    set c $limit
		}
		set newline [string trimright [string range $line 0 $c]]
		$t insert insert "$sedit(pref,replPrefix)$newline\n"
		set space \n
		incr c
		set line [string range $line $c end]
	    }
	    $t insert insert "$sedit(pref,replPrefix)$line\n"
	}
	$t insert insert $space
    }

}

proc Sedit_FormatParagraph { t } {
    global sedit address
    if [catch {$t index "sel.first linestart"} first] {
	set first [$t index "insert linestart"]
	set last [$t index "insert lineend"]
	while 1 {
	    set line [$t get $first "$first lineend"]
	    set len [string length $line]
	    if {$len == 0} {
		break
	    }
	    set first [$t index "$first - 1line"]
	    if {[regexp ^-- $line] || [$t compare $first <= hlimit]} {
		break
	    }
	}
	set first [$t index "$first + 1line"]
	while 1 {
	    set line [$t get "$last linestart" $last]
	    set len [string length $line]
	    if {($len == 0) || [regexp ^-- $line]} {
		set last [$t index "$last - 1line lineend +1char"]
		break
	    }
	    set nlast [$t index "$last + 1line lineend"]
	    if {[$t compare $nlast == $last]} {
		break
	    }
	    set last $nlast
	}
    } else {
	set last [$t index "sel.last lineend"]
    }
    set line [$t get $first "$last -1char"]
    set tags [$t tag names $first]
    $t delete $first $last
    $t mark set insert $first

    # Divide selection into groups separated by blank lines
    # Control-A is used as a pseudo-newline
    regsub -all "\n\n+" $line \x01 line

    set space ""
    set limit $sedit(lineLength)
    set cutoff 0

    # Escape Tcl specials
    regsub -all {]|[.^$*+|()\[\\]} $sedit(pref,replPrefix) {\\&} pattern
    foreach line [split $line \x01] {
	# Preserve line breaks that start with white space or the replPrefix
	regsub -all "\n(\[\ \t\n\]+)" $line \x01\\1 line
	regsub -all "\n$pattern" $line \x01 line
	# Eliminate other line breaks
	regsub -all " *\n" $line " " line

	$t insert insert $space
	set space \n

	foreach line [split $line \x01] {
	    while {[string length $line] > $limit} {
		set hit 0
		for {set c $limit} {$c >= $cutoff} {incr c -1} {
		    set char [string index $line $c]
		    if [regexp \[\ \t\n>/\] $char] {
			set hit 1
			break
		    }
		}
		if !$hit {
		    set c $limit
		}
		set newline [string trimright [string range $line 0 $c]]
		$t insert insert "$newline\n" $tags
		incr c
		set line [string range $line $c end]
	    }
	    $t insert insert "$line\n" $tags
	}
    }
    $t mark set insert "insert -1char"

}

proc SeditInsertFileDirect { draft t } {
    global sedit
    set name [FSBox "Select file name"]
    if {$name != ""} {
	if [file readable $name] {
	    # check for 8bit characters in the file
	    catch {
		set in [open $name]
		if [regexp "\[\x80-\xff\]" [read $in]] {
		    set sedit($t,8bit) 1
		}
		close $in
	    }
	    SeditInsertFile $draft $t $name
	} else {
	    SeditMsg $t "Cannot read $name"
	}
    }
}
proc SeditInsertFileDialog { draft t } {
    global sedit
    set name [FSBox "Select file name"]
    if {$name != ""} {
	if [file readable $name] {
	    set options [SeditFormatDialog $t $name]
	    eval {SeditInsertFile $draft $t $name} $options
	} else {
	    SeditMsg $t "Cannot read $name"
	}
    }
}
# Thanks to Anders Klemets, klemets@it.kth.se, for the message/external feature.
proc SeditInsertExternalDialog { draft t } {
    global sedit env
    set name [FSBox "(Optionally) Select file name"]
    set options [SeditExternalDialog $t $name]
    set tmpfname [Mime_TempFile extern]
    if [catch {open $tmpfname w} fp] {
	SeditMsg $t $fp
	return
    }
    puts $fp "Content-Type: $sedit($t,exttype)"
    # Construct content-id
    regsub -all " |:" [exec date] _ date
    puts $fp [format "Content-ID: <%s_%s@%s>\n" $env(USER) $date \
					[exec uname -n]]
    close $fp
    eval {SeditInsertFile $draft $t $tmpfname} $options
    File_Delete $tmpfname
}
proc SeditExternalDialog { t name } {
    global sedit
    catch {destroy $t.format}
    set f [frame $t.format -bd 2 -relief ridge]

    message $f.msg1 -text "Insert external file" -aspect 1000
    pack $f.msg1 -side top -fill both

    Widget_BeginEntries 15 30 [list SeditFormatNewPart $t $f 1]
    set sedit($t,desc) [file tail $name]
    Widget_LabeledEntry $f.e0 Description: sedit($t,desc)

    catch {exec uname -n} sedit($t,extsite)
    Widget_LabeledEntry $f.e1 Site: sedit($t,extsite)

    set sedit($t,extdirectory) [file dirname $name]
    Widget_LabeledEntry $f.e2 Directory: sedit($t,extdirectory)

    set sedit($t,extname) [file tail $name]
    Widget_LabeledEntry $f.e3 "File name" sedit($t,extname)
    Widget_BindEntryCmd $f.e3.entry <Return> \
	[list SeditTweakContentType sedit($t,extname) sedit($t,exttype) $name]

    SeditTweakContentType sedit($t,extname) sedit($t,exttype) $name
    Widget_LabeledEntry $f.e4 "Content-Type:" sedit($t,exttype)

    set sedit($t,trans-mode) image
    Widget_LabeledEntry $f.e5 "Transfer mode:" sedit($t,trans-mode)

    Widget_EndEntries

    message $f.msg -text "Access type?" -aspect 1000
    pack $f.msg -side top -fill both
    set b1 [frame $f.but1 -bd 10 -relief flat]
    set b3 [frame $f.but3 -bd 10 -relief flat]
    pack $b1 $b3 -side top

    set sedit($t,encoding) {}
    set sedit($t,compress) {}
    set sedit($t,newpart) 0
    set sedit($t,extaccesstype) local

    button $b3.plain -text "Cancel" -command [list SeditFormatNewPart $t $f -1]
    button $b3.newpart -text "OK" -command [list SeditFormatNewPart $t $f 1]
    pack $b3.plain $b3.newpart -side left -padx 3

    radiobutton $b1.local -text "Local file" -variable sedit($t,extaccesstype) -value LOCAL-FILE
    radiobutton $b1.anon -text "Anonymous FTP" -variable sedit($t,extaccesstype) -value ANON-FTP
    pack $b1.local $b1.anon -side left -padx 3

    $b1.local select

    Widget_PlaceDialog $t $f
    tkwait window $f

    if {$sedit($t,extaccesstype) == "LOCAL-FILE"} {
	set sedit($t,type) "message/external-body;\n\tname=\"$sedit($t,extdirectory)/$sedit($t,extname)\";\n\taccess-type=$sedit($t,extaccesstype)"
	if {[string length $sedit($t,extsite)] != 0} {
	    append sedit($t,type) ";\n\tsite=\"$sedit($t,extsite)\""
	}
    } else {
	set sedit($t,type) "message/external-body;\n\tname=\"$sedit($t,extname)\";\n\tsite=\"$sedit($t,extsite)\";\n\taccess-type=$sedit($t,extaccesstype);\n\tdirectory=\"$sedit($t,extdirectory)\";\n\tmode=\"$sedit($t,trans-mode)\""
    }

    return [list $sedit($t,newpart) $sedit($t,encoding) $sedit($t,type) $sedit($t,desc)]
}
proc SeditTweakContentType { nameVar contentVar filenameOrig } {
    global sedit
    upvar #0 $nameVar name
    upvar #0 $contentVar content
    if [catch {SeditGuessContentType $filenameOrig} content] {
	Exmh_Status $content
	set content $sedit(defaultType)
    }
}
proc SeditFormatDialog { t name } {
    global sedit
    set f [frame $t.format -bd 2 -relief ridge]

    if [catch {SeditGuessContentType $name} sedit($t,type)] {
	Exmh_Status $sedit($t,type)
	set sedit($t,type) "$sedit(defaultType); name=\"[file tail $name]\""
    }
    message $f.msg1 -text "File Insert [file tail $name]" -aspect 1000
    pack $f.msg1 -side top -fill both

    Widget_BeginEntries 13 30 [list SeditFormatNewPart $t $f 1]
    Widget_LabeledEntry $f.e1 "Content-Type:" sedit($t,type)

    set sedit($t,desc) [file tail $name]
    Widget_LabeledEntry $f.e2 "Description:" sedit($t,desc)
    Widget_EndEntries

    message $f.msg -text "Transfer encoding?" -aspect 1000
    pack $f.msg -side top -fill both
    set b1 [frame $f.but1 -bd 10 -relief flat]
    set b3 [frame $f.but3 -bd 10 -relief flat]
    pack $b1 $b3 -side top

    set sedit($t,encoding) {}
    set sedit($t,compress) {}
    set sedit($t,newpart) 0

    button $b3.plain -text "Cancel" -command [list SeditFormatNewPart $t $f -1]
    button $b3.newpart -text "OK" -command [list SeditFormatNewPart $t $f 1]
    pack $b3.plain $b3.newpart -side left -padx 3

    radiobutton $b1.none -text "None" -variable sedit($t,encoding) -value {}
    radiobutton $b1.base64 -text "Base64" -variable sedit($t,encoding) -value base64
    radiobutton $b1.quoted -text "QuotedPrintable" -variable sedit($t,encoding) -value quoted-printable
    radiobutton $b1.uu -text "X-uuencode" -variable sedit($t,encoding) -value x-uuencode
    pack $b1.none $b1.base64 $b1.quoted $b1.uu -side left -padx 3

#   Guess an appropriate content transfer encoding for this part,
#   based on recommendations in Appendix F of the MIME RFC.
    switch -glob -- $sedit($t,type) {
	text/plain		{ $b1.none select }
	text/*			{ $b1.quoted select }
	multipart/*		{ $b1.none select }
	message/*		{ $b1.none select }
	application/postscript	{ $b1.quoted select }
	application/*		{ $b1.base64 select }
	image/*			{ $b1.base64 select }
	audio/*			{ $b1.base64 select }
	video/*			{ $b1.base64 select }
	*			{ $b1.base64 select }
    }
    Widget_PlaceDialog $t $f
    tkwait window $f
    return [list $sedit($t,newpart) $sedit($t,encoding) $sedit($t,type) $sedit($t,desc)]
}
proc SeditFormatNewPart { t f {doit 0} } {
    global sedit
    set sedit($t,newpart) $doit
    destroy $f
}
proc SeditSpell { draft f t } {
    global tk_version sedit editor wish
    set parent [file root $f]
    if {[winfo exists $parent.spell]} {
	destroy $parent.spell
	return
    }
    # Do an unformatted save so spell gets the right info
    set path [Env_Tmp]/exmh.s[pid].[file tail $t]
    SeditSaveBody $t $path

    switch -- $sedit(spell) {
	ispell {set prog {exmh-async xterm -e ispell}}
	custom {set prog $editor(spell)}
	default {set prog spell}
    }
    if [string match exmh-async* $prog] {
	# exmh-async isn't really right
	# craft a wish script instead
	set script [Env_Tmp]/exmh.w[pid].[file tail $t]
	if [catch {open $script w} out] {
	    Exmh_Status $out
	    return 0
	}
	puts $out "wm withdraw ."
	puts $out "catch \{"
	puts $out "exec [lrange $editor(spell) 1 end] $path"
	puts $out "\}"
	puts $out [list send [winfo name .] [list SeditReplaceBody $t $path]]
	puts $out "exec rm -f $path"
	puts $out "exec rm -f $script"
	puts $out exit
	close $out
	exec $wish -f $script &
	return
    }
    # Display the results of the spell program
    catch {eval exec $prog {$path}} result
    catch {exec rm $path}

    set f2 [Widget_Frame $parent spell {top fill}]

    set lines [llength [split $result \n]]
    set height [expr {$lines > 8 ? 8 : $lines}]
    set t2 [Widget_Text $f2 $height]
    $t2 configure -height $height	;# Widget_Text broken
    $t2 insert 1.0 $result
    $t2 config -state disabled
    if {$tk_version >= 3.3} {
	pack $f2 -before $f -side top
    } else {
	pack before $f $f2 top
    }
}
proc Sedit_Find {draft t} {
    global sedit
    if [catch {selection get} string] {
	SeditMsg $t "Select a string first"
	return
    }
    # hack
    global find
    if ![info exists find(line)] {
	set find(line) {}
    }
    if ![info exists find(lasthit)] {
	set find(lasthit) {}
    }
    set sedit(searchWidget) $t
    set match [Find_Inner $string forw $find(line) [lindex [split [$t index end] .] 0] Sedit_FindMatch nofeedback]
    case $match {
	0 {
	    SeditMsg $t "Next search will wrap."
	}
	-1 {
	    SeditMsg $t "$string not found"
	}
	default {
	    SeditMsg $t $draft
	    $t mark set insert sel.first
	    focus $t
	}
    }
}
proc Sedit_FindMatch { L string } {
    global sedit
    return [FindTextMatch $sedit(searchWidget) $L $string]
}
proc SeditGuessContentType { filenameOrig } {
    global exmh mimeType sedit

    set filename [string tolower $filenameOrig]
    set type {}
    if [catch {set type [mailcap_guess_content_type $filename]} ] {
	if ![info exists mimeType] {
	    SeditLoadMimeTypes
	}
	if [regexp -- {^([1-9][0-9]*|@)$} [file tail $filename]] {
	    return message/rfc822
	}
	set suffix [file extension $filename]
	set newfilename [file rootname $filename]
	while {$newfilename != $filename} {
	    if [info exists mimeType($suffix)] {
		set type $mimeType($suffix)
	    }
	    set filename $newfilename
	    set suffix "[file extension $filename]$suffix"
	    set newfilename [file rootname $filename]
	}
    }
    if {[string length $type] == 0} {
	if {[string length [set type [Mime_Magic $filenameOrig]]] == 0} {
	    return $sedit(defaultType)
	}
    }
    return $type
}
proc SeditLoadMimeTypes {} {
    global exmh mimeType env mimetypes_default
    # A few defaults
    set mimeType(.au)  audio/basic
    set mimeType(.gif) image/gif
    set mimeType(.ps)  application/postscript
    set mimeType(.txt) text/plain
    SeditReadMimeTypes $exmh(library)/mime.types		;# depreciated
    SeditReadMimeTypes $exmh(library)/local.mime.types		;# depreciated
    SeditReadMimeTypes $mimetypes_default			;# new
    SeditReadMimeTypes $env(HOME)/.mime.types
    SeditReadMimeTypes $exmh(userLibrary)/user.mime.types
}
proc SeditReadMimeTypes {file} {
    global mimeType
    if [catch {open $file} in] {
	return
    }
    while {[gets $in line] >= 0} {
	if [regexp {^( 	)*$} $line] {
	    continue
	}
	if [regexp {^( 	)*#} $line] {
	    continue
	}
	if [regexp {([^ 	]+)[ 	]+(.+)$} $line match type rest] {
	    foreach item [split $rest] {
		if [string length $item] {
		    set mimeType(.$item) $type
		}
	    }
	}
    }
}

proc SeditCheckForIsigHeader { t hdrline } {
    # Check whether there's an existing X-Exmh-Isig-Folder or
    # X-Exmh-Isig-CompType header line
    if {[catch {set end [$t index hlimit]}] &&
	[catch {set end [$t index header]}]} {
	    set end end
    }
    set X [$t get 1.0 $end]
    if {![regexp -nocase "(^|\n)x-exmh-isig-$hdrline:\[ \t\]*(\[^\n\]*)\n" $X bin1 bin2 cont]} {
	return {}
    }
    return $cont
}
proc SeditSetIsigHeader { t hook svar evar } {
    global exmh sedit intelligentSign
    set cont [eval SeditCheckForIsigHeader $t $hook]
    if {$cont == {}} {
	set sedit($t,$svar) $exmh($evar)
	if {$intelligentSign(showhdrs)} {
	    $t insert 1.0 "X-Exmh-Isig-$hook: $sedit($t,$svar)\n"
	}
    } else {
	set sedit($t,$svar) $cont
	if {!$intelligentSign(showhdrs)} {
	    if {[catch {set end [$t index hlimit]}] &&
		[catch {set end [$t index header]}]} {
		    set end end
	    }
	    for {set spos [$t search -regexp -nocase "^x-exmh-isig-$hook:.*\$" 1.0 $end]} {$spos != {}} {} {
		set sidx [$t index $spos]
		regexp {([0-9]*)\..*} $sidx bin1 line
		incr line
		$t delete $spos $line.0
		set spos [$t search -regexp -nocase "^x-exmh-isig-$hook:.*\$" 1.0 $end]
	    }
	}
    }
}
proc SeditCheckForIsigHeaders { t } {
    global sedit
    set cont [SeditCheckForIsigHeader $t CompType]
    if {$cont != {}} {
	set sedit($t,isigc) $cont
    }
    set cont [SeditCheckForIsigHeader $t Folder]
    if {$cont != {}} {
	set sedit($t,isigf) $cont
    }
}
proc SeditSetIsigHeaders { t } {
    global exmh
    if {![info exists exmh(ctype)]} {
	set exmh(ctype) {unknown}
    }
    SeditSetIsigHeader $t CompType isigc ctype
    set exmh(ctype) {unknown}
    SeditSetIsigHeader $t Folder isigf folder
}

# proc SeditClip: Use Clip from Sedit as a previewer

proc SeditClip {draft t} {
    global mhProfile

    if [SeditIsDirty $t] {
        if ![SeditSave $draft $t] {
	    return 0
        }
	SeditDirty $t	;# force abort check
    }
    set id [SeditId $draft]
    if [regexp {^[0-9]+$} $id] {
	set f $mhProfile(draft-folder)
    } else {
	set f [file dirname $id]
	set id [file tail $id]
    }
    Msg_Clip $f $id
}

proc Sedit_Mailto { url } {
    global mhProfile sedit
    MhExec comp -nowhatnowproc
    Sedit_Start [Mh_Path $mhProfile(draft-folder) cur]
    regsub mailto: $url {} url
    SeditSetHeader $sedit(t) to $url 
}
# Run MHN now to format a message
proc SeditMHN {draft t} {
    global env sedit editor

    set format $sedit($t,format)
    set sedit($t,format) Never
# add these two clauses from SeditSend
    if {$sedit($t,mhn)} {
      SeditFixupMhn $draft $t
    }
    if {$sedit(iso)} {
      SeditFixupCharset $draft $t
    }
    if [catch {SeditSave $draft $t {} 0} err] {
	SeditMsg $t $err
	set sedit($t,format) $format
	return
    }
    set sedit($t,format) $format

    set env(mhdraft) $draft
    if [catch {exec $editor(mhn) $draft} err] {
	SeditMsg $t $err
    } else {
	if [catch {open $draft r} in] {
	    SeditMsg $t "Cannot open $draft"
	} else {
	    $t delete 1.0 end
	    SeditMimeReset $t
	    $t insert 1.0 [read $in]
	    close $in
	    SeditPositionCursor $t
	    SeditMimeParse $t
	}
    }
}
proc SeditExternalCmd { draft t cmd } {
    # Save message, process with external command, and reload
    # last argument to command will be draft file name.
    SeditSave $draft $t
    if [catch {eval exec $cmd $draft} err] {
	Exmh_Debug "$err while executing external command."
    } else {
	if [catch {open $draft r} in] {
	    SeditMsg $t "Cannot open $draft"
	} else {
	    $t delete 1.0 end
	    SeditMimeReset $t
	    $t insert 1.0 [read $in]
	    close $in
	    SeditPositionCursor $t
	    SeditMimeParse $t
	}
    }
}

