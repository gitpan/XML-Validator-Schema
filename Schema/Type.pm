package XML::Validator::Schema::Type;

use strict;
use warnings;

use Carp qw(croak);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(check_type supported_type);

our %SUPPORTED_TYPES = 
  map { $_ => 1 } qw( string boolean integer int dateTime NMTOKEN );
   
# returns 1 if this type is supported by check_type, 0 if not
sub supported_type {
    my $type = shift;
    $type =~ s!.*?:!!; # strip off namespace

    return 1 if $SUPPORTED_TYPES{$type};
    return 0;
}

# checks a value against a specified type.  Returns true if the value
# passes muster or false if not.
sub check_type {
    my $type = shift;
    local $_ = shift;
    $type =~ s!.*?:!!; # strip off namespace

    croak("check_type called with unsupported data type '$type'!")
      unless ($SUPPORTED_TYPES{$type});

    if ($type eq 'string') {
        # nothing to do?
        return 1;
    }

    if ($type eq 'boolean') {
        return 1 if $_ eq '1' or $_ eq '0' or $_ eq 'true' or $_ eq 'false';
        return 0;
    }

    if ($type eq 'integer') {
        return 1 if /^[-+]?\d+$/;
        return 0;
    }

    if ($type eq 'int') {
        return 1 if /^[-+]?\d+$/ and $_ >= -2147483648 and $_ <= 2147483647;
        return 0;
    }

    if ($type eq 'dateTime') {
        return 1 if /^[-+]?
                      (\d{4,})-\d{2}-\d{2}  # CCCC...-MM-DD
                      T 
                      \d{2}:\d{2}:\d{2}     # hh:mm:ss
                      (?:\.\d+)?            # .sss...
                      (?:
                        (?:Z)               # Z == +00:00
                        |
                        (?:[-+]\d{2}:\d{2}) # +hh:mm
                      )?
                    /x;
        return 0;
    }

    if ($type eq 'NMTOKEN') {
        return 1 if /^[-_.:\w\d]*$/;
        return 0;
    }

    croak("Fell through check_type(). That shouldn't happen!");
}

1;
