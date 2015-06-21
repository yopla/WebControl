#!/bin/sh

# Simple sample script for creating daily stats
# best called from cron at 23:59

cd /root/fwanalog

# create the daily report
nice ./fwanalog.sh -t 

# mail the report to root
cat out/today.txt | mail -s "daily firewall log" root

# call script normally
nice ./fwanalog.sh
