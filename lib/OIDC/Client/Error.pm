package OIDC::Client::Error;
use utf8;
use Moose;
extends 'Throwable::Error';
use namespace::autoclean;

__PACKAGE__->meta->make_immutable;

1;
