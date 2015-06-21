#! /bin/sh

# Shell script to convert an Analog language file to a fwAnalog one.
# Usage: mklangfile.us.sh {infile} [> outfile]
# $Id: mklangfile.us.sh,v 1.4 2002/05/11 19:05:06 bb Exp $

cat $1 \
	| sed 's/request/blocked packet/g' \
	| sed 's/virtual host/interface/g' \
	| sed 's/directory/blocked packet/g' \
	| sed 's/directories/blocked packets/g' \
	| sed 's/^URL/source port/g' \
	| sed 's/Web Server Statistics for/Block statistics of your firewall, created by/g' \
	| sed 's/Busiest month:/Month with the most blocked packets:/g' \
	| sed 's/Busiest week:/Week with the most blocked packets:/g' \
	| sed 's/Busiest day:/Day with the most blocked packets:/g' \
	| sed 's/Busiest hour:/Hour with the most blocked packets:/g' \
	| sed 's/Busiest quarter of an hour:/Quarter-hour with the most blocked packets:/g' \
	| sed 's/Busiest five minutes:/Five minutes with the most blocked packets:/g' \
	| sed 's/Virtual Host/Interface/g' \
	| sed 's/virtual host/interface/g' \
	| sed 's/Host Report/Packet Source Host Report/g' \
	| sed 's/Directory Report/Blocked Packet Report/g' \
	| sed 's/Referrer Report/Source Port Report/g' \
	| sed 's/referring URL/source port/g' \
	| sed 's/File/Packet/g' \
	| sed 's/Browsers/MAC Addresses/g' \
	| sed 's/browsers/MAC addresses/g' \
	| sed 's/Browser/MAC Address/g' \
	| sed 's/browser/MAC address/g' \
	| sed 's/Successful/Blocked/g' \
	| sed 's/successful/blocked/g' \
	| sed 's/Distinct hosts served/Distinct hosts blocked/g' \
	| sed 's/Unwanted logfile entries/Unwanted logfile entries (because of a date range, EXCLUDE etc.)/g' \
	| sed 's/Data transferred/Size of all dropped packets together/g' \
	| sed 's/Average data transferred per day/Average size of dropped packets per day/g' \
	| sed 's/#reqs/#blocks/g' \
	| sed 's/%reqs/%blocks/g' \
	| sed 's/Blocked blocked/Blocked/g' \
	| sed 's/blocked blocked/blocked/g' \
	| sed 's/User/Log Prefix/g' \
	| sed 's/users/log prefixes/g' \
	| sed 's/user/log prefix/g' \
	| sed 's!^files!ports/ICMP types!g' \
	| sed 's!^file!port/ICMP type!g' \
	| sed 's!Request Report!Port/ICMP Type Report!g' \
	| sed 's/Distinct files blocked packeted/Distinct blocked packets/g' \
	| perl -pwe "s!^## This is a language file for analog!## Converted from $1 on `date` \\n## by mklangfile.us.sh (from the fwanalog distribution)\\n## More info: http://tud.at/programm/fwanalog/\\n##\\n## This is a language file for analog!" 
