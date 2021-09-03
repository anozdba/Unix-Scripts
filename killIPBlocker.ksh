#!/bin/bash
# --------------------------------------------------------------------
# killIPBlocker.ksh
#
# $Id: killIPBlocker.ksh,v 1.2 2013/07/17 01:54:16 db2admin Exp db2admin $
#
# Description:
# Script to kill IPBlocker.ksh
#
# Usage:
#   killIPBlocker.ksh
#
# $Name:  $
#
# ChangeLog:
# $Log: killIPBlocker.ksh,v $
#
# --------------------------------------------------------------------

exec >logs/killIPBlocker.log
echo '# Commands generated ' `date` >/tmp/killIPBlocker.ksh
for i in `ps -ef | grep logScraper | grep -v grep | awk '{print $2}'`
  do
    echo "kill $i"  >>/tmp/killIPBlocker.ksh
  done
chmod a+x /tmp/killIPBlocker.ksh
/tmp/killIPBlocker.ksh

echo '# Commands generated ' `date` >/tmp/killIPBlocker.ksh
for i in `ps -ef | grep IPBlocker.ksh | grep -v grep | awk '{print $2}'`
  do
    echo "kill $i"  >>/tmp/killIPBlocker.ksh
  done
chmod a+x /tmp/killIPBlocker.ksh
/tmp/killIPBlocker.ksh

