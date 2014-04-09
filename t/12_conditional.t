use lib 'ext/pegex-pm/lib';
use t::TestVIC tests => 1, debug => 0;

my $input = <<'...';
PIC P16F690;

Main {
    digital_output PORTC;
    $var1 = TRUE;
    $var2 = FALSE;
    Loop {
        if $var1 != FALSE && $var2 != FALSE {
            write PORTC, 1;
            $var1 = !$var2;
        } else if $var1 != FALSE {
            write PORTC, 2;
            $var2 = !$var1;
        } else if $var2 != FALSE {
            write PORTC, 4;
            $var2 = !$var1;
        } else {
            write PORTC, 8;
            $var1 = !$var2;
        }
    }
}
...

my $output = << '...';
;;;; generated code for PIC header file
#include <p16f690.inc>

;;;; generated code for variables
GLOBAL_VAR_UDATA udata
VAR1 res 1
VAR2 res 1
VIC_STACK res 3	;; temporary stack

;;;; generated code for macros


	__config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _BOR_OFF & _IESO_OFF & _FCMEN_OFF)



	org 0



;;;; generated code for Main
_start:

	banksel TRISC
	clrf TRISC
	banksel PORTC
	clrf PORTC

	;; moves 1 (0x01) to VAR1
	movlw 0x01
	movwf VAR1

	;; moves 0 (0x00) to VAR2
	clrf VAR2

;;;; generated code for Loop1
_loop_1:

	bcf STATUS, Z
	movf VAR1, W
	xorlw 0x00
	btfss STATUS, Z ;; var1 != 0 ?
	goto _end_conditional_0_0_t_0
	goto _end_conditional_0_0_f_0
_end_conditional_0_0_t_0:
	clrw
	goto _end_conditional_0_0_e_0
_end_conditional_0_0_f_0:
	movlw 0x01
_end_conditional_0_0_e_0:
	movwf VIC_STACK + 0


	bcf STATUS, Z
	movf VAR2, W
	xorlw 0x00
	btfss STATUS, Z ;; var2 != 0 ?
	goto _end_conditional_0_0_t_1
	goto _end_conditional_0_0_f_1
_end_conditional_0_0_t_1:
	clrw
	goto _end_conditional_0_0_e_1
_end_conditional_0_0_f_1:
	movlw 0x01
_end_conditional_0_0_e_1:
	movwf VIC_STACK + 1


	;; perform check for VIC_STACK + 0 && VIC_STACK + 1
	bcf STATUS, Z
	movf VIC_STACK + 0, W
	btfss STATUS, Z  ;; VIC_STACK + 0 is false if it is set else true
	movf VIC_STACK + 1, W
	btfss STATUS, Z ;; VIC_STACK + 1 is false if it is set else true
	btfss STATUS, Z ;; VIC_STACK + 0 && VIC_STACK + 1 ?
	goto _end_conditional_0_0
	goto _true_2
_end_conditional_0_0:


	bcf STATUS, Z
	movf VAR1, W
	xorlw 0x00
	btfss STATUS, Z ;; var1 != 0 ?
	goto _true_3
	goto _end_conditional_0_1
_end_conditional_0_1:


	bcf STATUS, Z
	movf VAR2, W
	xorlw 0x00
	btfss STATUS, Z ;; var2 != 0 ?
	goto _true_4
	goto _false_5
_end_conditional_0_2:


_end_conditional_0:

	goto _loop_1

;;;; generated code for functions
;;;; generated code for False5
_false_5:

	;; moves 8 (0x08) to PORTC
	movlw 0x08
	movwf PORTC

	;;;; generate code for !VAR2
	comf VAR2, W
	btfsc STATUS, Z
	movlw 1

	movwf VAR1

	goto _end_conditional_0;; go back to end of conditional

;;;; generated code for True2
_true_2:

	;; moves 1 (0x01) to PORTC
	movlw 0x01
	movwf PORTC

	;;;; generate code for !VAR2
	comf VAR2, W
	btfsc STATUS, Z
	movlw 1

	movwf VAR1

	goto _end_conditional_0;; go back to end of conditional

;;;; generated code for True3
_true_3:

	;; moves 2 (0x02) to PORTC
	movlw 0x02
	movwf PORTC

	;;;; generate code for !VAR1
	comf VAR1, W
	btfsc STATUS, Z
	movlw 1

	movwf VAR2

	goto _end_conditional_0;; go back to end of conditional

;;;; generated code for True4
_true_4:

	;; moves 4 (0x04) to PORTC
	movlw 0x04
	movwf PORTC

	;;;; generate code for !VAR1
	comf VAR1, W
	btfsc STATUS, Z
	movlw 1

	movwf VAR2

	goto _end_conditional_0;; go back to end of conditional



;;;; generated code for end-of-file
	end
...

compiles_ok($input, $output);