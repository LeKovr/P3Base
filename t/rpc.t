#!/usr/bin/env perl

use strict;
use warnings;

use LWP::UserAgent;
use Test::More;

use JSON;

my $ua = LWP::UserAgent->new;
my $host=(shift || '127.0.0.1:9091') . '/rpc';

my @tests = ({ 
        method => 'ping', result => 'pong',
        name => 'ping'
    }, {
        method => 'ping', status => '204 No Content',
        name => 'notification'
    }, {
        method => 'unknown', error => { code => -32601, data => 'unknown', message => 'Method not found.'},
        name => 'unknown method'
    }, { method => -32000, error => {code => -32600, data => '-32000 is not a valid method name.', message => 'Invalid Request.'},
        name => 'invalid request'
    }
);

plan tests => scalar(@tests);
my $json = JSON->new->canonical(1); #->allow_nonref;

foreach my $t (@tests) {
    my $subtests = $t->{bulk} ? $t->{bulk} : [$t];
    my (@req, @resp);
    foreach my $ti (@$subtests) {
        my $req = { jsonrpc => '2.0', method  => $ti->{method} };
        $req->{id} = $$ unless ($ti->{status});
        $req->{params} = $ti->{params} if ($ti->{params});
        push @req, $req;

        my $resp = { jsonrpc => '2.0', id      => $$  };
        if ($ti->{result}) {         $resp->{result} = $ti->{result};
        } elsif ($ti->{error}) {     $resp->{error}  = $ti->{error};
        }
        push @resp, $resp;
    }
    my $req  = $t->{bulk} ? \@req  : $req[0];
    my $resp = $t->{bulk} ? \@resp : $resp[0];

    my $req_json = $json->encode($req);
    my $resp_json = $t->{status} || $json->encode($resp);
    my $got = $ua->post('http://'.$host, 'Content' => $req_json, 'Content-Type' => "application/json; charset=UTF-8");
    if ($t->{status}) {
        is($got->status_line, $t->{status}, $t->{name});
    } else {
        my $json_sorted = $json->encode($json->decode($got->content));
        is($json_sorted, $resp_json, $t->{name});
    }
}
