# cutbuffer.tcl
#	Stub for missing cutbuffer command
#	The best thing to do is add the tkCutbuffer.c code to your wish.
#	However, if that is not done, then these stub routines mask
#	the missing functionality

proc cutbuffer {args} {
    global cut_priv
    if ![info exists cut_priv(init)] {
	set cut_priv(init) 1
	Exmh_Debug "cutbuffer command missing (add tkCutbuffer.c to wish)"
    }
    set op [lindex $args 0]
    set ix [lindex $args 1]
    switch -- $op {
	set {
	    set cut_priv($ix) [lindex $args 2]
	}
	get {
	    if ![info exists cut_priv($ix)] {
		error "cutbuffer $ix undefined"
	    } else {
		return $cut_priv($ix)
	    }
	}
	rotate {
	    if {$ix < 0} {
		# Popping
		for {set ix 0} {$ix < 7} {incr ix} {
		    set next [expr $ix+1]
		    if ![info exists cut_priv($next)] {
			set cut_priv($ix) {}
		    } else {
			set cut_priv($ix) $cut_priv($next)
		    }
		}
	    } else {
		for {set ix 7} {$ix > 0} {incr ix -1} {
		    set prev [expr $ix-1]
		    if ![info exists cut_priv($prev)] {
			set cut_priv($ix) {}
		    } else {
			set cut_priv($ix) $cut_priv($prev)
		    }
		}
	    }
	}
    }
    return {}
}
