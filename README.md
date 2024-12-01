# OIDC::Client

This library was born out of a lack of support in the Perl language for the OpenID Connect protocol (OIDC), although it is inspired by [OIDC::Lite](https://metacpan.org/pod/OIDC::Lite) and [Mojolicious::Plugin::OAuth2](https://metacpan.org/pod/Mojolicious::Plugin::OAuth2).

It facilitates integration of the protocol for different types of application, with :

- specific plugins for applications using the Mojolicious or Catalyst frameworks. Other plugins may be added in the future.
- a module for use with a batch or script

Supported features :

- redirect the browser to the authorize URL to initiate an authorization code flow
- get the token(s) from the provider
- session management : the tokens are stored and later retrieved from the session
- refresh the access token if needed
- JWT token verification with support for automatic JWK key rotation
- get the user information from the *userinfo* endpoint
- token exchange
- redirect the browser to the logout URL

## Mojolicious Application

### Configuration

Section to be added to your configuration file :

```
  oidc_client => {
    provider => {
      provider_name => {
        id                   => 'my-app-id',
        secret               => 'xxxxxxxxx',
        well_known_url       => 'https://yourprovider.com/oauth2/.well-known/openid-configuration',
        signin_redirect_path => '/oidc/login/callback',
        scope                => 'openid profile roles email',
        expiration_leeway    => 20,
        jwt_claim_key => {
          issuer     => 'iss',
          expiration => 'exp',
          audience   => 'aud',
          subject    => 'sub',
          login      => 'sub',
          lastname   => 'lastName',
          firstname  => 'firstName',
          email      => 'email',
          roles      => 'roles',
        },
      },
    },
  },
```

This is an example, see the detailed possibilities in : [configuration](configuration.md)

### Setup the plugin when the application is launched

```perl
  $app->plugin('OIDC::Client::Plugin::Mojolicious');
```

### Authentication

```perl
  $app->hook(before_dispatch => sub {
    my $c = shift;

    my $path = $c->req->url->path;

    # Public routes
    return if $path =~ m[^/oidc/]
           || $path =~ m[^/error/];

    # Authentication
    if (my $identity = $c->oidc->get_stored_identity()) {
      $c->remote_user($identity->{login});
    }
    elsif (uc($c->req->method) eq 'GET' && !$c->is_ajax_request()) {
      $c->oidc->redirect_to_authorize();
    }
    else {
      $c->render(template => 'error',
                 message  => "You have been logged out. Please try again after refreshing the page.",
                 status   => 401);
    }
  });

```
### API call with propagation of the security context (exchange token)

```perl
  # Retrieving a web client (Mojo::UserAgent object)
  my $ua = try {
    $c->oidc->build_api_useragent('other_app_name')
  }
  catch {
    $c->log->warn("Unable to exchange token : $_");
    $c->render(template => 'error',
               message  => "Authorization problem. Please try again after refreshing the page.",
               status   => 403);
    return;
  } or return;

  # Usual call to the API
  my $res = $ua->get($url)->result;
```

### Checking a token from an Authorisation Server

For example, with an application using [Mojolicious::Plugin::OpenAPI](https://metacpan.org/pod/Mojolicious::Plugin::OpenAPI), you can define a security definition:

```perl
use OIDC::Client::UserUtil qw(build_user_from_claims);

$app->plugin(OpenAPI => {
  url      => "data:///swagger.yaml",
  security => {
    oidc_token => sub {
      my ($c, $definition, $roles_to_check, $cb) = @_;

      my $claims = try {
        return $c->oidc->verify_token();
      }
      catch {
        $c->app->log->warn("Token validation : $_");
        $c->$cb("Invalid or incomplete token");
        return;
      } or return;

      my $userinfo = $c->oidc->get_userinfo();
      my $mapping  = $c->oidc->client->jwt_claim_key;
      my $user     = build_user_from_mapping($userinfo, $mapping);

      if (! @$roles_to_check) {
        return $c->$cb();
      }

      foreach my $role_to_check (@$roles_to_check) {
        if ($user->has_role($role_to_check)) {
          return $c->$cb();
        }
      }

      return $c->$cb("Insufficient roles");
    },
  }
});
```

## Catalyst Application

### Configuration

Section to be added to your configuration file :

```
<oidc_client>
    <provider provider_name>
        id                    my-app-id
        secret                xxxxxxxxx
        well_known_url        https://yourprovider.com/oauth2/.well-known/openid-configuration
        signin_redirect_path  /oidc/login/callback
        scope                 openid profile email
        expiration_leeway     20
        <jwt_claim_key>
            issuer      iss
            expiration  exp
            audience    aud
            subject     sub
            login       sub
            lastname    lastName
            firstname   firstName
            email       email
        </jwt_claim_key>
        <audience_alias other_app_name>
            audience    other-app-audience
        </audience_alias>
    </provider>
</oidc_client>
```

This is an example, see the detailed possibilities in : [configuration](configuration.md)

### Setup the plugin when the application is launched

```perl
my @plugin = (
  ...
  '+OIDC::Client::Plugin::Catalyst',
);
__PACKAGE__->setup(@plugin);
```

### Authentication

```perl
  if (my $identity = $c->oidc->get_stored_identity()) {
    $c->request->remote_user($identity->{login});
  }
  elsif (uc($c->request->method) eq 'GET' && !$c->is_ajax_request()) {
    $c->oidc->redirect_to_authorize();
  }
  else {
    MyApp::Exception::Authentication->throw(
      error => "You have been logged out. Please try again after refreshing the page.",
    );
  }
```

### API call with propagation of the security context (exchange token)

```perl
  # Retrieving a web client (Mojo::UserAgent object)
  my $ua = try {
    $c->oidc->build_api_useragent('other_app_name')
  }
  catch {
    $c->log->warn("Unable to exchange token : $_");
    MyApp::Exception::Authorization->throw(
      error => "Authorization problem. Please try again after refreshing the page.",
    );
  };

  # Usual call to the API
  my $res = $ua->get($url)->result;
```

## Batch or script

### Configuration

Section to be added to your batch configuration :

```yaml
oidc_client:
  provider:       provider_name
  id:             my-app-id
  secret:         xxxxxxxxx
  audience:       other_app_name
  well_known_url: https://yourprovider.com/oauth2/.well-known/openid-configuration
  login_scope:    roles
  username:       TECHXXXX
  password:       xxxxxxxx
```

### API call

```perl
  my $oidc_client = OIDC::Client->new(
    log    => $self->log,
    config => $self->ctx->conf->get(key => 'oidc_client'),
  );

  my $token = $oidc_client->get_token(grant_type => 'password');

  # Retrieving a web client (Mojo::UserAgent object)
  my $ua = $oidc_client->build_api_useragent(
    token_type => $token->token_type,
    token      => $token->access_token,
  );

  # Usual call to the API
  my $res = $ua->get($url)->result;
```

## Limitations

- no multi-audience support
- no support for Implicit and Hybrid flows (applicable to front-end applications only and deprecated)
