\ rf69 driver
\ uses spi

       $00 constant RF:FIFO
       $01 constant RF:OP
       $07 constant RF:FRF
       $11 constant RF:PA
       $18 constant RF:LNA
       $1F constant RF:AFC
       $24 constant RF:RSSI
       $27 constant RF:IRQ1
       $28 constant RF:IRQ2
       $2F constant RF:SYN1
       $31 constant RF:SYN3
       $39 constant RF:ADDR
       $3A constant RF:BCAST
       $3C constant RF:THRESH
       $3D constant RF:PCONF2
       $3E constant RF:AES

0 2 lshift constant RF:M_SLEEP
1 2 lshift constant RF:M_STDBY
2 2 lshift constant RF:M_FS
3 2 lshift constant RF:M_TX
4 2 lshift constant RF:M_RX

       $C2 constant RF:START_TX
       $42 constant RF:STOP_TX
       $80 constant RF:RCCALSTART

     7 bit constant RF:IRQ1_MRDY
     6 bit constant RF:IRQ1_RXRDY
     3 bit constant RF:IRQ1_RSSI
     2 bit constant RF:IRQ1_TIMEOUT
     0 bit constant RF:IRQ1_SYNC

     6 bit constant RF:IRQ2_FIFO_NE
     3 bit constant RF:IRQ2_SENT
     2 bit constant RF:IRQ2_RECVD
     1 bit constant RF:IRQ2_CRCOK

     variable rf.mode  \ last set chip mode
     variable rf.last  \ flag used to fetch RSSI only once per packet
     variable rf.rssi  \ RSSI signal strength of last reception
     variable rf.lna   \ Low Noise Amplifier setting (set by AGC)
     variable rf.afc   \ Auto Frequency Control offset
     variable rf.buf rom-active @ ram #66 cell- allot rom-active !

create rf:init  \ initialise the radio, each 16-bit word is <reg#,val>
  0200 h, \ packet mode, fsk
  0505 h, 06C3 h, \ 90.3kHzFdev -> modulation index = 2
  1942 h, 1A42 h, \ RxBw 125khz, AFCBw 125khz
  2607 h, \ disable clkout
  29C4 h, \ RSSI thres -98dB
  2B40 h, \ RSSI timeout after 128 bytes
  2D06 h, \ Preamble 6 bytes
  2E98 h, \ sync size 3 bytes
  2FF0 h, \ sync1: 0xAA -- this is really the last preamble byte
  3012 h, \ sync2: 0x2D -- actual sync byte
  3178 h, \ sync3: network group
  3710 h, \ drop pkt if CRC fails \ 37D8 h, \ deliver even if CRC fails
  3840 h, \ max 64 byte payload
  0 h,  \ sentinel

\ r/w access to the RF registers
: rf!@ ( b reg -- b ) +rf-spi >rf-spi >rf-spi> -rf-spi ;
: rf! ( b reg -- ) $80 or rf!@ drop ;
: rf@ ( reg -- b ) 0 swap rf!@ ;

: rf-h! ( h -- ) dup $FF and swap 8 rshift rf! ;

: rf!mode ( b -- )  \ set the radio mode, and store a copy in a variable
  dup rf.mode !
  RF:OP rf@  $E3 and  or RF:OP rf!
  begin  RF:IRQ1 rf@  RF:IRQ1_MRDY and  until ;

: rf-config! ( addr -- ) \ load many registers from <reg,value> array, zero-terminated
  RF:M_STDBY rf!mode \ some regs don't program in sleep mode, go figure...
  begin  dup h@  ?dup while  rf-h!  2+ repeat drop
  ;

: rf-freq ( u -- )  \ set the frequency, supports any input precision
  begin dup #100000000 < while #10 * repeat
  ( f ) 2 lshift  #32000000 #11 rshift u/mod nip  \ avoid / use u/ instead
  ( u ) dup #10 rshift  RF:FRF rf!
  ( u ) dup #2 rshift  RF:FRF 1+ rf!
  ( u ) #6 lshift RF:FRF 2+ rf!
  ;

: rf-check ( b -- )  \ check that the register can be accessed over SPI
  begin  dup RF:SYN1 rf!  RF:SYN1 rf@  over = until
  drop ;

\ rf-rssi checks whether the rssi bit is set in IRQ1 reg and sets the LED to match.
\ It also checks whether there is an rssi timeout and restarts the receiver if so.
: rf-rssi ( -- )
  RF:IRQ1 rf@
  dup RF:IRQ1_RSSI and 3 rshift LED1 io!
  dup RF:IRQ1_TIMEOUT and if
      RF:M_FS rf!mode
    then
  drop ;

\ rf-timeout checks whether there is an rssi timeout and restarts the receiver if so.
: rf-timeout ( -- )
  RF:IRQ1 rf@ RF:IRQ1_TIMEOUT and if
    RF:M_FS rf!mode
  then ;

\ rf-status fetches the IRQ1 reg, checks whether rx_sync is set and was not set
\ in rf.last. If so, it saves rssi, lna, and afc values; and then updates rf.last.
\ rf.last ensures that the info is grabbed only once per packet.
: rf-status ( -- )  \ update status values on sync match
  RF:IRQ1 rf@  RF:IRQ1_SYNC and  rf.last @ <> if
    rf.last  RF:IRQ1_SYNC over xor!  @ if
      RF:RSSI rf@  rf.rssi !
      RF:LNA rf@  3 rshift  7 and  rf.lna !
      RF:AFC rf@  8 lshift  RF:AFC 1+ rf@  or rf.afc !
    then
  then ;

: rf-n@spi ( addr len -- )  \ read N bytes from the FIFO
  0 do  RF:FIFO rf@ over c! 1+  loop drop ;
: rf-n!spi ( addr len -- )  \ write N bytes to the FIFO
  0 do  dup c@ RF:FIFO rf! 1+  loop drop ;

\ this is the intended public API for the RF69 driver

: rf-init ( freq -- )  \ internal init of the RFM69 radio module
  $AA rf-check  $55 rf-check  \ will hang if there is no radio!
  rf:init rf-config!
  rf-freq ;

: rf-power ( n -- )  \ change TX power level (0..31)
  RF:PA rf@ $E0 and or RF:PA rf! ;

: rf-sleep ( -- ) RF:M_SLEEP rf!mode ;  \ put radio module to sleep

: rf-recv ( -- b )  \ check whether a packet has been received, return #bytes
  rf.mode @ RF:M_RX <> if
    0 rf.rssi !  0 rf.afc !
    RF:M_RX rf!mode
  else rf-rssi rf-status then
  RF:IRQ2 rf@  RF:IRQ2_CRCOK and if
    rf.buf $40 rf-n@spi $40
  else 0 then ;

: rf-send ( addr count -- )  \ send out one packet
  RF:M_STDBY rf!mode
  over RF:FIFO rf!
  ( addr count ) rf-n!spi
  RF:M_TX rf!mode
  begin RF:IRQ2 rf@ RF:IRQ2_SENT and until
  RF:M_STDBY rf!mode ;

: rf-info ( -- )  \ display reception parameters as hex string
  rf.rssi @ h.2 rf.lna @ h.2 rf.afc @ h.4 ;

: rf-listen ( -- )  \ init RFM69 and report incoming packets until key press
  0 rf.last !
  begin
    rf-recv ?dup if
      ." RF69 " rf-info
      dup 0 do
        rf.buf i + c@ h.2
        i 1 = if 2- h.2 space then
      loop  cr
    then
  key? until ;

: rf. ( -- )  \ print out all the RF69 registers
  base @ hex
  cr 5 spaces
  $10   0 do i . space loop
  $60 $00 do
    i dup $10 umod if space else cr dup h.2 $3A emit space then
          rf@ h.2
  loop cr base ! ;

: rf-txtest ( n -- )  \ send out a test packet with the number as ASCII chars
  #16 rf-power  pad $40 rf-send ;

