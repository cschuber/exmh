# tioga.tcl
# exmh support to view multipart/x-tioga messages

set tioga(converter) /project/pcedar10.1/bin/MimeToTioga

proc Tioga_ShowMsg { tkw part } {
    global tioga mimeHdr uri

    for {set i 1} {$i <= $mimeHdr($part,numParts)} {incr i} {
	switch -glob -- $mimeHdr($part=$i,hdr,content-type) {
	    *text/plain* {set t $i}
	    *text/x-html* {set h $i}
	}
    }
    if ![info exists t] {
	Exmh_Status "No plain text"
	set t 1
	return
    }
    # Show the text/plain part,
    # and set up the menu to display to
    # tioga or html versions
    set mimeHdr($part=$t,color) $mimeHdr($part,color)
    set mimeHdr($part=$t,display) 1
    set mimeHdr($part=$t,hdr,content-description) "Press right button for menu"
    MimeShowPart $tkw $part=$t [MimeLabel $part part] 0
    MimeMenuDelete $part=$t "View using mailcap rule..."
    MimeMenuDelete $part=$t "Pass a*to metamail..."

    MimeMenuAdd $part=$t command \
	-label "View Tioga..." \
	-command [list TiogaViewTioga $tkw $part]
    if [info exists h] {
	MimeMenuAdd $part=$t command \
	    -label "View HTML..." \
	    -command [list Mosaic_ShowPart $tkw $part=$h]
    }

    MimeMenuAdd $part=$t checkbutton \
	-label "Always View Tioga" \
	-command [list TiogaSetDefault $tkw $part tioga(viewTioga)] \
	-variable tioga(viewTioga)
    MimeMenuAdd $part=$t checkbutton \
	-label "Always View HTML" \
	-command [list TiogaSetDefault $tkw $part uri(viewHtml)] \
	-variable uri(viewHtml)

    if {$tioga(viewTioga)} {
	TiogaViewTioga $tkw $part
    }
    if {$uri(viewHtml) && [info exists h]} {
	Mosaic_ShowPart $tkw $part=$h
    }
}
proc TiogaViewTioga {tkw part} {
    global mimeHdr tioga
    set out [Mime_TempFile tioga]
    exec $tioga(converter) $mimeHdr(0,file) > $out
    exec /import/Xmisc/bin/viewtioga $out &
    after 60000 [list exec rm -f $out]
}
proc TiogaSetDefault {tkw part variable} {
    upvar #0 $variable var
    if {$var} {
	busy MimeRedisplayPart $tkw $part
    }
}
