package VIC::PIC::Base;
use strict;
use warnings;
use bigint;
use Carp;
use POSIX ();
use Pegex::Base; # use this instead of Mo

our $VERSION = '0.12';
$VERSION = eval $VERSION;

has type => undef;

has include => undef;

has org => 0;

has frequency => 0; # 4MHz

has address_range => [ 0x0000, 0x0FFF ]; # 4K

has reset_address => 0x0000;

has isr_address => 0x0004;

has program_counter_size => 13; # PCL and PCLATH<4:0>

has stack_size => 8; # 8-level x 13-bit wide

has register_size => 8; # size of register W

has banks => {
    # general purpose registers
    gpr => undef,
    # special function registers
    sfr => undef,
    bank_size => undef,
    common_bank => undef,
};

has register_banks => {};

has pin_count => 0;

has pins => {
    #name  #port  #portbit #pin
	Vdd => [undef, undef, 1],
};

has ports => {};

has visible_pins => {};

has gpio_pins => {};

has input_pins => {};

has power_pins => {};

has analog_pins => {}; 

has comparator_pins => {};

has timer_prescaler => {};

has wdt_prescaler => {};

has timer_pins => {};

has interrupt_pins => {};

has usart_pins => {};

has clock_pins => {};

has oscillator_pins => {};

has icsp_pins => {};

has selector_pins => {};

has spi_pins => {};

has i2c_pins => {};

has pwm_pins => {};

has chip_config => <<"...";
\t__config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _BOR_OFF & _IESO_OFF & _FCMEN_OFF)

...

has code_config => {
    debounce => {
        count => 5,
        delay => 1000, # in microseconds
    },
    adc => {
        right_justify => 1,
        vref => 0,
        internal => 0,
    },
    variable => {
        bits => 8, # bits. same as register_size
        export => 0, # do not export variables
    },
};

sub update_code_config {
    my ($self, $grp, $key, $val) = @_;
    return unless defined $grp;
    $self->code_config->{$grp} = {} unless exists $self->code_config->{$grp};
    my $grpref = $self->code_config->{$grp};
    if ($key eq 'bits') {
        $val = 8 unless defined $val;
        $val = 8 if $val <= 8;
        $val = 16 if ($val > 8 and $val <= 16);
        $val = 32 if ($val > 16 and $val <= 32);
        carp "$val-bits is not supported. Maximum supported size is 64-bit"
            if $val > 64;
        $val = 64 if $val > 32;
    }
    $val = 1 unless defined $val;
    if (ref $grpref eq 'HASH') {
        $grpref->{$key} = $val;
    } else {
        $self->code_config->{$grp} = { $key => $val };
    }
    1;
}

sub address_bits {
    my ($self, $varname) = @_;
    my $bits = $self->code_config->{variable}->{bits};
    return $bits unless $varname;
    $bits = $self->code_config->{lc $varname}->{bits} || $bits;
    return $bits;
}

sub convert_to_valid_pin {
    my ($self, $var) = @_;
    return undef unless defined $var;
    return undef if $var =~ /^\d+$/;
    return $var if exists $self->ports->{$var};
    return $var if exists $self->pins->{$var};
    my $pin_no = undef;
    $pin_no = $self->analog_pins->{$var}->[0] if exists $self->analog_pins->{$var};
    $pin_no = $self->power_pins->{$var} if exists $self->power_pins->{$var};
    $pin_no = $self->comparator_pins->{$var} if exists $self->comparator_pins->{$var};
    $pin_no = $self->interrupt_pins->{$var} if exists $self->interrupt_pins->{$var};
    $pin_no = $self->timer_pins->{$var} if exists $self->timer_pins->{$var};
    $pin_no = $self->spi_pins->{$var} if exists $self->spi_pins->{$var};
    $pin_no = $self->usart_pins->{$var} if exists $self->usart_pins->{$var};
    $pin_no = $self->clock_pins->{$var} if exists $self->clock_pins->{$var};
    $pin_no = $self->selector_pins->{$var} if exists $self->selector_pins->{$var};
    $pin_no = $self->oscillator_pins->{$var} if exists $self->oscillator_pins->{$var};
    $pin_no = $self->icsp_pins->{$var} if exists $self->icsp_pins->{$var};
    $pin_no = $self->i2c_pins->{$var} if exists $self->i2c_pins->{$var};
    $pin_no = $self->pwm_pins->{$var} if exists $self->pwm_pins->{$var};
    return $self->visible_pins->{$pin_no} if defined $pin_no;
    return undef;
}


sub validate {
    my ($self, $var) = @_;
    return undef unless defined $var;
    return 0 if $var =~ /^\d+$/;
    return 1 if exists $self->pins->{$var};
    return 1 if exists $self->ports->{$var};
    return 1 if exists $self->analog_pins->{$var};
    return 1 if exists $self->register_banks->{$var};
    return 1 if exists $self->power_pins->{$var};
    return 1 if exists $self->comparator_pins->{$var};
    return 1 if exists $self->interrupt_pins->{$var};
    return 1 if exists $self->timer_pins->{$var};
    return 1 if exists $self->spi_pins->{$var};
    return 1 if exists $self->usart_pins->{$var};
    return 1 if exists $self->clock_pins->{$var};
    return 1 if exists $self->selector_pins->{$var};
    return 1 if exists $self->oscillator_pins->{$var};
    return 1 if exists $self->icsp_pins->{$var};
    return 1 if exists $self->i2c_pins->{$var};
    return 1 if exists $self->pwm_pins->{$var};
    return 0;
}

sub validate_operator {
    my ($self, $op) = @_;
    my $vop = "op_$op" if $op =~ /^
            LE | GE | GT | LT | EQ | NE |
            ADD | SUB | MUL | DIV | MOD |
            BXOR | BOR | BAND | AND | OR | SHL | SHR |
            ASSIGN | INC | DEC | NOT | COMP |
            TBLIDX | ARRIDX | STRIDX
        /x;
    return $vop;
}

sub validate_modifier_operator {
    my ($self, $mod, $suffix) = @_;
    my $vmod = "op_$mod" if $mod =~ /^
            SQRT | HIGH | LOW
        /x;
    return $vmod;
}

sub digital_output {
    my ($self, $outp) = @_;
    return unless defined $outp;
    my $code;
    if (exists $self->ports->{$outp}) {
        my $port = $self->ports->{$outp};
        my $flags = 0xFF;
        my $flagsH = 0xFF;
        for (0 .. 7) {
            my $pin = 'R' . $port . $_;
            next unless exists $self->pins->{$pin};
            my ($p1, $p2, $pin_no) = @{$self->pins->{$pin}};
            my $apinname = $self->analog_pins->{$pin_no} if defined $pin_no;
            if (defined $apinname) {
                my ($apin, $abit) = @{$self->analog_pins->{$apinname}};
                $flags ^= 1 << $abit if $abit < 8;
                $flagsH ^= 1 << ($abit - 8) if $abit >= 8;
            }
        }
        my $an_code = '';
        if ($flags != 0) {
            $flags = sprintf "0x%02X", $flags;
            $an_code .= "\tbanksel ANSEL\n";
            $an_code .= "\tmovlw $flags\n";
            $an_code .= "\tandwf ANSEL, F\n";
        }
        if ($flagsH != 0) {
            $flagsH = sprintf "0x%02X", $flagsH;
            $an_code .= "\tbanksel ANSELH\n";
            $an_code .= "\tmovlw $flagsH\n";
            $an_code .= "\tandwf ANSELH, F\n";
        }
        $code = << "...";
\tbanksel TRIS$port
\tclrf TRIS$port
$an_code
\tbanksel $outp
\tclrf $outp
...
    } elsif (exists $self->pins->{$outp}) {
        my ($port, $portbit, $pin_no) = @{$self->pins->{$outp}};
        my $an_code = '';
        if (defined $port and defined $portbit) {
            my $apinname = $self->analog_pins->{$pin_no} if defined $pin_no;
            if (defined $apinname) {
                my ($apin, $abit) = @{$self->analog_pins->{$apinname}};
                my $ansel = ($abit >= 8) ? 'ANSELH' : 'ANSEL';
                $an_code = "\tbanksel $ansel\n\tbcf $ansel, ANS$abit";
            }
            $code = << "...";
\tbanksel TRIS$port
\tbcf TRIS$port, TRIS$port$portbit
$an_code
\tbanksel PORT$port
\tbcf PORT$port, $portbit
...
        }
    } else {
        carp "Cannot find $outp in the list of ports or pins";
    }
    return $code;
}

sub write {
    my ($self, $outp, $val) = @_;
    return unless defined $outp;
    if (exists $self->ports->{$outp}) {
        my $port = $self->ports->{$outp};
        unless (defined $val) {
            return << "...";
\tclrf PORT$port
\tcomf PORT$port, 1
...
        }
        if ($self->validate($val)) {
            # ok we want to write the value of a pin to a port
            # that doesn't seem right so let's provide a warning
            if ($self->pins->{$val}) {
                carp "$val is a pin and you're trying to write a pin to a port" .
                    " $outp. You can write a pin to a pin or a port to a port only.\n";
                return;
            }
        }
        return $self->op_ASSIGN("PORT$port", $val);
    } elsif (exists $self->pins->{$outp}) {
        my ($port, $portbit) = @{$self->pins->{$outp}};
        if ($val =~ /^\d+$/) {
            return "\tbcf PORT$port, $portbit\n" if "$val" eq '0';
            return "\tbsf PORT$port, $portbit\n" if "$val" eq '1';
            carp "$val cannot be applied to a pin $outp\n";
        } elsif ($self->validate($val)) {
            # ok we want to short two pins, and this is not bit-banging
            # although seems like it
            my $vpin = $self->convert_to_valid_pin($val);
            if ($vpin and $self->pins->{$vpin}) {
                my ($vport, $vportbit) = @{$self->pins->{$vpin}};
                return << "...";
\tbtfss PORT$port, $vpin
\tbcf PORT$vport, $outp
\tbtfsc PORT$port, $vpin
\tbsf PORT$vport, $outp
...
            } else {
                carp "$val is a port or unknown pin and cannot be written to a pin $outp. ".
                    "Only a pin can be written to a pin.\n";
                return;
            }
        }
        return $self->op_ASSIGN("PORT$port", $val);
    } elsif ($self->validate($outp)) {
        my $code = "\tbanksel $outp\n";
        $code .= $self->op_ASSIGN($outp, $val);
        return $code;
    } else {
        carp "Cannot find $outp in the list of ports or pins";
        return;
    }
}

sub analog_input {
    my ($self, $inp) = @_;
    return unless defined $inp;
    my $code;
    if (exists $self->ports->{$inp}) {
        my $port = $self->ports->{$inp};
        my $flags = 0;
        my $flagsH = 0;
        for (0 .. 7) {
            my $pin = 'R' . $port . $_;
            next unless exists $self->pins->{$pin};
            my ($p1, $p2, $pin_no) = @{$self->pins->{$pin}};
            my $apinname = $self->analog_pins->{$pin_no} if defined $pin_no;
            if (defined $apinname) {
                my ($apin, $abit) = @{$self->analog_pins->{$apinname}};
                $flags ^= 1 << $abit if $abit < 8;
                $flagsH ^= 1 << ($abit - 8) if $abit >= 8;
            }
        }
        my $an_code = '';
        if ($flags != 0) {
            $flags = sprintf "0x%02X", $flags;
            $an_code .= "\tbanksel ANSEL\n";
            $an_code .= "\tmovlw $flags\n";
            $an_code .= "\tiorwf ANSEL, F\n";
        }
        if ($flagsH != 0) {
            $flagsH = sprintf "0x%02X", $flagsH;
            $an_code .= "\tbanksel ANSELH\n";
            $an_code .= "\tmovlw $flagsH\n";
            $an_code .= "\tiorwf ANSELH, F\n";
        }
        $code = << "...";
\tbanksel TRIS$port
\tmovlw 0xFF
\tmovwf TRIS$port
$an_code
\tbanksel PORT$port
...
    } elsif (exists $self->pins->{$inp}) {
        my ($port, $portbit, $pin) = @{$self->pins->{$inp}};
        if (defined $port and defined $portbit and defined $pin) {
            my $an_code = '';
            if (exists $self->analog_pins->{$pin}) {
                my $pinname = $self->analog_pins->{$pin};
                my ($apin, $abit) = @{$self->analog_pins->{$pinname}};
                my $ansel = ($abit >= 8) ? 'ANSELH' : 'ANSEL';
                $an_code = "\tbanksel $ansel\n\tbsf $ansel, ANS$abit";
            }
            $code = << "...";
\tbanksel TRIS$port
\tbsf TRIS$port, TRIS$port$portbit
$an_code
\tbanksel PORT$port
...
        }
    } else {
        carp "Cannot find $inp the list of ports or pins";
    }
    return $code;
}
sub digital_input {
    my ($self, $inp) = @_;
    return unless defined $inp;
    my $code;
    my $an_code = '';
    if (exists $self->ports->{$inp}) {
        my $port = $self->ports->{$inp};
        my $flags = 0xFF;
        my $flagsH = 0xFF;
        for (0 .. 7) {
            my $pin = 'R' . $port . $_;
            next unless exists $self->pins->{$pin};
            my ($p1, $p2, $pin_no) = @{$self->pins->{$pin}};
            my $apinname = $self->analog_pins->{$pin_no} if defined $pin_no;
            if (defined $apinname) {
                my ($apin, $abit) = @{$self->analog_pins->{$apinname}};
                $flags ^= 1 << $abit if $abit < 8;
                $flagsH ^= 1 << ($abit - 8) if $abit >= 8;
            }
        }
        if ($flags != 0) {
            $flags = sprintf "0x%02X", $flags;
            $an_code .= "\tbanksel ANSEL\n";
            $an_code .= "\tmovlw $flags\n";
            $an_code .= "\tandwf ANSEL, F\n";
        }
        if ($flagsH != 0) {
            $flagsH = sprintf "0x%02X", $flagsH;
            $an_code .= "\tbanksel ANSELH\n";
            $an_code .= "\tmovlw $flagsH\n";
            $an_code .= "\tandwf ANSELH, F\n";
        }
        $code = << "...";
\tbanksel TRIS$port
\tmovlw 0xFF
\tmovwf TRIS$port
$an_code
\tbanksel PORT$port
...
    } elsif (exists $self->pins->{$inp}) {
        my ($port, $portbit, $pin) = @{$self->pins->{$inp}};
        if (defined $port and defined $portbit and defined $pin) {
            my $apinname = $self->analog_pins->{$pin};
            if (defined $apinname) {
                my ($apin, $abit) = @{$self->analog_pins->{$apinname}};
                my $ansel = ($abit >= 8) ? 'ANSELH' : 'ANSEL';
                $an_code = "\tbanksel $ansel\n\tbcf $ansel, ANS$abit";
            }
            $code = << "...";
\tbanksel TRIS$port
\tbsf TRIS$port, TRIS$port$portbit
$an_code
\tbanksel PORT$port
...
        }
    } else {
        carp "Cannot find $inp the list of ports or pins";
    }
    return $code;
}

sub hang {
    my ($self, @args) = @_;
    return "\tgoto \$";
}

sub m_delay_var {
    return <<'...';
;;;;;; DELAY FUNCTIONS ;;;;;;;

VIC_VAR_DELAY_UDATA udata
VIC_VAR_DELAY   res 3

...
}

sub m_delay_us {
    return <<'...';
;; 1MHz => 1us per instruction
;; return, goto and call are 2us each
;; hence each loop iteration is 3us
;; the rest including movxx + return = 2us
;; hence usecs - 6 is used
m_delay_us macro usecs
    local _delay_usecs_loop_0
    variable usecs_1 = 0
    variable usecs_2 = 0
if (usecs > D'6')
usecs_1 = usecs / D'3' - 2
usecs_2 = usecs % D'3'
    movlw   usecs_1
    movwf   VIC_VAR_DELAY
    decfsz  VIC_VAR_DELAY, F
    goto    $ - 1
    while usecs_2 > 0
        goto $ + 1
usecs_2--
    endw
else
usecs_1 = usecs
    while usecs_1 > 0
        nop
usecs_1--
    endw
endif
    endm
...
}

sub m_delay_wus {
    return <<'...';
m_delay_wus macro
    local _delayw_usecs_loop_0
    movwf   VIC_VAR_DELAY
_delayw_usecs_loop_0:
    decfsz  VIC_VAR_DELAY, F
    goto    _delayw_usecs_loop_0
    endm
...
}

sub m_delay_ms {
    return <<'...';
;; 1MHz => 1us per instruction
;; each loop iteration is 3us each
;; there are 2 loops, one for (768 + 3) us
;; and one for the rest in ms
;; we add 3 instructions for the outer loop
;; number of outermost loops = msecs * 1000 / 771 = msecs * 13 / 10
m_delay_ms macro msecs
    local _delay_msecs_loop_0, _delay_msecs_loop_1, _delay_msecs_loop_2
    variable msecs_1 = 0
    variable msecs_2 = 0
msecs_1 = (msecs * D'1000') / D'771'
msecs_2 = ((msecs * D'1000') % D'771') / 3 - 2;; for 3 us per instruction
    movlw   msecs_1
    movwf   VIC_VAR_DELAY + 1
_delay_msecs_loop_1:
    clrf   VIC_VAR_DELAY   ;; set to 0 which gets decremented to 0xFF
_delay_msecs_loop_0:
    decfsz  VIC_VAR_DELAY, F
    goto    _delay_msecs_loop_0
    decfsz  VIC_VAR_DELAY + 1, F
    goto    _delay_msecs_loop_1
if msecs_2 > 0
    ;; handle the balance
    movlw msecs_2
    movwf VIC_VAR_DELAY
_delay_msecs_loop_2:
    decfsz VIC_VAR_DELAY, F
    goto _delay_msecs_loop_2
    nop
endif
    endm
...
}

sub m_delay_wms {
    return <<'...';
m_delay_wms macro
    local _delayw_msecs_loop_0, _delayw_msecs_loop_1
    movwf   VIC_VAR_DELAY + 1
_delayw_msecs_loop_1:
    clrf   VIC_VAR_DELAY   ;; set to 0 which gets decremented to 0xFF
_delayw_msecs_loop_0:
    decfsz  VIC_VAR_DELAY, F
    goto    _delayw_msecs_loop_0
    decfsz  VIC_VAR_DELAY + 1, F
    goto    _delayw_msecs_loop_1
    endm
...
}

sub m_delay_s {
    return <<'...';
;; 1MHz => 1us per instruction
;; each loop iteration is 3us each
;; there are 2 loops, one for (768 + 3) us
;; and one for the rest in ms
;; we add 3 instructions for the outermost loop
;; 771 * 256 + 3 = 197379 ~= 200000
;; number of outermost loops = seconds * 1000000 / 200000 = seconds * 5
m_delay_s macro secs
    local _delay_secs_loop_0, _delay_secs_loop_1, _delay_secs_loop_2
    local _delay_secs_loop_3
    variable secs_1 = 0
    variable secs_2 = 0
    variable secs_3 = 0
    variable secs_4 = 0
secs_1 = (secs * D'1000000') / D'197379'
secs_2 = ((secs * D'1000000') % D'197379') / 3
secs_4 = (secs_2 >> 8) & 0xFF - 1
secs_3 = 0xFE
    movlw   secs_1
    movwf   VIC_VAR_DELAY + 2
_delay_secs_loop_2:
    clrf    VIC_VAR_DELAY + 1   ;; set to 0 which gets decremented to 0xFF
_delay_secs_loop_1:
    clrf    VIC_VAR_DELAY   ;; set to 0 which gets decremented to 0xFF
_delay_secs_loop_0:
    decfsz  VIC_VAR_DELAY, F
    goto    _delay_secs_loop_0
    decfsz  VIC_VAR_DELAY + 1, F
    goto    _delay_secs_loop_1
    decfsz  VIC_VAR_DELAY + 2, F
    goto    _delay_secs_loop_2
if secs_4 > 0
    movlw secs_4
    movwf VIC_VAR_DELAY + 1
_delay_secs_loop_3:
    clrf VIC_VAR_DELAY
    decfsz VIC_VAR_DELAY, F
    goto $ - 1
    decfsz VIC_VAR_DELAY + 1, F
    goto _delay_secs_loop_3
endif
if secs_3 > 0
    movlw secs_3
    movwf VIC_VAR_DELAY
    decfsz VIC_VAR_DELAY, F
    goto $ - 1
endif
    endm
...
}

sub m_delay_ws {
    return <<'...';
m_delay_ws macro
    local _delayw_secs_loop_0, _delayw_secs_loop_1, _delayw_secs_loop_2
    movwf   VIC_VAR_DELAY + 2
_delayw_secs_loop_2:
    clrf    VIC_VAR_DELAY + 1   ;; set to 0 which gets decremented to 0xFF
_delayw_secs_loop_1:
    clrf    VIC_VAR_DELAY   ;; set to 0 which gets decremented to 0xFF
_delayw_secs_loop_0:
    decfsz  VIC_VAR_DELAY, F
    goto    _delayw_secs_loop_0
    decfsz  VIC_VAR_DELAY + 1, F
    goto    _delayw_secs_loop_1
    decfsz  VIC_VAR_DELAY + 2, F
    goto    _delayw_secs_loop_2
    endm
...
}

sub delay_s {
    my ($self, $t) = @_;
    return $self->delay($t * 1e6) if $t =~ /^\d+$/;
    return $self->delay_w(s => uc($t));
}

sub delay_ms {
    my ($self, $t) = @_;
    return $self->delay($t * 1000) if $t =~ /^\d+$/;
    return $self->delay_w(ms => uc($t));
}

sub delay_us {
    my ($self, $t) = @_;
    return $self->delay($t) if $t =~ /^\d+$/;
    return $self->delay_w(us => uc($t));
}

sub delay_w {
    my ($self, $unit, $varname) = @_;
    my $funcs = {};
    my $macros = { m_delay_var => $self->m_delay_var };
    my $fn = "_delay_w$unit";
    my $mac = "m_delay_w$unit";
    my $code = << "...";
\tmovf $varname, W
\tcall $fn
...
    $funcs->{$fn} = << "....";
\t$mac
\treturn
....
    $macros->{$mac} = $self->$mac;
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub delay {
    my ($self, $t) = @_;
    return $self->delay_w(s => uc($t)) unless $t =~ /^\d+$/;
    return '' if $t <= 0;
    # divide the time into component seconds, milliseconds and microseconds
    my $sec = POSIX::floor($t / 1e6);
    my $ms = POSIX::floor(($t - $sec * 1e6) / 1000);
    my $us = $t - $sec * 1e6 - $ms * 1000;
    my $code = '';
    my $funcs = {};
    # return all as part of the code always
    my $macros = {
        m_delay_var => $self->m_delay_var,
        m_delay_s => $self->m_delay_s,
        m_delay_ms => $self->m_delay_ms,
        m_delay_us => $self->m_delay_us,
    };
    ## more than one function could be called so have them separate
    if ($sec > 0) {
        my $fn = "_delay_${sec}s";
        $code .= "\tcall $fn\n";
        $funcs->{$fn} = <<"....";
\tm_delay_s D'$sec'
\treturn
....
    }
    if ($ms > 0) {
        my $fn = "_delay_${ms}ms";
        $code .= "\tcall $fn\n";
        $funcs->{$fn} = <<"....";
\tm_delay_ms D'$ms'
\treturn
....
    }
    if ($us > 0) {
        # for less than 6 us we just inline the code
        if ($us <= 6) {
            $code .= "\tm_delay_us D'$us'\n";
        } else {
            my $fn = "_delay_${us}us";
            $code .= "\tcall $fn\n";
            $funcs->{$fn} = <<"....";
\tm_delay_us D'$us'
\treturn
....
        }
    }
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub op_SHL {
    my ($self, $var, $bits, %extra) = @_;
    my $literal = qr/^\d+$/;
    my $code = '';
    if ($var !~ $literal and $bits =~ $literal) {
        $var = uc $var;
        $code .= "\t;;;; perform $var << $bits\n";
        if ($bits == 1) {
            $code .= << "...";
\tbcf STATUS, C
\trlf $var, W
\tbtfsc STATUS, C
\tbcf $var, 0
...
        } elsif ($bits == 0) {
            $code .= "\tmovf $var, W\n";
        } else {
            carp "Not implemented. use the 'shl' instruction\n";
            return;
        }
    } elsif ($var =~ $literal and $bits =~ $literal) {
        my $res = $var << $bits;
        $code .= "\t;;;; perform $var << $bits = $res\n";
        $code .= sprintf "\tmovlw 0x%02X\n", $res;
    } else {
        carp "Unable to handle $var << $bits";
        return;
    }
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    return $code;
}

sub op_SHR {
    my ($self, $var, $bits, %extra) = @_;
    my $literal = qr/^\d+$/;
    my $code = '';
    if ($var !~ $literal and $bits =~ $literal) {
        $var = uc $var;
        $code .= "\t;;;; perform $var >> $bits\n";
        if ($bits == 1) {
            $code .= << "...";
\tbcf STATUS, C
\trrf $var, W
\tbtfsc STATUS, C
\tbcf $var, 7
...
        } elsif ($bits == 0) {
            $code .= "\tmovf $var, W\n";
        } else {
            carp "Not implemented. use the 'shr' instruction\n";
            return;
        }
    } elsif ($var =~ $literal and $bits =~ $literal) {
        my $res = $var >> $bits;
        $code .= "\t;;;; perform $var >> $bits = $res\n";
        $code .= sprintf "\tmovlw 0x%02X\n", $res;
    } else {
        carp "Unable to handle $var >> $bits";
        return;
    }
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    return $code;
}

sub shl {
    my ($self, $var, $bits) = @_;
    $var = uc $var;
    my $code = '';
    for (1 .. $bits) {
        $code .= << "...";
\trlf $var, 1
...
    }
    $code .= << "...";
\tbcf STATUS, C
...
}

sub rol {
    my ($self, $var, $bits) = @_;
    $var = uc $var;
    my $code = <<"...";
\tbcf STATUS, C
...
    for (1 .. $bits) {
        $code .= << "...";
\trlf $var, 1
\tbtfsc STATUS, C
\tbsf $var, 0
...
    }
    return $code;
}

sub shr {
    my ($self, $var, $bits) = @_;
    $var = uc $var;
    my $code = '';
    for (1 .. $bits) {
        $code .= << "...";
\trrf $var, 1
...
    }
    $code .= << "...";
\tbcf STATUS, C
...
}

sub ror {
    my ($self, $var, $bits) = @_;
    $var = uc $var;
    my $code = <<"...";
\tbcf STATUS, C
...
    for (1 .. $bits) {
        $code .= << "...";
\trrf $var, 1
\tbtfsc STATUS, C
\tbsf $var, 7
...
    }
    return $code;
}

sub op_ASSIGN_literal {
    my ($self, $var, $val) = @_;
    my $bits = $self->address_bits($var);
    my $bytes = POSIX::ceil($bits / 8);
    my $nibbles = 2 * $bytes;
    $var = uc $var;
    my $code = sprintf "\t;; moves $val (0x%0${nibbles}X) to $var\n", $val;
    if ($val >= 2 ** $bits) {
        carp "Warning: Value $val doesn't fit in $bits-bits";
        $code .= "\t;; $val doesn't fit in $bits-bits. Using ";
        $val &= (2 ** $bits) - 1;
        $code .= sprintf "%d (0x%0${nibbles}X)\n", $val, $val;
    }
    if ($val == 0) {
        $code .= "\tclrf $var\n";
        for (2 .. $bytes) {
            $code .= sprintf "\tclrf $var + %d\n", ($_ - 1);
        }
    } else {
        my $valbyte = $val & ((2 ** 8) - 1);
        $code .= sprintf "\tmovlw 0x%02X\n\tmovwf $var\n", $valbyte if $valbyte > 0;
        $code .= "\tclrf $var\n" if $valbyte == 0;
        for (2 .. $bytes) {
            my $k = $_ * 8;
            my $i = $_ - 1;
            my $j = $i * 8;
            # get the right byte. 64-bit math requires bigint
            $valbyte = (($val & ((2 ** $k) - 1)) & (2 ** $k - 2 ** $j)) >> $j;
            $code .= sprintf "\tmovlw 0x%02X\n\tmovwf $var + $i\n", $valbyte if $valbyte > 0;
            $code .= "\tclrf $var + $i\n" if $valbyte == 0;
        }
    }
    return $code;
}

sub op_ASSIGN {
    my ($self, $var1, $var2, %extra) = @_;
    my $literal = qr/^\d+$/;
    return $self->op_ASSIGN_literal($var1, $var2) if $var2 =~ $literal;
    my $b1 = POSIX::ceil($self->address_bits($var1) / 8);
    my $b2 = POSIX::ceil($self->address_bits($var2) / 8);
    $var2 = uc $var2;
    $var1 = uc $var1;
    my $code = "\t;; moving $var2 to $var1\n";
    if ($b1 == $b2) {
        $code .= "\tmovf $var2, W\n\tmovwf $var1\n";
        for (2 .. $b1) {
            my $i = $_ - 1;
            $code .= "\tmovf $var2 + $i, W\n\tmovwf $var1 + $i\n";
        }
    } elsif ($b1 > $b2) {
        # we are moving a smaller var into a larger var
        $code .= "\t;; $var2 has a smaller size than $var1\n";
        $code .= "\tmovf $var2, W\n\tmovwf $var1\n";
        for (2 .. $b2) {
            my $i = $_ - 1;
            $code .= "\tmovf $var2 + $i, W\n\tmovwf $var1 + $i\n";
        }
        $code .= "\t;; we practice safe assignment here. zero out the rest\n";
        # we practice safe mathematics here. zero-out the rest of the place
        $b2++;
        for ($b2 .. $b1) {
            $code .= sprintf "\tclrf $var1 + %d\n", ($_ - 1);
        }
    } elsif ($b1 < $b2) {
        # we are moving a larger var into a smaller var
        $code .= "\t;; $var2 has a larger size than $var1. truncating..,\n";
        $code .= "\tmovf $var2, W\n\tmovwf $var1\n";
        for (2 .. $b1) {
            my $i = $_ - 1;
            $code .= "\tmovf $var2 + $i, W\n\tmovwf $var1 + $i\n";
        }
    } else {
        carp "Warning: should never reach here: $var1 is $b1 bytes and $var2 is $b2 bytes";
    }
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    return $code;
}

sub op_ASSIGN_w {
    my ($self, $var) = @_;
    return unless $var;
    $var = uc $var;
    return "\tmovwf $var\n";
}

sub op_NOT {
    my $self = shift;
    my $var2 = shift;
    my $pred = '';
    if (@_) {
        my ($dummy, %extra) = @_;
        $pred .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    }
    $var2 = uc $var2;
    return << "...";
\t;;;; generate code for !$var2
\tcomf $var2, W
\tbtfsc STATUS, Z
\tmovlw 1
$pred
...
}

sub op_COMP {
    my $self = shift;
    my $var2 = shift;
    my $pred = '';
    if (@_) {
        my ($dummy, %extra) = @_;
        $pred .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    }
    $var2 = uc $var2;
    return << "...";
\t;;;; generate code for ~$var2
\tcomf $var2, W
$pred
...
}

sub op_ADD_ASSIGN_literal {
    my ($self, $var, $val, %extra) = @_;
    my $b1 = POSIX::ceil($self->address_bits($var) / 8);
    $var = uc $var;
    my $nibbles = 2 * $b1;
    my $code = sprintf "\t;; $var = $var + 0x%0${nibbles}X\n", $val;
    return $code if $val == 0;
    # we expect b1 == 1,2,4,8
    my $b2 = 1 if $val < 2 ** 8;
    $b2 = 2 if ($val < 2 ** 16 and $val >= 2 ** 8);
    $b2 = 4 if ($val < 2 ** 32 and $val >= 2 ** 16);
    $b2 = 8 if ($val < 2 ** 64 and $val >= 2 ** 32);
    if ($b1 > $b2) {
    } elsif ($b1 < $b2) {

    } else {
        # $b1 == $b2
        my $valbyte = $val & ((2 ** 8) - 1);
        $code .= sprintf "\t;; add 0x%02X to byte[0]\n", $valbyte;
        $code .= sprintf "\tmovlw 0x%02X\n\taddwf $var, F\n", $valbyte if $valbyte > 0;
        $code .= sprintf "\tbcf STATUS, C\n" if $valbyte == 0;
        for (2 .. $b1) {
            my $k = $_ * 8;
            my $i = $_ - 1;
            my $j = $i * 8;
            # get the right byte. 64-bit math requires bigint
            $valbyte = (($val & ((2 ** $k) - 1)) & (2 ** $k - 2 ** $j)) >> $j;
            $code .= sprintf "\t;; add 0x%02X to byte[$i]\n", $valbyte;
            $code .= "\tbtfsc STATUS, C\n\tincf $var + $i, F\n";
            $code .= sprintf "\tmovlw 0x%02X\n\taddwf $var + $i, F\n", $valbyte if $valbyte > 0;
        }
    }
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    return $code;
}

## TODO: handle carry bit
sub op_ADD_ASSIGN {
    my ($self, $var, $var2, %extra) = @_;
    my $literal = qr/^\d+$/;
    return $self->op_ADD_ASSIGN_literal($var, $var2, %extra) if $var2 =~ $literal;
    $var = uc $var;
    $var2 = uc $var2;
    my $code = '';
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    return << "...";
\t;;moves $var2 to W
\tmovf $var2, W
\taddwf $var, F
$code
...
}

## TODO: handle carry bit
sub op_SUB_ASSIGN {
    my ($self, $var, $var2) = @_;
    my ($code, $funcs, $macros) = $self->op_SUB($var, $var2);
    $code .= $self->op_ASSIGN_w($var);
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub op_MUL_ASSIGN {
    my ($self, $var, $var2) = @_;
    my ($code, $funcs, $macros) = $self->op_MUL($var, $var2);
    $code .= $self->op_ASSIGN_w($var);
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub op_DIV_ASSIGN {
    my ($self, $var, $var2) = @_;
    my ($code, $funcs, $macros) = $self->op_DIV($var, $var2);
    $code .= $self->op_ASSIGN_w($var);
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub op_MOD_ASSIGN {
    my ($self, $var, $var2) = @_;
    my ($code, $funcs, $macros) = $self->op_MOD($var, $var2);
    $code .= $self->op_ASSIGN_w($var);
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub op_BXOR_ASSIGN {
    my ($self, $var, $var2) = @_;
    my ($code, $funcs, $macros) = $self->op_BXOR($var, $var2);
    $code .= $self->op_ASSIGN_w($var);
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub op_BAND_ASSIGN {
    my ($self, $var, $var2) = @_;
    my ($code, $funcs, $macros) = $self->op_BAND($var, $var2);
    $code .= $self->op_ASSIGN_w($var);
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub op_BOR_ASSIGN {
    my ($self, $var, $var2) = @_;
    my ($code, $funcs, $macros) = $self->op_BOR($var, $var2);
    $code .= $self->op_ASSIGN_w($var);
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub op_SHL_ASSIGN {
    my ($self, $var, $var2) = @_;
    my ($code, $funcs, $macros) = $self->op_SHL($var, $var2);
    $code .= $self->op_ASSIGN_w($var);
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub op_SHR_ASSIGN {
    my ($self, $var, $var2) = @_;
    my ($code, $funcs, $macros) = $self->op_SHR($var, $var2);
    $code .= $self->op_ASSIGN_w($var);
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub op_INC {
    my ($self, $var) = @_;
    # we expect b1 == 1,2,4,8
    my $b1 = POSIX::ceil($self->address_bits($var) / 8);
    my $code = "\t;; increments $var in place\n";
    $code .= "\t;; increment byte[0]\n\tincf $var, F\n";
    for (2 .. $b1) {
        my $j = $_ - 1;
        my $i = $_ - 2;
        $code .= << "...";
\t;; increment byte[$j] iff byte[$i] == 0
\tbtfsc STATUS, Z
\tincf $var + $j, F
...
    }
    return $code;
}

sub op_DEC {
    my ($self, $var) = @_;
    my $b1 = POSIX::ceil($self->address_bits($var) / 8);
    my $code = "\t;; decrements $var in place\n";
    $code .= "\tmovf $var, W\n" if $b1 > 1;
    for (2 .. $b1) {
        my $i = $_ - 1;
        my $j = $i - 1;
        $code .= << "...";
\t;; decrement byte[$i] iff byte[$j] == 0
\tbtfsc STATUS, Z
\tdecf $var + $i, F
...
    }
    $code .= "\t;; decrement byte[0]\n\tdecf $var, F\n";
    return $code;
}

sub op_ADD {
    my ($self, $var1, $var2, %extra) = @_;
    my $literal = qr/^\d+$/;
    my $code = '';
    #TODO: temporary only 8-bit math
    my ($b1, $b2);
    if ($var1 !~ $literal and $var2 !~ $literal) {
        $var1 = uc $var1;
        $var2 = uc $var2;
        $b1 = $self->address_bits($var1);
        $b2 = $self->address_bits($var2);
        # both are variables
        $code .= << "...";
\t;; add $var1 and $var2 without affecting either
\tmovf $var1, W
\taddwf $var2, W
...
    } elsif ($var1 =~ $literal and $var2 !~ $literal) {
        $var2 = uc $var2;
        $var1 = sprintf "0x%02X", $var1;
        $b2 = $self->address_bits($var2);
        # var1 is literal and var2 is variable
        # TODO: check for bits for var1
        $code .= << "...";
\t;; add $var1 and $var2 without affecting $var2
\tmovf  $var2, W
\taddlw $var1
...
    } elsif ($var1 !~ $literal and $var2 =~ $literal) {
        $var1 = uc $var1;
        $var2 = sprintf "0x%02X", $var2;
        # var2 is literal and var1 is variable
        $b1 = $self->address_bits($var1);
        # TODO: check for bits for var1
        $code .= << "...";
\t;; add $var2 and $var1 without affecting $var1
\tmovf $var1, W
\taddlw $var2
...
    } else {
        # both are literals
        # TODO: check for bits
        my $var3 = $var1 + $var2;
        $var3 = sprintf "0x%02X", $var3;
        $code .= << "...";
\t;; $var1 + $var2 = $var3
\tmovlw $var3
...
    }
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    return $code;
}

sub op_SUB {
    my ($self, $var1, $var2, %extra) = @_;
    my $literal = qr/^\d+$/;
    my $code = '';
    #TODO: temporary only 8-bit math
    my ($b1, $b2);
    if ($var1 !~ $literal and $var2 !~ $literal) {
        $var1 = uc $var1;
        $var2 = uc $var2;
        $b1 = $self->address_bits($var1);
        $b2 = $self->address_bits($var2);
        # both are variables
        $code .= << "...";
\t;; perform $var1 - $var2 without affecting either
\tmovf $var2, W
\tsubwf $var1, W
...
    } elsif ($var1 =~ $literal and $var2 !~ $literal) {
        $var2 = uc $var2;
        $var1 = sprintf "0x%02X", $var1;
        $b2 = $self->address_bits($var2);
        # var1 is literal and var2 is variable
        # TODO: check for bits for var1
        $code .= << "...";
\t;; perform $var1 - $var2 without affecting $var2
\tmovf $var2, W
\tsublw $var1
...
    } elsif ($var1 !~ $literal and $var2 =~ $literal) {
        $var1 = uc $var1;
        $var2 = sprintf "0x%02X", $var2;
        # var2 is literal and var1 is variable
        $b1 = $self->address_bits($var1);
        # TODO: check for bits for var1
        $code .= << "...";
\t;; perform $var1 - $var2 without affecting $var1
\tmovlw $var2
\tsubwf $var1, W
...
    } else {
        # both are literals
        # TODO: check for bits
        my $var3 = $var1 - $var2;
        $var3 = sprintf "0x%02X", $var3;
        $code .= << "...";
\t;; $var1 - $var2 = $var3
\tmovlw $var3
...
    }
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    return $code;
}

sub m_multiply_var {
    # TODO: do more than 8 bits
    return << "...";
;;;;;; VIC_VAR_MULTIPLY VARIABLES ;;;;;;;

VIC_VAR_MULTIPLY_UDATA udata
VIC_VAR_MULTIPLICAND res 2
VIC_VAR_MULTIPLIER res 2
VIC_VAR_PRODUCT res 2
...
}

sub m_multiply_macro {
    return << "...";
;;;;;; Taken from Microchip PIC examples.
;;;;;; multiply v1 and v2 using shifting. multiplication of 8-bit values is done
;;;;;; using 16-bit variables. v1 is a variable and v2 is a constant
m_multiply_internal macro
    local _m_multiply_loop_0, _m_multiply_skip
    clrf VIC_VAR_PRODUCT
    clrf VIC_VAR_PRODUCT + 1
_m_multiply_loop_0:
    rrf VIC_VAR_MULTIPLICAND, F
    btfss STATUS, C
    goto _m_multiply_skip
    movf VIC_VAR_MULTIPLIER + 1, W
    addwf VIC_VAR_PRODUCT + 1, F
    movf VIC_VAR_MULTIPLIER, W
    addwf VIC_VAR_PRODUCT, F
    btfsc STATUS, C
    incf VIC_VAR_PRODUCT + 1, F
_m_multiply_skip:
    bcf STATUS, C
    rlf VIC_VAR_MULTIPLIER, F
    rlf VIC_VAR_MULTIPLIER + 1, F
    movf VIC_VAR_MULTIPLICAND, F
    btfss STATUS, Z
    goto _m_multiply_loop_0
    movf VIC_VAR_PRODUCT, W
    endm
;;;;;;; v1 is variable and v2 is literal
m_multiply_1 macro v1, v2
    movf v1, W
    movwf VIC_VAR_MULTIPLIER
    clrf VIC_VAR_MULTIPLIER + 1
    movlw v2
    movwf VIC_VAR_MULTIPLICAND
    clrf VIC_VAR_MULTIPLICAND + 1
    m_multiply_internal
    endm
;;;;;; multiply v1 and v2 using shifting. multiplication of 8-bit values is done
;;;;;; using 16-bit variables. v1 and v2 are variables
m_multiply_2 macro v1, v2
    movf v1, W
    movwf VIC_VAR_MULTIPLIER
    clrf VIC_VAR_MULTIPLIER + 1
    movf v2, W
    movwf VIC_VAR_MULTIPLICAND
    clrf VIC_VAR_MULTIPLICAND + 1
    m_multiply_internal
    endm
...
}

sub op_MUL {
    my ($self, $var1, $var2, %extra) = @_;
    my $literal = qr/^\d+$/;
    my $code = '';
    #TODO: temporary only 8-bit math
    my ($b1, $b2);
    if ($var1 !~ $literal and $var2 !~ $literal) {
        $var1 = uc $var1;
        $var2 = uc $var2;
        $b1 = $self->address_bits($var1);
        $b2 = $self->address_bits($var2);
        # both are variables
        $code .= << "...";
\t;; perform $var1 * $var2 without affecting either
\tm_multiply_2 $var1, $var2
...
    } elsif ($var1 =~ $literal and $var2 !~ $literal) {
        $var2 = uc $var2;
        $var1 = sprintf "0x%02X", $var1;
        $b2 = $self->address_bits($var2);
        # var1 is literal and var2 is variable
        # TODO: check for bits for var1
        $code .= << "...";
\t;; perform $var1 * $var2 without affecting $var2
\tm_multiply_1 $var2, $var1
...
    } elsif ($var1 !~ $literal and $var2 =~ $literal) {
        $var1 = uc $var1;
        $var2 = sprintf "0x%02X", $var2;
        # var2 is literal and var1 is variable
        $b1 = $self->address_bits($var1);
        # TODO: check for bits for var1
        $code .= << "...";
\t;; perform $var1 * $var2 without affecting $var1
\tm_multiply_1 $var1, $var2
...
    } else {
        # both are literals
        # TODO: check for bits
        my $var3 = $var1 * $var2;
        $var3 = sprintf "0x%02X", $var3;
        $code .= << "...";
\t;; $var1 * $var2 = $var3
\tmovlw $var3
...
    }
    my $macros = {
        m_multiply_var => $self->m_multiply_var,
        m_multiply_macro => $self->m_multiply_macro,
    };
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    return wantarray ? ($code, {}, $macros) : $code;
}

sub m_divide_var {
    # TODO: do more than 8 bits
    return << "...";
;;;;;; VIC_VAR_DIVIDE VARIABLES ;;;;;;;

VIC_VAR_DIVIDE_UDATA udata
VIC_VAR_DIVISOR res 2
VIC_VAR_REMAINDER res 2
VIC_VAR_QUOTIENT res 2
VIC_VAR_BITSHIFT res 2
VIC_VAR_DIVTEMP res 1
...
}

sub m_divide_macro {
    return << "...";
;;;;;; Taken from Microchip PIC examples.
m_divide_internal macro
    local _m_divide_shiftuploop, _m_divide_loop, _m_divide_shift
    clrf VIC_VAR_QUOTIENT
    clrf VIC_VAR_QUOTIENT + 1
    clrf VIC_VAR_BITSHIFT + 1
    movlw 0x01
    movwf VIC_VAR_BITSHIFT
_m_divide_shiftuploop:
    bcf STATUS, C
    rlf VIC_VAR_DIVISOR, F
    rlf VIC_VAR_DIVISOR + 1, F
    bcf STATUS, C
    rlf VIC_VAR_BITSHIFT, F
    rlf VIC_VAR_BITSHIFT + 1, F
    btfss VIC_VAR_DIVISOR + 1, 7
    goto _m_divide_shiftuploop
_m_divide_loop:
    movf VIC_VAR_DIVISOR, W
    subwf VIC_VAR_REMAINDER, W
    movwf VIC_VAR_DIVTEMP
    movf VIC_VAR_DIVISOR + 1, W
    btfss STATUS, C
    addlw 0x01
    subwf VIC_VAR_REMAINDER + 1, W
    btfss STATUS, C
    goto _m_divide_shift
    movwf VIC_VAR_REMAINDER + 1
    movf VIC_VAR_DIVTEMP, W
    movwf VIC_VAR_REMAINDER
    movf VIC_VAR_BITSHIFT + 1, W
    addwf VIC_VAR_QUOTIENT + 1, F
    movf VIC_VAR_BITSHIFT, W
    addwf VIC_VAR_QUOTIENT, F
_m_divide_shift:
    bcf STATUS, C
    rrf VIC_VAR_DIVISOR + 1, F
    rrf VIC_VAR_DIVISOR, F
    bcf STATUS, C
    rrf VIC_VAR_BITSHIFT + 1, F
    rrf VIC_VAR_BITSHIFT, F
    btfss STATUS, C
    goto _m_divide_loop
    endm
;;;;;; v1 and v2 are variables
m_divide_2 macro v1, v2
    movf v1, W
    movwf VIC_VAR_REMAINDER
    clrf VIC_VAR_REMAINDER + 1
    movf v2, W
    movwf VIC_VAR_DIVISOR
    clrf VIC_VAR_DIVISOR + 1
    m_divide_internal
    movf VIC_VAR_QUOTIENT, W
    endm
;;;;;; v1 is literal and v2 is variable
m_divide_1a macro v1, v2
    movlw v1
    movwf VIC_VAR_REMAINDER
    clrf VIC_VAR_REMAINDER + 1
    movf v2, W
    movwf VIC_VAR_DIVISOR
    clrf VIC_VAR_DIVISOR + 1
    m_divide_internal
    movf VIC_VAR_QUOTIENT, W
    endm
;;;;;;; v2 is literal and v1 is variable
m_divide_1b macro v1, v2
    movf v1, W
    movwf VIC_VAR_REMAINDER
    clrf VIC_VAR_REMAINDER + 1
    movlw v2
    movwf VIC_VAR_DIVISOR
    clrf VIC_VAR_DIVISOR + 1
    m_divide_internal
    movf VIC_VAR_QUOTIENT, W
    endm
m_mod_2 macro v1, v2
    m_divide_2 v1, v2
    movf VIC_VAR_REMAINDER, W
    endm
;;;;;; v1 is literal and v2 is variable
m_mod_1a macro v1, v2
    m_divide_1a v1, v2
    movf VIC_VAR_REMAINDER, W
    endm
;;;;;;; v2 is literal and v1 is variable
m_mod_1b macro v1, v2
    m_divide_1b v1, v2
    movf VIC_VAR_REMAINDER, W
    endm
...
}

sub op_DIV {
    my ($self, $var1, $var2, %extra) = @_;
    my $literal = qr/^\d+$/;
    my $code = '';
    #TODO: temporary only 8-bit math
    my ($b1, $b2);
    if ($var1 !~ $literal and $var2 !~ $literal) {
        $var1 = uc $var1;
        $var2 = uc $var2;
        $b1 = $self->address_bits($var1);
        $b2 = $self->address_bits($var2);
        # both are variables
        $code .= << "...";
\t;; perform $var1 / $var2 without affecting either
\tm_divide_2 $var1, $var2
...
    } elsif ($var1 =~ $literal and $var2 !~ $literal) {
        $var2 = uc $var2;
        $var1 = sprintf "0x%02X", $var1;
        $b2 = $self->address_bits($var2);
        # var1 is literal and var2 is variable
        # TODO: check for bits for var1
        $code .= << "...";
\t;; perform $var1 / $var2 without affecting $var2
\tm_divide_1a $var1, $var2
...
    } elsif ($var1 !~ $literal and $var2 =~ $literal) {
        $var1 = uc $var1;
        $var2 = sprintf "0x%02X", $var2;
        # var2 is literal and var1 is variable
        $b1 = $self->address_bits($var1);
        # TODO: check for bits for var1
        $code .= << "...";
\t;; perform $var1 / $var2 without affecting $var1
\tm_divide_1b $var1, $var2
...
    } else {
        # both are literals
        # TODO: check for bits
        my $var3 = int($var1 / $var2);
        $var3 = sprintf "0x%02X", $var3;
        $code .= << "...";
\t;; $var1 / $var2 = $var3
\tmovlw $var3
...
    }
    my $macros = {
        m_divide_var => $self->m_divide_var,
        m_divide_macro => $self->m_divide_macro,
    };
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    return wantarray ? ($code, {}, $macros) : $code;
}

sub op_MOD {
    my ($self, $var1, $var2, %extra) = @_;
    my $literal = qr/^\d+$/;
    my $code = '';
    #TODO: temporary only 8-bit math
    my ($b1, $b2);
    if ($var1 !~ $literal and $var2 !~ $literal) {
        $var1 = uc $var1;
        $var2 = uc $var2;
        $b1 = $self->address_bits($var1);
        $b2 = $self->address_bits($var2);
        # both are variables
        $code .= << "...";
\t;; perform $var1 / $var2 without affecting either
\tm_mod_2 $var1, $var2
...
    } elsif ($var1 =~ $literal and $var2 !~ $literal) {
        $var2 = uc $var2;
        $var1 = sprintf "0x%02X", $var1;
        $b2 = $self->address_bits($var2);
        # var1 is literal and var2 is variable
        # TODO: check for bits for var1
        $code .= << "...";
\t;; perform $var1 / $var2 without affecting $var2
\tm_mod_1a $var1, $var2
...
    } elsif ($var1 !~ $literal and $var2 =~ $literal) {
        $var1 = uc $var1;
        $var2 = sprintf "0x%02X", $var2;
        # var2 is literal and var1 is variable
        $b1 = $self->address_bits($var1);
        # TODO: check for bits for var1
        $code .= << "...";
\t;; perform $var1 / $var2 without affecting $var1
\tm_mod_1b $var1, $var2
...
    } else {
        # both are literals
        # TODO: check for bits
        my $var3 = int($var1 % $var2);
        $var3 = sprintf "0x%02X", $var3;
        $code .= << "...";
\t;; $var1 / $var2 = $var3
\tmovlw $var3
...
    }
    my $macros = {
        m_divide_var => $self->m_divide_var,
        m_divide_macro => $self->m_divide_macro,
    };
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    return wantarray ? ($code, {}, $macros) : $code;
}

sub op_BXOR {
    my ($self, $var1, $var2, %extra) = @_;
    my $literal = qr/^\d+$/;
    my $code = '';
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    if ($var1 !~ $literal and $var2 !~ $literal) {
        $var1 = uc $var1;
        $var2 = uc $var2;
        return << "...";
\t;; perform $var1 ^ $var2 and move into W
\tmovf $var1, W
\txorwf $var2, W
$code
...
    } elsif ($var1 !~ $literal and $var2 =~ $literal) {
        $var1 = uc $var1;
        $var2 = sprintf "0x%02X", $var2;
        return << "...";
\t;; perform $var1 ^ $var2 and move into W
\tmovlw $var2
\txorwf $var1, W
$code
...
    } elsif ($var1 =~ $literal and $var2 !~ $literal) {
        $var2 = uc $var2;
        $var1 = sprintf "0x%02X", $var1;
        return << "...";
\t;; perform $var1 ^ $var2 and move into W
\tmovlw $var1
\txorwf $var2, W
$code
...
    } else {
        my $var3 = $var1 ^ $var2;
        $var3 = sprintf "0x%02X", $var3;
        return << "...";
\t;; $var3 = $var1 ^ $var2. move into W
\tmovlw $var3
$code
...
    }
}

sub op_BAND {
    my ($self, $var1, $var2, %extra) = @_;
    my $literal = qr/^\d+$/;
    my $code = '';
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    if ($var1 !~ $literal and $var2 !~ $literal) {
        $var1 = uc $var1;
        $var2 = uc $var2;
        return << "...";
\t;; perform $var1 & $var2 and move into W
\tmovf $var1, W
\tandwf $var2, W
$code
...
    } elsif ($var1 !~ $literal and $var2 =~ $literal) {
        $var1 = uc $var1;
        $var2 = sprintf "0x%02X", $var2;
        return << "...";
\t;; perform $var1 & $var2 and move into W
\tmovlw $var2
\tandwf $var1, W
$code
...
    } elsif ($var1 =~ $literal and $var2 !~ $literal) {
        $var2 = uc $var2;
        $var1 = sprintf "0x%02X", $var1;
        return << "...";
\t;; perform $var1 & $var2 and move into W
\tmovlw $var1
\tandwf $var2, W
$code
...
    } else {
        my $var3 = $var2 & $var1;
        $var3 = sprintf "0x%02X", $var3;
        return << "...";
\t;; $var3 = $var1 & $var2. move into W
\tmovlw $var3
$code
...
    }
}

sub op_BOR {
    my ($self, $var1, $var2, %extra) = @_;
    my $literal = qr/^\d+$/;
    my $code = '';
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    if ($var1 !~ $literal and $var2 !~ $literal) {
        $var1 = uc $var1;
        $var2 = uc $var2;
        return << "...";
\t;; perform $var1 | $var2 and move into W
\tmovf $var1, W
\tiorwf $var2, W
$code
...
    } elsif ($var1 !~ $literal and $var2 =~ $literal) {
        $var1 = uc $var1;
        $var2 = sprintf "0x%02X", $var2;
        return << "...";
\t;; perform $var1 | $var2 and move into W
\tmovlw $var2
\tiorwf $var1, W
$code
...
    } elsif ($var1 =~ $literal and $var2 !~ $literal) {
        $var2 = uc $var2;
        $var1 = sprintf "0x%02X", $var1;
        return << "...";
\t;; perform $var1 | $var2 and move into W
\tmovlw $var1
\tiorwf $var2, W
$code
...
    } else {
        my $var3 = $var1 | $var2;
        $var3 = sprintf "0x%02X", $var3;
        return << "...";
\t;; $var3 = $var1 | $var2. move into W
\tmovlw $var3
$code
...
    }
}

sub get_predicate {
    my ($self, $comment, %extra) = @_;
    my $pred = '';
    ## predicate can be either a result or a jump block
    unless (defined $extra{RESULT}) {
        my $flabel = $extra{SWAP} ? $extra{TRUE} : $extra{FALSE};
        my $tlabel = $extra{SWAP} ? $extra{FALSE} : $extra{TRUE};
        my $elabel = $extra{END};
        $pred .= << "..."
\tbtfss STATUS, Z ;; $comment ?
\tgoto $flabel
\tgoto $tlabel
$elabel:
...
    } else {
        my $flabel = $extra{SWAP} ? "$extra{END}_t_$extra{COUNTER}" :
                        "$extra{END}_f_$extra{COUNTER}";
        my $tlabel = $extra{SWAP} ? "$extra{END}_f_$extra{COUNTER}" :
                        "$extra{END}_t_$extra{COUNTER}";
        my $elabel = "$extra{END}_e_$extra{COUNTER}";
        $pred .=  << "...";
\tbtfss STATUS, Z ;; $comment ?
\tgoto $flabel
\tgoto $tlabel
$flabel:
\tclrw
\tgoto $elabel
$tlabel:
\tmovlw 0x01
$elabel:
...
        $pred .= $self->op_ASSIGN_w($extra{RESULT});
    }
    return $pred;
}

sub get_predicate_literals {
    my ($self, $comment, $res, %extra) = @_;
    if (defined $extra{RESULT}) {
        my $tcode = 'movlw 0x01';
        my $fcode = 'clrw';
        my $code;
        if ($res) {
            $code = $extra{SWAP} ? $fcode : $tcode;
        } else {
            $code = $extra{SWAP} ? $tcode : $fcode;
        }
        my $ecode = $self->op_ASSIGN_w($extra{RESULT});
        return "\t$code ;;$comment\n$ecode\n";
    } else {
        my $label;
        if ($res) {
            $label = $extra{SWAP} ? $extra{FALSE} : $extra{TRUE};
        } else {
            $label = $extra{SWAP} ? $extra{TRUE} : $extra{FALSE};
        }
        return "\tgoto $label ;; $comment\n$extra{END}:\n";
    }
}

sub op_EQ {
    my ($self, $lhs, $rhs, %extra) = @_;
    my $comment = $extra{SWAP} ? "$lhs != $rhs" : "$lhs == $rhs";
    my $pred = $self->get_predicate($comment, %extra);
    my $literal = qr/^\d+$/;
    if ($lhs !~ $literal and $rhs !~ $literal) {
        # lhs and rhs are variables
        $rhs = uc $rhs;
        $lhs = uc $lhs;
        return << "...";
\tbcf STATUS, Z
\tmovf $rhs, W
\txorwf $lhs, W
$pred
...
    } elsif ($rhs !~ $literal and $lhs =~ $literal) {
        # rhs is variable and lhs is a literal
        $rhs = uc $rhs;
        $lhs = sprintf "0x%02X", $lhs;
        return << "...";
\tbcf STATUS, Z
\tmovf $rhs, W
\txorlw $lhs
$pred
...
    } elsif ($rhs =~ $literal and $lhs !~ $literal) {
        # rhs is a literal and lhs is a variable
        $lhs = uc $lhs;
        $rhs = sprintf "0x%02X", $rhs;
        return << "...";
\tbcf STATUS, Z
\tmovf $lhs, W
\txorlw $rhs
$pred
...
    } else {
        # both rhs and lhs are literals
        my $res = $lhs == $rhs ? 1 : 0;
        return $self->get_predicate_literals("$lhs == $rhs => $res", $res, %extra);
    }
}

sub op_LT {
    my ($self, $lhs, $rhs, %extra) = @_;
    my $pred = $self->get_predicate("$lhs < $rhs", %extra);
    my $literal = qr/^\d+$/;
    if ($lhs !~ $literal and $rhs !~ $literal) {
        # lhs and rhs are variables
        $rhs = uc $rhs;
        $lhs = uc $lhs;
        return << "...";
\t;; perform check for $lhs < $rhs or $rhs > $lhs
\tbcf STATUS, C
\tmovf $rhs, W
\tsubwf $lhs, W
\tbtfsc STATUS, C ;; W($rhs) > F($lhs) => C = 0
$pred
...
    } elsif ($rhs !~ $literal and $lhs =~ $literal) {
        # rhs is variable and lhs is a literal
        $rhs = uc $rhs;
        $lhs = sprintf "0x%02X", $lhs;
        return << "...";
\t;; perform check for $lhs < $rhs or $rhs > $lhs
\tbcf STATUS, C
\tmovf $rhs, W
\tsublw $lhs
\tbtfsc STATUS, C ;; W($rhs) > k($lhs) => C = 0
$pred
...
    } elsif ($rhs =~ $literal and $lhs !~ $literal) {
        # rhs is a literal and lhs is a variable
        $lhs = uc $lhs;
        $rhs = sprintf "0x%02X", $rhs;
        return << "...";
\t;; perform check for $lhs < $rhs or $rhs > $lhs
\tbcf STATUS, C
\tmovlw $rhs
\tsubwf $lhs, W
\tbtfsc STATUS, C ;; W($rhs) > F($lhs) => C = 0
$pred
...
    } else {
        # both rhs and lhs are literals
        my $res = $lhs < $rhs ? 1 : 0;
        return $self->get_predicate_literals("$lhs < $rhs => $res", $res, %extra);
    }
}

sub op_GE {
    my ($self, $lhs, $rhs, %extra) = @_;
    my $pred = $self->get_predicate("$lhs >= $rhs", %extra);
    my $literal = qr/^\d+$/;
    if ($lhs !~ $literal and $rhs !~ $literal) {
        # lhs and rhs are variables
        $rhs = uc $rhs;
        $lhs = uc $lhs;
        return << "...";
\t;; perform check for $lhs >= $rhs or $rhs <= $lhs
\tbcf STATUS, C
\tmovf $rhs, W
\tsubwf $lhs, W
\tbtfss STATUS, C ;; W($rhs) <= F($lhs) => C = 1
$pred
...
    } elsif ($rhs !~ $literal and $lhs =~ $literal) {
        # rhs is variable and lhs is a literal
        $rhs = uc $rhs;
        $lhs = sprintf "0x%02X", $lhs;
        return << "...";
\t;; perform check for $lhs >= $rhs or $rhs <= $lhs
\tbcf STATUS, C
\tmovf $rhs, W
\tsublw $lhs
\tbtfss STATUS, C ;; W($rhs) <= k($lhs) => C = 1
$pred
...
    } elsif ($rhs =~ $literal and $lhs !~ $literal) {
        # rhs is a literal and lhs is a variable
        $lhs = uc $lhs;
        $rhs = sprintf "0x%02X", $rhs;
        return << "...";
\t;; perform check for $lhs >= $rhs or $rhs <= $lhs
\tbcf STATUS, C
\tmovlw $rhs
\tsubwf $lhs, W
\tbtfss STATUS, C ;; W($rhs) <= F($lhs) => C = 1
$pred
...
    } else {
        # both rhs and lhs are literals
        my $res = $lhs >= $rhs ? 1 : 0;
        return $self->get_predicate_literals("$lhs >= $rhs => $res", $res, %extra);
    }
}

sub op_NE {
    my ($self, $lhs, $rhs, %extra) = @_;
    return $self->op_EQ($lhs, $rhs, %extra, SWAP => 1);
}

sub op_LE {
    my ($self, $lhs, $rhs, %extra) = @_;
    # we swap the lhs/rhs stuff instead of using SWAP
    return $self->op_GE($rhs, $lhs, %extra);
}

sub op_GT {
    my ($self, $lhs, $rhs, %extra) = @_;
    # we swap the lhs/rhs stuff instead of using SWAP
    return $self->op_LT($rhs, $lhs, %extra);
}

sub op_AND {
    my ($self, $lhs, $rhs, %extra) = @_;
    my $pred = $self->get_predicate("$lhs && $rhs", %extra);
    my $literal = qr/^\d+$/;
    if ($lhs !~ $literal and $rhs !~ $literal) {
        # lhs and rhs are variables
        $rhs = uc $rhs;
        $lhs = uc $lhs;
        return << "...";
\t;; perform check for $lhs && $rhs
\tbcf STATUS, Z
\tmovf $lhs, W
\tbtfss STATUS, Z  ;; $lhs is false if it is set else true
\tmovf $rhs, W
\tbtfss STATUS, Z ;; $rhs is false if it is set else true
$pred
...
    } elsif ($rhs !~ $literal and $lhs =~ $literal) {
        # rhs is variable and lhs is a literal
        $rhs = uc $rhs;
        $lhs = sprintf "0x%02X", $lhs;
        return << "...";
\t;; perform check for $lhs && $rhs
\tbcf STATUS, Z
\tmovlw $lhs
\txorlw 0x00        ;; $lhs ^ 0 will set the Z bit
\tbtfss STATUS, Z  ;; $lhs is false if it is set else true
\tmovf $rhs, W
\tbtfss STATUS, Z ;; $rhs is false if it is set else true
$pred
...
    } elsif ($rhs =~ $literal and $lhs !~ $literal) {
        # rhs is a literal and lhs is a variable
        $lhs = uc $lhs;
        $rhs = sprintf "0x%02X", $rhs;
        return << "...";
\t;; perform check for $lhs && $rhs
\tbcf STATUS, Z
\tmovlw $rhs
\txorlw 0x00        ;; $rhs ^ 0 will set the Z bit
\tbtfss STATUS, Z  ;; $rhs is false if it is set else true
\tmovf $lhs, W
\tbtfss STATUS, Z ;; $lhs is false if it is set else true
$pred
...
    } else {
        # both rhs and lhs are literals
        my $res = ($lhs && $rhs) ? 1 : 0;
        return $self->get_predicate_literals("$lhs && $rhs => $res", $res, %extra);
    }
}

sub op_OR {
    my ($self, $lhs, $rhs, %extra) = @_;
    my $pred = $self->get_predicate("$lhs || $rhs", %extra);
    my $literal = qr/^\d+$/;
    if ($lhs !~ $literal and $rhs !~ $literal) {
        # lhs and rhs are variables
        $rhs = uc $rhs;
        $lhs = uc $lhs;
        return << "...";
\t;; perform check for $lhs || $rhs
\tbcf STATUS, Z
\tmovf $lhs, W
\tbtfsc STATUS, Z  ;; $lhs is false if it is set else true
\tmovf $rhs, W
\tbtfsc STATUS, Z ;; $rhs is false if it is set else true
$pred
...
    } elsif ($rhs !~ $literal and $lhs =~ $literal) {
        # rhs is variable and lhs is a literal
        $rhs = uc $rhs;
        $lhs = sprintf "0x%02X", $lhs;
        return << "...";
\t;; perform check for $lhs || $rhs
\tbcf STATUS, Z
\tmovlw $lhs
\txorlw 0x00        ;; $lhs ^ 0 will set the Z bit
\tbtfsc STATUS, Z  ;; $lhs is false if it is set else true
\tmovf $rhs, W
\tbtfsc STATUS, Z ;; $rhs is false if it is set else true
$pred
...
    } elsif ($rhs =~ $literal and $lhs !~ $literal) {
        # rhs is a literal and lhs is a variable
        $lhs = uc $lhs;
        $rhs = sprintf "0x%02X", $rhs;
        return << "...";
\t;; perform check for $lhs || $rhs
\tbcf STATUS, Z
\tmovlw $rhs
\txorlw 0x00        ;; $rhs ^ 0 will set the Z bit
\tbtfsc STATUS, Z  ;; $rhs is false if it is set else true
\tmovf $lhs, W
\tbtfsc STATUS, Z ;; $lhs is false if it is set else true
$pred
...
    } else {
        # both rhs and lhs are literals
        my $res = ($lhs || $rhs) ? 1 : 0;
        return $self->get_predicate_literals("$lhs || $rhs => $res", $res, %extra);
    }
}

sub m_sqrt_var {
    return << '...';
;;;;;; VIC_VAR_SQRT VARIABLES ;;;;;;
VIC_VAR_SQRT_UDATA udata
VIC_VAR_SQRT_VAL res 2
VIC_VAR_SQRT_RES res 2
VIC_VAR_SQRT_SUM res 2
VIC_VAR_SQRT_ODD res 2
VIC_VAR_SQRT_TMP res 2
...
}

sub m_sqrt_macro {
    return << '...';
;;;;;; Taken from Microchip PIC examples.
;;;;;; reverse of Finite Difference Squaring
m_sqrt_internal macro
    local _m_sqrt_loop, _m_sqrt_loop_break
    movlw 0x01
    movwf VIC_VAR_SQRT_ODD
    clrf VIC_VAR_SQRT_ODD + 1
    clrf VIC_VAR_SQRT_RES
    clrf VIC_VAR_SQRT_RES + 1
    clrf VIC_VAR_SQRT_SUM
    clrf VIC_VAR_SQRT_SUM + 1
    clrf VIC_VAR_SQRT_TMP
    clrf VIC_VAR_SQRT_TMP + 1
_m_sqrt_loop:
    movf VIC_VAR_SQRT_SUM + 1, W
    addwf VIC_VAR_SQRT_ODD + 1, W
    movwf VIC_VAR_SQRT_TMP + 1
    movf VIC_VAR_SQRT_SUM, W
    addwf VIC_VAR_SQRT_ODD, W
    movwf VIC_VAR_SQRT_TMP
    btfsc STATUS, C
    incf VIC_VAR_SQRT_TMP + 1, F
    movf VIC_VAR_SQRT_TMP, W
    subwf VIC_VAR_SQRT_VAL, W
    movf VIC_VAR_SQRT_TMP + 1, W
    btfss STATUS, C
    addlw 0x01
    subwf VIC_VAR_SQRT_VAL + 1, W
    btfss STATUS, C
    goto _m_sqrt_loop_break
    movf VIC_VAR_SQRT_TMP + 1, W
    movwf VIC_VAR_SQRT_SUM + 1
    movf VIC_VAR_SQRT_TMP, W
    movwf VIC_VAR_SQRT_SUM
    movlw 0x02
    addwf VIC_VAR_SQRT_ODD, F
    btfsc STATUS, C
    incf VIC_VAR_SQRT_ODD + 1, F
    incf VIC_VAR_SQRT_RES, F
    btfsc STATUS, Z
    incf VIC_VAR_SQRT_RES + 1, F
    goto _m_sqrt_loop
_m_sqrt_loop_break:
    endm
m_sqrt_8bit macro v1
    movf v1, W
    movwf VIC_VAR_SQRT_VAL
    clrf VIC_VAR_SQRT_VAL + 1
    m_sqrt_internal
    movf VIC_VAR_SQRT_RES, W
    endm
m_sqrt_16bit macro v1
    movf high v1, W
    movwf VIC_VAR_SQRT_VAL + 1
    movf low v1, W
    movwf VIC_VAR_SQRT_VAL
    m_sqrt_internal
    movf VIC_VAR_SQRT_RES, W
    endm
...
}

sub op_SQRT {
    my ($self, $var1, $dummy, %extra) = @_;
    my $literal = qr/^\d+$/;
    my $code = '';
    #TODO: temporary only 8-bit math
    if ($var1 !~ $literal) {
        $var1 = uc $var1;
        my $b1 = $self->address_bits($var1) || 8;
        # both are variables
        $code .= << "...";
\t;; perform sqrt($var1)
\tm_sqrt_${b1}bit $var1
...
    } elsif ($var1 =~ $literal) {
        my $svar = sqrt $var1;
        my $var2 = sprintf "0x%02X", int($svar);
        $code .= << "...";
\t;; sqrt($var1) = $svar -> $var2;
\tmovlw $var2
...
    } else {
        carp "Warning: $var1 cannot have a square root";
        return;
    }
    my $macros = {
        m_sqrt_var => $self->m_sqrt_var,
        m_sqrt_macro => $self->m_sqrt_macro,
    };
    $code .= $self->op_ASSIGN_w($extra{RESULT}) if $extra{RESULT};
    return wantarray ? ($code, {}, $macros) : $code;
}

sub m_debounce_var {
    return <<'...';
;;;;;; VIC_VAR_DEBOUNCE VARIABLES ;;;;;;;

VIC_VAR_DEBOUNCE_VAR_IDATA idata
;; initialize state to 1
VIC_VAR_DEBOUNCESTATE db 0x01
;; initialize counter to 0
VIC_VAR_DEBOUNCECOUNTER db 0x00

...
}

sub debounce {
    my ($self, $inp, %action) = @_;
    my $action_label = $action{ACTION};
    my $end_label = $action{END};
    return unless $action_label;
    return unless $end_label;
    my ($port, $portbit);
    if (exists $self->pins->{$inp}) {
        ($port, $portbit) = @{$self->pins->{$inp}};
    } elsif (exists $self->ports->{$inp}) {
        $port = $self->ports->{$inp};
        $portbit = 0;
        carp "Port $inp has been supplied. Assuming portbit to debounce is $portbit";
    } else {
        carp "Cannot find $inp in the list of ports or pins";
        return;
    }
    # incase the user does weird stuff override the count and delay
    my $debounce_count = $self->code_config->{debounce}->{count} || 1;
    my $debounce_delay = $self->code_config->{debounce}->{delay} || 1000;
    my ($deb_code, $funcs, $macros) = $self->delay($debounce_delay);
    $macros = {} unless defined $macros;
    $funcs = {} unless defined $funcs;
    $deb_code = 'nop' unless defined $deb_code;
    $macros->{m_debounce_var} = $self->m_debounce_var;
    $debounce_count = sprintf "0x%02X", $debounce_count;
    my $code = <<"...";
\t;;; generate code for debounce $port<$portbit>
$deb_code
\t;; has debounce state changed to down (bit 0 is 0)
\t;; if yes go to debounce-state-down
\tbtfsc   VIC_VAR_DEBOUNCESTATE, 0
\tgoto    _debounce_state_up
_debounce_state_down:
\tclrw
\tbtfss   PORT$port, $portbit
\t;; increment and move into counter
\tincf    VIC_VAR_DEBOUNCECOUNTER, 0
\tmovwf   VIC_VAR_DEBOUNCECOUNTER
\tgoto    _debounce_state_check

_debounce_state_up:
\tclrw
\tbtfsc   PORT$port, $portbit
\tincf    VIC_VAR_DEBOUNCECOUNTER, 0
\tmovwf   VIC_VAR_DEBOUNCECOUNTER
\tgoto    _debounce_state_check

_debounce_state_check:
\tmovf    VIC_VAR_DEBOUNCECOUNTER, W
\txorlw   $debounce_count
\t;; is counter == $debounce_count ?
\tbtfss   STATUS, Z
\tgoto    $end_label
\t;; after $debounce_count straight, flip direction
\tcomf    VIC_VAR_DEBOUNCESTATE, 1
\tclrf    VIC_VAR_DEBOUNCECOUNTER
\t;; was it a key-down
\tbtfss   VIC_VAR_DEBOUNCESTATE, 0
\tgoto    $end_label
\tgoto    $action_label
$end_label:\n
...
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub adc_enable {
    my $self = shift;
    if (@_) {
        my ($clock, $channel) = @_;
        my $scale = int(1e6 / $clock) if $clock > 0;
        $scale = 2 unless $clock;
        $scale = 2 if $scale < 2;
        my $adcs = $self->adcon1_scale->{$scale};
        $adcs = $self->adcon1_scale->{internal} if $self->code_config->{adc}->{internal};
        my $adcon1 = "0$adcs" . '0000';
        my $code = << "...";
\tbanksel ADCON1
\tmovlw B'$adcon1'
\tmovwf ADCON1
...
        if (defined $channel) {
            my $adfm = defined $self->code_config->{adc}->{right_justify} ?
            $self->code_config->{adc}->{right_justify} : 1;
            my $vcfg = $self->code_config->{adc}->{vref} || 0;
            my ($pin, $pbit, $chs) = @{$self->analog_pins->{$channel}};
            my $adcon0 = "$adfm$vcfg$chs" . '01';
            $code .= << "...";
\tbanksel ADCON0
\tmovlw B'$adcon0'
\tmovwf ADCON0
...
        }
        return $code;
    }
    # no arguments have been given
    return << "...";
\tbanksel ADCON0
\tbsf ADCON0, ADON
...
}

sub adc_disable {
    my $self = shift;
    return << "...";
\tbanksel ADCON0
\tbcf ADCON0, ADON
...
}

sub adc_read {
    my ($self, $varhigh, $varlow) = @_;
    $varhigh = uc $varhigh;
    $varlow = uc $varlow if defined $varlow;
    my $code = << "...";
\t;;;delay 5us
\tnop
\tnop
\tnop
\tnop
\tnop
\tbsf ADCON0, GO
\tbtfss ADCON0, GO
\tgoto \$ - 1
\tmovf ADRESH, W
\tmovwf $varhigh
...
    $code .= "\tmovf ADRESL, W\n\tmovwf $varlow\n" if defined $varlow;
    return $code;
}

sub isr_var {
    my $self = shift;
    my ($cb_start, $cb_end) = @{$self->banks->{common_bank}};
    $cb_start = 0x70 unless $cb_start;
    $cb_start = sprintf "0x%02X", $cb_start;
    return << "...";
cblock $cb_start ;; unbanked RAM that is common across all banks
ISR_STATUS
ISR_W
endc
...
}

sub isr_entry {
    my $self = shift;
    my $isr_addr = $self->isr_address;
    my $org_addr = $self->org;
    my $count = $isr_addr - $org_addr - 1;
    my $nops = '';
    for my $i (1 .. $count) {
        $nops .= "\tnop\n";
    }
    return << "...";
$nops
\torg $isr_addr
ISR:
_isr_entry:
\tmovwf ISR_W
\tmovf STATUS, W
\tmovwf ISR_STATUS
...
}

sub isr_exit {
    return << "...";
_isr_exit:
\tmovf ISR_STATUS, W
\tmovwf STATUS
\tswapf ISR_W, F
\tswapf ISR_W, W
\tretfie
...
}

sub timer_enable {
    my ($self, $tmr, $scale, %isr) = @_;
    unless (exists $self->timer_pins->{$tmr}) {
        carp "$tmr is not a timer.";
        return;
    }
    my $psx = $self->timer_prescaler->{$scale} || $self->timer_prescaler->{256};
    my $code = << "...";
;; timer prescaling
\tbanksel OPTION_REG
\tclrw
\tiorlw B'00000$psx'
\tmovwf OPTION_REG
...
    my $isr_code = << "...";
;; enable interrupt servicing
\tbanksel INTCON
\tclrf INTCON
\tbsf INTCON, GIE
\tbsf INTCON, T0IE
...
    my $end_code = << "...";
;; clear the timer
\tbanksel $tmr
\tclrf $tmr
...
    $code .= "\n$isr_code\n" if %isr;
    $code .= "\n$end_code\n";
    my $funcs = {};
    my $macros = {};
    if (%isr) {
        my $action_label = $isr{ISR};
        my $end_label = $isr{END};
        return unless $action_label;
        return unless $end_label;
        $funcs->{isr_timer} = << "..."
_isr_timer:
\tbtfss INTCON, T0IF
\tgoto $end_label
\tbcf   INTCON, T0IF
\tgoto $action_label
$end_label:
...
    }
    return wantarray ? ($code, $funcs, $macros) : $code;
}

sub timer_disable {
    my ($self, $tmr) = @_;
    unless (exists $self->timer_pins->{$tmr}) {
        carp "$tmr is not a timer.";
        return;
    }
    return << "...";
\tbanksel INTCON
\tbcf INTCON, T0IE ;; disable only the timer bit
\tbanksel OPTION_REG
\tmovlw B'00001000'
\tmovwf OPTION_REG
\tbanksel $tmr
\tclrf $tmr
...

}

sub timer {
    my ($self, %action) = @_;
    return unless exists $action{ACTION};
    return unless exists $action{END};
    return << "...";
\tbtfss INTCON, T0IF
\tgoto $action{END}
\tbcf INTCON, T0IF
\tgoto $action{ACTION}
$action{END}:
...
}

sub break { return 'BREAK'; }
sub continue { return 'CONTINUE'; }

sub store_string {
    my ($self, $str, $strvar, $len, $lenvar) = @_;
    $len = sprintf "0x%02X", $len;
    return << "...";
$strvar data "$str" ; $strvar is a string
$lenvar equ $len ; $lenvar is length of $strvar
...
}

sub store_array {
    my ($self, $arr, $arrvar, $sz, $szvar) = @_;
    # use db in 16-bit MCUs for 8-bit values
    # arrays are read-write objects
    my $arrstr = join (",", @$arr) if scalar @$arr;
    $arrstr = '0' unless $arrstr;
    $sz = sprintf "0x%02X", $sz;
    return << "..."
$arrvar db $arr ; array stored as accessible bytes
$szvar equ $sz   ; length of array $arrvar is a constant
...
}

sub store_table {
    my ($self, $table, $label, $tblsz, $tblszvar) = @_;
    my $code = "$label:\n";
    $code .= "\taddwf PCL, F\n";
    if (scalar @$table) {
        foreach (@$table) {
            my $d = sprintf "0x%02X", $_;
            $code .= "\tdt $d\n";
        }
    } else {
        # table is empty
        $code .= "\tdt 0\n";
    }
    $tblsz = sprintf "0x%02X", $tblsz;
    my $szdecl = "$tblszvar equ $tblsz ; size of table at $label\n";
    return wantarray ? ($code, $szdecl) : $code;
}

sub op_TBLIDX {
    my ($self, $table, $idx, %extra) = @_;
    return unless defined $extra{RESULT};
    my $sz = $extra{SIZE};
    $idx = uc $idx;
    $sz = uc $sz if $sz;
    my $szcode = '';
    # check bounds
    $szcode = "\tandlw $sz - 1" if $sz;
    return << "..."
\tmovwf $idx
$szcode
\tcall $table
\tmovwf $extra{RESULT}
...
}

sub op_ARRIDX {
    my ($self, $array, $idx, %extra) = @_;
    XXX { array => $array, index => $idx, %extra };
}

sub op_STRIDX {
    my ($self, $string, $idx, %extra) = @_;
    XXX { string => $string, index => $idx, %extra };
}

sub pwm_details {
    my ($self, $pwm_frequency, $duty, $type, @pins) = @_;
    no bigint;
    #pulse_width = $duty / $pwm_frequency;
    # timer2 prescaler
    my $prescaler = 1; # can be 1, 4 or 16
    # Tosc = 1 / Fosc
    my $f_osc = $self->frequency;
    my $pr2 = POSIX::ceil(($f_osc / 4) / $pwm_frequency); # assume prescaler = 1 here
    if (($pr2 - 1) <= 0xFF) {
        $prescaler = 1; # prescaler stays 1
    } else {
        $pr2 = POSIX::ceil($pr2 / 4); # prescaler is 4 or 16
        $prescaler = (($pr2 - 1) <= 0xFF) ? 4 : 16;
    }
    my $t2con = q{b'00000100'}; # prescaler is 1 or anything else
    $t2con = q{b'00000101'} if $prescaler == 4;
    $t2con = q{b'00000111'} if $prescaler == 16;
    # readjusting PR2 as per supported pre-scalers
    $pr2 = POSIX::ceil((($f_osc / 4) / $pwm_frequency) / $prescaler);
    $pr2--;
    $pr2 &= 0xFF;
    my $ccpr1l_ccp1con54 = POSIX::ceil(($duty * 4 * ($pr2 + 1)) / 100.0);
    my $ccp1con5 = ($ccpr1l_ccp1con54 & 0x02); #bit 5
    my $ccp1con4 = ($ccpr1l_ccp1con54 & 0x01); #bit 4
    my $ccpr1l = ($ccpr1l_ccp1con54 >> 2) & 0xFF;
    my $ccpr1l_x = sprintf "0x%02X", $ccpr1l;
    my $pr2_x = sprintf "0x%02X", $pr2;
    my $p1m = '00' if $type eq 'single';
    $p1m = '01' if $type eq 'full_forward';
    $p1m = '10' if $type eq 'half';
    $p1m = '11' if $type eq 'full_reverse';
    $p1m = '00' unless defined $p1m;
    my $ccp1con = sprintf "b'%s%d%d1100'", $p1m, $ccp1con5, $ccp1con4;
    my %str = (P1D => 0, P1C => 0, P1B => 0, P1A => 0); # default all are port pins
    my %trisc = ();
    foreach my $pin (@pins) {
        my $vpin = $self->convert_to_valid_pin($pin);
        unless ($vpin and exists $self->pins->{$vpin}) {
            carp "$pin is not a valid pin on the microcontroller. Ignoring\n";
            next;
        }
        my ($port, $portpin, $pinno) = @{$self->pins->{$vpin}};
        # the user may use say RC5 instead of CCP1 and we still want the
        # CCP1 name which should really be returned as P1A here
        my $pwm_pin = $self->pwm_pins->{$pinno};
        next unless defined $pwm_pin;
        # pulse steering only needed in Single mode
        $str{$pwm_pin} = 1 if $type eq 'single';
        $trisc{$portpin} = 1;
    }
    my $pstrcon = sprintf "b'0001%d%d%d%d'", $str{P1D}, $str{P1C}, $str{P1B}, $str{P1A};
    my $trisc_bsf = '';
    my $trisc_bcf = '';
    foreach (sort (keys %trisc)) {
        $trisc_bsf .= "\tbsf TRISC, TRISC$_\n";
        $trisc_bcf .= "\tbcf TRISC, TRISC$_\n";
    }
    my $pstrcon_code = '';
    if ($type eq 'single') {
        $pstrcon_code = << "...";
\tbanksel PSTRCON
\tmovlw $pstrcon
\tmovwf PSTRCON
...
    }
    return (
        # actual register values
        CCP1CON => $ccp1con,
        PR2 => $pr2_x,
        T2CON => $t2con,
        CCPR1L => $ccpr1l_x,
        PSTRCON => $pstrcon,
        PSTRCON_CODE => $pstrcon_code,
        # no ECCPAS
        PWM1CON => '0x80', # default
        # code to be added
        TRISC_BSF => $trisc_bsf,
        TRISC_BCF => $trisc_bcf,
        # general comments
        CCPR1L_CCP1CON54 => $ccpr1l_ccp1con54,
        FOSC => $f_osc,
        PRESCALER => $prescaler,
        PWM_FREQUENCY => $pwm_frequency,
        DUTYCYCLE => $duty,
        PINS => \@pins,
        TYPE => $type,
    );
}

sub pwm_code {
    my $self = shift;
    my %details = @_;
    my @pins = @{$details{PINS}};
    return << "...";
;;; PWM Type: $details{TYPE}
;;; PWM Frequency = $details{PWM_FREQUENCY} Hz
;;; Duty Cycle = $details{DUTYCYCLE} / 100
;;; CCPR1L:CCP1CON<5:4> = $details{CCPR1L_CCP1CON54}
;;; CCPR1L = $details{CCPR1L}
;;; CCP1CON = $details{CCP1CON}
;;; T2CON = $details{T2CON}
;;; PR2 = $details{PR2}
;;; PSTRCON = $details{PSTRCON}
;;; PWM1CON = $details{PWM1CON}
;;; Prescaler = $details{PRESCALER}
;;; Fosc = $details{FOSC}
;;; disable the PWM output driver for @pins by setting the associated TRIS bit
\tbanksel TRISC
$details{TRISC_BSF}
;;; set PWM period by loading PR2
\tbanksel PR2
\tmovlw $details{PR2}
\tmovwf PR2
;;; configure the CCP module for the PWM mode by setting CCP1CON
\tbanksel CCP1CON
\tmovlw $details{CCP1CON}
\tmovwf CCP1CON
;;; set PWM duty cycle
\tmovlw $details{CCPR1L}
\tmovwf CCPR1L
;;; configure and start TMR2
;;; - clear TMR2IF flag of PIR1 register
\tbanksel PIR1
\tbcf PIR1, TMR2IF
\tmovlw $details{T2CON}
\tmovwf T2CON
;;; enable PWM output after a new cycle has started
\tbtfss PIR1, TMR2IF
\tgoto \$ - 1
\tbcf PIR1, TMR2IF
;;; enable @pins pin output driver by clearing the associated TRIS bit
$details{PSTRCON_CODE}
;;; disable auto-shutdown mode
\tbanksel ECCPAS
\tclrf ECCPAS
;;; set PWM1CON if half bridge mode
\tbanksel PWM1CON
\tmovlw $details{PWM1CON}
\tmovwf PWM1CON
\tbanksel TRISC
$details{TRISC_BCF}
...
}

sub pwm_single {
    my ($self, $pwm_frequency, $duty, @pins) = @_;
    my %details = $self->pwm_details($pwm_frequency, $duty, 'single', @pins);
    # pulse steering automatically taken care of
    return $self->pwm_code(%details);
}

sub pwm_halfbridge {
    my ($self, $pwm_frequency, $duty, $deadband, @pins) = @_;
    # we ignore the @pins that comes in
    @pins = qw(P1A P1B);
    my %details = $self->pwm_details($pwm_frequency, $duty, 'half', @pins);
    # override PWM1CON
    if (defined $deadband and $deadband > 0) {
        my $fosc = $details{FOSC};
        my $pwm1con = $deadband * $fosc / 4e6; # $deadband is in microseconds
        $pwm1con &= 0x7F; # 6-bits only
        $pwm1con |= 0x80; # clear PRSEN bit
        $details{PWM1CON} = sprintf "0x%02X", $pwm1con;
    }
    return $self->pwm_code(%details);
}

sub pwm_fullbridge {
    my ($self, $direction, $pwm_frequency, $duty, @pins) = @_;
    my $type = 'full_forward';
    $type = 'full_reverse' if $direction =~ /reverse|backward|no?|0/i;
    # we ignore the @pins that comes in
    @pins = qw(P1A P1B P1C P1D);
    my %details = $self->pwm_details($pwm_frequency, $duty, $type, @pins);
    return $self->pwm_code(%details);
}

sub pwm_update {
    my ($self, $pwm_frequency, $duty) = @_;
    # hack into the existing functions to update only what we need
    my @pins = qw(P1A P1B P1C P1D);
    my %details = $self->pwm_details($pwm_frequency, $duty, 'single', @pins);
    my ($ccp1con5, $ccp1con4);
    $ccp1con4 = $details{CCPR1L_CCP1CON54} & 0x0001;
    $ccp1con5 = ($details{CCPR1L_CCP1CON54} >> 1) & 0x0001;
    if ($ccp1con4) {
        $ccp1con4 = "\tbsf CCP1CON, DC1B0";
    } else {
        $ccp1con4 = "\tbcf CCP1CON, DC1B0";
    }
    if ($ccp1con5) {
        $ccp1con5 = "\tbsf CCP1CON, DC1B1";
    } else {
        $ccp1con5 = "\tbcf CCP1CON, DC1B1";
    }
    return << "...";
;;; updating PWM duty cycle for a given frequency
;;; PWM Frequency = $details{PWM_FREQUENCY} Hz
;;; Duty Cycle = $details{DUTYCYCLE} / 100
;;; CCPR1L:CCP1CON<5:4> = $details{CCPR1L_CCP1CON54}
;;; CCPR1L = $details{CCPR1L}
;;; update CCPR1L and CCP1CON<5:4> or the DC1B[01] bits
$ccp1con4
$ccp1con5
\tmovlw $details{CCPR1L}
\tmovwf CCPR1L
...

}

1;

=encoding utf8

=head1 NAME

VIC::PIC::Base

=head1 SYNOPSIS

A class that describes the code to be generated for each specific
microcontroller that maps the VIC syntax back into assembly. This is the
back-end to VIC's front-end.

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
