package OIDC::Client::ResponseParser;
use utf8;
use Moose;
use namespace::autoclean;

use Try::Tiny;
use OIDC::Client::Error::InvalidResponse;
use OIDC::Client::Error::Provider;

sub parse {
  my ($self, $res) = @_;

  if ($res->is_success) {
    return try {
      $res->json;
    }
    catch {
      OIDC::Client::Error::InvalidResponse->throw(
        sprintf(q{Invalid response: %s}, $_)
      );
    };
  }
  else {
    OIDC::Client::Error::Provider->throw({
      response_parameters => try { $res->json } || {},
      alternative_error   => $res->is_error ? $res->message || $res->code
                                            : $res->{error}{message} || $res->{error}{code},
    });
  }
}

__PACKAGE__->meta->make_immutable;

1;
