@ ---------------------------------------------------------------------
@ -- CoreForth starts here --------------------------------------------

    .syntax unified
    .text

    .set ram_start, 0x20000000
    .set eval_words, 0x00010000

    .include "stm32f072_definitions.s"
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
