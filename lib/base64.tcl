# Emit base64 encoding for a string
set i 0
foreach char {A B C D E F G H I J K L M N O P Q R S T U V W X Y Z \
	      a b c d e f g h i j k l m n o p q r s t u v w x y z \
	      0 1 2 3 4 5 6 7 8 9 + /} {
    set base64($char) $i
    set base64_en($i) $char
    incr i
}

proc Base64_Encode {string} {
    Base64_EncodeInit state old length
    set result [Base64_EncodeBlock $string state old length]
    append result [Base64_EncodeTail state old length]
    return $result
}
proc Base64_EncodeInit {stateVar oldVar lengthVar} {
    upvar 1 $stateVar state
    upvar 1 $oldVar old
    upvar 1 $lengthVar length
    set state 0
    set length 0
    if {[info exists old]} { unset old }
}
proc Base64_EncodeBlock {string stateVar oldVar lengthVar} {
    global base64_en
    upvar 1 $stateVar state
    upvar 1 $oldVar old
    upvar 1 $lengthVar length
    set result {}
    foreach {c} [split $string {}] {
	scan $c %c x
	switch [incr state] {
	    1 {	append result $base64_en([expr {($x >>2) & 0x3F}]) }
	    2 { append result $base64_en([expr {(($old << 4) & 0x30) | (($x >> 4) & 0xF)}]) }
	    3 { append result $base64_en([expr {(($old << 2) & 0x3C) | (($x >> 6) & 0x3)}])
		append result $base64_en([expr {($x & 0x3F)}])
                incr length
		set state 0
              }
	}
	set old $x
	incr length
	if {$length >= 72} {
	    append result \n
	    set length 0
	}
    }
    return $result
}
proc Base64_EncodeTail {stateVar oldVar lengthVar} {
    global base64_en
    upvar 1 $stateVar state
    upvar 1 $oldVar old
    upvar 1 $lengthVar length
    set result ""
    switch $state {
	0 { # OK }
	1 { append result $base64_en([expr {(($old << 4) & 0x30)}])== }
	2 { append result $base64_en([expr {(($old << 2) & 0x3C)}])=  }
    }
    return $result
}
proc Base64_Decode {string} {
    global base64

    set output {}
    set group 0
    set pad 0
    set j 18
    foreach char [split $string {}] {
	if {[string compare $char "\n"] == 0} {
          continue
        }
	if [string compare $char "="] {
	    set bits $base64($char)
	    set group [expr {$group | ($bits << $j)}]
	} else {
	    incr pad
	}

	if {[incr j -6] < 0} {
		set i [scan [format %06x $group] %2x%2x%2x a b c]
		switch $pad {
		    2 { append output [format %c $a] }
		    1 { append output [format %c%c $a $b] }
		    0 { append output [format %c%c%c $a $b $c] }
		}
		set group 0
		set j 18
	}
    }
    return $output
}


