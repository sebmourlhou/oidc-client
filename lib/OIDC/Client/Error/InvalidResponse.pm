package OIDC::Client::Error::InvalidResponse;
use utf8;
use Moose;
extends 'OIDC::Client::Error';
use namespace::autoclean;

has '+message' => (
  default => 'OIDC: invalid response',
);

__PACKAGE__->meta->make_immutable;

1;
