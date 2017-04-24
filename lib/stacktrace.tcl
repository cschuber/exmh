proc stacktrace {} {
    set stack "Stack trace:\n"
    set distanceToTop [info level]
    for {set i 1} {$i < $distanceToTop} {incr i} {
	set callerlevel [expr {$distanceToTop - $i}]
        set lvl [info level -$i]
        set pname [lindex $lvl 0]
	append stack "CALLER $callerlevel: $pname"
        foreach value [lrange $lvl 1 end] arg [info args $pname] {
            if {$value eq ""} {
                info default $pname $arg value
            }
            append stack " $arg='$value'"
        }
        append stack \n
    }
    return $stack
}
