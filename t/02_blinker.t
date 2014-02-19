use lib 'pegex-pm/lib';
use t::TestVIC tests => 1, debug => 0;

my $input = <<'...';
PIC P16F690;

# A Comment

Main {
     digital_output RC0;
     Loop {
         write RC0, 0x1;
         delay 1s;
         write RC0, 0;
         delay 1s;
     }
}
...

my $output = <<'...';
#include <p16f690.inc>

DELAY_VAR_UDATA udata
DELAY_VAR   res 3

m_delay_s macro secs
    local _delay_secs_loop_0, _delay_secs_loop_1, _delay_secs_loop_2
    variable secs_1 = 0
secs_1 = secs * D'1000000' / D'197379'
    movlw   secs_1
    movwf   DELAY_VAR + 2
_delay_secs_loop_2:
    clrf    DELAY_VAR + 1   ;; set to 0 which gets decremented to 0xFF
_delay_secs_loop_1:
    clrf    DELAY_VAR   ;; set to 0 which gets decremented to 0xFF
_delay_secs_loop_0:
    decfsz  DELAY_VAR, F
    goto    _delay_secs_loop_0
    decfsz  DELAY_VAR + 1, F
    goto    _delay_secs_loop_1
    decfsz  DELAY_VAR + 2, F
    goto    _delay_secs_loop_2
    endm

    __config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _BOR_OFF & _IESO_OFF & _FCMEN_OFF)

     org 0

_start:
    banksel   TRISC
    bcf       TRISC, TRISC0
    banksel   PORTC
    bcf PORTC, RC0
_loop_1:
    bsf PORTC, RC0
    call _delay_1s
    bcf PORTC, RC0
    call _delay_1s
    goto _loop_1

_delay_1s:
    m_delay_s D'1'
    return

    end
...
compiles_ok($input, $output);
