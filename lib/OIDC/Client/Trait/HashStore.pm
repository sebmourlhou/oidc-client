package OIDC::Client::Trait::HashStore;
use utf8;
use Moose::Role;
use namespace::autoclean;
use OIDC::Client::Utils qw(reach_data affect_data delete_data);

# creates read_session(), write_session() and delete_session() for 'session' attribute
# creates read_stash(), write_stash() and delete_stash() for 'stash' attribute
after 'install_accessors' => sub {
  my $self = shift;
  my $realclass = $self->associated_class();
  my $name = $self->name;
  $realclass->add_method("read_${name}"   => sub { return scalar reach_data( $_[0]->$name, $_[1]) });
  $realclass->add_method("write_${name}"  => sub { return scalar affect_data($_[0]->$name, $_[1], $_[2]) });
  $realclass->add_method("delete_${name}" => sub { return scalar delete_data ($_[0]->$name, $_[1]) });
};

1;
