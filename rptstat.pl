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

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
$ENV{'PATH'} = ":/s/sirsi/Unicorn/Bincustom:/s/sirsi/Unicorn/Bin:/s/sirsi/Unicorn/Search/Bin:/export/home/oracle/product/10.2.0/bin:/usr/bin:/etc:/usr/ucb:/usr/sbin";
$ENV{'UPATH'} = "/s/sirsi/Unicorn/Config/upath";
###############################################

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

usage: $0 [-x] [-d ascii_date] [-2345789[aAbBcDghHiIMmopstTu]] [-c file] [-D]
	
This script takes the name, or partial name of a report finds it by date
(default today) and outputs the results to STDOUT. The 3rd field in the -c file
can include a script to run who's output will be printed first. If the script requires
the current report as an argument, then use the \@ character as a placeholder for the
name of the report being reported on.
Example: './count.pl -c \@.prn -s "\.email"' will run the script with \@ symbol expanded to:
'./count.pl -c /s/sirsi/Unicorn/Rptprint/xast.prn -s "\.email"'.

 -d yyyymmdd : checks the reports for a specific day (ANSI date format)
 -c file     : input config file of stats you want to collect. Should be formated as:
               name (required)|date (required but can be blank)|script and params (required but can be blank|code1|code2|...|codeN|
             Example: 
               Generalized bills|||5u|
               which would report the number of user's selected from today's report.
             Example:
               Holds Notices|20120614|./script.pl -e|9N|
               which would print the output from script.pl -e as the results in addition
               to the codes you specify. You may get unpredictable results depending on the executable's behaviour.
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

example: echo "Generalized Bill" | $0 -d 20120324 -5u -s"count.pl -c @.log -s\"\.email\"" 
         cat reports.lst | $0 -odr -s"count.pl -c @.log -s\"WOOCA6\"" -d-1
		 $0 -c weekday.stats -odr
EOF
    exit;
}

#
# Returns the date based on the request of either 'yyyymmdd' or '-n', where
# 'n' is the number of days in the past that the required report was run.
# Side effect to set the -d flag. Will exit if invalid date specified.
# param:  string of ANSI date to '-n' format.
# return:
#
sub setDate($)
{
	my $d = shift;
	if (!defined($d) or $d eq "") 
	{
		my $date = `transdate -d-0`;
		chomp($date);
		print "     -$date-\n" if ($opt{'D'});
		$opt{'d'} = $date;
	}
	elsif ($d =~ m/\d{8}/)
	{
		print "     -$d-\n" if ($opt{'D'});
		$opt{'d'} = $d;
	}
	elsif (substr($d, 0, 1) eq "-") # date from some 'N' days ago.
	{
		my $numDays = substr($d, 1);
		my $date = `transdate -d-$numDays`;
		chomp($date);
		print "     -$date- -$numDays-\n" if ($opt{'D'});
		$opt{'d'} = $date;
	}
	else
	{
		print STDERR "***Invalid date specified.***\n";
		exit(0);
	}
}

# use this next line for production.
my $listDir            = `getpathname rptprint`;
chomp($listDir);
my $printList          = qq{$listDir/printlist};
my @requestedReports;                                  # list of reports we want results from.
my @printListLines;                              # list of printed reports from printlist.
my $options;                                     # Hash ref to the users switches for report output (all num switches)
my $externSymbol       = qq{%};                  # symbol that this is an external report not found in printlist.

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'Dd:c:o:s:x2:3:4:5:7:8:9:';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ($opt{'x'}); # Must have a name or a config that must have a name.
    if ($opt{'d'})
	{
		setDate($opt{'d'});                                # Validate date.
	}
	else
	{
		setDate("");
	}
	if ($opt{'c'})
	{
		open(STDIN, "<$opt{'c'}") or die "Error: unable to open input report list: $!\n";
	}
	# Now read in the names of the reports you want.
	my @array = <STDIN>;
	close(STDIN);
	foreach my $report (@array)
	{
		# skip blank lines and comments.
		next if ($report =~ m/^ / or $report =~ m/^#/ or $report eq "\n");
		chomp($report);
		push(@requestedReports, $report);
	}
}

# Validates report names. Must not be empty but can have special symbol.
# Side effect: sets $opt{'n'}.
# param:  report name string - name or partial name of the report.
# return:
sub setName($)
{
	my $name = shift;
	if ($name ne "")
	{
		$opt{'n'} = $name;
	}
	else
	{
		print STDERR "***error: un-named report request.***\n";
		exit(0);
	}
}

# Sets the script name. So far not implemented.
# Side effects: sets $opt{'s'}.
# param:  name of the script to run. Passing "" will erase any value stored in $opt{'s'}.
# return:
sub setScript
{
	$opt{'s'} = shift;
}


init();

open(PRINTLIST, $printList) || die "Failed to open $printList: $!\n";
@printListLines = <PRINTLIST>;
close(PRINTLIST);

foreach my $reportListEntry (@requestedReports)
{
	$options = {}; # new hash ref for options unique to each line report.
	my @optionList = split('\|', $reportListEntry);
	if (@optionList < 3)
	{
		# This is a request from the command line other than with switches.
		setName($reportListEntry);
		# fill the options from the command line. 
		$options = getCmdLineOptionsForResults();
	}
	else
	{
		setName($optionList[0]);
		setDate($optionList[1]);
		setScript($optionList[2]);
		# make sure these options don't get passed on to the search.
		shift(@optionList);
		shift(@optionList);
		shift(@optionList);
		# fill the options from the configuration file entry.
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
	}
	searchPrintList($opt{'n'}, $opt{'d'}, $options, $opt{'s'}, @printListLines);
}
1;

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
			if (defined($script) and $script ne "")
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
	# there is no report. Hmm is it a special request?
	elsif ($name =~ m/^($externSymbol)/)
	{
		my $n = substr($name, length($externSymbol));
		$cmdLine = "";
		# Stop warnings about script strings that are empty.
		if (!defined($script) or $script eq "")
		{
			$itemsPrinted = getRptMetaData($opt{'o'}, "----|$n|$date|UNKNOWN|UNKNOWN|none|0||");
		}
		else
		{
			$itemsPrinted = getRptMetaData($opt{'o'}, "----|$n|$date|UNKNOWN|UNKNOWN|$script|0||");
			# we can't just print what the script does becaue when no other option is picked
			# it can return a new line and nothing else which means it failed.
			$cmdLine = qq{$script};
			my $sResults = `$cmdLine`;
			print $sResults;
			chomp($sResults);
			$itemsPrinted += 1 if ($sResults ne "");
		}
		print "\n"; # run or not we print a new line.
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
			case 'e' { getEmailedCount($printListRecord[0], 1); $count++ }
			case 'E' { getEmailedCount($printListRecord[0], 0); $count++ }
			else     { print "" }
		}
	}
	return $count;
}

# Searches for email activity in the prn file.
# param:  code string - file code.
# param:  isEmail integer - 0 means false anything else is true.
# return:
sub getEmailedCount
{
	my ($code, $isEmail) = @_;
	# special reports scripts don't have codes so you wont find them.
	return qq{0|} if ($code eq "----");
	my $reportPrintFile = qq{$listDir/$code.prn};
	my $reportLogFile   = qq{$listDir/$code.log};
	my $emailCount = 0;
	my $totalCount = 0;
	# Total users in the log file,
	open(RPTLOG, "<$reportLogFile") or die "*** error: $!\n";
	while (<RPTLOG>)
	{
		if ($_ =~ m/\$<user> \$\(130[59]\)/)
		{
			$totalCount = trim(substr($_, 0, index($_, "<") -1));
		}
	}
	close(RPTLOG);
	# Total emails in prn file, so we have to search that too.
	open(RPTPRINT, "<$reportPrintFile") or die "Error opening $reportPrintFile: $!\n";
	while (<RPTPRINT>)
	{
		if ($_ =~ m/\.email/)
		{
			$emailCount++;
		}
	}
	close(RPTPRINT);
	if ($isEmail)
	{
		print $emailCount."|";
	}
	elsif ($totalCount > 0)
	{
		my $difference = $totalCount - $emailCount;
		print $difference."|";
	}
	else
	{
		print qq{0|};
	}
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
				print STDERR "Ignoring invalid switch or code (check -c file for errors or that the requested code is valid. See -x).\n";
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
