# setmax - set the variable to the maximum of its current value
# or the value of the second argument
# return 1 if the variable's value was changed.
proc setmax {varName value} {
    upvar $varName var
    if {![info exists var] || ($value > $var)} {
	set var $value
	return 1
    } 
    return 0
}
# setmin - set the variable to the minimum of its current value
# or the value of the second argument
# return 1 if the variable's value was changed.
proc setmin {varName value} {
    upvar $varName var
    if {![info exists var] || ($value < $var)} {
	set var $value
	return 1
    } 
    return 0
}
# Assign a set of variables from a list of values.
# If there are more values than variables, they are ignored.
# If there are fewer values than variables, the variables get the empty string.
proc lassign {varList value} {
    if {[string length $value] == 0} {
	foreach var $varList {
	    uplevel [list set $var {}]
	}
    } else {
	uplevel [list foreach $varList $value { break }]
    }
}

# Delete a list item by value.  Returns 1 if the item was present, else 0
proc ldelete {varList value} {
    upvar $varList list
    if ![info exist list] {
	return 0
    }
    set ix [lsearch $list $value]
    if {$ix >= 0} {
	set list [lreplace $list $ix $ix]
	return 1
    } else {
	return 0
    }
}

# Recursive make directory
if {$tk_version < 4.2} {
proc makedir { pathname } {
    if {[file isdirectory $pathname]} {
	return [glob $pathname]	;# Handle ~
    } elseif {[file exists $pathname]} {
	error "Non-directory $pathname already exists."
    } else {
	# Recurse to create intermediate directories
	set parent [makedir [file dirname $pathname]]
	set pathname [file join $parent [file tail $pathname]]
	exec mkdir $pathname
	return $pathname
    }
}
} else {
proc makedir { pathname } {
    file mkdir $pathname
}
}

proc Visibility_Wait {win} {
    catch {tkwait visibility $win}
}
proc File_Delete {args} {
    global tcl_version
    if {$tcl_version >= 7.6} {
	foreach f $args {
	    if [file isdirectory $f] {
		error "Should not delete directories this way"
	    }
	    file delete -force $f
	}
    } else {
	if {[llength $args]} {
	    eval {exec /bin/rm -f} $args
	}
    }
}
