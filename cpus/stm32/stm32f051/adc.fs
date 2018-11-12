\ simple one-shot ADC

$40012000 constant ADC1
    ADC1 $00 + constant ADC1-SR
    ADC1 $04 + constant ADC1-CR1
    ADC1 $08 + constant ADC1-CR2
    ADC1 $0C + constant ADC1-SMPR1
    ADC1 $10 + constant ADC1-SMPR2
    ADC1 $2C + constant ADC1-SQR1
    ADC1 $30 + constant ADC1-SQR2
    ADC1 $34 + constant ADC1-SQR3
    ADC1 $4C + constant ADC1-DR
    ADC1 $304 + constant ADC-CCR

: adc-calib ( -- )  \ not needed on F4, retained for compatibility
  ;

: adc-once ( -- u )  \ read ADC value once
  0 bit ADC1-CR2 bis!  \ set ADON to start ADC
  30 bit ADC1-CR2 bis! \ set SWSTART to begin conversion
  begin 1 bit ADC1-SR bit@ until  \ wait until EOC set
  ADC1-DR @ ;

: adc-init ( -- )  \ initialise ADC
  8 bit RCC-APB2ENR bis!  \ set ADC1EN
  23 bit ADC-CCR bis! \ set TSVREFE for vRefInt use
   0 bit ADC1-CR2 bis!  \ set ADON to enable ADC
  \ 7.5 cycles sampling time is enough for 18 kΩ to ground, measures as zero
  \ even 239.5 cycles is not enough for 470 kΩ, it still leaves 70 mV residual
  %111 21 lshift ADC1-SMPR1 bis! \ set SMP17 to 239.5 cycles for vRefInt
  %110110110 ADC1-SMPR2 bis! \ set SMP0/1/2 to 71.5 cycles, i.e. 83 µs/conv
  adc-once drop ;

: adc# ( pin -- n )  \ convert pin number to adc index
\ nasty way to map the pins (a "c," table offset lookup might be simpler)
\   PA0..7 => 0..7, PB0..1 => 8..9, PC0..5 => 10..15
  dup io# swap  io-port ?dup if shl + 6 + then ;

: adc ( pin -- u )  \ read ADC value
\ IMODE-ADC over io-mode!
\ nasty way to map the pins (a "c," table offset lookup might be simpler)
\   PA0..7 => 0..7, PB0..1 => 8..9, PC0..5 => 10..15
  adc# ADC1-SQR3 !  adc-once ;

: adc-vcc ( -- mv )  \ return estimated Vcc, based on 1.2V internal bandgap
  3300 1200  17 ADC1-SQR3 !  adc-once  */ ;

