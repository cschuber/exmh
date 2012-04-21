proc jpilot-addr-lookup {n} {
    # look up addresses in jpilot's address book

    Exmh_Status "Querying jpilot for $n"

    if [catch {set jpilot_results [eval exec query_jpilot.sh $n]} e] {
	Exmh_Status "Error executing jpilot-dump: $e"
	return {}
    }

    # the jpilot_results looks like this:
    # e-mail@add.ress\tlastname firstname\tcompany

    set result {}
    foreach i [split $jpilot_results \n] {
	if [string match {*@*} $i] {
    	    lappend result "[jpilot-addr-formatformail $i]"
	}
    }

    return $result
}

proc jpilot-addr-formatformail { line } {
    global addr_db

    set s [split $line \t]
    # s will contain "email" "lastname firstname" "company"
    set email [lindex $s 0]
    set name [lindex $s 1]
    set company [lindex $s 2]

    return [LDAP_Entry_FormatForMail $email $name]
}
