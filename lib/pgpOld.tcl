# pgpOld.tcl

# $Log$
# Revision 1.4  2002/07/22 21:23:48  cwg
#     ftoc.tcl, msg,tcl, scan.tcl - Eliminate optional "line" argument to
# 	Ftoc_FindMsg, not incidently removing *all* the code that
# 	between the old location and the new location in my patch of
# 	7/19; as a result, also remove the optional line argument to
# 	Ftoc_Change and the msgid argument to Msg_Change; also, of
# 	course, change all the callers of these functions, and remove
# 	the dead Msg_ShowWhat proc.  This gives us a net reduction in
# 	code and makes it all somewhat clearer. Let's see what I broke
# 	by doing this.
#     pgpMain.tcl, pgpOld.Tcl - Call Msg_Change, not MsgChange.
#
# Revision 1.3  1999/08/22 19:19:22  bmah
# Fix typo that prevented Old PGP->Extract Keys from working.
#
# Revision 1.2  1999/08/03 04:05:55  bmah
# Merge support for PGP2/PGP5/GPG from multipgp branch.
#
# Revision 1.1.4.1  1999/06/14 20:05:16  gruber
# updated multipgp interface
#
# Revision 1.1  1999/06/14 15:14:54  markus
# added files
#
# Revision 1.2  1998/12/02 19:36:26  markus
# Fixed automagic version checking
#
# Revision 1.1.1.1  1998/11/24 22:34:46  markus
# Initial revision
#

# decrypt the current message
proc Pgp_Old_Decrypt { } {
    global exmh msg mhProfile exwin pgp

    set file $msg(path)

    # decide which version to use / implicitely checks for pgp enabled
    if { [catch {Pgp_CheckVersion $file real v} err] } {
        Exmh_Debug "<PGP> $err"
        Exmh_Status "No version found! Perhaps this is no ciphertext."
        return
    }

    set pgpfile [Mime_TempFile "decrypt"]
    Exmh_Status "[set pgp($v,fullName)] $exmh(folder)/$msg(id)"
    Pgp_Exec_Decrypt $v $file $pgpfile message [set pgp($v,myname)]

    if {$message != {}} {
	Pgp_Misc_DisplayText "[set pgp($v,fullName)] decrypt $exmh(folder)/$msg(id)" $message
    }
    set t $exwin(mtext)

    set orig [open $file r]
    if [catch {
	set mess [open $pgpfile r]
    } err] {
	return 0
    }

    set outfile [Mime_TempFile "decypted"]
    set comb [open $outfile w 0600]
    while {[gets $orig line] != -1} {
	if {[regexp {^-+BEGIN PGP MESSAGE} $line]} {
	    puts -nonewline $comb [read $mess]
	    while {[gets $orig line] != -1} {
		if {[regexp {^-+END PGP MESSAGE} $line]} { break }
	    }
	} else {
	    puts $comb $line
	}
    }
    close $orig
    close $comb
    close $mess

    Mh_Rename $outfile $file
    File_Delete $pgpfile
    set msg(dpy) {}
    Msg_Change $msg(id)

    return 1
}

proc Pgp_Old_ExtractKeys { path } {

    Exmh_Debug "Pgp_Old_ExtractKeys $path"

    # decide which version to use / implicitely checks for pgp enabled
    if { [catch {Pgp_CheckVersion $path real v} err] } {
        Exmh_Debug "<PGP> $err"
        Exmh_Status "No version found! Perhaps there is no key."
        return
    }

    Exmh_Debug "<Pgp_Old_ExtractKeys> Pgp_Exec_ExtractKeys $v $path out"
    Pgp_Exec_ExtractKeys $v $path out

    return 1
}
