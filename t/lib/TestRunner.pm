# YAML test runner for XML::Validator::Schema.  Takes .yml files
# containing a schema and applies it to one or more files evaluating
# the results as specified.  Just look at t/*.yml and you'll get the
# idea.

package TestRunner;
use strict;
use warnings;

use Test::Builder;
my $Test = Test::Builder->new;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = ('test_yml', 'foreach_parser');

use YAML qw(LoadFile);
use XML::SAX::ParserFactory;
use XML::Validator::Schema;
use XML::SAX;

use Data::Dumper;

sub foreach_parser (&) {
    my $tests = shift;

    my @parsers = map { $_->{Name} } (@{XML::SAX->parsers});
    @parsers = ($ENV{XMLVS_TEST_PARSER}) if exists $ENV{XMLVS_TEST_PARSER};
    
    # remove XML::LibXML::SAX::Parser from this list.  what is that anyway?
    @parsers = grep { $_ ne 'XML::LibXML::SAX::Parser' } @parsers;

    # run tests with all available parsers
    foreach my $pkg (@parsers) {
        $XML::SAX::ParserPackage = $pkg;    
        
        # make sure the parser is available
        my $parser = XML::SAX::ParserFactory->parser();
        print STDERR "\n\n                ======> Testing against $pkg ".
          "<======\n\n";
        $tests->();            
    }
}

sub test_yml {
    my $file = shift;
    my ($prefix) = $file =~ /(\w+)\.yml$/;
    my @data = LoadFile($file);

    # write out the schema file
    my $xsd = shift @data;
    open(my $fh, '>', "t/$prefix.xsd") or die $!;
    print $fh $xsd;
    close($fh) or die $!;

    my $num = 0;
    while(@data) {
        my $xml = shift @data;
        my $result = shift @data;
        chomp($result);
        $num++;

        # run the xml through the parser
        eval { 
            my $parser = XML::SAX::ParserFactory->parser(
              Handler => XML::Validator::Schema->new(file => 
                                                     "t/$prefix.xsd"));
            $parser->parse_string($xml) 
        };
        my $err = $@;

        if ($result =~ m!^FAIL\s*(?:/(.*?)/)?$!) {
            my $re = $1;
            $Test->ok($err, "$prefix.yml: block $num should fail validation");
            if ($re) {
                if ($err) {
                    $Test->like($err, qr/$re/, 
                                "$prefix.yml: block $num should fail matching /$re/");
                } else {
                    $Test->ok(0, "$prefix.yml: block $num should fail matching /$re/");
                }
            }
        } else {
            $Test->ok(not($err), "$prefix.yml: block $num should pass validation");
            print STDERR "$prefix.yml: block $num ====> $@\n" if $err;
        }
    }

    # cleanup
    unlink "t/$prefix.xsd" or die $!;
}

1;
