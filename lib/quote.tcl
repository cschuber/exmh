# Quoting support for exmh.  These functions center around the
# writing of the quote file, which is a pseudo-copy of the message
# being replied to.  The quote file is usually read by the editor,
# sedit or other (I use XEmacs), and processed more completely.
#
# Originally written by Ben Escoto <bescoto@rice.edu>

proc Quote_Cleanup {} {
    global quote
    File_Delete $quote(filename)
}

proc Quote_MakeFile { folder msg } {
    global mhProfile quote mimeHdr

    Exmh_Debug "Quote_MakeFile"
    Quote_Cleanup

    if {!$quote(enabled)} {
	return;
    } elseif {[file isdirectory $quote(filename)]} {
	Exmh_Status "quote file is dir"
	return;
    } else {
	if {$quote(symlink)} {
	    if [catch {exec ln -s $mhProfile(path)/$folder/$msg $quote(filename)} err] {
		Exmh_Debug "Quote_MakeFile: $err"
	    }
	} else {
	    set file [open $quote(filename) w 0600]
	    Quote_General 0 $file
	    close $file
	    
	}
    }
}

# This function takes a part and decides which function to run on it.
proc Quote_General { part file } {
    global mimeHdr quote

    # This first part determines the function to call.
    foreach addType $quote(add) {
	if {[string match $addType $mimeHdr($part,type)]} {

	    foreach omitType $quote(omit) {
		if {[string match $omitType $mimeHdr($part,type)]} {
		    return
		}
	    }

	    set function [option get . quote_$mimeHdr($part,type) {}]
	    if {$function == ""} {
		if {[regexp {(.*)/\*} $addType {} begin]} {
		    set function \
			[option get . quote_$begin/default {}]
		} elseif {[regexp {\*/(.*)} $addType {} end]} {
		    set function \
			[option get . quote_default/$end {}]
		}

		if {$function == ""} {
		    set function Quote_Default
		}
	    }

	    break
	}
    }

    if {[info exist function] && ($function != "")} {
	$function $part $file
    }
}

proc Quote_Default { part file } {
    global mimeHdr

    if [catch {open $mimeHdr($part,file) r} infile] {
	return
    }
    while {[gets $infile line] >= 0} {
	puts $file $line
    }
    close $infile
}

proc Quote_Message { part file } {
    global mimeHdr quote

    if {!$mimeHdr($part,numParts)} {
	if {$quote(headers)} {
	    Quote_Default $part $file
	} else {
	    set infile [open $mimeHdr($part,file) r]
	    if {!$quote(headers)} {
		while {([gets $infile line] >= 0) &&
		       ([string length $line] != 0)} {
		   # skip headers
		}
	    }
	    while {[gets $infile line] >= 0} {
		puts $file $line
	    }
	    close $infile
	}
    } else {
	if {$quote(headers)} {
	    set infile [open $mimeHdr($part,file) r]
	    while {([gets $infile line] >= 0) &&
		   ([string length $line] != 0)} {
		puts $file $line
	    }
	    close $infile
	    puts $file ""
	}
	Quote_General $part=1 $file
    }
}


proc Quote_MultipartDefault { part file } {
    global mimeHdr

    for {set i 1} {$i <= ($mimeHdr($part,numParts) || 0)} {incr i 1} {
	Quote_General $part=$i $file
	puts $file ""
    }
}
	
proc Quote_MultipartSigned { part file } {
    Quote_General $part=1 $file
}

proc Quote_MultipartEncrypted { part file } {
    global mimeHdr

    if {[info exist mimeHdr($part,pgpdecode)] &&
	$mimeHdr($part,pgpdecode)} {
	Quote_General $part=2=1 $file
    }
}

proc Quote_AppPgp { part file } {
    global mimeHdr

    if {[info exist mimeHdr($part,numParts)]} {
	Quote_General $part=1 $file
    } elseif {([info exist mimeHdr($part,param,x-action)]) &&
	      ($mimeHdr($part,param,x-action) == "signclear")} {
	Quote_Default $part $file
    }
}
