#!/usr/bin/perl
use strict;
use warnings;

use Test::More qw(no_plan);
use XML::Validator::Schema::TypeLibrary;
my $lib = XML::Validator::Schema::TypeLibrary->new();

sub supported_type {
    return 1 if $lib->find(name => shift);
    return 0;
}

our $LAST_MSG;
sub check_type {
    my $type = $lib->find(name => shift);
    return 0 unless $type;
    my ($ok, $msg) = $type->check(shift);
    $LAST_MSG = $msg;
    return $ok;
}
    

ok(supported_type('string'));
ok(check_type(string => "any ol' thang"));
ok(check_type(string => ""));

ok(supported_type('integer'));
ok(check_type(integer => "1"));
ok(check_type(integer => "-1"));
ok(check_type(integer => "2147483647"));
ok(check_type(integer => "-2147483648"));
ok(check_type(integer => "12147483648"));
ok(check_type(integer => "-12147483648"));

ok(supported_type('int'));
ok(check_type(int => "1"));
ok(check_type(int => "-1"));
ok(check_type(int => "2147483647"));
ok(check_type(int => "-2147483648"));
ok(not check_type(int => "12147483648"));
ok(not check_type(int => "-12147483648"));

ok(supported_type('unsignedInt'));
ok(check_type(unsignedInt => "1"));
ok(not check_type(unsignedInt => "-1"));
ok(check_type(unsignedInt => "2147483647"));
ok(not check_type(unsignedInt => "-2147483648"));
ok(not check_type(unsignedInt => "12147483648"));
ok(not check_type(unsignedInt => "-12147483648"));

ok(supported_type('short'));
ok(check_type(short => "1"));
ok(check_type(short => "-1"));
ok(not check_type(short => "2147483647"));
ok(not check_type(short => "-2147483648"));

ok(supported_type('unsignedShort'));
ok(check_type(unsignedShort => "1"));
ok(not check_type(unsignedShort => "-1"));
ok(not check_type(unsignedShort => "2147483647"));
ok(not check_type(unsignedShort => "-2147483648"));

ok(supported_type('byte'));
ok(check_type(byte => "1"));
ok(check_type(byte => "-1"));
ok(not check_type(byte => "255"));
ok(not check_type(byte => "-255"));

ok(supported_type('unsignedByte'));
ok(check_type(unsignedByte => "1"));
ok(not check_type(unsignedByte => "-1"));
ok(check_type(unsignedByte => "255"));
ok(not check_type(unsignedByte => "-255"));

ok(supported_type('boolean'));
ok(check_type(boolean => "0"));
ok(check_type(boolean => "1"));
ok(check_type(boolean => "true"));
ok(check_type(boolean => "false"));
ok(not check_type(boolean => "foo"));

ok(supported_type('dateTime'));
ok(check_type(dateTime => "1999-05-31T13:20:00-05:00"));
ok(check_type(dateTime => "1999-05-31T13:20:00+05:00"));
ok(check_type(dateTime => "1999-05-31T13:20:00"));
ok(check_type(dateTime => "1999-05-31T13:20:00Z"));
ok(check_type(dateTime => "-1999-05-31T13:20:00Z"));
ok(check_type(dateTime => "+1999-05-31T13:20:00Z"));
ok(not check_type(dateTime => "99-05-31T13:20:00-05:00"));

ok(supported_type('NMTOKEN'));
ok(check_type(NMTOKEN => ""));
ok(check_type(NMTOKEN => "sam"));
ok(check_type(NMTOKEN => "123sam.-_:"));
ok(not check_type(NMTOKEN => "123sam.-_:!"));

ok(supported_type('normalizedString'));
ok(check_type(normalizedString => ""));
ok(check_type(normalizedString => "sam"));
ok(check_type(normalizedString => "\n\ns\na\nm\n\n"));

ok(supported_type('token'));
ok(check_type(normalizedString => ""));
ok(check_type(normalizedString => "sam"));
ok(check_type(normalizedString => "\n\ns\na\nm\n\n"));

ok(supported_type('double'));
ok(check_type(double => '-1E4'));
ok(check_type(double => '1267.43233E12'));
ok(check_type(double => '12.78e-2'));
ok(check_type(double => '12'));
ok(check_type(double => '012'));
ok(check_type(double => 'INF'));
ok(not check_type(double => 'A'));
ok(not check_type(double => 'b10.5'));
ok(not check_type(double => ''));
