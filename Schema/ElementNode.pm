package XML::Validator::Schema::ElementNode;
use strict;
use warnings;

=head1 NAME

XML::Validator::Schema::ElementNode - an element node in a schema object

=head1 DESCRIPTION

This is an internal module used by XML::Validator::Schema to represent
element nodes derived from XML Schema documents.

=cut

use base qw(Tree::DAG_Node);
use XML::Validator::Schema::Util qw(_attr);
use XML::Validator::Schema::Type qw(check_type supported_type);

# create a node based on the contents of an element hash
sub parse {
    my ($pkg, $data) = @_;
    my $self = $pkg->new();

    my $name = _attr($data, 'name');
    $self->_err('Found element without a name.')
      unless $name;
    $self->name($name);

    my $type = _attr($data, 'type');
    if ($type) {
        unless (supported_type($type)) {
            $self->{unresolved_type} = 1;
        }
        $self->{type} = $type;
    }

    my $min = _attr($data, 'minOccurs');
    $min = 1 unless defined $min;
    $self->_err("Invalid value for minOccurs '$min' found in <$name>.")
      unless $min =~ /^\d+$/;
    $self->{min} = $min;

    my $max = _attr($data, 'maxOccurs');
    $max = 1 unless defined $max;
    $self->_err("Invalid value for maxOccurs '$max' found in <$name>.")
      unless $max =~ /^\d+$/ or $max eq 'unbounded';
    $self->{max} = $max;

    return $self;
}

# check contents of an element against declared type
sub check_contents {
    my ($self, $contents) = @_;

    # do type check if a type is declared
    if ($self->{type} and not check_type($self->{type}, $contents)) {
        $self->_err("Illegal value '$contents' in element <$self->{name}>, declared as '$self->{type}'");
    }

    # mixed content isn't supported, so all complex elements must be
    # element only or have nothing but whitespace between the elements
    if ($self->{is_complex} and $contents =~ /\S/) {
        $self->_err("Illegal character data found in element <$self->{name}>.");
    }
}


# checks whether a given sequence of elements is a valid ordering,
# does not handle min/max checking which are handled at end_element in
# check_min_max()
#
# FIX: should find a way to avoid rechecking preceeding values.
#
# FIX^2: should add min/max checking so that errors can be found
#        before the end of the enclosing element.
sub check_sequence {
    my ($self, @seq) = @_;    
    my @names = map { $_->{name} } $self->daughters;
    my $n = 0;

    foreach my $seq (@seq) {
        if ($names[$n] eq $seq) {
            # it's a match, move on
            next;
        } else {            
            # ran out of names before running through sequence,
            # must be invalid
            return 0 if $n == $#names;

            # retry the next name, it's not this one
            $n++;
            redo;
        }
    }
    
    # got through @seq without running out of @names, @seq is ok
    return 1;
}

# check that min/max constraints are obeyed
sub check_min_max {
    my $self = shift;

    # count em
    my %count;
    foreach my $name (@{$self->{memory}}) {
        $count{$name}++;
    }

    # verify
    foreach my $d ($self->daughters) {
        my $name = $d->{name};
        $count{$name} ||= 0;
        if ($d->{min} == 1 and $count{$name} == 0) {
            $self->_err("<$self->{name}> is missing required element <$name>");
        } elsif ($d->{min} and $count{$name} < $d->{min}) {
            $self->_err("<$self->{name}> does not contain enough <$name> elements, $d->{min} are required.");
        } elsif ($d->{max} ne 'unbounded' and $d->{max} == 1 and 
                 $count{$name} > 1) {
            $self->_err("<$self->{name}> contains too many <$name> elements, only 1 is allowed.");
        } elsif ($d->{max} ne 'unbounded' and $count{$name} > $d->{max}) {
            $self->_err("<$self->{name}> contains too many <$name> elements, only $d->{max} are allowed.");
        }
    }
}

# check if a given name is a legal child, and return it if it is
sub check_daughter {
    my ($self, $name) = @_;
    my ($daughter) = grep { $_->{name} eq $name } ($self->daughters);

    # doesn't even exist?
    $self->_err("Found a '<$name>' was expecting " . 
                $self->expected_daughters())
      unless $daughter;

    # sequence check
    if ($self->{is_sequence} and
        not $self->check_sequence(@{$self->{memory} ||= []}, $name)) {
        $self->_err("Found a '<$name>' out of order.  Contents of <$self->{name}> must match ...");
    }

    # does this daughter have a valid type?  if not, attempt to elaborate
    if ($daughter->{type} and not supported_type($daughter->{type})) {        
        # FIX: should avoid rewalking all elements here
        $self->root->complete_types();
        ($daughter) = grep { $_->{name} eq $name } ($self->daughters);
    }

    # note the event
    push @{$self->{memory} ||= []}, $name;

    return $daughter;
}

# check that attributes are kosher
sub check_attributes {
    my ($self, $data) = @_;

    # get lists required and allowed attributes
    my (@required, %allowed);
    foreach my $attr (@{$self->{attr} || []}) {
        $allowed{$attr->{name}} = $attr;
        push(@required, $attr->{name}) if $attr->{required};
    }

    # check attributes
    my %saw;
    foreach my $jcname (keys %$data) {
        my $attr = $data->{$jcname};

        # attributes in the http://www.w3.org/2001/XMLSchema-instance
        # namespace are processing instructions, not part of the
        # document to be validated
        next if $attr->{NamespaceURI} eq 'http://www.w3.org/2001/XMLSchema-instance';

        # attributes in http://www.w3.org/2000/xmlns/ namespace
        # declarations and don't concern us
        next if $attr->{NamespaceURI} eq 'http://www.w3.org/2000/xmlns/';

        my $name = $attr->{LocalName};
        $self->_err("Illegal attribute '$name' found in <$self->{name}>.")
          unless $allowed{$name};
        $saw{$name} = 1;

        # check value, if attribute is typed
        if ($allowed{$name}->{type} and not 
            check_type($allowed{$name}->{type}, $attr->{Value})) {
            $self->_err("Illegal value '$attr->{Value}' for attribute '$name' in <$self->{name}>, declared as '$allowed{$name}->{type}'");
        }
    }
    
    # make sure all required attributes are present
    foreach my $name (@required) {
        $self->_err("Missing required attribute '$name' " .
                    "in <$self->{name}>.")
          unless $saw{$name};
    }
}


# forget about the past
sub clear_memory {
    delete shift->{memory};
}

# describe the expected daughters of this node
sub expected_daughters {
    my $self = shift;
    return join(' or ', map { "<" . $_->{name} . ">" } $self->daughters);   
}

sub is_root {
    0;
}

# throw a Validator exception
sub _err {
    my $self = shift;
    XML::SAX::Exception::Validator->throw(Message => shift);
}

1;
