# fetch a url via a proxy server.  The Cern proxy server appears to
# handle http, ftp, wais, and gopher.
#   url:	The name of the url to fetch
#   command	The command to run when the fetch is complete
#   progress  A progress call-back to provide status information
#     it gets called with 3 args: <status> <bytes read> <bytes expected>

# This is the default global state

array set Http [list	\
	hunk	1024	\
	max_pending 5	\
	pending ""	\
	agent "SunLab's Tcl/Tk Editor $WebTk(version)"	\
	queue	{}	\
]

# only accept these types (This is usually ignored)
set Http(accept) {
	text/plain text/html   image/gif   image/jpeg   image/xbm
}

proc Http_SetProxy {win} {
    global Http
    DialogEntry $win .proxy "
Enter host name and port of your Http proxy server.
If you do not use a proxy server, clear the server field.
" HttpSetProxyOK [list [list server $Http(server)] [list port $Http(port)]]
}
proc HttpSetProxyOK {list} {
    global Http
    array set Http $list
    CheckPoint
}
proc HttpAgent {} {
    global Http
    return $Http(agent)
}
proc Http_CheckPoint {out} {
    global Http
    puts $out [list array set Http [list \
	server $Http(server) \
	port $Http(port) \
]]
}

proc Http_get {url {command #} {progress #}} {
	upvar #0 $url data
	set data(protocol) GET
	catch {unset data(query)}
	regexp {\?(.+)} $url x data(query)
	HttpGet $url $command $progress
}

# POST to ship form data

proc Http_post {url query {command {}} {progress {}}} {
	global Http
	upvar #0 $url data

	set data(query) $query
	set data(protocol) POST
	HttpGet $url $command $progress
}

# Use HEAD to just validate a URL.

proc Http_head {url {command {}}} {
	upvar #0 $url data

	set data(protocol) HEAD
	HttpGet $url $command
}

proc HttpGet {url {command #} {progress #}} {
	global Http
	upvar #0 $url data


	if {![info exists data(count)]} {
		set data(count) 0
	}

	if {![info exists data(url)] || [info exists data(query)] ||
	    ($data(protocol) != "HEAD" && $data(count) == 0 && \
		([lsearch $Http(queue) $url] < 0) &&
		([lsearch $Http(pending) $url] < 0))} {
		set data(url) $url
		set data(state) queued	;# internal state
		set data(requests) 1	;# number of times requested
		set data(count) 0		;# bytes retrieved so far
		set data(length) 0		;# expected size (bytes)
		catch {unset data(html)}	;# Nuke old page
		lappend data(command) $command	;# command to run on completion
		set data(progress) $progress	;# progress callback
		lappend Http(queue) $url
		after idle Http_poke 
	} else {
		incr data(requests)
		if {$data(state) == "done"} {
			HttpLog fetching existing url ($command)
			catch $command
		} elseif {$data(state) == "link"} {
			HttpLog fetching linked url ($data(link))
			Http_get $data(link) $command
		} else {
			HttpLog appending ($command) to ($data(command))
			lappend data(command) $command
		}
	}
	catch {eval $progress $data(state) $data(count) $data(length)}
	if [info exists data(state)] {
	    return $data(state)
	} else {
	    return {}
	}
}


# process an item on the Url Queue.  This gets automatically rescheduled
# when a fetch is complete.

proc Http_poke {} {
    global Http HttpHost
  
    if {$Http(queue) == ""} {
	return 0
    }

    if {[llength $Http(pending)] >= $Http(max_pending)} {
	after 2000 Http_poke
	return 0
    }

    # find the item on the head of the Q

    set url [lindex $Http(queue) 0]
    set Http(queue) [lrange $Http(queue) 1 end]
    lappend Http(pending) $url

    upvar #0 $url data

    # go ask for the url, and wait for the data

    set data(state) connecting
    set data(what) connect
    set port {}
    if ![regexp -nocase {(http|ftp)://([^/:]+)(:([0-9]+))?(.*)} $url x protocol host y port srvurl] {
	HttpLog Invalid url $url
	Http_kill $url
	return
    }
    if {[string length $port] == 0} {
	set port 80
    }
    if {$protocol == "http"} {
	# Callback to determine if a proxy is necessary
	lassign {proxy pport} [Http_Proxy $host]
	if [catch {
	    if [string length $proxy] {
		set sock [HttpConnect $proxy $pport $data(protocol) $url]
	    } else {
		set sock [HttpConnect $host $port $data(protocol) $srvurl]
	    }
	} err] {
	    HttpLog $err
	    Http_kill $url
	    return
	}
    } elseif {$protocol == "ftp"} {
	if [catch {set sock [FtpConnect $host 21]} err] {
	    HttpLog $err
	    Http_kill $url
	    return
	}
    }
    set data(socket) $sock
    set data(mime) {}
    set data(what) connected
    if {$protocol == "http"
	&& [catch {
  	    foreach type $Http(accept) {
		puts $sock "Accept: $type"
  	    }
  	    puts $sock "User-Agent: [HttpAgent]"
  	    puts $sock "Host: $host"
  	    if {$data(protocol) == "POST"} {
		HttpLog $data(query)
		puts $sock "Content-type: application/x-www-form-urlencoded"
		puts $sock "Content-length: [string length $data(query)]\n"
		puts $sock "$data(query)"
		puts $sock "\n"
  	    } else {
		puts $sock ""
  	    }
  	    flush $sock
  	    # Our translation is now lf because of our own output.   Reset it.
  	    fileevent $sock r [list Http_event $url]
	    fconfigure $sock -translation auto
	} err]} {
	# Connect really failed.
	HttpLog $err
	Http_kill $url
	return
    } elseif {$protocol == "ftp"} {
	global ftp

	set ftp(cmdSock) $sock
	if {![FtpSetConnectionInfo $url]} {
	    HttpLog "invalid URL for FTP: $url"
  	    Http_kill $url
  	    return
  	}
	fileevent $sock r [list Ftp_event $url]
    }

    catch {eval $data(progress) connecting 0 0}
    return 1
}

proc HttpConnect {server port cmd url} {
    HttpLog $server:$port $cmd $url HTTP/1.0
    set sock [socket $server $port]
    fconfigure $sock -blocking false
    puts $sock "$cmd $url HTTP/1.0"
    flush $sock
    return $sock
}

# got fileevent for this URL
# data(what) determines the current fetching state
#   connected		The first line is about to be received
#	header		Getting the mime header
#	body		getting the message body
#	file		getting the body into a file
#	error		no mime header, put entire text into message
#               This doesn't work for Pre HTTP/1.0 servers.

if {[info commands "unsupported0"] == "unsupported0"} {
    rename unsupported0 copychannel
}
if {[info commands "copychannel"] == ""} {
    proc copychannel {in out {size {}}} {
	if {$size == ""} {
	    return [fcopy $in $out]
	} else {
	    return [fcopy $in $out -size $size]
	}
    }
}

proc Http_event {url} {
    global Http 
    upvar #0 $url data

    if {![info exists data] || ![info exists data(socket)]} {
	return
    }
    if ![info exists data(count)] {
	set data(count) 0
    }
    set more 1
    switch $data(what) {
	connect -
	connecting -
	connected {
	    set more [HttpGetLine $data(socket) line]
	    HttpLog $line <$url>
	    if {[regexp {^HTTP/1\.[01] *(.*)} $line dummy data(http)]} {
		set data(what) header
	    } else {
		if {[regexp {([^:]+):[ 	]*(.*)}  $line dummy key value]} {
		    set data(what) header
		    HttpHeader $url $key $value
		} elseif {[regexp {<|>} $line]} {
		    # Looks like error document with no protocol header.
		    set data(http) "400 Error"
		    set data(html) $line
		    set data(what) body
		} else {
		    set data(message) $line
		    set data(html) {}
		    set data(what) error
		}
	    }
	}

	error {
	    if [catch {read $data(socket) $Http(hunk)} block] {
		catch {eval $data(progress) error $more 0}
		HttpLog "Read error on $url\n$block"
		Http_kill $url
		return
	    }
	    set more  [string length $block]
	    if {$more > 0} {
		append data(message) $block
		incr data(count) $more
		catch {eval $data(progress) error $data(count) $data(length)}
	    }
	}

	header {	
	    set more [HttpGetLine $data(socket) line]
	    if {$line == ""} {
		if {[info exists data(file)]} {
			# Divert remaining data into a file.
			# Turn off cr-lf translations to preserve all bits.
			set data(what) file
			fconfigure $data(socket) -translation lf
		} else {
			fconfigure $data(socket) -translation auto
			set data(what) body
		}
		return
	    }
	    if {![regexp {([^ :]+):[ 	]*(.*)}  $line dummy key value]} {
		return
	    }
	    HttpHeader $url $key $value
	    return
	}
	body {
	    if [catch {read $data(socket) $Http(hunk)} block] {
		catch {eval $data(progress) error $more 0}
		HttpLog "Read error on $url\n$block"
		Http_kill $url
		return
	    }
	    set more  [string length $block]
	    if {$more > 0 } {
		append data(html) $block
		incr data(count) $more
		catch {eval $data(progress) body $data(count) $data(length)}
	    }
	}
	file {
	    if [catch {copychannel $data(socket) $data(fd) $Http(hunk)} more] {
		HttpLog "Read error on $url\n$more"
		catch {eval $data(progress) error $more 0}
		Http_kill $url
		return
	    }
	    if {$more >= 0} {
		incr data(count) $more
		catch {eval $data(progress) file $data(count) $data(length)}
	    }
	} 
    }

    if {[info exists data(socket)] && [eof $data(socket)]} {
	catch {close $data(socket)}
	Http_depend $url
	unset data(socket)
	set data(state) done
	if {$data(what) == "file"} {
	    catch {close $data(fd)}
	    unset data(fd)
	    Cache_SetFile $url $data(file)
	}
	catch {eval $data(progress) done $data(count) $data(length)}
	foreach cmd $data(command) {
	    HttpLog $cmd
	    catch $cmd
	}
	set data(command) ""
	after idle Http_poke
	return 1
    }
}

proc HttpHeader {url key value} {
	upvar #0 $url data
	regsub "\r" $value {} value
	lappend data(mime) $key $value
	switch [string tolower $key] {
		content-length {
			set data(length) $value
		}
		location {
			UrlResolve $url value
			HttpLog "linking to $value"
			set data(link) $value
			set data(state) link
			catch {close $data(socket)}
			unset data(socket)
			Http_depend $url
			foreach i $data(command) {
				Http_get $value $i $data(progress)
			}
			set data(command) ""
			catch {eval $data(progress) linking $value 0}
			set data(progress) ""
			return
		}
		content-type {
			set data(type) $value
			if [regexp text/plain $value] {
				set data(html) {}
			} elseif {![regexp {text/html} $value]} {
				set data(file) [Cache_NewFile $data(url)]
				if {[catch {open $data(file) w 0600} data(fd)]} {
				    Exmh_Status "Cannot write to HTML cache directory"
				    Http_kill $data(url)
				} else {
				    HttpLog "using file $data(file)"
				    fconfigure $data(fd) -translation lf
				}
			}
		}
	}
}

# remove a url from the pending list

proc Http_depend {url} {
	global Http
	if {[set index [lsearch -exact $Http(pending) $url]] >=0} {
		set Http(pending) [lreplace $Http(pending) $index $index]
		return 1
	} else {
		return 0
	}
}

# stop fetching a url

proc Http_kill {url} {
	global Http
	upvar #0 $url data
	if {[info exists data(socket)]} {
		catch {close $data(socket)}
		unset data(socket)
		Http_depend $url
		set data(state) killed
		after idle Http_poke
	} elseif {[set pos [lsearch -exact $Http(queue) $url]] >=0} {
		lreplace $Http(queue) $pos $pos
	} else {
		Http_depend $url
	}
	catch {
	    set data(valid) complete	;# nudge tkwaiters
	    unset data
	}
}

proc Http_stop {} {
    global Http
    foreach url [concat $Http(pending) $Http(queue)] {
	Http_kill $url
    }
}

proc HttpGetLine {sock lineVar} {
    upvar $lineVar line
    set line {}
    if [catch {gets $sock line} n] {
	HttpLog $sock $n
	return 0
    }
    return $n
}
proc HttpTrace {} {
    global Http
    trace variable Http(queue) w HttpTraceQueue
    trace variable Http(pending) w HttpTracePending
    set Http(listbox) .httpbox
    set f $Http(listbox)
    if ![winfo exists $f] {
	toplevel $f 
	wm group $f .
	wm title $f "HTTP Queue"
	wm iconname $f "HTTP Queue"
	label $f.label -text "HTTP Queue"
	button $f.quit -text "Dismiss" -command {destroy .httpbox}
	label $f.status -text "(status line)" -textvar Http(dbg_status)
	label $f.lqueue -text Queue
	label $f.lpending -text Active
	listbox $f.queue
	listbox $f.pending
	set Http(log) [text $f.log -width 50 -height 10 -wrap none \
	    -yscrollcommand "$f.yscroll set" \
	    -xscrollcommand "$f.xscroll set"]
	scrollbar $f.xscroll -command "$f.log xview" -orient horiz
	scrollbar $f.yscroll -command "$f.log yview" -orient vert
	bind $f.queue <Button-1> {HttpTraceInfo queue %y}
	bind $f.pending <Button-1> {HttpTraceInfo pending %y}
	bind $f.queue <Double-1> {HttpTraceKill queue %y}
	bind $f.pending <Double-1> {HttpTraceKill pending %y}
	grid $f.quit $f.label -
	grid $f.status - - -sticky news
	grid $f.lqueue $f.lpending -sticky news
	grid $f.queue $f.pending -sticky news
	grid $f.log - $f.yscroll -sticky news
	grid $f.xscroll - -sticky news
	grid columnconfigure $f 0 -weight 1
	grid columnconfigure $f 1 -weight 1
	grid columnconfigure $f 2 -weight 0
	grid rowconfigure $f 2 -weight 1
	grid rowconfigure $f 3 -weight 1
	grid $f.label -sticky news
	grid $f.quit -sticky w

    }
    HttpTraceQueue
    HttpTracePending

}
proc HttpLog {args} {
    global Http
    catch {
	$Http(log) insert end [join $args { }]\n
	$Http(log) see end
    }
}

proc HttpTraceQueue {args} {
    global Http
    catch {
	$Http(listbox).queue delete 0 end
	foreach f $Http(queue) {
	    $Http(listbox).queue insert end $f
	}
    }
}
proc HttpTraceKill {what y} {
    global Http
    set list $Http(listbox).$what
    set i [$list cur]
    if {[string length $i]} {
	Http_kill [$list get $i]
    }
}
proc HttpTraceInfo {what y} {
    global Http
    set list $Http(listbox).$what
    set i [$list nearest $y]
    set Http(dbg_status) {}
    catch {trace vdelete $Http(dbg_url) w HttpTraceTrace}
    if {[string length $i]} {
	set url [$list get $i]
	global $url
	upvar #0 $url data
	trace variable $url w HttpTraceTrace
	HttpTraceTrace $url
    }

}
proc HttpTraceTrace {name1 args} {
    global Http
    upvar #0 $name1 data
    set Http(dbg_status) {}
    foreach key {state what count length http} {
	if [info exists data($key)] {
	    append Http(dbg_status) "$key=\"$data($key)\" "
	}
    }
    update idletasks
}
proc HttpTracePending {args} {
    global Http
    catch {
	$Http(listbox).pending delete 0 end
	foreach f $Http(pending) {
	    $Http(listbox).pending insert end $f
	}
    }
}

