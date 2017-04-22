# calendar.tcl
# Handling of text/calendar body parts if mhical is available from
# a sufficiently new nmh, and post to a Google calendar if gcalcli is found.
#
# Some code shamelessly re-used from receipt.tcl
#
# We blindly run mhical so user default config applies
# Probably should accept a 'mhical commandline' from exmh.prefs
#

proc calendarGenerate {bodyPart method} {
global calendar

# Create a draft, and run something like:
# mhical $method -contenttype
# # and ship it off
}

proc calendarGoogle {tkw address} {
global calendar
#
# Run gcalcli --calendar=$calendar(googleCalendar) import $bodypart
}


proc calendarAsk {tkw address explain} {
    global mimeHdr exmh calendar

    $tkw insert insert " The sender has sent you a calendar event."

# We need to invoke calendar(pref_ical) mhcali here
#
# too-do - track down "unexpected input: whinges"

    $tkw insert insert "\n\n Do you wish to accept this calendar event?"
    $tkw insert insert "\n\n"

    TextButton $tkw "Accept event" \
	[list calendarGenerate $mimeHdr(0,rawfile) "-reply accept" ]

    TextButton $tkw "Accept tentative event" \
	[list calendarGenerate $mimeHdr(0,rawfile) "-reply tentative" ]

    TextButton $tkw "Decline event" \
	[list calendarGenerate $mimeHdr(0,rawfile) "-reply decline" ]

    TextButton $tkw "Cancel event" \
	[list calendarGenerate $mimeHdr(0,rawfile) "-cancel" ]

    if {$exmh(have_gcalci) && calendar(googleCalendar) != {} } {
        TextButton $tkw "Schedule Goggle Calendar event" \
	    [list calendarGoogle $mimeHdr(0,rawfile) "schedule" ]
    }
    
    $tkw insert insert "\n"
    MimeInsertSeparator $tkw 0 6
}



