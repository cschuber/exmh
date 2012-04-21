#!/usr/local/bin/bash
# query_jpilot.sh
# (c) Gerhard Siegesmund (gerhard.siegesmund@epost.de)

# Adjust the paths.
TEMP=/tmp
jpilotdump=/usr/local/bin/jpilot-dump

# In which records of an entry to search. Here e.g. the 4. userdefined field
# where I put the nickname of people. You can use (nearly) anything you like,
# just don't use tabs in here (see jpilot-dump -? for help). If you just want
# to search for the default, meaning name, lastname company, just set to ""
more=""
#more=" %U4"

tempnumber=$RANDOM.$$.`date +%s`
tempdb=$TEMP/jpilot-email-dump.$tempnumber
tempresult=$TEMP/jpilot-email-result.$tempnumber

function thatsit () {
        rm -f $tempdb
        rm -f $tempresult
        exit $1
}

# Is there a querystring?
if [ -z "$1" ]; then
        echo "No querystring. Please try again with a querystring!"
        exit 1
fi

# Create temporary Database-File
(for nummer in 1 2 3 4 5; do
        $jpilotdump +A"%p$nummer%t%f %l%t%c$more" -A
done) | grep @ > $tempdb

numall=`cat $tempdb | wc -l | sed -e "s/[^0-9]//g"`
if [ $numall = "0" ]; then
        echo "No emails found in your jpilot-database"
        thatsit 2
fi

# Search for the querystring
cat $tempdb | grep -i $1 > $tempresult

numres=`cat $tempresult | wc -l | sed -e "s/[^0-9]//g"`
if [ $numres = "0" ]; then
        echo "Didn't find the querystring \"$1\" in the database (Searched $numall records)."
        thatsit 3
fi

# Output the result
echo "Searched $numall records. Found $numres matching records."
cat $tempresult

thatsit 0

