#
# This is a hacked version of send that keeps the xhost list cleared out.
#

if {[info command tk-send] == ""} {
    rename send tk-send
    bind . <Destroy> {if {"%W" == "."} {rename tk-send {}}}
}

# This file is sourced from Background_Init,
# which both exmh and exmh-bg execute.
# Initial space defeats auto_mkindex

 proc send { args } {
    global errorInfo errorCode
    if [catch {eval tk-send $args} x] {
	if [string match "*X server insecure*" $x] {
	    catch {exec xhost} out
	    set retry 0
	    if [regexp disabled $out] {
		set retry 1
		catch {exec xhost -}
	    }
	    set cmd "exec xhost"
	    foreach host [lrange [split $out \n] 1 end] {
		set retry 2
		Exmh_Status "Removing $host from xhost list"
		lappend cmd -$host
	    }
	    if {$retry != 0} {
		if {$retry > 1} {
		    catch {eval $cmd}
		}
		if [catch {eval tk-send $args} x] {
		    return -code error -errorinfo $errorInfo -errorcode $errorCode
		} else {
		    return $x
		}
	    } else {
		return -code error -errorinfo $errorInfo -errorcode $errorCode
	    }
	} else {
	    return -code error -errorinfo $errorInfo -errorcode $errorCode
	}
    } else {
	return $x
    }
}

