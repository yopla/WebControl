#!/bin/sh
# ipfw startup script by hany@hanynet.com v1.1
# this script is included in WaterRoof v3.6 application bundle and should be installed in /etc.
# please chmod +x this script if you put/replace it manually!!


# We need to trap on TERM signals, according to Apple's launchd docs:
#
trap 'exit 1' 15

#
# Issue a log message so we know when we started
#
syslog -s -l 1 waterroof.sh: Starting WaterRoof boot script...

#
# Use the "ipconfig waitall" command to wait for all the
# interfaces to come up:
#
ipconfig waitall
		  # enable firewall
		  sysctl -w net.inet.ip.fw.enable=1
          # set up ipv4 firewall rules
          ipfw /etc/firewallrules
		  # set up ipv6 firewall rules
		  ip6fw /etc/firewallrules_v6
		  # firewall logging (default is 2,0)
		  sysctl -w net.inet6.ip6.fw.verbose=0
		  sysctl -w net.inet.ip.fw.verbose=0
		  sysctl -w net.inet.ip.fw.verbose_limit=0
		  # start 10.4 logging
		  #/usr/libexec/ipfwloggerd
		  # start 10.5 logging 
		  #/usr/libexec/ApplicationFirewall/appfwloggerd
		  # start 10.6 logging
		  #touch /var/run/socketfilterfw.launchd
		  #/usr/libexec/ApplicationFirewall/socketfilterfw
		  # interface forwarding
		  sysctl -w net.inet.ip.forwarding=0
		  # NAT - Network Address Translation
		  #/usr/sbin/natd -f /etc/nat.conf

# Sleep 
sleep 10

# log message 
syslog -s -l 1 waterroof.sh: Waterroof script ended.

# Exit with a clean status
exit 0
