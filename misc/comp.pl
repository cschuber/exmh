#!/usr/bin/perl -w

# Arguments to the script:
#   1  to
#   2  -c cc
#   3  -b bcc
#   4  -s subject
#   5  -i body file
#   6  org

use FileHandle;
use strict;

use Getopt::Long;

# set this to your normal components file
my $comps = "/home/slipcon/Mail/components";

# I have two variables here because I run netscape and exmh on different
# machines.  If you run them on the same machine, you can set $usecomps to
# the same value as $newcomps.
my $newcomps = "/net/mercea/tmp/components.$<.$$";
my $usecomps = "/tmp/components.$<.$$";
#my $usecomps = $newcomps;

use vars qw($to $cc $bcc $subj $bodyfile $org);
use vars qw($haveto $havecc $havebcc $havesubj $havebodyf $haveorg);

$haveto = $havecc = $havebcc = $havesubj = $havebodyf = $haveorg = 1;

$to = shift @ARGV;
GetOptions("c=s" => \$cc, "b=s" => \$bcc, "s=s" => \$subj, "i=s" => \$bodyfile);
$org = shift @ARGV;

if (!defined($to)) {
	$haveto = 0;
	$to = "";
}
if (!defined($cc)) {
	$havecc = 0;
	$cc = "";
}
if (!defined($bcc)) {
	$havebcc = 0;
	$bcc = "";
}
if (!defined($subj)) {
	$havesubj = 0;
	$subj = "";
}
if (!defined($bodyfile)) {
	$havebodyf = 0;
	$bodyfile = "";
}
if (!defined($org)) {
	$haveorg = 0;
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
		$haveto = 0;
	} elsif ((/^Cc:/) || (/^cc:/)) {
		print $outfh $_ . " " . $cc . "\n";
		$havecc = 0;
	} elsif ((/^Bcc:/)  || (/^bcc:/)) {
		print $outfh $_ . " " . $bcc . "\n";
		$havebcc = 0;
	} elsif (/^Organization:/) {
		print $outfh $_ . " " . $org . "\n";
		$haveorg = 0;
	} elsif (/^Subject:/) {
		print $outfh $_ . " " . $subj . "\n";
		$havesubj = 0;
	} elsif (/^--------/) {  # end of components file
		if ($havebcc) {
			print $outfh "Bcc: $bcc\n";
			$havebcc = 0;
		}
		if ($haveorg) {
			print $outfh "Organization: $org\n";
			$haveorg = 0;
		}
		print $outfh "--------\n";
		if ($havebodyf) {
			my $bodyfh = new FileHandle;
			$bodyfh->open($bodyfile);
			while (<$bodyfh>) {
				print $outfh $_;
			}
			$bodyfh->close();
		}
	} else {
		print $outfh $_ . "\n";
	}
}
$infh->close();
$outfh->close();

system("echo \"send exmh Msg_Compose -form $usecomps\nexit\n\" | wish");
system("rm $newcomps");
