# content.tcl
#	Handlers for different content types called by UrlDisplay.

# These procedures need to return 1 or 0.
# A 1 indicates they displayed something in the current page.
# If they can't do anything with the content, they should raise an error
# and UrlDisplay will call the next content type handler.

proc Content_text/html {win url} {
    upvar #0 HM$win var
    upvar #0 $url data
    regsub {\?.*} $url {} var(S_url)
    Url_DisplayHtml $win $var(S_url) $data(html)
    return 1
}
proc Content_text/plain {win url} {
    upvar #0 HM$win var
    upvar #0 $url data
    set var(S_url) $url
    HMreset_win $win
    wm title [winfo toplevel $win] [file tail $url]
    wm iconname  [winfo toplevel $win] [file tail $url]
    $win insert 1.0 $data(html)
    return 1
}
proc Content_image {win url} {
    upvar #0 $url data
    Status $win "starting xv to view image"
    exec xv $data(file) &
    return 0
}
proc Content_default {win url} {
    upvar #0 HM$win var
    upvar #0 $url data
    if [info exists data(message)] {
	regsub {\?.*} $url {} var(S_url)
	Url_DisplayHtml $win $var(S_url) $data(message)
	return 1
    } else {
	if {[info exists data(file)] && [file exists $data(file)]} {
	    set localname \
		[FSBox "Location for downloaded file"]
	    while {$localname != {}} {
		if [catch {
		    exec cp $data(file) $localname
		} err] {
		    Status $win $err
		} else {
		    Status $win "Saved to $localname"
		    break
		}
		set localname \
		    [fileselect "Location for downloaded file"]
	    }
	    catch {rm -f $data(file)}
	}
	return 0
    }
}
