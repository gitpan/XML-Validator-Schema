package XML::Validator::Schema;

use 5.006;
use strict;
use warnings;

our $VERSION = '1.00';

=head1 NAME

XML::Validator::Schema - validate XML against a subset of W3C XML Schema

=head1 SYNOPSIS

  use XML::SAX::ParserFactory;
  use XML::Validator::Schema;

  #
  # create a new validator object, using foo.xsd
  #
  $validator = XML::Validator::Schema->new(file => 'foo.xsd');

  #
  # create a SAX parser and assign the validator as a Handler
  #
  $parser = XML::SAX::ParserFactory->parser(Handler => $validator);

  #
  # validate foo.xml against foo.xsd
  #
  eval { $parser->parse_uri('foo.xml') };
  die "File failed validation: $@" if $@;

=head1 DESCRIPTION

This module allows you to validate XML documents against a W3C XML
Schema.  This module does not implement the full W3C XML Schema
recommendation (http://www.w3.org/XML/Schema), but a useful subset.
See the L<SCHEMA SUPPORT|"SCHEMA SUPPORT"> section below.

=head1 INTERFACE

=over 4

=item *

C<< XML::Validator::Schema->new(file => 'file.xsd') >>

Call this method to create a new XML::Validator:Schema object.  The
only available option is C<file> which is required and must provide a
path to an XML Schema document.

Since XML::Validator::Schema is a SAX filter you will normally pass
this object to a SAX parser:

  $validator = XML::Validator::Schema->new(file => 'foo.xsd');
  $parser = XML::SAX::ParserFactory->parser(Handler => $validator);

Then you can proceed to validate files using the parser:

  eval { $parser->parse_uri('foo.xml') };
  die "File failed validation: $@" if $@;

=back

=head1 RATIONALE

I'm writing a piece of software which uses Xerces/C++
( http://xml.apache.org/xerces-c/ ) to validate documents against XML
Schema schemas.  This works very well, but I'd like to release my
project to the world.  Requiring users to install Xerces is simply too
onerous a requirement; few will have it already and the Xerces
installation system leaves much to be desired.

On CPAN, the only available XML Schema validator is XML::Schema.
Unfortunately, this module isn't ready for use as it lacks the ability
to actually parse the XML Schema document format!  I looked into
enhancing XML::Schema but I must admit that I'm not smart enough to
understand the code...  One day, when XML::Schema is completed I will
replace this module with a wrapper around it.

This module represents my attempt to support enough XML Schema syntax
to be useful without attempting to tackle the full standard.  I'm sure
this will mean that it can't be used in all situations, but hopefully
that won't prevent it from being used at all.

=head1 SCHEMA SUPPORT

=head2 Supported Elements

The following elements are supported by the XML Schema parser.  If you
don't see an element or an attribute here then you definitely can't
use it in a schema document. 

You can expect that the schema document parser will produce an error
if you include elements which are not supported.  However, unsupported
attributes I<may> be silently ignored.  This should not be
misconstrued as a feature and will eventually be fixed.

  <schema>

     Supported attributes: targetNamespace, elementFormDefault,
     attributeFormDefault

     Notes: the only supported values for elementFormDefault and
     attributeFormDefault are "unqualified."  As such, targetNamespace
     is essentially ignored.
        
  <element name="foo">

     Supported attributes: name, type, minOccurs, maxOccurs

  <attribute>

     Supported attributes: name, type, use

  <sequence>

  <complexType>

    Supported attributes: name

  <annotation>

  <documentation>

    Supported attributes: name

=head2 Supported Built-In Types

Supported built-in types are:

  string
  boolean
  integer
  int
  dateTime
  NMTOKEN

=head2 Miscellaneous Details

Other known devations from the specification:

=over

=item *

Only a single global element is allowed.

=item *

Global attributes are not supported.

=item *

Named complex types must be global.

=back

=head1 CAVEATS

Here are a few gotchas that you should know about:

=over

=item *

This module has only been tested with XML::Parser.  It's definitely
possibly it could break when used with other SAX parsers.

=item *

Line and column numbers are not included in the generated error
messages.  This should change soon.

=item *

No performance testing or tuning has been done.

=item *

The module doesn't pass-along SAX events and as such isn't ready to be
used as a real SAX filter.  The example in the L<SYNOPSIS|"SYNOPSIS">
works, but that's it.

=back

=head1 BUGS

Please use C<rt.cpan.org> to report bugs in this module:

  http://rt.cpan.org

Please note that I will delete bugs which merely point out the lack of
support for a particular feature of XML Schema.  Those are feature
requests, and believe me, I know we've got a long way to go.

=head1 SUPPORT

This module is supported on the perl-xml mailing-list.  Please join
the list if you have questions, suggestions or patches:

  http://listserv.activestate.com/mailman/listinfo/perl-xml

=head1 CVS

If you'd like to help develop XML::Validator::Schema you'll want to
check out a copy of the CVS tree:

  http://sourceforge.net/cvs/?group_id=89764

=head1 AUTHOR

Sam Tregar <sam@tregar.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2002 Sam Tregar

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl 5 itself.

=head1 A NOTE ON DEVELOPMENT METHODOLOGY

This module isn't just an XML Schema validator, it's also a test of
the Test Driven Development methodology.  I've been writing tests
while I develop code for a while now, but TDD goes further by
requiring tests to be written I<before> code.  One consequence of this
is that the module code may seem naive; it really is I<just enough>
code to pass the current test suite.  If I'm doing it right then there
shouldn't be a single line of code that isn't directly related to
passing a test.  As I add functionality (by way of writing tests) I'll
refactor the code a great deal, but I won't add code only to support
future development.

For more information I recommend "Test Driven Development: By Example"
by Kent Beck.

=head1 SEE ALSO

L<XML::Schema>

http://www.w3.org/XML/Schema

http://xml.apache.org/xerces-c/

=cut

use base qw(XML::SAX::Base); # this module is a SAX filter
use Carp qw(croak);          # make some noise
use XML::SAX::Exception;     # for real
use XML::Filter::BufferText; # keep text together
use XML::SAX::ParserFactory; # needed to parse the schema documents

use XML::Validator::Schema::Parser;
use XML::Validator::Schema::ElementNode;
use XML::Validator::Schema::RootNode;
use XML::Validator::Schema::ComplexTypeNode;
use XML::Validator::Schema::Attribute;

# setup an exception class for validation errors
@XML::SAX::Exception::Validator::ISA = qw(XML::SAX::Exception);

# create a new validation filter
sub new {
    my $pkg  = shift;
    my $opt  = (@_ == 1)  ? { %{shift()} } : {@_};
    my $self = bless $opt, $pkg;

    # check options
    croak("Missing required 'file' option.") unless $self->{file};

    # create an empty element stack
    $self->{node_stack} = [ $self->{element_tree} = 
                               XML::Validator::Schema::RootNode->new ];
    $self->{node_stack}[0]->name('<<<SCHEMA ROOT>>>');

    # load the schema, filling in the element tree
    $self->parse_schema();

    # buffer text for convenience
    my $bf = XML::Filter::BufferText->new( Handler => $self );

    return $bf;
}

# parse an XML schema document, filling $self->{element_tree}
sub parse_schema {
    my $self = shift;

    $self->_err("Specified schema file '$self->{file}' does not exist.")
      unless -e $self->{file};

    # parse the schema file
    my $parser = XML::SAX::ParserFactory->parser(
                   Handler => XML::Validator::Schema::Parser->new(schema => $self));
    $parser->parse_uri($self->{file});
}

# check element start
sub start_element {
    my ($self, $data) = @_;
    my $name = $data->{LocalName};
    my $node_stack = $self->{node_stack};
    my $element = $node_stack->[-1];

    # check that this alright
    my $daughter = $element->check_daughter($name);

    # check attributes
    $daughter->check_attributes($data->{Attributes});

    # enter daughter node
    push(@$node_stack, $daughter);
}

# check character content
sub characters {
    my ($self, $data) = @_;
    my $element = $self->{node_stack}[-1];
    $element->check_contents($data->{Data});
}

# finish element checking
sub end_element {
    my ($self, $data) = @_;
    my $node_stack = $self->{node_stack};
    my $element = $node_stack->[-1];

    $element->check_min_max();

    # done
    $element->clear_memory();
    pop(@$node_stack);
}

# throw a Validator exception
sub _err {
    my $self = shift;
    XML::SAX::Exception::Validator->throw(Message => shift);
}

1;
