#
# crypt.tcl
#	Generalized sypport for multipart/signed and multipart/encrypted
#	in exmh.
#
#	Written by Chris Garrigues

proc Crypt_Init {} {
    global mime

    set protocols [concat [option get . sigProts {}] [option get . sigUProts {}]]
    Exmh_Debug sigProtocols $protocols
    set mime(showsig,default)			Mime_ShowMultipart
    if {[llength $protocols] == 0} {
	set mime(showsig,application/pgp-signature)	Pgp_MimeShowMultipartSignedPgp
    } else {
	foreach protocol $protocols {
	    set func [option get . sig_$protocol {}]
	    if {[string length $func] != 0} {
		set mime(showsig,$protocol) $func
	    }
	}
    }
    set protocols [concat [option get . cryptProts {}] [option get . cryptUProts {}]]
    Exmh_Debug cryptProtocols $protocols
    set mime(showcrypt,default)			Mime_ShowMultipart
    if {[llength $protocols] == 0} {
	set mime(showcrypt,application/pgp-encrypted)	Pgp_MimeShowMultipartEncryptedPgp
    } else {
	foreach protocol $protocols {
	    set func [option get . crypt_$protocol {}]
	    if {[string length $func] != 0} {
		set mime(showcrypt,$protocol) $func
	    }
	}
    }
}

proc MimeShowMultipartSigned {tkw part} {
    global mimeHdr mime

    set protocol $mimeHdr($part,param,protocol)
    
    if [info exists mime(showsig,$protocol)] {
	if [catch {$mime(showsig,$protocol) $tkw $part} err] {
	    Exmh_Status "Error decoding $protocol: $err"
	    $mime(showsig,default) $tkw $part
	}
    } else {
	Exmh_Status "Unknown signature protocol: $protocol"
	$mime(showsig,default) $tkw $part
    }
}

proc MimeShowMultipartEncrypted {tkw part} {
    global mimeHdr mime

    set protocol $mimeHdr($part,param,protocol)

    if [info exists mime(showcrypt,$protocol)] {
	$mime(showcrypt,$protocol) $tkw $part
    } else {
	Exmh_Status "Unknown encryption protocol: $protocol"
	$mime(showcrypt,default) $tkw $part
    }
}

