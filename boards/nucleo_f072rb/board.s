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
rom_start:
    .long addr_TASKZTOS               /* Top of Stack                 */
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
    .long generic_forth_handler + 1
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
    ldr r1, =0x0000000d
    str r1, [r0, #UART_CR1]
    movs r1, #0
    subs r1, #1
    str r1, [r0, #UART_ICR]

    pop {pc}

    .ltorg

readkey:
    ldr r0, =CPUID
    ldr r0, [r0]
    cmp r0, #0
    bne 1f
    ldr r0, =EMULATOR_UART
    ldr r0, [r0]
    bx lr
1:  push {r1, r2, r3, lr}
    ldr r1, =UART2
    movs r2, #32
2:  ldr r3, [r1, #UART_ISR]
    ands r3, r2
    cmp r3, r2
    bne 2b
    ldr r0, [r1, #UART_RDR]
    pop {r1, r2, r3, pc}

putchar:
    push {r1, r2, r3, lr}
    ldr r1, =CPUID
    ldr r1, [r1]
    cmp r1, #0
    bne 1f
    ldr r1, =EMULATOR_UART
    str r0, [r1]
    b 3f
1:  ldr r3, =UART2
    str r0, [r3, #UART_TDR]
    movs r2, #0x40
2:  ldr r1, [r3, #UART_ISR]
    ands r1, r2
    cmp r1, r2
    bne 2b
3:  pop {r1, r2, r3, pc}

    .ltorg
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
    mov r4, r8
    push {r4}
    mov r4, r9
    push {r4}
    mov r4, r10
    push {r4}
    mov r4, r11
    push {r4}
    movs r1, #1
    orrs r2, r1
    blx r2
    pop {r4}
    mov r11, r4
    pop {r4}
    mov r10, r4
    pop {r4}
    mov r9, r4
    pop {r4}
    mov r8, r4
    pop {r4 - r7, pc}
1:  bx lr

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

    defcode "UNLOCK-FLASH", UNLOCK_FLASH
    push {r0, r1, lr}
    ldr r0, =FPEC
    ldr r1, =0x45670123
    str r1, [r0, #FLASH_KEYR]
    ldr r1, =0xCDEF89AB
    str r1, [r0, #FLASH_KEYR]
    movs r1, #1
    str r1, [r0, #FLASH_CR]
    pop {r0, r1, pc}

    defcode "LOCK-FLASH", LOCK_FLASH
    push {r0, r1, r2, lr}
    ldr r0, =FPEC
    ldr r1, [r0]
    movs r2, #128
    orrs r1, r2
    str r1, [r0]
    pop {r0, r1, r2, pc}

    defcode "KEY?", KEYQ
    movs r2, #0
    ldr r0, =(UART1 + UART_ISR)
    ldr r0, [r0]
    movs r1, #32
    tst r1, r0
    beq 1f
    subs r2, #1
1:  ppush r2
    mov pc, lr

    defvar "SBUF", SBUF, 16
    defvar "SBUF-HEAD", SBUF_HEAD
    defvar "SBUF-TAIL", SBUF_TAIL
    defvar "IVT", IVT, 48 * 4
    defvar "UART0-TASK", UARTZ_TASK

    defword "TURNKEY", TURNKEY
    bl ABORT
    exit

    .ltorg

    .set last_word, link
    .set last_host, link_host
    .set data_start, ram_here
    .set here, .

    .ltorg
