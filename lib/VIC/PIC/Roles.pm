use strict;
use warnings;
package VIC::PIC::Roles::CodeGen;
{
    use Moo::Role;
    requires qw(type org include chip_config code_config);
}

package VIC::PIC::Roles::Chip;
{
    use Moo::Role;

    requires qw(f_osc pcl_size stack_size wreg_size
                memory address banks registers
                pins);
    # useful for checking if a chip is PDIP or SOIC or SSOP or QFN
    # maybe extracted to a separate role defining chip type but not yet
    requires qw(pin_counts);
}
package VIC::PIC::Roles::GPIO;
{
    use Moo::Role;
    # gpio_pins is bidirectional. input_pins is input-only
    # output pins is output only
    requires qw(gpio_pins input_pins output_pins);
}

package VIC::PIC::Roles::CCP;
{
    use Moo::Role;
    requires qw(ccp_pins);
}

1;
__END__
