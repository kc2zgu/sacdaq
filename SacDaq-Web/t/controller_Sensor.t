use strict;
use warnings;
use Test::More;


use Catalyst::Test 'SacDaq::Web';
use SacDaq::Web::Controller::Sensor;

ok( request('/sensor')->is_success, 'Request should succeed' );
done_testing();
