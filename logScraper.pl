#!/usr/bin/perl
# --------------------------------------------------------------------
# IPScraper_NGINX.pl
#
# $Id:  $
#
# Description:
# Script to tail a NGINX access log to identify IP addresses that are tryuing to hack the system and then 
# generate changes to the firewall to block the IP addresses
#
# NOTE: to ensure that the log scraper doesn't stall it is expected to be cancelled and restarted 
#       every 60 minutes
#
# Usage:
#   IPScraper_NGINX.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: $
#
# --------------------------------------------------------------------

use strict;

my $machine;            # machine name
my $machine_info;       # ** UNIX ONLY ** uname
my @mach_info;          # ** UNIX ONLY ** uname split by spaces
my $OS;                 # OS
my $scriptDir;          # directory where the script is running
my $tmp;

BEGIN {
  if ( $^O eq "MSWin32") {
    $machine = `hostname`;
    $OS = "Windows";
    $scriptDir = 'c:\udbdba\scrxipts';
    $tmp = rindex($0,'\\');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
  else {
    $machine = `uname -n`;
    $machine_info = `uname -a`;
    @mach_info = split(/\s+/,$machine_info);
    $OS = $mach_info[0] . " " . $mach_info[2];
    $scriptDir = "scripts";
    $tmp = rindex($0,'/');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
}

use lib "$scriptDir";

use commonFunctions qw(getOpt ltrim myDate trim $getOpt_optName $getOpt_optValue @myDate_ReturnDesc $cF_debugLevel);

my $debugLevel = 0;
my $ID = '$Id: $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 [-?hs] -f <file to be scanned> [-I] [-t <# days>] [-b <filename>]

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -f              : file to be tailed (if none entered then STDIN will be used)
       -t              : days an IP is to be blocked for (default: 90)
       -I              : immediate - issue the iptables commands immediately
       -b              : file containing historically blocked IPs


       \n ";
}

# Set default values for variables

my $silent = "No";
my $blockWindow = 90;
my $logFile = "";
my $blockedIPs = "blockedIPs.txt";
my $immediate = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

while ( getOpt(":?hsf:t:v:b:I") ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s"))  {
   $silent = "Yes";
 }
 elsif ($getOpt_optName eq "f" )  {
   if ( $silent ne "Yes") {
     print "file to be processed will be $getOpt_optValue\n";
   }
   $logFile = $getOpt_optValue;
 }
 elsif ($getOpt_optName eq "b" )  {
   if ( $silent ne "Yes") {
     print "Blocked IPs details will be helf in $getOpt_optValue\n";
   }
   $blockedIPs = $getOpt_optValue;
 }
 elsif ($getOpt_optName eq "I" )  {
   if ( $silent ne "Yes") {
     print "IPTABLES commands will be issued immediately\n";
   }
   $immediate = 1;
 }
 elsif ($getOpt_optName eq "t" )  {
   $blockWindow = "";
   ($blockWindow) = ($getOpt_optValue =~ /(\d*)/);
   if ($blockWindow eq "") {
      usage ("Value supplied for the blocking window parameter (-t) is not numeric");
      exit;
   }
   if ( $silent ne "Yes") {
     print "IP Addresses will be blocked for $blockWindow days\n";
   }
 }
 elsif ($getOpt_optName eq "v")  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "debug level now set to $debugLevel\n";
   }
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   usage ("Parameter $getOpt_optValue is invalid");
   exit;
 }
}

# ----------------------------------------------------
# -- End of Parameter Section
# ----------------------------------------------------

chomp $machine;
my @ShortDay = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
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
my @dateReturn = myDate("Date:$year$month$day");

# calculate the day of the start of the blocking window
my @dateLimit = myDate($dateReturn[5] - $blockWindow);
my $dateLim = "$dateLimit[2]$dateLimit[1]$dateLimit[0]";
print "Date limit set to $dateLim\n";

# initialize arrays

my %blockedIPs = ();
my %monthNums = (
     'Jan' =>'01',
     'Feb' =>'02',
     'Mar' =>'03',
     'Apr' =>'04',
     'May' =>'05',
     'Jun' =>'06',
     'Jul' =>'07',
     'Aug' =>'08',
     'Sep' =>'09',
     'Oct' =>'10',
     'Nov' =>'11',
     'Dev' =>'12'
     );

# Load up the current IP Adddresses that we know should be blocked

my $numberLoaded = 0;
my $numberAvail = 0;

if (! open(BLOCKEDIPS,"<$blockedIPs")) { die "Error: File containing blockedIPs is missing. Unable to open $blockedIPs\n"; }
else { # load up the blocked IPs
  while ( <BLOCKEDIPS> ) {
    chomp $_;
    $numberAvail++;
    # Skip lines starting with #! (Comments)
    my ($IP_date,$IP_address) = split(" ") ;
    if ( $IP_date >= $dateLim ) { # exclude IP addresses that were seen previous to the start of the date Limit
      $blockedIPs{$IP_address} = $IP_date; 
      $numberLoaded++;
    }
  }
  close BLOCKEDIPS;
}

print "$numberLoaded IP addreses loaded from a possible $numberAvail\n";

if ( $logFile ne "" ) {
  print "Opening $logFile for continuous tailing\n";
  if (! open (LOGPIPE,"tail -f $logFile | "))  {
    die "Can't open $logFile! \n$!\n";
  }
}
else {
  print "Reading logfile from STDIN\n";
  if (! open (LOGPIPE,"-"))  { # open STDIN if a file hasn't been declared
    die "Can't open STDIN! \n$!\n";
  }
}

# start processing the input file ...

my $inLines = 0;        # number of input lines processed
my @words;              # input string broken into components in this array
my $logTime ;
my $logRecordIn = '';
my $x1;

# clear down the chain and reload the known values .....

if ($immediate) { $x1 = `/usr/sbin/iptables -F XTIRPATE`; }  # clear down the xtirpate chain 
else {
  print STDERR "sudo /usr/sbin/iptables -F XTIRPATE\n";
}
foreach my $IP ( keys %blockedIPs ) {
  if ($immediate) { $x1 = `/usr/sbin/iptables -A XTIRPATE -s $IP -j DROP`; }  # add known problem IPs to the chain
  else {print STDERR "sudo /usr/sbin/iptables -A XTIRPATE -s $IP -j DROP\n"; }
}

# wait on new entries to add

while (<LOGPIPE>) {
  $inLines++;
  
  if ( $_ =~ /\.well/ ) { next; }
  if ( $_ =~ /10\.1\.1\.1/ ) { next; }
  if ( $_ =~ /192\.168\.1/ ) { next; }

  my ($tmpIP, $tmpDate, $HTMLReq, $HTMLResponse);

  if ( $_ =~ /forwarded for/ ) { # forwarded message
    ($tmpIP, $tmpDate, $HTMLReq, $HTMLResponse) = ( $_ =~ /([^ ]*) forwarded for .*\[([^\:]*)\:[^\]]*\] *"([^\"]*)" ([^ ]*) /);
  }
  else {
    ($tmpIP, $tmpDate, $HTMLReq, $HTMLResponse) = ( $_ =~ /([^ ]*) .*\[([^\:]*)\:[^\]]*\] "([^\"]*)" ([^ ]*) /);
  }
  if ( $HTMLResponse == 200 ) { # request was ok so let it go 
    print "Ret 200 ?????? $HTMLReq : $_\n";
    next; 
  }
  
  my ($xDay, $xMon, $xYear) = ( $tmpDate =~ /(..)\/(...)\/(....)/ ) ;
  $tmpDate = "$xYear$monthNums{$xMon}$xDay";
  
  if ( ! defined($blockedIPs{$tmpIP}) ) {
    print "Processing (new IP) >>>> [$tmpIP,$tmpDate,$HTMLReq, $HTMLResponse] >>>> $_\n";
    if ($immediate) { $x1 = `/usr/sbin/iptables -A XTIRPATE -s $tmpIP -j DROP`; }  # add new problem IPs to the chain
    else { print STDERR "sudo /usr/sbin/iptables -A XTIRPATE -s $tmpIP -j DROP\n"; }
    `echo "$tmpDate $tmpIP" >>$blockedIPs`;
    $blockedIPs{$tmpIP} = $tmpDate;
  }
  else {
    print "Ignored (already blocked)>>>> [$tmpIP,$tmpDate,$HTMLReq, $HTMLResponse] >>>> $_\n";
  }
  
  $logRecordIn = $_;
  chomp $logRecordIn;

  @words = split;
  
}


