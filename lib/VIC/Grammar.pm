package VIC::Grammar;
use strict;
use warnings;

our $VERSION = '0.08';
$VERSION = eval $VERSION;

use Pegex::Base;
extends 'Pegex::Grammar';

use constant file => './share/vic.pgx';

sub make_tree {
  {
    '+grammar' => 'vic',
    '+toprule' => 'program',
    '+version' => '0.1.1',
    'COMMA' => {
      '.rgx' => qr/\G,/
    },
    'DOLLAR' => {
      '.rgx' => qr/\G\$/
    },
    'EOS' => {
      '.rgx' => qr/\G\z/
    },
    '_' => {
      '.rgx' => qr/\G[\ \t]*\r?\n?/
    },
    '__' => {
      '.rgx' => qr/\G[\ \t]+\r?\n?/
    },
    'anonymous_block' => {
      '.all' => [
        {
          '.ref' => 'start_block'
        },
        {
          '+min' => 0,
          '.ref' => 'statement'
        },
        {
          '.ref' => 'end_block'
        }
      ]
    },
    'any_conditional' => {
      '.any' => [
        {
          '.ref' => 'single_conditional'
        },
        {
          '.ref' => 'nested_conditional'
        }
      ]
    },
    'array' => {
      '.all' => [
        {
          '.ref' => 'start_array'
        },
        {
          '.ref' => '_'
        },
        {
          '+min' => 0,
          '.ref' => 'array_element_type',
          '.sep' => {
            '.ref' => 'list_separator'
          }
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'end_array'
        }
      ]
    },
    'array_element' => {
      '.all' => [
        {
          '.ref' => 'variable'
        },
        {
          '.ref' => 'start_array'
        },
        {
          '.ref' => 'rhs_expr'
        },
        {
          '.ref' => 'end_array'
        }
      ]
    },
    'array_element_type' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.any' => [
            {
              '.ref' => 'number_units'
            },
            {
              '.ref' => 'number'
            },
            {
              '.ref' => 'string'
            }
          ]
        },
        {
          '.ref' => '_'
        }
      ]
    },
    'assert_comparison' => {
      '.all' => [
        {
          '.ref' => 'assert_value'
        },
        {
          '.ref' => 'compare_operator'
        },
        {
          '.ref' => 'assert_value'
        }
      ]
    },
    'assert_condition' => {
      '.ref' => 'assert_comparison'
    },
    'assert_message' => {
      '.all' => [
        {
          '.ref' => 'list_separator'
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'string'
        }
      ]
    },
    'assert_statement' => {
      '.all' => [
        {
          '.ref' => 'name'
        },
        {
          '.ref' => 'assert_condition'
        },
        {
          '.ref' => '_'
        },
        {
          '+max' => 1,
          '.ref' => 'assert_message'
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'line_ending'
        }
      ]
    },
    'assert_value' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.any' => [
            {
              '.ref' => 'validated_variable'
            },
            {
              '.ref' => 'variable'
            },
            {
              '.ref' => 'number'
            }
          ]
        },
        {
          '.ref' => '_'
        }
      ]
    },
    'assign_expr' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'variable'
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'assign_operator'
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'rhs_expr'
        }
      ]
    },
    'assign_operator' => {
      '.any' => [
        {
          '.rgx' => qr/\G([\+\-%\^\*\|&\/]?=)/
        },
        {
          '.ref' => 'shift_assign_operator'
        }
      ]
    },
    'bit_operator' => {
      '.rgx' => qr/\G([\|\^&])/
    },
    'blank_line' => {
      '.rgx' => qr/\G[\ \t]*\r?\n?\r?\n/
    },
    'block' => {
      '.ref' => 'named_block'
    },
    'boolean' => {
      '.rgx' => qr/\G(TRUE|FALSE|true|false|0|1)/
    },
    'comment' => {
      '.any' => [
        {
          '.rgx' => qr/\G[\ \t]*\r?\n?\#.*\r?\n/
        },
        {
          '.ref' => 'blank_line'
        }
      ]
    },
    'compare_operator' => {
      '.rgx' => qr/\G([!=<>]=|(?:<|>))/
    },
    'comparison' => {
      '.all' => [
        {
          '.ref' => 'expr_value'
        },
        {
          '.ref' => 'compare_operator'
        },
        {
          '.ref' => 'expr_value'
        }
      ]
    },
    'complement' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'complement_operator'
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'rhs_expr'
        },
        {
          '.ref' => '_'
        }
      ]
    },
    'complement_operator' => {
      '.rgx' => qr/\G(\~|!)/
    },
    'conditional_predicate' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'anonymous_block'
        },
        {
          '.ref' => '_'
        },
        {
          '+max' => 1,
          '.all' => [
            {
              '.rgx' => qr/\Gelse/
            },
            {
              '.ref' => '_'
            },
            {
              '+min' => 0,
              '.any' => [
                {
                  '.ref' => 'anonymous_block'
                },
                {
                  '.ref' => 'conditional_statement'
                }
              ]
            }
          ]
        },
        {
          '.ref' => '_'
        }
      ]
    },
    'conditional_statement' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.rgx' => qr/\G(if|while)/
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'conditional_subject'
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'conditional_predicate'
        },
        {
          '+max' => 1,
          '.ref' => 'line_ending'
        }
      ]
    },
    'conditional_subject' => {
      '.any' => [
        {
          '.ref' => 'single_conditional_subject'
        },
        {
          '.ref' => 'nested_conditional_subject'
        }
      ]
    },
    'constant' => {
      '.any' => [
        {
          '.ref' => 'number_units'
        },
        {
          '.ref' => 'number'
        },
        {
          '.ref' => 'string'
        },
        {
          '.ref' => 'array'
        }
      ]
    },
    'declaration' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'variable'
        },
        {
          '.ref' => '_'
        },
        {
          '.rgx' => qr/\G=/
        },
        {
          '.ref' => '_'
        },
        {
          '.any' => [
            {
              '.ref' => 'constant'
            },
            {
              '.ref' => 'modifier_constant'
            }
          ]
        }
      ]
    },
    'double_quoted_string' => {
      '.rgx' => qr/\G(?:"((?:[^\n\\"]|\\"|\\\\|\\[0nt])*?)")/
    },
    'end_array' => {
      '.rgx' => qr/\G[\ \t]*\r?\n?\][\ \t]*\r?\n?/
    },
    'end_block' => {
      '.rgx' => qr/\G[\ \t]*\r?\n?\}[\ \t]*\r?\n?\r?\n?/
    },
    'end_nested_expr' => {
      '.rgx' => qr/\G[\ \t]*\r?\n?\)[\ \t]*\r?\n?/
    },
    'expr_value' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.any' => [
            {
              '.ref' => 'number'
            },
            {
              '.ref' => 'array_element'
            },
            {
              '.ref' => 'variable'
            },
            {
              '.ref' => 'number_units'
            },
            {
              '.ref' => 'complement'
            },
            {
              '.ref' => 'modifier_variable'
            },
            {
              '.ref' => 'nested_expr_value'
            }
          ]
        },
        {
          '.ref' => '_'
        }
      ]
    },
    'expression' => {
      '.all' => [
        {
          '.any' => [
            {
              '.ref' => 'assign_expr'
            },
            {
              '.ref' => 'unary_expr'
            },
            {
              '.ref' => 'declaration'
            }
          ]
        },
        {
          '.ref' => 'line_ending'
        }
      ]
    },
    'header' => {
      '.any' => [
        {
          '.ref' => 'pragmas'
        },
        {
          '.ref' => 'comment'
        }
      ]
    },
    'identifier' => {
      '.rgx' => qr/\G([a-zA-Z][0-9A-Za-z_]*)/
    },
    'identifier_without_keyword' => {
      '.rgx' => qr/\G(?!if|else|while|true|false|TRUE|FALSE)([a-zA-Z][0-9A-Za-z_]*)/
    },
    'instruction' => {
      '.all' => [
        {
          '.ref' => 'name'
        },
        {
          '.ref' => 'values'
        },
        {
          '.ref' => 'line_ending'
        }
      ]
    },
    'line_ending' => {
      '.rgx' => qr/\G[\ \t]*\r?\n?;[\ \t]*\r?\n?\r?\n?/
    },
    'list_separator' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'COMMA'
        },
        {
          '.ref' => '_'
        },
        {
          '+max' => 1,
          '.ref' => 'comment'
        }
      ]
    },
    'logic_operator' => {
      '.rgx' => qr/\G([&\|]{2})/
    },
    'math_operator' => {
      '.rgx' => qr/\G([\+\-\*\/%])/
    },
    'modifier_constant' => {
      '.all' => [
        {
          '.ref' => 'identifier_without_keyword'
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'constant'
        }
      ]
    },
    'modifier_variable' => {
      '.all' => [
        {
          '.ref' => 'identifier_without_keyword'
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'variable'
        }
      ]
    },
    'name' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'identifier_without_keyword'
        },
        {
          '.ref' => '_'
        }
      ]
    },
    'named_block' => {
      '.all' => [
        {
          '.ref' => 'name'
        },
        {
          '.ref' => 'anonymous_block'
        }
      ]
    },
    'nested_conditional' => {
      '.all' => [
        {
          '.ref' => 'start_nested_expr'
        },
        {
          '.ref' => 'single_conditional'
        },
        {
          '.ref' => 'end_nested_expr'
        }
      ]
    },
    'nested_conditional_subject' => {
      '.all' => [
        {
          '.ref' => 'start_nested_expr'
        },
        {
          '.ref' => 'single_conditional_subject'
        },
        {
          '.ref' => 'end_nested_expr'
        }
      ]
    },
    'nested_expr_value' => {
      '.all' => [
        {
          '.ref' => 'start_nested_expr'
        },
        {
          '.ref' => 'rhs_expr'
        },
        {
          '.ref' => 'end_nested_expr'
        }
      ]
    },
    'number' => {
      '.any' => [
        {
          '.rgx' => qr/\G(0[xX][0-9a-fA-F]+|-?[0-9]+)/
        },
        {
          '.ref' => 'boolean'
        }
      ]
    },
    'number_units' => {
      '.all' => [
        {
          '.ref' => 'number'
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'units'
        }
      ]
    },
    'pragma_expression' => {
      '.all' => [
        {
          '.ref' => 'name'
        },
        {
          '.rgx' => qr/\G=[\ \t]*\r?\n?/
        },
        {
          '.any' => [
            {
              '.ref' => 'number_units'
            },
            {
              '.ref' => 'number'
            },
            {
              '.ref' => 'string'
            }
          ]
        },
        {
          '.ref' => '_'
        }
      ]
    },
    'pragmas' => {
      '.all' => [
        {
          '.rgx' => qr/\Gpragma/
        },
        {
          '.ref' => '__'
        },
        {
          '.any' => [
            {
              '.ref' => 'variable'
            },
            {
              '.ref' => 'name'
            }
          ]
        },
        {
          '+max' => 1,
          '.any' => [
            {
              '.ref' => 'pragma_expression'
            },
            {
              '.ref' => 'name'
            }
          ]
        },
        {
          '.ref' => 'line_ending'
        }
      ]
    },
    'program' => {
      '.all' => [
        {
          '.ref' => 'uc_select'
        },
        {
          '+min' => 0,
          '.ref' => 'header'
        },
        {
          '+min' => 0,
          '.ref' => 'statement'
        },
        {
          '.ref' => 'EOS'
        }
      ]
    },
    'rhs_expr' => {
      '+min' => 1,
      '.ref' => 'expr_value',
      '.sep' => {
        '.ref' => 'rhs_operator'
      }
    },
    'rhs_operator' => {
      '.any' => [
        {
          '.ref' => 'math_operator'
        },
        {
          '.ref' => 'bit_operator'
        },
        {
          '.ref' => 'shift_operator'
        }
      ]
    },
    'shift_assign_operator' => {
      '.rgx' => qr/\G(<<=|>>=)/
    },
    'shift_operator' => {
      '.rgx' => qr/\G(<<|>>)/
    },
    'single_conditional' => {
      '.any' => [
        {
          '.ref' => 'comparison'
        },
        {
          '.ref' => 'expr_value'
        }
      ]
    },
    'single_conditional_subject' => {
      '+min' => 1,
      '.ref' => 'any_conditional',
      '.sep' => {
        '.ref' => 'logic_operator'
      }
    },
    'single_quoted_string' => {
      '.rgx' => qr/\G(?:'((?:[^\n\\']|\\'|\\\\)*?)')/
    },
    'start_array' => {
      '.rgx' => qr/\G[\ \t]*\r?\n?\[[\ \t]*\r?\n?/
    },
    'start_block' => {
      '.rgx' => qr/\G[\ \t]*\r?\n?\{[\ \t]*\r?\n?\r?\n?/
    },
    'start_nested_expr' => {
      '.rgx' => qr/\G[\ \t]*\r?\n?\([\ \t]*\r?\n?/
    },
    'statement' => {
      '.any' => [
        {
          '.ref' => 'comment'
        },
        {
          '.ref' => 'instruction'
        },
        {
          '.ref' => 'expression'
        },
        {
          '.ref' => 'conditional_statement'
        },
        {
          '.ref' => 'assert_statement'
        },
        {
          '.ref' => 'block'
        }
      ]
    },
    'string' => {
      '.any' => [
        {
          '.ref' => 'single_quoted_string'
        },
        {
          '.ref' => 'double_quoted_string'
        }
      ]
    },
    'uc_select' => {
      '.rgx' => qr/\GPIC[\ \t]+((?i:P16F690|P16F690X))[\ \t]*\r?\n?;[\ \t]*\r?\n?\r?\n?/
    },
    'unary_expr' => {
      '.any' => [
        {
          '.ref' => 'unary_lhs'
        },
        {
          '.ref' => 'unary_rhs'
        }
      ]
    },
    'unary_lhs' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'unary_operator'
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'variable'
        },
        {
          '.ref' => '_'
        }
      ]
    },
    'unary_operator' => {
      '.rgx' => qr/\G(\+\+|\-\-)/
    },
    'unary_rhs' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'variable'
        },
        {
          '.ref' => '_'
        },
        {
          '.ref' => 'unary_operator'
        },
        {
          '.ref' => '_'
        }
      ]
    },
    'units' => {
      '.rgx' => qr/\G(s|ms|us|kHz|Hz|MHz)/
    },
    'validated_variable' => {
      '.ref' => 'identifier_without_keyword'
    },
    'value' => {
      '.all' => [
        {
          '.ref' => '_'
        },
        {
          '.any' => [
            {
              '.ref' => 'string'
            },
            {
              '.ref' => 'number_units'
            },
            {
              '.ref' => 'number'
            },
            {
              '.ref' => 'array_element'
            },
            {
              '.ref' => 'variable'
            },
            {
              '.ref' => 'named_block'
            },
            {
              '.ref' => 'modifier_constant'
            },
            {
              '.ref' => 'modifier_variable'
            },
            {
              '.ref' => 'validated_variable'
            }
          ]
        },
        {
          '.ref' => '_'
        }
      ]
    },
    'values' => {
      '+min' => 0,
      '.ref' => 'value',
      '.sep' => {
        '.ref' => 'list_separator'
      }
    },
    'variable' => {
      '.all' => [
        {
          '.ref' => 'DOLLAR'
        },
        {
          '.ref' => 'identifier'
        }
      ]
    }
  }
}

1;

=encoding utf8

=head1 NAME

VIC::Grammar

=head1 SYNOPSIS

The Pegex::Grammar class for handling the grammar.

=head1 DESCRIPTION

INTERNAL CLASS. THIS IS AUTO-GENERATED. DO NOT EDIT.

=head1 AUTHOR

Vikas N Kumar <vikas@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2014. Vikas N Kumar

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
