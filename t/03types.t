#!/usr/bin/perl
use strict;
use warnings;

use Test::More qw(no_plan);
use XML::Validator::Schema::Type qw(check_type supported_type);

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
