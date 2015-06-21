#! /bin/sh

cat fwanalog.opts.master \
	| sed 's!@logformat@!iptables!' \
	| sed 's!@inputfiles_mask@!messages*!' \
	| sed 's!@inputfiles_dir@!/var/log!' \
	> fwanalog.opts.linux24

cat fwanalog.opts.master \
	| sed 's!@logformat@!ipchains!' \
	| sed 's!@inputfiles_mask@!messages*!' \
	| sed 's!@inputfiles_dir@!/var/log!' \
	> fwanalog.opts.linux22

cat fwanalog.opts.master \
	| sed 's!@logformat@!freebsd!' \
	| sed 's!@inputfiles_mask@!ipflog*!' \
	| sed 's!@inputfiles_dir@!/var/log!' \
	> fwanalog.opts.freebsd

cat fwanalog.opts.master \
	| sed 's!@logformat@!ipfw!' \
	| sed 's!@inputfiles_mask@!ipflog*!' \
	| sed 's!@inputfiles_dir@!/var/log!' \
	> fwanalog.opts.ipfw

cat fwanalog.opts.master \
	| sed 's!@logformat@!openbsd!' \
	| sed 's!@inputfiles_mask@!ipflog*!' \
	| sed 's!@inputfiles_dir@!/var/log!' \
	> fwanalog.opts.openbsd

cat fwanalog.opts.master \
	| sed 's!@logformat@!pf_30!' \
	| sed 's!@inputfiles_mask@!pflog*!' \
	| sed 's!@inputfiles_dir@!/var/log!' \
	> fwanalog.opts.openbsd3

cat fwanalog.opts.master \
	| sed 's!@logformat@!solarisipf!' \
	| sed 's!@inputfiles_mask@!syslog.local0*!' \
	| sed 's!@inputfiles_dir@!/var/log!' \
	> fwanalog.opts.solarisipf

cat fwanalog.opts.master \
	| sed 's!@logformat@!zynos!' \
	| sed 's!@inputfiles_mask@!router*!' \
	| sed 's!@inputfiles_dir@!/var/log!' \
	> fwanalog.opts.zynos

cat fwanalog.opts.master \
	| sed 's!@logformat@!pix!' \
	| sed 's!@inputfiles_mask@!firewall*!' \
	| sed 's!@inputfiles_dir@!/var/log!' \
	> fwanalog.opts.pix

cat fwanalog.opts.master \
	| sed 's!@logformat@!watchguard!' \
	| sed 's!@inputfiles_mask@!firewall*!' \
	| sed 's!@inputfiles_dir@!/var/log!' \
	> fwanalog.opts.watchguard

cat fwanalog.opts.master \
	| sed 's!@logformat@!fw1!' \
	| sed 's!@inputfiles_mask@!firewall*!' \
	| sed 's!@inputfiles_dir@!/var/log!' \
	> fwanalog.opts.fw1

cat fwanalog.opts.master \
	| sed 's!@logformat@!sonicwall!' \
	| sed 's!@inputfiles_mask@!firewall*!' \
	| sed 's!@inputfiles_dir@!/var/log!' \
	> fwanalog.opts.sonicwall

