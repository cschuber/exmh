# pgpBase.tcl

#
# This file contains basic variables and procedures needed
# for the initialisation process
#

# $Log$
# Revision 1.5  2000/06/09 03:46:25  valdis
# PGP 6.5 support
#
# Revision 1.4  1999/08/24 15:51:07  bmah
# Patch from Kevin Christian to make email PGP key queries work, and
# to make key attachment RFC 2015 compliant.
#
# Revision 1.3  1999/08/22 18:17:08  bmah
# Email PGP queries now go out correctly.  Use Exmh_Status to inform
# user of state of an outgoing email key query.
#
# Revision 1.2  1999/08/03 04:05:54  bmah
# Merge support for PGP2/PGP5/GPG from multipgp branch.
#
# Revision 1.1.4.3  1999/07/18 12:52:04  gruber
# *** empty log message ***
#
# Revision 1.1.4.2  1999/07/09 12:36:10  gruber
# few fixes
#
# Revision 1.1.4.1  1999/06/14 20:05:14  gruber
# updated multipgp interface
#
# Revision 1.1  1999/06/14 15:14:53  markus
# added files
#

proc Pgp_Base_Init {} {
global pgp miscRE env
###

# ---- For all versions ---- #
set miscRE(headerend) {^(--+.*--+)?$}
set miscRE(mimeheaders) {^content-[-a-z]+:}
set miscRE(true) {^(on|y(es)?|t(rue)?)$}
set miscRE(beginpgp) {^-+BEGIN PGP}
set miscRE(beginpgpkeys) {^-+BEGIN PGP PUBLIC KEY BLOCK-+$}
set miscRE(beginpgpclear) {^-+BEGIN PGP SIGNED MESSAGE-+$}

set pgp(enabled) 0
set pgp(pat_MenuInner) {Pgp}

set pgp(supportedversions) [list pgp pgp5 gpg pgp6]

# -- GnuPG -- #
set pgp(gpg,enabled) 0
set pgp(gpg,fullName) "GnuPG"

set pgp(gpg,executable,key) gpg
set pgp(gpg,executable,verify) gpg
set pgp(gpg,executable,encrypt) gpg
set pgp(gpg,executable,sign) gpg

if [info exists env(GNUPGHOME)] {
    set pgp(gpg,defaultPath) "$env(GNUPGHOME)"
} else {
    set pgp(gpg,defaultPath) "$env(HOME)/.gnupg"
}

set pgp(gpg,configFile) "$pgp(gpg,defaultPath)/options"
set pgp(gpg,pubring) "$pgp(gpg,defaultPath)/pubring.gpg"
set pgp(gpg,secring) "$pgp(gpg,defaultPath)/secring.gpg"
set pgp(gpg,pubringBkp) "$pgp(gpg,defaultPath)/pubring.gpg~"
set pgp(gpg,keyGenCmd) "rm -f $pgp(gpg,pubringBkp) && gpg --gen-key"

## ButtonMenuInner
set pgp(gpg,pat_MenuInner) {GPG}
## Version checking and Compatibilty
set pgp(gpg,pat_Version) "Version:\[ \t\]*(GNUPG|GnuPG).*"
set pgp(gpg,list_Alien) {pgp5 pgp6 pgp}


# -- PGP 2.6 -- #
set pgp(pgp,enabled) 0
set pgp(pgp,fullName) "PGP 2.6"

set pgp(pgp,executable,key) pgp
set pgp(pgp,executable,verify) pgp
set pgp(pgp,executable,encrypt) pgp
set pgp(pgp,executable,sign) pgp

if [info exists env(PGPPATH)] {
    set pgp(pgp,defaultPath) "$env(PGPPATH)"
} else {
    set pgp(pgp,defaultPath) "$env(HOME)/.pgp"
}
set pgp(pgp,configFile) "$pgp(pgp,defaultPath)/config.txt"
set pgp(pgp,pubring) "$pgp(pgp,defaultPath)/pubring.pgp"
set pgp(pgp,secring) "$pgp(pgp,defaultPath)/secring.pgp"
set pgp(pgp,pubringBkp) "$pgp(pgp,defaultPath)/pubring.bak"
set pgp(pgp,keyGenCmd) "rm -f $pgp(pgp,pubringBkp) && pgp -kg"
set pgp(pgp,afterKeyGen) {
    if {![file exists pgp(pgp,pubringBkp)]} {
        return
    } else {
        set tmpfile [Mime_TempFile "pgp"]
        Exec_GetKeys pgp \
               [lindex [lindex $pgp(pgp,privatekeys) 0] 0] $tmpfile
        Pgp_Misc_Send $pgp(pgp,keyserver) ADD $tmpfile \
               "content-type: application/pgp; format=keys-only"
        File_Delete $tmpfile
    }
}

## ButtonMenuInner
set pgp(pgp,pat_MenuInner) {PGP[^5]}
## Version checking and Compatibilty
set pgp(pgp,pat_Version) "Version:\[ \t\]*2\.6.*"
set pgp(pgp,list_Alien) {pgp5 pgp6 gpg}

# -- PGP 5.0 -- #
set pgp(pgp5,enabled) 0
set pgp(pgp5,fullName) "PGP 5.0"
set pgp(pgp5,executable,key) pgpk
set pgp(pgp5,executable,verify) pgpv
set pgp(pgp5,executable,encrypt) pgpe
set pgp(pgp5,executable,sign) pgps

set pgp(pgp5,defaultPath) "$pgp(pgp,defaultPath)"
set pgp(pgp5,configFile) "$pgp(pgp5,defaultPath)/pgp.cfg"
set pgp(pgp5,pubring) "$pgp(pgp5,defaultPath)/pubring.pkr"
set pgp(pgp5,secring) "$pgp(pgp5,defaultPath)/secring.skr"
set pgp(pgp5,pubringBkp) "$pgp(pgp5,defaultPath)/pubring.bak"
set pgp(pgp5,keyGenCmd) "rm -f $pgp(pgp5,pubringBkp) && pgpk -g"

## ButtonMenuInner
set pgp(pgp5,pat_MenuInner) {PGP5}
## Version checking and Compatibilty
set pgp(pgp5,pat_Version) "Version:\[ \t\]*((PGP\[^\n\]*)? 5\\.|PGPsdk).*"
set pgp(pgp5,list_Alien) {gpg pgp pgp6}

# -- PGP 6.5.n -- #
set pgp(pgp6,enabled) 0
set pgp(pgp6,fullName) "PGP 6.5"

set pgp(pgp6,executable,key) pgp6
set pgp(pgp6,executable,verify) pgp6
set pgp(pgp6,executable,encrypt) pgp6
set pgp(pgp6,executable,sign) pgp6

if [info exists env(PGPPATH)] {
    set pgp(pgp6,defaultPath) "$env(PGPPATH)"
} else {
    set pgp(pgp6,defaultPath) "$env(HOME)/.pgp"
}
set pgp(pgp6,configFile) "$pgp(pgp6,defaultPath)/config.txt"
set pgp(pgp6,pubring) "$pgp(pgp6,defaultPath)/pubring.pkr"
set pgp(pgp6,secring) "$pgp(pgp6,defaultPath)/secring.skr"
set pgp(pgp6,pubringBkp) "$pgp(pgp6,defaultPath)/pubring-bak-1.pkr"
set pgp(pgp6,keyGenCmd) "rm -f $pgp(pgp6,pubringBkp) && pgp6 -kg"
set pgp(pgp6,afterKeyGen) {
    if {![file exists pgp(pgp6,pubringBkp)]} {
        return
    } else {
        set tmpfile [Mime_TempFile "pgp"]
        Exec_GetKeys pgp \
               [lindex [lindex $pgp(pgp6,privatekeys) 0] 0] $tmpfile
        Pgp_Misc_Send $pgp(pgp6,keyserver) ADD $tmpfile \
               "content-type: application/pgp; format=keys-only"
        File_Delete $tmpfile
    }
}

## ButtonMenuInner
set pgp(pgp6,pat_MenuInner) {PGP6}
## Version checking and Compatibilty
set pgp(pgp6,pat_Version) "Version:\[ \t\]*6\.5.*"
set pgp(pgp6,list_Alien) {pgp pgp5 gpg}

###
}
