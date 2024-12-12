#!/usr/bin/perl
# --------------------------------------------------------------------
# strChng.pl
#
# $Id: strChng.pl,v 1.10 2019/01/29 00:04:12 db2admin Exp db2admin $
#
# Description:
# Script to make string changes to multiple files
#
# If this file has windows CTRL characters then you can either use dos2unix or run
#  perl -p -e 's/\r$//' <strChng.pl >strChng.new
#
#
# Usage:
#          strChng.pl <from string> <to string> <list of files to change>
#   or     strChng.pl STRIPWINCR|ADDWINCR|HTML <list of files to change>
#
# $Name:  $
#
# ChangeLog:
# $Log: strChng.pl,v $
# Revision 1.10  2019/01/29 00:04:12  db2admin
# change the parameter names referenced in commonFunctions.pm
#
# Revision 1.9  2018/10/07 20:18:44  db2admin
# make the search on the case insensitive change also case insensitive
#
# Revision 1.8  2018/04/02 22:52:47  db2admin
# modify script to stop parsing parameters after the first file name encountered
#
# Revision 1.7  2017/01/29 12:14:50  db2admin
# add in LT and d options
#
# Revision 1.6  2016/11/28 00:16:42  db2admin
# A number of changes were made:
# 1. use strict
# 2. new switch to add <BR> string to end of each line
# 3. allow stream processing
#
# Revision 1.5  2015/10/02 00:18:55  db2admin
# add case insensitive search
#
# Revision 1.4  2014/05/25 22:34:10  db2admin
# correct the allocation of windows include directory
#
# Revision 1.3  2009/01/19 00:48:37  db2admin
# Correct spelling mistake in one of the messages
#
# Revision 1.2  2009/01/09 03:46:18  db2admin
# standardised parameters and improved output messages
#
# Revision 1.1  2008/09/25 22:36:42  db2admin
# Initial revision
#
# --------------------------------------------------------------------"

use strict;

my $ID = '$Id: strChng.pl,v 1.10 2019/01/29 00:04:12 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print STDERR "\n$_[0]\n\n";
    }
  }

  print STDERR "Usage: $0 -?hsc [-i] [-T] [-L] [[-f <from string>] [-t <to string>] | -d <string to delete>] <list of files to change>
             or
       $0 -?hs [-S|-A|-H] [-T] [-L]  <list of files to change>

       Version $Version Last Changed on $Changed (UTC)

       -h or -?         : This help message
       -s               : Silent mode
       -A or ADDWINCR   : Add Windows EOL characters to each line
       -S or STRIPWINCR : Remove Windows EOL characters from each line
       -H or HTML       : Insert <BR> prior to any CRLF characters found
       -T               : remove trailing spaces
       -d               : string to delete - if set the from to will be ignored
       -L               : remove leading spaces
       -f               : String to be replaced in the file (FROM)
       -t               : String to replace the found string in the file (TO)
       -c               : Only run in check mode - make no changes
       -i               : case insensitive

       Note that -S is similar to a command of perl -p -e 's/\\r\$//' <strChng.pl

     \n";
}

my $machine;     # machine script is running on
my $OS;          # OS
my $dirSep;      # directory separator for OS
my $scriptDir;   # directory script is running from
my $tmp;

if ( $^O eq "MSWin32") {
  $machine = `hostname`;
  $OS = "Windows";
  $dirSep = '\\';
  BEGIN {
    $scriptDir = 'c:\udbdba\scripts';
    my $tmp = rindex($0,"\\");
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
  use lib "$scriptDir";
}
else {
  $machine = `uname -n`;
  my $machine_info = `uname -a`;
  my @mach_info = split(/\s+/,$machine_info);
  $OS = $mach_info[0] . " " . $mach_info[2];
  $dirSep = '/';
  BEGIN {
    $scriptDir = "c:\udbdba\scripts";
    my $tmp = rindex($0,'/');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
  use lib "$scriptDir";
}

use commonFunctions qw(getOpt myDate trim $getOpt_optName $getOpt_optValue @myDate_ReturnDesc $cF_debugLevel);

# Set default values for variables

my $parmsFinished = 0; # flag to indicate when the fixed parameters have stopped
my $silent = "No";
my $action = "";
my $from = "";
my $to = "";
my $files = "";
my $check = "No";
my $caseInsensitive = 0;
my $html = 0;
my $truncLeading = 0;
my $truncTrailing = 0;
my $deleteString = 0;

sub addFileToList {
  
  my $file = shift;

  if ($files eq "" ) {
    $files = $file;
  }
  else {
    $files = "$files|$file";
  }
}

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

my $getOpt_prm = 0;

$getOpt_optName = "";
$getOpt_optValue = "";

while ( getOpt(":?hcsiLTd:f:t:ASH|^STRIPWINCR|^ADDWINCR|^HTML") ) {
 if ( $parmsFinished) { # no more fixed parameters
   if ( ($getOpt_optName eq ':' ) || ($getOpt_optName eq '*' ) ) { # parameter name held in the value field
     addFileToList($getOpt_optValue); 
   }
   else {
     addFileToList($getOpt_optName);
     if ( $getOpt_optValue ne '' ) { 
       addFileToList($getOpt_optValue); 
     }
   } 
 } 
 elsif (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s") )  {
   $silent = "Yes";
 }
 elsif (($getOpt_optName eq "c"))  {
   if ( $silent ne "Yes") {
     print "Check only run - NO updates will be made\n";
   }
   $check = "Yes";
 }
 elsif (($getOpt_optName eq "i"))  {
   if ( $silent ne "Yes") {
     print "String search wil be case insensitive\n";
   }
   $caseInsensitive = 1;
 }
 elsif (($getOpt_optName eq "L"))  {
   if ( $silent ne "Yes") {
     print "File will have all leading spaces removed\n";
   }
   $truncLeading = 1;
 }
 elsif (($getOpt_optName eq "T"))  {
   if ( $silent ne "Yes") {
     print "File will have all trailing spaces removed\n";
   }
   $truncTrailing = 1;
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "String $getOpt_optValue will be deleted\n";
   }
   $deleteString = 1;
   $from = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print "String to search for is $getOpt_optValue\n";
   }
   if ( $deleteString) {
     print "Delete option already selected so from/to being ignored\n"
   }
   else {
     $from = $getOpt_optValue;
   }
 }
 elsif (($getOpt_optName eq "t"))  {
   if ( $silent ne "Yes") {
     print "String to use to replace the found string is $getOpt_optValue\n";
   }
   if ( $deleteString) {
     print "Delete option already selected so from/to being ignored\n"
   }
   else {
     $to = $getOpt_optValue;
   }
 }
 elsif (($getOpt_optName eq "H") || ($getOpt_optName eq "HTML"))  {
   if ( $silent ne "Yes") {
     print "HTML characters will be added as necessary\n";
   }
   $action = "HTML";
   $from = "\cJ";
   $to = "<BR>\cJ";
 }
 elsif (($getOpt_optName eq "A") || ($getOpt_optName eq "ADDWINCR"))  {
   if ( $silent ne "Yes") {
     print "Windows EOL characters will be added to the file\n";
   }
   $action = "ADDWINCR";
   $from = "\cJ";
   $to = "\cM\cJ";
 }
 elsif (($getOpt_optName eq "S") || ($getOpt_optName eq "STRIPWINCR"))  {
   if ( $silent ne "Yes") {
     print "Windows EOL characters will be removed from the file\n";
   }
   $action = "STRIPWINCR";
   $from = "\cM";
   $to = "";
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $from eq "" ) {
     $from = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print STDERR "String to search for is $getOpt_optValue\n";
     }
   }
   elsif ( ($to eq "" ) && ($from ne "\cM")  && ($deleteString == 0) ) {
     $to = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print STDERR "String to use to replace the found string is $getOpt_optValue\n";
     }
   }
   else {
     $parmsFinished = 1;
     addFileToList($getOpt_optValue);
   }
 }
}

# ----------------------------------------------------
# -- End of Parameter Section
# ----------------------------------------------------

chomp $machine;
my @ShortDay = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
my @monthName = ('January','February','March','April','May','June','July','August','September','October','November','December');
my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
my $year = 1900 + $yearOffset;
$month = $month + 1;
$hour = substr("0" . $hour, length($hour)-1,2);
$minute = substr("0" . $minute, length($minute)-1,2);
$second = substr("0" . $second, length($second)-1,2);
$month = substr("0" . $month, length($month)-1,2);
my $day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
my $Now = "$year.$month.$day $hour:$minute:$second";
my $NowDayName = "$year/$month/$day ($ShortDay[$dayOfWeek])";
my $NowDay = "$year$month$day";
my $NowMonth = "$day $monthName[$month-1], $year at $hour:$minute";
my $currentDay = '';
my $YYYYMMDD = "$year$month$day";
my $NowTS = "$year-$month-$day-$hour.$minute.$second";

if ( $from eq "" ) {
  usage 'Minimally, a from string MUST be specified';
  exit;
}

my $changed = 0;
my $found = 0;
my $nfiles = 0;

if ( $files eq '' ) { $files = "STDIN" ; }
my @filelist = split(/\|/,$files);

for (my $i=0; $i <= $#filelist; $i++) {

  if ( $files eq 'STDIN' ) { #read from STDIN
    if (! open(INPUT,"-") ) {
      print STDERR "Can't open STDIN for input\n";
      next;
    }
  }
  else {
    if ( ! open(INPUT,"<$filelist[$i]") ) {
      print STDERR "Can't open $filelist[$i] for input\n";
      next;
    }
  }
  $nfiles++;
  undef $/;
  # Read input file as one long record.
  my $prtdata=<INPUT>;
  close INPUT;
  if ( $truncLeading ) {
    $prtdata =~ s/^\s*//gm;
    $prtdata =~ s/\n\s*/\n/gm;
    $prtdata =~ s/\r\s*/\r/gm;
  }
  if ( $truncTrailing ) {
    $prtdata =~ s/\s*$//gm;
    $prtdata =~ s/\s*\n/\n/gm;
    $prtdata =~ s/\s*\r/\r/gm;
  }
  $to =~ s/##EOL##/\n/gm;
  if ( $caseInsensitive ) {
    if ($prtdata =~ /$from/i) {
      print STDOUT "File $filelist[$i] needs to be changed ....\n";
      $found++;
      if ( $check ne "Yes" ) {
        if ( $deleteString ) { # remove the string
          $prtdata =~ s/$from//gm;
        }
        else  {
          $prtdata =~ s/$from/$to/igm;
        }
        if ( $files eq 'STDIN' ) {
          if (! open(OUTPUT,">-") ) { # if STDIN in then STDOUT out
            print STDERR "Can't open STDOUT for output\n";
            next;
          }
        }
        else {
          if (! open(OUTPUT,">$filelist[$i]") ) {
            print STDERR "Can't open file $filelist[$i] for output\n";
            next;
          }
        }
        print OUTPUT "$prtdata";
        $changed++;
      }
    }
  }
  else { # case sensitive
    if ($prtdata =~ /$from/) {
      print STDOUT "File $filelist[$i] needs to be changed ....\n";
      $found++;
      if ( $check ne "Yes" ) {
        if ( $deleteString ) { # remove the string
          $prtdata =~ s/$from//gm;
        }
        else {
          $prtdata =~ s/$from/$to/gm;
        }
        if ( $files eq 'STDIN' ) {
          if (! open(OUTPUT,">-") ) { # if STDIN in then STDOUT out
            print STDERR "Can't open STDOUT for output\n";
            next;
          }
        }
        else {
          if (! open(OUTPUT,">$filelist[$i]") ) {
            print STDERR "Can't open file $filelist[$i] for output\n";
            next;
          }
        }

        print OUTPUT "$prtdata";
        $changed++;
      }
    }
  }
  $/ = "\n";
}

if ( $silent ne "Yes" ) {
  print STDOUT "\nFiles processed:$nfiles \n";
  print STDOUT "Files containing the search string: $found\n";
  print STDOUT "Files changed  :$changed \n";
  print STDOUT "Ending \n";
}

exit(0);


