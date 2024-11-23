package OIDC::Client::Plugin::Catalyst;
use utf8;
use Moose;
use namespace::autoclean;
with 'Catalyst::ClassData';

use feature 'signatures';
no warnings 'experimental::signatures';

use Carp qw(croak);
use Clone qw(clone);
use List::Util qw(first);
use Try::Tiny;
use OIDC::Client;
use OIDC::Client::Plugin::Common::Main;
use OIDC::Client::Error::Authentication;

__PACKAGE__->mk_classdata('_oidc_config');
__PACKAGE__->mk_classdata('_oidc_client_by_provider');

# code executed once when the application is loaded
sub setup_finalize ($app) {

  my $config = $app->config->{'oidc_client'}
    or croak('no oidc_client config');

  $app->_oidc_config($config);

  my %client_by_provider;
  my %seen_path;

  my $dispatch_path = first { $_->isa('Catalyst::DispatchType::Path') } @{$app->dispatcher->dispatch_types};

  foreach my $provider (keys %{ $config->{provider} || {} }) {
    my $config_provider = clone($config->{provider}{$provider});
    $config_provider->{provider} = $provider;

    $client_by_provider{$provider} = OIDC::Client->new(
      config => $config_provider,
      log    => $app->log,
    );

    # didn't find a better way to dynamically add the callback routes to the application
    my @new_actions;
    foreach my $action_type (qw/ login logout /) {
      my $path = $action_type eq 'login' ? $config_provider->{signin_redirect_path}
                                         : $config_provider->{logout_redirect_path};
      next if !$path || $seen_path{$path}++;
      require Catalyst::Action;
      push @new_actions, Catalyst::Action->new(
        class      => __PACKAGE__,
        namespace  => '',
        code       => $action_type eq 'login' ? \&_oidc_login_callback : \&_oidc_logout_callback,
        name       => "oidc_${action_type}_callback",
        reverse    => "oidc/${action_type}_callback",
        attributes => { Path => [ $path ] },
      );
    }
    $dispatch_path->register($app, $_) for @new_actions;
  }

  $app->_oidc_client_by_provider(\%client_by_provider);
}

# entry point for application (see methods in OIDC::Client::Plugin::Common::Main)
sub oidc ($c, %options) {

  return OIDC::Client::Plugin::Common::Main->new(
    log             => $c->log,
    store_mode      => $c->_oidc_config->{store_mode} || 'session',
    request_params  => $c->req->params,
    request_headers => { $c->req->headers->flatten },
    session         => $c->session,
    stash           => $c->stash,
    get_flash       => sub { return $c->flash->{$_[0]}; },
    set_flash       => sub { $c->flash->{$_[0]} = $_[1]; return; },
    redirect        => sub { $c->response->redirect($_[0]); return; },
    client          => $c->_oidc_get_client_for_provider($options{provider}),
    base_url        => $c->req->base->as_string,
    current_url     => $c->req->uri->as_string,
  );
}

# code executed on callback after authentication attempt
sub _oidc_login_callback ($self, $c) {

  my @providers = keys %{ $c->_oidc_client_by_provider };
  my $provider = @providers == 1 ? $providers[0]
                                 : $c->flash->{oidc_provider};
  try {
    $c->oidc(provider => $provider)->get_token();
    $c->response->redirect($c->flash->{oidc_target_url} || $c->uri_for('/'));
  }
  catch {
    my $e = $_;
    $c->log->warn("OIDC: error retrieving token : $e");
    if (my $error_path = $c->_oidc_config->{authentication_error_path}) {
      $c->response->redirect($c->uri_for($error_path));
    }
    else {
      $c->response->status(401);
      OIDC::Client::Error::Authentication->throw(
        $c->_oidc_config->{authentication_error_message} || ()
      );
    }
  };
}

# code executed on callback after user logout
sub _oidc_logout_callback ($self, $c) {

  $c->log->debug('Logging out');
  $c->delete_session;

  $c->response->redirect($c->flash->{oidc_target_url} || $c->uri_for('/'));
}

sub _oidc_get_client_for_provider ($c, $provider) {

  unless ($provider) {
    my @providers = keys %{ $c->_oidc_client_by_provider };
    if (@providers == 1) {
      $provider = $providers[0];
    }
    elsif (@providers > 1) {
      croak(q{OIDC: more than one provider are configured, the provider is mandatory : $c->oidc(provider => $provider)});
    }
    else {
      croak("OIDC: no provider is configured");
    }
  }

  my $client = $c->_oidc_client_by_provider->{$provider}
    or croak("OIDC: no client for provider $provider");

  return $client;
}

__PACKAGE__->meta->make_immutable;

1;
