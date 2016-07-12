package ZephyrResource;

use Moose;

use Data::Dumper;
use RestWrap;
use MIME::Base64;
use JSON;
use Test::More;

has staging_url => (is => 'rw', isa  => 'Str', default => 'https://stagingjira.myinstance.com');
has production_url => (is => 'rw', isa  => 'Str', default => 'https://jira.myinstance.com');
has username => (is => 'rw', isa  => 'Str', required => 1);
has password => (is => 'rw', isa  => 'Str', required => 1);
#rc == rest_client
has production_rc => (is => 'rw', isa  => 'Object', lazy => 1, default => sub { RestWrap->new(host => $_[0]->production_url);}) ;
has dev_rc => (is => 'rw', isa  => 'Object', lazy => 1, default => sub { RestWrap->new(host => $_[0]->staging_url);});
has json => (is => 'ro', isa  => 'Object', lazy => 1, default => sub {JSON->new->allow_nonref });


sub test_step_base  { return '/rest/zapi/latest/teststep'; }

sub rest_headers {
    my $self = shift;

    my $encoded_auth = encode_base64($self->username.":".$self->password,'');

    return { 'Authorization' => "Basic $encoded_auth",
             'Accept' => 'application/json',
             'Content-Type' => 'application/json'
           };
}

sub process_response {
    my ($self, $rc,$key)= @_;

     my $code = $rc->responseCode() or die "failed to get response code" ;

    if ($code != 200 and $code != 302  ){
        print Dumper $rc->response ;
		die "issue: $key had problems\n";
    }

	return $self->json->decode( $rc->responseContent());
}

sub validate_test_steps {
    my ($self, $prod_steps,$dev_steps) = @_;

    my $steps = scalar(@$prod_steps);
    is($steps,scalar(@$dev_steps), 'number of steps match'); 

    for( my $i=0;$i <$steps; $i++){
        is($prod_steps->[$i]->{step},$dev_steps->[$i]->{step}, "$i step matches");
        is($prod_steps->[$i]->{data},$dev_steps->[$i]->{data}, "$i datamatches");
        is($prod_steps->[$i]->{result},$dev_steps->[$i]->{result}, "$i result matches");
    }

    return 1;
}

sub get_test_executions { 
    my ($self, %p) = @_;
    my $rc = $p{rc} or die;
    my $issue_id = $p{issue_id} or die;

    #$rc->GET("rest/zapi/latest/execution/executionByIssue?issueIdOrKey=$issue_key", $self->rest_headers);
    $rc->GET("rest/zapi/latest/execution?issueId=$issue_id", $self->rest_headers);
    
    return $self->process_response($rc, $issue_id);
}

sub sync_test_executions {
    my ($self, %p) = @_;
    my $issue_key = $p{issue_key};
    print "key $issue_key\n";

    my $source_rc= $p{source_rc};
    my $dest_rc= $p{dest_rc};

	$source_rc->GET("rest/api/2/issue/$issue_key?fields=id", $self->rest_headers);
    my $shash =$self->process_response($source_rc, $issue_key);
	my $source_id = $shash->{id};
    print "source_id: $source_id\n";

	$dest_rc->GET("rest/api/2/issue/$issue_key?fields=id,project", $self->rest_headers);
    my $dhash =$self->process_response($dest_rc, $issue_key);
	my $dest_id = $dhash->{id};
    print "dest_id: $dest_id\n";
    my $dest_project_id = $dhash->{fields}->{project}->{id};

    unless($dest_project_id){
        print Dumper $dhash;
        die;
    }

=cut
my %versions;
if($self->{_versions}){
    %versions = %{$self->{_versions}};
}else {
    my $str = "rest/zapi/latest/cycle?projectId=$dest_project_id";
#    print $str . "\n";
     $dest_rc->GET($str, $self->rest_headers);
    $dhash =$self->process_response($dest_rc, $issue_key);

# $source_rc->GET("rest/zapi/latest/cycle?projectId=13902", $self->rest_headers);
     # $dhash =$self->process_response($source_rc, $issue_key);

     # print Dumper $dhash;
     # exit;

    for my $version_id(keys %$dhash){
         for my $hashes(@{$dhash->{$version_id}}){
             delete $hashes->{recordsCount};

             for my $cycle_id (keys %$hashes){
                 my $h = $hashes->{$cycle_id};
                 $versions{$h->{versionName}}->{versionId} = $version_id;
                 $versions{$h->{versionName}}->{$h->{name}} = $cycle_id;
             }
         }
     }

    $self->{_versions} = \%versions;
}
=cut

    my $source_hash = $self->get_test_executions(rc => $source_rc, issue_id => $source_id);
    my $s_ex = $source_hash->{executions};
    return 1 if scalar(@$s_ex) == 0;


    my $dest_hash = $self->get_test_executions(rc => $dest_rc, issue_id => $dest_id);
    my $d_ex = $dest_hash->{executions};

    my $i= 0;
    print "execution count: " . scalar(@$d_ex) . "\n";

    for my $s (@$s_ex){
        #print Dumper $s;
        $i++;
        my $version_name = $s->{versionName};

        my $cycle_name = $s->{cycleName};

        my @hits = grep {($_->{versionName} eq $version_name) && ($_->{cycleName} eq $cycle_name ) } @$d_ex;
        if(scalar(@hits) == 0 and $version_name eq 'Unscheduled' ){
            next;
        }
        unless(@hits){
            die "no hits";
        }

        if(scalar(@hits) > 1){
            print Dumper \@hits;
            die "multiple hits";
        }

        my $id = $hits[0]->{id};
        print "found id: $id\n";
    #    print Dumper \@hits;
        unless( $s->{executedOn}){
            print "not executed on dev\n";
            next;
        }
        if($hits[0]->{executedOn}){
            print "production already executed\n";
            next;
        }

        my %ex  = ( executions => [$id],
                   "assigneeType" => "assignee",
                   "assignee" =>  $s->{executedBy},
                   );

print "put assign\n";
print Dumper \%ex;


           $dest_rc->PUT("rest/zapi/latest/execution/bulkAssign" ,  encode_json(\%ex), $self->rest_headers);
           my $hash =$self->process_response($dest_rc, $dest_id) or die;
           

           %ex =( status => $s->{executionStatus},);

print "put status: \n";
print Dumper \%ex;

           $dest_rc->PUT("rest/zapi/latest/execution/$id/execute/" ,  encode_json(\%ex), $self->rest_headers);
           $hash =$self->process_response($dest_rc, $dest_id) or die;
    }

    return 1;
}

sub create_test_steps {
    my ($self, $steps, $issue_id, $rc) = @_;
    die unless $issue_id;
    $rc = $self->production_rc unless $rc;

    my $i = 0;

    for(@$steps){
        $i++;
        my %changes = (
            step=> $_->{step},
            data=> $_->{data},
            result => $_->{result},
        );
            
        $rc->POST($self->test_step_base . "/$issue_id" ,  encode_json(\%changes), $self->rest_headers);
        print "creating step $i: \n";
#        print Dumper \%changes;

        my $hash =$self->process_response($rc, $issue_id) or die;
    }

    return 1;
}

sub delete_test_steps {
    my ($self, $steps, $issue_id, $rc) = @_;
    $rc = $self->production_rc unless $rc;

    my $i; 
    for( @$steps){ 
        $i++;

        print "deleting $i\n";
        $rc->DELETE($self->test_step_base . "/$issue_id/". $steps->{id} , $self->rest_headers);
        my $hash =$self->process_response($rc, $issue_id) or die;
    }

    return 1;
}

sub validate_step_counts {
    my ($self,$prod_steps,$dev_steps, $prod_key ) = @_;
	die "need key" unless $prod_key;

    my $steps = scalar(@$prod_steps);
    my $dev_count=  scalar(@$dev_steps);

    if($steps != $dev_count){
        print "DIFF_STEP_COUNT $prod_key\n";
        # print Dumper
        # die "steps not equal prod: $steps and dev: $dev_count";
    }else{
        print "SAME_STEP_COUNT $prod_key\n";
    }

	return 1; 
}

__PACKAGE__->meta->make_immutable;
1;

=cut

test_step resource returned from zapi:

$VAR1 = {
          'htmlResult' => '',
          'createdBy' => 'e421sq',
          'htmlStep' => '<p>Test Case History</p>',
          'step' => 'Test Case History',
          'data' => 'Created by: Satish Balakrishnan
Created In: June 07 Release
Created On: 03/12/2007

Requirements in the form of ClearQuest CQ: 35895',
          'id' => 716287,
          'modifiedBy' => 'e421sq',
          'htmlData' => '<p>Created by: Satish Balakrishnan<br/>
Created In: June 07 Release<br/>
Created On: 03/12/2007</p>

<p>Requirements in the form of ClearQuest CQ: 35895</p>',
          'orderId' => 1
        };
