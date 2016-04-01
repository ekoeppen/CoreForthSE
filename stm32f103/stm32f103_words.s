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

    defword "FIB", FIB
    @ : fib ( n1 -- n2 ) dup 2 < if drop 1 else dup 1- recurse swap 2 - recurse + then ;
    bl DUP; bl LIT; .word 2; bl LT; bl QBRANCH; .word 1f - .
    bl DROP; bl LIT; .word 1; bl BRANCH; .word 2f - .
1:  bl DUP; bl DECR; bl FIB; bl SWAP; bl LIT; .word 2; bl SUB; bl FIB; bl ADD
2:  exit
    /*
    bl DUP; movs r0, 2; push {r0}; bl LT; pop {r0}; cmp r0, 0; beq 1f;
    bl DROP; movs r0, 1; push {r0}; b 2f;
1:  bl DUP; bl DECR; bl FIB; bl SWAP; movs r0, 2; push {r0}; bl SUB; bl FIB; bl ADD
2:  exit
    */

    defword ".SP", DOTSP
    movs r0, PSP; bl puthexnumber; bl CR
    exit

    defword ".S", DOTS
    ldr r5, =addr_TASKZTOS;
    movs r6, PSP
2:  cmp r5, r6
    bge 1f
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

