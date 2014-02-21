# NOTE:
# This algorithm should be rewritten as a proper token -> infix ->
# shunting-yard -> RPN -> evaluate to AST... parser.
# It should treat % as a proper infix operator with right precedence.
package Pegex::Bootstrap;

use Pegex::Base;
extends 'Pegex::Compiler';

use Pegex::Grammar::Atoms;

my $modifier = qr{[\!\=\-\+\.]};
my $group_modifier = qr{[\.]};
my $quantifier = qr{(?:[\?\*\+]|\d+(?:\+|\-\d+)?)};
my %prefixes = (
    '!' => ['+asr', -1],
    '=' => ['+asr', 1],
    '.' => '-skip',
    '-' => '-pass',
    '+' => '-wrap',
);

sub parse {
    my ($self, $grammar_text) = @_;
    $self = $self->new unless ref $self;

    # If the grammar looks like a filename, try to read that file for the
    # grammar content.
    if (length($grammar_text) and $grammar_text !~ /(\s|\:|\#|\%)/) {
        open IN, $grammar_text
            or die "Can't open file '$grammar_text' for input";
        $grammar_text = do {local $/; <IN>};
        close IN;
    }
    $self->{tree} = {};

    # Remove comment lines
    $grammar_text =~ s/^#.*\n+//gm;

    # Remove trailing comments
    $grammar_text =~ s/\ +#.*//g;

    # Remove blank lines
    $grammar_text =~ s/^\s*\n//gm;

    # Turn semis into line breaks
    $grammar_text =~ s/;/\n/g;

    # Ensure trailing newline
    $grammar_text .= "\n" unless
        $grammar_text eq '' or
        $grammar_text =~ /\n\z/;

    # Process directives
    if ($grammar_text =~ s/\A((%\w+ +.*\n)+)//) {
        my $section = $1;
        my (@directives) = ($section =~ /%(\w+) +(.*?) *\n/g);
        my $tree = $self->tree;
        while (@directives) {
            my ($key, $val) = splice(@directives, 0, 2);
            die "'$key' is an invalid Pegex directive"
                unless $key =~ /^(grammar|version|extends|include)$/;
            $key = "+$key";
            my $old = $tree->{$key};
            if (defined $old) {
                if (ref $old) {
                    push @$old, $val;
                }
                else {
                    $tree->{$key} = [ $old, $val ];
                }
            }
            else {
                $tree->{$key} = $val;
            }
        }
    }

    for my $rule (split /(?=^[\w\-]+:\s*)/m, $grammar_text) {
        (my $value = $rule) =~ s/^([\w-]+):// or die "$rule";
        (my $key = $1) =~ s/-/_/g;
        $value =~ s/\s+/ /g;
        $value =~ s/^\s*(.*?)\s*$/$1/;
        $self->{tree}->{$key} = $value;
        $self->{tree}->{'+toprule'} ||= $key;
        $self->{tree}->{'+toprule'} = $key if $key eq 'TOP';
    }

    for my $rule (sort keys %{$self->{tree}}) {
        next if $rule =~ /^\+/;
        my $text = $self->{tree}->{$rule};
        my @tokens = map {
            s/-(?!\d)/_/g if /^\-+$/ or not /^[\`\/\-]/;
            s/(?<![\w\>])\++/__/g if /^\++$/ or not /^[\)\`\/\+]/;
            $_;
        } grep $_,
        ($text =~ m{(
            `[^`\n]*` |
            /[^/\n]*/ |
            ~+ |
            \-+(?=\s|$) |
            \++(?=\s|$) |
            %%? |
            $modifier?<[\w\-]+>$quantifier? |
            $modifier?[\w\-]+$quantifier? |
            \| |
            $group_modifier?\( |
            \)$quantifier? |
        )}gx);
        die "No tokens found for rule <$rule> => '$text'"
            unless @tokens;
        unshift @tokens, '(';
        push @tokens, ')';
        my $tree = $self->make_tree(\@tokens);
        $self->{tree}->{$rule} = $self->compile_next($tree);
    }
    return $self;
}

sub make_tree {
    my ($self, $tokens) = @_;
    my $stack = [];
    my $tree = [];
    push @$stack, $tree;
    for my $token (@$tokens) {
        if ($token =~ /^$group_modifier?\(/) {
            push @$stack, [];
        }
        push @{$stack->[-1]}, $token;
        if ($token =~ /^\)/) {
            my $branch = pop @$stack;
            push @{$stack->[-1]}, $self->wilt($branch);
        }
    }
    return $tree->[0];
}

sub wilt {
    my ($self, $branch) = @_;
    return $branch unless ref($branch) eq 'ARRAY';
    my $wilted = [];
    for (my $i = 0; $i < @$branch; $i++) {
        push @$wilted, ($branch->[$i] =~ /^%%?$/)
            ? [$branch->[$i], pop(@$wilted), $branch->[++$i]]
            : $branch->[$i];
    }
    if (grep {$_ eq '|'} @$wilted) {
        my @group;
        my @grouped = shift @$wilted;   # '('
        shift @$wilted if $wilted->[0] eq '|';
        for (@$wilted) {
            if (/^(?:\||\)$quantifier?)$/) {
                push @grouped, (
                    (@group == 1
                        ? $group[0]
                        : ['(', @group, ')']
                    ), $_
                );
                @group = ();
            }
            else {
                push @group, $_;
            }
        }
        $wilted = \@grouped;
    }
    return $wilted;
}

sub compile_next {
    my ($self, $node) = @_;
    my $unit = ref($node) ?
        $node->[0] =~ /^%%?$/
            ? $self->compile_sep($node) :
        $node->[2] eq '|'
            ? $self->compile_group($node, 'any')
            : $self->compile_group($node, 'all')
    :
        $node =~ /^~+$/ ? $self->compile_ws($node) :
        $node =~ m!^`! ? $self->compile_error($node) :
        $node =~ m!/! ? $self->compile_re($node) :
        $node =~ m!<! ? $self->compile_rule($node) :
        $node =~ m!^$modifier?[\w\-]+$quantifier?$!
            ? $self->compile_rule($node) :
            die $node;

    while (defined $unit->{'.all'} and @{$unit->{'.all'}} == 1) {
        $unit = $unit->{'.all'}->[0];
    }
    return $unit;
}

sub compile_group {
    my ($self, $node, $type) = @_;
    die unless @$node > 2;
    my $object = {};
    if ($node->[0] =~ /^($modifier)/) {
        my ($key, $val) = ($prefixes{$1}, 1);
        ($key, $val) = @$key if ref $key;
        $object->{$key} = $val;
    }
    if ($node->[-1] =~ /($quantifier)$/) {
        $self->set_quantity($object, $1);
    }
    shift @$node;
    pop @$node;
    if ($type eq 'any') {
        $object->{'.any'} = [
            map $self->compile_next($_), grep {$_ ne '|'} @$node
        ];
    }
    elsif ($type eq 'all') {
        $object->{'.all'} = [
            map $self->compile_next($_), @$node
        ];
    }
    return $object;
}

sub compile_re {
    my ($self, $node) = @_;
    my $object = {};
    $node =~ s!^/(.*)/$!$1! or die $node;
    $node =~ s/(?:^|\s)(\-+)(?:\s|$)/'<' . '_' x length($1) . '>'/ge;
    $node =~ s/(?:^|\s)(\++)(?:\s|$)/'<' . '__' x length($1) . '>'/ge;
    $node =~ s!\s+!!g;
    $node =~ s!\((\:|\=|\!)!(?$1!g;
    $object->{'.rgx'} = $node;
    return $object;
}

sub compile_rule {
    my ($self, $node) = @_;
    my $object = {};
    if ($node =~ s/^($modifier)//) {
        my ($key, $val) = ($prefixes{$1}, 1);
        ($key, $val) = @$key if ref $key;
        $object->{$key} = $val;
    }
    if ($node =~ s/($quantifier)$//) {
        $self->set_quantity($object, $1);
    }
    $node =~ s!^<(.*)>$!$1!;
    $object->{'.ref'} = $node;
    if (defined(my $re = Pegex::Grammar::Atoms->atoms->{$node})) {
        $self->tree->{$node} ||= {'.rgx' => $re};
    }
    return $object;
}

sub compile_error {
    my ($self, $node) = @_;
    my $object = {};
    $node =~ s!^`(.*)`$!$1! or die $node;
    $object->{'.err'} = $node;
    return $object;
}

sub compile_sep {
    my ($self, $node) = @_;
    my $object = $self->compile_next($node->[1]);
    $object->{'.sep'} = $self->compile_next($node->[2]);
    $object->{'.sep'}{'+eok'} = 1 if $node->[0] eq '%%';
    return $object;
}

sub compile_ws {
    my ($self, $node) = @_;
    my $regex = '<ws' . length($node) . '>';
    return { '.rgx' => $regex };
}

sub set_quantity {
    my ($self, $object, $quantifier) = @_;
    if ($quantifier eq '*') {
        $object->{'+min'} = 0;
    }
    elsif ($quantifier eq '+') {
        $object->{'+min'} = 1;
    }
    elsif ($quantifier eq '?') {
        $object->{'+max'} = 1;
    }
    elsif ($quantifier =~ /^(\d+)\+$/) {
        $object->{'+min'} = $1;
    }
    elsif ($quantifier =~ /^(\d+)\-(\d+)+$/) {
        $object->{'+min'} = $1;
        $object->{'+max'} = $2;
    }
    elsif ($quantifier =~ /^(\d+)$/) {
        $object->{'+min'} = $1;
        $object->{'+max'} = $1;
    }
    else { die "Invalid quantifier: '$quantifier'" }
}

1;
