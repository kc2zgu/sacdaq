use strict;
use warnings;
use Test::More;


use Catalyst::Test 'SacDaq::Web';
use SacDaq::Web::Controller::Api;

ok( request('/api')->is_success, 'Request should succeed' );
done_testing();
