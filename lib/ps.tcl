# ps.tcl
#
#	Code to look for processes in the process table.
# Copyright 1995 Xerox Corporation All rights reserved.
#License is granted to copy, to use, and to make and to use derivative works for
# research and evaluation purposes, provided that the Xerox copyright notice and
# this license notice is included in all copies and any derivatives works and in
# all  related documentation.  Xerox grants no other licenses expressed or
# implied and the licensee acknowleges that Xerox has no  liability for
# licensee's use or for any derivative works  made by licensee. The Xerox  name
# shall not be used in any advertising or the like without its written
# permission.
# This software is provided AS IS.  XEROX CORPORATION DISCLAIMS AND LICENSEE
# AGREES THAT ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
#THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#NOTWITHSTANDING ANY OTHER PROVISION CONTAINED HEREIN, ANY LIABILITY FOR DAMAGES
# RESULTING FROM THE SOFTWARE OR ITS USE IS EXPRESSLY DISCLAIMED, INCLUDING
# CONSEQUENTIAL OR ANY OTHER INDIRECT DAMAGES, WHETHER ARISING IN CONTRACT, TORT
# (INCLUDING NEGLIGENCE) OR STRICT LIABILITY, EVEN IF XEROX CORPORATION IS
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGES."
#

if [catch {exec uname -s} os] {
    set os nextstep	;# No uname there
    set name noname
} else {
    if [catch {exec uname -n} name] {
	set name $os
    }
}
if {[string compare $name $os] == 0} {
    # Bogus OS name on many SYS V systems
    set os unix_sv
}
if {[info exist env(LOGNAME)]} {
    # Sys V has LOGNAME instead of USER
    set env(USER) $env(LOGNAME)
}

# Defaults for SunOS 4.1.3
catch {unset ps}
set ps(cmd) ps
set ps(pflag) ""	;# -p on some systems to query process
set ps(aflag)  x	;# To list all processes owned by the user

switch -glob -- [string tolower $os] {
    sunos {
	if [regexp ^5 [exec uname -r]] {
	    set ps(cmd) /bin/ps	;# Not /usr/ucb
	    set ps(pflag) -p
	    set ps(aflag) "-u $env(USER)"
	}
    }
    *bsd*	-
    nextstep	-
    nextstep-i386	-
    linux {
	# BSD-like systems. 
	# Verified: linux
	# defaults OK
    }
    ultrix	{
	set ps(pflag) ""
	set ps(aflag) "-u $env(USER)"
    }
    osf1	-
    aix		-
    dgux	-
    sco_sv	-
    *ptx*	-
    unix	-
    hp-ux	-
    irix*	-
    convexos	-
    epix	-
    uts		-
    sinix-d	-
    unix_system_v -
    unix_sv	{
	# SYS V like systems
	# Verified: irix, hp-ux
	set ps(pflag) -p
	set ps(aflag) "-u $env(USER)"
    }
    default {
	puts stderr "Unknown OS $os - check ps.tcl"
    }
}

proc PsByID { pid } {
    global ps
    eval exec $ps(cmd) $ps(pflag) $pid
}
proc PsByName { program } {
    global ps
    set in [open "|$ps(cmd) $ps(aflag)"]
    while {[gets $in line] >= 0} {
	if ![regexp {^ *([0-9]+) .*[0-9:.]+ +([^ ]+)} $line x pid name] {
	    continue
	}
	if [regexp -- $program $name] {
	    catch {close $in}
	    return $pid
	}
    }
    catch {close $in}
    return {}
}
proc PsTest {{self tclsh}} {
    puts [exec uname -a]
    puts "My process ID is [pid]"
    if [catch {PsByName $self} err] {
	puts "PsByName $self failed: $err"
    } elseif {$err != [pid]} {
	puts "PsByName($self) failed $err"
    } else {
	puts "PsByName OK"
    }
    if [catch {PsByID [pid]} err] {
	puts "PsByID([pid]) failed: $err"
    } else {
	puts "PsByID([pid]) OK"
    }
}
