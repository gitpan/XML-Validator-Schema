package XML::Validator::Schema::RootNode;
use base 'XML::Validator::Schema::ElementNode';

=head1 NAME

XML::Validator::Schema::RootNode - the root node in a schema document

=head1 DESCRIPTION

This is an internal module used by XML::Validator::Schema to represent
the root node in an XML Schema document.

=cut

# register a new named complex type
sub add_complex_type {
    my ($self, $node) = @_;
    my $types = $self->{complex_types} ||= {};
    my $name = $node->name;

    # already saw it?
    $self->_err("Duplicate definition for ComplexType '$name'.")
      if (exists $types->{$name});

    $types->{$name} = $node;    
}

# finish typing using the nodes in complex_types to finish the tree
sub complete_types {
    my $self = shift;
    my $type_map = $self->{complex_types};

    foreach my $element ($self->descendants) {
        next unless $element->{unresolved_type};
        my $type = $element->{type};
        my $type_node = $type_map->{$type};
        
        # isn't there?
        $self->_err("Element '<$element->{name}>' has unrecognized ".
                    "type '$type'.")
          unless $type_node;        

        # can't have daughters for this to work
        $self->_err("Element '<$element->{name}>' is using a named complexType and has sub-elements of its own.  That's not supported.")
          if $element->daughters;

        # replace the current element with one based on the complex node
        my $new_node = $type_node->copy_at_and_under;
        $new_node->name($element->{name});
        $element->replace_with($new_node);
    }
}

sub is_root {
    1;
}

1;
