# seditQP
#
# Crude quoted-printable support for sedit
#
# Copyright (c) 1994 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc SeditInitMimeType { draft t } {
    # This is really lame.
    # The code from mime.tcl needs to be generalized so it can
    # reparse draft files.
    global sedit exmh
    set id $sedit($t,id)
    if {$exmh($id,action) == "dist"} {
	return
    }

    $t mark set cursor insert
    for {set i 1} {1} {incr i} {
	set line [$t get $i.0 $i.end]
	set len [string length $line]
	if [regexp -nocase {content-type:(.*)$} $line match type] {
	    return
	}
	if {$len == 0 || [regexp ^-- $line]} {
	    break
	}
    }
    SeditMsg $t "MIME type text/plain ; charset=$sedit(charset)"
    SeditMimeType text/plain promote
    $t mark set insert cursor
}

proc SeditFixupEncoding { draft t quote } {
    if [catch {open $draft} in] {
	SeditMsg $t $out
	error "Cannot read draft to quote it"
    }
    global mime
    if {[string length $mime(dir)] == 0} {
	SeditMsg $t "Metamail required to quote/encode text"
	error "Metamail required to quote/encode text"
    }
    if [catch {open $draft.new w} out] {
	close $in
	SeditMsg $t $out
	error "Cannot fix encoding: $out"
    }
    if {$quote} {
	SeditMsg $t "Quoting text"
	Exmh_Debug Quoting text
    } else {
	SeditMsg $t "8-bit encoding"
	Exmh_Debug 8-bit encoding
    }
    set state header
    set done 0
    set needCoder 0
    set type text
    set typeActive 0
    set boundaries {}
    for {set len [gets $in line]} {$len >= 0} {set len [gets $in line]} {
	if {$state == "header"} {
	    if [regexp -nocase content-transfer-encoding $line] {
		Exmh_Debug coding already done
		set done 1
	    }
	    if {[regexp "^\[ \t]" $line] && $typeActive} {
		append type $line
	    }
	    if [regexp -nocase {content-type:(.*)$} $line match type] {
		set typeActive 1
	    } else {
		set typeActive 0
	    }
	    if {$len == 0 || [regexp ^-- $line]} {
		set state body
		set params [split $type \;]
		set type [string tolower [string trim [lindex $params 0]]]
		Exmh_Debug type $type
		foreach sub [lrange $params 1 end] {
		    if [regexp {([^=]+)=(.+)} $sub match key val] {
			set key [string trim [string tolower $key]]
			set val [string trim $val \ \"]
			if {[string compare $key boundary] == 0} {
			    # push new boundary onto the stack
			    set boundaries [linsert $boundaries 0 $val]
			}
		    }
		}
		if {! $done && [regexp -nocase text $type]} {
		    set needCoder 1
		    Exmh_Debug needCoder $type
		}
	    }

	    if {$needCoder} {
		set savedLine $line
	    } else {
		if {$quote} {
		    puts $out [SeditQuoteHeader $line]
		} else {
		    puts $out $line
		}
	    }
	} else {
	    foreach b $boundaries {
		if [regexp ^--$b\(--\)?\$ $line match alldone] {
		    catch {close $encoder}
		    catch {unset encoder}
		    set type text
		    if {[string compare $alldone --] == 0} {
			# should pop boundary stack
			set done 1
		    } else {
			set state header
			set typeActive 0
			set type text
			set done 0
		    }
		    set needCoder 0
		    Exmh_Debug no coder $line
		}
	    }
	    if {$needCoder} {
		set needCoder 0
		Exmh_Debug coding
                puts $out "Mime-Version: 1.0"
		if {$quote} {
		    puts $out "Content-Transfer-Encoding: quoted-printable"
		    puts $out $savedLine
		    flush $out
		    if [catch {open "|$mime(encode) -q >@ $out" w} encoder] {
			SeditMsg $t $encoder
			close $in
			close $out
			error "Cannot run $mime(encode)"
		    }
		} else {
		    puts $out "Content-Transfer-Encoding: 8bit"
		    puts $out $savedLine
		}
	    }
	    if [info exists encoder] {
		puts $encoder $line
	    } else {
		puts $out $line
	    }
	}
    }
    catch {close $encoder}
    close $out
    close $in
    Mh_Rename $draft.new $draft
}
proc SeditQuoteHeader { line } {
    global sedit
    set newline {}
    set begin 1
    if [regexp {^([ 	]+)(.*)} $line match space value] {
	set newline $space
	set line $value
    } elseif [regexp {^([^: 	]+:[ 	]*)(.*)} $line match key value] {
	set newline $key
	set line $value
    }
    set hithit 0
    while {[string length $line] > 0} {
	if [regexp -indices {^([^][\(\)<>@,;:"/\?\.= 	]*)([][\(\)<>@,;:"/\?\.= 	]*)} $line match word special] {
	    set x [expr [lindex $special 1]+1]
	    set word [eval {string range $line} $word]
	    set special [eval {string range $line} $special]
	    if {[string length $special] == 0} {
		set line {}
	    } else {
		set line [string range $line $x end]
	    }
	    set hit 0
	    foreach char [split $word {}] {
		scan $char %c code
		if {$code > 127} {
		    set hit 1
		    Exmh_Debug Hit $code $char
		    break
		}
	    }
	    if {! $hit} {
		set hithit 0
		append newline $word $special
	    } else {
		append newline =?$sedit(charset)?Q?
		if {$hithit} {
		    append newline _
		}
		foreach char [split $word {}] {
		    scan $char %c code
		    if {$code > 127 || $char == "_" || $char == "=" || $char == {?}} {
			append newline [format =%X $code]
		    } else {
			append newline $char
		    }
		}
		append newline ?= $special
		set hithit 1
	    }
	} else {
	    Exmh_Debug Fail <$line>
	    append newline $line
	    set line {}
	}
    }
    return $newline
}
