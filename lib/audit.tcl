#
# audit.tcl --
#	Leave an audit trail of operations on mail messages.
#
# Copyright 1995 Xerox Corporation All rights reserved.
# License is granted to copy, to use, and to make and to use derivative works for
# research and evaluation purposes, provided that the Xerox copyright notice and
# this license notice is included in all copies and any derivatives works and in
# all  related documentation.  Xerox grants no other licenses expressed or
# implied and the licensee acknowleges that Xerox has no  liability for
# licensee's use or for any derivative works  made by licensee. The Xerox  name
# shall not be used in any advertising or the like without its written
# permission.
# This software is provided AS IS.  XEROX CORPORATION DISCLAIMS AND LICENSEE
# AGREES THAT ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# NOTWITHSTANDING ANY OTHER PROVISION CONTAINED HEREIN, ANY LIABILITY FOR DAMAGES
# RESULTING FROM THE SOFTWARE OR ITS USE IS EXPRESSLY DISCLAIMED, INCLUDING
# CONSEQUENTIAL OR ANY OTHER INDIRECT DAMAGES, WHETHER ARISING IN CONTRACT, TORT
# (INCLUDING NEGLIGENCE) OR STRICT LIABILITY, EVEN IF XEROX CORPORATION IS
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGES."



proc Audit { event } {
    global exmh
    if {![info exists exmh(auditEnabled)] || !$exmh(auditEnabled)} {
	return
    }
    after 1 [list AuditInner $event]
}
proc AuditInner { event } {
    global audit
    if ![info exists audit(file)] {
	if [catch {open [Env_Tmp]/.exmhaudit.[pid] w 0600} audit(file)] {
	    Exmh_Status $audit(file)
	    set audit(file) {}
	}
    }
    if {$audit(file) == {}} {
	return
    }
    regexp {^([^ 	]+)} $event key
    if ![info exists audit(stat,$key)] { set audit(stat,$key) 0}
    incr audit(stat,$key)
    foreach ignore {folder} {
	if {[string compare $key $ignore] == 0} {
	    return
	}
    }
    puts $audit(file) $event
    flush $audit(file)
}
proc Audit_Stats {} {
    global exwin audit
    set t .audit
    if [Exwin_Toplevel .audit "Audit Stats" Audit] {
	Widget_AddBut $t.but audit "Update Stats" Audit_Stats
	FontWidget listbox $t.list -yscrollcommand "$t.scroll set" -setgrid true
	scrollbar $t.scroll -command "$t.list yview"
	pack $t.scroll $t.list -side $exwin(scrollbarSide)
	pack $t.scroll -fill y
	pack $t.list -fill both
    }
    $t.list delete 0 end
    eval $t.list insert end [AuditGetStats]
    catch {eval $t.list insert end Background [send $exmh(bgInterp) AuditGetStats]}
}
proc Audit_View {} {
    global exwin audit
    set t .auditview
    if [Exwin_Toplevel $t "Audit View" Audit] {
	if ![info exists audit(view)] {
	    set audit(view) Current
	}
	Widget_RadioBut $t.but cur "Current" audit(view) {right} \
		-command {AuditLoad $audit(view)}
	Widget_RadioBut $t.but past "Past" audit(view) {right} \
		-command {AuditLoad $audit(view)}
	set audit(text) [Widget_Text $t 20]
    }
    AuditLoad $audit(view)

}
proc AuditLoad { view } {
    global audit mhProfile
    set t $audit(text)
    switch -- $view {
	Past { set path $mhProfile(path)/.exmhaudit }
	Current -
	default { set path [Env_Tmp]/.exmhaudit.[pid] }
    }
    $t delete 1.0 end
    if [catch {open $path} in] {
	$t insert end $in
    } else {
	$t insert end [read $in]
	close $in
    }
}
proc AuditGetStats {} {
    global audit
    set x {}
    if [info exists audit] {
	foreach index [lsort [array names audit]] {
	    if [regexp {^stat,(.+)} $index _ key] {
		lappend x [format "%-10s %s" $key $audit($index)]
	    }
	}
    }
    return $x
}
proc Audit_CheckPoint {} {
    global audit mhProfile argv0 exmh
    if {![info exists exmh(auditEnabled)] || !$exmh(auditEnabled)} {
	return
    }
    set file $audit(file)
    unset audit(file)

    puts $file "$argv0 run ending: [exec date]\nStats\n"
    foreach index [lsort [array names audit]] {
	if [regexp {^stat,(.+)} $index x key] {
	    puts $file "$index $audit($index)"
	}
	unset audit($index)
    }
    close $file
    exec cat [Env_Tmp]/.exmhaudit.[pid] >> $mhProfile(path)/.exmhaudit
    Exmh_Status "Updated $mhProfile(path)/.exmhaudit"
    File_Delete [Env_Tmp]/.exmhaudit.[pid]
}
