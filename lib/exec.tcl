# exec.tcl
#
# wrapper around exec that caches location in your PATH.
# the built-in exec doesn't do this, so the directories on your
# path are constantly searched, which is silly for long lived processes.
#

if {[string length [info commands exec-orig]] == 0} {
    rename exec exec-orig
    trace variable env(PATH) w ExecCacheReset
}

proc Exec_Init {} {
    # Just to fault in this file.
}

proc exec {args} {
    global ExecCache env

# Caution:  Enabling the line below will cause PGP passphrases to be logged!
#    Exmh_Debug exec [join $args]

    if {![regexp {^( 	)*([^<>	 ]+)(.*)$} $args all x cmd rest]} {
	# auto-exec generates commands like:
	#	>&@stdout <@stdin /bin/ls
	return [eval {exec-orig} $args]
    }

    if {[info exists ExecCache($cmd)]} {
	if [catch {eval {exec-orig $ExecCache($cmd)} $rest} x] {
	    unset ExecCache($cmd)
	    return -code error $x
	}
	return $x
    } else {
	foreach dir [split $env(PATH) :] {
	    set path [file join $dir $cmd]
	    if {[file executable $path] && ![file isdirectory $path]} {
		if [catch {eval {exec-orig $path} $rest} x] {
		    return -code error $x
		}
		set ExecCache($cmd) $path
		return $x
	    }
	}
    }
    eval {exec-orig $cmd} $rest
}

proc ExecCacheReset {args} {
    global ExecCache env
    unset ExecCache
}
