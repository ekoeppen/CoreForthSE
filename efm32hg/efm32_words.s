@ ---------------------------------------------------------------------
@ -- CoreForth starts here --------------------------------------------

    .syntax unified
    .code 16
    .text

    .set ram_start, 0x20000000
    .set eval_words, 0x00010000

    .include "efm32_definitions.s"
    .include "CoreForthSE.s"

    .ltorg

    defcode "RETI", RETI
    .ifdef THUMB1
    b .
    .else
    pop {r4 - r12, pc}
    .endif

    defword ";I", SEMICOLONI, F_IMMED
    bl LIT; .word RETI; bl COMMAXT; bl REVEAL; bl LBRACKET
    exit

    defvar "IVT", IVT, 75 * 4

    defcode "KEY?", KEYQ
    movs r2, #0
    ldr r0, =USART1_STATUS
    movs r3, #0x80
    ldr r1, [r0]
    ands r1, r3
    beq 1f
    movs r2, #0
    mvns r2, r2
1:  push {r2}
    mov pc, lr

    defcode "ERASE-PAGE", ERASE_PAGE
    mov pc, lr

    defcode "FLASH-PAGE", FLASH_PAGE
    mov pc, lr

    defcode "CON-RX!", CON_RXSTORE
    ldr r0, =addr_CON_RX
    ldr r1, =addr_CON_RX_HEAD
con_store:
    pop {r3}
    ldr r2, [r1]
    strb r3, [r0, r2]
    adds r2, #1
    movs r3, #0x3f
    ands r2, r3
    str r2, [r1]
    mov pc, lr

    defcode "CON-TX!", CON_TXSTORE
    ldr r0, =addr_CON_TX
    ldr r1, =addr_CON_TX_HEAD
    b con_store

    defvar "CON-RX-TAIL", CON_RX_TAIL
    defvar "CON-RX-HEAD", CON_RX_HEAD
    defvar "CON-RX", CON_RX, 64
    defvar "CON-TX-TAIL", CON_TX_TAIL
    defvar "CON-TX-HEAD", CON_TX_HEAD
    defvar "CON-TX", CON_TX, 64
    defvar "UART0-TASK", UARTZ_TASK

    defword ".SP", DOTSP
    movs r0, PSP; bl puthexnumber; bl CR
    exit

    defword "((.S))", DOTSX
    ldr r5, =addr_TASKZTOS;
    movs r6, PSP
    adds r5, #4
2:  cmp r5, r6
    bgt 1f
    ldr r0, [r5]
    bl puthexnumber; bl SPACE;
    adds r5, #4
    b 2b
1:  bl CR; exit

    defword "TURNKEY", TURNKEY
    b ABORT

    .ltorg

    .set last_word, link
    .set last_host, link_host
    .set data_start, ram_here
    .set here, .

