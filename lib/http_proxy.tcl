# Default proxy selection

proc Http_Proxy {host} {
    global Http
    if {[info exists Http(server)] && [string length $Http(server)]} {
	if {![info exists Http(port)]} {
	    set Http(port) 8080
	}
	return [list $Http(server) $Http(port)]
    }
    return {}
}

