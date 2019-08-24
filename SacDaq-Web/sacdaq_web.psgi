use strict;
use warnings;

use SacDaq::Web;

my $app = SacDaq::Web->apply_default_middlewares(SacDaq::Web->psgi_app);
$app;

