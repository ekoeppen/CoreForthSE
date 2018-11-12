\ interrupt-based USART2 with input ring buffer
\ needs ring.fs,cond.fs,stm32f4/io.h

$40004400 constant USART2
   USART2 $00 + constant USART2-SR
   USART2 $04 + constant USART2-DR
   USART2 $08 + constant USART2-BRR
   USART2 $0C + constant USART2-CR1
\  USART2 $10 + constant USART2-CR2
\  USART2 $14 + constant USART2-CR3
\  USART2 $18 + constant USART2-GPTR

128 4 + buffer: uart-ring

: uart-irq-handler ( -- )  \ handle the USART receive interrupt
  USART2-DR @  \ will drop input when there is no room left
  uart-ring dup ring? if >ring else 2drop then ;

$E000E104 constant NVIC-EN1R \ IRQ 32 to 63 Set Enable Register

: uart-irq-init ( -- )  \ initialise the USART2 using a receive ring buffer
  uart-ring 128 init-ring
  ['] uart-irq-handler irq-usart2 !
  6 bit NVIC-EN1R !  \ enable USART2 interrupt 38
  5 bit USART2-CR1 bis!  \ set RXNEIE
;

: uart-irq-key? ( -- f )  \ input check for interrupt-driven ring buffer
  pause uart-ring ring# 0<> ;
: uart-irq-key ( -- c )  \ input read from interrupt-driven ring buffer
  begin uart-irq-key? until  uart-ring ring> ;

: init ( -- )
  [ifdef] init init [then] \ run previous init if it exists
  uart-irq-init
  ['] uart-irq-key? hook-key?  !
  ['] uart-irq-key  hook-key   !
  ;
