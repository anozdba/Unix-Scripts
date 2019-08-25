#!/bin/bash -f
# --------------------------------------------------------------------
# watch.ksh
#
# $Id: watch.ksh,v 1.10 2018/02/20 00:36:19 db2admin Exp db2admin $
#
# Description:
# Script to run a specified command a number of times
#
# This script is really an expansion of
#      while true; do <command>; sleep 120 ; done
#
# Usage:
#   watch.ksh -n iterations <command to run>
#
# $Name:  $
#
# ChangeLog:
# $Log: watch.ksh,v $
# Revision 1.10  2018/02/20 00:36:19  db2admin
# correct bug preventing the use of the -g parameter
# add information display for -g and -G parameters
#
# Revision 1.9  2017/08/03 00:57:26  db2admin
# 1. Add in -x option to not run setup scripts
# 2. quote the egrep strings to allow for spaces
#
# Revision 1.8  2017/04/22 05:11:25  db2admin
# add in option to write command output to file
#
# Revision 1.7  2017/01/26 23:26:34  db2admin
# Various changes
# 1. Add in g/G options to grep obtained output
# 2. q option to clear screen between displays (not working)
# 3. moved command execution to subroutine to simplify code
#
# Revision 1.6  2017/01/23 20:39:07  db2admin
# add in -m option
#
# Revision 1.5  2017/01/23 04:39:25  db2admin
# add in ##DIR## variable to be substituted
#
# Revision 1.4  2017/01/23 00:16:09  db2admin
# 1. Added in -d option to monitor a directory
# 2. Added in option to optionally break when change observed
#
# Revision 1.3  2017/01/22 23:48:08  db2admin
# implemented break on change/no change functionality
#
# Revision 1.2  2017/01/22 22:08:00  db2admin
# add in more comments
# correct format error in if statement
#
# Revision 1.1  2017/01/22 21:18:28  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

#exec 3>&1 4>&2
#exec >logs/watch_$$.log 2>&1

echo `date` Starting $0

export dte=`date '+%Y-%m-%d'`

# send email

sendEmail () {
  (
    echo "To:$email"
    echo 'From:do-not-reply@KAGJCM.com.au'
    echo 'Subject:' $dte': '"$mach" $subject

    echo "MIME-Version: 1.0"
    echo 'Content-Type: multipart/mixed; boundary="-q1w2e3r4t5"'

    echo '---q1w2e3r4t5'
    echo 'Content-type: text/html'
    echo '<html>'
    echo '<head><title>' $mach $subject '</title></head>'
    echo '<body style="font-family:arial">'

    echo " The details in both outputs from command: <BR>"
    echo "$displayCMD <BR>"
    echo "<BR>"
    echo "Prev output ($HOLDTIME):<BR>"
    echo "$HOLDRES" | sed 's/$/<br>/'
    if [[ "$directory" == '' ]] ; then    # show command output
      echo "<BR>Last output ($RESTIME):<BR>"
      echo "$RES" | sed 's/$/<br>/'
    else # show directory listing output
      echo "<BR>Last output ($DIRRESTIME):<BR>"
      echo "$DIRRES" | sed 's/$/<br>/'
    fi
    echo "<BR><BR>"

  ) | /usr/lib/sendmail $email

}

executeCommand () {
  # construct and execute the command
  if [[ "$grepIncl" == ""  && "$grepExcl" == "" ]]; then
    RES=$($command)
  elif [[ "$grepIncl" != ""  && "$grepExcl" == "" ]]; then # only grep include
    RES=$( $command | egrep "$grepIncl" )
  elif [[ "$grepIncl" == ""  && "$grepExcl" != "" ]]; then # only grep exclude
    RES=$( $command | egrep -v "$grepExcl" )
  else # both include and exclude
    RES=$( $command | egrep "$grepIncl" | egrep -v "$grepExcl" )
  fi

  RESTIME=`date`
}

executeDirCommand () {
  if [[ $grepIncl == ""  && $grepExcl == "" ]]; then
    DIRRES=$(ls -al $directory)
  elif [[ $grepIncl != ""  && $grepExcl == "" ]]; then # only grep include
    DIRRES=$( ls -al $directory | egrep $grepIncl )
  elif [[ $grepIncl == ""  && $grepExcl != "" ]]; then # only grep exclude
    DIRRES=$( ls -al $directory | egrep -v $grepExcl )
  else # both include and exclude
    DIRRES=$( ls -al $directory | egrep $grepIncl | egrep -v $grepExcl )
  fi
  DIRRESTIME=`date`
}

checkCLS () {
  if [ "$clearSC" == "1" ] ; then 
    `clear`
  fi
}

displayOutput () {

  if [[ $# -gt 0 ]] ; then
    if [[ "$outFile" == '' ]] ; then
      echo "$*"
    else
      echo "$*" >>$outFile
    fi
  else
    if [[ "$outFile" == '' ]] ; then
      echo ""
    else
      echo "" >>$outFile
    fi
  fi
}

# Usage command
usage () {

     rc=0

#   If a parameter has been passed then echo it
     [[ $# -gt 0 ]] && { echo "${0##*/}: $*" 1>&2; rc=1; }

     cat <<-EOF 1>&2
   Usage: watch.ksh {-h] [-C|c] [-b|B] [-x] [-n <number of iterations>] [-w <wait>] [-d directory to monitor] [-G <matching string>] [-g <matching string>] [-m <email address>] [[-e] <command to run>] [-o <filename>]

      -h      : this message
      -n      : number of times to issue the command (default is 288)
      -w      : wait time before executions in seconds (default is 300)
      -d      : directory to watch - when something changes run the command
      -C      : identify when command output doesn't change
      -c      : identify when command output changes
      -g      : include output which matches this string
      -G      : exclude output which matches this string
      -q      : clear screen between executions
      -m      : parameter is an email address. When state changes an email will be sent to this address
      -b      : when the -c or -C event occurs then break [default]
      -B      : when the -c or -C event occurs then continue
      -a      : Add before and after snapshots to end of command (only valid where -d and -e specified
      -r      : modifies the -C parameter to mean stop on no change
      -x      : dont run profile scripts
      -o      : if specified command output will be directed here (appended)
      <command> : if no command is entered then the current time will just be displayed (note -e is optional)

   Script to repeat a specified command a number of times

   Notes:
           1. Really just an expansion of while true; do <command> ; sleep 120 ; done
           2. The following 2 commands are functionally identical
                  watch.ksh -n 5 -w 10 -d '/home/d94115/local\*'
              and
                  watch.ksh -n 5 -w 10 -e 'ls -al /home/d94115/local\*'

              The benefit of using the first form is that it allows you to execute a command on status change

           Another use, to send an email when the directory changes, could be:

             watch.ksh -n 20 -c  -w 5 -d '/home/d94115/local\*' -m 'webmaster@KAGJCM.com.au'

EOF

     exit $rc
}

mach=`uname -a | cut -d " " -f 2`

#-----------------------------------------------------------------------
# Set defaults and parse command line

# Default settings
numIter=288
wait=300
command=""
directory=""
change="0"
break="1"
append="0"
email=""
grepIncl=""
grepExcl=""
clearSc="0"
outFile=""
runProfile=1;

# Check command line options
while getopts ":hxCcqg:G:n:o:w:e:a:m:d:bB" opt; do
     case $opt in
         # How many times to run the command
         n) numIter="$OPTARG" ;;

         # How long to wait between executions
         w) wait="$OPTARG" ;;

         #  Check for change indicator
         C) change="-1" ;;

         #  set the output file
         o) outFile="$OPTARG" ;;

         #  Check for change indicator
         c) change="1" ;;

         #  Dont run the profile scripts
         x) runProfile=0 ;;

         #  Set grep include string
         g) echo "Only lines containing $OPTARG will be displayed"
            grepIncl="$OPTARG" ;;

         #  Set grep exclude string
         G) echo "Lines containing $OPTARG will be exluded"
            grepExcl="$OPTARG" ;;

         #  Set clear screen optrion
         q) clearSc="1" ;;

         #  email to be sent?
         m) email="$OPTARG" ;;

         #  Append before and after images to command
         a) append="1" ;;

         #  Break on change of state
         b) break="1" ;;

         #  Dont break on change of state
         B) break="0" ;;

         #  Directory to monitor
         d) if [ "$OPTARG" == '' ]; then
              directory=' '
            else
              directory="$OPTARG" 
            fi;;

         #  What to execute
         e) command="$OPTARG" ;;

         # Print out the usage information
         h)  usage ''
             return 1 ;;

         *)  usage 'invalid option(s)'
             return 1 ;;
     esac
done
shift $(($OPTIND - 1))      # get rid of any parameters processed by getopts

# assign parameters if not explicitly assigned

for i in "$@"
do
   command="$command $i"
   shift
done

if [[ $numIter == 1 ]] ; then
   echo The command will be executed once 
else
   echo The command will be executed $numIter times
fi

echo The delay between executions will be $wait seconds

# get rid of any backslashes
command=${command//\\/}
directory=${directory//\\/}

# run set up scripts if requested

if [[ $runProfile == 1 ]] ; then
  if [ -f sqllib/db2profile ]; then
       . sqllib/db2profile
  fi

  if [ -f ~/.bashrc ]; then
       . ~/.bashrc
  fi

  if [ -f ~/.profile ]; then
       . ~/.profile
  fi
fi


# end of parameter section
#-----------------------------------------------------------------------

if [[ "$directory" == '' ]] ; then
  displayOutput "The commnand to be run is: $command"
  displayCMD="$command"
  set +f
  checkCLS
  TMP=`date`
  TMP+=" Iteration $numIter ($command)"
  displayOutput "$TMP" 
  executeCommand
  displayOutput "$RES" 
  HOLDRES="$RES"      # holds the results from the previous execution
  HOLDTIME="$RESTIME" # holds the tiome of the previous execution
  numIter=$[$numIter-1]
else
  displayOutput "The commnand to be run is: ls -al $directory"
  command=${command//##DIR##/$directory}
  echo Command to be triggered when state changes: $command
  displayCMD="ls -al $directory"
  set +f
  checkCLS
  TMP=`date`
  TMP+=" Iteration $numIter"
  displayOutput $TMP
  executeDirCommand
  displayOutput "$DIRRES"
  HOLDRES="$DIRRES"
  HOLDTIME="$DIRRESTIME"
  numIter=$[$numIter-1]
fi

if [[ "$directory" == '' ]] ; then

  while [ $numIter -gt 0 ]
     do
       subject="watch.ksh alert" 

       sleep $wait
       checkCLS
       TMP=`date`
       TMP+=" Iteration $numIter ($command)"
       displayOutput $TMP
       executeCommand
       displayOutput "$RES"
       numIter=$[$numIter-1]
       if [ $change -ne 0 ] ; then
         if [ $change -gt 0 ] ; then # break on change
           subject="$subject - output changed" 
           if [ "$HOLDRES" != "$RES" ] ; then
             if [ -n "$email" ] ; then
               sendEmail
             fi 
             if [ $break -gt 0 ] ; then
               break
             fi
           fi
         else # break on no change
           subject="$subject - output NOT changed" 
           if [ "$HOLDRES" == "$RES" ] ; then
             if [ -n "$email" ] ; then
               sendEmail
             fi 
             if [ $break -gt 0 ] ; then
               break
             fi
           fi
         fi
       fi
       HOLDRES="$RES"
       HOLDTIME="$RESTIME"
     done

else # directory is set so things are a little bit diffent - now it watches a directory

  while [ $numIter -gt 0 ]
     do
       subject="watch.ksh alert" 

       sleep $wait
       checkCLS
       TMP=`date`
       TMP+=" Iteration $numIter"
       displayOutput $TMP
       executeDirCommand
       displayOutput "$DIRRES"
       numIter=$[$numIter-1]
       if [ $change -ne 0 ] ; then
         if [ $change -gt 0 ] ; then # break on change
           subject="$subject - output changed" 
           if [ "$HOLDRES" != "$DIRRES" ] ; then
             set -f
             executeCommand
             displayOutput "$RES"
             if [ -n "$email" ] ; then
               sendEmail
             fi 
             if [ $break -gt 0 ] ; then
               break
             fi
           fi
         else # break on no change
           subject="$subject - output NOT changed" 
           if [ "$HOLDRES" == "$DIRRES" ] ; then
             set -f
             executeCommand
             displayOutput "$RES"
             if [ -n "$email" ] ; then
               sendEmail
             fi 
             if [ $break -gt 0 ] ; then
               break
             fi
           fi
         fi
       fi
       HOLDRES="$DIRRES"
       HOLDTIME="$DIRRESTIME"
     done

fi

