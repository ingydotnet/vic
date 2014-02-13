package VIC::PIC;
use strict;
use warnings;
use POSIX ();

use Pegex::Base;
extends 'Pegex::Tree';

use VIC::PIC::Any;

# use XXX;
has pic_override => undef;
has pic => undef;
has ast => {
    block_stack => [],
    block_stack_top => 0,
    funcs => {},
    variables => {},
};

sub throw_error { shift->parser->throw_error(@_); }

sub got_uc_select {
    my ($self, $type) = @_;
    # override the PIC in code if defined
    $type = $self->pic_override if defined $self->pic_override;
    $type = lc $type;
    # assume supported type else return
    $self->pic(VIC::PIC::Any->new($type));
    die "$type is not a supported chip" unless $self->pic->type eq $type;
    $self->ast->{include} = $self->pic->include;
    # set the defaults in case the headers are not provided by the user
    $self->ast->{org} = $self->pic->org;
    $self->ast->{config} = $self->pic->config;
    return;
}

sub got_uc_config {
    my ($self, $list) = @_;
    #my $conf = shift @$list;
    ## TODO: add more options to the default
    $self->ast->{config} = $self->pic->config;
    chomp $self->ast->{config};
    return;
}

sub got_start_block {
    my ($self, $list) = @_;
    $self->flatten($list); # we flatten because we only want the name out
    my $block = shift @$list;
    my $id = $self->ast->{block_stack_top};
    $block = "$block$id" if $block eq 'Loop';
    push @{$self->ast->{block_stack}}, $block;
    $self->ast->{block_stack_top} = scalar @{$self->ast->{block_stack}};
    my $stack = [];
    if ($block eq 'Main') {
        push @$stack, "_start:\n";
    } elsif ($block =~ /^Loop/) {
        push @$stack, "_loop_$id:\n";
    }
    $self->ast->{$block} = $stack;
    return;
}

sub got_end_block {
    my ($self, $list) = @_;
    # we are not capturing anything here
    my $block = pop @{$self->ast->{block_stack}};
    $self->ast->{block_stack_top} = scalar @{$self->ast->{block_stack}};
    my $top = $self->ast->{block_stack_top};
    return if $top eq 0;
    my $parent = $self->ast->{block_stack}->[$top - 1];
    return unless $parent;
    push @{$self->ast->{$parent}}, @{$self->ast->{$block}};
    my $endcode = "\tgoto _loop_$top\n" if $block =~ /^Loop/;
    push @{$self->ast->{$parent}}, $endcode if $endcode;
    return;
}

sub got_name {
    my ($self, $list) = @_;
    $self->flatten($list);
    return shift(@$list);
}

sub _update_block {
    my ($self, $code, $funcs, $macros) = @_;
    my $top = $self->ast->{block_stack_top};
    $top = $top - 1 if $top > 0;
    my $block = $self->ast->{block_stack}->[$top];
    push @{$self->ast->{$block}}, $code if $block;
    return unless ref $funcs eq 'HASH';
    foreach (keys %$funcs) {
        $self->ast->{funcs}->{$_} = $funcs->{$_};
    }
    return unless ref $macros eq 'HASH';
    foreach (keys %$macros) {
        $self->ast->{macros}->{$_} = $macros->{$_};
    }
}

sub got_instruction {
    my ($self, $list) = @_;
    my $method = shift @$list;
    $self->flatten($list) if $list;
    my @args = @$list if $list;
    $self->throw_error("Unknown instruction $method") unless $self->pic->can($method);
    my ($code, $funcs, $macros) = $self->pic->$method(@args);
    $self->throw_error("Error in statement $method @args") unless $code;
    $self->_update_block($code, $funcs, $macros);
    return;
}

sub _handle_var_op {
    my ($self, $varname, $op) = @_;
    my $method = 'increment' if $op eq '++';
    $method = 'decrement' if $op eq '--';
    $self->throw_error("Operator $op not supported. Use -- or ++ only.") unless $method;
    $self->throw_error("Unknown instruction $method") unless $self->pic->can($method);
    my $nvar = $self->ast->{variables}->{$varname}->{name} || uc $varname;
    my $code = $self->pic->$method($nvar);
    $self->throw_error("Invalid expression $varname $op") unless $code;
    $self->_update_block($code);
    return;
}

sub got_lhs_op {
    my ($self, $list) = @_;
    $self->flatten($list);
    my $varname = shift @$list;
    my $op = shift @$list;
    return $self->_handle_var_op($varname, $op);
}

sub got_op_rhs {
    my ($self, $list) = @_;
    $self->flatten($list);
    my $op = shift @$list;
    my $varname = shift @$list;
    return $self->_handle_var_op($varname, $op);
}

sub got_lhs_op_rhs {
    my ($self, $list) = @_;
    $self->flatten($list);
    my $varname = shift @$list;
    my $op = shift @$list;
    my $value = shift @$list;
    my $code;
    $self->throw_error("Operator $op not supported") unless $op eq '=';
    my $method = 'assign_' if $op eq '=';
    $method .= exists $self->ast->{variables}->{$value} ? 'variable' : 'literal';

    $self->throw_error("Unknown instruction $method") unless $self->pic->can($method);
    my $nvar = $self->ast->{variables}->{$varname}->{name} || uc $varname;
    $code = $self->pic->$method($nvar, $value);
    $self->throw_error("Invalid expression $varname $op $value") unless $code;
    $self->_update_block($code);
    return;
}

sub got_variable {
    my ($self, $list) = @_;
    $self->flatten($list);
    my $varname = shift @$list;
    $self->ast->{variables}->{$varname} = {
        name => uc $varname,
        scope => $self->ast->{block_stack_top},
        size => POSIX::ceil($self->pic->address_bits / 8),
    } unless exists $self->ast->{variables}->{$varname};
    return $varname;
}

sub got_number {
    my ($self, $list) = @_;
    # if it is a hexadecimal number we can just convert it to number using int()
    # since hex is returned here as a string
    return hex($list) if $list =~ /0x|0X/;
    return int($list);
}

# convert the number to appropriate units
sub got_number_units {
    my ($self, $list) = @_;
    $self->flatten($list);
    my $num = shift @$list;
    my $units = shift @$list || 's';
    $num *= 1 if $units eq 'us';
    $num *= 1000 if $units eq 'ms';
    $num *= 1e6 if $units eq 's';
    return $num;
}

# remove the dumb stuff from the tree
sub got_comment { return; }

sub final {
    my ($self, $got) = @_;
    my $ast = $self->ast;
    $self->throw_error("Missing '}'") if $self->ast->{block_stack_top} ne 0;
    $self->throw_error("Main not defined") unless defined $self->ast->{Main};
    my $funcs = '';
    foreach my $fn (keys %{$ast->{funcs}}) {
        $funcs .= "$fn:\n";
        $funcs .= $ast->{funcs}->{$fn};
        $funcs .= "\n";
    }
    my $macros = '';
    # variables are part of macros and need to go first
    my $variables = '';
    my $vhref = $ast->{variables};
    $variables .= "GLOBAL_VAR_UDATA udata\n" if keys %$vhref;
    foreach my $var (keys %$vhref) {
        # should we care about scope ?
        $variables .= "$vhref->{$var}->{name} res $vhref->{$var}->{size}\n";
    }
    foreach my $mac (keys %{$ast->{macros}}) {
        $variables .= "\n" . $ast->{macros}->{$mac} . "\n", next if $mac =~ /_var$/;
        $macros .= $ast->{macros}->{$mac};
        $macros .= "\n";
    }
    my $main_code = join("\n", @{$ast->{Main}});
    my $pic = <<"...";
#include <$ast->{include}>

; variables go here
$variables
; macros go here
$macros

$ast->{config}

\torg $ast->{org}

; the main function goes here
$main_code

; all the other functions go here
$funcs

\tend
...
    return $pic;
}

1;

=encoding utf8

=head1 NAME

VIC::PIC

=head1 SYNOPSIS

The Pegex::Receiver class for handling the grammar.

=head1 DESCRIPTION

INTERNAL CLASS.

=head1 AUTHOR

Vikas N Kumar <vikas@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2014. Vikas N Kumar

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
