@ -- vim:syntax=asm:foldmethod=marker:foldmarker=@\ --\ ,@\ ---:

@ ---------------------------------------------------------------------
@ -- Definitions ------------------------------------------------------

    .include "definitions.s"

    .set eval_words, 0x00010000

@ ---------------------------------------------------------------------
@ -- Interrupt vectors ------------------------------------------------

    .text
    .syntax unified

    .global rom_start
    .global reset_handler
    .global putchar
    .global init_board
    .global readkey
    .global usart2_irq_handler
    .global generic_forth_handler
    .global unlock_flash
    .global lock_flash
    .global erase_flash

    .type reset_handler, %function
    .type putchar, %function
    .type init_board, %function
    .type readkey, %function
    .type usart2_irq_handler, %function
    .type generic_forth_handler, %function
    .type unlock_flash, %function
    .type lock_flash, %function
    .type erase_flash, %function

rom_start:
    .long ram_top                     /* Top of Stack                 */
    .long reset_handler + 1           /* Reset Handler                */
    .long nmi_handler + 1             /* NMI Handler                  */
    .long hardfault_handler + 1       /* Hard Fault Handler           */
    .long 0
    .long 0
    .long 0
    .long 0
    .long 0
    .long 0
    .long 0
    .long generic_forth_handler + 1   /* SVCall handler               */
    .long 0
    .long 0
    .long 0
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long usart2_irq_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1
    .long generic_forth_handler + 1

    .org 0xc0
    .set end_of_irq, .

@ ---------------------------------------------------------------------
@ -- Board specific code and initialization ---------------------------

code_start:
init_board:
    ldr r0, =CPUID
    ldr r0, [r0]
    cmp r0, #0
    bne 1f
    bx lr
1:  push {lr}

    @ switch to 48MHz PLL from HSI
    ldr r0, =FPEC
    movs r1, #0x11
    str r1, [r0, #FLASH_ACR]

    ldr r0, =RCC

    ldr r1, =0x00280000
    ldr r2, [r0, #RCC_CFGR]
    orrs r1, r2
    str r1, [r0, #RCC_CFGR]

    ldr r1, =0x01000000
    ldr r2, [r0, #RCC_CR]
    orrs r1, r2
    str r1, [r0, #RCC_CR]

    ldr r2, =0x02000000
1:  ldr r1, [r0, #RCC_CR]
    ands r1, r2
    beq 1b

    ldr r1, =0x00000002
    ldr r2, [r0, #RCC_CFGR]
    orrs r1, r2
    str r1, [r0, #RCC_CFGR]

    @ reset the interrupt vector table
    ldr r0, =addr_IVT
    movs r1, #0
    movs r2, 48
2:  str r1, [r0]
    adds r0, r0, #4
    subs r2, r2, #1
    bgt 2b

    @ enable clocks on UART2 and GPIOA
    ldr r0, =RCC
    ldr r1, =(1 << 17)
    str r1, [r0, #RCC_AHBENR]
    ldr r1, =(1 << 17)
    str r1, [r0, #RCC_APB1ENR]

    @ enable pins on GPIOA
    ldr r0, =GPIOA
    ldr r1, =0x280000a0
    str r1, [r0, #GPIO_MODER]
    ldr r1, =0x00001100
    str r1, [r0, #GPIO_AFRL]

    @ enable UART
    ldr r0, =UART2
    ldr r1, =(48000000 / 115200)
    str r1, [r0, #UART_BRR]
    ldr r1, =0x0000002d
    str r1, [r0, #UART_CR1]
    movs r1, #0
    ldr r0, =addr_SBUF_HEAD
    str r1, [r0]
    ldr r0, =addr_SBUF_TAIL
    str r1, [r0]
    subs r1, #1
    str r1, [r0, #UART_ICR]

    @ enable NVIC UART2 IRQ
    movs r0, #0
    msr primask, r0
    movs r0, #0
    msr basepri, r0
    ldr r0, =(NVIC + NVIC_SETENA_BASE)
    ldr r1, =(1 << 28)
    str r1, [r0]
    pop {pc}

    .ltorg

haskey:
    push {lr}
    movs r3, #0
    ldr r1, =addr_SBUF_TAIL
    ldr r1, [r1]
    ldr r2, =addr_SBUF_HEAD
    ldr r2, [r2]
    cmp r2, r1
    beq 1f
    subs r3, #1
1:  subs r6, #4
    str r0, [r6]
    movs r0, r3
    pop {pc}

readkey:
3:  push {lr}
    ldr r1, =addr_SBUF_TAIL
    ldr r3, [r1]
2:  ldr r2, =addr_SBUF_HEAD
    ldr r2, [r2]
    cmp r2, r3
    bne 1f
    wfi
    b 2b
1:  ldr r4, =addr_SBUF
    ldrb r4, [r4, r3]
    adds r3, #1
    movs r2, #0x7f
    ands r3, r2
    str r3, [r1]
    subs r6, #4
    str r0, [r6]
    movs r0, r4
    pop {pc}

putchar:
    push {lr}
1:  ldr r3, =UART2
    str r0, [r3, #UART_TDR]
    movs r2, #0x40
2:  ldr r1, [r3, #UART_ISR]
    ands r1, r2
    cmp r1, r2
    bne 2b
    ldr r0, [r6]
    adds r6, #4
3:  pop {pc}

    .ltorg

unlock_flash:
    ldr r2, =FPEC
    ldr r1, =0x45670123
    str r1, [r2, #FLASH_KEYR]
    ldr r1, =0xCDEF89AB
    str r1, [r2, #FLASH_KEYR]
    movs r1, #1
    str r1, [r2, #FLASH_CR]
    mov pc, lr

lock_flash:
    ldr r2, =FPEC
    ldr r1, [r2]
    movs r3, #128
    orrs r1, r3
    str r1, [r2]
    mov pc, lr

erase_flash:
    push {r0, lr}
    movs r1, r0
    ldr r2, =0xFFFFF800
    ands r1, r2
    subs r2, r0, r1
    ldr r0,=constaddr_RAM_DP
    ldr r0, [r0]
    ldr r0, [r0]
    adds r0, #128
    movs r3, r0
    movs r5, r1
    movs r7, r2
1:  ldr r4, [r1]
    str r4, [r0]
    adds r0, #4
    adds r1, #4
    subs r2, #4
    bgt 1b

    ldr r2, =FPEC
    ldr r1, =0x45670123
    str r1, [r2, #FLASH_KEYR]
    ldr r1, =0xCDEF89AB
    str r1, [r2, #FLASH_KEYR]
    movs r1, #2
    str r1, [r2, #FLASH_CR]
    str r5, [r2, #FLASH_AR]
    movs r1, #66
    str r1, [r2, #FLASH_CR]
    nop
    movs r4, #32
1:  ldr r1, [r2, #FLASH_SR]
    ands r1, r4
    beq 1b
    str r4, [r2, #FLASH_SR]

    movs r0, #1
    str r0, [r2, #FLASH_CR]

2:  ldrh r4, [r3]
    strh r4, [r5]
3:  ldr r1, [r2, #FLASH_SR]
    ands r1, r0
    bne 3b
    adds r3, #2
    adds r5, #2
    subs r7, #2
    bgt 2b
    bl lock_flash
    pop {r0, pc}

@ ---------------------------------------------------------------------
@ -- IRQ handlers -----------------------------------------------------

@ Generic handler which checks if a Forth word is defined to handle the
@ IRQ. If not, this handler will simply return. Note that this will
@ usually lock up the system as the interrupt will be retriggered, the
@ generic handler is not clearing the interrupt.

generic_forth_handler:
    ldr r0, =addr_IVT
    mrs r1, ipsr
    lsls r1, #2
    add r0, r0, r1
    ldr r2, [r0]
    cmp r2, #0
    beq 1f

    push {r4 - r7, lr}
    movs r1, #1
    orrs r2, r1
    blx r2
    pop {r4 - r7, pc}
1:  bx lr

usart2_irq_handler:
    ldr r3, =UART2
    ldr r1, [r3, UART_ISR]
    movs r0, #0x08
    ands r0, r1
    bne 2f
    movs r0, #0x20
    ands r0, r1
    beq 1f
    ldr r0, =addr_SBUF
    ldr r1, =addr_SBUF_HEAD
    ldr r1, [r1]
    ldr r2, [r3, UART_RDR]
    strb r2, [r0, r1]
    adds r1, #1
    movs r0, 0x7F
    ands r0, r1
    ldr r1, =addr_SBUF_HEAD
    str r0, [r1]
1:  movs r1, #0x20
3:  str r1, [r3, UART_ICR]
    bx lr
2:  movs r1, #0x08
    b 3b

nmi_handler:
    b .

hardfault_handler:
    b .

memmanage_handler:
    b .

busfault_handler:
    b .

usagefault_handler:
    b .

svc_handler:
    b .

debugmon_handler:
    b .

pendsv_handler:
    b .

systick_handler:
    b .

    .include "CoreForthSE.s"

    defvar "SBUF", SBUF, 128
    defvar "SBUF-HEAD", SBUF_HEAD
    defvar "SBUF-TAIL", SBUF_TAIL
    defvar "IVT", IVT, 48 * 4

    .ltorg

    .set last_word, link
    .set last_host, link_host
    .set data_start, ram_here
    .set here, .

    .ltorg
