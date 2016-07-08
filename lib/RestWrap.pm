package RestWrap;

use Moose;

our ($VERSION) = (1);

use Data::Dumper;
use URI;
use LWP::UserAgent;
use Http::Request;

has debug => ( is => 'rw', isa => 'Bool', default => 0);
has host => ( is => 'rw', isa => 'Str',);
has response => ( is => 'rw', isa => 'Object',);
has timeout => ( is => 'ro', isa => 'Str', default => 300);
has headers => ( is => 'rw', isa => 'Maybe[HashRef]', lazy => 1, default => sub { {} }  );

has user_agent => ( is => 'ro', isa => 'LWP::UserAgent', default => sub {
            my $ua = LWP::UserAgent->new;
            $ua->agent("RestWrap/$VERSION");
            return $ua;
        }
);

{
    my $meta = __PACKAGE__->meta or die 'no meta';

    for my $name (qw/PUT PATCH POST /){
        $meta->add_method( $name => sub { shift->request($name, @_); });
    }

    for my $name (qw/GET OPTIONS HEAD /){
        $meta->add_method( $name => sub { 
            my ($self, $url, $headers) = @_;
            return $self->request('GET', $url, undef, $headers);
         });
    }
}

sub DELETE {
    my ($self, $url, $headers) = @_;
    return $self->request('DELETE', $url, undef, $headers);

}

sub build_query {
    my $self = shift;

    my $uri = URI->new();
    $uri->query_form(@_);
    return $uri->as_string();
}

sub request {
    my ($self, $method , $url ,$content , $headers) = @_;

    my $supported = '(get|patch|put|post|delete|options|head)';

    die "invalid 'method': $method (supported options: $supported)" unless $method =~ /^$supported$/i;
    die "url required param" unless($url);
    die "header need to be a hashref" if( $headers && ref $headers ne 'HASH');

    $url = $self->_prepareURL($url);
    print "PREPARE: $url\n" if $self->debug;

    my $ua = $self->user_agent();
       $ua->timeout($self->timeout);

    my $req = HTTP::Request->new( $method => $url );

    #build headers
    if(defined $content && length($content)){
        $req->content($content);
        $req->header('Content-Length', length($content));
    }else{
        $req->header('Content-Length', 0);
    }

    my $custom_headers = $self->headers;
    for my $header (keys %$custom_headers){
        $req->header($header, $custom_headers->{$header});
    }

    for my $header (keys %$headers){
        $req->header($header, $headers->{$header});
    }

    $self->response($ua->request($req));
    # print Dumper $req;
    # print Dumper $self->response;

    return $self;
}

sub responseCode {$_[0]->response->code; }
sub responseContent { $_[0]->response->content; }
sub responseHeaders { $_[0]->response->headers()->header_field_names(); }

sub responseHeader {
    my ($self ,$header ) = @_;
    die "header is required" unless $header;
    return $self->response->header($header);
}

sub _prepareURL {
    my ($self ,$url ) = @_;

    
    if( my $host = $self->host){
        $url = '/'.$url unless $url =~ /^\//;
        $url = $host . $url;
    }

    return $url;
}

__PACKAGE__->meta->make_immutable;

1;
