requires 'perl', 5.020000;
requires 'Carp';
requires 'Crypt::JWT';
requires 'List::Util';
requires 'List::MoreUtils';
requires 'Mojolicious';
requires 'Moose';
requires 'Moose::Util::TypeConstraints';
requires 'MooseX::Params::Validate';
requires 'Readonly';
requires 'Try::Tiny';
requires 'namespace::autoclean';

suggests 'Catalyst';
suggests 'Test::WWW::Mechanize::Catalyst::WithContext';

test_requires 'Log::Any';
test_requires 'Log::Any::Test';
test_requires 'Test::Deep';
test_requires 'Test::Exception';
test_requires 'Test::MockModule';
test_requires 'Test::MockObject';
test_requires 'Test::More';

author_requires 'Catalyst';
author_requires 'Test::WWW::Mechanize::Catalyst::WithContext';
