# ftp_get.tcl
#
# Author: Ovidiu Predescu <ovidiu@aracnet.com>
#
# Retrive an a file via FTP using passive data transfer (see RCF 959)

set ftp(cmdSock) -1
set ftp(dataSock) -1
set ftp(host) ""
set ftp(directory) ""
set ftp(filename) ""

proc FtpConnect {server port} {
    HttpLog ftp $server on $port
    set sock [socket $server $port]
    fconfigure $sock -blocking false
    return $sock
}

proc FtpSetConnectionInfo { url } {
    upvar #0 $url data
    global ftp

    # Check if the URL is correct. Also separate the host, directory
    # and filename
    if {![regexp "\[fF\]\[tT\]\[pP\]://(\[^/\]+)(.*)/(\[^/\]*)" $url x \
	      ftp(host) ftp(directory) ftp(filename)]} {
	return 0
    }

    # Create the data file
    set data(file) [Cache_NewFile $data(url)]
    if {[catch {open $data(file) w 0600} data(fd)]} {
	Exmh_Status "Cannot write to HTML cache directory"
	Http_kill $data(url)
    } else {
	HttpLog "using file $data(file)"
	fconfigure $data(fd) -translation lf
    }

    return 1
}

proc Ftp_event {url} {
    global Http env ftp
    upvar #0 $url data

    if {![info exists data] || ![info exists data(socket)]} {
	return
    }
    if ![info exists data(count)] {
	set data(count) 0
    }

    if [catch {
	switch $data(what) {
	    connected {
		# Get the server's greeting
		ftp_reply_expect 220
		# Send the user name
		ftp_send "USER anonymous"
		set data(what) login
		Exmh_Status "login into $ftp(host)..."
		HttpLog "login into $ftp(host)..."
	    }

	    login {
		# Get the user name response reply
		ftp_reply_expect 230 331
		# Send the password
		ftp_send "PASS $env(USER)@"
		set data(what) password
	    }

	    password {
		# Get the password response reply
		ftp_reply_expect 230
		ftp_send "CWD $ftp(directory)"
		set data(what) changedir
		Exmh_Status "changing directory to $ftp(directory)..."
		HttpLog "changing directory to $ftp(directory)..."
	    }

	    changedir {
		# Get the change directory reply
		ftp_reply_expect 250
		# Set the type to binary
		ftp_send "TYPE I"
		set data(what) settype
	    }

	    settype {
		# Get the type set reply
		ftp_reply_expect 200
		# Create a pasive connection to the server
		ftp_send "PASV"
		set data(what) dataconnection
	    }

	    dataconnection {
		# Get the data connection information
		ftp_get response
		if {![regexp "^227" $response]} {
		    error "the FTP server does not support passive connections!"
		}
		if {![regexp "^227(\[^0123456789\]*)(\[0-9\]+),(\[0-9\]+),(\[0-9\]+),(\[0-9\]+),(\[0-9\]+),(\[0-9\]+).*$" $response x y h1 h2 h3 h4 p1 p2]} {
		    error "cannot get the address of the server socket data"
		} else {
		    set host $h1.$h2.$h3.$h4
		    set port [format "%u" 0x[format "%x%x" ${p1} ${p2}]]
		    if [catch {set ftp(dataSock) [socket $host $port]} err] {
			error "cannot open data socket to $host, port $port! ($err)"
		    }
		    fconfigure $ftp(dataSock) -blocking false
		}
		# Send the retrieve command
		ftp_send "RETR $ftp(filename)"
		Exmh_Status "opening the data channel for $ftp(filename)..."
		HttpLog "opening the data channel for $ftp(filename)..."
		set data(what) retrievecmd
	    }

	    retrievecmd {
		# Get the response from the retrieve request and
		# analyze it to get information about the file's size
		ftp_get response
		if {![regexp "^150" $response]} {
		    error "$response"
		}
		if {![regexp "^150.*\\((\[0-9\]+).*" $response x data(length)]} {
		    set data(length) -1
		}
		set data(what) dataget
	    }

	    dataget {
		# Get the data from the data socket
		if [catch {copychannel $ftp(dataSock) $data(fd) $Http(hunk)} more] {
		    catch {eval $data(progress) error $more 0}
		    error "Read error on $url\n$more"
		}
		if {$more >= 0} {
		    incr data(count) $more
		    catch {eval $data(progress) file $data(count) $data(length)}
		}
		if {$data(length) > 0} {
		    set percent [format "%3.1f" [expr $data(count) * 100 / $data(length)]]
		    Exmh_Status "$url...$percent%"
		    HttpLog "$url...$percent%"
		} else {
		    set kbytes [format "%4.1" [expr $data(count) / 1024]]
		    Exmh_Status "$url...$kbytes kb"
		    HttpLog "$url...$kbytes kb"
		}
		if [eof $ftp(dataSock)] {
		    set data(what) closeconnection
		}
	    }

	    closeconnection {
		Exmh_Status "$url...done"
		HttpLog "$url...done"
		catch {close $ftp(dataSock)}
		set ftp(dataSock) -1
		catch {close $ftp(cmdSock)}
		set ftp(cmdSock) -1
		Http_depend $url
		catch {close $data(fd)}
		unset data(fd)
		Cache_SetFile $url $data(file)
		catch {eval $data(progress) done $data(count) $data(length)}
		foreach cmd $data(command) {
		    HttpLog $cmd
		    catch $cmd
		}
		set data(command) ""
		after idle Http_poke
	    }

	}
    } err] {
	if {$err != "again"} {
	    # An error appeared during the execution of the protocol
	    HttpLog $err
	    catch {eval [list $data(progress) error "$err" $data(length)]}
	    catch {close $ftp(dataSock)}
	    set ftp(dataSock) -1
	    catch {close $ftp(cmdSock)}
	    set ftp(cmdSock) -1
	    catch {close $data(fd)}
	    catch {unset data(fd)}
	    Http_kill $url
	    return
	} else {
	    # Not enough data; return to the main loop and await for
	    # more data
	    return
	}
    }
}

proc ftp_reply_expect { args } {
    ftp_get response

    foreach code $args {
	if {[regexp "^$code.*" $response]} {
	    return;
	}
    }
    error "bad response from the ftp server: $response"
}

proc ftp_get { varname } {
    global ftp
    upvar $varname response

    if {[gets $ftp(cmdSock) response] == -1} {
	if [fblocked $ftp(cmdSock)] {
	    # Line was not read completly because there's not a full
	    # line available yet
	    error "again"
	} else {
	    # End of file was encountered before reading a full line
	    close $ftp(cmdSock)
	    set ftp(cmdSock) -1
	    error "remote has closed the connection!"
	}
    }
    HttpLog "ftpd: $response"
}

proc ftp_send { cmd } {
    global ftp

    HttpLog "--> $cmd"
    if [catch {puts $ftp(cmdSock) $cmd} err] {
	error "cannot send to ftp socket: $err"
    }
    flush $ftp(cmdSock)
}
