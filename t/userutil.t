#!/usr/bin/env perl
use utf8;
use strict;
use warnings;

use Test::More;
use Test::Deep;

use FindBin qw($Bin);
use lib "$Bin/lib";
use OIDCClientTest qw(launch_tests);

use Local::OIDC::Client::User;
my $class = 'Local::OIDC::Client::UserUtil';
use_ok $class, qw(build_user_from_identity
                  build_user_from_mapping);

my $test = OIDCClientTest->new();

launch_tests();
done_testing;


sub test_build_user_from_identity {
  subtest "build_user_from_identity() with maximum of information" => sub {

    # Given
    my %identity = (
      login     => 'my_login',
      lastname  => 'my_lastname',
      firstname => 'my_firstname',
      email     => 'my_email',
      roles     => ['MY.PREFIX.ROLE-A', 'MY.PREFIX.ROLE-B'],
    );
    my $role_prefix = 'MY.PREFIX.';

    # When
    my $user = build_user_from_identity(\%identity, $role_prefix);

    # Then
    my $expected_user = Local::OIDC::Client::User->new(
      login       => 'my_login',
      lastname    => 'my_lastname',
      firstname   => 'my_firstname',
      email       => 'my_email',
      roles       => ['MY.PREFIX.ROLE-A', 'MY.PREFIX.ROLE-B'],
      role_prefix => 'MY.PREFIX.',
    );
    cmp_deeply($user, $expected_user,
               'expected user');
  };

  subtest "build_user_from_identity() with minimum of information" => sub {

    # Given
    my %identity = (
      login => 'my_login',
    );

    # When
    my $user = build_user_from_identity(\%identity);

    # Then
    my $expected_user = Local::OIDC::Client::User->new(
      login       => 'my_login',
      lastname    => undef,
      firstname   => undef,
      email       => undef,
      roles       => undef,
      role_prefix => '',
    );
    cmp_deeply($user, $expected_user,
               'expected user');
  };
}

sub test_build_user_from_mapping {
  subtest "build_user_from_mapping() with maximum of information" => sub {

    # Given
    my %data = (
      sub       => 'my_login',
      lastName  => 'my_lastname',
      firstName => 'my_firstname',
      email     => 'my_email',
      roles     => ['MY.PREFIX.ROLE-A', 'MY.PREFIX.ROLE-B'],
    );
    my $role_prefix = 'MY.PREFIX.';
    my %mapping = (
      subject    => 'sub',
      login      => 'sub',
      lastname   => 'lastName',
      firstname  => 'firstName',
      email      => 'email',
      roles      => 'roles',
    );

    # When
    my $user = build_user_from_mapping(\%data, \%mapping, $role_prefix);

    # Then
    my $expected_user = Local::OIDC::Client::User->new(
      login       => 'my_login',
      lastname    => 'my_lastname',
      firstname   => 'my_firstname',
      email       => 'my_email',
      roles       => ['MY.PREFIX.ROLE-A', 'MY.PREFIX.ROLE-B'],
      role_prefix => 'MY.PREFIX.',
    );
    cmp_deeply($user, $expected_user,
               'expected user');
  };

  subtest "build_user_from_mapping() with minimum of information" => sub {

    # Given
    my %data = (
      sub => 'my_login',
    );
    my %mapping = (
      subject    => 'sub',
      login      => 'sub',
      lastname   => 'lastName',
      firstname  => 'firstName',
      email      => 'email',
      roles      => 'roles',
    );

    # When
    my $user = build_user_from_mapping(\%data, \%mapping);

    # Then
    my $expected_user = Local::OIDC::Client::User->new(
      login       => 'my_login',
      lastname    => undef,
      firstname   => undef,
      email       => undef,
      roles       => undef,
      role_prefix => '',
    );
    cmp_deeply($user, $expected_user,
               'expected user');
  };
}
