proc SeditCiteSelectionPar { draft t } {
    global sedit address
    if [catch {selection get} txt] {
        SeditMsg $t "No selection"
        return
    }
    $t insert insert "\n$address wrote:\n"
    regsub -all "(\n|^)" $txt "\\1$sedit(pref,replPrefix)" txt
    set res [exec par -rTbgqR -B=.\?_A_a -Q=_s\>\| $sedit(lineLength) << $txt]
    $t insert insert "$res\n"
}

proc SeditCiteSelectionNoFmt { draft t } {
    global sedit address
    if [catch {selection get} txt] {
        SeditMsg $t "No selection"
        return
    }
    $t insert insert "\n$address wrote:\n"
    regsub -all "(\n|^)" $txt "\\1$sedit(pref,replPrefix)" txt
    $t insert insert "$txt\n"
}

proc Sedit_FormatParagraphPar { t } {
    global sedit address
    if [catch {$t index "sel.first linestart"} first] {
	set first [$t index "insert linestart"]
	set last [$t index "insert lineend"]
	while 1 {
	    set line [$t get $first "$first lineend"]
	    set len [string length $line]
	    if {$len == 0} {
		break
	    }
	    set first [$t index "$first - 1line"]
	    if {[regexp ^-- $line] || [$t compare $first <= hlimit]} {
		break
	    }
	}
	set first [$t index "$first + 1line"]
	while 1 {
	    set line [$t get "$last linestart" $last]
	    set len [string length $line]
	    if {($len == 0) || [regexp ^-- $line]} {
		set last [$t index "$last - 1line lineend +1char"]
		break
	    }
	    set nlast [$t index "$last + 1line lineend"]
	    if {[$t compare $nlast == $last]} {
		break
	    }
	    set last $nlast
	}
    } else {
	set last [$t index "sel.last lineend"]
    }
    set line [$t get $first "$last -1char"]
    set tags [$t tag names $first]
    SeditMsg $t "Reformatting paragraph..."
    if [catch {set fmtline [exec par -rTbgqR -B=.\?_A_a -Q=_s\>\| $sedit(lineLength) << [set line]]}] {
      SeditMsg $t "par error"
    } else {
      $t delete $first $last
      $t mark set insert $first
      if {[string compare "" $fmtline] != 0} {
        $t insert insert "$fmtline\n"
      }
      SeditMsg $t ""
    }
    $t mark set insert "insert -1char"
}
proc SeditSelFmt {t} {
    global sedit

    if [catch {selection get} txt] {
	SeditMsg $t "No selection"
	return
    }

    set res [exec par -rTbgqR -B=.\?_A_a -Q=_s\>\| $sedit(lineLength) << $txt]
    if ![catch {$t index sel.first} tndx] {
        $t delete sel.first sel.last
    } else {
	set tndx [$t index insert]
    }
    $t mark set insert $tndx
    $t insert insert "$res\n"
}


proc SeditSelFmtArg {t} {
    global par sedit
    set par(t) $t

    if [catch {selection get} par(txt)] {
	SeditMsg $t "No selection"
	return
    }
    if [Exwin_Toplevel .par "Format" Format] {
	set par(options) "rTbgqR"
	set par(body) ".?_A_a"
	set par(quote) "_s>|"
	set par(protect) ""
	set par(width) $sedit(lineLength)
	.par.but.quit configure -command {Exwin_Dismiss .par nosize}
	Widget_BeginEntries 7 17
	Widget_LabeledEntry .par.options "Options:" par(options)
	Widget_LabeledEntry .par.body "Body:" par(body)
	Widget_LabeledEntry .par.quote "Quote:" par(quote)
	Widget_LabeledEntry .par.protect "Protect:" par(protect)
	Widget_LabeledEntry .par.width "Width:" par(width)
	Widget_AddBut .par.but format "Format" {
	    Exmh_Status "Formatting Selection"
	    if [catch {exec par -$par(options) -B=$par(body) -Q=$par(quote) -P=$par(protect) $par(width) << $par(txt)} res] {
	        Exmh_Status "Error: Invalid options for Par" warning
	    } else {
            	if ![catch {$par(t) index sel.first} tndx] {
                    $par(t) delete sel.first sel.last
           	} else {
    	            set tndx [$par(t) index insert]
            	}
            	$par(t) mark set insert $tndx
            	$par(t) insert insert "$res\n"
	    	Exmh_Status ""
	    	Exwin_Dismiss .par nosize
	    }
	}
    }
}


proc SeditSelSpell { f t } {
    global sedit editor wish

    set parent [file root $f]
    catch {[destroy $parent.spell]}

    if [catch {selection get} txt] {
	SeditMsg $t "No selection"
	return
    }

    set path [Env_Tmp]/exmh.s[pid].[file tail $t]
    set out [open $path w 0600]
    puts $out $txt
    close $out

    switch -- $sedit(spell) {
	ispell {set prog {exmh-async xterm -e ispell}}
	custom {set prog $editor(spell)}
	default {set prog spell}
    }
    if [string match exmh-async* $prog] {
	# exmh-async isn't really right
	# craft a wish script instead
	set script [Env_Tmp]/exmh.w[pid].[file tail $t]
	if [catch {open $script w 0600} out] {
	    Exmh_Status $out
	    return 0
	}
	puts $out "wm withdraw ."
	puts $out "catch \{"
	puts $out "exec [lrange $editor(spell) 1 end] $path"
	puts $out "\}"
	puts $out [list send [winfo name .] [list SeditReplaceSel $t $path]]
	puts $out "file delete -force $path"
	puts $out "file delete -force $script"
	puts $out exit
	close $out
	exec $wish -f $script &
	return
    }

    # Display the results of the spell program
    catch {eval exec $prog {$path}} result
    catch {file delete -force $path}

    set f2 [Widget_Frame $parent spell {top fill}]

    set lines [llength [split $result \n]]
    set height [expr {$lines > 8 ? 8 : $lines}]
    set t2 [Widget_Text $f2 $height]
    $t2 configure -height $height	;# Widget_Text broken
    $t2 insert 1.0 $result
    $t2 config -state disabled
    pack $f2 -before $f -side top
}

proc SeditReplaceSel { t infile } {
    set in [open $infile]

    if ![catch {$t index sel.first} tndx] {
        $t delete sel.first sel.last
    } else {
	set tndx [$t index insert]
    }

    $t mark set insert $tndx
    $t insert insert [read -nonewline $in] 

    close $in
}


