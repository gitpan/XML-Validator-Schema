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
our @EXPORT = ('test_yml');

use YAML qw(LoadFile);
use XML::SAX::ParserFactory;
use XML::Validator::Schema;

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

        if ($result =~ m!^FAIL\s*(?:/(.*?)/)?$!) {
            my $re = $1;
            $Test->ok($@, "$prefix.yml: block $num should fail validation");
            if ($re) {
                $Test->like($@, qr/$re/, 
                     "$prefix.yml: block $num should fail matching /$re/");
            }
        } else {
            $Test->ok(not($@), "$prefix.yml: block $num should pass validation");
            print STDERR "$prefix.yml: block $num ====> $@\n" if $@;
        }
    }

    # cleanup
    unlink "t/$prefix.xsd" or die $!;
}

1;
