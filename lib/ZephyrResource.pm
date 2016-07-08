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
