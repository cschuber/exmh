#
# partial.tcl --
#
# Prodedure to Concatenate Partial messages to a new message.
#
# Author: Sven-Ove Westberg   (sow@cad.luth.se)
# Sven-Ove Westberg, CAD, University of Lulea, S-971 87 Lulea, Sweden
#
proc Partial_Concatenate {} {
	global exmh
	set msgs {}
	Ftoc_Iterate line {
	    lappend msgs [Ftoc_MsgNumber $line]
	}
	Exmh_Status "Concatenate message $msgs"
	Exmh_Debug exec mhn -store +$exmh(folder) $msgs
	if [catch {open "|mhn -store +$exmh(folder) $msgs |& cat"} input] {
	    Exmh_Status $input
	    return
	}
	while {[gets $input line] >= 0} {
		Exmh_Status $line
	}
	if [catch {close $input} err] {
	    Exmh_Status $err
	}
	busy Scan_FolderForce ; Msg_ShowSomething
}
