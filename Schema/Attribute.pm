package XML::Validator::Schema::Attribute;
use strict;
use warnings;

use XML::Validator::Schema::Util qw(_attr);
use XML::Validator::Schema::Type qw(supported_type);

sub new {
    my ($pkg, %arg) = @_;
    my $self = bless \%arg, $pkg;    
}

# create an attribute based on the contents of an element hash
sub parse {
    my ($pkg, $data) = @_;
    my $self = $pkg->new();

    my $name = _attr($data, 'name');
    $self->_err('Found <attribute> without a name.')
      unless $name;
    $self->{name} = $name;

    my $type = _attr($data, 'type');
    if ($type) {
        $self->_err(qq{Attribute '$name' has an unsupported type: $type.})
          unless supported_type($type);
        $self->{type} = $type;
    }

    # load use, defaults to optional
    my $use = _attr($data, 'use') || 'optional';
    $self->_err("Invalid 'use' value in <attribute name='$name'>: '$use'.") 
      unless $use eq 'optional' or $use eq 'required';
    $self->{required} = $use eq 'required' ? 1 : 0;

    return $self;
}

# throw a Validator exception
sub _err {
    my $self = shift;
    XML::SAX::Exception::Validator->throw(Message => shift);
}

1;

