use Test::More;
use strict; use warnings;
use xt::Test;

for my $grammar (test_grammar_paths) {
    my $parser = pegex_parser;
    my $input = slurp($grammar);
    my $timer = [gettimeofday];
    my $result = eval { $parser->parse($input) };
    my $time = tv_interval($timer);
    if ($result) {
        pass "$grammar parses in $time seconds";
    }
    else {
        fail "$grammar failed to parse $@";
    }
}

done_testing;
