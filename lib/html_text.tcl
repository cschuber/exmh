# text.tcl
# Wrappers around low-level text widget functions

proc Text_DeleteForUndo {win m1 m2} {
    set m1 [$win index $m1]
    set m2 [$win index $m2]
    if [$win compare $m1 == $m2] {
	Undo_Record $win \
		[list Text_Insert $win $m1 [$win get $m1] [$win tag names $m1]] \
		[list Text_Delete $win $m1 $m1]
	$win delete $m1
    } else {
	set state(tags) [$win tag names $m1]
	set state(m1) $m1		;# Index for all undo ops in this batch
	$win dump -tag -text -window -command \
		[list TextUndoTextProc state $win] $m1 $m2
	TextUndoTextDel state $win $m2
	$win delete $m1 $m2
    }    
}

# Fully general undo-able tag remove.  Have to look closely
# to make sure we only undo tag ranges that are present.
proc Text_TagRemove {win tag m1 {m2 {}}} {
    if {[string length $m2] == 0} {
	set m2 [$win index "$m1 +1char"]
    }
    if {[lsearch [$win tag names $m1] $tag] >= 0} {
	set state(ix) [$win index $m1]
    }
    set state(tag) $tag
    $win dump -tag -text -window -command \
	    [list TextUndoTagRemoveProc state $win] $m1 $m2
    TextUndoTagRemove state $win [$win index $m2]
    $win tag remove $tag $m1 $m2
}
# Optimized TagRemove that only works if the tag is applied to the
# whole range - i.e. there are no gaps.  Use with Edit_CurrentRange.
proc Text_TagClearRange {win tag m1 m2} {
    Undo_Record $win \
	    [list Text_TagAdd $win $tag $m1 $m2] \
	    [list Text_TagRemove $win $tag $m1 $m2]
    $win tag remove $tag $m1 $m2
}
# Optimized version of Text_TagRemove to clear the selection
proc Text_SelClear {win {tag sel}} {
    foreach {m1 m2} [$win tag ranges $tag] {
	Text_TagClearRange $win $tag $m1 $m2
    }
}

# Fully general undo-able tag add.  The tag may already be present
# in parts of the range
proc Text_TagAdd {win tag m1 {m2 {}}} {
    if {[string length $m2] == 0} {
	set m2 [$win index "$m1 +1char"]
    }
    if {[lsearch [$win tag names $m1] $tag] < 0} {
	set state(ix) [$win index $m1]
    }
    set state(tag) $tag
    $win dump -tag -text -window -command \
	    [list TextUndoTagAddProc state $win] $m1 $m2
    TextUndoTagAdd state $win [$win index $m2]
    $win tag add $tag $m1 $m2
}

proc Text_MarkSet {win mark {index insert} {gravity left}} {
    if [catch {$win index $mark} old] {
	set undoCmd [list Text_MarkUnset $win $mark]
    } else {
	set undoCmd [list Text_MarkSet $win $mark $old [$win mark gravity $mark]]
    }
    Undo_Record $win $undoCmd \
	    [list Text_MarkSet $win $mark [$win index $index] $gravity]
    $win mark set $mark $index
    if {[string compare $mark "insert"] != 0} {
	$win mark gravity $mark $gravity
    }
}

proc Text_MarkUnset {win args} {
    foreach mark $args {
	Undo_Record $win \
	    [list Text_MarkSet $win $mark [$win index $mark] [$win mark gravity $mark]] \
	    [list Text_MarkUnset $win $mark]
	$win mark unset $mark
    }
}

proc Text_CreateWindow {win index widget args} {
    Undo_Record $win [list Text_Delete $win $widget $widget] \
	    [concat [list Text_CreateWindow $win $index $widget] $args]
    eval {$win window create $index -window $widget} $args
}


# Text_Insert is in bed with undo so it can go fast when
# undo is disabled, which happens during initial page display.
proc Text_InsertForUndo {win mark string tags} {
    upvar #0 Undo$win undo
    set m1 [$win index $mark]
    $win insert $m1 $string $tags
    if [info exists undo] {
	set l [string length $string]
	if {$l > 0} {
	    Undo_Record $win \
		[list Text_Delete $win $m1 [$win index "$m1 +$l c"]] \
		[list Text_Insert $win $m1 $string $tags]
	}
    }
}

######### Below is support for undoing deletions ##############

# This is tricky because the indices change as a result of partial deletions:
# If the user selects "abcd" and deletes it, we may encounter text segments
# "ab" and "cd" because of a mark or something.  As a result, all the undo
# and redo operations will start at the same index, the very first one, and
# not necessarily the index passed into the TextUndoTextProc iterator.

proc TextUndoTextProc {stateVar win key value ix} {
    upvar $stateVar state
    # Log text up to this point, if any
    TextUndoTextDel state $win $ix
    if {$key == "text"} {
	set state(text) $value
	set state(textlen) [string length $value]
	return
    }
    switch -- $key {
	window {
	    TextSaveWindow state $win $value $ix
	}
	tagon {
	    if {[lsearch $state(tags) $value] < 0} {
		lappend state(tags) $value
	    }
	}
	tagoff {
	    set ix [lsearch $state(tags) $value]
	    if {$ix >= 0}  {
		set state(tags) [lreplace $state(tags) $ix $ix]
	    }
	}
    }
}
proc TextUndoTextDel {stateVar win endix} {
    upvar $stateVar state
    if [info exists state(text)] {
	Undo_Record $win \
		[list Text_Insert $win $state(m1) $state(text) $state(tags)] \
		[list Text_Delete $win $state(m1) "$state(m1) +$state(textlen) c"]
	unset state(text)
	unset state(textlen)
    }
}
proc TextUndoTagRemoveProc {stateVar win key value ix} {
    upvar $stateVar state
    switch -- $key {
	tagon {
	    if {[string compare $value $state(tag)] == 0} {
		set state(ix) $ix
	    }
	}
	tagoff {
	    if {[string compare $value $state(tag)] == 0} {
		TextUndoTagRemove state $win $ix
	    }
	}
    }
}
proc TextUndoTagRemove {stateVar win endix} {
    upvar $stateVar state
    if [info exists state(ix)] {
	Undo_Record $win \
		[list Text_TagAdd $win $state(tag) $state(ix) $endix] \
		[list Text_TagRemove $win $state(tag) $state(ix) $endix]
	unset state(ix)
    }
}
proc TextUndoTagAddProc {stateVar win key value ix} {
    upvar $stateVar state
    if [info exists state(tag)] {
        switch -- $key {
            tagon {
                if {[string compare $value $state(tag)] == 0} {
                    TextUndoTagAdd state $win $ix
                }
            }
            tagoff {
                if {[string compare $value $state(tag)] == 0} {
                    set state(ix) $ix
                }
            }
        }
    }
}
proc TextUndoTagAdd {stateVar win endix} {
    upvar $stateVar state
    if [info exists state(ix)] {
	Undo_Record $win \
		[list Text_TagRemove $win $state(tag) $state(ix) $endix] \
		[list Text_TagAdd $win $state(tag) $state(ix) $endix]
	unset state(ix)
    }
}
proc TextSaveWindow {stateVar win name ix} {
    upvar $stateVar state
    set blob [list [winfo class $name] $name [$win configure]]
    foreach child [winfo children $win] {
	lappend blob [TextSaveWindow state $win $child {}]
    }
    if {[string length $ix] == 0} {
	return $blob
    } else {
	Undo_Record $win \
		[list TextRebuildWindow $win $blob $state(ix) $state(tags)] \
		[list Text_Delete $win $ix $ix]
    }
}
proc TextRebuildWindow {win blob {ix {}} {tags {}}} {
    set class [lindex $blob 0]
    set name [lindex $blob 1]
    set config [lindex $blob 2]
    [string tolower $class] $name
    foreach conf $config {
	$name config [lindex $conf 0] [lindex $conf 4]
    }
    foreach child [lrange $blob 3 end] {
	set w [TextRebuildWindow $win $child]
	pack $w	;# surely wrong
    }
    if {[string length $ix]} {
	$win create window $ix -window $name
	foreach tag $tags {
	    $win add tag $tag $ix
	}
    } else {
	return $name
    }
}
