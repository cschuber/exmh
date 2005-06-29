'\"
'\" 
'\" $Header$ SPRITE (Berkeley)
.\" .DS
.\"	Begin an indented unfilled display.
.\"
.\" .DE
.\"	End of indented unfilled display.
.\"
'	# DS - begin display
.de DS
.RS
.nf
.sp
..
'	# DE - end display
.de DE
.fi
.RE
.sp .5
..
.TH "EXMH TOUR" 1 "December 3, 1996" "Exmh 2.0" "INTRO TO EXMH"
.SH NAME
exmh \- An introduction to the exmh mail user interface.
.SH INTRODUCTION
.PP
This man page provides a quick tour through some of the basic features of
.I exmh version 2.0,
which provides a graphical user interface to the MH mail system.
.PP
After you read this tutorial you should be able to use
.I exmh
for your
basic daily mail reading needs.
You will learn how to send mail, read mail, manage your messages
in folders, and adjust some of the \fIexmh\fP features by
means of its Preferences user interface.
.PP
There is much more documentation available on-line through HTML
pages that are viewable from within exmh.  In particular.
\fBexmh-use\fP provides information about using the more advanced
features of \fIexmh\fP.
If you are already an experienced email user, you
may want to just read the GETTING STARTED section here
and then 
skip to the \fBexmh-use\fP man page.
\fBexmh-custom\fP describes how to customize exmh to suit your needs.
\fBexmh-ref\fP lists each button and menu entry in \fIexmh\fP and
explains what they do.  If you are an experienced \fIexmh\fP user,
this may be the most useful man page for you.
.PP
A cleaned up version of these man pages
appear in the 3rd edition of the book by Jerry Peek, \fIMH & xmh:
email for users and programmers\fP,
which is published by O'Reilly & Associates.
.PP
Web versions of the documentation can also be found at
.PP
http://www.beedub.com/exmh/
.PP
.SH "GETTING STARTED"
.PP
If you are already an MH or \fIxmh\fP user, you can start with the
examples given in this tour.  If you are a new user, exmh will set
up your basic MH environment.
This includes a Mail directory which will have one subdirectory
for each mail folder, plus several files that MH mail uses for
its own purposes.  You also get a ~/.mh_profile file that has
user settings for MH and exmh.
.PP
\fIExmh\fP uses the
regular MH programs to manipulate your mail folders
and messages.
This means it is compatible with command-line use of MH programs,
and its actions should be familiar if you are an experienced MH user.
If you are a new MH user, then the details of running MH programs
is hidden behind the graphical interface.
The MH programs used by exmh are described
towards the end of this man page.
.PP
When you run \fIexmh\fP for the first time it checks a few things
in your MH profile.  In particular, it depends on
the Draft-Folder and Unseen-Sequence
profile components.
If these profile components are not present,
a dialog appears and \fIexmh\fP can set them up for you.
If you do not let \fIexmh\fP create them nor
set them up by hand, \fIexmh\fP will not work properly.
These profile entries are described in the \fBexmh-ref\fP man page.
.PP
\fIExmh\fP has been designed to be very flexible, 
although it will work just fine "out of the box".
The Preference package used to adjust some of the settings
in exmh is introduced in this man page, and some of the
important settings are described here.
A more complete guide to customizing \fIexmh\fP is given
in the \fBexmh-custom\fP man page.
.SH RUNNING EXMH
.PP
The command to start \fIexmh\fP looks like this:
.DS
exmh -display \fIhostname\fP:0 &
.DE
If your DISPLAY environment variable is set up properly, then
the -display argument is not needed, and the command is even simpler.
You do not need to specify a -geometry argument,
although \fIexmh\fP supports one.
Instead, simply position and size the window using your window manager.
When \fIexmh\fP quits, it saves the geometry information so you don't
have to worry about it.  It does this with all its top level windows,
so you can adjust their position once and then forget about it.
There are more command line options described in the \fBexmh-ref\fP
man page.
.PP
You can add the exmh command to your startup X environment by
editing your startup file (like .xsession).  You might also want
to add it to the main menu of your window manager.  The details
about this vary from X system to X system, so ask your local
X guru for help.  \fIExmh\fP also supports the window manager
session protocol, which means that session-smart window managers
will automatically start exmh for you if you quit X when \fIexmh\fP is running.
.SH THE EXMH DISPLAY
.PP
This section describes the main parts of the \fIexmh\fP display.
It probably makes sense to run exmh at this point so you
can follow along.
There are three sets of buttons in the interface,
and three main subwindows.
.PP
\fBMain Buttons\fP.
Along the top of the window is a set of buttons and menus
that apply to \fIexmh\fP itself.  Quit, for example, quits \fIexmh\fP.
The Help button pops up a menu, and you can select the entries there
to get more on-line information about \fIexmh\fP.
Use the left mouse button to select the buttons and menus.
A button will change its appearance when you press it, and it
will be invoked when you release the mouse over the button.
If you slide the mouse off the button before releasing it,
nothing happens.
.PP
\fBFolder Display\fP.
Below the main buttons is the folder display subwindow.
It has a special button for each of your top-level folders,
and these are called \fIfolder labels\fP.
As a new user you will see two folder labels, one for inbox and drafts.
The inbox folder is for your new messages,
and the drafts folder is for messages you are writing.
If you have used MH (or xmh) before, then you may have many more
folders that will appear in this display.
The mouse bindings for folder labels are explained in
the \fBexmh-use\fP man page.  The \fIColor Legend\fP from the
Help menu also tells you how the folder labels respond to mouse clicks.
.PP
\fBFolder Cache\fP.
A second folder display called the \fIfolder cache\fP may appear under
the main folder display.  This shows the folder labels for recently
used folders.  If you only have a few folders this wastes screen
real estate.  The PREFERENCES section near the end of
this man page explains how to turn this off via the
Folder Cache preferences setting.
If you are a first-time exmh user,
Exmh tries to guess if you need
this display based on the number of folders and nested folders you have.
.PP
\fBFolder Buttons\fP.
The middle set of buttons is for operations that apply to folders.
For example, you can create a new folder with the New button here.
The More... button displays a popup menu with several more operations
you can apply to folders.  Some of these buttons will be introduced in
this man page.  All of these buttons and menus are explained
in detail in the \fBexmh-ref\fP man page.
.PP
To the left of the folder buttons, summary information about the
current folder is displayed.
.PP
\fBTable of Contents\fP.
The middle subwindow of the display shows a summary of the messages in
the folder.
It shows the message number, the date of the message, the subject of
the message, and, space permitting, the first few words of the message.
Left click on a line in the table of contents to view the
corresponding message.
The mouse bindings for the table of contents are described in
more detail in the \fBexmh-use\fP man page.
.PP
MH experts: The display in this window comes from both the
MH scan program or MH inc programs, so it is affected by the
form specification used by these programs.
.PP
\fBColor and Monochrome Highlights\fP.
Both the folder display and table of contents windows use highlights
to give you visual clues about the state of messages and folders.
Your unread messages are highlighted in the
table of contents and the folders
that contain unread message are highlighted in the folder display.
Pull down the main Help menu and select \fIColor Legend\fP 
to display a key to the highlights for your display.
The highlighting is covered in more detail later in the
\fBexmh-use\fP man page.
The \fBexmh-custom\fP man page tells how you can control
the highlighting yourself.
.PP
\fBStatus Line\fP.
Just below the table of contents is the status line.
This has two parts.  The left part shows the name of the
folder and the message number for the current message, if any.
The right part gives feedback about what \fIexmh\fP is doing.
After it displays a message, the Subject component is displayed
there.
.PP
\fBSubwindow Resize Diamond.\fP
The black diamond to the right of the status line is used to
change the size of the internal windows.  Press the first mouse
button on this target and a horizontal line appears.
Drag it up and down to adjust the window sizes.  Try dragging it
all the way to the top and bottom of the exmh window to see
how the mode changes to adjust different windows.
.PP
\fBMessage Buttons\fP
The bottom row of buttons are for operations that apply to the
current message.  Several of these operations will be introduced
in this man page.  The right hand button labeled More... brings up
a menu with several more advanced message operations.
.PP
\fIHint:\fP Many of these message operations have keyboard shortcuts
that make it easy to use \fIexmh\fP with your hands on the keyboard.
Some of the short-cuts are introduced in this man page, and all
of them are listed in the \fBexmh-use\fP man page.
.PP
\fBMessage Display\fP.
The bottom subwindow displays the current message, if any.
Some of the less interesting mail headers start out scrolled off the
top of this window.
.SH SENDING MAIL
.PP
A good way to test things out is to send a message to yourself.
Here are the steps you take to do that:
.PP
1.
Click the Send button, which is in the Message buttons in the bottom group.
A new window will open that contains the template for your message.
The built-in editor, which is called \fIsedit\fP,
will start out with the insert cursor positioned at the end
of the first empty header line.
Enter your user name after the To: header.
If you want to send the message to more than one person,
use a comma to separate the names.
.PP
2.
Position the insert cursor on the next header line.
You can do this a few different ways.
The most direct way is to click the left mouse button where you
want the cursor to be.
There are keyboard shortcuts, too.
If you press <Tab> the editor will take you to the end of
the next header line.  
You can also use the arrow keys or some emacs-like bindings
to move the cursor.  <Control-n> goes to the next line,
<Control-f> moves the cursor forward a character.
<Control-p> moves up a line, and <Control-b> moves back a character.
The \fISimple Edit\fP menu entry shows you all the keybindings.
.PP
3.
The next header is the Cc: line.
People listed in the Cc: line get a "courtesy" (or "carbon")
copy of the message.  By convention, the message is primarily for
the people listed in the To: component, and the people in the Cc: component
are getting the message "for information."
In this case, you can leave the Cc: component empty.
.PP
Move the insert cursor to the Subject: line and enter a Subject.
The people that receive your message will get an idea of
what the message is about from the subject, so take a moment
to think of a good one.  For this test, you can type
something like "exmh test message".
.PP
4.
Make sure the headers are OK.
In particular, make sure there are no blank lines in the headers.
The mail system treats a blank line as meaning "end-of-headers",
so you don't want to prematurely end the header section.
If you have a blank line, position the insert cursor on it and
use Backspace to remove the empty line.
.PP
Position the cursor at the start of the message body.
You can use the mouse for this,
or you can press <Tab> twice quickly and the editor will
position the cursor correctly.
When using the default MH message templates, 
this will be right after the line of all dashes.
.PP
5.
Type in your message.
When you type in a long message, the lines will wrap automatically
at word boundaries.
To get a blank line for paragraph boundaries, press <Return>.
The built-in editor supports several editing commands
that are based on the GNU emacs
key bindings.
If you select the \fISimple Edit\fP menu entry under the main Bindings
menu, you will bring up a dialog that lets you view and edit
the key bindings.
.PP
6.
If you are happy with the message, you send it by pressing
the Send button at the top-right corner of the window.
The Send button will turn grey, and the window will disappear
once the message has been sent successfully.
.PP
If you do not want to send the message, press the Abort button instead.
If you want to save the message draft and continue to work on it later,
press the Save&Quit button.  Working on a saved draft message is
described in the \fBexmh-use\fP man page.
.PP
Send yourself a few messages, or have a friend send you
a few test messages.
You will use these test messages to practice moving around
in a folder and deleting messages. 
Make one of the messages pretty long
so you can practice scrolling through it.
.PP
Finally, try sending mh-mime-sample@online.ora.com a message.
This addresses
a program that will return a MIME message to you.
Just put this address in the To field with anything as the message
body and subject.  Reading this message will be described below.
.SH MOUSING AROUND
.PP
The selection is dragged out with the left
mouse button.  You can modify the selection by holding the Shift key
while pressing the left button.
A double-click begins a word-oriented selection,
and a triple-click begins a line-oriented selection.
If you drag a selection off the bottom or top of a window
the text will be scrolled automatically
and the selection will be extended.
.PP
Paste is done with the middle mouse button.
.I The current insert point is used, not the point at which you middle-click.
If you drag the middle mouse button, then the window is scrolled
instead as described below.
There is also a key-binding for paste, which is <Control-y>.
Use <Control-w> or the <Delete> key to delete
the selection.
.PP
The middle mouse button is used for "drag-scrolling".
To scroll, simply press the middle mouse button over the text and drag
the text.
If you press the Shift key, the scrolling is faster.
Drag-scrolling works in the text widgets, for vertical scrolling,
and the one-line entry widgets, for horizontal scrolling.
The text widgets are used to display the folder contents
and the current message.  The entry widgets are used in various
dialogs in order to enter values.
You can change the scrolling button to the right button or
to only work with shift-middle.  Set this up in the
Simple Edit Bindings... dialog.
.PP
Buttons and menus are also sensitive to which mouse button is pressed.
Only the left button activates a button,
and it is the <ButtonRelease> event that is important.
If you accidentally move the mouse off of the button
as you release it, nothing will happen.  Don't worry,
the wrong button will not be invoked.
.PP
Press the left button over a menu button to  pull down a menu.
Most of the menus in \fIexmh\fP are distinguished with a "..."
in their label, e.g. "More...".
The menu will go away
when the button is released.  Release the mouse button off the menu
if you do not want to invoke any menu item.
(In some versions of Tk,
the middle button will "tear off" a Tk menu.
This is quite handy if you use the menu often.
To get the menu to go away, you must click the left button over
the menu button.  This will reattach the menu to the menu button,
and another left click will make the menu go away.
In the latest versions of Tk, the first menu entry
is a dashed line that invokes this tear-off operation.)
.SH GETTING NEW MAIL
.PP
By now you should have some new mail waiting.
Press the Inc button from the middle set of buttons that
do Folder operations.
This will transfer messages from your system spool file into
your inbox folder.
You will hear an audible cue if there was new mail,
and the table of contents will be updated to reflect the new messages
in your inbox.
New messages will be underlined (on a monochrome screen),
or blue (on a color screen), to indicate that you have not read them yet.
.PP
To view the new message, click on its line in the table of contents,
or press the Next button in the bottom group of buttons.  
The message will be displayed in the bottom subwindow,
and the line in the table of contents will be highlighted to
remind you which message is being displayed.
.PP
To view the next message, click the Next button.
The keyboard shortcut for this is the 'n' key.
.PP
The view the previous message, click the Prev button.
The keyboard shortcut for this is the 'p' key.
.PP
\fBScrolling through messages\fP.
If you get a message that is too long to fit into the message window,
then the scrollbar will change its appearance to indicate how
much text is displayed.
The scrollbar is Motif-like.  You can click
on the arrows at either end to go up and down one line.  If you click
above or below the elevator box you go up and down one page.  You can
drag the elevator box to scroll, too.
.PP
You can also scroll text windows in \fIexmh\fP by dragging
with the middle mouse button.  Press the middle button over the text
area, not the scrollbar, and hold it down while you move the mouse up
or down.  If you hold the shift key at the same time, the scrolling
is faster.  This works in the folder Table of Contents window, too.
.PP
\fIHint\fP.
The space bar is a keyboard short-cut that does a combination of
scrolling and advancing to the next message.  If the message is long,
then space will scroll by one screen.  Once you are at the end of the
message, space will advance to the next message, just like the 'n' key.
You can use the BackSpace key to scroll back through a message.
.SH READING MIME MESSAGES
.PP
By now you should have also received the sample MIME message
from mh-mime-sample@online.ora.com.
The MIME message has three parts to it, and these are numbered and
labeled in the display.
The first part is a multipart/alternative content, which means there
are a few different ways to view the content.  This is indicated by
the message under the heading \fB1.\fP that there are alternative
views of the following content.  \fIExmh\fP will go ahead and
display what it thinks is the best alternative, and you see the
text/enriched content displayed in part \fB1.2\fP.  If you want
to see the other alternatives, then you can press the right button
over section 1 to get a popup menu with some choices.
.PP
The next two parts are an audio clip and a picture in GIF format.
The audio clip is handled directly by exmh, and it displays
two active text buttons labeled "Play attached audio" and
"Save audio file".  Click on either of these with the left mouse
button.
The part corresponding to the image displays a message about what
the type is, and suggests that you press the right mouse button
to display a menu.  You can always press the right button to get
a MIME menu that has type-specific options for parts of your message.
If you press the right button over part \fB2.\fP, then the
popup menu will offer you these choices:
.DS
Decode part as MIME
Save Hello from the author...
View using mailcap rule...
Pass an audio fragment to metamail...
.DE
The first item is a checkbox menu item that lets you view the raw content
if you want to.
The Save... menu entry displays a file selection box so you can choose
a non-temporary file to store the content.
This same function is available through the text button,
but not all MIME parts displays buttons like this.
The next two entries should result in the same thing.
They use the mailcap specifications to run another program that
displays the content.  In the first case, View using mailcap rule...,
\fIexmh\fP runs the program directly.  In the other case,
Pass to metamail..., the \fImetamail\fP program is run first, and it
decodes the mailcap file and runs the external program.
Again, the text button labeled "Play attached audio" also plays
the audio.
.SH REPLYING TO MAIL
.PP
Select one of the messages from your friend that you'd like to answer.
Press the left button over the Reply... menu button.
A menu with a few entries will be displayed.
Select the \fIReply to sender\fP menu entry by dragging the mouse
down to that entry and letting up over it.
The menu entry has a <Key-r> in it, which means that you could
also press the 'r' key to invoke this function.
.PP
This time the built-in editor will open a window with a message that
is partly filled in.  All the headers are initialized based on the
header components from the original message.
The built-in editor will automatically position the cursor at the
beginning of the message body.  You can enter your reply message
like you did with the previous messages.  You should also double-check
the header components.  In this case, add yourself to the Cc: component
so you will get a copy of the reply message.  When you are done,
press the Send button in the editor window to send the message.
.PP
There are a number of ways to control the format of your reply messages.
The MH \fIrepl\fP command has several formatting options,
and because \fIexmh\fP uses \fIrepl\fP to set up the reply message,
you can customize your reply format.
\fIExmh\fP lets you define several variations on reply and add them
to the Reply... menu.  This is described in the \fBexmh-custom\fP man page.
.PP
It should not take long for you to get the copy of the reply message.
Wait a minute or so and press the Inc button.
The keyboard short-cut for Inc is the 'i' key.
.SH SELECTING MESSAGES
.PP
Before we go on to more things you can do with messages,
we need to talk about selecting multiple messages at once.
Several of the message operations in \fIexmh\fP can operate on
a set of messages.
You can manually select multiple messages by using the mouse,
or you can select messages based on their content.
.PP
\fBUsing the Mouse\fP.
To select messages with the mouse, press the left button
and then drag out a selection.  This will select a contiguous
range of messages.
If the messages you want to select are not so nicely
organized, you can make a disjoint selection by holding down
the Shift key while making your selection.
This adds new messages to the selection.
If you shift-click on a message that is already selected,
then it becomes unselected.
If you need to select a lot of messages, simply drag the mouse off
the top or bottom of the window.  It will be scrolled automatically
and the selection will be extended.
.SH SEARCHING
.PP
The Search... menu has several operations for finding messages
and finding text within a message.
There is also a help entry that explains searching in more detail.

If you select "Find in message body" or "Find in table of contents"
a small search dialog appears.
Enter the search string and use the Next or Prev buttons to
find the next match.
When you are searching over the table of contents, you can
select All to select all matching messages.
.PP
The other way to search a folder is with "Pick by attributes".
The MH pick program is used to search
the current folder for messages that match
mail headers like From or Subject.
You can build up boolean expressions among search criteria.
This is a much more general search mechanism than
the "Find in table of contents" operation.
.PP
Get started in the Pick dialog by pressing the "Choose pick attribute"
button.  A menu of attribute types appears, including the Subject,
From, To, and Cc header components.
You can type a regular expression pattern in these entries to search for
messages that have a matching header component.
.PP
The Before and After attributes are dates.
You can find all messages before or after a given date by
using these fields.
You can specify dates as mm/dd/yy.  Be sure to include the year.
Dates can also be keywords like "today", "yesterday", "tomorrow",
and any day of the week ("Sunday", "Monday", and so on.)
.PP
The Search attribute is used to search for something in the body of a message.
This will run little slower because \fIpick\fP must read through
all of your messages, not just their headers.
.PP
If you select more than one attribute, \fIpick\fP finds messages
that match all the criteria.  In other words, it does the logical
\fIand\fP of the search criteria.  If you want to search for this \fIor\fP
that, then you need to press the Or button in the dialog.
This adds another set of fields to the dialog, and pick will search
for everything that matches the first set \fIor\fP matches the
second set.
.PP
The "Add to Sel" checkbutton should be set \fIbefore\fP you do the
search.  This controls whether or not the selected messages are
added to any existing selection.
.PP
Finally, use the "Pick" button to do the search.  Once the search has
completed you can perform a few operations on the selection.
You can delete and refile messages as described later.
You can also display a new table of contents that only contains the
selected messages.  Use the "New FTOC" button for this.
You can also clear the unseen state of the messages with the "Mark Seen"
button.
.PP
The "Clear" button resets the fields.
.PP
The two entries in the dialog are used to control MH sequences.
The only sequence exmh really supports well is the "unseen" sequence,
although you can define up to 10 sequences in each folder.
.PP
If you use New FTOC to get a new scan listing, it would be better if
it appeared in a new window, but currently it replaces the table
of contents.  You can move around and manipulate messages in this
table of contents.  However, if you do another pick, it will only
find things in this limited table of contents, not the whole folder.
(Yes, this is a bug.)
Use the Rescan Folder menu entry in the folder More... menu to
get a complete folder listing.
.SH FORWARDING MESSAGES
.PP
If you want to send someone a copy of a message or messages
that you have received,
use the Forward message operation.
Select the messages as described in the previous section,
then press the Forward button.
The keyboard short-cut for forward is the 'f' key.
.PP
The message template will have a copy of the selected messages.
You fill in the headers, and you can also add a short message
before the start of the forwarded messages.  When you are done,
press Send to forward the messages.
.SH DELETING MESSAGES
.PP
After you have read a message, you might want to remove it to keep
your mail folders tidy.  \fIExmh\fP uses two steps to remove mail.
In the first step you \fImark\fP a message as being deleted.
In the second step you \fIcommit\fP the operations on all marked messages.
It turns out that delete just renames your message files.  They will
survive until you get another message by the same number and remove it, too.
In addition, exmh has a "Purge Folder" operation that removes these
renamed files if they are more than a week old.
.PP
The Delete operation applies to the current message, or
you can also select a range of messages by dragging out
a selection in the table of contents.
You can delete the current message(s) by pressing the Delete button.
The keyboard short-cut is the 'd' key.
The deleted message(s) will be highlighted after the delete operation
so you can easily see the state of the message.
On a monochrome screen, a cross hatching will be drawn through the
table of contents line for the message.
On a color screen, the table of contents
line will get a dark grey background.
.PP
After you mark a message for delete, you are automatically advanced
to the next message.  This makes it easy to go through your folder
and clean it up.  Click 'd' to delete, or click 'n' to leave it alone.
.PP
\fIHint\fP.  If you are really in a hurry, use 'D' and 'N' as your
keyboard short-cuts.  This prevents the next message from being displayed,
which can be slow for complex multi-media messages.
.PP
When you are ready to commit the pending delete actions,
press the Commit button.
The keyboard shortcut for commit is <Control-Return>.
.PP
If you decide you do not want to delete a message
you can unmark it.  Use the \fIUnmark (Undo)\fP menu entry that
is under the message More... menu.  The unmark operation applies to
the current message or messages, so you have to select the messages
to unmark first.  The keyboard short-cut for unmark is 'u'.
.PP
\fIHint\fP.  The minus, '-', keyboard shortcut takes you to the
previous message, even if it has been marked for delete.
Ordinarily the Prev operation, and the 'p' short-cut for it,
will skip over marked messages.
.SH LEAVING EXMH
.PP
Press the Quit button to leave exmh.
It will take a few moments to close down because it saves
some state information before quitting.  The Quit button will
grey out after you click it, and you will see a few status messages
as it shuts itself down.
.SH PREFERENCES
.PP
Try out the Preferences by turning off the folder cache.
This just takes up display space if you don't have many folders.
If you have lots of nested folders, though, you might even want to
make this display bigger!
.PP
Click the Preference button, which brings up a dialog that has
buttons for several of the modules that make up \fIexmh\fP.
Click on the Folder Cache button to bring up the preference items
that control the folder cache.  In this case there are just two items:
the number of lines of labels in the cache, and the names of folders
that are always in the cache.  Click in the first field and
backspace over the default value of 1.  Type in 0 instead, and
press <Return>.  Voila!  The folder cache disappears.
.PP
If you like this setting, press Save on the main Preference dialog
and your changes will be saved to a file named ~/.exmh-defaults.
Press Reset if you want to undo your changes.
You should be a little careful here, because you are allowed to
Dismiss the preference dialog without saving.
.PP
Another useful preference item to set is under Background Processing.
You can arrange for \fIexmh\fP to periodically run \fIinc\fP so your
messages are automatically transferred into your inbox.
The advantage of doing this is that the folder label highlighting
works best this way.  Unfortunately, \fIexmh\fP does not give you
any visual clues when mail is only waiting in your system spool file.
.PP
More details about the Preferences dialog are given in the \fBexmh-use\fP
man page, and an overview of the various preference sections is
given in the \fBexmh-custom\fP man page..
.SH "WHAT IS MH MAIL?"
.PP
MH is a collection of UNIX programs that store, manipulate, and display
your mail. MH originated from RAND, and it is now in the public domain.
Exmh uses these programs to do all the hard work,
while it concentrates on the user interface.
.PP
You can use the MH programs to read your mail.
Run them from the UNIX command line like you would
cd, ls, cc, or make.  They are useful
when you are connecting over a slow line or cannot run exmh for
some other reason.
For more details, there are individual man pages for each MH program,
plus one overview man page called MH.
Below is a short summary of the main MH programs used by exmh.
.IP folder
Query or set the current folder.
.IP inc
Incorporate mail from your system spool file into your folders.
.IP scan
Display a listing of a mail folder.
.IP show
Display a mail message.
.IP next
Display the next mail message.  (Exmh doesn't actually run this.)
.IP prev
Display the previous mail message.  (Exmh doesn't actually run this.)
.IP rmm
Delete a mail message.
.IP refile
Move a message into another mail folder.
.IP repl
Reply to a mail message
.IP forw
Forward one or more mail messages.
.IP comp
Compose a new mail message.
.PP
MH keeps track of the current folder and the current message
in between uses of these MH programs.  For example:
.DS
% scan +inbox unseen
1713  04/14 foote.PARC@xerox.  Have you started blasting cdroms yet?<<Probably.
1715  04/14 FlashBack Publish  1232: Tactix Introduces Break through in Unix Ad
1716  04/14 FlashBack Publish  1234: CERT Advisory - NCSA HTTP Daemon for UNIX<
1717 M04/15 To:welch           PGP test<<-----BEGIN PGP MESSAGE----- Version: 2
1718 M04/17 flash@flashback.c  mime-flashback-w MIME FlashBack April 13th, 1995
1719 -04/16 Bill Wohler        Notes for MH Chapters 20-22<<Brent, I have been 
1720+-04/17 "Allen R. Carl"    Re: Tabs<<Brent, where is this -tabs resource se
% show 1717
(Message 1717 displayed)
% next
(Message 1718 displayed)
% rmm
(Message 1718 deleted)
% repl 1717
(Set up template for reply to message 1717, invoke editor)
.DE
.PP
Each user has a .mh_profile file that stores general MH settings
as well as per-command settings.  Each line has a key, and a value.
For example, your mail directory is set with the Path profile entry:
.DS
Path: Mail
.DE
.PP
If your old mail system uses that directory already, just edit
your .mh_profile to change the name used for your MH mail folders.

.SH MORE ABOUT EXMH
.PP
This man page should get you started with \fIexmh\fP.
If you decide you want to know more about it,
here are some of the features described in the other \fIexmh\fP man pages.
.PP
\fBMIME support\fP.  \fIExmh\fP can display
MIME (Multipurpose Internet Mail Extensions)
messages, either directly or with the
help of the \fImetamail\fP package.
The built-in editor lets you compose enriched text messages
and insert files as parts of a multipart message.
.PP
\fBMail Folders\fP.
You can create other mail folders to hold messages about certain
topics or from certain people.
You can create a hierarchical arrangement of folders,
just like the hierarchical directory structure of the file system.
The folder display supports these \fInested folders\fP,
and it allows you to nest folders to any depth.
.PP
\fBMail Filtering\fP.
Mail filtering lets you sort mail into different folders
\fIbefore\fP you read it.
If you get lots of mail, this is a great way to avoid plowing
through junk mail just to get your important messages.
The folder labels are highlighted to
indicate which folders have unread mail in them.
.PP
\fBFacesaver bitmap display\fP.  If you have a facesaver database
on your system, \fIexmh\fP displays the bitmap face of the person
that sent the current message (or their organization).
.PP
\fBBackground processing\fP.  You can set \fIexmh\fP to run
\fIinc\fP periodically,
check for new messages arriving asynchronously in folders,
run the MH \fImsgchk\fP program,
or count up the messages in your mail spool file.
.PP
\fBEditor interface\fP.  You can hook \fIexmh\fP to your favorite editor
using the \fBexmh-async\fP script.  Or, Tcl-based editors such
as \fImxedit\fP can interact with \fIexmh\fP directly.
.PP
\fBKeybinding User Interface\fP.  You can define new key bindings for
Tcl commands that are part of the implementation.
.PP
\fBAliases User Interface\fP.  A browser for your MH aliases lets you
define new aliases and insert aliases into mail messages.
.PP
\fBPretty Good Privacy (PGP)\fP.  If you have PGP, you can use it from
\fIexmh\fP to digitally sign, encrypt, and decrypt messages.
.PP
\fBUser Programming\fP.  If the preference settings are not enough for you,
you can program \fIexmh\fP more directly.  You can define new buttons
and menus and add new Tcl code to its implementation.
.SH SEE ALSO
exmh-use, exmh-ref, exmh-custom, mh
.SH AUTHOR
Brent Welch, <welch@acm.org>
.SH THANKS
To Xerox PARC/CSL, for supporting this work initially,
to Sun Microsystems Laboratories for continuing the support,
and to all the exmh users that contributed ideas and code.
