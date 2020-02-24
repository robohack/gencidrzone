#!/usr/bin/env perl
#
#ident	"@(#)gencidrzone:$Id: gencidrzone.pl,v 1.4 2020/02/24 00:18:33 woods Exp $"

#	(C)Copyright 1996 Mathias Koerber <mathias@singnet.com.sg>
#	(C)Copyright 1996-2020 Greg A. Woods <woods@robohack.ca>
#	Free to use for all
#	No warranties, claims etc ...

# usage:
#
#	gencidrzone <block in prefix/length notation>
#
# Note that the prefix must include all 4 bytes... (i.e.  "A.B/16"
# does not work here).
#
# The output will be two files:
#
#	a) a file called <a.b.c.d-bits.inc>
#
#	This file contains the delegation to the subdomain for the customer's
#	block and the CNAMES...  It should be $INCLUDE'd in the reverse file for
#	the /24.
#
#	b) a template for the customer's delegated subdomain called
#	   <a.b.c.d-bits.db>
#

#
# The a.b.c master zonefile should look like this:
#
#	$TTL 4h		; defines the default TTL for all records listed in this file
#
#	;$ORIGIN c.b.a.IN-ADDR-ARPA.
#	@	IN	SOA	<providor-primary-ns>. hostmaster.<providor.domain>.	(
#				2012010201	; Serial number (yyymmddhh)
#				4h		; Refresh interval
#				2h		; Refresh retry interval
#				1w		; Expire time
#				4h )		; negative response TTL
#
#		IN	NS	<providor-primary-ns>.
#		IN	NS	<providor-secondary-ns>.
#
#	; optionally if this whole zone is a delegated network with a NETNAME
#	;0	IN	PTR	<NETNAME>.<providor.domain>.	; RFC 1101 Network Name
#	;	IN	A	255.255.255.0			; RFC 1101 netmask
#
#	$INCLUDE a.b.c.d0-bits.inc
#	; ...
#	$INCLUDE a.b.c.dN-bits.inc
#
#	; optionally if this whole zone is a delegated network with a NETNAME
#	;255	IN	PTR	<NETNAME>-bcast.<providor.domain>. ; RFC 1101 broadcast


# This version follows RFC 2317 more closely, with additions for RFC 1101.

# Originally posted to bind-users as follows:
#
# In-Reply-To: <9603120329.AA28115@dmssyd.syd.dms.CSIRO.AU>
# Message-Id: <Pine.OSF.3.91.960313133244.3522R-100000@singapura.singnet.com.sg>
# From: Mathias Koerber <mathias@singnet.com.sg>
# Reply-To: Mathias Koerber <mathias@singnet.com.sg>
# Sender: <bind-users-request@vix.com>
# To: Mark Andrews <Mark.Andrews@dms.csiro.au>
# Cc: Jorge Miguel Ferreira Alves <Jorge.Alves@co.ip.pt>, bind-users@vix.com
# Date: Wed, 13 Mar 1996 13:39:49 +0800 (SST)
# Subject: Re: Reverse Tool?
#
# I have hacked an (admittedly icky) tool that generates the files
# for this.  One include file to be included in the parent domain,
# and one template to be given to the sibdomain's owner..
# ...
# This script is still very new and might not work for all cases (like I
# tested them all, right).  So caveat usor:  If you use it, you take all
# the responsibility...
#
# here it is, enjoy
#

# A slightly different version was distrbuted in bind8/contrib/misc/gencidrzone

require "newgetopt.pl";

# some defaults
$opt_primary		= "<your_primary_nameserver>"; # customer's NS
$opt_contact		= "<your_contact_address>";    # customer hostmaster email
@opt_secondary_def	= ("<your_secondary_nameserver>"); # customer's NS2

if ((NGetOpt(
	 "primary=s",
	 "contact=s",
	 "secondary=s@",
     ) == 0) || ($#ARGV != 0)) {
	print STDERR <<"EOF";
usage $0 [options] <addressblock>

where: 	<addressblock> is the subnet in CIDR dotted-quad prefix/length notation
options include:
	-primary <name>		name of the customer's primary nameserver
	-secondary <name>	customer's secondary NS (may be repeated)
	-contact <email_addr>	customer's SOA contact address
defaults: placeholder strings for these..
EOF

	exit 2;
}

@opt_secondary = @opt_secondary_def if (!@opt_secondary);
#perform some courtesy translations
$opt_contact =~ tr/\@/./;
# and some sanity ones
chop($opt_primary) if ($opt_primary =~ /\.$/);
chop($opt_contact) if ($opt_contact =~ /\.$/);
for $i (0 .. $#opt_secondary) {
	chop($opt_secondary[$i]) if ($opt_secondary[$i] =~ /\.$/);
}

($ip, $bits) = split('/', $ARGV[0]);
($a, $b, $c, $d) = split(/\./, $ip);

if ($bits <= 24) {
	print STDERR "gencidrzone only makes sense for prefixes > 24bits\n";
	exit 2;
}

$add1 = (($a * (256**3)) + ($b * (256**2)) + ($c * (256**1)) + $d);

$mb = (2**32) - (2**(32 - $bits));

$mb2 = 2**(32 - $bits) - 1;

($na, $nb, $nc, $nd) = &unp(~(2**(32 - $bits) - 1));

($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst, $zone, $gmtoff) = localtime();
$year += ($year < 70) ? 2000 : 1900;

# yyyymmddhh
$serial = sprintf("%-4.4d%-2.2d%-2.2d00", $year, ($mon + 1), $mday);

$add2 = ($add1 & $mb);
$add3 = ($add2 | $mb2);

($fa, $fb, $fc, $fd) = &unp($add2);
($la, $lb, $lc, $ld) = &unp($add3);

$fdg = $fd + 1;			# gateway
$fdh = $fd + 2;			# first host
$ldh = $ld - 1;			# last host

open(SUB, ">$fa.$b.$fc.$fd-$bits.db");
open(INC, ">$fa.$b.$fc.$fd-$bits.inc");

print SUB <<"EOF_SUB";
;
; Classless IN-ADDR.ARPA delegation (CIDR) reverse delegation zone.
;
; Your site has been allocated the address range $fa.$fb.$fc.$fd/$bits
; (the addresses from $fa.$fb.$fc.$fd to $la.$lb.$lc.$ld).
;
; Since this range (/$bits) is smaller than a classical Class C (/24), you
; cannot be given authority over the full $fc.$fb.$fa.in-addr.arpa reverse
; domain (you are sharing it with other networks).
;
; For this reason we are only allocating you a subdomain of the above reverse
; domain and delegating it alon to your nameservers.  This subdomain is called:
;
; 	$fd/$bits.$fc.$fb.$fa.in-addr.arpa.
;
; To set up a primary nameserver running BIND for this domain, you will need
; to add the following line to your nameserver's named.boot file, where
; <zonefile> will have to be replaced with the path/filename where you store
; this zone file:
;
; 	primary	$fd/$bits.$fc.$fb.$fa.in-addr.arpa <this-zonefile>
;
; For a primary nameserver running NSD you would add a "zone:" section as
; follows to your nsd.conf file:
;
;	zone:
;		name: "$fd/$bits.$fc.$fb.$fa.in-addr.arpa"
;		zonefile: <this-zonefile>
;		provide-xfr: 0.0.0.0/0 NOKEY
;		# secondary #1
;		notify: N.N.N.N NOKEY
;		outgoing-interface: M.M.M.M
;
; Please remember to make all other necessary changes below, i.e. replace the
; references to <your_primary_nameserver> and <your_contact_address> with the
; real values, and edit the PTR records as indicated below.
;
; Please note that you cannot use the traditional IN-ADDR.ARPA zone entries
; giving the full reverse domainname on the LHS since you will have been
; delegated a specially named subdomain.  We advise you to use the pre-listed
; records below as-is, only specifying the last octet in the host address in
; the first field.
;
; Please do *not* uncomment or change the \$ORIGIN given below.
;
; Please note that you can only list addresses from:
;
; 	$fdh to $ldh
;
; in this file, and that the first and last addresses in your allocated subnet
; cannot be used for hosts (they are reserved for the network and broadcast
; address respectively); and the second address is your default gateway router
; address.
;
; We have (or will shortly) set up CNAME translations from:
;
;	    XX.$fc.$fb.$fa.in-addr.arpa.
;
; to:
;
;	XX.$fd/$bits.$fc.$fb.$fa.in-addr.arpa.
;
; For more information on this delegation scheme, please see RFC 2317.
;
; NOTE:  please enter your primary and secondary servers and contact
; address below:
;
; 	(don't forget the trailing '.')
;       Replace the '\@' in the contact address with '.' !!!
;
; CAVEAT ADMINISTRATOR:  *never* use '#' as the comment character in files
; used by the nameserver (named.boot, zonefiles, etc).  The correct comment
; character is the semicolon (';').
;
; IMPORTANT:  DO NOT FORGET TO UPDATE THE SERIAL NUMBER EACH TIME YOU CHANGE
;		THIS FILE !!!
;
; The following \$ORIGIN will be specified by virtue of your correct
; entry in the named.boot (BIND) or nsd.conf (NSD) file specified above:
;
;\$ORIGIN $fd/$bits.$fc.$fb.$fa.in-addr.arpa.
\$TTL 4h		; defines the default TTL for all records in this file
\@	IN	SOA	$opt_primary. $opt_contact. (
				$serial	; Serial number (yyyymmddhh)
				4h		; Refresh interval
				2h		; Refresh retry interval
				1w		; Expire time
				4h )		; negative response TTL
	IN	NS	$opt_primary.
EOF_SUB

for $i (@opt_secondary) {
	print SUB "\tIN\tNS\t$i.\n";
}

print SUB <<"EOF_SUB";
;
; NOTE:  You cannot use the first ($fa.$fb.$fc.$fd = network address)
; or last ($la.$lb.$lc.$ld = broadcast) address for hosts (PTR), and the
; second address ($fa.$fb.$fc.$fdg) is your default gateway's address.
;
; The individual PTR records below are still commented out.
; fill in the correct hostnames and remove the leading ';'.
;
; We advise that you only uncomment the PTR records that you really use.
;
EOF_SUB

print INC <<"EOF_INC";
;
; delegation for $fa.$fb.$fc.$fd/$bits
; 	(addresses from $fa.$fb.$fc.$fd to $la.$lb.$lc.$ld)
;
; this file should be included, with "\$INCLUDE", in the master
; "$fc.$fb.$fa.in-addr.arpa" zonefile
;
$fd/$bits	IN	NS	$opt_primary.
EOF_INC

for $i (@opt_secondary) {
	print INC "\tIN\tNS\t$i.\n";
}

print INC <<"EOF_INC";
;
; RFC 1101 network name and subnet mask
;
; Note that $fa.$fb.$fc.$fd is the subnet's network address, and
; $la.$lb.$lc.$ld is the broadcast address.  Neither can be used as
; host addresses, so their PTRs should point to names that represent
; the customter's network name.  So, the following hostnames should
; be created in your top domain or a "subnets" domain, e.g. as:
;
;	<customer-netname>		IN	A	$fa.$fb.$fc.$fd
;	<customer-gateway>		IN	A	$fa.$fb.$fc.$fdg
;	<customer-netname>-bcast	IN	A	$fa.$fb.$fc.$ld
;
$fd	IN	PTR	<customer-netname>.<providor.domain>.
	IN	A	$na.$nb.$nc.$nd
	IN	UINFO	"Subnet Net and Netmask for $fa.$fb.$fc.$fd/$bits"
;
$fdg	IN	PTR	<customer-gateway>.<providor.domain>.
;
EOF_INC

# here we print both the example PTR and the delegation CNAME
#
for $dd (($fdh) .. ($ldh)) {
	print SUB ";$dd	IN	PTR	<some_FQ_hostname_for.$dd>.\n";
	print INC "$dd	IN	CNAME	$dd.$fd/$bits\n";
}

#print SUB "\n; this is the sub-net's broadcast address, as per RFC 1110, and strictly\n";
#print SUB "; speaking should not be used for a host address:\n;\n";
#print SUB "$ld	IN	PTR	<your-netname>-bcast.<your.domain>.\n";

print INC ";\n$ld	IN	PTR	<customer-netname>-bcast.<providor.domain>\n";

#print INC "\n; this points to the sub-net's broadcast address, as per RFC 1101:\n;\n";
#print INC "$ld	IN	CNAME	$ld.$fd/$bits\n";

close(SUB);
close(INC);

sub unp {
	local($o) = @_[0];
	local($r);
	local($a, $b, $c, $d);

	$d = $o & 0x000000ff;
        $o >>= 8;
	$c = $o & 0x000000ff;
        $o >>= 8;
	$b = $o & 0x000000ff;
        $o >>= 8;
	$a = $o & 0x000000ff;

	return($a, $b, $c, $d);
}
