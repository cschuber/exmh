#
# unseenwin.tcl - display a little window with unseen counts in it
#
# hacked into exmh by Olly Stephens <olly@zycad.com>
#


proc UnseenWinSetGeom {width height} {
    incr width 4
    .unseen.lb configure -width $width -height $height
}

proc UnseenWinSetSelection {{which -1}} {
    .unseen.lb select clear 0 end
    if {$which != -1} {
      .unseen.lb select set $which
    }
}

proc UnseenWinToggle {args} {
  global unseenwin flist

if [catch {
  if {$unseenwin(on) && ![winfo exists .unseen]} {
    Exwin_Toplevel .unseen "exmhunseen" UnseenWin no
    listbox .unseen.lb -exportselection no -font $unseenwin(font) \
                       -relief flat -bd 2
    .unseen.lb configure -highlightthickness 0
    UnseenWinSetGeom $unseenwin(minwidth) $unseenwin(minlines)
    pack .unseen.lb -fill both

    bind .unseen.lb <1> {UnseenWinClick %y b1mode}
    foreach b { Shift-1 Control-1 Control-Shift-1 } {
      bind .unseen.lb <$b> {UnseenWinClick %y mb1mode}
    }
    foreach b { B1-Motion Shift-B1-Motion Control-B1-Motion
                2 B2-Motion
                3 B3-Motion Control-3 Control-Shift-3 } {
      bind .unseen.lb <$b> {;}
    }
    bind .unseen.lb <ButtonPress-3> {UnseenWinButton3 press %X %Y}
    bind .unseen.lb <Any-ButtonRelease-3> {UnseenWinButton3 release}

    UnseenWinToggleIcon
    UnseenWinToggleClick

    set unseenwin(curwidth)  $unseenwin(minwidth)
    set unseenwin(curlines)  $unseenwin(minlines)
    set unseenwin(listwidth) $unseenwin(minwidth)
    set unseenwin(empty)     1
    set unseenwin(folders)   {}

    if {![info exists flist(unseen)] ||
        ([llength $flist(unseen)] == 0)} {
      UnseenWinEmptyMsg
    } else {
      foreach f $flist(unseen) {
        UnseenWinAdd $f $flist(new,$f)
      }
    }
    trace variable flist wu UnseenWinTrace

  } elseif {!$unseenwin(on) && [winfo exists .unseen]} {
    trace vdelete flist w UnseenWinTrace
    destroy .unseen
  }
} error] {
    Exmh_Status "UnseenWinToggle error"
    Exmh_Debug UnseenWinToggle error: $error
}
}

proc UnseenWinTrace {array elem op} {
  global flist unseenwin

  if [catch {
    if {[scan $elem "new,%s" folder] != 1} {
      return
    }
    if [info exists flist($elem)] {
      set num $flist($elem)
    } else {
      set num 0
    }
    set index [lsearch $unseenwin(folders) $folder]
    if {$index == -1} {
      if {$num > 0} {
        UnseenWinAdd $folder $num
      }
    } else {
      if {$num == 0} {
        UnseenWinRemove $index $folder
      } else {
        UnseenWinShow $index 1 $folder $num
      }
    }
  } error] {
    if {[string length $error]} {
      Exmh_Debug UnseenWinTrace error: $error
    }
  }
}

proc UnseenWinShow {index delete folder count} {
  global unseenwin

  if $delete {
    .unseen.lb delete $index
  }
  set width $unseenwin(listwidth)
  .unseen.lb insert $index [format "%${width}s %2d" $folder $count]
  if {$width > $unseenwin(curwidth)} {
    .unseen.lb xview [expr $width - $unseenwin(curwidth)]
  }
}

proc UnseenWinAdd {folder num} {
  global unseenwin flist

  set index [llength $unseenwin(folders)]

  if {$index == 0} {
    if $unseenwin(hidewhenempty) {
      catch {wm deiconify .unseen}
      raise .unseen
    }
    .unseen.lb delete 0 end
  } elseif {$index < $unseenwin(curlines)} {
    .unseen.lb delete end
  }

  set newlines $index
  set newwidth [string length $folder]

  set hasmaxlines [expr $unseenwin(maxlines) >= $unseenwin(minlines)]
  set hasmaxwidth [expr $unseenwin(maxwidth) >= $unseenwin(minwidth)]

  set resize 0
  set redisplay 0

  if {($index >= $unseenwin(minlines)) &&
      (!$hasmaxlines || ($unseenwin(curlines) < $unseenwin(maxlines)))} {
    incr unseenwin(curlines)
    set resize 1
  }
  if {$newwidth > $unseenwin(listwidth)} {
    set redisplay 1
    set unseenwin(listwidth) $newwidth
    if {!$hasmaxwidth || ($unseenwin(curwidth) < $unseenwin(maxwidth))} {
      set resize 1
      if {$hasmaxwidth && ($newwidth > $unseenwin(maxwidth))} {
        set unseenwin(curwidth) $unseenwin(maxwidth)
      } else {
        set unseenwin(curwidth) $newwidth
      }
    }
  }

  if $resize {
    UnseenWinSetGeom $unseenwin(curwidth) $unseenwin(curlines)
  }
  if {($unseenwin(listwidth) > $unseenwin(curwidth)) ||
      ($index >= $unseenwin(curlines))} {
    bind .unseen.lb <2> {%W scan mark %x %y}
    bind .unseen.lb <B2-Motion> {%W scan dragto %x %y}
  }
  if {$index == 0} {
    for {set i 1} {$i < $unseenwin(curlines)} {incr i} {
      .unseen.lb insert end " "
    }
  }
  if $redisplay {
    set i 0
    foreach f $unseenwin(folders) {
      UnseenWinShow $i 1 $f $flist(new,$f)
      incr i
    }
  }
  UnseenWinShow $index 0 $folder $num
  lappend unseenwin(folders) $folder
}

proc UnseenWinRemove {index folder} {
  global unseenwin flist

  set unseenwin(folders) [lreplace $unseenwin(folders) $index $index]
  set newlines [llength $unseenwin(folders)]
  .unseen.lb delete $index

  set resize 0
  set redisplay 0

  if {[string length $folder] == $unseenwin(listwidth)} {
    set newwidth 0
    foreach f $unseenwin(folders) {
      set len [string length $f]
      if {$len > $newwidth} {
        set newwidth $len
      }
    }
    if {$newwidth < $unseenwin(minwidth)} {
      set newwidth $unseenwin(minwidth)
    }
    if {$newwidth < $unseenwin(listwidth)} {
      set redisplay 1
      if {$newwidth < $unseenwin(curwidth)} {
        set resize 1
        set unseenwin(curwidth) $newwidth
      }
      set unseenwin(listwidth) $newwidth
    }
  }
  if {($newlines < $unseenwin(curlines)) &&
      ($newlines >= $unseenwin(minlines))} {
    incr unseenwin(curlines) -1
    set resize 1
  }

  if $resize {
    UnseenWinSetGeom $unseenwin(curwidth) $unseenwin(curlines)
  }
  if {($unseenwin(listwidth) == $unseenwin(curwidth)) &&
      ($newlines <= $unseenwin(curlines))} {
    bind .unseen.lb <2> {;}
    bind .unseen.lb <B2-Motion> {;}
  }
  if {$newlines == 0} {
    UnseenWinEmptyMsg
  } else {
    if $redisplay {
      set i 0
      foreach f $unseenwin(folders) {
        UnseenWinShow $i 1 $f $flist(new,$f)
        incr i
      }
    }
    while {$newlines < $unseenwin(curlines)} {
      .unseen.lb insert end " "
      incr newlines
    }
  }
}

proc UnseenWinToggleIcon {args} {
  global unseenwin

  if [winfo exists .unseen] {
    set already [expr [string compare [wm iconwindow .] .unseen] == 0]
    if {$unseenwin(icon) && !$already} {
      wm iconwindow . .unseen
    } elseif $already {
      wm iconwindow . {}
      catch {wm deiconify .unseen}
    }
  }
}

proc UnseenWinToggleClick {args} {
  global unseenwin

  if [winfo exists .unseen] {
    if {[string match "W*" $unseenwin(b1mode)] ||
        [string match "W*" $unseenwin(mb1mode)]} {
      bind .unseen.lb <Leave> {UnseenWinSetSelection}
      bind .unseen.lb <Motion> {UnseenWinMove %y}
    } else {
      UnseenWinSetSelection
      bind .unseen.lb <Leave> {;}
      bind .unseen.lb <Motion> {;}
    }
  }
}

proc UnseenWinChangeFont {args} {
  global unseenwin

  if [winfo exists .unseen] {
    set old [lindex [.unseen.lb configure -font] 4]
    if {[catch {
      .unseen.lb configure -font $unseenwin(font)
    } err] != 0} {
      set unseenwin(font) $old
    }
  }
}

proc UnseenWinChangeMinMax {args} {
  global unseenwin flist
  if {[catch {expr $unseenwin(minlines)}] ||  $unseenwin(minlines) < 1} {
    set unseenwin(minlines) 1
  }
  if {[catch {expr $unseenwin(minwidth)}] || $unseenwin(minwidth) < 5} {
    set unseenwin(minwidth) 5
  }
  if {[catch {expr $unseenwin(maxlines)}]} {
    set unseenwin(maxlines) $unseenwin(minlines)
  }
  if {[catch {expr $unseenwin(maxwidth)}]} {
    set unseenwin(maxwidth) $unseenwin(minwidth)
  }
  if [winfo exists .unseen] {
    # Trigger the trace
    set unseenwin(on) 0
    set unseenwin(on) 1
  }
}

proc UnseenWinEmptyMsg {args} {
  global unseenwin

  if {[winfo exists .unseen] && ([llength $unseenwin(folders)] == 0)} {
    if $unseenwin(hidewhenempty) {
      catch {wm withdraw .unseen}
      return
    } elseif (!$unseenwin(icon)) {
      catch {wm deiconify .unseen}
    }
    set elen [string length $unseenwin(emptymsg)]
    set pad [expr ((($unseenwin(listwidth) + 4) - $elen) / 2) + $elen]
    set empty [expr (($unseenwin(curlines) + 1) / 2) - 1]
    .unseen.lb delete 0 end
    set index 1
    while {$index < $unseenwin(curlines)} {
      .unseen.lb insert end " "
      incr index
    }
    .unseen.lb insert $empty [format "%${pad}s" $unseenwin(emptymsg)]
    .unseen.lb yview 0
    .unseen.lb xview 0
    UnseenWinSetSelection
  }
}
  
proc UnseenWinMove {y} {
  global unseenwin

  set entry [.unseen.lb nearest $y]

  if {$entry < [llength $unseenwin(folders)]} {
    UnseenWinSetSelection $entry
  } else {
    UnseenWinSetSelection
  }
}

proc UnseenWinClick {y mode} {
  global unseenwin exmh

  set mode $unseenwin($mode)

  if {[string compare $mode None] == 0} {
    return
  }

  set entry [.unseen.lb nearest $y]

  if {($entry < [llength $unseenwin(folders)]) &&
      ([string compare $mode Raise] != 0)} {
    set folder [lindex $unseenwin(folders) $entry]
    if {[string compare $exmh(folder) $folder] != 0} {
      if {[string compare $mode Warp] == 0} {
        Folder_Change $folder
      } else {
        Folder_Change $folder Msg_ShowUnseen
      }
    } elseif {[string compare $mode "Warp & Show"] == 0} {
      Msg_ShowUnseen
    }
  }

  wm deiconify .
  raise .
  update idletasks
}

proc UnseenWinButton3 {action {x 0} {y 0}} {
  global unseenwin

  switch $unseenwin(b3mode) {
    Nothing {
      return
    }
    Compose {
      if {[string compare $action release] == 0} {
        Msg_Compose
      }
    }
  }
}
