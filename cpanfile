requires 'perl', 5.020000;
requires 'Carp';
requires 'Crypt::JWT';
requires 'Data::UUID';
requires 'List::Util';
requires 'List::MoreUtils';
requires 'Mojolicious';
requires 'Moose';
requires 'Moose::Util::TypeConstraints';
requires 'MooseX::Params::Validate';
requires 'Readonly';
requires 'Try::Tiny';
requires 'namespace::autoclean';

suggests 'Catalyst::Runtime';

test_requires 'Log::Any';
test_requires 'Log::Any::Test';
test_requires 'Test::Deep';
test_requires 'Test::Exception';
test_requires 'Test::MockModule';
test_requires 'Test::MockObject';
test_requires 'Test::More';

author_requires 'Catalyst::Runtime';
author_requires 'Catalyst::Plugin::Session::Store::FastMmap';
author_requires 'Catalyst::Plugin::Static::Simple';
author_requires 'Test::WWW::Mechanize::Catalyst::WithContext';
author_requires 'Catalyst::Plugin::ConfigLoader';
author_requires 'Catalyst::View::JSON';
author_requires 'Catalyst::Action::RenderView';
author_requires 'Config::General';
