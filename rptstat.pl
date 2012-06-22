#!/s/sirsi/Unicorn/Bin/perl -w
########################################################################
# Purpose: Get results of a given report report.
# Method:  The script reads the printlist searching for Convert discards
#          reports for a user specified day (default: today). It then
#          searches for the day's remove_discard_items report to retrieve
#          the daily removed items total. Much of this code is reusable
#          for the Morning stats reporting. All results and statuses are
#          printed to STDOUT.
#
# Author:  Andrew Nisbet, Edmonton Public Library.
# Date:    May 25, 2012
# Rev:     0.1 - develop
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
(default today) and outputs the results to STDOUT. The 3rd field in the -i file
can include a script to run who's output will be printed first. If the script requires
the current report as an argument, then use the \@ character as a placeholder for the
name of the report being reported on.
Example: './count.pl -i \@.prn -s "\.email"' will run the script with \@ symbol expanded to:
'./count.pl -i /s/sirsi/Unicorn/Rptprint/xast.prn -s "\.email"'.

usage: $0 [-x] [-d ascii_date] [-n report_name] [-2345789[aAbBcDghHiIMmopstTu]] [-i file] [-D]

 -d yyyymmdd : checks the reports for a specific day (ANSI date format)
 -i file     : UNFINISHED input file of stats you want to collect. Should be formated as:
               name (required)|date (required but can be blank)|script and params (required but can be blank|code1|code2|...|codeN|
             Example: 
               Generalized bills|||5u|
               which would report the number of user's selected from today's report.
             Example:
               Holds Notices|20120614|./script.pl -e|9N|
               which would print the output from script.pl -e as the results in addition
               to the codes you specify. You may get unpredictable results depending on the executable's behaviour.
 -n name     : name (or partial name) of report.
 -o          : output capital letters for report meta data lowercase for report results:
               d - date ascii
               D - date and time ascii
               r - report name
               s - status
               o - owner
               n - script name
               c - report code - 4 character code report file name.
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
 -s script   : script that you want to run.
 -x          : this (help) message

example: $0 -d 20120324 -n "Generalized Bill" -5u -s"count.pl -i @.log -s\"\.email\"" 
         $0 -n"Convert DISCARD" -odr -s"count.pl -i @.log -s\"WOOCA6\"" -d-1
EOF
    exit;
}

#
# Returns the date based on the request of either 'yyyymmdd' or '-n', where
# 'n' is the number of days in the past that the required report was run.
# param:  string of ANSI date to '-n' format.
# return: requested date.
#
sub getDate($)
{
	my $d = shift;
	if ($d eq "")
	{
		my $date = `transdate -d-0`;
		chomp($date);
		print "     -$date-\n" if ($opt{'D'});
		return $date;
	}
	elsif ($d =~ m/\d{8}/)
	{
		print "     -$d-\n" if ($opt{'D'});
		return $d;
	}
	elsif (substr($d, 0, 1) eq "-") # date from some 'N' days ago.
	{
		my $numDays = substr($d, 1);
		my $date = `transdate -d-$numDays`;
		chomp($date);
		print "     -$date- -$numDays-\n" if ($opt{'D'});
		return $date;
	}
	print STDERR "Invalid date specified.\n";
	return "";
}

# use this next line for production.
my $listDir            = `getpathname rptprint`;
chomp($listDir);
my $printList          = qq{$listDir/printlist};
my $date               = `transdate -d+0`;       # current date preseed.
chomp($date);
my @reportList;                                  # list of reports we want results from.
my $options;                                     # Hash ref to the users switches for report output (all num switches)
my $externSymbol       = qq{%};                   # symbol that this is an external report not found in printlist.

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'Dd:i:n:o:s:x2:3:4:5:7:8:9:';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ($opt{'x'} or (!$opt{'n'} and !$opt{'i'})); # Must have a name or a config that must have a name.
    $date = getDate($opt{'d'}) if ($opt{'d'});
	if ($opt{'i'})
	{
		open REPORT_LIST, "<$opt{'i'}" or die "Error: unable to open input report list: $!\n";
		# skip empty or lines that start with #
		while (<REPORT_LIST>)
		{
			if ($_ =~ m/^ / or $_ =~ m/^#/ or $_ eq "\n")
			{
				next;
			}
			push(@reportList, $_);
		}
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
	my $lineCount = 1;
	foreach my $reportListEntry (@reportList)
	{
		$options = {}; # new hash ref for options unique to each line.
		my @optionList = split('\|', $reportListEntry);
		if (@optionList < 3)
		{
			print STDERR "malformed input file $opt{'i'} on line $lineCount\n";
			exit 0;
		}
		$lineCount++;
		my $name   = $optionList[0];
		my $d      = $optionList[1];
		my $script = $optionList[2];
		# make sure these options don't get passed on to the search.
		shift(@optionList);
		shift(@optionList);
		shift(@optionList);
		$date = getDate($d);
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
		# Do we run this as a stand alone command or do we search print list?
		if ($name eq "")
		{
			print STDERR "*** error: ignoring un-named report request on line $lineCount***\n";
		}
		elsif ($name =~ m/^($externSymbol)/)
		{
			my $bareName = substr($name, length($externSymbol));
			searchExternally($bareName, $date, $options, $script);
		}
		else
		{
			searchPrintList($name, $date, $options, $script, @printListLines);
		}
	}
}
else # just one report requested by -n on the command line.
{
	if ($opt{'n'} =~ m/^($externSymbol)/)
	{
		my $bareName = substr($opt{'n'}, length($externSymbol));
		searchExternally($bareName, $date, $options, $opt{'s'});
	}
	else
	{
		searchPrintList($opt{'n'}, $date, $options, $opt{'s'}, @printListLines);
	}
}
1;

# Runs an external script based on a request for '$Reporting Script Name||script||'
# param:  name string name that will appear in output if -or is selected.
# param:  date ANSI date - the user can specify a date but that can't be varified by 
#         rptstat.pl since the optional included script is run now, but who knows
#         when the data it produces was created.
# param:  options string ignored.
# param:  script - string command to run to produce stats.
# return: 
#
sub searchExternally
{
	my ($name, $date, $options, $script) = @_;
	my $record = "----|$name|$date|UNKNOWN|UNKNOWN|$script|0||";
	my $itemsPrinted = getRptMetaData($opt{'o'}, $record);
	if ($script ne "")
	{
		# we can't just print what the script does becaue when no other option is picked
		# it can return a new line and nothing else which means it failed.
		my $runThis = qq{$script};
		my $sResults = `$runThis`;
		print $sResults;
		chomp($sResults);
		$itemsPrinted += 1 if ($sResults ne "");
	}
	if ($itemsPrinted > 0)
	{
		print "\n";
	}
}

#
# Perhaps no surprise that this runs the search based on the input parameters.
# param:  name - string name, or partial name, of the report.
# param:  date - string requested date of the report in ANSI 'yyyymmdd' format.
# param:  options - string list of switches and codes for status'.
# param:  printListLines - array of all the lines in the print list.
# param:  script - executable command line string.
# return: number of items successfully matched to the supplied options.
#
sub searchPrintList
{
	my ($name, $date, $options, $script, @printListLines) = @_;
	my $itemsPrinted = 0;
	my $cmdLine;
	# Find all the reports with the name, or partial name supplied.
	my $reportHash = getReportFile($name, $date, @printListLines);
	if (keys (%$reportHash) > 0)
	{
		for my $reportKey ( keys %$reportHash )
		{
			my $report = $reportKey.".log";
			$itemsPrinted += getRptMetaData($opt{'o'}, $reportHash->{ $reportKey });
			$itemsPrinted += getRptResults($report, $options);
			# now execute the script if there is one.
			if ($script ne "")
			{
				# we need to replace the @ for each report.
				$cmdLine = $script;
				# now a user can use the '@' symbol to indicate that the 
				# the name of the file is to be substituted. First we have
				# replace any '@' with the path and name of the report.
				print "\n$report==>and $reportKey\n" if ($opt{'D'});
				$cmdLine =~ s/@/$reportKey/g;
				print STDERR "running script: '$cmdLine'\n" if ($opt{'D'});
				# we can't just print what the script does becaue when no other option is picked
				# it can return a new line and nothing else which means it failed.
				my $runThis = qq{$cmdLine};
				my $sResults = `$runThis`;
				print $sResults;
				chomp($sResults);
				$itemsPrinted += 1 if ($sResults ne "");
			}
			if ($itemsPrinted > 0)
			{
				print "\n";
			}
		}
	}
	else # Print that the report is not available.
	{
		print STDERR "report '$name' from '$date' is not available.\n";
	}
	return $itemsPrinted;
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
	my $hashRef;
	# Search the print list for candidate reports.
	if (!defined($rptName) or $rptName eq "")
	{
		return "";
	}
	foreach my $printListLine (@printListLines)
	{
		# vszd|Convert DISCARD Items CSDCA3|201202080921|OK|ADMIN|cvtdiscard|0||
		my @printListEntry = split('\|', $printListLine);
		# field 5 (0 indexed) contains the last run date and 
		# if the time stamp the report ran matches the specified ascii date, and the name matches:
		if ($printListEntry[1] =~ m/($rptName)/ and substr($printListEntry[2], 0, 8) eq $date)
		{
			# get it from the rptprint directory/wwqk.log
			my $reportPath = qq{$listDir/$printListEntry[0]};
			$hashRef->{ $reportPath } = $printListLine;
		}
	}
	return $hashRef;
}

# This function prints out the requested metadata about the report.
# param: outParams - string of codes user would like to see output.
# param: printListRecord List: vszd|Convert DISCARD Items CSDCA3|201202080921|OK|ADMIN|cvtdiscard|0||
# return: number of switches set.
sub getRptMetaData
{
	my ($outParams, $printRecord) = @_;
	my @printListRecord = split('\|', $printRecord);
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
			# print ">>$line<<: $outParams{$code}, $switch\n";
			# You need to check this when using a config file since user's
			# can easily enter wrong codes and switches in the file.
			if (!defined($outParams{$code}) or !defined($switch))
			{
				print STDERR "Ignoring invalid switch or code (check -i file for errors or that the requested code is valid. See -x).\n";
				return 0;
			}
			if ($line =~ m/\$<($outParams{$code})> \$\(130($switch)\)/)
			{
				print trim(substr($line, 0, index($line, "<") -1))."|";
				$count++;
			}
		}
	}
	return $count;
}

#
# Trim function to remove whitespace from the start and end of the string.
# param:  string to trim.
# return: string without leading or trailing spaces.
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
