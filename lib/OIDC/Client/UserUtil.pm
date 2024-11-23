package OIDC::Client::UserUtil;
use utf8;
use strict;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Exporter 'import';
our @EXPORT_OK = qw(build_user_from_identity
                    build_user_from_mapping);

use OIDC::Client::User;
use Readonly;

Readonly my @USER_ATTRIBUTES => qw( login lastname firstname email roles );

=encoding utf8

=head1 NAME

OIDC::Client::UserUtil

=head1 DESCRIPTION

Utility class for L<OIDC::Client::User>.

=head1 METHODS

=head2 build_user_from_identity( $identity, $role_prefix )

  use OIDC::Client::UserUtil qw(build_user_from_identity);
  ...
  my $identity = $oidc->get_stored_identity();
  my $user = build_user_from_identity($identity, $oidc->client->role_prefix);

Returns a L<OIDC::Client::User> object from an identity hashref
which is usually stored in the session.

The list parameters are:

=over 2

=item identity

identity object (hashref)

=item role_prefix

Role prefix (string). See L<OIDC::Client::User>.

=back

=cut

sub build_user_from_identity ($identity, $role_prefix = '') {
  return OIDC::Client::User->new(
    (map { $_ => $identity->{$_} } @USER_ATTRIBUTES),
    role_prefix => $role_prefix,
  );
}


=head2 build_user_from_mapping( $data, $mapping, $role_prefix )

  use OIDC::Client::UserUtil qw(build_user_from_mapping);
  ...
  my $userinfo    = $oidc->get_userinfo();
  my $mapping     = $oidc->client->jwt_claim_key;
  my $role_prefix = $oidc->client->role_prefix;
  my $user = build_user_from_mapping($userinfo, $mapping, $role_prefix);

Returns a L<OIDC::Client::User> object from JWT claims.

The list parameters are:

=over 2

=item claims

Claims (hashref)

=item jwt_claim_key

JWT claim key mapping : claim name => claim key (hashref)

=item role_prefix

Role prefix (string). See L<OIDC::Client::User>.

=back

=cut

sub build_user_from_mapping ($data, $mapping, $role_prefix = '') {
  return OIDC::Client::User->new(
    ( map {
        $_ => defined $mapping->{$_} ? $data->{ $mapping->{$_} } : undef
      } @USER_ATTRIBUTES ),
    role_prefix => $role_prefix,
  );
}

1;
