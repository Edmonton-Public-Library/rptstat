#!/s/sirsi/Unicorn/Bin/perl -w
###########################################################################################
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
# Rev:     0.5 - develop
#          0.5.1 - cleaned up environment variables added warning message
#          to remind user when scripts are user defined.
#          0.5.2 - added report renaming. You can change a report's name
#          to anything so that you can store stats in a database by report ID
#          or you can specify that for two identically named reports, one
#          is for email and one is for snail mail. Added db date time return option.
#          0.5.3 - change -eE to -Oe and -0E for consistent report handling
#          and simplier config files.
#          0.5.4 - added -d* to show results of all available named reports result display.
#          Fixed '@' bug that didn't include full path to file on substitution match.
############################################################################################

use strict;
use warnings;
use vars qw/ %opt /;
use Getopt::Std;
use Switch;
my $VERSION = "0.5.4";

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
$ENV{'PATH'} = ":/s/sirsi/Unicorn/Bincustom:/s/sirsi/Unicorn/Bin:/s/sirsi/Unicorn/Search/Bin";
$ENV{'UPATH'} = "/s/sirsi/Unicorn/Config/upath";
###############################################

# Id| Report name                   | Run date |Status|Owner|Script|
# vtfs|Generalized Bill Notices Weekday|201202090552|OK|ADMIN|bill|0||
# 0     record emails from prn file.
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

	usage: $0 [-xwv] [-d [-n|*|ascii_date]] [-23457890[aAbBcDEeghHiIMmopstTu]] [-odDeErsonc]
	
Version: $VERSION.
This script takes the name, or partial name of a report finds it by date
(default today) and outputs the results to STDOUT. This script can report many metrics 
about a report as well as the salient results of the report. 

$0 includes can run an external script to collect stats from outside Symphony's normal
reporting pipeline. An example would be to collecting stats directly from API calls.
Be careful to test all scripts you are run before implementing them in a production environment.

$0 can also read a special configuration file as input. This file contains 3 pipe delimited
fields as a minimum, but no maximum number of fields. The first field is the name of the
desired report, the date the report ran, blank if from today, and a script to run which
may also be blank. Any additional fields are considered results to be searched for and 
printed if they exist. Examples would be -5u to print out the number of 'users' associated 
with the report code of 1305. 

More on scripting: The script in the 3rd field in the -c file requires the current report
as an argument, then use the \@ character is used as a placeholder for the name of the
report being reported on.

Example: 'count.pl -c \@.prn -s "\.email"' will run the script with \@ symbol expanded to:
'count.pl -c /s/sirsi/Unicorn/Rptprint/xast.prn -s "\.email"'.

Dates are entered using four formats: ANSI short date, 'yyyymmdd', relative date: '-n' where
'n' is the number of days ago the report ran, all dates: '*' report all named reports and 
blank: '', or the absence of a date which report for the current day.

If a report does not exist $0 will print nothing unless -w is selected, which will print
a warning message to STDERR.
Example: 
   bash\$ echo "Non-existant report" | $0 -oDr
   bash\$ 
   bash\$ echo "Non-existant report" | $0 -oDr -w
   * warning: report 'Non-existant report' from '20120717' is not available. *
   bash\$ 

 -d yyyymmdd : checks the reports for a specific day (ANSI date format)
 -d -n       : report from 'n' days ago.
 -d *        : all named reports currently available.
 -c file     : input config file of stats you want to collect. Should be formated as:
               name (required)|date (required but can be blank)|script and params (required but can be blank|code1|code2|...|codeN|
             Example: 
               Generalized bills|||5u|
               which would report the number of user's selected from today's report.
               Generalized bills ->Generalized bills - snail mail|||5u|
               which would report the same as above but change the name to 'Generalized bills - snail mail'
             Example:
               Holds Notices|20120614|./script.pl -e|9N|
               which would print the output from script.pl -e as the results in addition
               to the codes you specify. You may get unpredictable results depending on the executable's behaviour.
 -o          : d - date ascii
               D - date and time ascii
               e - emailed count
               E - mailed count
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
 -0 <code>   : records mailed. Reported values appear before any other switch <code> selection. For example
               echo Bill | $0 -5u -0e produces Generalized Bill Notices - Weekday|512|481|
               echo Bill | $0 -0e -5u produces Generalized Bill Notices - Weekday|512|481|
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
               e - email prints out before any other switch code.
               E - mail (printed notice) prints out before any other switch code.
 -s script   : script that you want to run.
 -t          : use MySQL timestamp time convention for output "yyyy-mm-dd hh:mm:ss".
 -v          : version (currently $VERSION).
 -w          : write warnings to STDERR.
 -x          : this (help) message

example: echo "Generalized Bill" | $0 -d 20120324 -5u -s"count.pl -c @.prn -s'.email'" -w
         cat reports.lst | $0 -odr -s"count.pl -c @.log -s'WOOCA6'" -d-1
         echo "Overdue Notices->Mailed Overdue Notices" | $0 -odr -5u -0E
         $0 -c weekday.stats -odr
		 
EOF
    exit;
}

# Returns a timestamp for the log file only. The Database uses the default
# time of writing the record for its timestamp in SQL. That was done to avoid
# the snarl of differences between MySQL and Perl timestamp details.
# Param:  ANSI time like yyyymmddhhmm
# Return: string of the current date and time as: 'yyyy-mm-dd hh:mm:ss'
sub getTimeAsMySQLTimeStamp($)
{
	my $ansiTime = shift;
	my @date     = split('', $ansiTime);
	my $year     = join('',@date[0..3]);
	my $month    = join('',@date[4..5]);
	my $day      = join('',@date[6..7]);
	# some reports don't come with hour and minute resolution.
	my $hour     = "00";
	my $minute   = "00";
	my $second   = "00";
	if (@date > 8)
	{
		$hour  = join('',@date[8..9]);
		$minute= join('',@date[10..11]);
	}
	return "$year-$month-$day $hour:$minute:$second";
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
	elsif (substr($d, 0, 1) eq "*") # all recorded named reports.
	{
		my $date = "9999";
		print "     -$date- -any time-\n" if ($opt{'D'});
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
my @requestedReports;                            # list of reports we want results from.
my @printListLines;                              # list of printed reports from printlist.
my $options;                                     # Hash ref to the users switches for report output (all num switches)
my $externSymbol       = qq{%};                  # symbol that this is an external report not found in printlist.

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'd:c:o:s:tvwx2:3:4:5:7:8:9:0:'; # *** -p is reserved for pseudonym don't use it as a cmd line option! ***
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ($opt{'x'}); # Must have a name or a config that must have a name.
	if ($opt{'v'})
	{
		print "$0 version: $VERSION\n";
		exit;
	}
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
# If the user specifies '->' the string after the '->' is used as the 
# name for the report on output.
# Side effect: sets $opt{'n'}, set $opt{'p'} which is not a valid command line switch.
# param:  report name string - name or partial name of the report.
# return:
sub setName($)
{
	my $name = shift;
	my @pseudonym = split("->", $name);
	if (defined($pseudonym[1]))
	{
		$opt{'p'} = $pseudonym[1];
	}
	# $pseudonym[0] will always contain the queryable report name even if user
	# didn't specify a pseudoynm.
	if ($pseudonym[0] ne "")
	{
		$opt{'n'} = $pseudonym[0];
	}
	else # happens if user enters "" or "->some other name"; lookup can't be empty.
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

open(PRINTLIST, $printList) || die "***error: failed to open $printList: $! ***\n";
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
			# my $report = $reportKey.".log";
			$itemsPrinted += getRptMetaData($opt{'o'}, $reportHash->{ $reportKey });
			$itemsPrinted += getRptResults($reportKey, $name, $options);
			# now execute the script if there is one.
			if (defined($script) and $script ne "")
			{
				# we need to replace the @ for each report.
				$cmdLine = $script;
				# now a user can use the '@' symbol to indicate that the 
				# the name of the file is to be substituted. First we have
				# replace any '@' with the path and name of the report.
				print "\nreport==>$reportKey\n" if ($opt{'D'});
				my $reportPath = qq{$listDir/$reportKey};
				$cmdLine =~ s/@/$reportPath/g;
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
		my $message = "";
		$message = "USER_DEFINED_SCRIPT: " if ($opt{'w'});
		if (!defined($script) or $script eq "")
		{
			$itemsPrinted = getRptMetaData($opt{'o'}, "----|".$message."$n|$date|UNKNOWN|UNKNOWN|none|0||");
		}
		else
		{
			$itemsPrinted = getRptMetaData($opt{'o'}, "----|".$message."$n|$date|UNKNOWN|UNKNOWN|$script|0||");
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
		if ($date eq "9999")
		{
			print STDERR "* warning: no record of report '$name' found. *\n" if ($opt{'w'});
		}
		else
		{
			print STDERR "* warning: report '$name' from '$date' is not available. *\n" if ($opt{'w'});
		}
	}
	return $itemsPrinted;
}

# Gets the options for the type of results the user wants to display from the report.
# param:  
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
# param:  printListLines List - list of all the printed reports in the printlist.
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
		if ($date eq "9999" or substr($printListEntry[2], 0, 8) eq $date)
		{
			if ($printListEntry[1] =~ m/($rptName)/ )
			{
				# get it from the rptprint directory/wwqk.log
				my $reportPath = qq{$printListEntry[0]};
				$hashRef->{ $reportPath } = $printListLine;
			}
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
			# e - emailed patrons
			# E - paper printed notice count
			# vszd|Convert DISCARD Items CSDCA3|201202080921|OK|ADMIN|cvtdiscard|0||
			case 'D' { 
				if ($opt{'t'})
				{
					print getTimeAsMySQLTimeStamp($printListRecord[2])."|";
				}
				else
				{
					print "$printListRecord[2]|"; 
				}
				$count++
			}
			case 'd' { 
				if ($opt{'t'})
				{
					print getTimeAsMySQLTimeStamp( substr($printListRecord[2], 0, 8) )."|";
				}
				else
				{
					print substr($printListRecord[2], 0, 8)."|"; 
				}
				$count++;
			}
			case 's' { print "$printListRecord[3]|"; $count++ }
			case 'o' { print "$printListRecord[4]|"; $count++ }
			case 'n' { print "$printListRecord[5]|"; $count++ }
			case 'c' { print "$printListRecord[0]|"; $count++ }
			case 'e' { getEmailedCount($printListRecord[0], $printListRecord[1], 1); $count++ }
			case 'E' { getEmailedCount($printListRecord[0], $printListRecord[1], 0); $count++ }
			case 'r' { if ($opt{'p'})
						{	
							print "$opt{'p'}|"; # prints the pseudonym instead of real name.
						}
						else
						{
							print "$printListRecord[1]|"; 
						}
						$count++;
					}
			else     { print "" }
		}
	}
	return $count;
}

# Searches for email activity in the prn file.
# param:  code string - file code.
# param:  name string - name of the report for reporting errors.
# param:  isEmail integer - 0 (false) means mail or paper, anything else means emailed patron count.
# return:
sub getEmailedCount
{
	my ($code, $name, $isEmail) = @_;
	# special reports scripts don't have codes so you wont find them.
	return qq{0|} if ($code eq "----");
	my $reportPrintFile = qq{$listDir/$code.prn};
	my $reportLogFile   = qq{$listDir/$code.log};
	my $emailCount = 0;
	my $totalCount = 0;
	# Total users in the log file,
	open(RPTLOG, "<$reportLogFile") or die "*** error while processing '$reportLogFile': $! ***\n";
	while (<RPTLOG>)
	{
		if ($_ =~ m/\$<user> \$\(130[59]\)/)
		{
			$totalCount = trim(substr($_, 0, index($_, "<") -1));
		}
	}
	close(RPTLOG);
	# Total emails in prn file, so we have to search that too, but not all reports are notice reports.
	if (not -e $reportPrintFile)
	{
		print STDERR "* warning: '$name' is not a notice report. *\n" if ($opt{'w'});
		print qq{0|};
		return;
	}
	open(RPTPRINT, "<$reportPrintFile") or die "*** error while processing '$reportPrintFile': $!\\n";
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
# param:  report - string code of the name of the file we are getting results from.
# param:  options - hash reference of requested switches and their codes.
# param:  name - string name of report. Passed to the function that counts emails.
# return: 
sub getRptResults
{
	my ($reportCode, $name, $options) = @_;
	my $reportFile = qq{$listDir/$reportCode.log};
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
		'e'=>"emailed", #not required handled by a separate check operation.
		'E'=>"printed", #not required handled by a separate check operation.
	);
	# print out the requested email counts first.
	if ( $options->{'0'} and $options->{'0'} eq "e" )
	{ 
		$count++ if (getEmailedCount($reportCode, $name, 1));
	} # emailed patrons.
	if ( $options->{'0'} and $options->{'0'} eq "E" )
	{ 
		$count++ if (getEmailedCount($reportCode, $name, 0));
	} # mailed patrons.
	# do the rest of the options (if any)
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
				print STDERR "*** error: '$switch' or '$code' is invalid (check config file for errors or that the requested code is valid. See -x). ***\n";
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
