package OIDC::Client::Plugin::Mojolicious;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Carp qw(croak);
use Clone qw(clone);
use Try::Tiny;
use OIDC::Client;
use OIDC::Client::Plugin::Common::Main;
use OIDC::Client::Error::Authentication;

has '_oidc_config';
has '_oidc_client_by_provider';

# code executed once when the application is loaded
sub register ($self, $app, $config) {

  keys %$config
    or $config = ($app->config->{oidc_client} || {});
  $self->_oidc_config($config);

  my %client_by_provider;
  my %seen_path;

  foreach my $provider (keys %{ $config->{provider} || {} }) {
    my $config_provider = clone($config->{provider}{$provider});
    $config_provider->{provider} = $provider;

    $client_by_provider{$provider} = OIDC::Client->new(
      config => $config_provider,
      log    => $app->log,
    );

    # dynamically add the callback routes to the application
    foreach my $action_type (qw/ login logout /) {
      my $path = $action_type eq 'login' ? $config_provider->{signin_redirect_path}
                                         : $config_provider->{logout_redirect_path};
      next if !$path || $seen_path{$path}++;
      my $method = $action_type eq 'login' ? '_login_callback' : '_logout_callback';
      my $name   = $action_type eq 'login' ? 'oidc_login_callback' : 'oidc_logout_callback';
      $app->routes->any(['GET', 'POST'] => $path => sub { $self->$method(@_) } => $name);
    }
  }
  $self->_oidc_client_by_provider(\%client_by_provider);

  $app->helper('oidc' => sub { $self->_helper_oidc(@_) });
}

# "oidc" entry point for application (see methods in OIDC::Client::Plugin::Common::Main)
sub _helper_oidc ($self, $c, %options) {

  return OIDC::Client::Plugin::Common::Main->new(
    log             => $c->app->log,
    store_mode      => $self->_oidc_config->{store_mode} || 'session',
    request_params  => $c->req->params->to_hash,
    request_headers => $c->req->headers->to_hash,
    session         => $c->session,
    stash           => $c->stash,
    get_flash       => sub { return $c->flash($_[0]); },
    set_flash       => sub { $c->flash($_[0], $_[1]); return; },
    redirect        => sub { $c->redirect_to($_[0]); return; },
    client          => $self->_get_client_for_provider($options{provider}),
    base_url        => $c->req->url->base->to_string,
    current_url     => $c->req->url->to_string,
  );
}

# code executed on callback after authentication attempt
sub _login_callback ($self, $c) {

  my @providers = keys %{ $self->_oidc_client_by_provider };
  my $provider = @providers == 1 ? $providers[0]
                                 : $c->flash('oidc_provider');
  try {
    $c->oidc(provider => $provider)->get_token();
    $c->redirect_to($c->flash('oidc_target_url') || $c->url_for('/'));
  }
  catch {
    my $e = $_;
    $c->app->log->warn("OIDC: error retrieving token : $e");
    if (my $error_path = $self->_oidc_config->{authentication_error_path}) {
      $c->redirect_to($c->url_for($error_path));
    }
    else {
      $c->res->code(401);
      OIDC::Client::Error::Authentication->throw(
        $self->_oidc_config->{authentication_error_message} || ()
      );
    }
  };
}

# code executed on callback after user logout
sub _logout_callback ($self, $c) {

  $c->app->log->debug('Logging out');
  $c->session(expires => 1);

  $c->redirect_to($c->flash('oidc_target_url') || $c->url_for('/'));
}

sub _get_client_for_provider ($self, $provider) {

  unless ($provider) {
    my @providers = keys %{ $self->_oidc_client_by_provider };
    if (@providers == 1) {
      $provider = $providers[0];
    }
    elsif (@providers > 1) {
      croak(q{OIDC: more than one provider are configured, the provider is mandatory : $c->oidc(provider => $provider)});
    }
    else {
      croak("OIDC: no provider configured");
    }
  }

  my $client = $self->_oidc_client_by_provider->{$provider}
    or croak("OIDC: no client for provider $provider");

  return $client;
}

1;
