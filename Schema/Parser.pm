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
use XML::Validator::Schema::Util qw(_attr _err);

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
            _err("$_ in <schema> must be 'unqualified', ".
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

    elsif ($name eq 'simpleType') {
        my $name = _attr($data, 'name');
        if ($name) {
            _err("Named simpleType must be global.")
              unless $mother->is_root;

            # this is a named type, parse it into an SimpleTypeNode 
            # and tell Mom about it
            my $node = XML::Validator::Schema::SimpleTypeNode->parse($data);
            $mother->add_daughter($node);
            push @$node_stack, $node;

        } else {
            _err("Anonymous global simpleType not allowed.")
              if $mother->is_root;

            _err("Found <simpleType> illegally combined with <complexType>.")
              if $mother->{is_complex};

            # this is a named type, parse it into an SimpleTypeNode 
            # and tell Mom about it
            my $node = XML::Validator::Schema::SimpleTypeNode->parse($data);
            $mother->add_daughter($node);
            push @$node_stack, $node;

        }
    }
    
    elsif ($name eq 'restriction') {
        _err("Found <restriction> outside a <simpleType> definition.")
          unless $mother->isa('XML::Validator::Schema::SimpleTypeNode');
        $mother->parse_restriction($data);
    }

    elsif ($name eq 'whiteSpace'   or 
           $name eq 'pattern'      or 
           $name eq 'enumeration'  or 
           $name eq 'length'       or 
           $name eq 'minLength'    or 
           $name eq 'maxLength'    or 
           $name eq 'minInclusive' or 
           $name eq 'minExclusive' or 
           $name eq 'maxInclusive' or 
           $name eq 'maxExclusive') {
        _err("Found <$name> outside a <simpleType> definition.")
          unless $mother->isa('XML::Validator::Schema::SimpleTypeNode');
        $mother->parse_facet($data);
    }

    elsif ($name eq 'complexType') {
        my $name = _attr($data, 'name');
        if ($name) {
            _err("Named complexType must be global.")
              unless $mother->is_root;

            # this is a named type, parse it into an ComplexTypeNode 
            # and tell Mom about it
            my $node = XML::Validator::Schema::ComplexTypeNode->parse($data);
            $mother->add_complex_type($node);
            push @$node_stack, $node;

            
        } else {
            _err("Anonymous global complexType not allowed.")
              if $mother->is_root;

            # anonymous complexTypes are just noted and passed on
            $mother->{is_complex} = 1;
        }
            
    }

    elsif ($name eq 'sequence' or $name eq 'choice' or $name eq 'all') {
        # create a new node for the model
        my $node = XML::Validator::Schema::ModelNode->parse($data);
        
        # add to current node's daughter list and become the current node
        $mother->add_daughter($node);
        push @$node_stack, $node;        

        # all needs special support due to the restrictions on its use
        $mother->{is_all} = 1 if $name eq 'all';
    }

    elsif ($name eq 'annotation' or $name eq 'documentation') {
        # skip
    }

    else {
        # getting here is bad news
        _err("Unrecognized element '<$name>' found.");
    }
}

sub end_element {
    my ($self, $data) = @_;
    my $node_stack = $self->{node_stack};
    my $node = $node_stack->[-1];
    my $name = $data->{LocalName};

    # all done?
    if ($name eq 'schema') {
        croak("Module done broke, man.  That element stack ain't empty!")
          unless @$node_stack == 1;

        # complete typing
        $node_stack->[-1]->complete_types();

        return;
    }

    # end of an element?
    if ($name eq 'element') {
        ($node->daughters)[0]->compile 
          if $node->daughters and 
            ($node->daughters)[0]->isa('XML::Validator::Schema::ModelNode');
        pop @$node_stack;
        return;
    }         

    # end of a model?
    if ($name eq 'sequence' or $name eq 'choice' or $name eq 'all') {
        pop @$node_stack;
        return;
    }

    # end of a named complexType?
    if ($name eq 'complexType' and 
        $node->isa('XML::Validator::Schema::ComplexTypeNode')) {
        ($node->daughters)[0]->compile 
          if $node->daughters and 
            ($node->daughters)[0]->isa('XML::Validator::Schema::ModelNode');
        pop @{$self->{node_stack}};
        return;
    }

    # end of named simpleType?
    if ($name eq 'simpleType' and 
        $node->isa('XML::Validator::Schema::SimpleTypeNode')) {
        my $type = $node->compile();
        $node->mother->{type} = $type unless $node->{name};
        $node->mother->remove_daughter($node);
        pop @{$self->{node_stack}};
        return;
    }
        
    # it's ok to fall off the end here, not all elements recognized in
    # start_element need finalizing.
}

1;
