package XML::Validator::Schema::Attribute;
use strict;
use warnings;

=head1 NAME

XML::Validator::Schema::Attribute - an attribute node in a schema object

=head1 DESCRIPTION

This is an internal module used by XML::Validator::Schema to represent
attributes derived from XML Schema documents.

=cut

use XML::Validator::Schema::Util qw(_attr _err);

sub new {
    my ($pkg, %arg) = @_;
    my $self = bless \%arg, $pkg;    
}

# create an attribute based on the contents of an element hash
sub parse {
    my ($pkg, $data) = @_;
    my $self = $pkg->new();

    my $name = _attr($data, 'name');
    _err('Found <attribute> without a name.')
      unless $name;
    $self->{name} = $name;

    my $type_name = _attr($data, 'type');
    if ($type_name) {
        $self->{unresolved_type} = 1;
        $self->{type_name} = $type_name;
    }

    # load use, defaults to optional
    my $use = _attr($data, 'use') || 'optional';
    _err("Invalid 'use' value in <attribute name='$name'>: '$use'.") 
      unless $use eq 'optional' or $use eq 'required';
    $self->{required} = $use eq 'required' ? 1 : 0;

    return $self;
}

1;

