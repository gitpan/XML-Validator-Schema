package XML::Validator::Schema::Util;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(_attr);

# get an attribute value by name, ignoring namespaces
sub _attr {
    my ($data, $name) = @_;
    return $data->{Attributes}{'{}' . $name}{Value}
      if exists $data->{Attributes}{'{}' . $name};
    foreach my $attr (keys %{$data->{Attributes}}) {
        return $data->{$attr}->{Value} if $attr =~ /^\{.*?\}$name/;
    }
    return;
}

1;
