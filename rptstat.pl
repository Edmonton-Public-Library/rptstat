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

usage: $0 [-x] [-d ascii_date] [-n report_name] [-2345789[aAbBcDghHiIMmopstTu]] [-i file]

 -d yyyymmdd : checks the reports for a specific day (ASCII date format)
 -i file     : UNFINISHED input file of stats you want to collect. Should be formated as:
               name|date (optional)|code1|code2|...|codeN|
             Example: 
               Generalized bills||5u|, which would report the number of user's selected from 
               today's report.
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
 code        : I - ascii
               A - authority
               B - bib
               b - bill
               n - callnum
               t - catacnt
               C - catalog
               c - charge
               g - charge
               H - chargehist
               M - communication
               h - hold
               i - item
               m - itemacnt
               N - notice
               p - pickup
               T - transact
               u - user
               a - useracnt
               s - userstatus
 -x          : this (help) message

example: $0 -d 20120324 -n "Generalized bills" -9u

EOF
    exit;
}

# use this next line for production.
my $listDir            = `getpathname rptprint`;
chomp($listDir);
my $printList          = qq{$listDir/printlist};
my $date               = `transdate -d+0`;       # current date preseed.
chomp($date);
my @reportList;                                  # list of reports we want results from.
my $options;                                     # Hash ref to the users switches for report output (all num switches)

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'd:i:n:o:x2:3:4:5:7:8:9:';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ($opt{'x'});
    $date = $opt{'d'} if ($opt{'d'});
	if ($opt{'i'})
	{
		open REPORT_LIST, "<$opt{'i'}" or die "Error: unable to open input report list: $!\n";
		@reportList = <REPORT_LIST>;
		close REPORT_LIST;
	}
	$options = getCmdLineOptionsForResults();
}
init();

open(PRINTLIST, $printList) || die "Failed to open $printList: $!\n";
my @printListLines = <PRINTLIST>;
close(PRINTLIST);

if ($opt{'i'})
{
	foreach my $reportListEntry (@reportList)
	{
		my @optionList = split('\|', $reportListEntry);
		my $name = $optionList[0];
		my $d    = $optionList[1];
		# Did the user enter the minimum of an ascii date value?
		if ($d ne "" and $d =~ m/\d{8}/) 
		{
			$date = $d;
		}
		shift(@optionList);
		shift(@optionList);
		# fill the options
		foreach my $o (@optionList)
		{
			# Split the '5u' pairs and populate options hash 
			# this will overwrite any other options specified on cmd line.
			my @switchCode = split('', $o);
			# block malformed switch code pairs and ignore if they are longer than a pair.
			if (defined($switchCode[0]) and defined($switchCode[1]))
			{
				$options->{$switchCode[0]} = $switchCode[1];
			}
		}
		runSearch($name, $date, $options, @printListLines);
	}
}
else # just one report requested by -n on the command line.
{
	runSearch($opt{'n'}, $date, $options, @printListLines);
}


sub runSearch
{
	my ($name, $date, $options, @printListLines) = @_;
	my $itemsPrinted = 0;
	my ($report, @printListEntry) = getReportFile($name, $date, @printListLines);
	if ($report ne "")
	{
		$itemsPrinted += getRptMetaData($opt{'o'}, @printListEntry);
		$itemsPrinted += getRptResults($report, $options);
	}
	if ($itemsPrinted > 0)
	{
		print "\n";
	}
}

# Gets the options for the type of results the user wants to display from the report.
# param:  none
# return: hash reference of all the -[0-9] switches and options.
sub getCmdLineOptionsForResults
{
	my $hashRef;
	for my $key ( keys %opt )
	{
		if ($key =~ m/\d/) # we save all the numeric switches only.
		{
			$hashRef->{$key} = $opt{$key};
		}
    }
	return $hashRef;
}

# Checks the print list for the requested report by name and requested date
# default to today, and returns the name of the file and the entry from printlist.
# param:  reportName - string the name of the report.
# param:  date - requested date.
# return: (the fully qualified path to the report file, entry from print list as a List)
#         or an empty string if no suitable entry found.
sub getReportFile
{
	my ($rptName, $date, @printListLines) = @_;
	# Search the print list for candidate reports.
	if ($rptName eq "")
	{
		return "";
	}
	my $itemsPrinted = 0;
	foreach my $printListLine (@printListLines)
	{
		# vszd|Convert DISCARD Items CSDCA3|201202080921|OK|ADMIN|cvtdiscard|0||
		my @printListEntry = split('\|', $printListLine);
		# field 5 (0 indexed) contains the last run date and 
		# if the time stamp the report ran matches the specified ascii date, and the name matches:
		if ($printListEntry[1] =~ m/($rptName)/ and substr($printListEntry[2], 0, 8) eq $date)
		{
			# get it from the rptprint directory/wwqk.log
			return (qq{$listDir/$printListEntry[0].log}, @printListEntry);
		}
	}
	return "";
}

# This function prints out the requested metadata about the report.
# param: outParams - string of codes user would like to see output.
# param: printListRecord List: vszd|Convert DISCARD Items CSDCA3|201202080921|OK|ADMIN|cvtdiscard|0||
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
	my ($reportFile, $options) = @_;
	my $count = 0;
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
	foreach my $line (@log)
	{
		while ( my ($switch, $code) = each(%$options) )
		{
			# find the code match per line. Note we only look for 130[n] codes.
			if ($line =~ m/\$<($outParams{$code})> \$\(130($switch)\)/)
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
