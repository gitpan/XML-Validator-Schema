package XML::Validator::Schema::SimpleTypeNode;
use base 'XML::Validator::Schema::Node';
use strict;
use warnings;

use XML::Validator::Schema::Util qw(_attr _err);

=head1 NAME

XML::Validator::Schema::SimpleTypeNode

=head1 DESCRIPTION

Temporary node in the schema parse tree to represent a simpleType.

=cut

sub parse {
    my ($pkg, $data) = @_;
    my $self = $pkg->new();

    my $name = _attr($data, 'name');
    $self->name($name) if $name;

    $self->{restrictions} = {};

    return $self;
}

sub parse_restriction {
    my ($self, $data) = @_;

    my $base = _attr($data, 'base');
    _err("Found restriction without required 'base' attribute.")
      unless $base;
    $self->{base} = $base;
}

sub parse_facet {
    my ($self, $data) = @_;
    my $facet = $data->{LocalName};

    my $value = _attr($data, 'value');
    _err("Found facet <$facet> without required 'value' attribute.")
      unless defined $value;

    push @{$self->{restrictions}{$facet} ||= []}, $value;
}

sub compile {
    my ($self) = shift;

    # compile a new type
    my $base = $self->root->{library}->find(name => $self->{base});
    my $type = $base->derive();
    
    # smoke 'em if you got 'em
    $type->{name} =  $self->{name} if $self->{name};
    
    # add restrictions
    foreach my $facet (keys %{$self->{restrictions}}) {
        foreach my $value (@{$self->{restrictions}{$facet}}) {
            if ($facet eq 'pattern') {
                $type->restrict($facet, qr/^$value$/);
            } else {
                $type->restrict($facet, $value);
            }
        }
    }

    # register in the library if this is a named type
    $self->root->{library}->add(name => $self->{name},
                                type => $type)
      if $self->{name};

    return $type;
}

1;
