# 
# extrasInit.tcl
#
# This has initialization code for some extra packages.
# The idea is to avoid auto_loading the whole package,
# while still allowing the package to manifest itself
# in the preferences dialog (for example).
#
# Copyright (c) 1993 Xerox Corporation.
# Use and copying of this software and preparation of derivative works based
# upon this software are permitted. Any distribution of this software or
# derivative works must comply with all applicable United States export
# control laws. This software is made available AS IS, and Xerox Corporation
# makes no warranty about the software, its performance or its conformity to
# any specification.

proc TopTenPreferences {} {
    Preferences_Add "The Top Ten" \
"Exmh has too many preferences.  Some of the more important ones are
collected here.  The preferences panel they come from is identified
in the extended help information for each item." {

	{ exmh(background) bgAction {CHOICE off count msgchk flist inc hook} {Background processing}
"exmh can periodically do some things for you:
count - count new messages sitting in your spool file.
msgchk - run the MH msgchk program.
flist - check for new mail in all folders.
inc - just like clicking the Inc button yourself.
hook - suppply your own Hook_Background procedure.
off - do nothing in the background.
(Background Processing Preferences.)"}

	{inc(style) incStyle	{CHOICE inbox presort multidrop presortmulti custom none} {Ways to Inc}
"inbox - basic MH inc from your spool file to inbox folder.
presort - slocal filtering directly into various folders.
multidrop - slocal filtering or POP delivery into various drop boxes,
as specified by ~/.xmhcheck, that are in turn inc'ed into folders.
presortmulti - presort + multidrop.
custom - use an Inc_Custom procedure, which is user supplied.
none - you have an external agent that handles inc for you, so
don't bother trying it from within exmh.
(Incorporate Mail Preferences.)"}

	{editor(prog) editCmd sedit {Editor command}
"The editor command used to compose mail messages.
The filename will be appended to the command.
\"sedit\" is the built-in editor.
Example commands include:
sedit
emacsclient &
give-away emacsclient
gnuclient &
give-away gnuclient
exmh-async emacs
exmh-async emacsclient
exmh-async xterm -e vi
(Editor Support Preferences.)"}

    {ftoc(autoCommit) autoCommit OFF "Auto Commit"
"If set, Exmh will invoke the Commit operation to
commit deletions and refiles when it would otherwise
just complain that such a commit is required.
(Scan Listing Preferences.)"}

	{uri(scanForURIs) uriScanForURIs	OFF {Scan for URLs in messages}
"This tells exmh to automatically scan for URLs in messages.
If you turn it on, any URLs it finds will be turned into buttons
which you can click on to launch a viewer application.
This can slow down message displaying somewhat, 
so you may prefer to do this manually by typing <Key-z>
(WWW Preferences.)"}

	{exwin(scrollbarSide) scrollbarSide {CHOICE left right} {Scrollbar side}
"Which side the scrollbars appear on.  This
only takes effect after you restart exmh.
(Windows & Scrolling Preferences.)"}

	{ unseenwin(on) unseenWinOn OFF {Enable Unseen Window}
"Enables the window that summarizes your unseen messages.
(Unseen Window Preferences.)" }

	{ sound(enabled) soundEnabled ON {Sound feedback}
"Enable audio feedback.  Exmh will make a sound when
new messages are incorporated into your folders
(except during startup) and when you try to change
folders without committing moves and delete operations.
(Sound Preferences.)"} 

	{faces(enabled) facesEnabled ON {Use faces database}
"Search for and display images from the facesaver database.
(Faces Preferences.)"}
	{
            addr_db(enabled)
            addressdbEnabled
            ON
            "Automatic address saving"
            "If set, From addresses are remembered and available in an address browser."
	}

    }
}

proc SlowDisplay_Init {} {
    global exmh

    Preferences_Add "Slow Display" \
"These items determine which parts of the system to disable when you have a 
slow display" {
        {exmh(slowDispLimit) slowDispLimit 200000	{Slow Display Limit}
"This is the microsecond count used to determine if the user is on a
\"slow display\"."}
        {exmh(slowDispFaces) slowDispFaces OFF {Show faces on a slow display}
	"Do faces processing if the display is slow"}
        {exmh(slowDispIcons) slowDispIcons OFF {Show color icons on a slow display}
	"Use color icons if the display is slow."}
    }
    Preferences_Resource exmh(testglyph) testGlyph flagdown.gif
    if ![string match /* exmh(testglyph)] {
	set exmh(testglyph) $exmh(library)/$exmh(testglyph)
    }
    set time [lindex [time {
	toplevel .foo
	pack [canvas .foo.c]
	image create photo testicon -file $exmh(testglyph)
	.foo.c configure -width [image width testicon] \
		-height [image height testicon]
	destroy .foo
    }] 0]
    set exmh(slowDisp) [expr {$time > $exmh(slowDispLimit)}]
    if $exmh(slowDisp) {
	Exmh_Debug "Slow display: $time"
    } else {
	Exmh_Debug "Fast display: $time"
    }
}

proc Faces_Init {} {
    global faces
    if {$faces(dir) == {}} {
	set faces(enabled) 0
    }
    # faces(suffix) starts out (by default) with {xpm gif xbm}
    if {![info exists faces(suffix)] || ([llength $faces(suffix)] == 0)} {
	set faces(suffix) xbm
    }
    # Double check the non-standard pixmap image type to avoid file stat
    if {[lsearch [image types] pixmap] < 0} {
	set ix [lsearch $faces(suffix) xpm]
	if {$ix >= 0} {
	    set faces(suffix) [lreplace $faces(suffix) $ix $ix]
	}
    }

    Preferences_Add "Faces" \
"Exmh will display a bitmap or image of the person that sent the current message (or their organization).  This relies on the faces/picon database, or the presence of an X-Face: mail header.

Any given mail address can match a range of face images, from most specific (such as an X-Face) or most general (such as an a default image for a toplevel domain)." {

        {faces(xFaceEnabled) xFaceEnabled ON {Use X-Face headers}
	"If a message contains an X-Face header, display the image encoded into the header."}

	{faces(xfaceProg) xfaceProg {} {X-Face command}
"A command to convert an X-Face: header line into a displayable X11 bitmap.

If you've patch uncompface, this can be:	uncompface -X
otherwise you should use this:			uncompface | ikon2xbm

Defining this enables the display of X-Face images.  This is independent of the facesaver database."}

	{faces(enabled) facesEnabled ON {Use faces database}
"Search for and display images from the facesaver database."}

	{faces(rowEnabled) facesRow OFF {Use faces row}
"Use a horizontal row to display all the matching images of a face, rather than the most specific one."}

        {faces(xImageUrl) xImageUrl ON {Use X-Image-URL}
"If a message contains an X-Image-URL header, display the image referenced in that header."}

	{faces(defer) facesDefer ON {Background processing} 
"When on, this causes faces display to be handled as a background task.  This allows the display of a faces row to be aborted when another message is selected.  If your machine can display faces quickly enough, you should turn this off."}

	{faces(palette) facesPalette {} {Size of color palette}
"This allows you to force exmh to render face images in a less color-consuming
manner.  Valid settings are as for the -palatte option of the Image Photo widget.

With the default setting, an empty string, images are rendered in as large a color cube as the photo widget can allocate.

When set to a single decimal number, this specifies the number of shades of gray to use.  A value of 2 results in a dithered monochrome; 32 results in a pleasing greyscale.

When set to three decimal numbers separated by slashes (/), specifying the number of shades of red, green and blue to use, respectively.  5/5/4 is a useful setting for an 8-bit Pseudocolor display"}

     }
}

proc Faces_Create { parent } {
    global faces

    # Remember these
    set faces(parent) $parent
    set faces(rowparent) [winfo parent $parent]

    trace variable faces(rowEnabled) w Faces_Setup
    Faces_Setup
}

proc Faces_Setup args {
    global faces faceCache exmh

    # should call this when one of these changes:
    #	faces(path), faces(dir), faces(sets), env(FACEPATH)
    Face_SetPath

    catch {unset faceCache}

    # Clear any faces (and delete images)
    if [info exists faces(alloc)] {
	Face_Delete
    }

    set faces(alloc) 0		;# last label allocated
    set faces(avail) 0		;# next label available for use

    catch {destroy $faces(rowparent).faceRow}
    if [winfo exists $faces(parent).default] {
    	catch [concat destroy [winfo children $faces(parent)]]

	# shrink the hole (why do I have to do this?)
	$faces(parent) config -width 1
	update idletasks
	$faces(parent) config -width 0
    }

    if {$faces(rowEnabled) && (!$exmh(slowDisp) || $exmh(slowDispFaces))} {
	set row [Widget_Frame $faces(rowparent) faceRow Face {top fill}]
	pack $row -before $faces(parent) -side bottom

	set faces(frame) $row
	set faces(rowbg) [lindex [$row config -bg] 4]
    } else {
    	set faces(frame) $faces(parent)
    }

    global exmh
    set faces(default) [Widget_Label $faces(frame) default {left fill} \
			-bitmap @$exmh(library)/exmh.bitmap]

    # kludge to get default background of the labels
    if {$faces(rowEnabled) && (!$exmh(slowDisp) || $exmh(slowDispFaces))} {
	set f [FaceAlloc]
	set faces(facebg) [lindex [$f config -bg] 4]
	Face_Delete
    }
}


proc Quote_Init {} {
    global quote

    Exmh_Debug "Quote_Init"
    set quote(add) [WidgetGetResources . quoteAdd]
    set quote(omit) [WidgetGetResources . quoteOmit]

    Preferences_Add "Quoting" \
"     The following options control how exmh writes to the quoting
file, @ by default.  This file contains a version of the message
replied to that sedit or other editors can use to quote.  Currently
there are two basic choices for the quote file.  It can either be a
symlink to the original message, or it can be a composite message
built by only including some types of a MIME message after
type-specific processing.

     If simple symlinking is off, exmh will read the X resources
(usually in app-defaults or ~/.exmh-defaults) to determine which
MIME types to process.  A mime type is processed if it matches a 
string-match (glob) pattern in *quoteAdd unless it matches one
in *quoteOmit.  For instance, if quoteAdd is text/* and *quoteOmit
is text/richtext, all MIME types starting in text/ will be added
except for text/richtext.  
    You can add to the resources in *quoteAdd with resources named
*uquoteAdd and *lquoteAdd, and remove resources from *quoteAdd with
resources named *u-quoteAdd and *l-quoteAdd.  There are similar
resources for tuning *quoteOmit.
    By default, only decrypted PGP messages and text/* types are added.

     If a MIME type is to be included, and *quote_type is
non-empty, the function in *quote_type is run on that MIME section.
For instance, if the following resources were set:

*quoteUAdd: message/rfc822 text/* multipart/* application/pgp \
    foo1/bar1 foo2/bar2 foo3/*
*quoteUOmit: foo3/barnone
*quote_message/rfc822:          Quote_Message
*quote_multipart/signed:        Quote_MultipartSigned
*quote_multipart/encrypted:     Quote_MultipartEncrypted
*quote_application/pgp:	        Quote_AppPgp
*quote_multipart/default:	Quote_MultipartDefault
*quote_foo3/default:            Quote_FooThree
*quote_foo1/bar1:               Quote_FooBar

Then the MIME types that would be quoted are message/rfc822, 
application/pgp, foo1/bar1, foo2/bar2, and any type starting with
text, multipart, and foo3, except for foo3/barnone.

Tcl programmers who want custom treatment of certain MIME types can
write their own quoting functions and specify them in the above way.
In the above example, Quote_FooThree and Quote_FooBar must be added
by the user.  Users unfamiliar with tcl are best off modifying
*quoteUAdd and *quoteUOmit only.

     If symlinking is off, the message being replied to must appear 
in the exmh display.  To quote a PGP encrypted message, it must 
already be decrypted.  Otherwise, it will be omitted like any other 
unquotable MIME type." {
    {quote(enabled) quoteEnabled ON {Enable quoting}
"If you do not enabled quoting, exmh will not create any quote file
when replying." }
    {quote(filename) quoteFilename @ {Quote file name}
"The filename of the quote file relative to the exmh home directory,
which is usually the user's home directory.  The default is @, I
have mine set to Mail/@." }
    {quote(symlink) quoteSymlink ON {Only symlink}
"In previous versions of exmh, the quote file was only a symlink to
the message being replied to.  Select this if you want to override
the following options and keep this behavior." }
    {quote(headers) quoteHeaders ON {Include headers}
"If this is off, exmh will not write the headers of the message
being replied to into the quote file.  Sedit expects this to be on." }
     }
}
proc Sound_Init {} {
    global sound
    # Preferences_Add will set these variables to Xresource values,
    # but only if the variables are not already defined.
    # These sound variables are defined at install time,
    # so we need to unset them in order honor any per-user defaults.
    set cmd $sound(cmd) ; unset sound(cmd)
    Preferences_Add "Sound" \
"Exmh can provide audio feedback.  It can ring your terminal bell, or play audio files." \
    [list \
	{ sound(enabled) soundEnabled ON {Sound feedback}
"Enable audio feedback.  Exmh will make a sound when
new messages are incorporated into your folders
(except during startup) and when you try to change
folders without committing moves and delete operations."} \
	{ sound(multifile) soundMultiFile OFF {Play Multiple}
"If your play command can handle multiple audio files,
then set this option.  In this case Exmh can run the
audio program in the background when it needs to
play multiple sounds."} \
	[list sound(bell) soundBell OFF {Use terminal bell} \
"Ring the terminal bell instead of playing an audio file."] \
	[list sound(cmd) soundCmd $cmd {Play command} \
"The command line used to play audio files.  You may want
to add flags to control the volume, for example.  The
name of the audio file is appended to this command line."] \
	[list sound(newMsg) soundNewMsg drip.au {Sound for a new message} \
"The name of an audio file to play when
new messages have arrived.  Relative pathnames are
searched for in the exmh script library directory."] \
	[list sound(error) soundError clink.au {Sound for an error} \
"The name of an audio file to play when
you forget to commit pending operations.  Relative pathnames are
searched for in the exmh script library directory."] \
]
    if {$sound(enabled) && ([string length $sound(cmd)] == 0)} {
	set sound(bell) 1
    }
}

proc Sedit_Init {} {
    global sedit

    set sedit(init) 1
    set sedit(height) 20
    set sedit(allids) {}

    if ![info exists sedit(key,sendMsg)] {
	set sedit(key,sendMsg) <Control-c><Control-c>
    }
    Preferences_Add "Simple Editor" \
"Exmh comes with a simple built in editor called \"sedit\".
It has about 20 keybindings for basic editing operations.
You can tune these bindings with the Bind dialog that defines
bindings for the Text and Entry widget classes."  {
    {sedit(pref,replPrefix) replPrefix "> " {Reply insert prefix}
"This string is prepended to lines included from the reply message
when you use the Insert @ command."}
    {sedit(formatChoice) seditFormatMail {CHOICE OnSend OnType Never} {Format Mail default}
"Sedit can format mail at two different times:
OnSend converts soft line wraps to hard line breaks when you hit the send button.
OnType generates hard line breaks as you type.
Never does no formatting at either time.
The text/enriched formatting is done for both OnSend and OnType
formatting choices.
This Preference setting chooses the default behaviour, which
you can change with the Format menu entry."}
    {sedit(mhnDefault) seditAttemptMhn OFF {Attempt mhn default}
"Sedit can send your message thru mhn in order to expand its #
MIME formating directives (see the man page about mhn for details).
You can control whethor or not this happens with the Attempt mhn menu
item.  This Preference setting chooses the default for that item."}
    {sedit(keepDefault) seditKeepOnSend OFF {Keep on send default}
"Sedit can save its window after you send a message.  This is useful
if you want to send variations on the same message to different addresses.
This Preference setting chooses the default for this option."}
    {sedit(quoteDefault) seditQuotedPrintable {CHOICE automatic always never} {Quoted-printable default}
"Sedit can encode text as quoted-printable to protect 8-bit characters.
Automatic means it will do this when you use the Compose key to
insert an 8-bit character.  Always means it always does it.
Never means it never does it.  You can also override this on
a per-message basis with the Quoted-Printable menu entry."}
    {sedit(lineLength)   seditLineLength 79 {Max Line Length}
"This is the length at which Format Mail chops lines.
It looks around for a word break when chopping."}
    {sedit(autoSign) seditAutoSign OFF {Automatically sign messages.}
"This will cause your .signature (or selected .signature* file) to
be automatically appended to your message when you Send it."}
    {sedit(sigDashes) seditSigDashes ON {Put a '-- ' before signature.}
"This puts a '-- ' on a line between your mail and signature,
as per ELM and also Usenet news.  This is only done for single-part mail."}
    {sedit(sigPosition) seditSigPosition {CHOICE end insert} {Where to position the signature.}
    "Where do you want your signature? At the _end_ or at the current insertion position?"}
    {sedit(sigfileDefault) seditSignatureFile "" {Default signature file}
"This is the name of the default signature file.  If set to something,
then this will be used as the default signature file in the Sign menu
for the built-in editor.  It is assumed to match the ~/.signature* pattern."}
    {sedit(colorize) seditColorize OFF {Colorize multiparts}
"For debugging, the multipart structure of a message can be highlighted
by coloring different type parts with different background colors."}
    {sedit(iso) seditISO ON {Specify Charset for Text}
"If enabled, this option adds character set information to
text content types, and promotes all messages to at least
MIME content-type text/plain."}
    {sedit(charset) seditCharset {CHOICE iso-8859-1 iso-8859-2 iso-8859-8 koi8-r} {8-bit character set}
"If you have enabled support for ISO character sets and enter
text that has the 8-th bit set, then
this is the character set used for text content types"}
    {sedit(defaultType) seditDefaultType {CHOICE text/plain application/octet-stream} {Default type for unknown files}
"If the type of a file cannot be determined from the mime.types file
and from the file -m program, use this as the default MIME type
when attaching files."}
    {sedit(spell) seditSpell {CHOICE spell ispell custom} {spell program}
"This chooses the spell program used by the built-in editor.
Use custom if you want to define the program explicitly."}
    {editor(spell) spellCmd {exmh-async xterm -e ispell} {custom spell command}
"NOTE: this affects the same internal variable as the
Spell Command in Editor preferences.

There are two flavors of spell programs.  If your spell program just
prints out the misspelled words, then just specify it directly.
Examples include the standard \"spell\" program.  If you spell program
is interactive, then run it from exmh-async:
exmh-async xterm -e ispell
(This is faked - exmh-async isn't really used.  Instead a temporary
wish script is used.)"}
    {sedit(autosaveInterval)   seditAutosaveInterval 60 {Seconds between auto saves}
"This is the interval, in seconds, between automatic saves of 
the message being edited.  Set to 0 to disable autosaving."}
    }
    Preferences_Resource sedit(wordbreakpat) seditWordBreakPat "\[\ \t/>\]"
    # Converting from boolean to choice
    switch $sedit(formatChoice) {
	1 {set sedit(formatChoice) OnSend}
	0 {set sedit(formatChoice) Never}
    }
    # Colors for multiparts
    Preferences_Resource sedit(c_enrichedBg) 	c_enrichedBg pink
    Preferences_Resource sedit(c_textBg) 	c_textBg snow
    Preferences_Resource sedit(c_audioBg) 	c_audioBg gold
    Preferences_Resource sedit(c_imageBg) 	c_imageBg powderblue
    Preferences_Resource sedit(c_messageBg) 	c_messageBg seashell
    Preferences_Resource sedit(c_applicationBg) c_applicationBg honeydew
    Preferences_Resource sedit(c_videoBg)	c_videoBg lavenderblush

    Preferences_Resource sedit(c_enrichedFg) 	c_enrichedFg black
    Preferences_Resource sedit(c_textFg) 	c_textFg black
    Preferences_Resource sedit(c_audioFg) 	c_audioFg black
    Preferences_Resource sedit(c_imageFg) 	c_imageFg black
    Preferences_Resource sedit(c_messageFg) 	c_messageFg black
    Preferences_Resource sedit(c_applicationFg) c_applicationFg black
    Preferences_Resource sedit(c_videoFg)	c_videoFg black

}

if {[info command Sedit_CheckPoint] == ""} {
proc Sedit_CheckPoint {} {
    # Dummy routine overridden when/if sedit.tcl is auto-loaded
}
}

proc Pgp_Init {} {
    global pgp env miscRE

    # Load a minimal amount of data
    # Otherwise it cannot check for pgp
    Pgp_Base_Init

    # Set up exmh for a pgp version
    # if there is an appropriate keyring
    foreach v $pgp(supportedversions) {
        if { [file exists [set pgp($v,pubring)]] && 
             [file isdirectory [set pgp($v,path)]]} {
            set pgp($v,enabled) 1
            set pgp(enabled) 1
            lappend setup $v
        }
    }
    if { ![info exists setup] } {
        return
    }

    # Now that we know, that there is a pgp variant
    # installed on the system, we load all the stuff
    # every pgp version needs for basic functionality
    Pgp_Shared_Init    

# Global PGP preferences
    Preferences_Add "General PGP Interface" \
"Pretty Good Privacy (PGP) lets you sign and encrypt messages using 
public keys.
There is considerable documentation that comes with PGP itself.
This set of preferences controls the general behavior of all the
PGP modules." {
    {pgp(seditpgp) pgpSeditPgp OFF {Sedit PGP passphrase}
"Turning this on provides you with a PGP passphrase field in the sedit
window so that you will not be prompted with the passphrase prompt.  
Changing this value will require that you exit and re-enter exmh if 
you've already composed email." }
    {pgp(sign) pgpSign ON {Sign outgoing messages}
"If this is turned on, outgoing messages will be signed." }
    {pgp(encrypt) pgpEncrypt OFF {Encrypt outgoing messages}
"If this is turned on, outgoing messages will be encrypted." }
    {pgp(mime) pgpMime ON {Use Mime for PGP}
"If this is turned on, outgoing PGP messages will use Mime for encapsulation." }
    {pgp(clearsign) pgpClearSign ON {Sign messages in the clear}
"If this is turned on, messages will be signed so that they can be read by
non-PGP mail readers." }
    {pgp(format) pgpFormat {CHOICE pm plain app} {Format to encode PGP}
"There are multiple standards for PGP encoding.
    Pm:     Use the multipart/pgp standard (This is the preferred standard)
    Plain:  No MIME headers at all
    App:    Use the now deprecated application/pgp standard.
This can be changed on the fly from the sedit window" }
    {pgp(version) pgpVersion {CHOICE pgp pgp5 gpg} {Version of PGP for new messages}
"There are multiple versions of the PGP program.
    PGP:    Pretty Good Privacy, Version 2
    PGP5:   Pretty Good Privacy, Version 5
    GPG:    GNU Privacy Guard
This can be changed on the fly from the sedit window" }
    {pgp(passtimeout) PassTimeout 60 {Minutes to cache PGP passphrase}
"Exmh will clear its memory of PGP passphrases after
this time period, in minutes, has elapesed." }
    }

    # And now load the version specific stuff
    foreach v $setup {
        # Load version specific support
        Pgp_${v}_Init
        # Add version specific Preferences
        Pgp_Preferences $v
    }

    # Other initialization
    Pgp_Match_Init
    Pgp_Exec_Init

}

# Glimpse_Init
#
#  glimpse options used in extrasInit.tcl	: version   : variable
#
#  -# : approximate matching (max error in match):since 1.0:glimpse(maxErrors)
#  -w : whole word				: since 1.0:glimpse(wholeWord)
#  -i : case insensitive			: since 1.0:glimpse(caseSensitive)
#  -F : file pattern				: since 1.0:glimpse(singleIndex)
#  -L {limit} : limit on the matches		: since 2.0:glimpse(maxHits)
#               (max hits (per folder))
#  -L {limit}:0:{flimit} : limit per file	: since 3.0:glimpse(maxHitsMsg)
#               (max hits per message)

proc Glimpse_Init {} {
	global glimpse

	if {[string length $glimpse(path)] == 0} {
	    global exwin
	    catch {destroy $exwin(fopButtons).glimpse}
	    catch {$exwin(fopButtons).search.m entryconfigure Glimpse* -state disabled}
	    return
	}
	if [info exists glimpse(init)] { return }

	if [catch {exec $glimpse(path)/glimpse -V} voutput] {
	    ExmhLog "$voutput"
	    return
	}
	if {! [regexp {[0-9]\.[0-9]} $voutput glimpse(version)] } {
	    ExmhLog "glimpse version info error : $voutput"
	    return
	}
	set glimpse(init) 1

	Preferences_Add "Glimpse" \
"Glimpse (which stands for GLobal IMPlicit SEarch) is an indexing and query
system that allows you to search through all your files very quickly.  You
could set here your default values. The 'Glimpse Window' allows you to re-
define them for a search in the menu 'opts'." {
        {glimpse(caseSensitive) glimpseCaseSensitive ON {Case sensitive search}
"Determines if the search is case sensitive or not.  This could be
changed on the fly in the 'Glimpse Window' in the menu 'opts'"}
        {glimpse(wholeWord) glimpseWholeWord ON {Match only whole words}
"If set to on your search string is assumed to be a complete word.  This
could be changed on the fly in the 'Glimpse Window' in the menu 'opts'"}
        {glimpse(searchRange) glimpseSearchRange {CHOICE all subtree current all-in-one}
 {Default search range is}
"The default search range of glimpse:
    all:     search in all your mails
    subtree: search in the current and all subfolders.
    current: search is restricted to the current folder
This can be changed on the fly in the 'Glimpse Window' in the menu 'opts'"} }

if {$glimpse(version) >= 2.0} {
    Preferences_Add "Glimpse" "" {
        {glimpse(maxHits) glimpseMaxHits {CHOICE 50 100 200 500 1000 2000 10000}
{Maximum number of matches (*per folder*)}
"Outputs only the first x matching records.
This applies on a per-folder basis, not per file.
If you have a single large glimpse index, it applies
to the whole search.

The maximum # of matches can be changed on the fly in the 'Glimpse Window'
in the menu 'opts'"} } }

if {$glimpse(version) >= 3.0} {
    Preferences_Add "Glimpse" "" {
	{glimpse(maxHitsMsg) glimpseMaxHitsMsg {CHOICE unlimited 1 5 10 100}
{Maximum number of matches *per message*}
"Outputs only the first x matching records.
This applies on a per-message basis.

The maximum # of matches can be changed on the fly in the 'Glimpse Window'
in the menu 'opts'"} } }

Preferences_Add "Glimpse" "" {
    {glimpse(maxErrors) glimpseMaxErrors {CHOICE none 1 2 3 4 5 6 7 8}
{Maximum allowed errors}
"Specifying the maximum number of errors permitted in finding the approximate
matches (the default is none).  Generally, each insertion, deletion, or
substitution counts as one error.

If not set to 'none' your search string is assumed to be a complete word.

The number of errors allow can be changed on the fly in the 'Glimpse Window'
in the menu 'opts'"}
	{glimpse(singleIndex) glimpseSingleIndex OFF {Use single index file}
"If set to on, uses a single glimpse index file stored in the .glimpse
directory in your MH home directory"}
	}
}

proc Signature_Init {} {
    Preferences_Add "Intelligent Signatures" \
"Outgoing messages may be signed differently depending upon whether
they are being sent solely within the local domain, or outside of it." {
    { intelligentSign(state) intelligentSign OFF {Intelligent sign default}
"If intelligent signing is on by default, the appropriate signature
will be chosen just before mail is sent out.  This may be changed on
a per-message basis using the \"Sign...\" menu in a sedit window."}
    { intelligentSign(showhdrs) intelligentSigShowHdrs OFF {Show headers in sedit}
"Various arguments are passed to executable .signatures giving
information about the MH command used to compose this message, current
folder at the start of composition, and full pathname of the draft
message (irrespective of whether intelligent signatures are enabled or
not).  This information is saved in the headers of the draft.  Enabling
this Preference setting causes those header lines to be shown initially
in the sedit window."}
    { intelligentSign(internal) intelligentSigInt "~/.signature"
{Internal signature} "This is the name of the default file to use for signing
messages being sent solely within the local domain."}
    { intelligentSign(external) intelligentSigExt "~/.signature"
{External signature} "This is the name of the default file to use for signing
messages being sent outside the local domain."}
    { intelligentSign(domain) intelligentSigDomain {} {Local domain}
"This is a (space-separated) list of domains to be considered local;
mail sent to addresses only in these domains will always be signed
with the local signature."}
    }
}

proc UnseenWin_Init {} {
  global unseenwin

  Preferences_Add "Unseen Window" \
"The unseen window, if enabled, shows a list of folders with unseen
messages (together with the number of unseen messages).  Options exist
to control its size (which in turn controls its behaviour as entries
are inserted or removed and also to control the action that will occur
if you click in the window." \
  {
    { unseenwin(on) unseenWinOn OFF {Enable Unseen Window}
"Enables the unseen window."
    }

    { unseenwin(icon) unseenWinIcon OFF {Icon Window}
"Tries to tell the window manager to use the unseen window as
exmh's icon.
Note: doesn't work with all window managers."
    }

    { unseenwin(minlines) unseenWinMinLines 3 {Minimum Entry Lines}
"The minimum number of entries that the unseen window will show.
This controls the minimum height that the unseen window will adopt."
    }

    { unseenwin(maxlines) unseenWinMaxLines 10 {Maximum Entry Lines}
"The maximum number of entries that the unseen window will show.

If set and the size of the entries exceeds the maximum,
scanning (using button 2) is enabled in the window.

If left blank (or set to a value less than the minimum),
the icon window will always grow to accomodate the current
number of entries."
    }

    { unseenwin(minwidth) unseenWinMinNameWidth 11 {Minimum Name Width}
"The minimum number of characters that will be used
for the folder name.  This in turn controls the minimum
width that the unseen window will adopt."
    }

    { unseenwin(maxwidth) unseenWinMaxNameWidth 20 {Maximum Name Width}
"The maximum number of characters that will be used
for the folder name.

If set and a folders name exceeds the width, it is cropped
to display just the last characters preceeded by ellipsis such
that it doesn't exceed the given width.

If left blank (or set to a value less than the minimum width),
the unseen window will always grow to accomodate the maximum
folder width."
    }

    { unseenwin(font) unseenWinFont 6x10 {Font}
"The font to use in the unseen window."
    }

    { unseenwin(hidewhenempty) unseenWinHideWhenEmpty OFF {Hide When Empty}
"The unseen window will only be displayed when there are unseen
messages."
    }

    { unseenwin(emptymsg) unseenWinEmptyMsg {NO UNREAD MAIL} {Empty Message}
"The message to display in the unseen window when there are
no unread messages.

Note; if \"Hide When Empty\" is on, this option has no use."
    }

    { unseenwin(b1mode) unseenWinButton1
      {CHOICE None Raise Warp {Warp & Show}}
      {Button 1 Mode}
"The behaviour when you click on the unseen window depends
on this setting.

None:        Nothing
Raise:       Bring the main window to the front
             (deiconifying if necessary)
Warp:        Raise then change to the folder clicked on
Warp & Show: Warp then select the first unseen message"
    }

    { unseenwin(b2mode) unseenWinButton2
      {CHOICE Nothing Inc}
      {Button 2 Mode}
"The behaviour when you press mouse button 2 depends on
this setting.

Nothing:     Does nothing
Inc:         Just like clicking the Inc button"
    }

    { unseenwin(mb1mode) unseenWinModifiedButton1
      {CHOICE None Raise Warp {Warp & Show}}
      {Modified Button 1 Mode}
"The behaviour when you shift-click, control-click or
shift-contol-click on the unseen window depends
on this setting.

None:        Nothing
Raise:       Bring the main window to the front
             (deiconifying if necessary)
Warp:        Raise then change to the folder clicked on
Warp & Show: Warp then select the first unseen message"
    }

    { unseenwin(b3mode) unseenWinButton3
      {CHOICE Nothing Compose}
      {Button 3 Mode}
"The behaviour when you press mouse button 3 depends on
this setting.

Nothing:     Does nothing
Compose:     Starts a mail composition"
    }
  }

  set unseenwin(digits) 1
  trace variable unseenwin(on)            w UnseenWinToggle
  trace variable unseenwin(icon)          w UnseenWinToggleIcon
  trace variable unseenwin(font)          w UnseenWinChangeFont
  trace variable unseenwin(emptymsg)      w UnseenWinEmptyMsg
  trace variable unseenwin(hidewhenempty) w UnseenWinEmptyMsg
  foreach v {minlines maxlines minwidth maxwidth} {
    trace variable unseenwin($v) w UnseenWinChangeMinMax
  }
  foreach v {b1mode mb1mode} {
    trace variable unseenwin($v) w UnseenWinToggleClick
  }
  if {$unseenwin(on)} {
      UnseenWinToggle
  }
}

