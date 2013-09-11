if {$exmh(sourceHook) && [info command source-orig] ==  ""} {
    rename source source-orig
    proc source {args} {
	 global SourceHook
	 set result [uplevel 1 "source-orig $args"]]
	 set fn [file rootname [file tail [lindex $args end]]]
	 if [info exists SourceHook($fn)] {
	    if [catch {uplevel 1 $SourceHook($fn)} err] {
		Exmh_Status "Error in source hook for $fn: $err" warning
	    }
	 }
	 return $result
    }
}

# Scan users' exmh directory for files called xxx.patch
# Assume that xxx.patch is an extension/patch for xxx.tcl in the main
# Exmh source tree.
# (Better not use ".tcl" for a file extension because we want to hide the
# patches from auto_mkindex).

proc SourceHook_Init {} {
    global exmh SourceHook
    set patches [glob -nocomplain $exmh(userLibrary)/*.patch]
    foreach file $patches {
	set fn [file rootname [file tail $file]]
	Exmh_Debug "Arm Patch $fn for $file "
	set SourceHook($fn) [list source-orig $file]
    }
}

