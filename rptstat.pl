#!/s/sirsi/Unicorn/Bin/perl
########################################################################
# Purpose: Get results of a given report report.
# Method:  The script reads the printlist searching for Convert discards
#          reports for a user specified day (default: today). It then
#          searches for the day's remove_discard_items report to retrieve
#          the daily removed items total. Much of this code is reusable
#          for the Morning stats reporting. All results and statuses are
#          printed to STDOUT.
#
# Author:  Andrew Nisbet
# Date:    May 25, 2012
# Rev:     0.0 - develop
########################################################################

use strict;
use warnings;
use vars qw/ %opt /;
use Getopt::Std;
use Switch;

# Id| Report name                   | Run date |Status|Owner|Script|
# vtfs|Generalized Bill Notices Weekday|201202090552|OK|ADMIN|bill|0||
# 1302	record(s) edited.
# 1303	record(s) printed.
# 1304	item(s) printed.
# 1305	record(s) processed.
# 1306	bad input record(s) encountered.
# 1307	record(s) encountered.
# 1308	record(s) considered.
# 1309	record(s) selected.
#
# Message about this program and how to use it
#
sub usage()
{
    print STDERR << "EOF";

This script takes the name, or partial name of a report finds it by date
(default today) and outputs the results to STDOUT.

usage: $0 [-x] [-d ascii_date] [-n report_name] [-m email] [-2345789[aAbBcDghHiIMmopstTu]]

 -d yyyymmdd : checks the reports for a specific day (ASCII date format)
 -n name     : name (or partial name) of report.
 -o output   : output capital letters for report meta data lowercase for report results:
               d - date ascii
			   D - date and time ascii
			   r - Report name
			   s - status
			   o - owner
			   n - script name
			   c - report code - 4 digit code for tracking.
 -2 <code>   : records edited
 -3 <code>   : records printed
 -4 <code>   : items printed
 -5 <code>   : records processed
 -7 <code>   : records encountered
 -8 <code>   : records considered
 -9 <code>   : records selected
 code        :	I	ascii
				A	authority
				B	bib
				b	bill
				n	callnum
				t	catacnt
				C	catalog
				c	charge
				g	charge
				H	chargehist
				M	communication
				h	hold
				i	item
				m	itemacnt
				N	notice
				p	pickup
				T	transact
				u	user
				a	useracnt
				s	userstatus
 -m addrs    : mail output to provided address
 -x          : this (help) message

example: $0 -d 20120324 -m anisbet\@epl.ca

EOF
    exit;
}

# use this next line for production.
my $listDir            = `getpathname rptprint`;
chomp($listDir);
my $printList          = qq{$listDir/printlist};
my $date               = `transdate -d+0`;       # current date preseed.
chomp($date);
my $outParams;

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'd:n:o:m:x2:3:4:5:7:8:9:';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ($opt{x});
    $date = $opt{'d'} if ($opt{d});
}
init();
my $mail = "";
open(PRINTLIST, $printList) || die "Failed to open $printList: $!\n";
my @printListLines = <PRINTLIST>;
close(PRINTLIST);
# Search the print list for candidate reports.
foreach my $printListLine (@printListLines)
{
	# vszd|Convert DISCARD Items CSDCA3|201202080921|OK|ADMIN|cvtdiscard|0||
    my @printListEntry = split('\|', $printListLine);
    # field 5 (0 indexed) contains the last run date.
    #print $printlistColumn[0].":".substr($printlistColumn[2], 0, 8)."\n";
    # if the time stamp the report ran matches the specified ascii date, and the name matches:
    if ($printListEntry[1] =~ m/($opt{'n'})/ and substr($printListEntry[2], 0, 8) eq $date)
    {
		#print "$printListEntry[2]::I found the entry for $opt{'n'} in log file: $printListEntry[0].log for date $date\n";
        # get it from the rptprint directory/wwqk.log
        my $logFile = qq{$listDir/$printListEntry[0].log};
		my $itemsPrinted = 0;
		$itemsPrinted += getRptMetaData($opt{'o'}, @printListEntry);
		$itemsPrinted += getRptResults($logFile, 1302, $opt{'2'});
		$itemsPrinted += getRptResults($logFile, 1303, $opt{'3'});
		$itemsPrinted += getRptResults($logFile, 1304, $opt{'4'});
		$itemsPrinted += getRptResults($logFile, 1305, $opt{'5'});
		$itemsPrinted += getRptResults($logFile, 1307, $opt{'7'});
		$itemsPrinted += getRptResults($logFile, 1308, $opt{'8'});
		$itemsPrinted += getRptResults($logFile, 1309, $opt{'9'});
		if ($itemsPrinted > 0)
		{
			print "\n";
		}
    }
}

# This function prints out the requested metadata about the report.
# param: outParams - string of codes user would like to see output.
# return: number of switches set.
sub getRptMetaData
{
	my ($outParams, @printListRecord) = @_;
	my $count = 0;
	if (!defined($outParams))
	{
		return $count;
	}
	foreach my $inputChars (split('', $outParams))
	{
		switch ($inputChars) 
		{
			# d - date
			# D - date-time
			# r - Report name
			# s - status
			# o - owner
			# n - script name
			# c - report code - 4 digit code for tracking.
			# vszd|Convert DISCARD Items CSDCA3|201202080921|OK|ADMIN|cvtdiscard|0||
			case 'D' { print "$printListRecord[2]|"; $count++ }
			case 'd' { print substr($printListRecord[2], 0, 8)."|"; $count++ }
			case 'r' { print "$printListRecord[1]|"; $count++ }
			case 's' { print "$printListRecord[3]|"; $count++ }
			case 'o' { print "$printListRecord[4]|"; $count++ }
			case 'n' { print "$printListRecord[5]|"; $count++ }
			case 'c' { print "$printListRecord[0]|"; $count++ }
			else     { print "" }
		}
	}
	return $count;
}

# This routine prints out the user's requested report results.
# param: reportFile - string of the name of the file we are getting results from.
# param: outParams - string of requested codes.
# param: printListRecord - list from print list formatted as:
#        vszd|Convert DISCARD Items CSDCA3|201202080921|OK|ADMIN|cvtdiscard|0||
sub getRptResults
{
	my ($reportFile, $switch, $options) = @_;
	my $count = 0;
	if (!defined($options))
	{
		return $count;
	}
	my %outParams = (
		'I'=>"ascii",
		'A'=>"authority",
		'B'=>"bib",
		'b'=>"bill",
		'n'=>"callnum",
		't'=>"catacnt",
		'C'=>"catalog",
		'c'=>"charge",
		'g'=>"charge",
		'H'=>"chargehist",
		'M'=>"communication",
		'h'=>"hold",
		'i'=>"item",
		'm'=>"itemacnt",
		'N'=>"notice",
		'p'=>"pickup",
		'T'=>"transact",
		'u'=>"user",
		'a'=>"useracnt",
		's'=>"userstatus",
	);
	open(REPORT, "<$reportFile") or die "Error opening $reportFile: $!\n";
	my @log = <REPORT>;
	close(REPORT);
	# TODO get the actual text for each of the supplied options.
	my @codeOptions = split('', $options);
	foreach my $line (@log)
	{
		foreach my $code (@codeOptions)
		{
			# find the code match per line.
			if ($line =~ m/\$<($outParams{$code})> \$\(($switch)\)/)
			{ 
				print trim(substr($line, 0, index($line, "<") -1))."|";
				$count++;
			}
		}
	}
	return $count;
}

# Trim function to remove whitespace from the start and end of the string
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
