package XML::Validator::Schema::RootNode;
use strict;
use warnings;

use base 'XML::Validator::Schema::ElementNode';

use XML::Validator::Schema::Util qw(_err);

=head1 NAME

XML::Validator::Schema::RootNode - the root node in a schema document

=head1 DESCRIPTION

This is an internal module used by XML::Validator::Schema to represent
the root node in an XML Schema document.  Holds a reference to the
::Library for the schema document and is responsible for hooking up
named types to their uses in the node tree at the end of parsing.

=cut

sub new {
    my $pkg = shift;
    my $self = $pkg->SUPER::new(@_);

    $self->{library} = XML::Validator::Schema::TypeLibrary->new();

    return $self;
}

# register a new named complex type
sub add_complex_type {
    my ($self, $node) = @_;
    my $types = $self->{complex_types} ||= {};
    my $name = $node->name;

    # already saw it?
    _err("Duplicate definition for ComplexType '$name'.")
      if (exists $types->{$name});

    $types->{$name} = $node;    
}

# finish typing using the nodes in complex_types to finish the tree
sub complete_types {
    my $self = shift;

    foreach my $element ($self->descendants, 
                         values(%{$self->{complex_types} || {}})) {
        $self->complete_type($element);
    }
}

sub complete_type {
    my ($self, $element) = @_;
    my $type_map = $self->{complex_types};

    # handle any unresolved attribute types
    if ($element->{attr}) {
        $self->complete_attr_type($_) 
          for (grep { $_->{unresolved_type} } (@{$element->{attr}}));
    }

    # all done unless unresolved
    return unless $element->{unresolved_type};

    # get type data
    my $type = $element->{type_name};
    if (my $complex_type_node = $type_map->{$type}) {

        # can't have daughters for this to work
        _err("Element '<$element->{name}>' is using a named complexType and has sub-elements of its own.  That's not supported.")
          if $element->daughters;
    
        # replace the current element with one based on the complex node
        my $new_node = $complex_type_node->copy_at_and_under;
        $new_node->name($element->{name});
        $element->replace_with($new_node);


    } elsif (my $simple_type = $self->{library}->find(name => $type)) {
        $element->{type} = $simple_type;

    } else {
        # isn't there?
        _err("Element '<$element->{name}>' has unrecognized ".
             "type '$type'.");
    }

    # fixed it
    delete $element->{unresolved_type};
}

sub complete_attr_type {
    my ($self, $attr) = @_;

    my $type = $self->{library}->find(name => $attr->{type_name});
    _err("Attribute '<$attr->{name}>' has unrecognized ".
         "type '$attr->{type_name}'.")
      unless $type;

    $attr->{type} = $type;
    delete $attr->{unresolved_type};
}

1;
