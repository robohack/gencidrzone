#!/usr/bin/perl
#

($ip,$bits) = split('/',$ARGV[0]);
($a,$b,$c,$d) = split(/\./,$ip);

# $add1 = pack("CCCC",$a,$b,$c,$d);
$add1 = (($a * (256**3)) + ($b * (256**2)) + ($c * (256**1)) + $d);
# $ms = ("1" x $bits) . ("0" x (32 - $bits));
# $mb = pack("B*",$ms);
$mb = (2**32)-(2**(32-$bits));
# $ms2 = ("0" x $bits) . ("1" x (32 - $bits));
# $mb2 = pack("B*", $ms2);
$mb2 = 2**(32-$bits)-1;

($secs,$min,$hour,$mday,$mon,$year) = localtime();
$serial = sprintf("%-2.2d%-2.2d%-2.2d01",$year,($mon+1),$mday);

$add2 = ($add1 & $mb);
$add3 = ($add2 | $mb2);

($fa,$fb,$fc,$fd) = &unp($add2);
($la,$lb,$lc,$ld) = &unp($add3);

open(SUB,">$fd.$fc.$fb.$fa.db");
open(INC,">$fc.$b.$fa.inc.$fd");

print SUB <<"EOF";
;
;	CIDRD reverse delegation
;		for $ARGV[0]
;		(addresses from $fa.$fb.$fc.$fd to $la.$lb.$lc.$ld)
;
;	This is the reverse zone file for the sub-zone $fd.$fc.$fb.$fa.in-addr.arpa
;
;	Your site has been allocated the address range $ARGV[0]
;		(addresses from $fa.$fb.$fc.$fd to $la.$lb.$lc.$ld)
;
;	Since this range is smaller than a classical Class C (/24), you cannot
;	be given authority over the full $fc.$fb.$fa.in-addr.arpa reverse domain
;	(you are sharing it with other networks).
;
;	For this reason we are only allocating you a subdomain of the above
;	reverse domain. This subdomain is called 
;		$fd.$fc.$fb.$fa.in-addr.arpa.
;
;	To set up a primary nameserver for this (reverse) domain, you will need
;	to add a line
;
;		primary	$fd.$fc.$fb.$fa.in-addr.arpa <zonefile>
;
;	into your nameserver's named.boot file, where <zonefile> will have to be
;	replaced with the path/filename of your zonefile.
;
;	You may use this file you are currently reading as the zonefile for your
;	reverse domain. Pls remember to make the necessary changes, ie
;	replace the references to <your_primary_nameserver> and <your_contact_address>
;	with the real data, and edit the PTR records as indicated below..
;
;	In it you can register the PTR records for your domain. Pls note that
;	you cannot use the traditional
;		XX.$fc.$fb.$fa.in-addr.arpa.	IN PTR	<somehostname>
;	notation (giving the full reverse domainname on the LHS), since you will have 
;	to use 	the  delegated subdomain. We advise you to use the pre-listed
;	records below, only giving the last octet in the host address. Please do 
;	*not* change the \$ORIGIN.
;
;	Pls note that you can only list addresses from
;		$fd to $ld
;	in this file, and that the first and last addresses in your allocated
;	block cannot be used for hosts (they are reserved for the network
;	and broadcast address respectively).
;
;	We have (or will shortly) set up CNAME translations from the
;		    XX.$fc.$fb.$fa.in-addr.arpa names to the
;		XX.$fd.$fc.$fb.$fa.in-addr.arpa names.
;
;	For more information on this allocation scheme, pls see
;	ftp://ftp.internic.net/internet-drafts/draft-degroot-classless-inaddr-00.txt
;	
;	NOTE: pls enter your primary and secondary servers and contact address below 
;		(don't forget the trailing '.')
;	      Replace the '\@' in the contact address with '.' !!
;
;	CAVEAT ADMINISTRATOR: *never* use '#' as the comment character in files
;	used by the nameserver (named.boot, zonefiles, etc). The correct comment
;	character is the semicolon (';'). named might not work if you use '#' !!!!
;
;	IMPORTANT: DO NOT FORGET TO UPDATE THE SERIAL NUMBER EACH TIME YOU CHANGE
;			THIS FILE !!!
;	
\$ORIGIN $fd.$fc.$fb.$fa.in-addr.arpa.
\@	IN	SOA	<your_primary_nameserver>. <your_contact_address>. (
			$serial
			10800
			1800
			3600000
			86400 )
	IN	NS	<your_primary_nameserver>.
	IN	NS	<your_secondary_nameserver>.
;------
;
;	note that you cannot use the first ($fa.$fb.$fc.$fd = network address)
;	and last ($la.$lb.$lc.$ld = broadcast) address for hosts (PTR).!!
;
;	The individual PTR records below are still commented out.
;	fill in the correct hostnames and remove the leading ';'.
;	We advise that you only uncomment the PTR record you really need.
;
EOF

print INC <<"EOF";
;
;	delegation for $ARGV[0]
;		(addresses from $fa.$fb.$fc.$fd to $la.$lb.$lc.$ld)
;
;	this file should be "include'd" in the $fc.$fb.$fa.in-addr.arpa zonefile
;
$fd	IN	NS	<customer_ns1>.
	IN	NS	<customer_ns2>.

EOF

for $dd (($fd+1) .. ($ld-1)) {
	print SUB ";$dd	IN	PTR	<some_hostname_$dd>.\n";
	print INC "$dd	IN	CNAME	$dd.$fd.$fc.$fb.$fa.in-addr.arpa.\n";
	}

close(SUB);
close(INC);

sub unp {
	local($o) = @_[0];
	local($r);
	local($a,$b,$c,$d);

	$d = $o & 0x000000ff;
        $o >>= 8;
	$c = $o & 0x000000ff;
        $o >>= 8;
	$b = $o & 0x000000ff;
        $o >>= 8;
	$a = $o & 0x000000ff;

	return($a,$b,$c,$d);
	}
