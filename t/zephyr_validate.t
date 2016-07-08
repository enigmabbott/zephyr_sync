#!/usr/bin/perl

use strict;
use warnings;
use ZephyrResource;
use Test::More qw/no_plan/;

#ideally we create a bunch of fake data or mock out
#this requires some real data :(

my $zr = ZephyrResource->new(username => 'user', password => 'pass' );

for my $issue_key (qw/AWQA-1 AWQA-2/) {

	$zr->production_rc->GET("rest/api/2/issue/$issue_key?fields=id", $zr->rest_headers);

    my $hash =$zr->process_response($zr->production_rc, $issue_key);
    my $prod_issue_id = $hash->{id} or die $issue_key;

	$zr->production_rc->GET($zr->test_step_base . "/$prod_issue_id" , $zr->rest_headers);

    my $prod_steps =$zr->process_response($zr->production_rc, $issue_key);

    ok($prod_steps, "got production steps for $issue_key");

	$zr->dev_rc->GET("rest/api/2/issue/$issue_key?fields=id", $zr->rest_headers);

    my $dhash =$zr->process_response($zr->dev_rc, $issue_key);
    my $dev_issue_id = $dhash->{id} or die $issue_key;

	$zr->dev_rc->GET($zr->test_step_base . "/$dev_issue_id" , $zr->rest_headers);

    my $dev_steps =$zr->process_response($zr->dev_rc, $issue_key);
    ok($dev_steps, "got dev steps for $issue_key");

    $zr->validate_test_steps($prod_steps,$dev_steps);
}
