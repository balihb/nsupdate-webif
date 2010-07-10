#!/usr/bin/perl
# Tis program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# http://sam.zoy.org/wtfpl/COPYING for more details.

use Net::DNS;
use Net::IP;
use Socket;
use CGI qw/:standard *table/;
use strict;

#config
my $charset='utf-8';
my $pagename='NSUpdate';
my $css='/nsupdate.css';
my $domain='example.local';
my $ptr='0.10.in-addr.arpa';
my $nsupdate='nsupdate';
my $rndc_key='/etc/bind/rndc.key';

#localize
my $txtname =
    'Name';
my $txtttl =
    'TTL';
my $txtclass =
    'Class';
my $txttype =
    'Type';
my $txtdata =
    'Data';
my $txtaction =
    'Action';
my $txtrefresh =
    'Refresh';
my $txtadd =
    'Add';
my $txtdel =
    'Delete';
my $txtaddrecord =
    'Add record';
my $txtnoa =
    'no A record';
my $txtmultia =
    'multiple A record';
my $txtnoptr =
    'no PTR record';
my $txtmultiptr =
    'multiple PTR record';
my $txtaptrdiff = 
    'A name and PTR name differs';
my $txtcnameadiff =
    'CNAME not points to the A record';
my $txtzonetransferfailed =
    'Zone transfer failed: ';
my $txtmalformedip =
    'Malformed IP: ';
my $txtnonexistingip =
    'Nonexisting IP: ';
my $txtproblems =
    'Problems';
my $txtaddtable =
    'Add record';
my $txtdomaintable =
    "Domain: $domain";

our(@sorted, @vals, @ips);
my $problem='';
my $res = Net::DNS::Resolver->new;
my @zone = $res->axfr($ptr);

print 
    header(-charset=>$charset),
    start_html(-title=>$pagename,
	       -encoding=>$charset,
	       -style=>{'src'=>$css});

print h1($pagename),a({-href=>url(),-id=>'refresh'},$txtrefresh);
if(param('a') eq 'add'){
    print h2($txtadd);
    my $command ='';
    $command .= 'update add '.param('name').' '.param('ttl').' '.param('class').' '.param('type').' '.param('data')."\n";
    $command .= "show\n";
    $command .= "send\n";
    $command .= "quit\n";
    if($rndc_key){
	print '<pre id="nsushow">'.`echo -n \"$command\" | nsupdate -k /etc/bind/rndc.key`.'</pre>';
    }
    else{
	print '<pre id="nsushow">'.`echo -n \"$command\" | nsupdate`.'</pre>';
    }
}
elsif(param('a') eq 'del'){
    print h2($txtdel);
    my $command ='';
    $command .= 'update delete '.param('name').' '.param('type')."\n";
    $command .= "show\n";
    $command .= "send\n";
    $command .= "quit\n";
    if($rndc_key){
	print '<pre id="nsushow">'.`echo -n \"$command\" | nsupdate -k /etc/bind/rndc.key`.'</pre>';
    }
    else{
	print '<pre id="nsushow">'.`echo -n \"$command\" | nsupdate`.'</pre>';
    }
}
Delete_all();

print start_multipart_form(),
    start_table({-id=>'addtable'}),caption($txtaddtable),
    Tr([
	th([$txtname,$txtttl,$txtclass,$txttype,$txtdata,$txtaction]),
	td([textfield(-name=>'name'),
	    textfield(-name=>'ttl'),
	    textfield(-name=>'class'),
	    textfield(-name=>'type'),
	    textfield(-name=>'data'),
	    submit(-value=>$txtadd).hidden(-name=>'a',-value=>'add')
	   ])
       ]),
    end_table,end_form;

if (@zone) {
    foreach my $rr (@zone) {
	if($rr->type eq 'PTR'){
	    my @addr=split(/\./,$rr->name);
	    @addr = reverse(splice(@addr,0,4));
	    my $addr=join('.',@addr);
	    if($addr!~/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/){
		$problem.=div({-class=>'problem'},$txtmalformedip.$rr->name, ' ', $rr->ttl, ' ', $rr->class, ' ', $rr->type, ' ', $rr->ptrdname ,start_multipart_form().submit(-value=>$txtdel).hidden(-name=>'a',-value=>'del').hidden(-name=>'name',-value=>$rr->name).hidden(-name=>'type',-value=>$rr->type).end_form);
		next;
	    }
	    &inssort(unpack('N', pack('C4', @addr)), join('.',@addr), ($rr->name, $rr->ttl, $rr->class, $rr->type, $rr->ptrdname));
	}
    }
} else {
    print $txtzonetransferfailed, $res->errorstring, "\n";
}

@zone = $res->axfr($domain);

if (@zone) {
    foreach my $rr (@zone) {
	if ($rr->type eq 'A'){
	    if($rr->address!~/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/){
		$problem.=div({-class=>'problem'},$txtmalformedip.$rr->name, ' ', $rr->ttl, ' ', $rr->class, ' ', $rr->type, ' ', $rr->address, start_multipart_form().submit(-value=>$txtdel).hidden(-name=>'a',-value=>'del').hidden(-name=>'name',-value=>$rr->name).hidden(-name=>'type',-value=>$rr->type).end_form);
		next;
	    }

	    &inssort(unpack('N',pack('C4', split(/\./, $rr->address))), $rr->address, ($rr->name, $rr->ttl, $rr->class, $rr->type, $rr->address));
	}
	elsif($rr->type eq 'CNAME'){
	    if(inet_aton($rr->cname)){
		my $addr=inet_ntoa(inet_aton($rr->cname));
		&inssort(unpack('N', pack('C4', split(/\./, $addr))), $addr, ($rr->name, $rr->ttl, $rr->class, $rr->type, $rr->cname));
	    }
	    else{
		$problem.=div({-class=>'problem'},$txtnonexistingip.$rr->name, ' ', $rr->ttl, ' ', $rr->class, ' ', $rr->type, ' ', $rr->cname, start_multipart_form().submit(-value=>$txtdel).hidden(-name=>'a',-value=>'del').hidden(-name=>'name',-value=>$rr->name).hidden(-name=>'type',-value=>$rr->type).end_form);
	    }
	}
	elsif($rr->type eq 'TXT'){
	    if(inet_aton($rr->name)){
		my $addr=inet_ntoa(inet_aton($rr->name));
		&inssort(unpack('N', pack('C4', split(/\./, $addr))), $addr, ($rr->name, $rr->ttl, $rr->class, $rr->type, $rr->txtdata));
	    }
	    else{
		$problem.=div({-class=>'problem'},$txtnonexistingip.$rr->name, ' ', $rr->ttl, ' ', $rr->class, ' ', $rr->type, ' ', $rr->txtdata, start_multipart_form().submit(-value=>$txtdel).hidden(-name=>'a',-value=>'del').hidden(-name=>'name',-value=>$rr->name).hidden(-name=>'type',-value=>$rr->type).end_form);
	    }

	}
    }
} else {
    print $txtzonetransferfailed, $res->errorstring;
}

print start_table({-id=>'maintable'}),caption($txtdomaintable);
print Tr({-class=>'heading'},th([$txtname,$txtttl,$txtclass,$txttype,$txtdata,$txtaction]));
my $c=1;

for my $i ( 0 .. $#vals ) {
    my $a = 0;
    my $adata='';
    my $ptr = 0;
    my $ptrdata='';
    my @cname = ();
    print Tr({-class=>'head',-id=>"$ips[$i]"},td({-colspan=>'6'},"$c: $ips[$i]"));
    foreach my $j (@{$vals[$i]}){
	print Tr({-class=>'data'},td([@{$j},start_multipart_form().submit(-value=>$txtdel).hidden(-name=>'a',-value=>'del').hidden(-name=>'name',-value=>${$j}[0]).hidden(-name=>'type',-value=>${$j}[3]).end_form]));
	if(${$j}[3] eq 'A'){
	    $a++;
	    $adata=${$j}[0];
	}
	elsif(${$j}[3] eq 'PTR'){
	    $ptr++;
	    $ptrdata=${$j}[4];
	}
	elsif(${$j}[3] eq 'CNAME'){
	    push @cname, ${$j}[4];
	}
    }
    $c++;
    if($a ne 1 or $ptr ne 1 or ($a eq 1 and $ptr eq 1 and lc $adata ne lc $ptrdata) or ($a eq 1 and $#cname ge 0)){
	my @problems;
	push(@problems, $txtnoa) if($a < 1);
	push(@problems, $txtmultia) if($a > 1);
	push(@problems, $txtnoptr) if($ptr < 1);
	push(@problems, $txtmultiptr) if($ptr > 1);
	push(@problems, $txtaptrdiff) if($a eq 1 and $ptr eq 1 and lc $adata ne lc $ptrdata);
	if($a eq 1 and $#cname ge 0){
	    foreach my $cn (@cname){
		if($cn ne $adata){
		    push(@problems, $txtcnameadiff);
		    last;
		}
	    }
	}
	$problem.=div({-class=>'problem'},a({href=>"#$ips[$i]"},$ips[$i]),join(', ',@problems)) if($#problems ge 0);
    }
}
print end_table;
print h2($txtproblems),div({-id=>'problems'},$problem) if($problem ne '');
print end_html();

sub inssort {
    my ($by, $ip, @val) = @_;
    if($#sorted eq -1){
	push @sorted, $by;
	push @vals, [\@val];
	push @ips, $ip;
    }
    else{
	for my $pos ( 0 .. $#sorted ) {
	    if ( $sorted[$pos] < $by and ($pos+1) > $#sorted ){
		push @sorted, $by;
		push @vals, [\@val];
		push @ips, $ip;
		return;
	    }
	    elsif ( ($pos == 0 and $by < $sorted[0]) or ($sorted[$pos] < $by and ($pos+1) < $#sorted and $sorted[$pos+1] > $by)) {
		splice @sorted, $pos+1, 0, $by;
		splice @vals, $pos+1, 0, [\@val];
		splice @ips, $pos+1, 0, $ip;
		return;
	    }
	    elsif( $sorted[$pos] == $by ){
		push @{$vals[$pos]}, \@val;
		return;
	    }
	}
    }
}
