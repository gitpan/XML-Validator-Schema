package XML::Validator::Schema::SimpleTypeNode;
use base 'XML::Validator::Schema::Node';
use strict;
use warnings;

use XML::Validator::Schema::Util qw(_attr _err);
use Carp qw(confess);

=head1 NAME

XML::Validator::Schema::SimpleTypeNode

=head1 DESCRIPTION

Temporary node in the schema parse tree to represent a simpleType.

=cut

# Hash mapping facet names to allowable values
our %FACET_VALUE = (length =>         "nonNegativeInteger",
                    minLength =>      "nonNegativeInteger",
                    maxLength =>      "nonNegativeInteger",
                    totalDigits =>    "positiveInteger",
                    fractionDigits => "nonNegativeInteger");

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
    $self->check_facet_value($facet, $value, $FACET_VALUE{$facet}) if defined $FACET_VALUE{$facet};

    push @{$self->{restrictions}{$facet} ||= []}, $value;
}

sub compile {
    my ($self) = shift;

    # compile a new type
    my $base = $self->root->{type_library}->find(name => $self->{base});
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
    $self->root->{type_library}->add(name => $self->{name},
                                     obj  => $type)
      if $self->{name};

    return $type;
}

sub check_facet_value {
  my ($self, $facet, $value, $type_name) = @_;
  my ($ok, $msg) = $self->root->{type_library}->find(name => $type_name)->check($value);
  _err("Facet <$facet> value $value is not a $type_name")
    unless $ok;
}

sub check_constraints {
  my ($self) = @_;
  my $r = $self->{restrictions};

  # Schema Component Constraint: fractionDigits-totalDigits
  if (exists $r->{fractionDigits} && exists $r->{totalDigits}) {
    _err("Facet <fractionDigits> value $r->{fractionDigits}[0] is greater than facet <totalDigits> value $r->{totalDigits}[0]")
      if ($r->{fractionDigits}[0] > $r->{totalDigits}[0]);
  }

  # Schema Component Constraint: length-minLength-maxLength
  _err("Facet <length> is defined in addition to facets <minLength> or <maxLength>")
    if (exists $r->{length} && (exists $r->{minLength} || exists $r->{maxLength}));

  # Schema Component Constraint: minLength-less-than-equal-to-maxLength
  if (exists $r->{minLength} && exists $r->{maxLength}) {
    _err("Facet <minLength> value $r->{minLength}[0] is greater than than facet <maxLength> value $r->{maxLength}[0]")
      if ($r->{minLength}[0] > $r->{maxLength}[0]);
  }
}

1;
