\ hardware SPI driver

$40013000 constant SPI1
     SPI1 $0 + constant SPI1-CR1
     SPI1 $4 + constant SPI1-CR2
     SPI1 $8 + constant SPI1-SR
     SPI1 $C + constant SPI1-DR

: spi. ( -- )  \ display SPI hardware registers
  cr ." CR1 " SPI1-CR1 @ h.4
    ."  CR2 " SPI1-CR2 @ h.4
     ."  SR " SPI1-SR @ h.4 ;

: >spi> ( c -- c )  \ hardware SPI, 8 bits
  begin SPI1-SR @ 2 and until
  SPI1-DR c!
  begin SPI1-SR @ 1 and until
  SPI1-DR c@ ;

\ single byte transfers
: spi> ( -- c ) 0 >spi> ;  \ read byte from SPI
: >spi ( c -- ) >spi> drop ;  \ write byte to SPI

: spi-init ( -- )  \ set up hardware SPI
  #12 bit RCC-APB2ENR bis!  \ set SPI1EN
  %0000001100010100 SPI1-CR1 !  \ clk/8, i.e. 9 MHz, master
  %0001011100000000 SPI1-CR2 !  \ 8 bit data size
  SPI1-SR @ drop  \ appears to be needed to avoid hang in some cases
  %0000001101010100 SPI1-CR1 !  \ clk/8, i.e. 9 MHz, master
;

