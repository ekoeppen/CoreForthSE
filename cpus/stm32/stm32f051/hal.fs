\ base definitions for STM32F407
\ adapted from mecrisp-stellaris 2.2.1a (GPL3)
\ needs io.fs

: chipid ( -- u1 u2 u3 3 )  \ unique chip ID as N values on the stack
  $1FFFF7AC @ $1FFFF7B0 @ $1FFFF7B4 @ 3 ;
: hwid ( -- u )  \ a "fairly unique" hardware ID as single 32-bit int
  chipid 1 do xor loop ;
: flash-kb ( -- u )  \ return size of flash memory in KB
  $1FFFF7CC h@ ;

$40022000 constant FLASH
    FLASH $0 + constant FLASH-ACR

: jtag-deinit ( -- ) \ implicitly disabled during gpio config
  ;
: swd-deinit ( -- ) \ implicitly disabled during gpio config
  ;

