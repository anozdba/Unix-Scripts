#!/bin/bash

# script to continuously montior the nginx access.log file and to add iptables rules to remoce access from bots

export dt=`date '+%Y-%m-%d'`

tail -f /var/log/nginx/access.log | /home/shared/udbdba/scripts/logScraper.pl -I 1>>logs/logScraper_$dt.log
