#!/usr/bin/env perl
use utf8;
use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Exception;
use Test::MockObject;
use Log::Any::Test;
use Log::Any qw($log);
use Local::OIDC::Client::Token;
use Local::OIDC::Client::User;
use Mojo::UserAgent;

use FindBin qw($Bin);
use lib "$Bin/lib";
use OIDCClientTest qw(launch_tests);

my $class = 'Local::OIDC::Client::Plugin::Common::Main';
use_ok $class;

my $test = OIDCClientTest->new();

launch_tests();
done_testing;

sub test_login_redirect_uri {
  subtest "login_redirect_uri with path configuration" => sub {

    # Given
    my $obj = build_object(config => {signin_redirect_path => '/oidc/redirect'});

    # When
    my $login_redirect_uri = $obj->login_redirect_uri;

    # Then
    is($login_redirect_uri, 'http://my-app/oidc/redirect',
       'expected login_redirect_uri');
  };

  subtest "login_redirect_uri without path configuration" => sub {

    # Given
    my $obj = build_object();

    # When
    my $login_redirect_uri = $obj->login_redirect_uri;

    # Then
    is($login_redirect_uri, undef,
       'no login_redirect_uri');
  };
}

sub test_logout_redirect_uri {
  subtest "logout_redirect_uri with path configuration" => sub {

    # Given
    my $obj = build_object(config => {logout_redirect_path => '/oidc/logout/redirect'});

    # When
    my $logout_redirect_uri = $obj->logout_redirect_uri;

    # Then
    is($logout_redirect_uri, 'http://my-app/oidc/logout/redirect',
       'expected logout_redirect_uri');
  };

  subtest "logout_redirect_uri without path configuration" => sub {

    # Given
    my $obj = build_object();

    # When
    my $logout_redirect_uri = $obj->logout_redirect_uri;

    # Then
    is($logout_redirect_uri, undef,
       'no logout_redirect_uri');
  };
}

sub test_redirect_to_authorize_with_maximum_parameters {
  subtest "redirect_to_authorize() with maximum of parameters" => sub {

    # Given
    my $obj = build_object(attributes => { login_redirect_uri => 'my_login_redirect_uri' });

    # When
    $obj->redirect_to_authorize(
      target_url         => 'my_target_url',
      extra_params       => { param => 'param' },
      other_state_params => [ 'state_param1', 'state_param2' ],
    );

    # Then
    cmp_deeply($obj->get_flash->('oidc_state'), re('^state_param1,state_param2,[\w-]{36,36}$'),
       'expected oidc_state flash');

    is($obj->get_flash->('oidc_provider'), 'my_provider',
       'expected oidc_provider flash');

    is($obj->get_flash->('oidc_target_url'), 'my_target_url',
       'expected oidc_target_url flash');

    is($obj->redirect->(), 'my_auth_url',
       'expected redirect');

    cmp_deeply([ $obj->client->next_call() ],
               [ 'auth_url', bag($obj->client, nonce        => re('^[\w-]{36,36}$'),
                                               state        => re('^state_param1,state_param2,[\w-]+$'),
                                               redirect_uri => 'my_login_redirect_uri',
                                               extra_params => { param => 'param' }) ],
               'expected call to client');
  };
}

sub test_redirect_to_authorize_with_minimum_parameters {
  subtest "redirect_to_authorize() with minimum of parameters" => sub {

    # Given
    my $obj = build_object(attributes => { login_redirect_uri => undef });

    # When
    $obj->redirect_to_authorize();

    # Then
    cmp_deeply($obj->get_flash->('oidc_nonce'), re('^[\w-]{36,36}$'),
       'expected oidc_state flash');

    cmp_deeply($obj->get_flash->('oidc_state'), re('^[\w-]{36,36}$'),
       'expected oidc_state flash');

    isnt($obj->get_flash->('oidc_nonce'), $obj->get_flash->('oidc_state'),
       'oidc_nonce and oidc_state have different values');

    is($obj->get_flash->('oidc_provider'), 'my_provider',
       'expected oidc_provider flash');

    is($obj->get_flash->('oidc_target_url'), '/current-url',
       'expected oidc_target_url flash');

    is($obj->redirect->(), 'my_auth_url',
       'expected redirect');

    cmp_deeply([ $obj->client->next_call() ],
               [ 'auth_url', bag($obj->client, nonce => re('^[\w-]{36,36}$'),
                                               state => re('^[\w-]{36,36}$')) ],
               'expected call to client');
  };
}

sub test_get_token_with_provider_error {
  subtest "get_token() with provider error" => sub {

    # Given
    my $obj = build_object(request_params => {error => 'error from provider'});

    # When - Then
    throws_ok {
      $obj->get_token();
    } qr/error from provider/,
      'expected exception';
    isa_ok($@, 'Local::OIDC::Client::Error::Provider');
  };
}

sub test_get_token_with_invalid_state_parameter {
  subtest "get_token() without state parameter/flash" => sub {

    # Given
    my $obj = build_object(request_params => {},
                           flash          => {});

    # When - Then
    throws_ok {
      $obj->get_token();
    } qr/invalid state parameter/,
      'expected exception';
    isa_ok($@, 'Local::OIDC::Client::Error::Authentication');
  };

  subtest "get_token() without state parameter" => sub {

    # Given
    my $obj = build_object(request_params => {},
                           flash          => {oidc_state => 'abc'});

    # When - Then
    throws_ok {
      $obj->get_token();
    } qr/got '' but expected 'abc'/,
      'expected exception';
    isa_ok($@, 'Local::OIDC::Client::Error::Authentication');
  };

  subtest "get_token() with state parameter different from state in flash" => sub {

    # Given
    my $obj = build_object(request_params => {state      => 'aaa'},
                           flash          => {oidc_state => 'abc'});

    # When - Then
    throws_ok {
      $obj->get_token();
    } qr/got 'aaa' but expected 'abc'/,
      'expected exception';
    isa_ok($@, 'Local::OIDC::Client::Error::Authentication');
  };
}

sub test_get_token_ok {
  subtest "get_token() ok" => sub {

    # Given
    my $obj = build_object(request_params => {code       => 'my_code',
                                              state      => 'abc'},
                           flash          => {oidc_nonce => 'my-nonce',
                                              oidc_state => 'abc'});

    # When
    my $identity = $obj->get_token(
      redirect_uri => 'my_redirect_uri',
    );

    # Then
    my %expected_stored_identity = (
      token      => 'my_id_token',
      issuer     => 'my_issuer',
      expiration => 123,
      audience   => 'my_id',
      subject    => 'my_subject',
      roles      => [qw/role1 role2 role3/],
    );
    cmp_deeply(
      $identity,
      \%expected_stored_identity,
      'expected returned identity'
    );
    cmp_deeply(
      get_stored_identity($obj),
      \%expected_stored_identity,
      'expected stored identity'
    );

    my %expected_stored_access_token = (
      expires_at    => re('^\d+$'),
      token         => 'my_access_token',
      refresh_token => 'my_refresh_token',
      token_type    => 'my_token_type',
    );
    cmp_deeply(
      get_stored_access_token($obj),
      \%expected_stored_access_token,
      'expected stored access token'
    );
    cmp_deeply([ $obj->client->next_call() ],
               [ 'get_token', [ $obj->client, code         => 'my_code',
                                              redirect_uri => 'my_redirect_uri' ] ],
               'expected call to client->get_token');
    cmp_deeply([ $obj->client->next_call(2) ],
               [ 'verify_token', [ $obj->client, token             => 'my_id_token',
                                                 expected_audience => 'my_id',
                                                 expected_nonce    => 'my-nonce'] ],
               'expected call to client->verify_token');
  };
}

sub test_refresh_access_token_with_exceptions {
  subtest "refresh_access_token() with unknown_audience" => sub {

    # Given
    my $obj = build_object();
    $obj->client->mock('get_audience_for_alias', sub {});

    # When - Then
    throws_ok {
      $obj->refresh_access_token('alias_audience');
    } qr/no audience for alias 'alias_audience'/,
      'expected exception';
  };

  subtest "refresh_access_token() without stored access token" => sub {

    # Given
    my $obj = build_object();

    # When - Then
    throws_ok {
      $obj->refresh_access_token();
    } qr/no access token has been stored/,
      'expected exception';
  };

  subtest "refresh_access_token() without stored refresh token" => sub {

    # Given
    my $obj = build_object();
    store_access_token(
      $obj,
      { refresh_token => undef }
    );

    # When - Then
    is($obj->refresh_access_token(), undef,
       'expected result');
  };
}

sub test_refresh_access_token_ok {
  subtest "refresh_access_token() ok" => sub {

    # Given
    my $obj = build_object();
    store_access_token(
      $obj,
      { token         => 'my_old_access_token',
        refresh_token => 'my_old_refresh_token' }
    );
    store_identity(
      $obj,
      { subject => 'my_subject' }
    );

    # When
    $obj->refresh_access_token();

    # Then
    my %expected_stored_access_token = (
      expires_at    => re('^\d+$'),
      token         => 'my_access_token',
      refresh_token => 'my_refresh_token',
      token_type    => 'my_token_type',
    );
    cmp_deeply(
      get_stored_access_token($obj),
      \%expected_stored_access_token,
      'expected stored access token'
    );
    cmp_deeply([ $obj->client->next_call(3) ],
               [ 'get_token', [ $obj->client, grant_type    => 'refresh_token',
                                              refresh_token => 'my_old_refresh_token' ] ],
               'expected call to client->get_token');
  };
}

sub test_exchange_token_with_exceptions {
  subtest "exchange_token() without configured audience alias" => sub {

    # Given
    my $obj = build_object();

    # When - Then
    throws_ok {
      $obj->exchange_token('my_audience_alias');
    } qr/no audience for alias 'my_audience_alias'/,
      'expected exception';
  };

  subtest "exchange_token() without access token" => sub {

    # Given
    my $obj = build_object(
      config => { audience_alias => { my_audience_alias => {audience => 'my_audience'} } }
    );

    # When - Then
    throws_ok {
      $obj->exchange_token('my_audience_alias');
    } qr/cannot retrieve the access token/,
      'expected exception';
  };
}

sub test_exchange_token_ok {
  subtest "exchange_token() ok" => sub {

    # Given
    my $obj = build_object(
      config => { audience_alias => { my_audience_alias => {audience => 'my_audience'} } }
    );
    store_access_token(
      $obj,
      { token         => 'my_access_token',
        refresh_token => 'my_refresh_token' }
    );
    store_identity(
      $obj,
      { subject => 'my_subject' }
    );

    # When
    my $exchanged_token = $obj->exchange_token('my_audience_alias');

    # Then
    my %expected_exchanged_token = (
      expires_at    => re('^\d+$'),
      token         => 'my_exchanged_access_token',
      refresh_token => 'my_exchanged_refresh_token',
      token_type    => 'my_exchanged_token_type',
    );
    cmp_deeply(
      $exchanged_token,
      \%expected_exchanged_token,
      'expected exchanged token'
    );
    cmp_deeply(
      get_stored_access_token($obj, 'my_audience'),
      \%expected_exchanged_token,
      'expected stored access token'
    );
    cmp_deeply([ $obj->client->next_call(5) ],
               [ 'exchange_token', [ $obj->client, token    => 'my_access_token',
                                                   audience => 'my_audience' ] ],
               'expected call to client->exchange_token');
  };
}

sub test_verify_token_with_exceptions {
  subtest "verify_token() without authorization header" => sub {

    # Given
    my $obj = build_object();

    # When - Then
    throws_ok {
      $obj->verify_token();
    } qr/no token in authorization header/,
      'expected exception';
  };

  subtest "verify_token() without expected type in authorization header" => sub {

    # Given
    my $obj = build_object(
      request_headers => { Authorization => 'abcd123' }
    );

    # When - Then
    throws_ok {
      $obj->verify_token();
    } qr/no token in authorization header/,
      'expected exception';
  };
}

sub test_verify_token {
  subtest "verify_token() ok" => sub {

    # Given
    my $obj = build_object(
      request_headers => { Authorization => 'bearer abcd123' }
    );

    # When
    my $claims = $obj->verify_token();

    # Then
    my %expected_claims = (
      iss => 'my_issuer',
      exp => 123,
      aud => 'my_id',
      sub => 'my_subject',
      roles => [qw/role1 role2 role3/],
    );
    my %expected_stored_token = (
      token      => 'abcd123',
      expires_at => 123,
    );
    cmp_deeply($claims,
               \%expected_claims,
               'expected result');
    cmp_deeply(
      get_stored_access_token($obj),
      \%expected_stored_token,
      'expected stored access token'
    );
    cmp_deeply([ $obj->client->next_call() ],
               [ 'default_token_type', [ $obj->client ] ],
               'expected call to client->default_token_type');
    cmp_deeply([ $obj->client->next_call() ],
               [ 'verify_token', [ $obj->client, token => 'abcd123' ] ],
               'expected call to client->verify_token');
  };

  subtest "verify_token() token is stored in stash" => sub {

    # Given
    my $obj = build_object(
      request_headers => { Authorization => 'Bearer ABC2' },
      store_mode      => 'stash',
    );

    # When
    my $claims = $obj->verify_token();

    # Then
    my %expected_claims = (
      iss => 'my_issuer',
      exp => 123,
      aud => 'my_id',
      sub => 'my_subject',
      roles => [qw/role1 role2 role3/],
    );
    my %expected_stored_token = (
      token      => 'ABC2',
      expires_at => 123,
    );
    cmp_deeply($claims,
               \%expected_claims,
               'expected result');
    cmp_deeply(
      get_stored_access_token($obj),
      undef,
      'not stored in session'
    );
    cmp_deeply(
      get_stored_access_token($obj, undef, 'stash'),
      \%expected_stored_token,
      'stored in stash'
    );
  };

  subtest "verify_token() with mocked claims" => sub {

    my %mocked_claims = (sub => 'my_mocked_subject');

    # Given
    my $obj = build_object(
      config     => { mocked_claims => \%mocked_claims },
      attributes => { base_url => 'http://localhost:3000' },
    );

    # When
    my $claims = $obj->verify_token();

    # Then
    cmp_deeply($claims, \%mocked_claims,
               'expected result');
  };

  subtest "verify_token() with mocked claims but not in local environment" => sub {

    my %mocked_claims = (sub => 'my_mocked_subject');

    # Given
    my $obj = build_object(
      config          => { mocked_claims => \%mocked_claims },
      attributes      => { base_url => 'http://my-app' },
      request_headers => { Authorization => 'bearer abcd123' }
    );

    # When
    my $claims = $obj->verify_token();

    # Then
    cmp_deeply($claims, superhashof({sub => 'my_subject'}),
               'expected result');
  };
}

sub test_get_userinfo {
  subtest "get_userinfo()" => sub {

    # Given
    my $obj = build_object();
    store_access_token(
      $obj,
      { token         => 'my_access_token',
        refresh_token => 'my_refresh_token' }
    );

    # When
    my $userinfo = $obj->get_userinfo();

    # Then
    is($userinfo->{lastName}, 'Doe',
       'expected last name');

    cmp_deeply([ $obj->client->next_call(4) ],
               [ 'get_userinfo', [ $obj->client, access_token => 'my_access_token', token_type => undef ] ],
               'expected call to client->get_userinfo');
  };

  subtest "get_userinfo() with mocked userinfo" => sub {

    my %mocked_userinfo = (lastName => 'my_mocked_lastname');

    # Given
    my $obj = build_object(
      config     => { mocked_userinfo => \%mocked_userinfo },
      attributes => { base_url => 'http://localhost:3000' },
    );

    # When
    my $userinfo = $obj->get_userinfo();

    # Then
    cmp_deeply($userinfo, \%mocked_userinfo,
               'expected result');
  };

  subtest "get_userinfo() with mocked userinfo but not in local environment" => sub {

    my %mocked_userinfo = (lastName => 'my_mocked_lastname');

    # Given
    my $obj = build_object(
      config     => { mocked_userinfo => \%mocked_userinfo },
      attributes => { base_url => 'http://my-app' },
    );
    store_access_token(
      $obj,
      { token         => 'my_access_token',
        refresh_token => 'my_refresh_token' }
    );

    # When
    my $userinfo = $obj->get_userinfo();

    # Then
    is($userinfo->{lastName}, 'Doe',
       'expected last name');
  };
}

sub test_build_api_useragent {
  subtest "build_api_useragent() with valid access token for audience" => sub {

    # Given
    my $obj = build_object(
      config => { audience_alias => { my_audience_alias => {audience => 'my_audience'} } }
    );
    store_access_token(
      $obj,
      { token         => 'my_audience_access_token',
        token_type    => 'my_audience_token_type',
        refresh_token => 'my_audience_refresh_token' },
      'my_audience',
    );

    # When
    my $ua = $obj->build_api_useragent('my_audience_alias');

    # Then
    isa_ok($ua, 'Mojo::UserAgent');

    cmp_deeply([ $obj->client->next_call(4) ],
               [ 'build_api_useragent', bag($obj->client, token_type => 'my_audience_token_type',
                                                          token      => 'my_audience_access_token') ],
               'expected call to client');
  };

  subtest "build_api_useragent() without access token for audience" => sub {

    # Given
    my $obj = build_object(
      config => { audience_alias => { my_audience_alias => {audience => 'my_audience'} } }
    );
    store_access_token(
      $obj,
      { token         => 'my_access_token',
        refresh_token => 'my_refresh_token' }
    );
    store_identity(
      $obj,
      { subject => 'my_subject' }
    );

    # When
    my $ua = $obj->build_api_useragent('my_audience_alias');

    # Then
    isa_ok($ua, 'Mojo::UserAgent');

    cmp_deeply([ $obj->client->next_call(10) ],
               [ 'build_api_useragent', bag($obj->client, token_type => 'my_exchanged_token_type',
                                                          token      => 'my_exchanged_access_token') ],
               'expected call to client');
  };

  subtest "build_api_useragent() without valid access token for audience" => sub {

    # Given
    my $obj = build_object(
      config => { audience_alias => { my_audience_alias => {audience => 'my_audience'} } }
    );
    store_access_token(
      $obj,
      { token         => 'my_audience_access_token',
        token_type    => 'my_audience_token_type',
        refresh_token => 'my_audience_refresh_token' },
      'my_audience',
    );
    store_access_token(
      $obj,
      { token         => 'my_a_token',
        refresh_token => 'my_r_token' }
    );
    store_identity(
      $obj,
      { subject => 'my_subject' }
    );
    $obj->client->mock(has_expired => sub { 1 });

    # When
    my $ua = $obj->build_api_useragent('my_audience_alias');

    # Then
    isa_ok($ua, 'Mojo::UserAgent');

    cmp_deeply([ $obj->client->next_call(9) ],
               [ 'build_api_useragent', bag($obj->client, token_type => 'my_token_type',
                                                          token      => 'my_access_token') ],
               'expected call to client');
  };

  subtest "build_api_useragent() with error while refreshing access token for audience" => sub {
    $log->clear();

    # Given
    my $obj = build_object(
      config => { audience_alias => { my_audience_alias => {audience => 'my_audience'} } }
    );
    store_access_token(
      $obj,
      { token         => 'my_audience_access_token',
        token_type    => 'my_audience_token_type',
        refresh_token => 'my_audience_refresh_token' },
      'my_audience',
    );
    store_access_token(
      $obj,
      { token         => 'my_access_token',
        refresh_token => 'my_refresh_token' }
    );
    store_identity(
      $obj,
      { subject => 'my_subject' }
    );
    my $i = 0;
    $obj->client->mock(has_expired => sub { $i++ == 0 ? die 'to have an error while refreshing token'
                                                      : 0 });

    # When
    my $ua = $obj->build_api_useragent('my_audience_alias');

    # Then
    isa_ok($ua, 'Mojo::UserAgent');

    cmp_deeply([ $obj->client->next_call(11) ],
               [ 'build_api_useragent', bag($obj->client, token_type => 'my_exchanged_token_type',
                                                          token      => 'my_exchanged_access_token') ],
               'expected call to client');

    cmp_deeply($log->msgs->[0],
               superhashof({
                 message => re('OIDC: error getting valid access token'),
                 level   => 'warning',
               }),
               'expected log');
  };

  subtest "build_api_useragent() without valid access token for audience and cannot exchange token" => sub {

    # Given
    my $obj = build_object(
      config => { audience_alias => { my_audience_alias => {audience => 'my_audience'} } }
    );
    store_access_token(
      $obj,
      { token         => 'my_access_token',
        refresh_token => 'my_refresh_token' }
    );
    store_identity(
      $obj,
      { subject => 'my_subject' }
    );
    $obj->client->mock(has_expired => sub { 1 });
    $obj->client->mock(exchange_token => sub { die 'AAAAAhhhh !!!'; });

    # When - Then
    throws_ok {
      $obj->build_api_useragent('my_audience_alias');
    } qr/AAAAAhhhh/,
      'expected exception';
  };
}

sub test_redirect_to_logout_with_id_token {
  subtest "redirect_to_logout() with id token" => sub {

    # Given
    my $obj = build_object(attributes => { logout_redirect_uri => 'my_logout_redirect_uri' });
    store_identity(
      $obj,
      { token => 'my_id_token' }
    );

    # When
    $obj->redirect_to_logout(
      state         => 'my_state',
      extra_params  => { param => 'param' },
      target_url    => 'my_target_url',
    );

    # Then
    is($obj->get_flash->('oidc_target_url'), 'my_target_url',
       'expected oidc_target_url flash');

    is($obj->redirect->(), 'my_logout_url',
       'expected redirect');

    cmp_deeply([ $obj->client->next_call(2) ],
               [ 'logout_url', bag($obj->client, id_token                 => 'my_id_token',
                                                 post_logout_redirect_uri => 'my_logout_redirect_uri',
                                                 state                    => 'my_state',
                                                 extra_params             => { param => 'param' }) ],
               'expected call to client');
  };
}

sub test_redirect_to_logout_without_id_token {
  subtest "redirect_to_logout() without id token" => sub {

    # Given
    my $obj = build_object(attributes => { logout_redirect_uri => 'my_logout_redirect_uri' });

    # When
    $obj->redirect_to_logout(
      with_id_token            => 0,
      post_logout_redirect_uri => 'my_personal_logout_redirect_uri',
    );

    # Then
    is($obj->get_flash->('oidc_target_url'), undef,
       'no oidc_target_url flash');

    is($obj->redirect->(), 'my_logout_url',
       'expected redirect');

    cmp_deeply([ $obj->client->next_call() ],
               [ 'logout_url', bag($obj->client, post_logout_redirect_uri => 'my_personal_logout_redirect_uri') ],
               'expected call to client');
  };
}

sub test_has_access_token_expired {
  subtest "has_access_token_expired() has expired" => sub {

    # Given
    my $obj = build_object();
    store_access_token(
      $obj,
      {}
    );
    $obj->client->mock(has_expired => sub { 1 });

    # When
    my $has_expired = $obj->has_access_token_expired();

    # Then
    ok($has_expired, 'has expired');
  };

  subtest "has_access_token_expired() has not expired" => sub {

    # Given
    my $obj = build_object();
    store_access_token(
      $obj,
      {}
    );

    # When
    my $has_expired = $obj->has_access_token_expired();

    # Then
    ok(!$has_expired, 'has not expired');
  };
}

sub test_get_valid_access_token_with_exceptions {
  subtest "get_valid_access_token() without configured audience alias" => sub {

    # Given
    my $obj = build_object();

    # When - Then
    throws_ok {
      $obj->get_valid_access_token('my_audience_alias');
    } qr/no audience for alias 'my_audience_alias'/,
      'expected exception';
  };
}

sub test_get_valid_access_token {
  subtest "get_valid_access_token() with expired access token and no refresh token" => sub {

    # Given
    my $obj = build_object();
    store_access_token(
      $obj,
      { token      => 'my_access_token',
        expires_at => 1234 }
    );
    $obj->client->mock(has_expired => sub { 1 });

    # When - Then
    is($obj->get_valid_access_token(), undef,
       'expected result');
  };

  subtest "get_valid_access_token() with expired access token" => sub {

    # Given
    my $obj = build_object();
    store_access_token(
      $obj,
      { token         => 'my_access_token',
        refresh_token => 'my_refresh_token',
        expires_at    => 1234 }
    );
    $obj->client->mock(has_expired => sub { 1 });

    # When
    my $access_token = $obj->get_valid_access_token();

    # Then
    is($access_token->{token}, 'my_access_token',
       'expected token');
  };

  subtest "get_valid_access_token() with not expired token" => sub {

    # Given
    my $obj = build_object();
    store_access_token(
      $obj,
      { token      => 'my_stored_token',
        expires_at => 1234 }
    );

    # When
    my $access_token = $obj->get_valid_access_token();

    # Then
    is($access_token->{token}, 'my_stored_token',
       'expected token');
  };
}

sub test_get_valid_access_token_for_audience {
  subtest "get_valid_access_token() with expired exchanged token" => sub {

    # Given
    my $obj = build_object(
      config => { audience_alias => { my_audience_alias => {audience => 'my_audience'} } }
    );
    my %expired_access_token = ( token         => 'my_old_access_token',
                                 refresh_token => 'my_old_refresh_token',
                                 expires_at    => 12 );
    store_access_token($obj, \%expired_access_token, 'my_audience');
    store_identity($obj, { subject => 'my_subject' });
    $obj->client->mock(has_expired => sub { 1 });

    # When
    my $exchanged_token = $obj->get_valid_access_token('my_audience_alias');

    # Then
    is($exchanged_token->{token}, 'my_access_token',
       'expected token');

    cmp_deeply([ $obj->client->next_call(3) ],
               [ 'has_expired', [ $obj->client, 12 ] ],
               'expected call to client');
  };

  subtest "get_valid_access_token() with expired exchanged token and no refresh token" => sub {

    # Given
    my $obj = build_object(
      config => { audience_alias => { my_audience_alias => {audience => 'my_audience'} } }
    );
    my %expired_access_token = ( token      => 'my_old_access_token',
                                 expires_at => 12 );
    store_access_token($obj, \%expired_access_token, 'my_audience');
    store_identity($obj, { subject => 'my_subject' });
    $obj->client->mock(has_expired => sub { 1 });

    # When
    is($obj->get_valid_access_token('my_audience_alias'), undef,
       'expected result');
  };

  subtest "get_valid_access_token() with unexpired exchanged token" => sub {

    # Given
    my $obj = build_object(
      config => { audience_alias => { my_audience_alias => {audience => 'my_audience'} } }
    );
    my %access_token = ( token      => 'my_access_token',
                         expires_at => 1234 );
    store_access_token($obj, \%access_token, 'my_audience');

    # When
    my $exchanged_token = $obj->get_valid_access_token('my_audience_alias');

    # Then
    cmp_deeply($exchanged_token, \%access_token,
               'expected result');
  };

  subtest "get_valid_access_token() with mocked token" => sub {

    my %identity = (subject => 'my_mocked_subject');

    # Given
    my $obj = build_object(
      config     => { mocked_identity => \%identity,
                      audience_alias => { my_audience_alias => {audience => 'my_audience'} } },
      attributes => { base_url => 'http://localhost:3000' },
    );

    # When
    my $exchanged_token = $obj->get_valid_access_token('my_audience_alias');

    # Then
    my %expected_exchanged_token = (token => q{mocked token for audience 'my_audience'});
    cmp_deeply($exchanged_token, \%expected_exchanged_token,
               'expected result');
  };

  subtest "get_valid_access_token() with mocked token but not in local environment" => sub {

    my %identity = (subject => 'my_mocked_subject');

    # Given
    my $obj = build_object(
      config     => { mocked_identity => \%identity,
                      audience_alias => { my_audience_alias => {audience => 'my_audience'} } },
      attributes => { base_url => 'http://my-app' },
    );
    my %access_token = ( token      => 'my_access_token',
                         expires_at => 1234 );
    store_access_token($obj, \%access_token, 'my_audience');

    # When
    my $exchanged_token = $obj->get_valid_access_token('my_audience_alias');

    # Then
    cmp_deeply($exchanged_token, \%access_token,
               'expected result');
  };
}

sub test_get_stored_identity {
  subtest "get_stored_identity() without stored identity" => sub {

    # Given
    my $obj = build_object();

    # When
    my $stored_identity = $obj->get_stored_identity();

    # Then
    is($stored_identity, undef,
       'expected result');
  };

  subtest "get_stored_identity() with stored identity" => sub {

    my %identity = (subject => 'my_subject');

    # Given
    my $obj = build_object();
    store_identity($obj, \%identity);

    # When
    my $stored_identity = $obj->get_stored_identity();

    # Then
    cmp_deeply($stored_identity, \%identity,
               'expected result');
  };

  subtest "get_stored_identity() with mocked identity" => sub {

    my %identity = (subject => 'my_mocked_subject');

    # Given
    my $obj = build_object(
      config     => { mocked_identity => \%identity },
      attributes => { base_url => 'http://localhost:3002' },
    );

    # When
    my $stored_identity = $obj->get_stored_identity();

    # Then
    cmp_deeply($stored_identity, \%identity,
               'expected result');
  };

  subtest "get_stored_identity() with mocked identity but not in local environment" => sub {

    my %identity = (subject => 'my_mocked_subject');

    # Given
    my $obj = build_object(
      config     => { mocked_identity => \%identity },
      attributes => { base_url => 'http://my-app' },
    );

    # When
    my $stored_identity = $obj->get_stored_identity();

    # Then
    cmp_deeply($stored_identity, undef,
               'expected result');
  };
}

sub build_object {
  my (%params) = @_;

  my %default_jwt_claim_key = (
    issuer     => 'iss',
    expiration => 'exp',
    audience   => 'aud',
    subject    => 'sub',
    roles      => 'roles',
  );
  my %claims = (
    iss => 'my_issuer',
    exp => 123,
    aud => 'my_id',
    sub => 'my_subject',
    roles => [qw/role1 role2 role3/],
  );
  my %token = (
    access_token  => 'my_access_token',
    id_token      => 'my_id_token',
    refresh_token => 'my_refresh_token',
    token_type    => 'my_token_type',
    expires_in    => 3600,
  );
  my %exchanged_token = (
    access_token  => 'my_exchanged_access_token',
    refresh_token => 'my_exchanged_refresh_token',
    token_type    => 'my_exchanged_token_type',
    expires_in    => 3600,
  );
  my %config = %{ $params{config} || {} };

  my $mock_client = Test::MockObject->new();
  $mock_client->set_isa('Local::OIDC::Client');
  $mock_client->mock(config         => sub { \%config });
  $mock_client->mock(auth_url       => sub { 'my_auth_url' });
  $mock_client->mock(logout_url     => sub { 'my_logout_url' });
  $mock_client->mock(id             => sub { 'my_id' });
  $mock_client->mock(audience       => sub { $config{audience} || 'my_id' });
  $mock_client->mock(provider       => sub { 'my_provider' });
  $mock_client->mock(verify_token   => sub { \%claims });
  $mock_client->mock(jwt_claim_key  => sub { $config{jwt_claim_key} || \%default_jwt_claim_key });
  $mock_client->mock(get_token      => sub { Local::OIDC::Client::Token->new(%token) });
  $mock_client->mock(exchange_token => sub { Local::OIDC::Client::Token->new(%exchanged_token) });
  $mock_client->mock(build_api_useragent => sub { Mojo::UserAgent->new(); });
  $mock_client->mock(has_expired    => sub { 0 });
  $mock_client->mock(get_userinfo   => sub { {firstName => "John", lastName => 'Doe'} });
  $mock_client->mock(default_token_type => sub { 'Bearer' });
  $mock_client->mock(get_claim_value => sub {
    my ($self, %params) = @_;
    return $params{claims}->{$self->jwt_claim_key->{$params{name}}};
  });
  $mock_client->mock(get_audience_for_alias => sub {
    my (undef, $alias) = @_;
    return $params{config}->{audience_alias}{$alias}{audience};
  });

  my $flash = $params{flash} || {};
  my $redirect;

  return $class->new(
    log             => $log,
    store_mode      => $params{store_mode} || 'session',
    request_params  => $params{request_params} || {},
    request_headers => $params{request_headers} || {},
    session         => {},
    stash           => {},
    get_flash       => sub { return $flash->{$_[0]}; },
    set_flash       => sub { $flash->{$_[0]} = $_[1]; return; },
    redirect        => sub { if ($_[0]) { $redirect = $_[0]; return; }
                             else { return $redirect } },
    client          => $mock_client,
    base_url        => 'http://my-app/',
    current_url     => '/current-url',
    %{$params{attributes} || {}},
  );
}

sub store_identity {
  my ($obj, $identity) = @_;

  $obj->session->{oidc}{provider}{my_provider}{identity} = $identity;
}

sub get_stored_identity {
  my ($obj) = @_;

  return $obj->session->{oidc}{provider}{my_provider}{identity};
}

sub store_access_token {
  my ($obj, $token, $audience) = @_;

  $obj->session->{oidc}{provider}{my_provider}{access_token}{audience}{$audience || 'my_id'} = $token;
}

sub get_stored_access_token {
  my ($obj, $audience, $store_mode) = @_;
  $store_mode ||= 'session';

  my $store = $store_mode eq 'session' ? $obj->session
                                       : $obj->stash;

  return $store->{oidc}{provider}{my_provider}{access_token}{audience}{$audience || 'my_id'};
}
