@ ---------------------------------------------------------------------
@ -- CoreForth starts here --------------------------------------------

    .syntax unified
    .code 16
    .text

    .set ram_start, 0x20000000
    .set eval_words, 0x00010000

    .include "stm32f103_definitions.s"
    .include "CoreForthSE.s"

    .ltorg

sysclock:
    push {r4, r5}
    ldr r0, =8000000
    ldr r4, =RCC
    ldr r4, [r4, #RCC_CFGR]
    mov r5, r4
    ands r5, #0x0c
    beq 1f
    cmp r5, #0x04
    beq 1f
    lsrs r4, #16
    ands r4, #0x3f
    mov r5, r4
    ands r5, #0x01
    beq 2f
    ands r5, #0x02
    beq 3f
2:  lsrs r0, #1
3:  lsrs r4, #2
    adds r4, #2
    mul r0, r0, r4
1:  pop {r4, r5}
    bx lr

    defword "SYSCLOCK", SYSCLOCK
    bl sysclock
    ppush r0
    exit

    defcode "RETI", RETI
    pop {r4 - r12, pc}

    defword ";I", SEMICOLONI, F_IMMED
    bl LIT; .word RETI; bl COMMAXT; bl REVEAL; bl LBRACKET
    exit

    defvar "IVT", IVT, 75 * 4

    defcode "KEY?", KEYQ
    mov r2, #0
    ldr r0, =UART2
    ldr r1, [r0, #UART_SR]
    ands r3, #32
    beq 1f
    mvn r2, #1
1:  push {r2}
    mov pc, lr

    defcode "ERASE-PAGE", ERASE_PAGE
    pop {r1}
    ldr r0, =FPEC
    mov r2, #0x2
    str r2, [r0, #FLASH_CR]
    str r1, [r0, #FLASH_AR]
    ldr r2, [r0, #FLASH_CR]
    orrs r2, #0x40
    str r2, [r0, #FLASH_CR]
1:  ldr r2, [r0, #FLASH_SR]
    ands r2, #0x1
    bne 1b
    mov pc, lr

    defcode "FLASH-PAGE", FLASH_PAGE
    pop {r2}
    pop {r3}
    mov r4, #0x400
    ldr r0, =FPEC
1:  mov r1, #0x1
    str r1, [r0, #FLASH_CR]
    ldrh r1, [r3]
    strh r1, [r2]
2:  ldr r1, [r0, #FLASH_SR]
    ands r1, #0x1
    bne 2b
    adds r2, #2
    adds r3, #2
    subs r4, #2
    bne 1b
    mov pc, lr

    defcode "CON-RX!", CON_RXSTORE
    ldr r0, =addr_CON_RX
    ldr r1, =addr_CON_RX_HEAD
con_store:
    pop {r3}
    ldr r2, [r1]
    strb r3, [r0, r2]
    adds r2, #1
    ands r2, #0x3f
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

    defword "COLD", COLD
    bl EMULATIONQ; bl QBRANCH; .word 1f - .
    bl ROM; bl LIT; .word eval_words; bl EVALUATE
    bl HERE; bl LIT; .word init_here; bl STORE
    bl RAM_DP; bl FETCH; bl LIT; .word init_data_start; bl STORE
    bl LATEST; bl FETCH; bl LIT; .word init_last_word; bl STORE
    @bl ROM_DUMP; bl BYE
1:  bl COPY_FARCALL;
    bl ABORT
@ 1:  bl LATEST; bl FETCH; bl FROMLINK; bl EXECUTE

    defword "INTERPRET", INTERPRET
    bl LIT; .word 0; bl STATE; bl STORE;
    bl TIB; bl XSOURCE; bl STORE;
    bl LIT; .word 0; bl SOURCEINDEX; bl STORE;
    bl ACCEPT; bl SOURCECOUNT; bl STORE; bl SPACE;
    bl XINTERPRET; bl QBRANCH; .word 1f - .
    bl DROP; bl LIT; .word 3f; bl LIT; .word 4; bl TYPE; bl BRANCH; .word 2f - .
1:  bl COUNT; bl TYPE; bl LIT; .word 63; bl EMIT;
2:  bl CR;
    exit
3:  .ascii " ok "

    defword "QUIT", QUIT
1:  bl INTERPRET
    b 1b

    defword "ABORT", ABORT
    bl LIT; .word 1f; bl LIT; .word 34; bl TYPE; bl CR;
    b QUIT
1:
    .ascii "CoreForth revision NNNNNNNN ready."

    .ltorg

    .set last_word, link
    .set last_host, link_host
    .set data_start, ram_here
    .set here, .

