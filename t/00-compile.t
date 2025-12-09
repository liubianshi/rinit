use strict;
use warnings;
use Test::More;

my @modules = qw(
    RInit::App
    RInit::Templates
    RInit::Manifest

);

plan tests => scalar @modules;

for my $module (@modules) {
    require_ok($module) || BAIL_OUT("Failed to load $module");
}
