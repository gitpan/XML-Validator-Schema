package XML::Validator::Schema::TypeLibrary;
use strict;
use warnings;

use XML::Validator::Schema::Util qw(XSD _err);
use XML::Validator::Schema::SimpleType;
use Carp qw(croak);

=head1 NAME

XML::Validator::Schema::TypeLibrary

=head1 DESCRIPTION

Internal module used to implement a library of types, simple and
complex.

=head1 USAGE

  # get a new type library, containing just the builtin types
  $library = XML::Validator::Schema::TypeLibrary->new();

  # add a new type
  $library->add(name => 'myString',
                ns   => 'http://my/ns',
                type => $type_obj);

  # lookup a type
  my $type = $library->find(name => 'myString',
                            ns   => 'http://my/ns');

=cut

sub new {
    my $pkg = shift;
    my $self = bless({@_}, $pkg);
    
    # load builtin simple types into XSD namespace
    $self->{XSD()} = { %XML::Validator::Schema::SimpleType::BUILTIN };

    return $self;
}

sub find {
    my ($self, %arg) = @_;

    # HACK: fix when QName resolution works
    $arg{name} =~ s!^[^:]*:!!;
    $arg{ns} ||= XSD;

    return $self->{$arg{ns}}{$arg{name}};
}

sub add {
    my ($self, %arg) = @_;
    croak("Missing required name paramter.") unless $arg{name};
    
    # HACK: fix when QName resolution works
    $arg{name} =~ s!^\w+:!!;
    $arg{ns} ||= XSD;

    _err("Illegal attempt to redefine type '$arg{name}' ".
         "in namespace '$arg{ns}'")
      if exists $self->{$arg{ns}}{$arg{name}};
    $self->{$arg{ns}}{$arg{name}} = $arg{type};
}

1;

