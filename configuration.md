# OIDC::Client - Configuration

## store_mode

Defines where the tokens are stored.

Possible values (*session* by default) :

- session: stored data persists between requests until the session expires.
- stash: the stored data can only be accessed in the current request. This may be useful for an API which must validate the token in the *Authorization* header for each request (Authorization Server).

## authentication\_error\_path

Relative path of the endpoint to which the browser is redirected if an error is returned by the provider during the callback to the application after an authentication attempt or if an error occurs when the token is retrieved in exchange for the code.

If this path is not configured, an error, with the message configured in *authentication\_error\_message* or else a generic message, is launched with an HTTP 401 code.

## authentication\_error\_message

Message used to return an error if *authentication_error\_path* is not set.

## provider."provider".proxy\_detect

If true, detects the proxy server based on environment variables.

## provider."provider".user\_agent

Change of user agent name.

## provider."provider".id

OIDC client ID supplied by your provider. Mandatory

## provider."provider".secret

OIDC client secret supplied by your provider.

If not present, the secret must be defined in the environment variable *OIDC\_${provider}\_SECRET*

## provider."provider".audience

Used to specify to the provider for whom the access token is intended.

If this parameter is omitted, the access token returned by the provider is intended for your OIDC client (useful for making exchange tokens).

For an application, it's better to leave this parameter out and make exchange tokens if you need to make API calls to other applications, but it can be useful for a batch if you know that the API calls will be made to a single application.

## provider."provider".role\_prefix

Enables you to define, if required, a prefix common to the roles that will be ignored during a comparison test between a role to be verified and the list of user roles.

For example, with the prefix configured: *MYAPP.*

```perl
my $can_access_app = $auth_user->has_role('USER');
```
au lieu de :
```perl
my $can_access_app = $auth_user->has_role('MYAPP.USER');
```

## provider."provider".well\_known\_url

Endpoint, which allows the library to retrieve the provider's metadata at the time of instantiation of the OIDC client only.

If it's not defined, the following parameters must be manually specified when required:

- issuer: provider identifier which must correspond exactly to the *iss* claim of the tokens received
- jwks\_url : endpoint for publishing the keys to be used to verify the signature of a JWT token
- authorize\_url : endpoint from which an interaction takes place between the provider and the browser in order to authenticate the user
- token_url : endpoint on which the backend exchanges an authorization code with a token or refreshes a token
- userinfo_url: endpoint used to retrieve user information
- end\_session\_url: endpoint used to clean up the user session on the provider side

You can also configure the well know URL and _overload_ one or more metadata with these same configuration entries.

## provider."provider".signin\_redirect\_path

Relative path of the endpoint used by the provider to redirect the user's browser to the application once authentication has been completed.

## provider."provider".signin\_redirect\_uri

Alternative to *signin\_redirect\_path*

Absolute path to the endpoint used by the provider to redirect the user's browser to the application once authentication has been completed.

## provider."provider".scope

List of scopes defining the scope of rights attached to the token transmitted.

Can be an array of strings or a string with space separators.

## provider."provider".expiration\_leeway

Number of seconds of leeway for a token to be considered expired before it actually is.

## provider."provider".decode\_jwt\_options

Options to be transferred to the library [Crypt::JWT](https://metacpan.org/pod/Crypt::JWT) used to validate a token.

By default, the options passed are :

- verify_exp: 1 (the 'exp' claim must be present)
- leeway: 30 (seconds margin, used for verifying the various timestamps)

## provider."provider".jwt\_claim\_key

Used to set the names of the attributes (claims) of the JWT token for creating the *identity* hashref.

By default, the library uses the names :

```
<jwt_claim_key>
    issuer      iss
    expiration  exp
    audience    aud
    subject     sub
</jwt_claim_key>
```

## provider."provider".audience\_alias

Audience configuration.

Allows you to give an alias to an audience rather than using the technical identifier.

For example :

```
<audience_alias other_app_name>
    audience    other-app-audience
</audience_alias>
```

## provider."provider".authorize\_endpoint\_response\_mode

Defines how tokens are sent by the provider.

Can take one of these values:

- query: tokens sent in query parameters
- form_post : tokens sent in a POST form

## provider."provider".authorize\_endpoint\_extra\_params

Allows you to define additional parameters to be sent to the provider when the *authorize* endpoint is called.

## provider."provider".token\_endpoint\_grant\_type

Defines the *grant_type* parameter to be sent to the provider when the *token* endpoint is called.

Can take one of these values:

- authorization_code
- client_credentials
- password

By default, the *authorization_code* grant type is used.

## provider."provider".token\_endpoint\_auth\_method

Used to define the authentication method to be used when calling the *token* endpoint.

Can take one of these values:

- post: the client id and secret are sent in the POST body 
- basic : the client id and the secret are sent in an *Authorization* header

By default, the *post* method is used.

## provider."provider".username

For a grant_type *password*, specify the technical account to be used.

## provider."provider".password

For a grant_type *password*, specify the technical account password to be used.

## provider."provider".logout\_redirect\_path

Relative path of the endpoint used by the provider to redirect the user's browser to the application once the session has been cleaned up on the provider side.

## provider."provider".post\_logout\_redirect\_uri

Alternative to *logout\_redirect\_path*

Absolute path to the endpoint used by the provider to redirect the user's browser to the application once the session has been cleaned up on the provider side.

## provider."provider".logout\_with\_id\_token

Used to specify whether the token id should be sent to the provider when the *end_session* endpoint is called.

True by default

## provider."provider".logout\_extra\_params

Allows you to define additional parameters to be sent to the provider when the *end_session* endpoint is called.

## provider."provider".mocked\_identity

For local use only, bypasses the authentication flow by directly defining a mocked object representing an identity.

Example:

```
<mocked_identity>
    login       DOEJ
    lastname    Doe
    firstname   John
    email       john.doe@gmail.com
    roles       MYAPP.ROLE1
    roles       MYAPP.ROLE2
</mocked_identity>
```

## provider."provider".mocked\_claims

For local use only, allows the verification of a token to be bypassed by directly defining a mocked object representing the claims.

Example:

```
<mocked_claims>
    sub         DOEJ
    exp         123456
    aud         MYAPP
</mocked_claims>
```

## provider."provider".mocked\_userinfo

For local use only, allows you to directly define a mocked object representing userinfo.

Example:

```
<mocked_userinfo>
    sub         DOEJ
    lastName    Doe
    firstName   John
    email       john.doe@gmail.com
    roles       MYAPP.ROLE1
    roles       MYAPP.ROLE2
</mocked_userinfo>
```
