# 
# xns.tcl
#
# Thin layer over xnsgetmail routine that fetching messages from
# an XNS mail server to your UNIX spool file.  An expect script is
# used to check if you need to login or not..
#
# Copyright (c) 1994 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Xns_GetMail {} {
    global exmh
    Exmh_Status "xnsgetmail -k"
    if [catch {exec $exmh(expect) -f $exmh(library)/xnsgetmail.exp} err] {
	if [regexp {XNS username} $err] {
	    Exmh_Status "Please XNS login"
	    exec xterm -e xnslogin
	    after 1000 Xns_GetMail
	} else {
	    Exmh_Status $err
	}
    }

}

