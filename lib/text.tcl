# text.tcl
#
# Some (more) basic text utilities.
#
# Copyright (c) 1994 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc Text_TagRangeHigh { t start end args } {
    # This adds the tags named in args to the given range
    # The tags are added at high priority, which is
    # appropriate for "looks" tags and the selection
    foreach tag $args {
	$t tag add $tag $start $end
	$t tag raise $tag	;# over background tags
    }
}
proc Text_TagRangeLow { t start end args } {
    # This adds the tags named in args to the given range
    # The tags are added at low priority, which is
    # appropriate for backgrounds
    foreach tag $args {
	$t tag add $tag $start $end
	$t tag lower $tag	;# Under selection and looks
    }
}
proc Text_TagRangeOverride { t start end args } {
    # This replaces tags in a range.
    # Each tag in args that has the pattern foo=bar
    # replaces any existing tags foo=baz
    # in the range
    set labels {}
    foreach tag $args {
	if [regexp {([^=]+)=} $tag match label] {
	    lappend labels $label
	}
    }
    foreach tag [concat [$t tag names $start] [$t tag names $end]] {
	foreach label $labels {
	    if [string match $label=* $tag] {
		$t tag remove $tag $start $end
	    }
	}
    }
    foreach tag $args {
	$t tag add $tag $start $end
	$t tag lower $tag	;# Under selection and looks
    }
    return $labels
}
