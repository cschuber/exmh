# pgpEWN.tcl

# $Log$
# Revision 1.2  1999/08/03 04:05:54  bmah
# Merge support for PGP2/PGP5/GPG from multipgp branch.
#
# Revision 1.1.4.1  1999/06/14 20:05:15  gruber
# updated multipgp interface
#
# Revision 1.3  1999/06/14 14:52:23  markus
# Update ready
#

proc EncryptWhatNow { v action id } {
	global draft-folder mhProfile pgp

	set draft [Mh_Path $mhProfile(draft-folder) $id]
	set tmp_draft [Mime_TempFile encrypt]

	set f_orig [open $draft r]
	set f_tmp [open $tmp_draft w 0600]

	set hasfcc 0

	set line [gets $f_orig]
	# while still in header
	while {![regexp {^(--+.*--+)?$} $line]} {
		if [regexp -nocase {^pgp-action:} $line] {
			# we found an existing pgp-action line
			# remove it
			set line " dummy"
			# while next lines start with tab or space
			while {[regexp "^\[ \t]" $line]} {
				set line [gets $f_orig]
			}
		} else {
			# other header lines
			if [regexp -nocase {^fcc:} $line] {
				set hasfcc 1
			}
			puts $f_tmp $line
			set line [gets $f_orig]
		}
	}
	if {[set pgp($v,enabled)]} {
		# build pgp-action: line
		set pgpaction "Pgp-Action: $action"
		if [set pgp($v,rfc822)] {
			append pgpaction "; rfc822=on"
		} else {
			append pgpaction "; rfc822=off"
		}
		if [regexp {sign} $action] {
			append pgpaction ";\n\toriginator=\"[lindex \
						[set pgp($v,myname)] 1]\""
		}
		if [regexp {encrypt} $action] {
			catch {
				append pgpaction "; \n\trecipients=\"[join [Pgp_Misc_Map key {lindex $key 1} [Pgp_Match_Whom $v $draft $hasfcc]] ",\n\t\t    "]\""
			}
		}
		append pgpaction ";\n\tpgp-version=$v"
		puts $f_tmp $pgpaction
	} else {
		# print warning
		Exmh_Status "[set pgp($v,fullName)] not enabled" warn
	}
	# faster
	puts $f_tmp $line
	set remaining [read $f_orig]
	puts -nonewline $f_tmp $remaining

	close $f_orig
	close $f_tmp
	# mv tmp to orig
	catch {Mh_Rename $tmp_draft $draft}
}
