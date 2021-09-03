#!/bin/bash

# script to continuously montior the nginx access.log file and to add iptables rules to remoce access from bots

export dt=`date -d "yesterday 13:00 " '+%Y-%m-%d'`

grep new logs/logScraper_$dt.log | cut -d"[" -f 2 | cut -d"," -f 1 | sort -u | awk '{print "IP blocked: "$1}' | mailx -s "$dt Blocked IPs" kevin@localhost
