#! /bin/sh

# Creates a services.conf file for fwanalog from your /etc/services 
# or another file you specify
#
# $Id: mkservices.conf.sh,v 1.5 2002/04/28 13:36:15 bb Exp $

#services="/etc/services"
#services="/usr/share/nmap/nmap-services"
services="$1"

egrep '^[a-zA-Z0-9_:.-]+' $services \
	| perl -pwe 's!^([a-zA-Z0-9_.:*-]+)[ \t]+([0-9]+)/([a-zA-Z]+).*$!FILEALIAS REGEXPI:^/(.+)/$3/$2/\$ "/\$1/$3/$1 ($2)/"!' \
	| perl -pwe 's!\*!-!g' \
	> services.conf
