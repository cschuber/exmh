proc Pgp_EncryptWhatNow {action id} {
	global pgp draft-folder mhProfile

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
	if {$pgp(enabled)} {
		# build pgp-action: line
		set pgpaction "Pgp-Action: $action"
		if $pgp(rfc822) {
			append pgpaction "; rfc822=on"
		} else {
			append pgpaction "; rfc822=off"
		}
		if [regexp {sign} $action] {
			append pgpaction ";\n\toriginator=\"[lindex $pgp(myname) 1]\""
		}
		if [regexp {encrypt} $action] {
			catch {
				append pgpaction "; \n\trecipients=\"[join [Misc_Map key {lindex $key 1} [PgpMatch_Whom $draft $hasfcc]] ",\n\t\t    "]\""
			}
		}
		puts $f_tmp $pgpaction
	} else {
		# print warning
		Exmh_Status "PGP not enabled" warn
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
