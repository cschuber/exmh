#################################################################################
# TCL Interactive Spell Checker Version 1.01 
# Developed for use in EXMH by John McLaughlin (johnmcl@sr.hp.com) 6/7/97
# 
# This new spell checking code for EXMH was developed out of
# frustration with the current spell checking EXMH code
# mostly I could not get it to work the way I wanted it to.
# Because I couldn't get the spell checker to work as well
# as I would like, I found myself spending inordinate amounts
# of time when writing e-mail, constantly fretting over
# the spelling.  This little piece of code is the result
# and seems to work pretty well in my environment.  I have
# tested this under both linux (redhat 4.0) HPUX 9.05
# 
# This software operates in one of two different
# modes, it can either spell check as you type, marking words
# in a variety of ways (underline, bold, italic, etc) that are
# not spelled correctly.  Also it can put a button in the sedit
# window to allow in place spell checking. (The button option
# requires changes to your .exmh-defaults file)
#
# This code depends on the excellent 'ispell' program and most
# of the variables & procedure's get their name from it.
# This code was developed under ispell v3.1.20
#
#######################################################################
#             INSTALLATION
# to Use: 3 easy steps (Note: EXMH should not be running when you do this)
#
# Note 2: This may be incorporated into a 'core' EXMH release in 
# the future so below may not be required.....
#
# 1) add to the file ~/.tk/exmh/user.tcl in the function 'User_Init'
#    a call to ispell_Preferences.  If you don't have a user.tcl
#    get one, Usually it can be found in '/usr/local/exmh-<version>'
#    where <version> is the version of exmh you are running
# 
#    if you are really desperate for a user.tcl the following
#    should work (just make a file called user.tcl with the
#    following line.....
#    proc User_Init {} { ispell_Preferences }
#
# 
# 2) add the following to your .exmh-defaults at the TOP of the file
# 
# *Sedit.Menubar.ubuttonlist: ispell
# *Sedit.Menubar.ispell.text: Ispell	    
# *Sedit.Menubar.ispell.command: Ispell_CheckEntireWindow $t
#
# 3) in your ~/.tk/exmh directory type 'wish' then type 
#         auto_mkindex . *.tcl
#    then type 'exit'
# 
#  
# That should be it!  There should be a preferences menu for 'I-Spell' now to allow
# control of various parts of the ispell package... Also the 'Sedit' window should
# have a 'ispell' button to check the entire document...
# if a word is marked misspelled right click on it to add to dictionary or
# select an alternate version
#
############## Trouble Shooting ######################
#
# Did you make sure that....
# Ispell was turned on? (from preferences/I-spell  menu)
# A 'Miss-Spelled word style' is selected? (from preferences/I-spell)
# the User Library directory is ~/.tk/exmh (preferences/Hacking Support)
# the changes above were made with EXMH NOT running?
#
# You are using the correct version of ispell?  it works against ispell
# version 3.0 & 3.1, version 4.0 (which seems to be a sort of 'non product'
# is reported NOT to work.  most un*x users seem to have 3.1 installed..
#
############## Performance ##########################
#
# This spell checker seems to operate without any 
# obvious performance drag when typing in sedit
# with enough ram, most modern workstations should 
# be able to use this without any obvious performance hit
# I find running it under Linux with a 40mb P90
# quite comfortable
# as a few benchmarks, this software can spell check
# a 2700 word letter in 12 seconds on a P90 running
# linux (redhat 4.0) with 40mb of ram.  other 
# timing results indicate a user can expect 
# a 1.3ms to 3.0ms additional delay for
# correctly spelled words, and up to 30ms
# for words not spelled correctly.  As always
# ram helps, ram starved machines will 
# not fair as well
######################################################
#
# Enjoy, if you find it useful or have any comments
# please let me know (johnmcl@sr.hp.com) also if you 
# make any improvements please send them to me
#
# John McLaughlin, HP Santa Rosa, January 1997 (johnmcl@sr.hp.com)
######################################################

#########################################################
# ispell_init is called to start the entire process off
#########################################################
proc Ispell_Init { } { 
    global ispellVars

    if {! [ info exists ispellVars(currentLanguage) ] } {
	set ispellVars(currentLanguage) ""
    }

    if { $ispellVars(currentLanguage) == $ispellVars(language) } return ; 

    set ispellVars(currentLanguage) $ispellVars(language)  ; # mark current language


    # These things are now specified by the 'Preferences' menu
    #    a good choice f0or the spell command is "ispell -a"
    #   
    set ispellVars(last_word) "dummy" 
    # this variable are the alternate spellings of the misspelled word...
    set ispellVars(choices) "" 

    # how to view, see the text.n man page for other ideas
    # options include -background <color> -foreground <color> 
    # -font <font> etc..
    #    set ispellVars(viewStyle) "-underline t"

    if { [ info exists ispellVars(spell_buffer) ] } {
	if { [catch {
	    close $ispellVars(spell_buffer)
	} reason] } {
	     Exmh_Debug Ispell Buffer Closed:$reason
	}
    }

    if {!$ispellVars(on)} {
	set ispellVars(currentLanguage) "disabled"
    }
    if {$ispellVars(currentLanguage) == "disabled"} {
	catch {unset ispellVars(spell_buffer) }
	return ;
    }

    if {[info exists ispellVars(command)]} {
	set cmd $ispellVars(command)
    } else {
	set cmd $ispellVars(defaultCommand)
    }
    if [catch {open "|$cmd" r+} ispellVars(spell_buffer)] {
	set ispellVars(on) 0	;# triggers trace
	return
    }

    # Poke the process because:
    # 4.0 doesn't respond with a full line, so gets hangs
    # 2.0 doesn't output a version number.
    # We only like 3.*

    puts $ispellVars(spell_buffer) "?"
    flush $ispellVars(spell_buffer)
    gets $ispellVars(spell_buffer) line
    set version {"unknown"}
    if {([string compare $line *] == 0) ||
	([regexp {[Vv]ersion ([0-9])\.} $line x version] &&
	    $version != 3)} {
	# Oh No!  Why are you not running version 3.X???
	# specifically version 4.0 doesn't work!!!
	Exmh_Status "Ignoring ispell version $version (3.* required)"
	catch { close $ispellVars(spell_buffer) } reason
	set ispellVars(on) 0
	return
    }
    #
    # Since this is the right version, we need to read the (blank) reply to
    # the "?" we sent...
    #
    gets $ispellVars(spell_buffer) line

    IspellWriteSpellBuffer "!" ; # enter terse mode
}

######################
# preferences
######################

proc Ispell_Preferences {} { 

    Preferences_Add "I-Spell" \
	    "This is a module to allow interactive spelling within a sedit window
it has many fine features include suggested correction and the ability
to add new words to a session or to your personnel dictionary.
For words that are either not correct or not generated 
by a combination of roots or compounds, the word is marked as not
spelled correctly." { 

	{ ispellVars(on) ispellOnOff ON {Turn Ispell On/Off} 
	"This turns the ispell feature on/off.  Note that the feature
	needs to be enabled BEFORE a message is brought up" } 

	{ ispellVars(ReCheckAfterAdd) ispellRecheckAfterAdd ON {Re-Verify after Adds?} 
	"Check this box if you want to re spell check words 
	currently marked Miss Spelled after you add to the dictionary 
	or session.  In general a good idea except if you work 
	in extremely long documents a small delay may be noticed 
	after you add words to your personal dictionary
	Additionally the right mouse button can be used to
	accept suggested words" }

	{ ispellVars(textOnly) ispellTextOnly OFF {Spell Check 'Text' only?} 
	"Check this box if you want to only perform spell checking 
of the text marked as 'text', this should avoid spell checking 
To:, CC: & X-Face: lines, it comes at a small time penalty, turn it off
if you want to see a small improvement in response time
Note that turning this option on will also not spell check 'attachements'
unless they are marked as Content-Type: text/enriched or text/plain.
if you find that spell checking STOPS working in a section of the document you
may want to turn this off" }

	{ ispellVars(defaultCommand) ispellCommand "ispell -a -S" {Default speller invocation}
	"This is the program used to actually do the real work
'ispell -a' is probably a good choice.  if you want to 
use an alternate dictionary, 'ispell -a -d <dictionary-file>' may be 
appropriate. you may find that -S sorts the list of possible
words better, see the ispell(1) man page for more details.
(really, it's got a lot of details and you can really personalize
how it works to fit best with your environment" } 
	{ ispellVars(otherCommands) ispellOthers " German  { ispell -a -d deutsch } \
		French { ispell -a -d francais } English { ispell -a -d english } " { Other Invocations }
	"Alternate Invocations of of the 'Ispell' programs, mostly intended for 
our friends in Europe who have to work in a variety of languages, this entry should
be in label/invocation pairs" } 

	
	{ ispellVars(popupBinding) ispellPopupBinding "ButtonPress-3" {Menu popup bound to:}
	" This controls what the 'popup' window is bound to, some examples include:
ButtonPress-3 
ButtonPress-2
ButtonPress-1
Shift-3
Control-3
Meta-2
Alt-1
etc...

Note that the menu is unposted on any ButtonRelease" }

	{ ispellVars(viewStyle) ispellStyle {CHOICE underline italic bold bgcolor fgcolor other } {Miss-spelled word style}
	" this is how to display misspelled words
	use the built in types or create your own
	using 'other', for 'color' ones fill in the color 
	examples using other include 
	-underline t
	-background red
	-foreground Bisque
	-font <font>
	-fgstipple <bitmap>
	-bgstipple <bitmap>

	Bitmap's can be many things, 'gray50' and 'gray25' are popular

	For example....

	-font *italic*
	or   -font *bold*
	or   -font *24*    (Big!)

	or   -font *italic*24* (big italics)

	-relief <relief> (see tk doc's for more info...)

	
	Effects can also be combined as in 
	
	-underline t -foreground red
	-bgstipple gray25 -color red

	
	" } 
	{ ispellVars(viewStyle-Color) ispellStyleColor red {color:} 
	"color for fgcolor and bgcolor" }
	{ ispellVars(viewStyle-Other) ispellStyleOther {-underline t -foreground red}  {other:}
	"Style if 'other' is selected" }
    }
    if { [ info exists ispellVars(CheckButton) ] } {
	if {$ispellVars(CheckButton) == 1} {

	    option add *Sedit.Menubar.ubuttonlist {ispell}
	    
	    option add *Sedit.Menubar.ispell.text {Ispell}
	    
	    option add *Sedit.Menubar.ispell.command {Ispell_CheckEntireWindow $t}
	}
    }
    global ispellVars
    set ispellVars(language) default
    trace variable ispellVars(on) w IspellOnOff    
}

proc IspellOnOff {args} {
    global ispellVars
    catch {unset ispellVars(currentLanguage)}
    Ispell_Init
}



# a safe procedure to write to the ispell buffer
# this procedure dumps the variable 'word' to the spell buffer
# if the buffer has died, it will restart it

proc IspellWriteSpellBuffer { word } {
    global ispellVars
    
    if {$ispellVars(currentLanguage) == "disabled"} { return * } ;

    puts $ispellVars(spell_buffer) $word
    if { [ catch { flush $ispellVars(spell_buffer) } ] } {
	Exmh_Debug "Ispell process terminated!!!!!, temp disabling"
	set ispellVars(language) disabled
	Ispell_Init
	return "*" ; # return if we had to restart
    }
}

# This procedure kills the ispell buffer
# 
proc Ispell_Kill {} { 
    global ispellVars
    close $ispellVars(spell_buffer)
    set ispellVars(on) 0
}

##########################################
# this is the proc that does the 
# actual spell checking, it will return a 
# '*' if everything is cool, otherwise
# it returns a list of possible miss-spelled
# words.  See ispell(1) for more details
proc IspellWords line { 
    global ispellVars

    regsub -all { +} $line { } line		;# compress out extra spaces
    set count [llength [split $line { }]]	;# Count space separated words
    set result ""

    if { $ispellVars(currentLanguage) == "disabled" } { return "*" } ;

    # clear out the fileevent
    if { [ catch {fileevent $ispellVars(spell_buffer) readable {} } ] } {
	Ispell_Init
	return "*"
    }
    # so the puts stuff doesn't freak out
    # CRITCAL prepend a '^' to keep the buffer from freaking
    puts $ispellVars(spell_buffer) "^$line"
    # we have to put the ^ in front of the line so ispell works correctly
    # see ispell(1) for more details
    if { [ catch { flush $ispellVars(spell_buffer) } ] } {
	Exmh_Debug "Ispell process terminated!!!!!, restarting"
	Ispell_Init
	return "*" ; # return if we had to restart
    }

    # loop through list of words, usually there is just 1
    for { set i 0 } { $i <= $count } {  incr i } { 
	gets $ispellVars(spell_buffer) var
	if {$var == {} } then {
	    lappend result "*";
	    break;
	}
	lappend result $var
    }
    # invoke a fileevent to help flush out the data so wer are always in sync
    fileevent $ispellVars(spell_buffer) readable {
	global ispellVars
	gets $ispellVars(spell_buffer) dummy 
    }
    return $result
}


# this proc spell checks the word under the current cursor
# marking it with a 'MissSpelled' tag if it is in fact incorrect
# text is the text window
# This version runs about 300us slower than the previous
# version using tk's built in 'wordstart' and 'wordend'
# (1.3ms vs 1.7ms)

proc IspellTextWindow { text } { 

#################
# WARNING
# CHANGES FOR SUPPORT OF EUROPEAN CHARACTERS!!
##########################
    set start [ $text get "insert linestart" insert ]
    
    set end   [ $text get insert "insert lineend" ] 
    
    set e1 ""
    set s1 ""
    
    regexp "\[^\t \]*" $end e1
    set e1 [ string trim $e1 ] 
    regexp "\[^\t \]+$" $start s1
    
    set startIndex "insert - [string length $s1] chars"
    set stopIndex "insert + [string length $e1] chars "

    set word "[ string trim $s1$e1 "\"\{\}\[\] \t" ] "

    IspellMarkWord $text $startIndex $stopIndex $word 
}

# this Proc is to spell check words that with 'inserts'
# i.e. after 'space', 'tab' etc.... This version
# runs at exactly the same speed as the tk built
# in version (1.3ms) so I feel pretty comfortable
# that this shouldn't effect speed too much
# all test times were gotten via 'time' 
# and thus may have some errors (especially 
# with regexps, I think the system compiles
# them).  In this version I can't use
# tk's built in 'word' functions because
# they don't allow for european characters....

proc IspellTextWindowInsert { text } { 
#################
# WARNING
# CHANGES FOR SUPPORT OF EUROPEAN CHARACTERS!!
##########################
    set start [ $text get "insert linestart" insert ]
    
    set s1 ""
    
    # now let's pick off the last word
    regexp "\[^\t ]+$" $start s1


    set startIndex "insert - [string length $s1] chars"
    set stopIndex "insert" 

    set word " [ string trim $s1 "\"\{\}\[\]  \t" ] "

    IspellMarkWord $text $startIndex $stopIndex $word 

}

####################################################
# proc to mark words in the text window, with the given 
# indexes, the 'word' is the word in question
####################################################
proc IspellMarkWord {text startIndex stopIndex word} {

    global ispellVars ;

    #first let's not mark the word bad if we aren't in a section marked 'type=text*"

    if {$ispellVars(textOnly)} {
	if { ! [ string match "*type=text*" [ $text tag names insert ] ] } { return * } ;
    }

    set result [ IspellWords $word ];
    #    * means fine, + means a root?, - means compount controlled by -C  option of ispell
    if { ! [regexp {^[*+-]} $result ] } {
	$text tag add MissSpelled $startIndex $stopIndex
	set prompt "Suggested for $word: [ lreplace [ lindex $result 0 ] 0 3 ]"
	# EXMH Specific 
	SeditMsg $text $prompt
	
    } else {
	$text tag remove MissSpelled $startIndex "$stopIndex +1c"
    }
    
    set ispellVars(last_word) $word ; # store word so we don't re-check next
    # time
    return $result
}


##############################################################
# Proedure to call to mark words after the dictionary has been
# modified, called from within the 'add' menus.....
# 
##############################################################

proc IspellReCheckBuffer { window startIndex stopIndex word } { 
    global ispellVars;
    
    # first let's make sure it's a real word....
    if { $word == "" } return ;

    IspellMarkWord $window $startIndex $stopIndex $word; 

    # check word requested
    if { [ info exists ispellVars(ReCheckAfterAdd) ] }  {
	
	if { $ispellVars(ReCheckAfterAdd) } { 
	    IspellReCheckWords $window ; 
	    # re-check buffer if requested..
	}   
    }
}

##########################################################
# This proc will take the word currently under the mouse pointer
# spell check it, and pop up a menu with suggestions or allowing
# additions to the ispell-dictionary
# 'text' is the text window, x,y are the co-ordinates relative to the
# window, X,Y are the co-ordinates relative to the root window
##########################################################

proc IspellPostMenuChoices { text x y   X Y } { 

    global ispellVars;

    set adjustment {} 
    set oldInsert [ $text index insert ] 
    $text mark set insert "@$x,$y"

    set start [ $text get "insert linestart" insert ]
    
    set end   [ $text get insert "insert lineend" ] 
    
    set e1 ""
    set s1 ""
    
    regexp "\[^\t \]*" $end e1
    set e1 [ string trim $e1 ] 
    regexp "\[^\t \]+$" $start s1

    set startIndex "insert - [string length $s1] chars"
    set stopIndex "insert + [string length $e1] chars "
    set word $s1$e1

    set word [ string trim $word  "\]\[\.\,\<\>\/\?\!\@\#\%\*0123456789\&\@\(\)\:\;\$ \{\}\"\\ \'\~\`\_\-\+\t\n\r\b\a\f\v\n "]   
    set word [ string trim $word ]

#    set stopIndex [ $text index "@$x,$y wordend"  ]
#    set startIndex [ $text index "$stopIndex  - 1 chars wordstart" ]
#    set word  " [ string trim [ $text get $startIndex "$stopIndex wordend" ] \
#	    "\@\(\)\:\;\$ \{\}\"\\ \t\n\r\b\a\f\v\n "] " ; # "
#    set word [ string trim $word ] ; # get rid of white space

    # if there is no word to mention, don't even post a menu...

    if { $word == "" } return ; 

    set result [ IspellMarkWord $text $startIndex $stopIndex $word ]

    $text mark set insert $oldInsert ; # get it back where it belongs
    # create a meanu
    set menu "$text.m"
    catch { 
	destroy $menu
    }
    menu $menu -tearoff f

    # remember the menu name so we can unpost it later.
    set ispellVars(PopupMenu) $menu
    
    # first let's label the menu with the current language
    $menu add command -label $ispellVars(language) -state disabled

    # now if spell checking is disabled, let's mark menus as such
    set disFlag normal
    if { $ispellVars(currentLanguage) == "disabled" } {
	set disFlag "disabled" 
    }

    $menu add separator 

    $menu add command -label "Add '$word' to Dictionary" -command  \
	    "IspellWriteSpellBuffer \"*$word\";\
	    IspellWriteSpellBuffer \#;\
	    IspellReCheckBuffer $text \"$startIndex\" \"$stopIndex\" $word;" -state $disFlag
    # add word to dictionary, save dictionary, recheck word
    
    $menu add command -label "Accept '$word' for this session" -command \
	    "IspellWriteSpellBuffer \"@$word\";\
	    IspellReCheckBuffer $text \"$startIndex\"  \"$stopIndex\" $word;" -state $disFlag
    # add word for this session, recheck word

    $menu add separator
    foreach i   [ split [ lreplace [ lindex $result 0 ] 0 3 ] "," ]   {
	set choice [ string trim $i ", " ]
	$menu add command -label $choice -command "IspellReplaceWordInText $text $x $y \"$choice\" " 
    }
    $menu add separator

    menu $menu.sub -tearoff f

    $menu.sub add radiobutton -label "disabled" \
	    -command "set ispellVars(language) disabled ;
    set ispellVars(command) \"\";
    Ispell_Init" -variable ispellVars(language) -value "disabled"


    $menu.sub add radiobutton -label "default" \
	-command "set ispellVars(language) default ;
	    set ispellVars(command) \"$ispellVars(defaultCommand)\";
	    Ispell_Init" \
	-variable ispellVars(language) -value "default"

    set count [ llength $ispellVars(otherCommands) ] 
    for { set i 0 } { $i < $count } { incr i 2 } {
	set lab  [ lindex $ispellVars(otherCommands) $i ]
	set command  [ lindex $ispellVars(otherCommands) [ expr $i +1 ]  ]
	$menu.sub add radiobutton -label "$lab " \
	    -command  " set ispellVars(language)  \"$lab\" ; 
		    set ispellVars(command) \"$command\"; 
		    Ispell_Init"  \
	    -variable ispellVars(language) -value "$lab"                       
    }
    
    $menu add cascade -label "Alternate..." -menu $menu.sub

    tk_popup $menu $X $Y 
}

#######################################################
#
# Procedure called to Unpost 
# the menu
#######################################################
proc IspellUnPostMenuChoices {window } { 
    global ispellVars

    catch {
	tkMenuUnpost $ispellVars(PopupMenu)
    }
}

#########################################################
# This proc will replace whatever word is listed at x,y
# with 'word'  It goes to some lengths to keep surrouning
# punctuation.
#########################################################
proc IspellReplaceWordInText { text x y word } { 

    set oldInsert [ $text index insert ] 

    $text mark set insert "@$x,$y"
    
    set start [ $text get "insert linestart" insert ]
    
    set end   [ $text get insert "insert lineend" ] 
    
    set e1 ""
    set s1 ""
    
    regexp "\[^\t \]*" $end e1
    set e1 [ string trim $e1 ] 
    regexp "\[^\t \]+$" $start s1

    # If we are being asked to replace a word, first remove the tag
    # so that whatever highlighting is there will be gone.
    $text tag remove MissSpelled "insert - [string length $s1] chars" "insert + [string length $e1] chars "

    # Now let's clean up that string a bit..... remove punctuation & stuff
 
    set e1 [ string trim [ string trim $e1 ] "\]\[\.\,\<\>\/\?\!\@\#\%\*0123456789\&\@\(\)\:\;\$ \{\}\"\\ \'\~\`\_\-\+\t\n\r\b\a\f\v\n "]   

    set s1 [ string trim [ string trim $s1 ] "\]\[\.\,\<\>\/\?\!\@\#\%\*0123456789\&\@\(\)\:\;\$ \{\}\"\\ \'\~\`\_\-\+\t\n\r\b\a\f\v\n "]   


    # now let's remove the old word & insert the new word.

    set startIndex "insert - [string length $s1] chars"
    set stopIndex "insert + [string length $e1] chars "
    set startInsert [ $text index $startIndex ] 

    $text delete $startIndex $stopIndex 
    $text insert $startInsert $word
    $text mark set insert $oldInsert ; # get it back where it belongs
}

##########################################################
# EXMH Specific procedure to bind the window in question 
# note that this has to be in the current process
# it won't automagically be sucked in
# a call to 'IspellPreferences' should do the trick...
##########################################################
proc Hook_SeditInit_TagMissSpelled { file window } {
    global ispellVars
    # only configure the window for ispell support if it is
    # actually needed, and if the appropriate variables exist
    # 
    # bind the window.....
    # use default style of underline
    set style "-underline t"

    if { [ catch {    
	switch -exact -- $ispellVars(viewStyle) \
		underline  { set style "-underline t"} \
		italic     { set style "-font *italic*" } \
		bold       { set style "-font *bold*"}  \
		other      { set style "$ispellVars(viewStyle-Other)" } \
		bgcolor    { set style "-background $ispellVars(viewStyle-Color)" } \
		fgcolor    { set style "-foreground $ispellVars(viewStyle-Color)" }
	
	eval  $window tag configure MissSpelled $style
    } result ] } { 	
	tk_dialog .window "Bad Style" \
		"Invalid I-Spell style: '$result' changing to underline" \
		{} 0 ok
	eval $window tag configure MissSpelled -underline t
    }
    
    # Only bind the window if 'ispell' is turned on...
    if { [ info exists ispellVars(on) ] } {
	if { $ispellVars(on) == 1 } { 
	    set ispellVars($window,effect) 1
	    Ispellbind $window 

	}
    }

    set ispellVars(command) $ispellVars(defaultCommand)

    set ispellVars(language) "default" 

    # Only init the spell checker if it had already not been previously init'd
    if { ! [ info exists ispellVars(spell_buffer) ] } { 
	Ispell_Init ; # init if the spell buffer is undefine
    }
} 

# this procedure re-checks the entire buffer in the
# window specified by 'window'
proc Ispell_CheckEntireWindow { text } { 
    global ispellVars


    set oldInsert [ $text index insert ] 

    set count 0
    # First things first, because this function COULD be called without
    # using any of the other ispell stuff, first ensure that the ispell 
    # process is running...
    # Only init the spell checker if it had already not been previously init'd

    if { ! [ info exists ispellVars(spell_buffer) ] } { 
	Ispell_Init ; # init if the spell buffer is undefine
    }

    # Pop up a little window to allow spell checking to be turned off......
    #
    set ispellVars(label) "Stop Spell Checking"
    catch { destroy .ispellStopWindow }
    set top [ toplevel .ispellStopWindow ] 
    wm group .ispellStopWindow .
    button $top.b  -textvariable ispellVars(label) -command { 
	set ispellVars(label) "" 
    }
    label $top.l1 -bitmap warning
    label $top.l2 -bitmap warning
    
    pack $top.l1 -side left
    pack $top.b -side left
    pack $top.l2 -side left
    
    set endOfDoc [ $text index end ] ; # get the last index mark
    set current 1.0

    # here is the actual code to spell check the document
    while { [ expr $current < $endOfDoc ] }  {

	if { $ispellVars(label) == "" } { break}
	$text mark set insert "$current"
	set start [ $text get "insert linestart" insert ]
	
	set end   [ $text get insert "insert lineend" ] 
	set e1 ""
	set s1 ""
	
	regexp "\[^\t \]*" $end e1
#	set e1 [ string trim $e1 ] 
	regexp "\[^\t \]+$" $start s1
	
	set startIndex "insert - [string length $s1] chars"
	set stopIndex "insert + [string length $e1] chars "
	
	set word "[ string trim $s1$e1 "\"\{\}\[\]" ] "
	
	set current [ $text index "$stopIndex + 2 chars" ]

	if {[string length $word] == 1} continue; # speed up process for small words....

	incr count
	update

	if { $count > 120 } {
	    
	    $text see $current
	    set count 0
	}

	IspellMarkWord $text $startIndex $stopIndex $word 
    }
    
    destroy $top
    # now let's redisplay the screen at the insert point....
    $text mark set insert "$oldInsert"
    $text see insert
}


########################################################
# procedure to re-check bound words to reconfirm they
# are still missspelled
# note that if quite a few words are missSpelled this could
# take quite a while.... Also note that this should probably
# only be called AFTER the dictionary has changed/updated
########################################################

proc IspellReCheckWords {window} { 
    global ispellVars
    

    set ranges [ $window tag ranges MissSpelled ] 
    set ispellVars(label) "Stop Spell Checking"
    set wcount 0

    if { [ expr [ llength $ranges ] > 100 ] } { 
	# Only pop up a window if
	# 100 or so need to be re-checked.
	catch {
	    destroy .ispellStop
	}

	toplevel .ispellStop
	button .ispellStop.b  -textvariable ispellVars(label) -command { 
	    set ispellVars(label) "" 
	}
	label .ispellStop.l1 -bitmap warning
	label .ispellStop.l2 -bitmap warning
	
	pack .ispellStop.l1 -side left
	pack .ispellStop.b -side left
	pack .ispellStop.l2 -side left
    }

    # loop through all the current words marked as misspelled
    #
    for { set i 0 } { $i < [ expr [llength $ranges] / 2 ] } { incr i } {
	set startIndex [ lindex $ranges [ expr $i*2 ] ] 
	set stopIndex  [ lindex $ranges [ expr $i*2+1 ] ]
	
	if { [ $window compare "$startIndex + 1 chars" == "$stopIndex" ] } {
	    $window tag remove MissSpelled $startIndex "$stopIndex +1c"
	}
	set word  " [ string trim [ $window get $startIndex $stopIndex ] \
		 " \t\"\{\}\[\]"] " ; # "
	if { $ispellVars(label) == "" } { break }

	incr wcount
	if { $wcount > 20 } {
	    $window see $startIndex
	    set wcount 0
	}

	update
	set result [ IspellMarkWord $window $startIndex $stopIndex $word ]

    }

    # destroy the toplevel window

    catch {
	destroy .ispellStop
    }

    # put the window back under the insert cursor

    $window see insert
}


# Call this procedure with the text window path to bind the spell command

proc Ispellbind { text } { 

    global ispellVars;

    set command {IspellTextWindow %W} ; 
    

    bind $text <Key-space> "IspellTextWindowInsert %W"
    bind $text <Key-Tab> "IspellTextWindowInsert %W" 
    
    bind $text <Key-Right> "$command"   
    bind $text <Key-Left>  "$command"    
    bind $text <Key-Down>  "$command"
    bind $text <Key-Up>    "$command"
    
    bind $text <Key-Return> " $command "
    
    # How do we correct words? Normally button-3!
    bind $text <$ispellVars(popupBinding)> { 
	IspellPostMenuChoices %W %x %y %X %Y 
    } ;

    # no user configurable way to select the unpost...
    # tk_popup should unpost the menu for us automatically
#    bind $text <Any-ButtonRelease> { IspellUnPostMenuChoices %W } 
    
}


    
    







