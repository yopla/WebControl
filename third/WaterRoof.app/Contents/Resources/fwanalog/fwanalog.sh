#!/bin/bash

###########################################################################
#
#	Shell program to parse firewall logs and analyze them with Analog.
#
#	Copyright 2001-2002, Balazs Barany balazs@tud.at
#
#	Version 0.6.9-w1 (patched & modified for OSX and Waterroof)
#
#	This program is free software; you can redistribute it and/or
#	modify it under the terms of the GNU General Public License as
#	published by the Free Software Foundation; either version 2 of the
#	License, or (at your option) any later version. 
#
#	This program is distributed in the hope that it will be useful, but
#	WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#	General Public License for more details.
#
#	Description:
#
#
#	NOTE: You must be the superuser to run this script or at least have
#		  access to the firewall logs. (See README.sudo for a solution.)
#
#	Usage:
#
#		fwanalog.sh [ -h | --help ] [-c conffile][-r] [-t] [-y] [-a IP-addr] [-p packet] 
#
#	Options:
#
#		-h, --help	Display this help message and exit.
#		-r          Rotate log cache
#		-c conffile Use this config file instead of ./fwanalog.opts
#		-t          Only update statistics for today (for hourly use in crontab)
#	                  The sep_hosts and sep_packets commands in fwanalog.opts
#	                  are ignored.
#		-y			Like -t, only for yesterday
#		-a IP-addr  Create a separate report for this host 
#		-p packet   Create a separate report for this packet 
#                       Format: target/protocol/portnumber
#                       e.g. 192.168.0.1/tcp/21 or firewall/udp/137		
#
#
#	$Id: fwanalog.sh,v 1.81 2005/02/24 16:59:44 bb Exp $
#
#	Revisions:
#
#	2001-04-07	File created
#	2001-04-08	First release 0.1, announced on Freshmeat
#	2001-04-15	Release 0.2: Linux 2.2 ipchains support
#	2001-05-05	Release 0.2.1: Analog 5.0 support, bugfixes
#	2001-06-07	Release 0.2.2: FreeBSD support
#	2001-08-05	Release 0.3: Bugfixes; ICMP support on Linux; onehost=dynip
#	2001-08-18	Version 0.4pre: Speed improvement in the diff phase
#	2001-08-23	Release 0.4: -t option, bugfixes in the pre version
#	2001-11-23	Release 0.4.1: regexp bugfixes in iptables() and ipchains()
# 	2001-12-22	Version 0.5pre: OpenBSD 3.0 pf and Solaris support
# 	2002-02-19	Version 0.5: iptables log-prefix support, portability fixes
# 	2002-02-23	Version 0.5.1: better error handling; analog 5.21 compatible
# 	2002-03-03	Version 0.5.2: added ZyNOS parser
# 	2002-03-07	Version 0.6pre: optional separate reports for each packet 
#                               and host
#	2002-04-28	Version 0.6: integrated change requests from lots of people
#	2002-04-28	Version 0.6.1: some bugfixes with packet/host report generation
#	2003-01-03	Version 0.6.2pre1: Support for Cisco PIX firewall logs
#	2003-01-08	Version 0.6.2: Released as pix() seems to work and because
#								the new analog version requires a new langfile
#	2003-01-14	Version 0.6.3pre1: Support for Watchguard Firebox logs
#	2003-01-18	Version 0.6.3pre2: New -y option for yesterday's logs, smaller
#								fixes
#	2003-01-21	Version 0.6.3pre3: Bugfix in watchguard(): allow two-digit dates
#	2003-01-22	Version 0.6.3pre4: pix(): allow [] around the logging host name
#	2003-02-13	Version 0.6.3pre5: pix(): the PIX date seems to be optional with
#										some configurations
#	2003-02-13	Version 0.6.3pre6: Added the -c option for using a different
#										config file
#	2003-03-11	Version 0.6.3pre7: Added support for Firewall-One 
#										(written by Jean-Louis Saint-Dizier)
#	2003-03-17	Version 0.6.3: Finally releasing it as stable
#	2003-03-20	Version 0.6.4pre1: Added support for Cisco routers with
#										access-lists, further fixes in cisco()
#	2003-06-19	Version 0.6.4pre2: Fixes in many functions, mostly in cisco()
#	2003-11-25	Version 0.6.4pre4: Smaller fixes, mainly for PIX
#	2004-03-18	Version 0.6.4: PIX fixes, released as 0.6.4 on the request of
#										the Debian maintainer
#	2005-02-24	Version 0.6.9: PIX fix, added contributed ipfw, sonicwall
#										parsers
#
###########################################################################

###########################################################################
#	Constants
###########################################################################

# Script options

PROGNAME=$(basename $0)
VERSION="0.6.9"

###########################################################################
#	Variables
###########################################################################

#
# Only update today's page - initialize with false
#
today_only=false		

#
# Only update yesterday's page - initialize with false
#
yesterday_only=false		

###########################################################################
#	Commands - Assist in platform portability - with defaults
###########################################################################

sed=${sed:-sed}
perl=${perl:-perl}
grep=${grep:-grep}
egrep=${egrep:-egrep}
zegrep=${zegrep:-zegrep}
analog=${analog:-analog}
date=${date:-date}

###########################################################################
#	Functions
###########################################################################

main ()
{
	# Function to do everything the script normally does.

	# Get today's date for the daily reports.
	TODAY=`$date +%y%m%d`

	if [ X"$configfile" != X ]; then
	# A config file is given
		if [ -r "$configfile" ]; then
			# use this if it is readable
			. "$configfile"

			# change into the script's directory because the analog config files are there
			cd `dirname $0`
		else
		# specified config file isn't readable or doesn't exist
			echo "fwanalog: couldn't read specified config file '$configfile'" >> /dev/stderr
			exit 1
		fi
	else
		# change into the script's directory because all the config files are there
		cd `dirname $0`
	
		# Load the user-settable options from the config file
		. ./`basename $0 | $sed 's/sh$/opts/'`
	fi

	if [ -z "$inputfiles" ]; then
		echo "fwanalog: No input files in the '$inputfiles_dir' directory " >> /dev/stderr
		echo "named $inputfiles_mask and under $inputfiles_mtime days old." >> /dev/stderr
		exit 1
	fi
	
	# create the output directory if necessary, ignore errors
	mkdir -p $outdir

    # Check if the lock file is there. If yes, warn and exit.
    if [ -e $outdir/fwanalog.lock ]; then
		echo "fwanalog: found lockfile '$outdir/fwanalog.lock'. " >> /dev/stderr
		echo "This could mean that another instance is running." >> /dev/stderr
		echo "If this is not the case, please remove the lock file." >> /dev/stderr
		exit 1
    fi

    # Create lock file
    touch $outdir/fwanalog.lock
	
	# Parse the logs into a format Analog understands
	$logformat

	# make sure the "all logs" file exists
	touch $outdir/fwanalog.all.log

	# Find the new lines since the last invocation
	if [ -s $outdir/fwanalog.all.log ]; then
	# there is already an old log - find its last line and use it
	# to determine the new contents of the grepped/converted file
		$grep . $outdir/fwanalog.all.log \
			| tail -n 1 \
			| $sed 's/[^a-zA-Z0-9 _-]/./g' \
			| $sed 's#^\(.*\)$#0,/^\1$/d#' \
			> $outdir/match_last_line.sed
			# match_last_line.sed now contains the last line in regexp form, so
			# it can be searched in the new file. Most non-alphanumeric chars
			# have been replaced with . so they don't act as metacharacters.

		$grep . $outdir/fwanalog.all.log \
			| tail -n 1 \
			| $sed 's/[^a-zA-Z0-9 _-]/./g' \
			> $outdir/match_last_line.pattern
			# create the regexp for grep

		# The two "$grep ."-s are for RedHat 7.1 systems with a broken zegrep
		# which appends a blank line at the end of its output
			
		# Check if there is a common part in the old an the new log
		if $grep --silent "`cat $outdir/match_last_line.pattern`" $outdir/fwanalog.current.log ; then
		# there is a common part
        
			# Delete the common lines in the current log so only the new ones
			# stay and write it to the end of the global log
			$sed -f $outdir/match_last_line.sed $outdir/fwanalog.current.log \
				>> $outdir/fwanalog.all.log

			# Save the new lines in current.log.1 and move that over current.log
			$sed -f $outdir/match_last_line.sed $outdir/fwanalog.current.log \
				> $outdir/fwanalog.current.log.1
			mv $outdir/fwanalog.current.log.1 $outdir/fwanalog.current.log
		else 
		# no common part
			cat $outdir/fwanalog.current.log >> $outdir/fwanalog.all.log
		fi
	else
	# There is no old log. We can use the entire current log.
		cp $outdir/fwanalog.current.log $outdir/fwanalog.all.log
	fi

	# Create an empty domain cache for analog so it doesn't complain
	touch $outdir/analog-domains.tab

	# Ask Analog's version number
	analogver=`$analog --help 2>&1 \
		| $grep "This is analog version" \
		| $sed 's!^.*\([0-9]\)\.[0-9]*/.*$!\1!'`

	# If the version couldn't be determined, chances are that analog is not 
	# really executable (misconfiguration!)
	if [ "X$analogver" = "X" ]; then
		echo "fwanalog: Analog's version could not be determined."
		echo "          Please check if it is installed, executable and"
		echo "          correctly given in fwanalog.opts."
		echo "exiting."
	
		exit 1
	fi

	# Command line option for the debugging phase: list corrupt logfile entries
	# This is important if bugs appear but doesn't disturb if they don't
	analogopts="$analogopts +V+C"

	# Version-dependent Analog config file
	touch $outdir/fwanalog.analog.conf.ver

	# Don't warn in case of empty reports, this is good for daily reports 
	# in case you're not attacked on this day
	noemptyreportwarning=" +q-R"

	rm -f "$outdir/analog.err"
	
	# Generate a runtime config file
	genconffile="$outdir/fwanalog.analog.conf.gen"

	echo "DNSFILE $outdir/analog-domains.tab" > "$genconffile"
	echo "DNSLOCKFILE $outdir/analog-domains.lck" >> "$genconffile" 
	echo "LOGFILE $outdir/fwanalog.all.log*" >> "$genconffile"
	echo "CONFIGFILE ./fwanalog.analog.conf.local" >> "$genconffile"

	# Call analog for today with ascii output, suitable for an e-mailed daily report
	$yesterday_only || $analog \
			-G +g./fwanalog.analog.conf $analogopts \
			-C"OUTFILE $outdir/today.txt" -C"OUTPUT ASCII" -d -W -m -4 -o -z -f -v \
			-C"GOTOS OFF" -C"RUNTIME OFF" -C"LASTSEVEN OFF" \
			+F$TODAY $noemptyreportwarning \
			+g"$genconffile" \
			2>> $outdir/analog.err

	# Call analog for yesterday with ascii output, suitable for an e-mailed daily report
	$yesterday_only && $analog \
			-G +g./fwanalog.analog.conf $analogopts \
			-C"OUTFILE $outdir/yesterday.txt" -C"OUTPUT ASCII" -d -W -m -4 -o -z -f -v \
			-C"GOTOS OFF" -C"RUNTIME OFF" -C"LASTSEVEN OFF" \
			+F-00-00-01:0000 +T-00-00-01:2359 $noemptyreportwarning \
			+g"$genconffile" \
			2>> $outdir/analog.err
			
	#Determine if there is an active date limitation
	datelimit=false
	$today_only && datelimit=true
	$yesterday_only && datelimit=true
			
	# Set special options for Analog version 5 and higher
	if [ $analogver -ge 5 ]
	then
		# Charts go to the output directory, name prefix is "alldates-"
		echo "LOCALCHARTDIR $outdir/alldates-" >> "$genconffile"
		echo "CHARTDIR alldates-" >> "$genconffile"
	fi
	
	# Call analog with all data
	$datelimit || $analog \
			-G +g./fwanalog.analog.conf $analogopts \
			-C"OUTFILE $outdir/alldates.html" \
			+g"$genconffile" \
			2>> $outdir/analog.err

	if [ X"$reportmagic" = "Xtrue" ]; then
		# Call analog with all data for ReportMagic
		$datelimit || $analog \
				-G +g./fwanalog.analog.conf $analogopts \
				-C"OUTFILE $outdir/alldates.dat" -C"OUTPUT COMPUTER" \
				+g"$genconffile" \
				2>> $outdir/analog.err
	fi

	# Set special options for Analog version 5 and higher
	if [ $analogver -ge 5 ]
	then
		# Charts go to the output directory, name prefix is "today-"
		$perl -pwi -e "s!^LOCALCHARTDIR.+!LOCALCHARTDIR $outdir/today-!" \
			"$genconffile"
		$perl -pwi -e "s!^CHARTDIR.+!CHARTDIR today-!" \
			"$genconffile"
	fi
	
	# Call analog for today, with the additional quarter-hour-report
	$yesterday_only || $analog \
			-G +g./fwanalog.analog.conf $analogopts \
			-C"OUTFILE $outdir/today.html" -d -W -m \+4 \
			+F$TODAY $noemptyreportwarning \
			+g"$genconffile" \
			2>> $outdir/analog.err

	# Call analog for yesterday if -y was specified, with html output
	$yesterday_only && $analog \
			-G +g./fwanalog.analog.conf $analogopts \
			-C"OUTFILE $outdir/yesterday.html" -d -W -m \+4 \
			-C"LASTSEVEN OFF" \
			+F-00-00-01:0000 +T-00-00-01:2359 $noemptyreportwarning \
			+g"$genconffile" \
			2>> $outdir/analog.err

	# Set special options for Analog version 5 and higher
	if [ $analogver -ge 5 ]
	then
		# Charts go to the output directory, name prefix is "lastweek-"
		$perl -pwi -e "s!^LOCALCHARTDIR.+!LOCALCHARTDIR $outdir/lastweek-!" "$genconffile"
		$perl -pwi -e "s!^CHARTDIR.+!CHARTDIR lastweek-!" "$genconffile"
	fi
	
	# Call analog for the last 7 days, with the additional hourly report
	$datelimit || $analog \
			-G +g./fwanalog.analog.conf $analogopts \
			-C"OUTFILE $outdir/lastweek.html" +H \
			+F-00-00-06 \
			+g"$genconffile" \
			2>> $outdir/analog.err
			
	# Remove the unnecessary "HTML Conformant" lines from the output
	# ignore error messages
	$perl -pwi -e 's!^.+(validator\.w3\.org/"|nonehtml2\.(gif|png)|HTML 2\.0 Conformant).+$!!' \
		$outdir/alldates.html $outdir/today.html $outdir/lastweek.html \
		2> /dev/null
		
	# If only today's or yesterday's report is generated, don't create separate 
	# host and packet reports unless $host_to_report or $packet_to_report is set
	# (checked later)
	if $datelimit; then
		sep_hosts=false
		sep_packets=false
	fi
		
	# Check if -a was used: create a separate report.
	if [ X"$host_to_report" != X ]; then
		sep_hosts=true
		# must create the separate host report
	fi
		
	# If configured, create separate logs for each host from the current log or
	# for the host given with -a
	if [ "X$sep_hosts" = "Xtrue" ]; then
		
		# The following characters are allowed in domain names - this is
		# important because people could (perhaps) manipulate their reverse DNS
		# to point to "../../../etc/passwd>.../something" and we would then, 
		# as root, overwrite that file with a report.
		hostchars='a-zA-Z0-9._-'

		if [ X"$host_to_report" = X ]; then
		# Create a list of unique IPs in the current log
			$sed 's/^\([0-9.]*\) .*$/\1/' $outdir/fwanalog.current.log \
				| sort -u \
				> $outdir/fwanalog.current.hosts.log
		else
		# Just use the provided IP address for the report
			if $egrep --silent " ([0-9].){4} $host_to_report" $outdir/analog-domains.tab; then
			# The address given on the command line is a domain name (not an
			# IP), so extract the IP address.
				host_to_report=`$egrep "([0-9].){4} $host_to_report" \
									$outdir/analog-domains.tab \
									| $perl -pwe "s/^\\d+ ([0-9.]+) $host_to_report/\$1/i"`
			fi
			
			echo "$host_to_report" > $outdir/fwanalog.current.hosts.log
		fi

		mkdir -p $outdir/hosts

		# Create a separate report for each host
		for host in `cat $outdir/fwanalog.current.hosts.log`; do
			
			# Determine the dns name of this host, if existent
			hostname=`$egrep "$host [$hostchars]+\$" $outdir/analog-domains.tab \
				| $perl -pwe 's/^[0-9]* [0-9.]* (.*)$/\L$1/' `
			#hostname can contain only the allowed characters ($hostchars).
			#It is lowercased because analog also lowercases the names.

			# Use the IP address if the name couldn't be resolved
			if [ X"$hostname" = "X" ]; then
				hostname=$host
			fi

			# Set special options for Analog version 5 and higher
			if [ $analogver -ge 5 ]
			then
				# Charts go to the output directory, name prefix is "hosts/NAME-"
				$perl -pwi -e "s!^LOCALCHARTDIR.+!LOCALCHARTDIR $outdir/hosts/$hostname-!" "$genconffile"
				$perl -pwi -e "s!^CHARTDIR.+!CHARTDIR $hostname-!" "$genconffile"
			fi
	
			# Call analog with all data
			$analog \
					-G +g./fwanalog.analog.conf $analogopts \
					-C"OUTFILE $outdir/hosts/$hostname.html" \
					-C"ORGANISATION OFF" -C"DOMAIN OFF" \
					-C"HOSTINCLUDE $hostname" \
					+g"$genconffile" \
					2>> $outdir/analog.err

			# Remove the unnecessary "HTML Conformant" lines from the output
			$perl -pwi -e 's!^.+(validator\.w3\.org/"|nonehtml2\.(gif|png)|HTML 2\.0 Conformant).+$!!' \
				$outdir/hosts/$hostname.html
		done

	fi
			
	# Check if -p was used: create a separate packet report.
	if [ X"$packet_to_report" != X ]; then
		sep_packets=true
		# must create the separate packet report
	fi
		
	# If configured, create separate logs for each packet from the current log
	# or for the packet given with -p
	if [ "X$sep_packets" = "Xtrue" ]; then
		
		if [ X"$packet_to_report" = X ]; then
		# Create a list of unique packets in the current log, and remove
		# slashes from the end (for protocols without a port number)
			$sed 's!^.*"GET /\([0-9a-zA-Z./]*\)/ HTTP.*$!\1!' $outdir/fwanalog.current.log \
				| sort -u \
				| $sed 's!/$!!' \
				> $outdir/fwanalog.current.packets.log
		else
		# Just use the provided packet for the report
			echo "$packet_to_report" > $outdir/fwanalog.current.packets.log
		fi

		mkdir -p $outdir/packets

		# Create a separate report for each packet
		for packet in `cat $outdir/fwanalog.current.packets.log`; do
			
			# Convert the packet into a matching pattern for analog's FILEINCLUDE
			analogmatch=`echo $packet \
				| $perl -pwe 's!(firewall|[0-9.]+)/([a-z]+)/([0-9]+)!/$1/$2/*($3)/*!gi'`

			# Convert the packet, which contains slashes, into a
			# filesystem-friendly form
			fsform=`echo $packet | $sed 's!/!-!g'`
			
			# Set special options for Analog version 5 and higher
			if [ $analogver -ge 5 ]
			then
				# Charts go to the output directory, name prefix is "packets/PACKET-"
				$perl -pwi -e "s!^LOCALCHARTDIR.+!LOCALCHARTDIR $outdir/packets/$fsform-!" "$genconffile"
				$perl -pwi -e "s!^CHARTDIR.+!CHARTDIR $fsform-!" "$genconffile"
			fi
	
			# Call analog with all data
			$analog \
					-G +g./fwanalog.analog.conf $analogopts \
					-C"OUTFILE $outdir/packets/$fsform.html" \
					-C"FILEINCLUDE /$packet/*" \
					-C"FILEINCLUDE $analogmatch" \
					+g"$genconffile" \
					2>> $outdir/analog.err

			# Remove the unnecessary "HTML Conformant" lines from the output
			$perl -pwi -e 's!^.+(validator\.w3\.org/"|nonehtml2\.(gif|png)|HTML 2\.0 Conformant).+$!!' \
				$outdir/packets/$fsform.html
		done
	fi

	# Change hosts in each generated report to point to the page about this host
	
	# Search for host reports in the output directory and edit the output
	# files to link to them
	for hostlog in $outdir/hosts/*.html; do

		# Get the hostname from the filename
		hostname=`echo $hostlog | $sed 's/^.*hosts.\(.*\).html/\1/' `

		if [ X"$hostname" != "X*" ]; then
		# there are files
		
			# Replace all hosts with a URL pointing to the separate report
			$perl -pwi -e \
				"s!(\\d+): ($hostname)\$!\$1: <a href=\"hosts/\$2.html\">\$2</a>!i" \
				$outdir/alldates.html $outdir/lastweek.html $outdir/today.html

			# Do the same in each file in the packet directory
			for packetlog in `$egrep -l "$hostname" $outdir/packets/*.html 2> /dev/null`; do

				if [ -e "$packetlog" ]; then
					$perl -pwi -e \
						"s!(\\d+): ($hostname)\$!\$1: <a href=\"../hosts/\$2.html\">\$2</a>!i" \
						"$packetlog"
				fi
			done
		fi
	done

	# The same for packets
	
	# Search for packet reports in the output directory and edit the output
	# files to link to them
	for packetlog in $outdir/packets/*.html; do

		# Get the packet from the filename
		packet=`echo $packetlog \
			| $sed 's!^.*/packets/\(.*\).html$!\1!' \
			| $sed 's!-!/!g' `

		# Get the relative filename
		packetfile=`echo $packetlog \
			| $sed 's!^.*/packets/\(.*.html\)$!\1!' `

		# Convert the first form into a matching pattern
		packetform1=`echo $packet \
			| $perl -pwe 's!^(firewall|[0-9.]+)/([a-z0-9]+)/([0-9]*)$!$1:$3/$2!i'`
		# Convert the second form into a matching pattern
		packetform2=`echo $packet \
			| $perl -pwe 's!^(firewall|[0-9.]+)/([a-z0-9]+)/([0-9]*)$!$1:[a-z0-9_*-]+ \\\\($3\\\\)/$2!i'`

		if [ X"$packet" != "X*" ]; then
		# there are packet logs

			# Replace all packets with a URL pointing to the separate report
			# - both possible forms
			$perl -pwi -e \
				"s!(\\d+: +)($packetform1)\$!\$1<a href=\"packets/$packetfile\">\$2</a>!i" \
				$outdir/alldates.html $outdir/lastweek.html $outdir/today.html
			$perl -pwi -e \
				"s!(\\d+: +)($packetform2)\$!\$1<a href=\"packets/$packetfile\">\$2</a>!i" \
				$outdir/alldates.html $outdir/lastweek.html $outdir/today.html

			# Do the same in each host log
			for hostlog in `$egrep -l "$packetform1|$packetform2" $outdir/hosts/*.html 2> /dev/null`; do

				if [ -e "$hostlog" ]; then

					$perl -pwi -e \
						"s!(\\d+: +)($packetform1)\$!\$1<a href=\"../packets/$packetfile\">\$2</a>!i" \
						"$hostlog"
					$perl -pwi -e \
						"s!(\\d+: +)($packetform2)\$!\$1<a href=\"../packets/$packetfile\">\$2</a>!i" \
						"$hostlog"
				fi
			done
		fi
	done
	
	keeperrfile=false	
	
	# check if there were corrupt lines
	corruptlines=`$grep "^C: " $outdir/analog.err | wc -l` 
	if [ $corruptlines -ge 1 ]; then
		echo "Analog found $corruptlines corrupt lines. Please consider sending "
		echo "$outdir/analog.err to balazs@tud.at "
		echo "so the author is able to fix the problem."
		keeperrfile=true
	fi
	
	# check if Analog complains of an old language file
	corruptlines=`$grep -i "error.*language file.*exiting" $outdir/analog.err | wc -l` 
	if [ $corruptlines -ge 1 ]; then
		echo "Analog isn't happy about the language file. Probably you updated"
		echo "to a new version. "
		echo "Use the mklangfile.*.sh scripts in the fwanalog distribution"
		echo "to create a new language file for fwanalog or get the current"
		echo "version of fwanalog (or just the language files) from"
		echo "http://tud.at/programm/fwanalog/"
		keeperrfile=true
	fi
	
	# Check if there is an error which wasn't catched
	corruptlines=`$grep "." $outdir/analog.err | wc -l` 
	if [ $corruptlines -ge 1 ]; then
		if [ "X$keeperrfile" != 'Xtrue' ]; then
		# There was no specific error message
			echo "fwanalog: Analog printed the following error messages ($outdir/analog.err):" >> /dev/stderr
			cat "$outdir/analog.err" >> /dev/stderr
			keeperrfile=true
		fi
	fi
	
	if [ "X$keeperrfile" != 'Xtrue' ]; then
		# no problem, remove the error log
		rm $outdir/analog.err
	fi

	# Clean up old logfiles
	rm -f $outdir/fwanalog.curr* $outdir/fwanalog.new*.log $outdir/convdate.sed \
		$outdir/fwanalog.analog.conf.ver $outdir/fwanalog.analog.conf.gen $outdir/match_last_line.*

    # Delete the lock file
    rm -f $outdir/fwanalog.lock
}

iptables () 
{
	# Parse iptables logfiles into an analog-compatible "URL log"

	$zegrep -h "IN.+OUT.+SRC.+DST.+LEN.+TTL.+PROTO.+" $inputfiles \
		| $sed 's/TYPE=\([0-9]\+\)/SPT= DPT=\1/' \
		> $outdir/fwanalog.current

	mkdateconvscript
	# Create script to convert lines without year to fully specified date

	$sed -f $outdir/convdate.sed $outdir/fwanalog.current > $outdir/fwanalog.current.withyear
	# Use the script on the current logfile

	# Example of converted log line:
	# 2001 Mar 31 00:58:17 www kernel: packet_explanation IN=eth1 OUT= MAC=00...:00 SRC=131....38 DST=212....31 LEN=44 \
	#	TOS=0x00 PREC=0x00 TTL=57 ID=58478 PROTO=TCP SPT=61636 DPT=21 WINDOW=16384 RES=0x00 SYN URGP=0 

	# Example of desired output:
	# 131....38 - packet_explanation [31/Mar/2001:00:58:17 +0200] "GET /212....31/TCP/21 HTTP/1.0" 200 \
	#	44 "61636" "00....:00" 10 eth1
	#
	# Which means:
	# ip - iptables_log-prefix [date] "GET Desthost/Protocol/Port" 200 PcktLen "http://Sourceport/" "Macadr" 0 interface
	# Sourceport is in the referrer field, macadr in the user-agent, interface
	# in the VirtualHost. (The interface comes from IN= and/or OUT=)
	# There is not always a MAC address, e.g. if the interface is ppp0

	# Decide if the source or the destination host is included in the 
	# Blocked Packet Report (option "onehost" in fwanalog.opts)
	if [ $onehost = true ]; then
		reqhost="\$9"				# The analog "request" contains the source ip
	elif [ $onehost = dynip ]; then
		reqhost="firewall"			# The analog "request" contains this string
	else
		reqhost="\$10"				# The analog "request" contains the destination ip
	fi
	#                1    2       3     4                5                       6        7               8         9            10           11                  12             13       14
	$perl -pwe "s!^(\d+) +(\w+) +(\d+) ([0-9:]+) [^:]+:? ?([a-zA-Z0-9/.,:_-]*).*IN=(.*) OUT=(\S*) ?M?A?C?=?(.*) SRC=([0-9.]+) DST=([0-9.]+) LEN=(\d+)[^[]+PROTO=([a-zA-Z0-9]+)(?: SPT=)?(\d*)(?: DPT=)?(\d*).*\$!\$9 - \$5 [\$3/\$2/\$1:\$4 $timezone] \"GET /$reqhost/\$12/\$14/ HTTP/1.0\" 200 \$11 \"http://\$13/\" \"\$8\" 0 \$6\$7!" \
		$outdir/fwanalog.current.withyear > $outdir/fwanalog.current.log

	# $outdir/fwanalog.current.log now contains the data in the Analog URL format.
}

ipf ()
{
	openbsd
	# For backward compatibility.
	# Initially, I thought that each BSD with ipf uses the same format. Wrong.
}

solarisipf () 
{
    # Adapted from the openbsd function below

	# Parse Solaris ipf syslog files into an analog-compatible "URL log"
	# Tested with Solaris 8 INTEL and ipf 3.4.20

	${zegrep} -h 'ipmon.+@[0-9:]+ b.+ -> .+ PR.+len' $inputfiles \
		> $outdir/fwanalog.current

	mkdateconvscript
	# Create script to convert lines without year to fully specified date

	${sed} -f $outdir/convdate.sed $outdir/fwanalog.current \
		> $outdir/fwanalog.current.withyear
	# Use the script on the current logfile
	
	# Example of converted log line:
	#	2001 Apr  5 16:55:55 fw ipmon[1875]: 16:55:54.150871              xl0 @0:2 b 
	#	  217.....93,3819 -> 195.....201,1080 PR tcp len 20 48 -S IN
	# Example of desired output:
	# 217....93 - - [5/Apr/2001:16:55:54 +0200] "GET /195.....201/tcp/1080 HTTP/1.0" 200 \
	#	20 "3819" "" 0 xl0
	#
	# Which means:
	# ip - - [date] "GET Desthost/Protocol/Port" 200 PcktLen "http://Sourceport/" "Macadr" 0 interface
	# Sourceport is in the referrer field, macadr in the user-agent, interface
	# in the VirtualHost. There is no macadr in the BSD log.
	
	# Decide if the source or the destination host is included in the 
	# Blocked Packet Report (option "onehost" in fwanalog.opts)
	if [ $onehost = true ]; then
		reqhost="\$7"				# The analog "request" contains the source ip
	elif [ $onehost =  dynip ]; then
		reqhost="firewall"			# The analog "request" contains this string
	else
		reqhost="\$10"				# The analog "request" contains the destination ip
	fi

	${perl} -pwe \
            's!
                ^							# Begin of line :-)
                    (\d+)\s+(\w+)\s+(\w+)			\s+	# syslog year($1) month($2) day($3)
                    [0-9:]+					\s+	# syslog time
                    [a-zA-Z0-9_.]+				\s+  	# syslog hostname
                    ipmon\[\d+\]:				\s+	# ipmon process identifier
                    \[ID\s+\d+\s+\w+\.\w+\]			\s+	# logging info 
                    ([0-9:]+)\.\d+				\s+	# time($4).hirestime
                    .*\s*(\w+)					\s+	# optional multipler and interface name($5)
                    \@[0-9:]+					\s+	# ruleset
                    .						\s+	# action
                    ([a-zA-Z0-9-_.]+\[)?([0-9.]+)\]?			# optional source name($6), source ip($7)
                    ,?([a-zA-Z0-9\-_]*)				\s+	# source port($8) - may be name or number 
                    -\>						\s+	# the arrow :-)
                    ([a-zA-Z0-9-_.]+\[)?([0-9.]+)\]?			# optional destination name($9), destination ip($10)
                    ,?([a-zA-Z0-9\-_]*)				\s+	# destination port($11)  - may be name or number
                    PR\s+(\w+)					\s+	# protocol($12)	
                    len\s+(\d+)						# length($13)
                    .+							# ignore the rest
                $							# End of line :-)
              !$7 - - [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost'/$12/$11/ HTTP/1.0" 200 $13 "http://$10/" "" 0 $5!x' \
		$outdir/fwanalog.current.withyear > $outdir/fwanalog.current.log

	# $outdir/fwanalog.current.log now contains the data in the Analog URL format.
}

openbsd () 
{
	# Parse OpenBSD ipf logfiles into an analog-compatible "URL log"
	# Tested with OpenBSD 2.8 ipf.

	$zegrep -h "ipmon.+@[0-9:]+ b.+ -> .+ PR.+len" $inputfiles \
		> $outdir/fwanalog.current

	mkdateconvscript
	# Create script to convert lines without year to fully specified date

	$sed -f $outdir/convdate.sed $outdir/fwanalog.current > $outdir/fwanalog.current.withyear
	# Use the script on the current logfile
	
	# Example of converted log line:
	#	2001 Apr  5 16:55:55 fw ipmon[1875]: 16:55:54.150871              xl0 @0:2 b 
	#	  217.....93,3819 -> 195.....201,1080 PR tcp len 20 48 -S IN
	# Example of desired output:
	# 217....93 - - [5/Apr/2001:16:55:54 +0200] "GET /195.....201/tcp/1080 HTTP/1.0" 200 \
	#	20 "3819" "" 0 xl0
	#
	# Which means:
	# ip - - [date] "GET Desthost/Protocol/Port" 200 PcktLen "http://Sourceport/" "Macadr" 0 interface
	# Sourceport is in the referrer field, macadr in the user-agent, interface
	# in the VirtualHost. There is no macadr in the BSD log.
	
	# Decide if the source or the destination host is included in the 
	# Blocked Packet Report (option "onehost" in fwanalog.opts)
	if [ $onehost = true ]; then
		reqhost="\$6"				# The analog "request" contains the source ip
	elif [ $onehost =  dynip ]; then
		reqhost="firewall"			# The analog "request" contains this string
	else
		reqhost="\$8"				# The analog "request" contains the destination ip
	fi

	#              1       2      3           4               5            6        7            8        9        10         11
	$perl -pwe "s!^(\d+) +(\w+) +(\w+) .+: ([0-9:]+)\.\d+.+ +(\w+) @.+ . ([0-9.]+),?(\d*) -\\> ([0-9.]+),?(\d*) PR (\w+) len (\d+).+\$!\$6 - - [\$3/\$2/\$1:\$4 $timezone] \"GET /$reqhost/\$10/\$9/ HTTP/1.0\" 200 \$11 \"http://\$7/\" \"\" 0 \$5!" \
		$outdir/fwanalog.current.withyear > $outdir/fwanalog.current.log

	# $outdir/fwanalog.current.log now contains the data in the Analog URL format.
}

pf_30 () 
{
	# Parse OpenBSD 3.0 pf logfiles into an analog-compatible "URL log"
	# This *must* happen on an OpenBSD 3.0 system as it requires the OpenBSD
	# version of tcpdump.

	(for log in $inputfiles ; do
		$gzcat -f $log \
		| $tcpdump -n -e -ttt -q -r -
	done) \
		| $egrep -h "rule .+: block .+ on .+ [0-9.]{7}" \
		> $outdir/fwanalog.current

	mkdateconvscript
	# Create script to convert lines without year to fully specified date

	$sed -f $outdir/convdate.sed $outdir/fwanalog.current > $outdir/fwanalog.current.withyear
	# Use the script on the current logfile
	
	# Example of converted log line:
	#  TCP:
	# 	2001 Dec 21 17:48:50.760648 rule 12/0(match): block in on ae0: 
	#		192.168.49.2.2081 > 192.168.49.3.22: S 2901914301:2901914301(0) 
	#		win 5840 <mss 1460,sackOK,timestamp 6674376 0,nop,wscale 0> (DF)
	#  UDP:
	#   2001 Dec 20 20:16:24.674266 rule 2/0(match): block in on ae0: 
	#		192.168.49.3.137 > 192.168.49.255.137:  udp 50 (ttl 64, id 61825)
	#  ICMP:
	#	2001 Dec 20 20:21:00.324025 rule 3/0(match): block in on ae0: 
	#		192.168.49.1 > 192.168.49.3: icmp: echo reply (id:23464 seq:2) (ttl 255, id 21394)	
	#
	# Example of desired output:
	# 192.168.49.2 - - [5/Apr/2001:16:55:54 +0200] "GET /192.168.49.3/tcp/22 HTTP/1.0" 
	#	200 20 "2081" "" 0 ae0
	#
	# Which means:
	# ip - - [date] "GET Desthost/Protocol/Port" 200 PcktLen "http://Sourceport/" "Macadr" 0 interface
	# Sourceport is in the referrer field, macadr in the user-agent, interface
	# in the VirtualHost. There is no macadr in the BSD log.
	
	# Decide if the source or the destination host is included in the 
	# Blocked Packet Report (option "onehost" in fwanalog.opts)
	# altreqhost is needed for unknown protocols (e.g. esp, ah)
	if [ $onehost = true ]; then
		reqhost="\$6"				# The analog "request" contains the source ip
		altreqhost="\$7"
	elif [ $onehost =  dynip ]; then
		reqhost="firewall"			# The analog "request" contains this string
		altreqhost="firewall"
	else
		reqhost="\$8"				# The analog "request" contains the destination ip
		altreqhost="\$9"
	fi

	#first TCP, then UDP, then ICMP, then others (hopefully this works)
	#               1      2      3        4                                5        6        7            8       9
	$perl -pwe "s!^(\d+) +(\w+) +(\d+) +([0-9:]+)\.\d+ rule.+block \w+ on (\w+): ([0-9.]+)\.(\d+) \\> ([0-9.]+)\.(\d+): tcp (\d+)(.*)\$!\$6 - - [\$3/\$2/\$1:\$4 $timezone] \"GET /$reqhost/tcp/\$9/ HTTP/1.0\" 200 \$10 \"http://\$7/\" \"\" 0 \$5!" \
		$outdir/fwanalog.current.withyear \
 	|$perl -pwe "s!^(\d+) +(\w+) +(\d+) +([0-9:]+)\.\d+ rule.+block \w+ on (\w+): ([0-9.]+)\.(\d+) \\> ([0-9.]+)\.(\d+): +udp (\d+).*\$!\$6 - - [\$3/\$2/\$1:\$4 $timezone] \"GET /$reqhost/udp/\$9/ HTTP/1.0\" 200 \$10 \"http://\$7/\" \"\" 0 \$5!" \
	|$perl -pwe "s!icmp: echo re(quest|ply)!icmp: echo_re\$1!" \
	|$perl -pwe "s!icmp: host(.+)unreachable!icmp: host_unreachable!" \
 	|$perl -pwe "s!^(\d+) +(\w+) +(\d+) +([0-9:]+)\.\d+ rule.+block \w+ on (\w+): ([0-9.]+)(X?) \\> ([0-9.]+): icmp: ([a-z][a-z_]+).*\$!\$6 - - [\$3/\$2/\$1:\$4 $timezone] \"GET /$reqhost/icmp/\$9/ HTTP/1.0\" 200 0 \"http://\$7/\" \"\" 0 \$5!" \
 	|$perl -pwe "s!^(\d+) +(\w+) +(\d+) +([0-9:]+)\.\d+ rule.+block \w+ on (\w+): ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.?(\d*) \\> ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.?(\d*): (\S*) ?(\d*).*\$!\$6 - - [\$3/\$2/\$1:\$4 $timezone] \"GET /$reqhost/\$10/\$9/ HTTP/1.0\" 200 0\$11 \"http://\$7/\" \"\" 0 \$5!" \
 	|$perl -pwe "s!^(\d+) +(\w+) +(\d+) +([0-9:]+)\.\d+ rule.+block \w+ on (\w+): (\w+) ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.?(\d*) \\> ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.?(\d*).*len (\d+).*\$!\$7 - - [\$3/\$2/\$1:\$4 $timezone] \"GET /$altreqhost/\$6\$10/ HTTP/1.0\" 200 \$11 \"http://\$8\" \"\" 0 \$5!" \
		> $outdir/fwanalog.current.log

	# $outdir/fwanalog.current.log now contains the data in the Analog URL format.
}

freebsd () 
{
	# Parse FreeBSD ipf logfiles into an analog-compatible "URL log"
	# Tested with FreeBSD ipf

	$zegrep -h " -> .+ PR.+len" $inputfiles \
		> $outdir/fwanalog.current

	mkmonthconvscript
	# Create script to convert lines with a numeric month to the alphanumeric month (Jan...Dec)

	$sed -f $outdir/convdate.sed $outdir/fwanalog.current \
		> $outdir/fwanalog.current.withmonth
	# Use the script on the current logfile

	# Example of converted log line:
	#	04/06/2001 16:55:55.418398 tun0 @0:2 b 
	#	  217.....93,3819 -> 195.....201,1080 PR tcp len 20 48 -S IN
	# Example of desired output:
	# 217....93 - - [5/Apr/2001:16:55:54 +0200] "GET /195.....201/tcp/1080 HTTP/1.0" 200 \
	#	20 "3819" "" 0 xl0
	#
	# Which means:
	# ip - - [date] "GET Desthost/Protocol/Port" 200 PcktLen "http://Sourceport/" "Macadr" 0 interface
	# Sourceport is in the referrer field, macadr in the user-agent, interface
	# in the VirtualHost. There is no macadr in the BSD log.
	
	# Decide if the source or the destination host is included in the 
	# Blocked Packet Report (option "onehost" in fwanalog.opts)
	if [ $onehost = true ]; then
		reqhost="\$4"				# The analog "request" contains the source ip
	elif [ $onehost =  dynip ]; then
		reqhost="firewall"			# The analog "request" contains this string
	else
		reqhost="\$6"				# The analog "request" contains the destination ip
	fi

	#              1             2                         3              4         5          6         7        8         9     
	$perl -pwe "s!^(\d+/\w+/\d+) ([0-9:]+)\.\d+ *[0-9]*x? +(\w+) @.+ . ([0-9a-f.:]+),*(\d*) -\\> ([0-9a-f.:]+),*(\d*) PR (\w+) len (\d+).+\$!\$4 - - [\$1:\$2 $timezone] \"GET /$reqhost/\$8/\$7/ HTTP/1.0\" 200 \$9 \"http://\$5/\" \"\" 0 \$3!" \
		$outdir/fwanalog.current.withmonth > $outdir/fwanalog.current.log

	# $outdir/fwanalog.current.log now contains the data in the Analog URL format.
}

ipchains () 
{
	# Parse ipchains logfiles into an analog-compatible "URL log"
	# ipchains doesn't write the protocol name into the log, only the protocol number. 
	# So we convert them here manually.

	$zegrep -h "Packet log: .+ (DENY|REJECT) .+PROTO=.+L=.+S.+I=.+F=.+T=" $inputfiles \
		| $sed 's/PROTO=1 /PROTO=icmp /' \
		| $sed 's/PROTO=2 /PROTO=igmp /' \
		| $sed 's/PROTO=6 /PROTO=tcp /' \
		| $sed 's/PROTO=17 /PROTO=udp /' \
		> $outdir/fwanalog.current

	mkdateconvscript
	# Create script to convert lines without year to fully specified date

	$sed -f $outdir/convdate.sed $outdir/fwanalog.current > $outdir/fwanalog.current.withyear
	# Use the script on the current logfile

	# Example of converted log line:
	# 2001 Apr 18 06:26:18 extdevel kernel: Packet log: input DENY eth0 PROTO=17 \
	#	193.83.115.48:137 193.83.115.255:137 L=78 S=0x00 I=60301 F=0x0000 T=128 (#9)
	# Example of desired output:
	# 131....38 - - [31/Mar/2001:00:58:17 +0200] "GET /212....31/TCP/21 HTTP/1.0" 200 \
	#	44 "61636" "00....:00" 10 eth1
	#
	# Which means:
	# ip - - [date] "GET Desthost/Protocol/Port" 200 PcktLen "http://Sourceport/" "Macadr" 0 interface
	# Sourceport is in the referrer field, macadr in the user-agent, interface
	# in the VirtualHost. 
	# There is no MAC address in ipchains logs.

	# Decide if the source or the destination host is included in the 
	# Blocked Packet Report (option "onehost" in fwanalog.opts)
	if [ $onehost = true ]; then
		reqhost="\$8"				# The analog "request" contains the source ip
	elif [ $onehost =  dynip ]; then
		reqhost="firewall"			# The analog "request" contains this string
	else
		reqhost="\$10"				# The analog "request" contains the destination ip
	fi

	#                1    2       3     4              5            6                 7        8 	   9        10      11       12 
	cat $outdir/fwanalog.current.withyear \
		| $perl -pwe "s!^(\d+) +(\w+) +(\d+) ([0-9:]+) .+(DENY|REJECT) ([a-z0-9]+) PROTO=([\w-]+) ([0-9.]+):?(\d*) ([0-9.]+):?(\d*) L=(\d+).+\$!\$8 - - [\$3/\$2/\$1:\$4 $timezone] \"GET /$reqhost/\$7/\$11/ HTTP/1.0\" 200 \$12 \"http://\$9/\" \"\" 0 \$6!" \
		| $perl -pwe "s!^(\d+) +(\w+) +(\d+) ([0-9:]+) .+(DENY|REJECT) ([a-z0-9]+) PROTO=(ICMP/[0-9]+):?[0-9]* ([0-9.]+)(x?) ([0-9.]+)(x?) L=(\d+).+\$!\$8 - - [\$3/\$2/\$1:\$4 $timezone] \"GET /$reqhost/\$7/ HTTP/1.0\" 200 \$12 \"http://\$9/\" \"\" 0 \$6!" \
		> $outdir/fwanalog.current.log

	# $outdir/fwanalog.current.log now contains the data in the Analog URL format.
}


ipfw ()
{
    # fwanalog extension for freebsds ipfw 
    # 15/Sept/2002 Peter Hunkirchen <phunkirchen@t-online.de> 

    # Parse ipfw logfiles into an analog-compatible "URL log"

    $grep -h "Deny" $inputfiles \
        > $outdir/fwanalog.current
      
    mkdateconvscript
    # Create script to convert lines without year to fully specified date

    $sed -f $outdir/convdate.sed $outdir/fwanalog.current > $outdir/fwanalog.current.withyear
    # Use the script on the current logfile
       
    # Example of converted log line:
    # 2002 Sep 15 07:47:04 yepp /kernel: ipfw: 65435 Deny UDP 80.133.123.52:1042 165.132.149.211:4665 out via tun0
    # Example of desired output:
    # 131....38 - - [31/Mar/2001:00:58:17 +0200] "GET /212....31/TCP/21 HTTP/1.0" 200 \
    #       44 "61636" "00....:00" 10 eth1
    #
    # Which means:
    # ip - - [date] "GET Desthost/Protocol/Port" 200 PcktLen "http://Sourceport/" "Macadr" 0 interface
    # Sourceport is in the referrer field, macadr in the user-agent, interface
    # in the VirtualHost.
    # There is no MAC address in ipchains logs.
       
    # Decide if the source or the destination host is included in the
    # Blocked Packet Report (option "onehost" in fwanalog.opts)
    if [ $onehost = true ]; then
        reqhost="\$8"                           # The analog "request" contains the source ip
    elif [ $onehost =  dynip ]; then
        reqhost="firewall"                      # The analog "request" contains this string
    else
        reqhost="\$10"                          # The analog "request" contains the destination ip
    fi

    #               1      2      3     4           5             6        7         8     9         10    11       12	      13
    $perl -pwe "s!^(\d+) +(\w+) +(\d+) ([0-9:]+) .+(Deny|Reject) ([.:\d\w-]+) ([0-9.]+):?(\d*)? ([0-9.]+):?(\d*)? ([\w-]+) ([\w-]+) ([\w-]+)\$!\$7 - - [\$3/\$2/\$1:\$4 $timezone] \"GET /$reqhost/\$6/\$10/ HTTP/1.0\" 200 1 \"http://\$8/\" \"\" 0 \$13 !" $outdir/fwanalog.current.withyear > $outdir/fwanalog.current.log

    # $outdir/fwanalog.current.log now contains the data in the Analog URL format.
}

zynos () 
{
	# Parse ZynOS (ZyXEL, NETGEAR) logfiles into an analog-compatible "URL log"

	# This pattern excludes "last message repeated X times" lines
	# so the count will be artificially low.  How to handle?!?
	$zegrep -h "IP.+Src.+Dst.+(ICMP|TCP|UDP).+spo.+dpo.+" $inputfiles \
		> $outdir/fwanalog.current

	mkdateconvscript
	# Create script to convert lines without year to fully specified date

	$sed -f $outdir/convdate.sed $outdir/fwanalog.current > $outdir/fwanalog.current.withyear
	# Use the script on the current logfile

	# Example of converted log line:
	# 2002 Feb 27 14:43:51 router host: IP[Src=164....2 Dst=65....189 TCP \
	#	spo=02945  dpo=00080]}S03>R02mD

	# Example of desired output:
	# 164....2 - - [27/Feb/2002:14:43:51 +0500] "GET /65....189/TCP/80 HTTP/1.0" 200 \
	#	1 "http://2945/" "" 0 router
	#
	# Which means:
	# SrcIP - - [date] "GET ReqHost/Protocol/DstPort HTTP/1.0" 200 
	#	FakePacketLen "http://SrcPort/" "" 0 routerName
	# SrcPort is in the referrer field, routerName in the VirtualHost.
	# There is no MAC address or packet length in NETGEAR/ZyXEL logs.

	# Decide if the source or the destination host is included in the 
	# Blocked Packet Report (option "onehost" in fwanalog.opts)
	if [ $onehost = true ]; then
		reqhost="\$6"		# The analog "request" contains the source ip
	elif [ $onehost = dynip ]; then
		reqhost="firewall"	# The analog "request" contains this string
	else
		reqhost="\$7"		# The analog "request" contains the destination ip
	fi
	#               1      2      3     4         5                     6               7           8            9               10         11
	$perl -pwe "s!^(\d+) +(\w+) +(\d+) ([0-9:]+) (\S+) [^:]+: +IP\[Src=([0-9\.]+) +Dst=([0-9\.]+) +(\S+) +spo=0*([0-9]+) +dpo=0*([0-9]+)\]}(\S+)\$!\$6 - - [\$3/\$2/\$1:\$4 $timezone] \"GET /$reqhost/\$8/\$10/ HTTP/1.0\" 200 1 \"http://\$9/\" \"\" 0 \$5!" \
		$outdir/fwanalog.current.withyear > $outdir/fwanalog.current.log

	# $outdir/fwanalog.current.log now contains the data in the Analog URL format.
}

cisco () 
{
	# Parse Cisco PIX and router logfiles into an analog-compatible "URL log"
	# Tested with logs from Cisco PIX and routers with access-lists.
	# Adapted from the solarisipf() function

	# Note: Cisco doesn't log packet lengts so each packet is faked to have 0 byte.
	# See Analog's SIZE and *COLS commands to turn off packet size reports.

	pixpatterns="Inbound .+ connection denied from [0-9./]+ to [0-9./]+"
	pixpatterns="$pixpatterns|Deny inbound (udp|icmp|tcp) from [0-9./]+ to [0-9./]+"
	pixpatterns="$pixpatterns|Deny (inbound )?(\(No xlate\) )?(udp|icmp|tcp) src [^:]+:[0-9./]+ dst [^:]+:[0-9./]"
	pixpatterns="$pixpatterns|Deny TCP (\(no connection\) )?from [0-9./]+ to [0-9./]+.+on interface"
	pixpatterns="$pixpatterns|translation creation failed for (udp|icmp|tcp) src [^:]+:[0-9./]+ dst [^:]+:[0-9./]+"
	pixpatterns="$pixpatterns|No translation group found for (udp|icmp|tcp) src [^:]+:[0-9./]+ dst [^:]+:[0-9./]+"
	pixpatterns="$pixpatterns|: list .+ denied [a-z0-9]+ [0-9.()]+ -> [0-9.()]+, .+ packets?"
	${zegrep} -hi "$pixpatterns" $inputfiles \
		> $outdir/fwanalog.current

	mkdateconvscript
	# Create script to convert lines without year to fully specified date

	${sed} -f $outdir/convdate.sed $outdir/fwanalog.current \
		> $outdir/fwanalog.current.withyear
	# Use the script on the current logfile
	
	# Examples of converted log lines:
	#	2002 Dec 24 09:14:18 example.com Dec 24 2002 15:14:18: 
	#		%PIX-2-306001: Inbound TCP connection denied from 
	#		10.206.26.58/4011 to 10.96.160.115/80 flags SYN  on interface outside 
	#	2002 Dec 24 09:05:40 example.com Dec 24 2002 15:05:40: 
	#		%PIX-2-306006: Deny inbound UDP 
	#		from 10.114.112.73/1028 to 10.96.160.196/137 on interface outside 
	#	2002 Dec 24 07:18:05 example.com Dec 24 2002 13:18:05: 
	#		%PIX-3-306011: Deny inbound (No xlate) icmp 
	#		src outside:10.249.118.254 dst outside:10.96.160.84 (type 8, code 0) 

	# Example of desired output:
	# 217....93 - - [5/Apr/2001:16:55:54 +0200] "GET /195.....201/tcp/1080 HTTP/1.0" 200 \
	#	20 "3819" "" 0 xl0
	#
	# Which means:
	# ip - - [date] "GET Desthost/Protocol/Port" 200 PcktLen "http://Sourceport/" "Macadr" 0 interface
	# Sourceport is in the referrer field, macadr in the user-agent, interface
	# in the VirtualHost. There is no macadr in the BSD log.
	
	# Decide if the source or the destination host is included in the 
	# Blocked Packet Report (option "onehost" in fwanalog.opts)
	if [ $onehost = true ]; then
		reqhost="\$5"				# The analog "request" contains the source ip
		reqhost_1="\$7"				# in a more complex regexp is the position $7 instead of $5
		reqhost_2="\$6"				# ... or $6
	elif [ $onehost =  dynip ]; then
		reqhost="firewall"			# The analog "request" contains this string
	else
		reqhost="\$7"				# The analog "request" contains the destination ip
		reqhost_1="\$10"			# in a more complex regexp is the position $10 instead of $7
		reqhost_2="\$8"				# ... or $8
	fi

	cat $outdir/fwanalog.current.withyear \
		| ${perl} -pwe \
            's! 				# Inbound TCP connection denied
                ^							# Begin of line :-)
                    (\d+)\s(\w+)\s+(\w+)	\s+	# syslog year $1 month $2 day $3
					(?:\d{4}\s)?				# optional year when timestamp is switched on
                    ([0-9:]+)				\s+	# syslog time $4
                    (?:\[?[a-zA-Z0-9_.-]*\]?\s)?# optional syslog hostname
					(?:\w\w\w \s+ \d+ \s+ \d+ \s+ [0-9:]+ \s)? # optional PIX date/time in UTC
					.+ Inbound.TCP.connection.denied \s	# PIX ID (?); verbose description
					from \s ([0-9.]+)/([0-9]+)	\s		# Source IP ($5), port ($6)
					to \s ([0-9.]+)/([0-9]+)	\s		# Destination IP ($7), port ($8)
                    flags \s ([A-Z 	]*) [ \t]+			# TCP flags ($9)
					(?:on.interface.)?([a-zA-Z0-9&_-]*)[ \t]*	# interface ($10), possible whitespace
                $							# End of line :-)
              !$5 - - [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost'/tcp/$8/ HTTP/1.0" 200 0 "http://$6/" "" 0 $10!x' \
		| ${perl} -pwe \
            's! 				# Deny TCP (no connection)
                ^							# Begin of line :-)
                    (\d+)\s(\w+)\s+(\w+)	\s+	# syslog year $1 month $2 day $3
					(?:\d{4}\s)?				# optional year when timestamp is switched on
                    ([0-9:]+)				\s+	# syslog time $4
                    (?:\[?[a-zA-Z0-9_.-]*\]?\s)?# optional syslog hostname
					(?:\w\w\w \s+ \d+ \s+ \d+ \s+ [0-9:]+ \s)? # optional PIX date/time in UTC
					.+ Deny.TCP..no.connection.	\s		# PIX ID (?); verbose description
					from \s ([0-9.]+)/([0-9]+)	\s		# Source IP ($5), port ($6)
					to \s ([0-9.]+)/([0-9]+)	\s		# Destination IP ($7), port ($8)
                    flags \s ([A-Z 	]*) \s+				# TCP flags ($9)
					on.interface.([a-zA-Z0-9&_-]+)		# interface ($10)
                .* $							# possible junk, end of line
              !$5 - - [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost'/tcp/$8/ HTTP/1.0" 200 0 "http://$6/" "" 0 $10!x' \
		| ${perl} -pwe \
            's! 				# Deny inbound UDP, first version (with "on interface")
                ^							# Begin of line :-)
                    (\d+)\s(\w+)\s+(\w+)	\s+	# syslog year $1 month $2 day $3
					(?:\d{4}\s)?				# optional year when timestamp is switched on
                    ([0-9:]+)				\s+	# syslog time $4
                    (?:\[?[a-zA-Z0-9_.-]*\]?\s)?# optional syslog hostname
					(?:\w\w\w \s+ \d+ \s+ \d+ \s+ [0-9:]+ \s)? # optional PIX date/time in UTC
					.+ Deny.inbound.UDP \s	# PIX ID (?); verbose description
					from \s ([0-9.]+)/([0-9]+)	\s		# Source IP ($5), port ($6)
					to \s ([0-9.]+)/([0-9]+)	\s		# Destination IP ($7), port ($8)
					on.interface \s ([a-zA-Z0-9&_-]+)?	# interface ($9), 
					.*									# possible whitespace or junk
                $							# End of line :-)
              !$5 - - [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost'/udp/$8/ HTTP/1.0" 200 0 "http://$6/" "" 0 $9!x' \
		| ${perl} -pwe \
            's! 				# Deny inbound UDP, second version (without "on interface")
                ^							# Begin of line :-)
                    (\d+)\s(\w+)\s+(\w+)	\s+	# syslog year $1 month $2 day $3
					(?:\d{4}\s)?				# optional year when timestamp is switched on
                    ([0-9:]+)				\s+	# syslog time $4
                    (?:\[?[a-zA-Z0-9_.-]*\]?\s)?# optional syslog hostname
					(?:\w\w\w \s+ \d+ \s+ \d+ \s+ [0-9:]+ \s)? # optional PIX date/time in UTC
					.+ Deny.inbound.UDP \s	# PIX ID (?); verbose description
					from \s ([0-9.]+)/([0-9]+)	\s		# Source IP ($5), port ($6)
					to \s ([0-9.]+)/([0-9]+)	\s		# Destination IP ($7), port ($8)
					.*									# possible whitespace or junk
                $							# End of line :-)
              !$5 - - [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost'/udp/$8/ HTTP/1.0" 200 0 "http://$6/" "" 0 unknown!x' \
		| ${perl} -pwe \
            's! 				# Deny inbound (No xlate) (tcp|udp)
                ^							# Begin of line :-)
                    (\d+)\s(\w+)\s+(\w+)	\s+	# syslog year $1 month $2 day $3
					(?:\d{4}\s)?				# optional year when timestamp is switched on
                    ([0-9:]+)				\s+	# syslog time $4
                    (?:\[?[a-zA-Z0-9_.-]*\]?\s)?# optional syslog hostname
					(?:\w\w\w \s+ \d+ \s+ \d+ \s+ [0-9:]+ \s)? # optional PIX date/time in UTC
					.+.Deny.inbound.(?:.No.xlate..)?(udp|tcp) \s	# PIX ID (?); desc; protocol ($5)
					src \s ([a-zA-Z0-9&_.-]+):([0-9.]+)/([0-9]+)	\s	# Interface $6, Source IP $7, port $8
					dst \s ([a-zA-Z0-9&_.-]+):([0-9.]+)/([0-9]+)		# Interface $9, Dest IP $10, port $11
					.*									# possible whitespace or junk
                $							# End of line :-)
              !$7 - - [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost_1'/$5/$11/ HTTP/1.0" 200 0 "http://$8/" "" 0 $6-$9!xi' \
		| ${perl} -pwe \
            's! 				# Deny inbound (No xlate) icmp
                ^							# Begin of line :-)
                    (\d+)\s(\w+)\s+(\w+)	\s+	# syslog year $1 month $2 day $3
					(?:\d{4}\s)?				# optional year when timestamp is switched on
                    ([0-9:]+)				\s+	# syslog time $4
                    (?:\[?[a-zA-Z0-9_.-]*\]?\s)?# optional syslog hostname
					(?:\w\w\w \s+ \d+ \s+ \d+ \s+ [0-9:]+ \s)? # optional PIX date/time in UTC
					.+.Deny.inbound(?:..No.xlate.)?.icmp \s	# PIX ID (?); desc; protocol
					src \s ([a-zA-Z0-9&_.-]+):([0-9.]+)	\s	# Interface $5, Source IP $6
					dst \s ([a-zA-Z0-9&_.-]+):([0-9.]+)	\s	# Interface $7, Dest IP $8
					.type \s (\w+),.code .+		# ICMP type $9
                $							# End of line :-)
              !$6 - - [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost_2'/icmp/$9/ HTTP/1.0" 200 0 "http:///" "" 0 $5-$7!x' \
		| ${perl} -pwe \
            's! 				# Deny PROTOCOL src inside:... dst ... by access-group "ACL"
                ^							# Begin of line :-)
                    (\d+)\s(\w+)\s+(\w+)	\s+	# syslog year $1 month $2 day $3
					(?:\d{4}\s)?				# optional year when timestamp is switched on
                    ([0-9:]+)				\s+	# syslog time $4
                    (?:\[?[a-zA-Z0-9_.-]*\]?\s)?# optional syslog hostname
					(?:\w\w\w \s+ \d+ \s+ \d+ \s+ [0-9:]+ \s)? # optional PIX date/time in UTC
					.+.Deny.(udp|tcp|icmp)\s	# PIX ID (?); desc; protocol $5
					src \s ([a-zA-Z0-9&_.-]+):([0-9.]+)/?(\d*)\s	# Interface $6, Source IP $7, src port $8
					dst \s ([a-zA-Z0-9&_.-]+):([0-9.]+)/?(\d*)\s	# Interface $9, Dest IP $10, dest port $11
					(?:\(type.)?(\d*)(?:,.code.\d+\)\s)? # optional ICMP type $12
					(?:by.access-group.")?(\w*)"?.*	# ACL group $13
                $							# End of line :-)
              !$7 - $13 [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost_1'/$5/$11$12/ HTTP/1.0" 200 0 "http://$8/" "" 0 $6-$9!x' \
		| ${perl} -pwe \
            's! 				# translation creation failed for (tcp|udp)
                ^							# Begin of line :-)
                    (\d+)\s(\w+)\s+(\d+)	\s+	# syslog year $1 month $2 day $3
					(?:\d{4}\s)?				# optional year when timestamp is switched on
                    ([0-9:]+)				\s+	# syslog time $4
                    (?:\[?[a-zA-Z0-9_.-]*\]?\s)?# optional syslog hostname
					(?:\w\w\w \s+ \d+ \s+ \d+ \s+ [0-9:]+ \s)? # optional PIX date/time in UTC
					.+translation.creation.failed.for.(udp|tcp) \s	# PIX ID (?); desc; protocol ($5)
					src \s ([a-zA-Z0-9&_.-]+):([0-9.]+)/([0-9]+)	\s	# Interface $6, Source IP $7, port $8
					dst \s ([a-zA-Z0-9&_.-]+):([0-9.]+)/([0-9]+)		# Interface $9, Dest IP $10, port $11
					.*									# possible whitespace or junk
                $							# End of line :-)
              !$7 - - [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost_1'/$5/$11/ HTTP/1.0" 200 0 "http://$8/" "" 0 $6-$9!x' \
		| ${perl} -pwe \
            's! 				# translation creation failed for icmp
                ^							# Begin of line :-)
                    (\d+)\s(\w+)\s+(\w+)	\s+	# syslog year $1 month $2 day $3
					(?:\d{4}\s)?				# optional year when timestamp is switched on
                    ([0-9:]+)				\s+	# syslog time $4
                    (?:\[?[a-zA-Z0-9_.-]*\]?\s)?# optional syslog hostname
					(?:\w\w\w \s+ \d+ \s+ \d+ \s+ [0-9:]+ \s)? # optional PIX date/time in UTC
					.+translation.creation.failed.for.icmp \s	# PIX ID (?); desc; protocol
					src \s ([a-zA-Z0-9&_.-]+):([0-9.]+)	\s	# Interface $5, Source IP $6
					dst \s ([a-zA-Z0-9&_.-]+):([0-9.]+)	\s	# Interface $7, Dest IP $8
					.type \s (\w+),.code .+		# ICMP type $9
                $							# End of line :-)
              !$6 - - [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost_2'/icmp/$9/ HTTP/1.0" 200 0 "http:///" "" 0 $5-$7!x' \
		| ${perl} -pwe \
            's! 				# No translation group found for udp/tcp
                ^							# Begin of line :-)
                    (\d+)\s(\w+)\s+(\w+)	\s+	# syslog year $1 month $2 day $3
					(?:\d{4}\s)?				# optional year when timestamp is switched on
                    ([0-9:]+)				\s+	# syslog time $4
                    (?:\[?[a-zA-Z0-9_.-]*\]?\s)?# optional syslog hostname
					(?:\w\w\w \s+ \d+ \s+ \d+ \s+ [0-9:]+ \s)? # optional PIX date/time in UTC
					.+No.translation.group.found.for.(udp|tcp) \s	# PIX ID (?); desc; protocol ($5)
					src \s ([a-zA-Z0-9&_.-]+):([0-9.]+)/([0-9]+)	\s	# Interface $6, Source IP $7, port $8
					dst \s ([a-zA-Z0-9&_.-]+):([0-9.]+)/([0-9]+)		# Interface $9, Dest IP $10, port $11
					.*									# possible whitespace or junk
                $							# End of line :-)
              !$7 - - [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost_1'/$5/$11/ HTTP/1.0" 200 0 "http://$8/" "" 0 $6-$9!x' \
		| ${perl} -pwe \
            's! 				# No translation group found for icmp
                ^							# Begin of line :-)
                    (\d+)\s(\w+)\s+(\w+)	\s+	# syslog year $1 month $2 day $3
					(?:\d{4}\s)?				# optional year when timestamp is switched on
                    ([0-9:]+)				\s+	# syslog time $4
                    (?:\[?[a-zA-Z0-9_.-]*\]?\s)?# optional syslog hostname
					(?:\w\w\w \s+ \d+ \s+ \d+ \s+ [0-9:]+ \s)? # optional PIX date/time in UTC
					.+No.translation.group.found.for.icmp \s	# PIX ID (?); desc; protocol
					src \s ([a-zA-Z0-9&_.-]+):([0-9.]+)	\s	# Interface $5, Source IP $6
					dst \s ([a-zA-Z0-9&_.-]+):([0-9.]+)	\s	# Interface $7, Dest IP $8
					.type \s (\w+),.code .+		# ICMP type $9
                $							# End of line :-)
              !$6 - - [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost_2'/icmp/$9/ HTTP/1.0" 200 0 "http:///" "" 0 $5-$7!x' \
		| ${perl} -pwe \
            's! 				# list 101 denied tcp 64.70.54.95(20) -> 64.5.47.191(40436), 7 packets
                ^							# Begin of line :-)
                    (\d+)\s(\w+)\s+(\w+)	\s+	# syslog year $1 month $2 day $3
					(?:\d{4}\s)?				# optional year when timestamp is switched on
                    ([0-9:]+)				\s+	# syslog time $4
                    .+							# uninteresting data
					: \s list\s([^ ]+)\sdenied \s # rule number $5
					(\w+) \s					# protocol $6
					([0-9.]+)\(?(\d*)\)?\s(->)\s# Source IP $7, optional port $8; $9 just for compatibility with $reqhost_1
					([0-9.]+)\(?(\d*)\)?		# Dest IP $10, optional port $11
					, \s (\d+) \s packets?		# Packet count $12
                $							# End of line :-)
              !$7 - $5 [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost_1'/$6/$11/ HTTP/1.0" 200 $12 "http://$8/" "" 0 !x' \
		> $outdir/fwanalog.current.log

	# $outdir/fwanalog.current.log now contains the data in the Analog URL format.
}

pix ()
{
	# Alias for cisco()
	cisco
}

watchguard () 
{
	# Parse Watchguard Firebox logfiles into an analog-compatible "URL log"
	# Tested with System 6.1
	# Adapted from the pix() function

	wgpatterns=": deny (in|out) [a-z]+[0-9] [0-9]+ [a-z]+ [0-9]+ [0-9]+ ([0-9.]+ )+"
	${zegrep} -hi "$wgpatterns" $inputfiles \
		> $outdir/fwanalog.current

	mkdateconvscript
	# Create script to convert lines without year to fully specified date

	${sed} -f $outdir/convdate.sed $outdir/fwanalog.current \
		> $outdir/fwanalog.current.withyear
	# Use the script on the current logfile
	
	# Examples of converted log lines:
	#	2003 Jan  4 15:41:01 216.234.247.49 firewalld[110]: 
	#		deny in eth0 84 icmp 20 254 216.234.234.120 216.234.249.147 
	#		8 0 (blocked site) 
	#	2003 Jan  4 15:41:56 216.234.247.49 firewalld[110]: 
	#		deny in eth0 78 udp 20 128 10.11.12.120 10.11.12.255 
	#		137 137 (blocked site) 


	# Example of desired output:
	# 217....93 - blocked_site [5/Apr/2001:16:55:54 +0200] "GET /195.....201/tcp/1080 HTTP/1.0" 200 \
	#	20 "3819" "" 0 xl0
	#
	# Which means:
	# ip - reason [date] "GET Desthost/Protocol/Port" 200 PcktLen "http://Sourceport/" "Macadr" 0 interface
	# Sourceport is in the referrer field, interface in the VirtualHost.
	
	# Decide if the source or the destination host is included in the 
	# Blocked Packet Report (option "onehost" in fwanalog.opts)
	if [ $onehost = true ]; then
		reqhost="\$8"				# The analog "request" contains the source ip
	elif [ $onehost =  dynip ]; then
		reqhost="firewall"			# The analog "request" contains this string
	else
		reqhost="\$9"				# The analog "request" contains the destination ip
	fi


	# First, add an empty "reason" to lines that don't have it

	cat $outdir/fwanalog.current.withyear \
		| ${perl} -pwe 's/([a-z0-9] )$/$1() /i' \
		| ${perl} -pwe \
            's! 				# ICMP
                ^									# Begin of line
                    (\d+)\s+(\w+)\s+(\d+)	\s+		# syslog year $1 month $2 day $3
                    ([0-9:]+)				\s+		# syslog time $4
					[0-9a-zA-Z_.-]+\s[a-z]+\[\d+\]:\s # ip/hostname, process name, PID
					deny\s[a-z]+ \s ([a-z]+\d+) \s	# deny in/out, interface $5
					(\d+)\s(icmp) \s \d+\s\d+\s	# Packet length $6, protocol $7
					([0-9.]+) \s ([0-9.]+) \s		# Source, dest IP $8, $9
					([0-9]+) \s ([0-9]+) \s			# ICMP type $10
					[a-z ()]*						# sometimes TCP options
					\(([a-zA-Z0-9_. -]*)\) \s		# Reason $12
                $							# End of line
              !$8 - $12 [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost'/$7/$10/ HTTP/1.0" 200 $6 "" "" 0 $5!x' \
		| ${perl} -pwe \
            's! 				# IGMP
                ^									# Begin of line
                    (\d+)\s+(\w+)\s+(\d+)	\s+		# syslog year $1 month $2 day $3
                    ([0-9:]+)				\s+		# syslog time $4
					[0-9a-zA-Z_.-]+\s[a-z]+\[\d+\]:\s # ip/hostname, process name, PID
					deny\s[a-z]+ \s ([a-z]+\d+) \s	# deny in/out, interface $5
					(\d+)\s(igmp) \s \d+\s\d+\s	# Packet length $6, protocol $7
					([0-9.]+) \s ([0-9.]+) \s		# Source, dest IP $8, $9
					([^ ]*) \s* (.*)				# Some optional info $10
					\(([a-zA-Z0-9_. -]*)\) \s		# Reason $12
                $							# End of line
              !$8 - $12 [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost'/$7/$10/ HTTP/1.0" 200 $6 "" "" 0 $5!x' \
		| ${perl} -pwe \
            's! 				# TCP and UDP
                ^									# Begin of line
                    (\d+)\s+(\w+)\s+(\d+)	\s+		# syslog year $1 month $2 day $3
                    ([0-9:]+)				\s+		# syslog time $4
					[0-9a-zA-Z_.-]+\s[a-z]+\[\d+\]:\s # ip/hostname, process name, PID
					deny\s[a-z]+ \s ([a-z]+\d+) \s	# deny in/out, interface $5
					(\d+)\s([a-z]+) \s \d+\s\d+\s	# Packet length $6, protocol $7
					([0-9.]+) \s ([0-9.]+) \s		# Source, dest IP $8, $9
					([0-9]+) \s ([0-9]+) \s			# Source $10, destination port $11
					[a-z ()]*						# sometimes TCP options
					\(([a-zA-Z0-9_. -]*)\) \s		# Reason $12
                $							# End of line
              !$8 - $12 [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost'/$7/$11/ HTTP/1.0" 200 $6 "http://$10/" "" 0 $5!x' \
		| ${perl} -pwe \ 's!^([0-9.]+) - ([^ ]+) ([a-z0-9_. -]+) \[(\d+/.+)$!$1 - $2_$3 [$4!i' \
		| ${perl} -pwe \ 's!^([0-9.]+) - ([^ ]+) ([a-z0-9_. -]+) \[(\d+/.+)$!$1 - $2_$3 [$4!i' \
		| ${perl} -pwe \ 's!^([0-9.]+) - ([^ ]+) ([a-z0-9_. -]+) \[(\d+/.+)$!$1 - $2_$3 [$4!i' \
		> $outdir/fwanalog.current.log

	# The last 3 perl lines convert spaces to underscores in the reason field. Therefore,
	# only three spaces (or fewer) are allowed. Duplicate the lines if you need more.

	# $outdir/fwanalog.current.log now contains the data in the Analog URL format.
}

fw1 () 
{
	# Parse FireWall-1 export logfiles into an analog-compatible "URL log"

	$zegrep -h 'FireWall-1" "' $inputfiles \
		| $egrep -v '"Accept"' \
		> $outdir/fwanalog.current.withyear

	##mkdateconvscript
	# Create script to convert lines without year to fully specified date

	##$sed -f $outdir/convdate.sed $outdir/fwanalog.current > $outdir/fwanalog.current.withyear
	# Use the script on the current logfile

	# Example of converted log line:
	# "6" "28May2002" "9:47:09" "VPN-1 & FireWall-1" "E100B2" "ntz" "Log" "Drop" \
    # "Http-8080" "213.56.82.222" "213.56.82.223" "tcp" "14" "28122" "" ""
	#
	# Example of desired output:
	# 213.56.82.222 - RuleNr [28/May/2002:9:47:09 +0000] "GET /213.56.82.223/tcp/Http-8080 HTTP/1.0" 200 \
	#	0 "http://28122/" "14" 0 E100B2
	#
	# Which means:

	# ip - - [date] "GET Desthost/Protocol/Port" 200 PcktLen "http://Sourceport/" "rule" 0 interface
	# Sourceport is in the referrer field, rule in the user-agent, interface
	# in the VirtualHost.
	# There is no MAC address or packet length in FireWall-1 logs.
	
	# Decide if the source or the destination host is included in the 
	# Blocked Packet Report (option "onehost" in fwanalog.opts)
	if [ $onehost = true ]; then
		reqhost="\$12"		# The analog "request" contains the source ip
	elif [ $onehost = dynip ]; then
		reqhost="firewall"	# The analog "request" contains this string
	else
		reqhost="\$13"		# The analog "request" contains the destination ip
	fi

	$perl -pwe \
            's!
                ^							# Begin of line :-)
                    \"([0-9]+)\"				\s+	# "Number": ($1)
		    \"([0-9\s]+)([a-zA-Z]+)([0-9]+)\"		\s+	# "Date": day($2)
									#  month($3) year($4)
                    \"([0-9:]+)\"				\s+	# "Time": time($5)
                    \"([a-zA-Z0-9 &-]+)\"			\s+  	# "Product": ($6)
                    \"([a-zA-Z0-9-]+)\"				\s+  	# "Interface": ($7)
                    \"([a-zA-Z0-9-]+)\"				\s+  	# "Origin": ($8)
                    \"([a-zA-Z0-9]+)\"				\s+  	# "Type": ($9)
                    \"([a-zA-Z0-9]+)\"				\s+  	# "Action": ($10)
		    \"([a-zA-Z0-9_.\-]*)\"			\s+	# "Service": destination port($11) - may be name or number or null
		    \"([a-zA-Z0-9_.\-]*)\"			\s+	# "Source": ($12) - may be name or number or null
		    \"([a-zA-Z0-9_.\-]+)\"			\s+	# "Destination": ($13) - may be name or number
		    \"([a-zA-Z0-9]*)\"				\s+	# "Protocol": ($14) - may be name or number or null
                    \"([0-9]*)\"				\s+	# "Rule": ($15)
		    \"([a-zA-Z0-9_.\-]*)\"			\s+	# "Source port": ($16) - may be name or number or null
		    \"([a-zA-Z0-9]*)\"				\s+	# "User": ($17)  may be name or number or null
		    .+							# ignore the rest
                $							# End of line :-)
              !$12 - $15 [$2/$3/$4:$5 '$timezone'] \"GET /'$reqhost'/$14/$11/ HTTP/1.0" 200 0 "http://$16/" "$15" 0 $7!x' \
		$outdir/fwanalog.current.withyear > $outdir/fwanalog.current.log

	# $outdir/fwanalog.current.log now contains the data in the Analog URL format.
}

sonicwall ()
{
	# Parse SonicWall TZ-170 syslog logfiles into an analog-compatible
	# "URL log"

	$zegrep -h " connection dropped" $inputfiles \
		> $outdir/fwanalog.current

	mkdateconvscript
	# Create script to convert lines without year to fully specified date

	$sed -f $outdir/convdate.sed $outdir/fwanalog.current > $outdir/fwanalog.current.withyear
	# Use the script on the current logfile

	# Example of converted log line:
	# 2004 Dec  9 14:50:38 192.168.1.1 id=firewall sn=0123456789AB \
	# time="2004-12-09 15:07:38" fw=400.300.200.100 pri=5 c=64 m=36 \
	# msg="TCP connection dropped" n=38533 src=66.167.62.131:2930:WAN \
	# dst=400.300.200.100:135:WAN

	# Example of desired output:
	# 66.167.62.131 - - [9/Dec/2004:14:50:38 -0500] \
	# "GET /400.300.200.100/TCP/135 HTTP/1.0" 200 36 \
	# "http://2930/" "-" 0 WAN
	#
	# Which means:
	# ip - - [date] \
	# "GET Desthost/Protocol/Port HTTP/1.0" 200 PcktLen \
	# "http://Sourceport/" "Mac" 0 interface

	# Sourceport is in the referrer field, macadr in the user-agent,
	# interface in the VirtualHost.

	# Decide if the source or the destination host is included in the
	# Blocked Packet Report (option "onehost" in fwanalog.opts)
	if [ $onehost = true ]; then
		reqhost="\$7"				# The analog "request" contains the source ip
	elif [ $onehost = dynip ]; then
		reqhost="firewall"			# The analog "request" contains this string
	else
		reqhost="\$10"				# The analog "request" contains the destination ip
	fi
	
	$perl -pwe 's!^
	(\d+)          \s+  #    1 year
	(\w+)          \s+  #    2 month
	(\d+)          \s+  #    3 day
	([0-9:]+)      \s+  #    4 time
	[0-9.]+        \s+  # skip IP-address
	\w+=\w+        \s+  # skip id=firewall
	\w+=\w+        \s+  # skip sn=serial-number
	\w+=\"[0-9-]+  \s+  # skip time="yyyy-mm-dd
	  [0-9:]+\"    \s+  #        hh:mm:ss"
	\w+=[0-9.]+    \s+  # skip fw=IP-address
	\w+=\d+        \s+  # skip pri=num
	\w+=\d+        \s+  # skip c=num
	\w+=                # skip m=
	(\d+)          \s+  #    5 packet-length
	\w+=\"              # skip msg="
	(\w+)          \s+  #    6 protocol
	\w+\s+\w+\"    \s+  # skip connection dropped"
	\w+=\d+        \s+  # skip n=num
	\w+=                # skip src=
	([0-9.]+)\:         #    7 source-IP:
	(\d+)\:             #    8 source-port:
	(\w+)          \s+  #    9 source-interface
	\w+=                # skip dst=
	([0-9.]+)\:         #   10 dest-IP:
	(\d+)\:             #   11 dest-port:
	\w+                 # skip dest-interface
	.+                  # skip the-rest
	!$7 - - [$3/$2/$1:$4 '$timezone'] \"GET /'$reqhost'/$6/$11/ HTTP/1.0\" 200 $5 \"http://$8/\" \"-\" 0 $9!x' \
		$outdir/fwanalog.current.withyear > $outdir/fwanalog.current.log
 
	# $outdir/fwanalog.current.log now contains the data in the Analog URL format.
}

mkdateconvscript ()
{
	# Creates a sed script in the output dir which converts the firewall logs
	# (that don't have the year specified) to the real year (if your logs 
	# aren't too old)

	currmo=`$date +%m`
	curryear=`$date +%Y`
	lastyear=`echo $curryear | awk '{ print($1 - 1) }'`

	(
	if [ $currmo -ge 1 ]; then echo "s/^Jan/$curryear Jan/"; else echo "s/^Jan/$lastyear Jan/"; fi
	if [ $currmo -ge 2 ]; then echo "s/^Feb/$curryear Feb/"; else echo "s/^Feb/$lastyear Feb/"; fi
	if [ $currmo -ge 3 ]; then echo "s/^Mar/$curryear Mar/"; else echo "s/^Mar/$lastyear Mar/"; fi
	if [ $currmo -ge 4 ]; then echo "s/^Apr/$curryear Apr/"; else echo "s/^Apr/$lastyear Apr/"; fi
	if [ $currmo -ge 5 ]; then echo "s/^May/$curryear May/"; else echo "s/^May/$lastyear May/"; fi
	if [ $currmo -ge 6 ]; then echo "s/^Jun/$curryear Jun/"; else echo "s/^Jun/$lastyear Jun/"; fi
	if [ $currmo -ge 7 ]; then echo "s/^Jul/$curryear Jul/"; else echo "s/^Jul/$lastyear Jul/"; fi
	if [ $currmo -ge 8 ]; then echo "s/^Aug/$curryear Aug/"; else echo "s/^Aug/$lastyear Aug/"; fi
	if [ $currmo -ge 9 ]; then echo "s/^Sep/$curryear Sep/"; else echo "s/^Sep/$lastyear Sep/"; fi
	if [ $currmo -ge 10 ]; then echo "s/^Oct/$curryear Oct/"; else echo "s/^Oct/$lastyear Oct/"; fi
	if [ $currmo -ge 11 ]; then echo "s/^Nov/$curryear Nov/"; else echo "s/^Nov/$lastyear Nov/"; fi
	if [ $currmo -ge 12 ]; then echo "s/^Dec/$curryear Dec/"; else echo "s/^Dec/$lastyear Dec/"; fi
	) > $outdir/convdate.sed
}

mkmonthconvscript ()
{
	# Creates a sed script in the output dir which converts the firewall logs
	# (that have the month specified numerically) to the month's abbreviation (Jan...Dec)

	(
	echo "s!/01/!/Jan/!"
	echo "s!/02/!/Feb/!"
	echo "s!/03/!/Mar/!"
	echo "s!/04/!/Apr/!"
	echo "s!/05/!/May/!"
	echo "s!/06/!/Jun/!"
	echo "s!/07/!/Jul/!"
	echo "s!/08/!/Aug/!"
	echo "s!/09/!/Sep/!"
	echo "s!/10/!/Oct/!"
	echo "s!/11/!/Nov/!"
	echo "s!/12/!/Dec/!"
	) > $outdir/convdate.sed
}

rotate_cache ()
{
	# Greps all entries not from the current month from $outdir/fwanalog.all.log
	# to another file. This is good because if fwanalog.all.log is smaller, it 
	# can be diffed faster. However, this is entirely optional.

	echo "Note: rotating is not necessary anymore!"

	# change into the script's directory because the config file is here
	cd `dirname $0`
	
	# Load the user-settable options from the config file
	. `basename $0 | $sed 's/sh$/opts/'`
	
	# Month and year as they appear in the web server log
	grepdate=`$date +/%b/%Y:`
	# Name to indicate that this file is older
	newlogname=fwanalog.all.log.`$date +%Y-%m`

	$grep -vh $grepdate $outdir/fwanalog.all.log > $outdir/$newlogname
	echo "$grep -vh $grepdate $outdir/fwanalog.all.log > $outdir/$newlogname"
	$grep -h $grepdate $outdir/fwanalog.all.log > $outdir/fwanalog.all.log.current
	$echo "$grep -h $grepdate $outdir/fwanalog.all.log > $outdir/fwanalog.all.log.current"

	rm $outdir/fwanalog.all.log
	echo "rm $outdir/fwanalog.all.log"
	mv $outdir/fwanalog.all.log.current $outdir/fwanalog.all.log
	echo "mv $outdir/fwanalog.all.log.current $outdir/fwanalog.all.log"
}

clean_up ()
{

	#####	
	#	Function to remove temporary files and other housekeeping
	#	No arguments
	#####

    # Delete the lock file
    if [ -e $outdir/fwanalog.lock ]; then
        rm -f $outdir/fwanalog.lock
    fi
}


graceful_exit ()
{
	#####
	#	Function called for a graceful exit
	#	No arguments
	#####

	clean_up
	exit
}


error_exit () 
{
	#####	
	# 	Function for exit due to fatal program error
	# 	Accepts 1 argument
	#		string containing descriptive error message
	#####

	
	echo "${PROGNAME}: ${1:-"Unknown Error"}" >&2
	clean_up
	exit 1
}


term_exit ()
{
	#####
	#	Function to perform exit if termination signal is trapped
	#	No arguments
	#####

	echo "${PROGNAME}: Terminated"
	clean_up
	exit
}


int_exit ()
{
	#####
	#	Function to perform exit if interrupt signal is trapped
	#	No arguments
	#####

	echo "${PROGNAME}: Aborted by user"
	clean_up
	exit
}


usage ()
{
	#####
	#	Function to display usage message (does not exit)
	#	No arguments
	#####

	echo "Usage: ${PROGNAME} [-h | --help] [-c conffile] [-r] [-t] [-y] [-a IP-addr] [-p packet]"
}


helptext ()
{
	#####
	#	Function to display help message for program
	#	No arguments
	#####
	
	local tab=$(echo -en "\t\t")
		
	cat <<- -EOF-

	${PROGNAME} ver. ${VERSION}	
	This is a program to parse firewall logs and analyze them with Analog.
	
	$(usage)
	
	Options:
	
	-h, --help    Display this help message and exit.
	-c conffile   Use this config file instead of fwanalog.opts
	-r            Rotate log cache (not necessary anymore)
	-t            Only update statistics for today (e.g. for hourly use)
	                  The sep_hosts and sep_packets commands in fwanalog.opts
	                  are ignored.
	-y            The same as -t, only for yesterday
	-a IP-addr    Create a separate report for this host
	-p packet     Create a separate report for this packet 
	              Format: target/protocol/portnumber
				  e.g. 192.168.0.1/tcp/21 or firewall/udp/137
			
	NOTE: You must be the superuser to run this script, or have at least 
		  read rights to the firewall log. (See README.sudo for how to 
		  do this as a normal user.)
-EOF-
}	


###########################################################################
#	Program starts here
###########################################################################

# Trap TERM, HUP, and INT signals and properly exit

trap term_exit TERM HUP
trap int_exit INT

# Process command line arguments

if [ "$1" = "--help" ]; then
	helptext
	graceful_exit
fi

# Process arguments - edit to taste

while getopts ":hrtymc:a:p:" opt; do
	case $opt in
		r )	rotate_cache
			graceful_exit ;;

		h )	helptext
			graceful_exit ;;

		t )	today_only=true ;;

		y )	yesterday_only=true ;;

		m ) reportmagic=true ;;

		a ) host_to_report="$OPTARG" ;;

		p ) packet_to_report="$OPTARG" ;;

		c ) configfile="$OPTARG" ;;

		* )	usage
			exit 1
	esac
done

# No arguments - normal case
if [ $OPTIND -gt $# ]; then
	(main)
fi

graceful_exit
