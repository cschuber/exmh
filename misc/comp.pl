#!/usr/bin/perl -w

# Arguments to the script:
#   1  to
#   2  cc
#   3  bcc
#   4  subject
#   5  body file
#   6  org

use FileHandle;
use strict;

# set this to your normal components file
my $comps = "/home/slipcon/Mail/components";

# I have two variables here because I run netscape and exmh on different
# machines.  If you run them on the same machine, you can set $usecomps to
# the same value as $newcomps.
my $newcomps = "/net/mercea/tmp/components.$<.$$";
my $usecomps = "/tmp/components.$<.$$";

(my $to, my $cc, my $bcc, my $subj, my $bodyfile, my $org) = @ARGV;

if (!defined($to)) {
	$to = "";
} 

if (!defined($cc)) {
	$cc = "";
}

if (!defined($bcc)) {
	$bcc = "";
}

if (!defined($subj)) {
	$subj = "";
}

if (!defined($bodyfile)) {
	$bodyfile = "";
}

if (!defined($org)) {
	$org = "";
}

my $infh = new FileHandle;
my $outfh = new FileHandle;

$outfh->open(">$newcomps");
$infh->open($comps);
while (<$infh>) {
	chomp;
	if (/^To:/) {
		print $outfh $_ . " " . $to . "\n";
	} elsif ((/^Cc:/) || (/^cc:/)) {
		print $outfh $_ . " " . $cc . "\n";
	} elsif (/^Subject:/) {
		print $outfh $_ . " " . $subj . "\n";
	} else {
		print $outfh $_ . "\n";
	}
}
$infh->close();
$outfh->close();

system("echo \"send exmh Msg_Compose -form $usecomps\nexit\n\" | wish");
system("rm $newcomps");
