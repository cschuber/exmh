# formtag.tcl
#
# This file has the code that displays form elements.
#
##########################################################
# html forms management commands

# As each form element is located, it is created and rendered.  Additional
# state is stored in a form specific global variable to be processed at
# the end of the form, including the "reset" and "submit" options.
# Remember, there can be multiple forms existing on multiple pages.  When
# HTML tables are added, a single form could be spread out over multiple
# text widgets, which makes it impractical to hang the form state off the
# HM$win structure.  We don't need to check for the existance of required
# parameters, we just "fail" and get caught in HMrender

# This causes line breaks to be preserved in the inital values
# of text areas
array set HMtag_map {
	textarea    {fill 0}
}

# FormElement is called by the forms parser when it adds a form-related
# widget to the main display.  We use this callback to build up information
# about the form when it is first displayed.

# - win:  name of the text widget
# - type: the form element type:
#	radio, check, text, submit, reset, isindex, select, option, textarea
# - param: the tag parameters
# - item: name of widget to install

proc FormElement {win formVar type param item} {
    upvar #0 $formVar form
    if {$type != "option"} {
	Win_Install $win $item -align bottom
    }
    dputs $win $formVar $type $param $item

    set widget $item	;# true in most cases
    switch -- $type {
	select {
	    set widget $item.list
	    lappend form(select) $widget
	    set form(curSelect) $widget
	}
	option {
	    set form(values,$form(curSelect)) $form(select_values)
	    if [info exists form(select_default)] {
		set form(default,$form(curSelect)) $form(select_default)
	    }
	    return	;# Don't clobber form(widgets,) info for select
	}
	textarea {
	    # Save the initial text for reset,
	    # and the widget for later output.
	    set widget $item.text
	    set form(textarea,$item) [$widget get 1.0 end]
	}
    }
    set info [list $type $param $item [Mark_Current $win]]
    set form(widgets,$widget) $info
    if {[Input_Edit $win]} {
	bindtags $widget FormEdit
    }
}
# - win:  name of the text widget
# - item: name of widget to install

proc Win_Install {win item args} {
	upvar #0 HM$win var
	eval {Text_CreateWindow $win $var(S_insert) $item} $args
	Text_TagAdd $win indent$var(level) $item
	foreach t [HMcurrent_tags $win] { # was $var(listtags)
	    Text_TagAdd $win $t $item
	}
	catch {unset var(newline)}	;# We are taking up a line, at least
	set var(trimspace) 1		;# But don't want spaces
	set focus [expr {[winfo class $item] != "Frame"}]
	$item configure -takefocus $focus
	Head_SetColors $win $item
	bind $item <FocusIn> "$win see $item"
	dputs "inserted $item"
}


##########################################################
# html isindex tag.  Although not strictly forms, they're close enough
# to be in this file

# is-index forms
# make a frame with a label, entry, and submit button

proc HMtag_isindex {win param text} {
	upvar #0 HM[Window_GetMaster $win] var

	set item $win.$var(tags)
	if {[winfo exists $item]} {
		destroy $item
	}
	frame $item -relief ridge -bd 3
	set prompt "Enter search keywords here"
	HMextract_param $param prompt
	label $item.label -text $prompt -font $var(xfont)
	entry $item.entry
	dputs "made entry and label"
	bind $item.entry <Return> "$item.submit invoke"
	button $item.submit -text search -font $var(xfont) -command \
		[format {HMsubmit_index %s {%s} [HMmap_reply [%s get]]} \
		$win $param $item.entry]
	pack $item.label -side top
	pack $item.entry $item.submit -side left

	# insert window into text widget

	Text_Insert $win $var(S_insert) \n isindex
	FormElement $win $var(form_id) isindex $param $item
	Text_Insert $win $var(S_insert) \n isindex
	bind $item <Visibility> {focus %W.entry}
}

# This is called when the isindex form is submitted.
# The default version calls HMlink_callback.  Isindex tags should either
# be deprecated, or fully supported (e.g. they need an href parameter)

proc HMsubmit_index {win param text} {
	dputs "Isindex submitted: $win $text"
	HMlink_callback $win ?$text
}

# initialize form state.  All of the state for this form is kept
# in a global array whose name is stored in the form_id field of
# the main window array.
# Parameters: ACTION, METHOD, ENCTYPE

proc HMtag_form {win param text} {
	upvar #0 HM[Window_GetMaster $win] var

	# create a global array for the form
	set formVar HM$win.form[incr var(S_formid)]
	upvar #0 $formVar form

	# Guard against missing /form tag
	catch {
	    HMtag_/form $win {} {}
	}
	catch {unset form}
	set var(form_id) $formVar

	# Use marks to deliniate forms because a tag like form=$id
	# is awkward to maintain in parallel with the H:form tag
	Text_MarkSet $win form=$var(S_formid) insert left

	set form(param) $param		;# form initial parameter list
	set form(uid)	$var(tags)	;# for unique variable names
	HMform_install $win $param $formVar
}
proc HMform_install {win param formVar} {
    # should save info for form submission?
}
proc HMtag_/form {win param text} {
	upvar #0 HM[Window_GetMaster $win] var
	unset var(form_id)
	Text_MarkSet $win /form=$var(S_formid) insert left
}

proc Form_SetID {win mark} {
    upvar #0 HM$win var
    for {set id 1} {$id <= $var(S_formid)} {incr id} {
	if {[catch {$win index /form=$id}] ||
		[$win compare $mark <= /form=$id]} {
	    break
	}
    }
    # This is a pointer to the current state about a form
    set var(form_id) HM$win.form$id
}

###################################################################
# handle form input items
# each item type is handled in a separate procedure
# Each "type" procedure needs to:
# - create the window
# - initialize it
# - add the "submit" and "reset" commands onto the proper Q's
#   "submit" is subst'd
#   "reset" is eval'd

proc HMtag_input {win param text} {
	upvar #0 HM[Window_GetMaster $win] var
	set type text	;# the default
	HMextract_param $param type
	set type [string tolower $type]
	if {[catch {HMinput_$type $win $var(form_id) $param} err]} {
		Exmh_Debug "HMtag_input $err"
	}
}

# input type=text
# parameters NAME (reqd), MAXLENGTH, SIZE, VALUE

proc HMinput_text {win formVar param {show {}}} {
	upvar #0 HM[Window_GetMaster $win] var
	upvar #0 $formVar form

	# make the entry
	HMextract_param $param name		;# required
	set item $win.input_text,[incr form(uid)]
	set size 20; HMextract_param $param size
	set maxlength 0; HMextract_param $param maxlength
	entry $item -width $size -show $show

	# support for tclvalue computed values
	if [HMextract_param $param tclvalue] {
	    if ![catch {Micro_Subst $win $tclvalue} x] {
		set value $x
	    }
	}

	# support for tclvar variable references
	if [HMextract_param $param tclvar] {
	    upvar #0 $tclvar z
	    if [info exists z] {
		set value $z
	    }
	    $item configure -textvariable $tclvar
	}

	# set the initial value
	if ![info exists value] {
	    set value ""
	    HMextract_param $param value
	}
	$item delete 0 end
	$item insert 0 $value
		
	# insert the entry
	FormElement $win $formVar "input" $param $item
	# handle the maximum length (broken - no way to cleanup bindtags state)
	if {$maxlength} {
		bindtags $item "[bindtags $item] max$maxlength"
		bind max$maxlength <KeyPress> "%W delete $maxlength end"
	}
}

# password fields - same as text, only don't show data
# parameters NAME (reqd), MAXLENGTH, SIZE, VALUE

proc HMinput_password {win formVar param} {
	HMinput_text $win $formVar $param *
}

# checkbuttons are missing a "get" option, so we must use a global
# variable to store the value.
# Parameters NAME, VALUE, (reqd), CHECKED

proc HMinput_checkbox {win formVar param} {
	upvar #0 $formVar form HM$win var

	set name check
	HMextract_param $param name
	set value 1
	HMextract_param $param value

	# support for tclvahlue computed values
	if [HMextract_param $param tclvar] {
	    upvar #0 $tclvar z
	    if [info exists z] {
		set value $z
	    }
	    set variable $tclvar
	}

	# Set the global variable, don't use the "form" alias as it is not
	# defined in the global scope of the button
	if ![info exists variable] {
	    set variable $formVar\(check_[incr form(uid)])
	}
	set item $win.input_checkbutton,[incr form(uid)]
	checkbutton $item -variable $variable -off {} -on $value -text "  "
	if {[HMextract_param $param checked]} {
		$item select
	}

	FormElement $win $formVar "input" $param $item
}

# radio buttons.  These are like check buttons, but only one can be selected

proc HMinput_radio {win formVar param} {
	upvar #0 HM$win var $formVar form

	HMextract_param $param name
	HMextract_param $param value

	# support for tclvar associated with form element
	if [HMextract_param $param tclvar] {
	    set variable $tclvar
	}

	# Set the global variable, don't use the "form" alias as it is not
	# defined in the global scope of the button
	if ![info exists variable] {
	    set variable $formVar\(radio_$name)
	}
	set first [expr ![info exists form(radio_$name)]]
	set item $win.input_radiobutton,[incr form(uid)]
	radiobutton $item -variable $variable -value $value -text " "

	FormElement $win $formVar "input" $param $item

	if {$first || [HMextract_param $param checked]} {
		$item select
	}
}

# hidden fields, just append to the "submit" data
# params: NAME, VALUE (reqd)

proc HMinput_hidden {win formVar param} {
	upvar #0 HM$win var $formVar form
	HMextract_param $param name
	# support for tclvalue computed values
	if [HMextract_param $param tclvalue] {
	    if ![catch {Micro_Subst $win $tclvalue} x] {
		set value $x
	    }
	}
	# support for tclvar variable references
	if [HMextract_param $param tclvar] {
	    upvar #0 $tclvar z
	    if [info exists z] {
		set value $z
	    }
	}
	# set the initial value
	if ![info exists value] {
	    set value ""
	    HMextract_param $param value
	}
	if ![info exists form(hidden_id)] {
	    set form(hidden_id) 0
	} else {
	    incr form(hidden_id)
	}
	set form(widgets,hidden$form(hidden_id)) [list input $param]
}

# handle input images.  The spec isn't very clear on these, so I'm not
# sure its quite right
# Use std image tag, only set up our own callbacks
#  (e.g. make sure ismap isn't set)
# params: NAME, SRC (reqd) ALIGN

proc HMinput_image {win formVar param} {
	upvar #0 HM$win var $formVar form
	HMextract_param $param name
	set name		;# barf if no name is specified
	set item [HMtag_img $win $param {}]
	$item configure -relief raised -bd 2 -bg blue
	dputs "Made the image, waiting for callback"

	# We have to get the %x,%y in the value somehow, so calculate it during
	# binding, and save it in the form array for later processing

	$item configure -takefocus 1
	bind $item <FocusIn> "catch \{$win see $item\}"
	bind $item <1> "$item configure -relief sunken"
	bind $item <Return> "
		set $var(form_id)(X) 0
		set $var(form_id)(Y) 0
		[list FormSubmit $win $formVar $param]
	"
	bind $item <ButtonRelease-1> "
		set $var(form_id)(X) %x
		set $var(form_id)(Y) %y
		$item configure -relief raised
		[list FormSubmit $win $formVar $param]
	"
	dputs "Done"
}

# Set up the reset button.  Wait for the /form to attach
# the -command option.  There could be more that 1 reset button
# params VALUE

proc HMinput_reset {win formVar param} {
	upvar #0 HM$win var $formVar form

	set value reset
	HMextract_param $param value

	set item $win.input_reset,[incr form(uid)]
	button $item -text $value \
		-command [list FormReset $win $formVar $param]
	FormElement $win $formVar "input" $param $item
}

# Set up the submit button.  Wait for the /form to attach
# the -command option.  There could be more that 1 submit button
# params: NAME, VALUE

proc HMinput_submit {win formVar param} {
	upvar #0 HM$win var $formVar form

	HMextract_param $param name
	set value submit
	HMextract_param $param value
	set item $win.input_submit,[incr form(uid)]
	button $item -text $value -fg blue \
		-command [list FormSubmit $win $formVar $param]
	FormElement $win $formVar "input" $param $item
}

#########################################################################
# selection items
# They all go into a list box.  We don't what to do with the listbox until
# we know how many items end up in it.  Gather up the data for the "options"
# and finish up in the /select tag
# params: NAME (reqd), MULTIPLE, SIZE 

proc HMtag_select {win param text} {
    upvar #0 HM[Window_GetMaster $win] var
    upvar #0 $var(form_id) form

    HMextract_param $param name
    set size 5;  HMextract_param $param size
    set form(select_size) $size
    set form(select_name) $name
    set form(select_values) ""		;# list of values to submit
    if {[HMextract_param $param multiple]} {
	    set mode multiple
    } else {
	    set mode single
    }
    set item $win.select,[incr form(uid)]
    frame $item
    set form(select_frame) $item
    listbox $item.list -selectmode $mode -width 0 -exportselection 0
    FormElement $win $var(form_id) select $param $item
    # Register an output procedure
    proc Output$item {stateVar win widget} [info body FormSelectOutput]
}

# select options
# The values returned in the query may be different from those
# displayed in the listbox, so we need to keep a separate list of
# query values.
#  form(select_default) - contains the default query value
#  form(select_frame) - name of the listbox's containing frame
#  form(select_values)  - list of query values
# params: VALUE, SELECTED

proc HMtag_option {win param text} {
    upvar #0 HM[Window_GetMaster $win] var
    upvar #0 $var(form_id) form
    upvar $text data
    set frame $form(select_frame)

    # set default option (or options)
    if {[HMextract_param $param selected]} {
        lappend form(select_default) [$form(select_frame).list size]
    }
    set value [string trimright $data " \n"]
    $frame.list insert end $value
    HMextract_param $param value
    lappend form(select_values) $value
    set data ""
    FormElement $win $var(form_id) option $param $form(select_frame)
}
 
# do most of the work here!
# if SIZE>1, make the listbox.  Otherwise make a "drop-down"
# listbox with a label in it
# If the # of items > size, add a scroll bar
# This should probably be broken up into callbacks to make it
# easier to override the "look".

proc HMtag_/select {win param text} {
	upvar #0 HM[Window_GetMaster $win] var
	upvar #0 $var(form_id) form
	set frame $form(select_frame)
	set size $form(select_size)
	set items [$frame.list size]

	if {[info exists form(select_default)]} {
		foreach i $form(select_default) {
			$frame.list selection set $i
		}
	} else {
		$frame.list selection set 0
	}
	# show the listbox - no scroll bar

	if {$size > 1 && $items <= $size} {
		$frame.list configure -height $items
		pack $frame.list

	# Listbox with scrollbar

	} elseif {$size > 1} {
		scrollbar $frame.scroll -command "$frame.list yview"  \
				-orient v -takefocus 0
		$frame.list configure -height $size \
			-yscrollcommand "$frame.scroll set"
		pack $frame.list $frame.scroll -side right -fill y

	# This is a joke!

	} else {
		scrollbar $frame.scroll -command "$frame.list yview"  \
			-orient h -takefocus 0
		$frame.list configure -height 1 \
			-yscrollcommand "$frame.scroll set"
		pack $frame.list $frame.scroll -side top -fill x
	}

	# cleanup

	foreach i [array names form select_*] {
		unset form($i)
	}
}

# do a text area (multi-line text)
# params: COLS, NAME, ROWS (all reqd, but default rows and cols anyway)

proc HMtag_textarea {win param text} {
	upvar #0 HM[Window_GetMaster $win] var
	upvar #0 $var(form_id) form
	upvar $text data

	set rows 5; HMextract_param $param rows
	set cols 30; HMextract_param $param cols
	HMextract_param $param name
	set item $win.textarea,[incr form(uid)]
	frame $item -class Textarea
	text $item.text -width $cols -height $rows -wrap none \
			-yscrollcommand "$item.scroll set" -padx 3 -pady 3
	scrollbar $item.scroll -command "$item.text yview"  -orient v
	$item.text insert 1.0 $data
	FormElement $win $var(form_id) textarea $param $item
	pack $item.text $item.scroll -side right -fill y
	set data ""
	# Register an output procedure
	proc Output$item {stateVar win widget} [info body FormTextAreaOutput]
}

#################### Submit support #######################
# The Submit and Reset handlers

proc FormSubmit {win formVar param} {
    upvar #0 HM[Window_GetMaster $win] var $formVar form
    set var(form_id) $formVar
    set query {}

    dputs $win $formVar $param
    # The name/value on a submit button might be used for identification
    HMextract_param $param value
    HMextract_param $param name
    if ![info exists name] {
	set name submit
    }
    if [info exists value] {
	lappend query [list $name $value]
    }
    # Suck values from the rest of the form elements
    FormIterate $win $formVar {FormSubmitQuery query}

    # Map into the proper format
    set newquery {}
    foreach pair $query {
	set value [lindex $pair 1]
	if {$value != ""} {
	    set item [lindex $pair 0]
	    lappend newquery $item $value
	}
    }
    # this is the user callback.
    if ![info exists form(param)] {
	error "No form parameters, only [array names form]"
    }
    HMsubmit_form $win $form(param) $newquery

}

# TODO - Figure out how to get the state from type=image
proc FormSubmitQuery {qVar win formVar type htag param widget} {
    upvar #0 HM$win var $formVar form
    upvar $qVar query
    set name $type
    HMextract_param $param name
    set tclvar {}
    if [HMextract_param $param tclvar] {
	upvar #0 $tclvar z
	if [info exists z] {
	    set value $z
	}
    }
    if ![info exists value] {
	set value {}
	HMextract_param $param value	;# handles "hidden", too
    }
    dputs $win $formVar $type $htag $param $widget
    switch -- $type {
	option -
	reset -
	submit {
	    return
	}
	select {
	    set list $widget
	    set sel [$list curselection]
	    for {set i 0} {$i < [$list size]} {incr i} {
		if {[lsearch $sel $i] >= 0} {
		    lappend query [list $name [lindex $form(values,$widget) $i]]
		}
	    }
	    return
	}
	radio -
	checkbox {
	    upvar #0 [$widget cget -variable] x
	    set value $x
	}
	password -
	text {
	    set value [$widget get]
	}
	textarea {
	    set value [$widget get 1.0 end]
	}
	image {
	    error "The editor doesn't do form image maps, yet"
	}
    }
    if {$type == "radio"} {
	if {[lsearch $query [list $name $value]] >= 0} {
	    return
	}
    }
    lappend query [list $name $value]
}
proc FormReset {win formVar param} {
    FormIterate $win $formVar FormResetItem
}
proc FormResetItem {win formVar type htag param widget} {
    upvar #0 HM[Window_GetMaster $win] var $formVar form
    set var(form_id) $formVar
    switch -- $type {
	select {
	    set list $widget
	    $list selection clear 0 end
	    if [info exists form(default,$list)] {
		foreach ix $form(default,$list) {
		    $list select set $ix
		}
	    } else {
		    $list select set 0
	    }
	}
	radio {
	    $widget deselect
	    if [HMextract_param $param checked] {
		$widget select
	    }
	}
	checkbox {
	    if {[HMextract_param $param checked]} {
		    $widget select
	    } else {
		    $widget deselect
	    }
	}
	password -
	text {
	    $widget delete 0 end
	    if {[HMextract_param $param value]} {
		    $widget insert 0 $value
	    }
	}
	textarea {
	    set t $widget
	    $t delete 1.0 end
	    $t insert 1.0 $form(textarea,[winfo parent $widget])
	}
    }
}
proc FormIterate {win formVar callback} {
    upvar #0 HM[Window_GetMaster $win] var $formVar form
    foreach w [array names form widgets,*] {
        regsub ^widgets, $w {} w
	lassign {htag param} $form(widgets,$w)
	if {"$htag" == "input"} {
	    set type text
	    HMextract_param $param type
	} else {
	    set type $htag
	}
	uplevel [concat $callback [list $win $formVar $type $htag $param $w]]
    }
}

proc HMsubmit_form {win param query} {
	set mainwin [Window_GetMaster $win]
	upvar #0 HM$mainwin var
	set result ""
	set sep ""
	set text {}
	dputs param $param
	foreach i $query {
		append result  $sep [HMmap_reply $i]
		append text $i
		if {$sep != "="} {
		    set sep =
		    append text " = "
		} else {
		    set sep &
		    append text \n
		}
	}
	set action $var(S_url)
	HMextract_param $param action
	set method GET
	HMextract_param $param method
	if {![Input_Edit $win]} {
	    dputs HMlink_callback $method $action $result
	    if {$method == "GET"} {
		    HMlink_callback $mainwin $action?$result
	    } else {
		    HMlink_callback $mainwin $action $result
	    }
	   # return
	} else {
	    # Otherwise just display the query
	    set t .submit.t
	    if [winfo exists .submit] {
		raise .submit
	    } else {
		toplevel .submit -bd 4 -relief raised
		wm group .submit .
		wm title .submit "Submit Results"
		wm iconname .submit "Submit Results"
		text $t -width 50 -height 30 -yscrollcommand {.submit.s set}
		scrollbar .submit.s -command "$t yview"
		pack .submit.s -side right -fill y
		pack $t -side left -expand true -fill both
	    }
	    $t delete 1.0 end
	    $t insert insert "Form attributes:\n"
	    foreach x [split $param] {
		$t insert insert "  $x\n"
	    }
	    $t insert insert "\nRaw query:\n"
	    $t insert insert $result\n
	    $t insert insert "\nForm values:\n"
	    $t insert insert $text
	}
}

