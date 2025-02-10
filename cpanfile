requires 'perl', '5.20.0';
requires 'Carp';
requires 'Crypt::JWT', '0.035';
requires 'Data::UUID';
requires 'List::Util';
requires 'List::MoreUtils', '0.423';
requires 'Module::Load';
requires 'Mojolicious', '8.24';
requires 'Moose';
requires 'Moose::Util::TypeConstraints';
requires 'MooseX::Params::Validate';
requires 'Readonly';
requires 'Throwable::Error';
requires 'Try::Tiny';
requires 'namespace::autoclean';

test_requires 'Log::Any';
test_requires 'Log::Any::Test';
test_requires 'Test::Deep';
test_requires 'Test::Exception';
test_requires 'Test::MockModule', '0.177.0';
test_requires 'Test::MockObject';
test_requires 'Test::More';

author_requires 'Test::CPAN::Meta';
author_requires 'Test::Perl::Critic';
author_requires 'Test::Vars';
