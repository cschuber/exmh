
proc Mosaic_Load { url {newwin goto} } {
    global mosaic uri
    if ![info exists mosaic(pid)] {
	set mosaic(pid) [PsByName $uri(mosaicApp)]
	if {[string length $mosaic(pid)] == 0} {
	    Exmh_Status "Starting $uri(mosaicApp)"
	    set mosaic(pid) [exec $uri(mosaicApp) $url &]
	    return
	} else {
	    Exmh_Status "$uri(mosaicApp) pid $mosaic(pid)"
	}
    }
    if [catch {open [Env_Tmp]/Mosaic.$mosaic(pid) w} out] {
	error $out
    }
    puts $out $newwin
    puts $out $url
    close $out
    catch {unset mosaic(fail)}
    if [catch {exec kill -USR1 $mosaic(pid)} err] {
	if [info exists mosaic(fail)] {
	    Exmh_Status "Cannot signal xmosaic $mosaic(pid)"
	    unset mosaic(pid)
	    unset mosaic(fail)
	    error $err
	} else {
	    set mosaic(fail) $err
	    unset mosaic(pid)
	    Mosaic_Load $url
	}
    }
}
proc Mosaic_ShowPart { tkw part } {
    Uri_ShowPart $tkw $part
}
