#! /local/bin/perl
#
#ident	"@(#)gencidrzone:$Id: gencidrzone.pl,v 1.2 1996/03/19 00:40:00 woods Exp $"

# TODO:
#
#	- make this thing generate *all* relavant files for a given subnetting.

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
#
# usage:
#
#	gencidrzone <block in prefix/length notation>
#
# Note that the prefix must include all 4 bytes... (i.e.  "A.B/16"
# does not work here).
#
# The output will be two files:
#
#	a) a file called <a.b.c.inc.d>.
#
#	This file contains the delegation to the subdomain for the customer's
#	block and the CNAMES...  It should be $INCLUDE'd in the reverse file for
#	the /24.
#
#	b) a template for the customer's subdomain.
#
# This script is still very new and might not work for all cases (like I
# tested them all, right).  So caveat usor:  If you use it, you take all
# the responsibility...
#
# here it is, enjoy
#

($ip, $bits) = split('/', $ARGV[0]);
($a, $b, $c, $d) = split(/\./, $ip);

# $add1 = pack("CCCC", $a, $b, $c, $d);
$add1 = (($a * (256**3)) + ($b * (256**2)) + ($c * (256**1)) + $d);

# $ms = ("1" x $bits) . ("0" x (32 - $bits));
# $mb = pack("B*", $ms);
$mb = (2**32) - (2**(32 - $bits));

# $ms2 = ("0" x $bits) . ("1" x (32 - $bits));
# $mb2 = pack("B*", $ms2);
$mb2 = 2**(32 - $bits) - 1;

($na, $nb, $nc, $nd) = &unp(~(2**(32 - $bits) - 1));

($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst, $zone, $gmtoff) = localtime();
$year += ($year < 70) ? 2000 : 1900;

$serial = sprintf("%-4.4d%-2.2d%-2.2d00", $year, ($mon + 1), $mday);

$add2 = ($add1 & $mb);
$add3 = ($add2 | $mb2);

($fa, $fb, $fc, $fd) = &unp($add2);
($la, $lb, $lc, $ld) = &unp($add3);

$fdh = $fd + 1;
$ldh = $ld - 1;

open(SUB, ">$fd.$fc.$fb.$fa.db");
open(INC, ">$fc.$b.$fa.inc.$fd");

print SUB <<"EOF_SUB";
;
; CIDRD reverse delegation
;	for $ARGV[0]
;	(addresses from $fa.$fb.$fc.$fd to $la.$lb.$lc.$ld)
;
; This is the reverse zone file for the sub-zone $fd.$fc.$fb.$fa.in-addr.arpa
;
; Your site has been allocated the address range $ARGV[0]:
; (addresses from $fa.$fb.$fc.$fd to $la.$lb.$lc.$ld)
;
; Since this range is smaller than a classical Class C (/24), you
; cannot be given authority over the full $fc.$fb.$fa.in-addr.arpa
; reverse domain (you are sharing it with other networks).
;
; For this reason we are only allocating you a subdomain of the above
; reverse domain.  This subdomain is called:
;
; 	$fd.$fc.$fb.$fa.in-addr.arpa.
;
; To set up a primary nameserver for this (reverse) domain, you will need
; to add a line:
;
; 	primary	$fd.$fc.$fb.$fa.in-addr.arpa <zonefile>
;
; into your nameserver's named.boot file, where <zonefile> will have
; to be replaced with the path/filename of where you store this zone
; file.
;
; You may use this file you are currently reading as the zonefile for
; your reverse domain.  Please remember to make the necessary changes,
; i.e. replace the references to <your_primary_nameserver> and
; <your_contact_address> with the real data, and edit the PTR records
; as indicated below.
;
; In it you can register the PTR records for your domain.  Please note
; that you cannot use the traditional IN-ADDR.ARPA zone entries with
; the:
;
; 	XX.$fc.$fb.$fa.in-addr.arpa.	IN PTR	<somehostname>
;
; notation (giving the full reverse domainname on the LHS), since you
; will have to use the delegated subdomain.  We advise you to use the
; pre-listed records below, only specifying the last octet in the host
; address.  Please do *not* change the \$ORIGIN.
;
; Please note that you can only list addresses from:
;
; 	$fdh to $ldh
;
; in this file, and that the first and last addresses in your
; allocated block cannot be used for hosts (they are reserved for the
; network and broadcast address respectively).
;
; We have (or will shortly) set up CNAME translations from:
;
;	    XX.$fc.$fb.$fa.in-addr.arpa
;
; to:
;
;	XX.$fd.$fc.$fb.$fa.in-addr.arpa
;
; For more information on this allocation scheme, please see:
;
; ftp://ftp.internic.net/internet-drafts/draft-degroot-classless-inaddr-00.txt
;
; NOTE:  please enter your primary and secondary servers and contact
; address below:
;
; 	(don't forget the trailing '.')
;       Replace the '\@' in the contact address with '.' !!!
;
; CAVEAT ADMINISTRATOR: *never* use '#' as the comment character in files
; used by the nameserver (named.boot, zonefiles, etc).  The correct comment
; character is the semicolon (';').  Named might not work if you use '#' !!!!
;
; IMPORTANT:  DO NOT FORGET TO UPDATE THE SERIAL NUMBER EACH TIME YOU CHANGE
;		THIS FILE !!!
;
; The following \$ORIGIN will be specified by virtue of your correct
; entry of the named.boot line specified above:
;
;\$ORIGIN $fd.$fc.$fb.$fa.in-addr.arpa.
\@	IN	SOA	<your_primary_nameserver>. <your_contact_address>. (
				$serial	; Serial
				10800		; Refresh, 3 hours
				7200		; Retry, 2 hours
				604800		; Expire, 1 week
				10800 )		; Default TTL, 3 hours
	IN	NS	<your_primary_nameserver>.
	IN	NS	<your_secondary_nameserver>.
;
; NOTE:  You cannot use the first ($fa.$fb.$fc.$fd = network address)
; and last ($la.$lb.$lc.$ld = broadcast) address for hosts (PTR).
;
; The individual PTR records below are still commented out.
; fill in the correct hostnames and remove the leading ';'.
;
; We advise that you only uncomment the PTR records that you really need.
;
EOF_SUB

print INC <<"EOF_INC";
;
; delegation for $ARGV[0]
; 	(addresses from $fa.$fb.$fc.$fd to $la.$lb.$lc.$ld)
;
; this file should be "include'd" in the $fc.$fb.$fa.in-addr.arpa zonefile
;
$fd	IN	NS	<customer_ns1>.
	IN	NS	<customer_ns2>.
	IN	PTR	<customer-netname>.<providor.domain>.
	IN	A	$na.$nb.$nc.$nd
	IN	UINFO	"Sub-net Netmask"

EOF_INC

for $dd (($fdh) .. ($ldh)) {
	print SUB ";$dd	IN	PTR	<some_hostname_$dd>.\n";
	print INC "$dd	IN	CNAME	$dd.$fd.$fc.$fb.$fa.in-addr.arpa.\n";
}

print SUB "\n; this is the sub-net's broadcast address, and strictly speaking should\n";
print SUB "; not be used for a host address:\n;\n";
print SUB "$ld	IN	PTR	<your-netname>-bcast.<your-domain>.\n";

print INC "\n; this is the sub-net's broadcast address, and strictly speaking should\n";
print INC "; not be used for a host address:\n;\n";
print INC "$ld	IN	CNAME	$ld.$fd.$fc.$fb.$fa.in-addr.arpa.\n";

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
