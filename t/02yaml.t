#!/usr/bin/perl
use strict;
use warnings;
use lib 't/lib';

use Test::More qw(no_plan);
use TestRunner qw(test_yml foreach_parser);

foreach_parser {
    test_yml('t/foo.yml');
    test_yml('t/two_level.yml');
    test_yml('t/sequence.yml');
    test_yml('t/multi_level.yml');
    test_yml('t/attribute.yml');
    test_yml('t/attribute_types.yml');
    test_yml('t/bad_attribute_type.yml');
    test_yml('t/element_type.yml');
    test_yml('t/media.yml');
    test_yml('t/qualified.yml');
    test_yml('t/global_type.yml');
    test_yml('t/simple_recursion.yml');
    test_yml('t/recursive.yml');
    test_yml('t/choice.yml');
    test_yml('t/all.yml');    
    test_yml('t/bad_all.yml');
};
