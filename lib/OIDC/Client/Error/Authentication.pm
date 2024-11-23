package OIDC::Client::Error::Authentication;
use utf8;
use Moose;
extends 'OIDC::Client::Error';
use namespace::autoclean;

has '+message' => (
  default => 'OIDC: authentication problem',
);

__PACKAGE__->meta->make_immutable;

1;
