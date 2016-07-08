#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use ZephyrResource;

my $zr = ZephyrResource->new(username => 'user', password => 'pass' );

while(<>){
    chomp;
    s/"//g;
	my $issue_key = $_;

    $zr->production_rc->GET("rest/api/2/issue/$issue_key?fields=id", $zr->rest_headers);
    my $hash =$zr->process_response($zr->production_rc, $issue_key);
    my $prod_issue_id = $hash->{id} or die $issue_key;

    $zr->production_rc->GET($zr->test_step_base . "/$prod_issue_id" , $zr->rest_headers);
    my $prod_steps =$zr->process_response($zr->production_rc, $issue_key);

    if($prod_steps and scalar(@$prod_steps)){
        print Dumper $prod_steps;
        die "was not expecting prod steps for $issue_key";
    }

	$zr->dev_rc->GET("rest/api/2/issue/$issue_key?fields=id", $zr->rest_headers);

    my $dhash =$zr->process_response($zr->dev_rc, $issue_key);
    my $dev_issue_id = $dhash->{id} or die $issue_key;

	$zr->dev_rc->GET($zr->test_step_base . "/$dev_issue_id" , $zr->rest_headers);

    my $dev_steps =$zr->process_response($zr->dev_rc, $issue_key);

    $zr->create_test_step($dev_steps, $prod_issue_id, $zr->production_rc) or die ;
}
