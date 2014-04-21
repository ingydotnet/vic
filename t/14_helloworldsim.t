use lib 'ext/pegex-pm/lib';
use t::TestVIC tests => 1, debug => 0;

my $input = <<'...';
PIC P16F690;

# A Comment
pragma simulator gpsim;

Main { # set the Main function
     digital_output RC0; # mark pin RC0 as output
     write RC0, 1; # write the value 1 to RC0
} # end the Main function

Simulator {
    attach_led RC0;
    limit 1s;
    logfile "helloworld.lxt";
    log RC0;
    scope RC0;
}
...

my $output = <<'...';
;;;; generated code for PIC header file
#include <p16f690.inc>
;;;; generated code for gpsim header file
#include <coff.inc>

;;;; generated code for variables

;;;; generated code for macros


	__config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _BOR_OFF & _IESO_OFF & _FCMEN_OFF)



	org 0

;;;; generated common code for the Simulator
	.sim "module library libgpsim_modules"
	.sim "p16f690.xpos = 200";
	.sim "p16f690.ypos = 200";

;;;; generated code for Simulator
	.sim "module load led L0"
	.sim "L0.xpos = 100"
	.sim "L0.ypos = 50"
	.sim "node rc0led"
	.sim "attach rc0led portc0 L0.in"

	.sim "break c 10000000"

	.sim "log lxt helloworld.lxt"

	.sim "log r portc"
	.sim "log w portc"

	.sim "scope.ch0 = \"portc0\""




;;;; generated code for Main
_start:

	banksel TRISC
	bcf TRISC, TRISC0
	banksel ANSEL
	bcf ANSEL, ANS4
	banksel PORTC
	bcf PORTC, 0

	bsf PORTC, 0

_end_start:

	goto $	;;;; end of Main

;;;; generated code for functions

;;;; generated code for end-of-file
	end
...

compiles_ok($input, $output);
