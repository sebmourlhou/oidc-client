# OIDC::Client

This library makes it easy to integrate the OpenID Connect protocol into different types of Perl applications. It includes :

- specific plugins for applications using the Mojolicious or Catalyst frameworks. Other plugins could be added for other frameworks.
- a module for use with a batch or any script

## Features

- automatically creates an endpoint used by the provider to redirect the user back to your application
- redirect the browser to the authorize URL to initiate an authorization code flow
- get the token(s) from the provider
- session management : the tokens are stored to be used for next requests
- refresh the access token if needed
- JWT token verification with support for automatic JWK key rotation
- get the user information from the *userinfo* endpoint
- token exchange
- redirect the browser to the logout URL

## Documentation

- Mojolicious Application

    [Plugin documentation](https://metacpan.org/pod/Mojolicious::Plugin::OIDC)

- Catalyst Application

    [Plugin documentation](https://metacpan.org/pod/Catalyst::Plugin::OIDC)

- Batch or script

    [Client module documentation](https://metacpan.org/pod/OIDC::Client)

## Limitations

- no multi-audience support
- no support for Implicit and Hybrid flows (applicable to front-end applications only and deprecated)
