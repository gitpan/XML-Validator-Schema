use 5.006;

use ExtUtils::MakeMaker;
WriteMakefile(
    NAME		=> 'XML::Validator::Schema',
    VERSION_FROM	=> 'Schema.pm', 
    PREREQ_PM		=> { 
                            'Test::More'              => 0.47,
                            'XML::SAX'                => 0.12,
                            'Carp'                    => 0,
                            'Tree::DAG_Node'          => 0,
                            'XML::Filter::BufferText' => 0,
                           },
    ABSTRACT_FROM       => 'Schema.pm',
    AUTHOR              => 'Sam Tregar <sam@tregar.com>');
