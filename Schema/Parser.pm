package XML::Validator::Schema::Parser;
use strict;
use warnings;

=head1 NAME

XML::Validator::Schema::Parser - XML Schema Document Parser

=head1 DESCRIPTION

This is an internal module used by XML::Validator::Schema to parse XML
Schema documents.

=cut


use base 'XML::SAX::Base';
use Data::Dumper;
use XML::Validator::Schema::Util qw(_attr);

sub new {
    my $pkg  = shift;
    my $opt  = (@_ == 1)  ? { %{shift()} } : {@_};
    my $self = bless $opt, $pkg;    

    # start with a dummy root node and an empty stack of elements
    $self->{node_stack} = $self->{schema}{node_stack};
    
    return $self;
}

sub start_element {
    my ($self, $data) = @_;
    my $node_stack = $self->{node_stack};
    my $mother = $node_stack->[-1];
    my $name = $data->{LocalName};
    
    # starting up?
    if ($name eq 'schema') {
        $self->{in_schema} = 1;

        # make sure elementFormDefault and attributeFormDefault are
        # 'unqualified' if declared since that's all we're up to
        for (qw(elementFormDefault attributeFormDefault)) {
            my $a = _attr($data, $_);
            $self->_err("$_ in <schema> must be 'unqualified', ".
                        "'qualified' is not supported.")
              if $a and $a ne 'unqualified';
        }

        # ignoring targetSchema intentionally.  With both Defaults
        # unqualified there isn't much point looking at it.
    }
    
    # handle element declaration
    elsif ($name eq 'element') {
        # create a new node for the element
        my $node = XML::Validator::Schema::ElementNode->parse($data);
        
        # add to current node's daughter list and become the current node
        $mother->add_daughter($node);
        push @$node_stack, $node;
    }

    elsif ($name eq 'attribute') {
        push @{$mother->{attr} ||= []}, 
             XML::Validator::Schema::Attribute->parse($data);
    }
    
    elsif ($name eq 'complexType') {
        my $name = _attr($data, 'name');
        if ($name) {
            $self->_err("Named complexType must be global.")
              unless $mother->is_root;

            # this is a named type, parse it into an ComplexTypeNode 
            # and tell Mom about it
            my $node = XML::Validator::Schema::ComplexTypeNode->parse($data);
            $mother->add_complex_type($node);
            push @$node_stack, $node;

            
        } else {
            $self->_err("Anonymous global complexType not allowed.")
              if $mother->is_root;

            # anonymous complexTypes are just noted and passed on
            $mother->{is_complex} = 1;
        }
            
    }

    elsif ($name eq 'sequence') {
        $mother->{is_sequence} = 1;
    }

    elsif ($name eq 'annotation' or $name eq 'documentation') {
        # skip
    }

    else {
        # getting here is bad news
        $self->_err("Unrecognized element '<$name>' found.");
    }
}

sub end_element {
    my ($self, $data) = @_;
    my $node_stack = $self->{node_stack};

    # all done?
    if ($data->{LocalName} eq 'schema') {
        croak("Module done broke, man.  That element stack ain't empty!")
          unless @$node_stack == 1;

        # complete typing
        $node_stack->[-1]->complete_types();

        return;
    }

    # end of an element?
    if ($data->{LocalName} eq 'element') {
        pop @$node_stack;
        return;
    }         

    # end of a named complexType?
    if ($data->{LocalName} eq 'complexType' and 
        $node_stack->[-1]->isa('XML::Validator::Schema::ComplexTypeNode')) {
        pop @{$self->{node_stack}};
        return;
    }         

    # it's ok to fall off the end here, not all elements recognized in
    # start_element need finalizing.
}

# throw a Validator exception.  Do I care that this sub appears in the
# stack trace?  Unsure.
sub _err {
    my $self = shift;
    XML::SAX::Exception::Validator->throw(Message => shift);
}

1;
