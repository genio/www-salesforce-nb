use Mojo::Base -strict;
use Test::More;
use Mojo::IOLoop::Delay;
use Mojo::JSON;
use Mojolicious::Lite;
use Try::Tiny;
use v5.10;

use FindBin;
use lib "$FindBin::Bin/lib";

BEGIN {
	$ENV{MOJO_NO_SOCKS} = $ENV{MOJO_NO_TLS} = 1;
	$ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
	use_ok( 'WWW::Salesforce' ) || BAIL_OUT("Can't use WWW::Salesforce");
}
my $ERROR_OUT=0;
my $SOSL = 'FIND {Chase Test} RETURNING Account(Id,Name)';
my $SOSL_MAL = 'FIND {Chase TesTURNING Account(Id,Name)';
my $RES = [{
	attributes=> {
		type=> "Account",
		url=> "/services/data/v34.0/sobjects/Account/001W000000KY10hIAD"
	},
	Id=> "001W000000KY10hIAD",
	Name=> "Chase test"
}];
my $RES_EMPTY = {
	layout=>"/services/data/v34.0/search/layout",
	scopeOrder=>"/services/data/v34.0/search/scopeOrder",
	suggestions=>"/services/data/v34.0/search/suggestions"
};
# Silence
app->log->level('fatal');
get '/services/data/v33.0/search' => sub {
	my $c = shift;
	return $c->render(status=>401,json=>[{message=>"Session expired or invalid",errorCode=>"INVALID_SESSION_ID"}]) if $ERROR_OUT;
	my $sosl = $c->param('q') || '';
	$sosl = '' unless $sosl && !ref($sosl);
	if ( !$sosl ) {
		return $c->render(json=>$RES_EMPTY);
	}
	elsif ( $sosl eq $SOSL_MAL ) {
		return $c->render(status=>404,json=>[{errorCode=> "MALFORMED_SEARCH", message=>"No search term found. The search term must be enclosed in braces."}]);
	}
	elsif ( $sosl eq $SOSL ) {
		return $c->render(json=>$RES);
	}
	return $c->render(json=>$RES_EMPTY);
};

my $sf = try {
	WWW::Salesforce->new(
		login_url => Mojo::URL->new('/'),
		login_type => 'oauth2_up',
		version => '33.0',
		username => 'test',
		password => 'test',
		pass_token => 'toke',
		consumer_key => 'test_id',
		consumer_secret => 'test_secret',
	);
} catch {
	BAIL_OUT("Unable to create new instance: $_");
	return undef;
};
isa_ok( $sf, 'WWW::Salesforce', 'Is a proper Salesforce object' ) || BAIL_OUT("can't instantiate");
# set the login
$sf->_instance_url('/');
$sf->_access_token('123455663452abacbabababababababanenenenene');
$sf->_access_time(time());
# actual testing
can_ok($sf, qw(search) );

# errors
{
	my $res;
	$res = try {$sf->search($SOSL_MAL)} catch {$_};
	like($res,qr/MALFORMED_SEARCH/, "search: error: Malformed SOSL string");
}

{ # successes
	my $res;
	$res = try {$sf->search()} catch {$_};
	is_deeply($res, $RES_EMPTY, "search: empty call");
	$res = try {$sf->search(undef)} catch {$_};
	is_deeply($res, $RES_EMPTY, "search: undef call");
	$res = try {$sf->search({})} catch {$_};
	is_deeply($res, $RES_EMPTY, "search: hashref call");
	$res = try {$sf->search('')} catch {$_};
	is_deeply($res, $RES_EMPTY, "search: empty string call");
}
done_testing;
