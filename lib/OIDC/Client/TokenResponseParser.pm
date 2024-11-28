package OIDC::Client::TokenResponseParser;
use utf8;
use Moose;
extends 'OIDC::Client::ResponseParser';
use namespace::autoclean;

use OIDC::Client::Token;

around 'parse' => sub {
  my $orig = shift;
  my $self = shift;

  my $result = $self->$orig(@_);

  return OIDC::Client::Token->new($result);
};

__PACKAGE__->meta->make_immutable;

1;
