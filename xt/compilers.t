# BEGIN { $TestML::Test::Differences = 1 }
# BEGIN { $Pegex::Parser::Debug = 1 }
# BEGIN { $Pegex::Bootstrap = 1 }

use Test::More;
use strict; use warnings;
use xt::Test;
use Pegex::Bootstrap;
use Pegex::Compiler;
use YAML::XS;

for my $grammar (test_grammar_paths) {
    my $expected = eval {
        Dump(Pegex::Bootstrap->new->parse(slurp($grammar))->tree);
    } or next;
    my $got = eval {
        Dump(Pegex::Bootstrap->new->parse(slurp($grammar))->tree);
    } or die "$grammar failed to compile: $@";
    is $got, $expected,
        "Bootstrap compile matches normal compile for $grammar";
}

done_testing;
