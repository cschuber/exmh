# seditCompose.tcl
#
# This routine defines a table that maps from two-character sequences,
# which are typed after the Compose key, into 8-bit input characters.
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc SeditComposedKey { w a1 a2 } {
    global composedkey sedit

    if [info exists composedkey($a1$a2)] {
	SeditInsert $w "$composedkey($a1$a2)"
	if {$sedit($w,quote) < 0} {
	    set sedit($w,quote) 1
	}
    } elseif [info exists composedkey($a2$a1)] {
	SeditInsert $w "$composedkey($a2$a1)"
	if {$sedit($w,quote) < 0} {
	    set sedit($w,quote) 1
	}
    } else {
	SeditInsert $w "$a1$a2"
    }
    bind SeditText <Any-Key> { SeditInsert %W %A }
}

proc SeditComposedKeyBindings {} {
    global composedkey

    set composedkey("a) "\xE4"
    set composedkey("e) "\xEB"
    set composedkey("i) "\xEF"
    set composedkey("u) "\xFC"
    set composedkey("o) "\xF6"
    set composedkey("A) "\xC4"
    set composedkey("E) "\xCB"
    set composedkey("I) "\xCF"
    set composedkey("O) "\xD6"
    set composedkey("U) "\xDC"
    set composedkey(`a) "\xE0"
    set composedkey(`e) "\xE8"
    set composedkey(`i) "\xEC"
    set composedkey(`u) "\xF9"
    set composedkey(`o) "\xF2"
    set composedkey(`A) "\xC0"
    set composedkey(`E) "\xC8"
    set composedkey(`I) "\xCC"
    set composedkey(`O) "\xD2"
    set composedkey(`U) "\xD9"
    set composedkey(^a) "\xE2"
    set composedkey(^e) "\xEA"
    set composedkey(^i) "\xEE"
    set composedkey(^u) "\xFB"
    set composedkey(^o) "\xF4"
    set composedkey(^A) "\xC2"
    set composedkey(^E) "\xCA"
    set composedkey(^I) "\xCE"
    set composedkey(^O) "\xD4"
    set composedkey(^U) "\xDB"
    set composedkey('a) "\xE1"
    set composedkey('e) "\xE9"
    set composedkey('i) "\xED"
    set composedkey('u) "\xFA"
    set composedkey('o) "\xF3"
    set composedkey('y) "\xFD"
    set composedkey('A) "\xC1"
    set composedkey('E) "\xC9"
    set composedkey('I) "\xCD"
    set composedkey('O) "\xD3"
    set composedkey('U) "\xDA"
    set composedkey('Y) "\xDD"
    set composedkey(/o) "\xF8"
    set composedkey(/O) "\xD8"
    set composedkey(ae) "\xE6"
    set composedkey(AE) "\xC6"
    set composedkey(~a) "\xE3"
    set composedkey(~o) "\xF5"
    set composedkey(~n) "\xF1"
    set composedkey(~A) "\xC3"
    set composedkey(~O) "\xD5"
    set composedkey(~N) "\xD1"
    set composedkey(aa) "\xE5"
    set composedkey(AA) "\xC5"
    set composedkey(*a) "\xE5"
    set composedkey(*A) "\xC5"
    set composedkey(\"\") "\xA8"
    set composedkey(,,) "\xB8"
    set composedkey(!!) "\xA1"
    set composedkey(??) "\xBF"
    set composedkey(ss) "\xDF"
    set composedkey(|c) "\xA2"
    set composedkey(-l) "\xA3"
    set composedkey(,c) "\xE7"
    set composedkey(,C) "\xC7"

}

proc Sedit_ComposeUI {} {
    global composedkey
    if [Exwin_Toplevel .compose "Compose Key" Key] {
	set f .compose
	Widget_Message $f msg -aspect 1000 -text \
"Compose Key Sequences
Press the Compose key and the
two-letter sequence on the left
to get the special character
in the right-hand column.
You can define the Compose key
in the Simple Edit dialog.
The font used to display these
characters is in the status line."
	set t [Widget_Text $f 20 -width 20]
	$t config -width 20
	foreach family { courier lucidatypwriter lucida times palatino * } {
	    if {[catch {$t config -font -*-$family-medium-r-*-*-12-*-*-*-*-*-iso8859-1}] == 0} {
		break
	    }
	}
    } else {
	set t .compose.t
    }
    Exmh_Status [lindex [$t config -font] 4]
    $t delete 1.0 end
    foreach key [lsort [array names composedkey]] {
	$t insert insert "  $key\t$composedkey($key)\n"
    }
}
