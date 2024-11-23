package OIDC::Client::Error::TokenValidation;
use utf8;
use Moose;
extends 'OIDC::Client::Error';
use namespace::autoclean;

has '+message' => (
  default => 'OIDC: token validation problem',
);

__PACKAGE__->meta->make_immutable;

1;
