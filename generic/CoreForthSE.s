@ -- vim:syntax=armasm:foldmethod=marker:foldmarker=@\ --\ ,@\ ---:

    .global reset_handler

@ ---------------------------------------------------------------------
@ -- Variable definitions ---------------------------------------------

    .set F_IMMED,           0x01
    .set F_HIDDEN,          0x20
    .set F_NODISASM,        0x40
    .set F_LENMASK,         0x1f
    .set F_MARKER,          0x80
    .set F_FLAGSMASK,       0x7f

    .set link,                 0
    .set link_host,            0
    .set ram_here, ram_start

    .set ENABLE_COMPILER,      1

RSP .req sp
PSP .req r6

@ ---------------------------------------------------------------------
@ -- Macros -----------------------------------------------------------

    .macro exit
    pop {pc}
    .endm

    .macro enter
    push {lr}
    .endm

    .macro ppush reg
    adds PSP, #4
    str \reg, [PSP]
    .endm

    .macro ppop reg
    ldr \reg, [PSP]
    subs PSP, #4
    .endm

    .macro pfetch reg
    ldr \reg, [PSP]
    .endm

    .macro pstore reg
    str \reg, [PSP]
    .endm

    .macro checkdef name
    .ifdef \name
    .print "Redefining \name"
    .endif
    .endm

    .macro target_conditional, feature
    .ifndef \feature
    .section .host
    .set link_save, link
    .set link, link_host
    .set conditional_feature, 1
    .endif
    .endm

    .macro end_target_conditional
    .if conditional_feature==1
    .set link_host, link
    .set link, link_save
    .section .text
    .set conditional_feature, 0
    .endif
    .endm

    .macro defword name, label, flags=0
    .align 2, 0
    checkdef \label
    .global name_\label
    .set name_\label , .
    .int link
    .set link, name_\label
    .byte \flags | F_MARKER
    .byte (99f - 98f)
98:
    .ascii "\name"
99:
    .align  2, 0
    .global \label
    .set \label , .
    enter
    @ code field follows
    .endm

    .macro defcode name, label, flags=0
    .align 2, 0
    .global name_\label
    checkdef \label
    .set name_\label , .
    .int link
    .set link, name_\label
    .byte \flags | F_MARKER
    .byte (99f - 98f)
98:
    .ascii "\name"
99:
    .align 2, 0
    .global \label
    checkdef \label
    .set \label , .
    @ code field follows
    .endm

    .macro defconst name, label, value
    .align 2, 0
    .global name_\label
    checkdef \label
    .set name_\label , .
    .int link
    .set link, name_\label
    .byte F_MARKER
    .byte (99f - 98f)
98:
    .ascii "\name"
99:
    .align 2, 0
    .global \label
    .set \label , .
    ldr r0, [pc, #4]
    ppush r0
    mov pc, lr
    .align 2, 0
    .set constaddr_\label , .
    .word \value
    .endm

    .macro defvar name, label, size=4
    defconst \name,\label,ram_here
    .set addr_\label, ram_here
    .global addr_\label
    .set ram_here, ram_here + \size
    .endm

    .macro defdata name, label
    defword \name,\label
    .endm

@ ---------------------------------------------------------------------
@ -- Entry point ------------------------------------------------------

reset_handler:
    bl init_board
    ldr RSP, =addr_TASKZRTOS
    ldr PSP, =addr_TASKZTOS
    @bl TASKZ; bl UPSTORE
    @bl TASKZRTOS; bl RZ; bl STORE
    @bl TASKZTOS; bl SZ; bl STORE
    bl LIT; .word 16; bl BASE; bl STORE
    bl RAM
    bl LIT; .word init_here; bl FETCH; bl ROM_DP; bl STORE
    bl LIT; .word init_data_start; bl FETCH; bl RAM_DP; bl STORE
    bl LIT; .word init_last_word; bl FETCH; bl LATEST; bl STORE
    bl SERIAL_CON
    bl COLD
    .ltorg

init_here:
    .word here
init_data_start:
    .word data_start
init_last_word:
    .word last_word

@ ---------------------------------------------------------------------
@ -- Helper code ------------------------------------------------------

putstring:
    cmp r1, #0
    bgt 1f
    exit
1:  push {r4, r5, lr}
    mov r5, r0
    mov r4, r1
putstring_loop:
    ldrb r0, [r5]
    adds r5, r5, #1
    bl putchar
    subs r4, r4, #1
    bgt putstring_loop
    pop {r4, r5, pc}

readline:
    push {r3, r4, r5, lr}
    mov r4, r0
    mov r5, r0
    movs r3, r1
    beq readline_end
readline_loop:
    bl readkey
    cmp r0, #10
    beq readline_end
    cmp r0, #13
    beq readline_end
    cmp r0, #127
    beq readline_backpspace
    cmp r0, #8
    bne readline_addchar
readline_backpspace:
    cmp r4, r5
    beq readline_loop
    movs r0, #32
    strb r0, [r5]
    subs r5, r5, #1
    adds r3, r3, #1
    movs r0, #8
    bl putchar
    movs r0, #32
    bl putchar
    movs r0, #8
    bl putchar
    b readline_loop
readline_addchar:
    bl putchar
    strb r0, [r5]
    adds r5, r5, #1
    subs r3, r3, #1
    bgt readline_loop
readline_end:
    subs r0, r5, r4
    pop {r3, r4, r5, pc}

puthexnumber:
    push {r3, r4, r5, r6, r7, lr}
    movs r3, #0
    movs r5, #8
    movs r6, #15
    movs r7, #28
puthexnumber_loop:
    rors r0, r7
    mov r4, r0
    ands r0, r6
    cmp r3, #0
    bgt 3f
    cmp r0, #0
    beq 2f
    movs r3, #1
3:  adds r0, r0, #'0'
    cmp r0, #'9'
    ble 1f
    adds r0, r0, #'A' - '0' - 10
1:  bl putchar
2:  mov r0, r4
    subs r5, r5, #1
    bne puthexnumber_loop
    cmp r3, #0
    bne 4f
    movs r0, #'0'
    bl putchar
4:  pop {r3, r4, r5, r6, r7, pc}

    @ Busy delay with three ticks per count
delay:
    subs r0, #1
    bne delay
    bx lr

@ ---------------------------------------------------------------------
@ -- Stack manipulation -----------------------------------------------

    defcode "DROP", DROP
    subs PSP, #4
    mov pc, lr

    defcode "SWAP", SWAP
    ppop r1
    ppop r0
    ppush r1
    ppush r0
    mov pc, lr

    defcode "OVER", OVER
    ppop r1
    ppop r0
    ppush r0
    ppush r1
    ppush r0
    mov pc, lr

    defcode "ROT", ROT
    ppop r0
    ppop r1
    ppop r2
    ppush r1
    ppush r0
    ppush r2
    mov pc, lr

    defcode "?DUP", QDUP
    pfetch r0
    cmp r0, #0
    beq 1f
    ppush r0
1:  mov pc, lr

    defcode "DUP", DUP
    pfetch r0
    ppush r0
    mov pc, lr

    defcode "NIP", NIP
    ppop r0
    ppop r1
    ppush r0
    mov pc, lr

    defcode "TUCK", TUCK
    ppop r0
    ppop r1
    ppush r0
    ppush r1
    ppush r0
    mov pc, lr

    defcode "2DUP", TWODUP
    ppop r0
    ppop r1
    ppush r1
    ppush r0
    ppush r1
    ppush r0
    mov pc, lr

    defcode "2SWAP", TWOSWAP
    ppop r0
    ppop r1
    ppop r2
    ppop r3
    ppush r1
    ppush r0
    ppush r3
    ppush r2
    mov pc, lr

    defcode "2DROP", TWODROP
    subs PSP, PSP, #8
    mov pc, lr

    defcode "2OVER", TWOOVER
    ppop r0
    ppop r1
    ppop r2
    ppop r3
    ppush r3
    ppush r2
    ppush r1
    ppush r0
    ppush r3
    ppush r2
    mov pc, lr

    defcode "PICK", PICK
    ppop r2
    mov r1, PSP
    lsls r2, #2
    subs r1, r2
    ldr r1, [r1]
    ppush r1
    mov pc, lr

    defcode ">R", TOR
    ppop r1
    push {r1}
    mov pc, lr

    defcode "R>", RFROM
    pop {r1}
    ppush r1
    mov pc, lr

    defcode "R@", RFETCH
    ldr r1, [RSP]
    ppush r1
    mov pc, lr

    defcode "RDROP", RDROP
    pop {r4}
    mov pc, lr

    defcode "SP@", SPFETCH
    mov r0, PSP
    ppush r0
    mov pc, lr

    defcode "RP@", RPFETCH
    mov r0, RSP
    ppush r0
    mov pc, lr

    defcode "SP!", SPSTORE
    ppop r0
    mov PSP, r0
    mov pc, lr

    defcode "RP!", RPSTORE
    ppop r0
    mov RSP, r0
    mov pc, lr

    defword "-ROT", ROTROT
    bl ROT; bl ROT
    exit

@ ---------------------------------------------------------------------
@ -- Memory operations -----------------------------------------------

    defconst "CHAR", CHAR, 1
    defconst "CELL", CELL, 4

    defword "CELLS", CELLS
    bl LIT; .word 4; bl MUL
    exit

    defcode "ALIGNED", ALIGNED
    pfetch r0
    adds r0, r0, #3
    movs r1, #3
    mvns r1, r1
    ands r0, r0, r1
    pstore r0
    mov pc, lr

    defcode "C@", FETCHBYTE
    pfetch r0
    ldrb r0, [r0]
    pstore r0
    mov pc, lr

    defcode "C!", STOREBYTE
    ppop r1
    ppop r0
    strb r0, [r1]
    mov pc, lr

    defcode "H@", HFETCH
    ppop r0
    ldrh r0, [r0]
    ppush r0
    mov pc, lr

    defcode "H!", HSTORE
    ppop r1
    ppop r0
    strh r0, [r1]
    mov pc, lr

    defcode "@", FETCH
    ppop r0
    ldr r0, [r0]
    ppush r0
    mov pc, lr

    defcode "!", STORE
    ppop r1
    ppop r0
    str r0, [r1]
    mov pc, lr

    defword "2!", TWOSTORE
    bl SWAP; bl OVER; bl STORE; bl CELL; bl ADD; bl STORE
    exit

    defword "2@", TWOFETCH
    bl DUP; bl CELL; bl ADD; bl FETCH; bl SWAP; bl FETCH
    exit

    defcode "+!", ADDSTORE
    ppop r1
    ppop r0
    ldr r2, [r1]
    adds r2, r2, r0
    str r2, [r1]
    mov pc, lr

    defcode "-!", SUBSTORE
    ppop r1
    ppop r0
    ldr r2, [r1]
    subs r2, r2, r0
    str r2, [r1]
    mov pc, lr

    defcode "FILL", FILL
    ppop r2
fill_code:
    ppop r1
    ppop r0
    cmp r1, #0
    beq fill_done
fill_loop:
    strb r2, [r0]
    adds r0, r0, #1
    subs r1, r1, #1
    bne fill_loop
fill_done:
    mov pc, lr

    defword "BLANK", BLANK
    bl BL; bl FILL
    exit

    defcode "CMOVE>", CMOVEUP
    ppop r0
    ppop r1
    ppop r2
2:  subs r0, r0, #1
    cmp r0, #0
    blt 1f
    ldrb r3, [r2, r0]
    strb r3, [r1, r0]
    b 2b
1:  mov pc, lr

    defcode "CMOVE", CMOVE
    ppop r0
    ppop r1
    ppop r2
2:  subs r0, r0, #1
    cmp r0, #0
    blt 1f
    ldrb r3, [r2]
    strb r3, [r1]
    adds r1, #1
    adds r2, #1
    b 2b
1:  mov pc, lr

    defcode "ALIGNED-MOVE>", ALIGNED_MOVEGT
    ppop r0
    ppop r1
    ppop r2
2:  subs r0, r0, #4
    cmp r0, #0
    blt 1f
    ldr r3, [r2, r0]
    str r3, [r1, r0]
    b 2b
1:  mov pc, lr

    defcode "S=", SEQU
    ppop r2
    ppop r1
    ppop r0
    push {r4, r5}
1:  cmp r2, #0
    beq 2f
    ldrb r4, [r0]
    adds r0, r0, #1
    ldrb r5, [r1]
    adds r1, r1, #1
    subs r5, r5, r4
    bne 3f
    subs r2, r2, #1
    b 1b
3:  mov r2, r5
2:  pop {r4, r5}
    ppush r2
    mov pc, lr

    .ltorg

    defword "/STRING", TRIMSTRING
    bl ROT; bl OVER; bl ADD; bl ROT; bl ROT; bl SUB
    exit

    defword "COUNT", COUNT
    bl DUP; bl INCR; bl SWAP; bl FETCHBYTE
    exit

    defword "(S\")", XSQUOTE
    bl RFROM; bl DECR; bl COUNT; bl TWODUP; bl ADD; bl ALIGNED; bl INCR; bl TOR
    exit

    defword ">>SOURCE", GTGTSOURCE
    bl LIT; .word 1; bl SOURCEINDEX; bl ADDSTORE
    exit

    target_conditional ENABLE_COMPILER

    defword "S\"", SQUOT, F_IMMED
    bl LIT_XT; .word XSQUOTE; bl COMMAXT; bl LIT; .word '"'; bl WORD
    bl FETCHBYTE; bl INCR; bl ALIGNED; bl ALLOT
    bl GTGTSOURCE
    exit

    defword ".\"", DOTQUOT, F_IMMED
    bl SQUOT; bl LIT_XT; .word TYPE; bl COMMAXT
    exit

    defword "SZ\"", SZQUOT, F_IMMED
    bl LIT_XT; .word XSQUOTE; bl COMMAXT; bl LIT; .word '"'; bl WORD
    bl LIT; .word 1; bl OVER; bl ADDSTORE; bl LIT; .word 0; bl OVER; bl DUP; bl FETCHBYTE; bl ADD; bl STOREBYTE
    bl FETCHBYTE; bl INCR; bl ALIGNED; bl ALLOT
    bl GTGTSOURCE
    exit

    end_target_conditional

    defword "PAD", PAD
    bl HERE; bl LIT; .word 128; bl ADD
    exit

@ ---------------------------------------------------------------------
@ -- Arithmetic ------------------------------------------------------

    defcode "1+", INCR
    pfetch r0
    adds r0, r0, #1
    pstore r0
    mov pc, lr

    defcode "1-", DECR
    pfetch r0
    subs r0, r0, #1
    pstore r0
    mov pc, lr

    defcode "4+", INCR4
    pfetch r0
    adds r0, r0, #4
    pstore r0
    mov pc, lr

    defcode "4-", DECR4
    pfetch r0
    subs r0, r0, #4
    pstore r0
    mov pc, lr

    defcode "+", ADD
    ppop r1
    pfetch r0
    adds r0, r1, r0
    pstore r0
    mov pc, lr

    defcode "-", SUB
    ppop r1
    pfetch r0
    subs r0, r0, r1
    pstore r0
    mov pc, lr

    defcode "*", MUL
    ppop r1
    pfetch r0
    muls r0, r1, r0
    pstore r0
    mov pc, lr

    .ifndef THUMB1
    defcode "U/MOD", UDIVMOD
    ppop r1
    ppop r0
    udiv r2, r0, r1
    mls r0, r1, r2, r0
    ppush r0
    ppush r2
    mov pc, lr

    defcode "/MOD", DIVMOD
    ppop r1
    ppop r0
    sdiv r2, r0, r1
    mls r0, r1, r2, r0
    ppush r0
    ppush r2
    mov pc, lr

    defcode "/", DIV
    ppop r1
    ppop r0
    sdiv r0, r0, r1
    ppush r0
    mov pc, lr

    defcode "MOD", MOD
    ppop r1
    ppop r0
    sdiv r2, r0, r1
    mls r0, r1, r2, r0
    ppush r0
    mov pc, lr

    defcode "UMOD", UMOD
    ppop r1
    ppop r0
    udiv r2, r0, r1
    mls r0, r1, r2, r0
    ppush r0
    mov pc, lr

    .else

unsigned_div_mod:               @ r0 / r1 = r3, remainder = r0
    mov     r2, r1              @ put divisor in r2
    mov     r3, r0
    lsrs    r3, #1
1:  cmp     r2, r3
    bgt     3f
    lsls    r2, #1              @ until r2 > r3 / 2
    b       1b
3:  movs    r3, #0              @ initialize quotient
2:  adds    r3, r3              @ double quotien
    cmp     r0, r2              @ can we subtract r2?
    blo     4f
    adds    r3, #1              @ if we can, increment quotiend
    subs    r0, r0, r2          @ and substract
4:  lsrs    r2, #1              @ halve r2,
    cmp     r2, r1              @ and loop until
    bhs     2b                  @ less than divisor
    bx      lr

    defword "U/MOD", UDIVMOD
    ppop r1
    ppop r0
    bl unsigned_div_mod
    ppush r0
    ppush r3
    exit

    defword "/MOD", DIVMOD
    ppop r1
    ppop r0
    bl unsigned_div_mod
    ppush r0
    ppush r3
    exit

    defword "/", DIV
    ppop r1
    ppop r0
    movs r3, #0
    movs r4, #1
    movs r5, #1
    cmp r0, r3
    bge 1f
    subs r4, #2
    muls r0, r4
1:  cmp r1, r3
    bge 2f
    subs r5, #2
    muls r1, r5
2:  bl unsigned_div_mod
    muls r3, r4
    muls r3, r5
    ppush r3
    exit

    defword "MOD", MOD
    ppop r1
    ppop r0
    movs r3, #0
    movs r4, #1
    movs r5, #0
    subs r5, #1
    cmp r0, r3
    bge 1f
    subs r4, #2
    muls r0, r4
1:  cmp r1, r3
    bge 2f
    muls r1, r5
2:  bl unsigned_div_mod
    muls r0, r4
    ppush r0
    exit

    defword "UMOD", UMOD
    ppop r1
    ppop r0
    bl unsigned_div_mod
    ppush r0
    exit
    .endif

    defcode "2*", TWOMUL
    pfetch r0
    .ifndef THUMB1
    lsls r0, r0, #1
    .else
    adds r0, r0
    .endif
    pstore r0
    mov pc, lr

    defcode "2/", TWODIV
    pfetch r0
    asrs r0, r0, #1
    pstore r0
    mov pc, lr

    defcode "ABS", ABS
    pfetch r0
    cmp r0, #0
    bge 1f
    mvns r0, r0
    adds r0, #1
    pstore r0
1:  mov pc, lr

    defcode "MAX", MAX
    ppop r0
    ppop r1
    cmp r0, r1
    bge 1f
    mov r0, r1
1:  ppush r0
    mov pc, lr

    defcode "MIN", MIN
    ppop r0
    ppop r1
    cmp r0, r1
    ble 1f
    mov r0, r1
1:  ppush r0
    mov pc, lr

    defcode "ROR", ROR
    ppop r0
    ppop r1
1:  rors r1, r0
    ppush r0
    mov pc, lr

    defword "ROTATE", ROTATE
    bl DUP; bl ZGT; bl QBRANCH; .word 1f - .; bl LIT; .word 32; bl SWAP; bl SUB; bl ROR
    exit
1:  bl NEGATE; bl ROR
    exit

    defcode "LSHIFT", LSHIFT
    ppop r1
    ppop r0
    lsls r0, r1
    ppush r0
    mov pc, lr

    defword "RSHIFT", RSHIFT
    ppop r1
    ppop r0
    lsrs r0, r1
    ppush r0
    mov pc, lr

    defword "NEGATE", NEGATE
    bl LIT; .word -1; bl MUL
    exit

    defword "WITHIN", WITHIN
    bl OVER; bl SUB; bl TOR; bl SUB; bl RFROM; bl ULT
    exit

    defword "BITE", BITE
    bl DUP; bl LIT; .word 0xff; bl AND; bl SWAP; bl LIT; .word 8; bl ROR
    exit

    defword "CHEW", CHEW
    bl BITE; bl BITE; bl BITE; bl BITE; bl DROP
    exit

@ ---------------------------------------------------------------------
@ -- Boolean operators -----------------------------------------------

    defcode "AND", AND
    ppop r1
    ppop r0
    ands r0, r1, r0
    ppush r0
    mov pc, lr

    defcode "OR", OR
    ppop r1
    ppop r0
    orrs r0, r1, r0
    ppush r0
    mov pc, lr

    defcode "XOR", XOR
    ppop r1
    ppop r0
    eors r0, r1, r0
    ppush r0
    mov pc, lr

    defcode "INVERT", INVERT
    pfetch r0
    mvns r0, r0
    pstore r0
    mov pc, lr

@ ---------------------------------------------------------------------
@ -- Comparisons -----------------------------------------------------

    defcode "=", EQU
    ppop r1
    ppop r0
    movs r2, #0
    cmp r0, r1
    bne 1f
    mvns r2, r2
1:  ppush r2
    mov pc, lr

    defcode "<", LT
    ppop r1
    ppop r0
    movs r2, #0
    cmp r0, r1
    bge 1f
    mvns r2, r2
1:  ppush r2
    mov pc, lr

    defcode "U<", ULT
    ppop r1
    ppop r0
    movs r2, #0
    cmp r0, r1
    bcs 1f
    mvns r2, r2
1:  ppush r2
    mov pc, lr

    defword ">", GT
    bl SWAP; bl LT
    exit

    defword "U>", UGT
    bl SWAP; bl ULT
    exit

    defword "<>", NEQU
    bl EQU; bl INVERT
    exit

    defword "<=", LE
    bl GT; bl INVERT
    exit

    defword ">=", GE
    bl LT; bl INVERT
    exit

    defword "0=", ZEQU
    bl LIT; .word 0; bl EQU
    exit

    defword "0<>", ZNEQU
    bl LIT; .word 0; bl NEQU
    exit

    defword "0<", ZLT
    bl LIT; .word 0; bl LT
    exit

    defword "0>", ZGT
    bl LIT; .word 0; bl GT
    exit

    defword "0<=", ZLE
    bl LIT; .word 0; bl LE
    exit

    defword "0>=", ZGE
    bl LIT; .word 0; bl GE
    exit

@ ---------------------------------------------------------------------
@ -- Input/output ----------------------------------------------------

    defconst "#TIB", TIBSIZE, 128
    defconst "C/BLK", CSLASHBLK, 1024

    defword "SOURCE", SOURCE
    bl XSOURCE; bl FETCH; bl SOURCECOUNT; bl FETCH
    exit

    .ltorg

    defword "(.S)", XPRINTSTACK
1:  bl TWODUP; bl LTGT; bl QBRANCH; .word 2f - .; bl CELL; bl MINUS; bl DUP; bl FETCH; bl DOT; bl BRANCH; .word 1b - .
2:  bl TWODROP; bl CR
    exit

    defword ".S", PRINTSTACK
    bl SPFETCH; bl SZ; bl FETCH; bl XPRINTSTACK
    exit

    defword ".R", PRINTRSTACK
    bl RZ; bl FETCH; bl CELL; bl ADD; bl RPFETCH; bl CELL; bl ADD; bl XPRINTSTACK
    exit

    defcode "PUTCHAR", PUTCHAR
    enter
    ppop r0
    bl putchar
    exit

    defword "LF", LF
    bl LIT; .word 10; bl EMIT
    exit

    defword "CR", CR
    bl LIT; .word 13; bl EMIT; bl LF
    exit

    defconst "BL", BL, 32

    defword "SPACE", SPACE
    bl BL; bl EMIT
    exit

    defword "HOLD", HOLD
    bl LIT; .word 1; bl HP; bl SUBSTORE; bl HP; bl FETCH; bl CSTORE
    exit

    defword "<#", LTNUM
    bl PAD; bl HP; bl STORE
    exit

    defword ">DIGIT", TODIGIT
    bl DUP; bl LIT; .word 9; bl GT; bl LIT; .word 7; bl AND; bl PLUS; bl LIT; .word 48; bl PLUS
    exit

    defword "#", NUM
    bl BASE; bl FETCH; bl UDIVMOD; bl SWAP; bl TODIGIT; bl HOLD
    exit

    defword "#S", NUMS
1:  bl NUM; bl DUP; bl ZEQU; bl QBRANCH; .word 1b - .
    exit

    defword "#>", NUMGT
    bl DROP; bl HP; bl FETCH; bl PAD; bl OVER; bl SUB
    exit

    defword "SIGN", SIGN
    bl ZLT; bl QBRANCH; .word 1f - .
    bl LIT; .word '-'; bl HOLD
1:  exit

    defword "U.", UDOT
    bl LTNUM; bl NUMS; bl NUMGT; bl TYPE; bl SPACE
    exit

    defword ".", DOT
    bl LTNUM; bl DUP; bl ABS; bl NUMS; bl SWAP; bl SIGN; bl NUMGT; bl TYPE; bl SPACE
    exit

    defcode "READ-KEY", READ_KEY
    enter
    bl readkey
    ppush r0
    exit

    defcode "READ-LINE", READ_LINE
    enter
    ldr r0, =constaddr_TIB
    ldr r0, [r0]
    ldr r1, =constaddr_TIBSIZE
    ldr r1, [r1]
    bl readline
    ppush r0
    exit

    .ltorg

    defword "WAIT-KEY", WAIT_KEY
    bl TICKWAIT_KEY; bl FETCH; bl EXECUTE
    exit

    defword "FINISH-OUTPUT", FINISH_OUTPUT
    bl TICKFINISH_OUTPUT; bl FETCH; bl EXECUTE
    exit

    defword "(KEY)", XKEY
    bl WAIT_KEY; bl READ_KEY
    exit

    defword "KEY", KEY
    bl TICKKEY; bl FETCH; bl EXECUTE
    exit

    defword "(EMIT)", XEMIT
    bl FINISH_OUTPUT; bl PUTCHAR
    exit

    defcode "(TYPE)", XTYPE
    enter
    ppop r1
    ppop r0
    bl putstring
    exit

    defword "ACCEPT", ACCEPT
    bl TICKACCEPT; bl FETCH; bl EXECUTE
    exit

    defword "EMIT", EMIT
    bl TICKEMIT; bl FETCH; bl EXECUTE
    exit

    defword "TYPE", TYPE
    bl TICKTYPE; bl FETCH; bl EXECUTE
    exit

    defword "4NUM", FOURNUM
    bl NUM; bl NUM; bl NUM; bl NUM
    exit

    defword "SERIAL-CON", SERIAL_CON
    bl LIT_XT; .word NOOP; bl DUP; bl TICKWAIT_KEY; bl STORE; bl TICKFINISH_OUTPUT; bl STORE
    bl LIT_XT; .word XKEY; bl TICKKEY; bl STORE
    bl LIT_XT; .word XEMIT; bl TICKEMIT; bl STORE
    bl LIT_XT; .word XTYPE; bl TICKTYPE; bl STORE
    bl LIT_XT; .word READ_LINE; bl TICKACCEPT; bl STORE
    exit

    defword "(DUMP-ADDR)", XDUMP_ADDR
    bl CR; bl DUP; bl LTNUM; bl FOURNUM; bl FOURNUM; bl NUMGT; bl TYPE; bl LIT; .word 58; bl EMIT; bl SPACE
    exit

    defword "DUMP", DUMP
    bl BASE; bl FETCH; bl TOR; bl HEX; bl QDUP; bl QBRANCH; .word dump_end - .
    bl SWAP
dump_start_line:
    bl XDUMP_ADDR
dump_line:
    bl DUP; bl FETCHBYTE; bl LTNUM; bl NUM; bl NUM; bl NUMGT; bl TYPE; bl SPACE; bl INCR
    bl SWAP; bl DECR; bl QDUP; bl QBRANCH; .word dump_end - .
    bl SWAP; bl DUP; bl LIT; .word 7; bl AND; bl QBRANCH; .word dump_start_line - .
    bl BRANCH; .word dump_line - .
dump_end:
    bl DROP; bl RFROM; bl BASE; bl STORE
    exit

    defword "DUMPW", DUMPW
    bl BASE; bl FETCH; bl TOR; bl HEX; bl QDUP; bl QBRANCH; .word dumpw_end_final - .
    bl SWAP
dumpw_start_line:
    bl XDUMP_ADDR
dumpw_line:
    bl DUP; bl FETCH; bl LTNUM; bl FOURNUM; bl FOURNUM; bl NUMGT; bl TYPE; bl SPACE; bl INCR4
    bl SWAP; bl DECR4; bl DUP; bl ZGT; bl QBRANCH; .word dumpw_end - .
    bl SWAP; bl DUP; bl LIT; .word 0x1f; bl AND; bl QBRANCH; .word dumpw_start_line - .
    bl BRANCH; .word dumpw_line - .
dumpw_end:
    bl DROP
dumpw_end_final:
    bl DROP; bl RFROM; bl BASE; bl STORE
    exit

    defword "SKIP", SKIP
    bl TOR
1:  bl OVER; bl FETCHBYTE; bl RFETCH; bl EQU; bl OVER; bl ZGT; bl AND; bl QBRANCH; .word 2f - .
    bl LIT; .word 1; bl TRIMSTRING; bl BRANCH; .word 1b - .
2:  bl RDROP
    exit

    defword "SCAN", SCAN
    bl TOR
1:  bl OVER; bl FETCHBYTE; bl RFETCH; bl NEQU; bl OVER; bl ZGT; bl AND; bl QBRANCH; .word 2f - .
    bl LIT; .word 1; bl TRIMSTRING; bl BRANCH; .word 1b - .
2:  bl RDROP
    exit

    defword "?SIGN", ISSIGN
    bl OVER; bl FETCHBYTE; bl LIT; .word 0x2c; bl SUB; bl DUP; bl ABS
    bl LIT; .word 1; bl EQU; bl AND; bl DUP; bl QBRANCH; .word 1f - .
    bl INCR; bl TOR; bl LIT; .word 1; bl TRIMSTRING; bl RFROM
1:  exit

    defword "DIGIT?", ISDIGIT
    bl DUP; bl LIT; .word '9'; bl GT; bl LIT; .word 0x100; bl AND; bl ADD
    bl DUP; bl LIT; .word 0x140; bl GT; bl LIT; .word 0x107; bl AND; bl SUB; bl LIT; .word 0x30; bl SUB
    bl DUP; bl BASE; bl FETCH; bl ULT
    exit

    defword "SETBASE", SETBASE
    bl OVER; bl FETCHBYTE
    bl DUP; bl LIT; .word '$'; bl EQU; bl QBRANCH; .word 1f - .; bl HEX; bl BRANCH; .word 4f - .
1:  bl DUP; bl LIT; .word '#'; bl EQU; bl QBRANCH; .word 2f - .; bl DECIMAL; bl BRANCH; .word 4f - .
2:  bl DUP; bl LIT; .word '%'; bl EQU; bl QBRANCH; .word 3f - .; bl BINARY; bl BRANCH; .word 4f - .
3:  bl DROP
    exit
4:  bl DROP; bl LIT; .word 1; bl TRIMSTRING
    exit

    defword ">NUMBER", TONUMBER
    bl BASE; bl FETCH; bl TOR; bl SETBASE
tonumber_loop:
    bl DUP; bl QBRANCH; .word tonumber_done - .
    bl OVER; bl FETCHBYTE; bl ISDIGIT
    bl ZEQU; bl QBRANCH; .word tonumber_cont - .
    bl DROP; bl BRANCH; .word tonumber_done - .
tonumber_cont:
    bl TOR; bl ROT; bl BASE; bl FETCH; bl MUL
    bl RFROM; bl ADD; bl ROT; bl ROT
    bl LIT; .word 1; bl TRIMSTRING
    bl BRANCH; .word tonumber_loop - .
tonumber_done:
    bl RFROM; bl BASE; bl STORE
    exit

    defword "?NUMBER", ISNUMBER /* ( c-addr -- n true | c-addr false ) */
    bl DUP; bl LIT; .word 0; bl DUP; bl ROT; bl COUNT;
    bl ISSIGN; bl TOR; bl TONUMBER; bl QBRANCH; .word is_number - .
    bl RDROP; bl TWODROP; bl DROP; bl LIT; .word 0
    exit
is_number:
    bl TWOSWAP; bl TWODROP; bl DROP; bl RFROM; bl ZNEQU; bl QBRANCH; .word is_positive - .; bl NEGATE
is_positive:
    bl LIT; .word -1
    exit

    .ltorg

    defword "DECIMAL", DECIMAL
    bl LIT; .word 10; bl BASE; bl STORE
    exit

    defword "HEX", HEX
    bl LIT; .word 16; bl BASE; bl STORE
    exit

    defword "OCTAL", OCTAL
    bl LIT; .word 8; bl BASE; bl STORE
    exit

    defword "BINARY", BINARY
    bl LIT; .word 2; bl BASE; bl STORE
    exit

@ ---------------------------------------------------------------------
@ -- Control flow -----------------------------------------------------

    defcode "EXIT", EXIT
    exit

    defcode "NOOP", NOOP
    mov pc, lr

    defcode "BRANCH", BRANCH
    @ .ifndef THUMB1
    @ subs lr, lr, #1
    @ ldr r0, [lr]
    @ adds lr, r0
    @ adds lr, lr, #1
    @ mov pc, lr
    @ .else
    mov r0, lr
    subs r0, r0, #1
    ldr r1, [r0]
    adds r0, r1
    adds r0, r0, #1
    mov pc, r0
    @ .endif

    defcode "?BRANCH", QBRANCH
    ppop r0
    cmp r0, #0
    beq BRANCH
    @ .ifndef THUMB1
    @ adds lr, lr, #4
    @ mov pc, lr
    @ .else
    mov r0, lr
    adds r0, r0, #4
    mov pc, r0
    @ .endif

    defcode "(FARCALL)", XFARCALL
    mov r0, lr
    subs r0, #1
    ldr r1, [r0]
    adds r0, #5
    mov lr, r0
    mov pc, r1

    defcode "COPY-FARCALL", COPY_FARCALL
    ldr r0, =addr_FARCALL
    ldr r1, =XFARCALL
    movs r2, #4
1:  ldr r3, [r1]
    str r3, [r0]
    adds r0, #4
    adds r1, #4
    subs r2, #1
    bne 1b
    mov pc, lr
    .ltorg

    target_conditional ENABLE_COMPILER

    defword "POSTPONE", POSTPONE, F_IMMED
    bl BL; bl WORD; bl FIND
    bl ZLT; bl QBRANCH; .word 1f - .
    bl LIT_XT; .word LIT_XT; bl COMMAXT; bl COMMA
    bl LIT_XT; .word COMMAXT; bl COMMAXT; bl BRANCH; .word 2f - .
1:  bl COMMAXT
    exit

    defword "LITERAL", LITERAL, F_IMMED
    bl LIT_XT; .word LIT; bl COMMAXT; bl COMMA
    exit

    defword "BEGIN", BEGIN, F_IMMED
    bl HERE
    exit

    defword "AGAIN", AGAIN, F_IMMED
    bl LIT_XT; .word BRANCH; bl COMMAXT; bl HERE; bl SUB; bl COMMA
    exit

    defword "UNTIL", UNTIL, F_IMMED
    bl LIT_XT; .word QBRANCH; bl COMMAXT; bl HERE; bl SUB; bl COMMA
    exit

    defword "IF", IF, F_IMMED
    bl LIT_XT; .word QBRANCH; bl COMMAXT; bl HERE; bl DUP; bl COMMA
    exit

    defword "ELSE", ELSE, F_IMMED
    bl LIT_XT; .word BRANCH; bl COMMAXT; bl HERE; bl DUP; bl COMMA
    bl SWAP; bl THEN
    exit

    defword "THEN", THEN, F_IMMED
    bl HERE; bl OVER; bl SUB; bl SWAP; bl STORE
    exit

    defword "WHILE", WHILE, F_IMMED
    bl IF
    exit

    defword "REPEAT", REPEAT, F_IMMED
    bl SWAP; bl LIT_XT; .word BRANCH; bl COMMAXT; bl HERE; bl SUB; bl COMMA
    bl THEN
    exit

    defword "CASE", CASE, F_IMMED
    bl LIT; .word 0
    exit

    defword "OF", OF, F_IMMED
    bl LIT_XT; .word OVER; bl COMMAXT; bl LIT_XT; .word EQU; bl COMMAXT; bl IF; bl LIT_XT; .word DROP; bl COMMAXT
    exit

    defword "ENDCASE", ENDCASE, F_IMMED
    bl LIT_XT; .word DROP; bl COMMAXT
1:  bl DUP; bl QBRANCH; .word 2f - .
    bl THEN; bl BRANCH; .word 1b - .
2:  bl DROP
    exit

    end_target_conditional

    defcode "(DO)", XDO
    ppop r0
    ppop r1
    pop {r2}
    push {r1}
    push {r0}
    push {r2}
    mov pc, lr

    defcode "I", INDEX
    .ifndef THUMB1
    ldr r0, [RSP, #4]
    .else
    mov r0, RSP
    adds r0, #4
    ldr r0, [r0]
    .endif
    ppush r0
    mov pc, lr

    defcode "(LOOP)", XLOOP
    .ifndef THUMB1
    ldr r2, [RSP, #4]
    adds r2, r2, #1
    ldr r1, [RSP, #8]
    cmp r2, r1
    bge 1f
    str r2, [RSP, #4]
    .else
    mov r0, RSP
    subs r0, #4
    ldr r0, [r0]
    adds r0, r0, #1
    mov r1, RSP
    adds r1, #8
    ldr r1, [r1]
    cmp r0, r1
    bge 1f
    mov r0, RSP
    adds r0, #4
    str r0, [r0]
    .endif
    movs r0, #0
    ppush r0
    mov pc, lr
1:  pop {r0, r1, r2}
    push {r0}
    movs r0, #0
    mvns r0, r0
    ppush r0
    mov pc, lr

    defcode "UNLOOP", UNLOOP
    pop {r0, r1, r2}
    push {r0}
    mov pc, lr

    target_conditional ENABLE_COMPILER

    defword "DO", DO, F_IMMED
    bl LIT_XT; .word XDO; bl COMMAXT; bl HERE
    exit

    defword "LOOP", LOOP, F_IMMED
    bl LIT_XT; .word XLOOP; bl COMMAXT; bl LIT_XT; .word QBRANCH; bl COMMAXT; bl HERE; bl SUB; bl COMMA
    exit

    defcode "DELAY", DELAY
    ppop r0
    bl delay
    mov pc, lr

    defword "RECURSE", RECURSE, F_IMMED
    bl LATEST; bl FETCH; bl FROMLINK; bl COMMAXT
    exit

    end_target_conditional

@ ---------------------------------------------------------------------
@ -- Compiler and interpreter ----------------------------------------

    defcode "EMULATION?", EMULATIONQ
    ldr r0, =0xe000ed00
    ldr r0, [r0]
    movs r1, #0
    cmp r0, r1
    bne 1f
    subs r1, #1
1:  ppush r1
    mov pc, lr

    defcode "EMULATOR-BKPT", EMULATOR_BKPT
    ppop r0
    push {r0}
    bkpt 0xab
    mov pc, lr

    target_conditional ENABLE_COMPILER

    defword "ROM-DUMP", ROM_DUMP
    ldr r0, =_start; push {r0}
    bl ROM_DP; bl FETCH; ppop r0; push {r0}
    movs r0, #0x80; push {r0}; bkpt 0xab
    exit

    end_target_conditional

    defword "BYE", BYE
    bl EMULATIONQ
    bl QBRANCH; .word 1f - .
    movs r0, #0x18; push {r0}; bkpt 0xab
1:  b .
    exit

    defcode "WFI", WFI
    wfi
    mov pc, lr

    defcode "WFE", WFE
    wfe
    mov pc, lr

    defcode "RESET", RESET
    ldr r0, =0xe000ed0c
    ldr r1, =0x05fa0004
    str r1, [r0]

    defcode "HALT", HALT
    b .

    .ltorg

    defcode "LIT", LIT
    mov r0, lr
    subs r0, r0, #1
    ldr r1, [r0]
    ppush r1
    adds r0, #5
    mov pc, r0

    defcode "LIT_XT", LIT_XT
    mov r0, lr
    subs r0, r0, #1
    ldr r1, [r0]
    adds r1, r1, #1
    ppush r1
    adds r0, #5
    mov pc, r0

    defword "ROM", ROM
    bl LIT; .word 1; bl ROM_ACTIVE; bl STORE
    exit

    defword "RAM", RAM
    bl LIT; .word 0; bl ROM_ACTIVE; bl STORE
    exit

    defword "ROM?", ROMQ
    bl ROM_ACTIVE; bl FETCH
    exit

    defword "DP", DP
    bl ROMQ; bl QBRANCH; .word 1f - .
    bl ROM_DP
    exit
1:  bl RAM_DP
    exit

    defword "HERE", HERE
    bl DP; bl FETCH
    exit

    defword "ORG", ORG
    bl DP; bl STORE
    exit

    defword "ALLOT", ALLOT
    bl DP; bl ADDSTORE
    exit

    defword "ALIGN", ALIGN
    bl HERE; bl ALIGNED; bl ORG
    exit

    defword ",", COMMA
    bl HERE; bl STORE; bl CELL; bl ALLOT
    exit

    defword ",H", COMMAH
    bl HERE; bl HSTORE; bl LIT; .word 2; bl ALLOT
    exit

    defword ",XT-FAR", COMMAXT_FAR
    bl LIT_XT; .word addr_FARCALL; bl COMMAXT; bl COMMA;
    exit

    defword ",XT", COMMAXT
    bl DUP;
    bl HERE; bl CELL; bl ADD; bl SUB;
    ppop r0
    ldr r1, =0x00400000
    cmp r1, r0
    ble 1f
    ldr r1, =0xffc00000
    cmp r1, r0
    ble 1f
    bl COMMAXT_FAR
    exit

1:  bl DROP
    asrs r0, r0, #1;
    ldr r1, =0xf800f400

    movs r2, r0
    asrs r2, #11
    ldr r3, =0x000003ff
    ands r2, r3
    orrs r1, r2

    movs r2, r0
    lsls r2, #16
    ldr r3, =0x7fff0000
    ands r2, r3
    orrs r1, r2

    movs r0, r1
    ppush r0
    bl COMMA
    exit
    .align 2,0
    .ltorg

    defword ",LINK", COMMALINK
    bl COMMA
    exit

    defword "C,", CCOMMA
    bl HERE; bl STOREBYTE; bl LIT; .word 1; bl ALLOT
    exit

    defword ">UPPER", GTUPPER
    bl OVER; bl PLUS; bl SWAP
1:  bl LPARENDORPAREN; bl I; bl CFETCH; bl UPPERCASE; bl I; bl CSTORE; bl LPARENLOOPRPAREN; bl QBRANCH; .word 1b - .
    exit

    defword "UPPERCASE", UPPERCASE
    bl DUP; bl LIT; .word 0x61; bl LIT; .word 0x7b; bl WITHIN; bl LIT; .word 0x20; bl AND; bl XOR
    exit

    defword "SI=", SIEQU
    bl GTR
1:  bl RFETCH; bl DUP; bl QBRANCH; .word 2f - .; bl DROP; bl TWODUP; bl CFETCH; bl UPPERCASE
    bl SWAP; bl CFETCH; bl UPPERCASE; bl EQU
2:  bl QBRANCH; .word 3f - .
    bl ONEPLUS; bl SWAP; bl ONEPLUS; bl RGT; bl ONEMINUS; bl GTR; bl BRANCH; .word 1b - .
3:  bl TWODROP; bl RGT; bl ZEQU
    exit

    defword "LINK>", FROMLINK
    bl LINKTONAME; bl DUP; bl FETCHBYTE; bl LIT; .word F_LENMASK; bl AND; bl CHAR; bl ADD; bl ADD; bl ALIGNED
    exit

    defcode ">FLAGS", TOFLAGS
    ppop r0
1:  subs r0, #1
    ldrb r1, [r0]
    cmp r1, #F_MARKER
    blt 1b
    ppush r0
    mov pc, lr

    defword ">NAME", TONAME
    bl TOFLAGS; bl CHAR; bl ADD
    exit

    .ltorg

    defword ">LINK", TOLINK
    bl TONAME; bl LIT; .word 5; bl SUB
    exit

    defword ">BODY", GTBODY
    bl CELL; bl ADD
    exit

    defword "LINK>NAME", LINKTONAME
    bl LIT; .word 5; bl ADD
    exit

    defword "LINK>FLAGS", LINKTOFLAGS
    bl CELL; bl ADD
    exit

    defword "ANY>LINK", ANYTOLINK
    bl LATEST
1:  bl FETCH; bl TWODUP; bl GT; bl QBRANCH; .word 1b - .
    bl NIP
    exit

    defcode "EXECUTE", EXECUTE
    ppop r0
    @.ifndef THUMB1
    @orr r0, r0, #1
    @.else
    movs r1, #1
    orrs r0, r1
    @.endif
    mov pc, r0

    target_conditional ENABLE_COMPILER

    defword "MARKER", MARKER, 0X0
    /*
    bl CREATE; bl LATEST; bl FETCH; bl FETCH; bl COMMA; bl LPARENDOESGTRPAREN
    .set marker_XT, .
    bl 0x47884900; bl DODOES + 1; bl FETCH; bl LATEST; bl STORE
    */
    exit

    defword "\'", TICK
    bl BL; bl WORD; bl FIND; bl DROP
    exit

    defword "[\']", BRACKETTICK, F_IMMED
    bl TICK; bl LIT_XT; .word LIT; bl COMMAXT; bl COMMA
    exit

    defword "(DOES>)", XDOES
    bl HERE
    pop {r0}; subs r0, #1; ppush r0
    bl LIT; .word -12; bl ALLOT;
    bl LIT; .word 0xb500; bl COMMAH
    bl COMMAXT;
    bl ORG
    exit

    defword "DODOES", DODOES
    exit

    defword "DOES>", DOES, F_IMMED
    bl LIT_XT; .word XDOES; bl COMMAXT
    exit


    defword "<BUILDS", BUILDS
    bl ALIGN
    bl LATEST; bl FETCH
    bl HERE; bl LATEST; bl STORE
    bl COMMALINK
    bl LIT; .word F_MARKER; bl CCOMMA
    bl BL; bl WORD; bl FETCHBYTE; bl INCR; bl INCR; bl ALIGNED; bl DECR; bl ALLOT
    exit

    defword "(CONSTANT)", XCONSTANT
    bl BUILDS;
    ldr r4, =DOCON;
    ldr r0, [r4]; ppush r0; bl COMMA;
    ldr r0, [r4, #4]; ppush r0; bl COMMA;
    exit
    .ltorg
    .align 2, 0
DOCON:
    ldr	r0, [pc, #4]
    ppush r0
    mov pc, lr

    defword "CONSTANT", CONSTANT
    bl XCONSTANT; bl COMMA;
    exit

    defword "CREATE", CREATE
    bl BUILDS;
    ldr r4, =DODATA;
    ldr r0, [r4]; ppush r0; bl COMMA;
    ldr r0, [r4, #4]; ppush r0; bl COMMA;
    ldr r0, [r4, #8]; ppush r0; bl COMMA;
    bl LIT; .word 4; bl COMMA
    exit
    .ltorg
    .align 2, 0
DODATA:
    mov r0, pc
    adds r0, #12
    ppush r0
    mov pc, lr
    exit

    .set DATA, CREATE

    defword "BUFFER", BUFFER
    bl XCONSTANT
    bl ROM_ACTIVE; bl FETCH
    bl HERE; bl CELL; bl ALLOT
    bl RAM; bl HERE; bl SWAP; bl STORE
    bl SWAP; bl ALLOT
    bl ROM_ACTIVE; bl STORE
    exit

    defword "VARIABLE", VARIABLE
    bl CELL; bl BUFFER
    exit

    defword "DEFER", DEFER
    /*
    bl CREATE; bl LIT_XT
    exit
    .set DEFER_XT, .
    ldr r1, [pc]
    blx r1
    bl DODOES + 1; bl FETCH; bl EXECUTE;
    */
    exit

    defword "IS", IS
    bl TICK; bl GTBODY; bl STORE
    exit

    defword "DECLARE", DECLARE
    bl CREATE; bl LATEST; bl FETCH; bl LINKTOFLAGS; bl DUP; bl FETCH; bl LIT; .word F_NODISASM; bl OR; bl SWAP; bl STORE
    exit

    defword "(FIND)", XFIND
2:  bl TWODUP; bl LINKGTNAME; bl OVER; bl CFETCH; bl ONEPLUS; bl SIEQU; bl ZEQU; bl DUP; bl QBRANCH; .word 1f - .
    bl DROP; bl FETCH; bl DUP
1:  bl ZEQU; bl QBRANCH; .word 2b - .
    bl DUP; bl QBRANCH; .word 3f - .
    bl NIP; bl DUP; bl LINKGT; bl SWAP; bl LINKGTFLAGS; bl CFETCH; bl LIT; .word 0x1; bl AND; bl ZEQU; bl LIT; .word 0x1; bl OR
3:  exit

    defword "FIND", FIND
    bl LATEST; bl FETCH; bl XFIND; bl QDUP; bl QBRANCH; .word 1f - .
    exit
1:  bl LIT; .word last_host; bl QDUP; bl QBRANCH; .word 2f - .; bl XFIND
    exit
2:  bl LIT; .word 0
    exit

    defword "\\", BACKSLASH, F_IMMED
    bl SOURCECOUNT; bl FETCH; bl SOURCEINDEX; bl STORE
    exit

    defword "(", LPAREN, F_IMMED
    bl LIT; .word ')'; bl WORD; bl DROP
    exit

    defword "WORD", WORD
    bl DUP; bl SOURCE; bl SOURCEINDEX; bl FETCH; bl TRIMSTRING
    bl DUP; bl TOR; bl ROT; bl SKIP
    bl OVER; bl TOR; bl ROT; bl SCAN
    bl DUP; bl ZNEQU; bl QBRANCH; .word noskip_delim - .; bl DECR
noskip_delim:
    bl RFROM; bl RFROM; bl ROT; bl SUB; bl SOURCEINDEX; bl ADDSTORE
    bl TUCK; bl SUB
    bl DUP; bl HERE; bl STOREBYTE
    bl HERE; bl INCR; bl SWAP; bl CMOVE
    bl HERE
    exit

    defword "(INTERPRET)", XINTERPRET
interpret_loop:
    bl BL; bl WORD; bl DUP; bl FETCHBYTE; bl QBRANCH; .word interpret_eol - .
    bl FIND; bl QDUP; bl QBRANCH; .word interpret_check_number - .
    bl STATE; bl FETCH; bl QBRANCH; .word interpret_execute - .
    bl INCR; bl QBRANCH; .word interpret_compile_word - .
    bl EXECUTE; bl BRANCH; .word interpret_loop - .
interpret_compile_word:
    bl COMMAXT; bl BRANCH; .word interpret_loop - .
interpret_execute:
    bl DROP; bl EXECUTE; bl BRANCH; .word interpret_loop - .
interpret_check_number:
    bl ISNUMBER; bl QBRANCH; .word interpret_not_found - .
    bl STATE; bl FETCH; bl QBRANCH; .word interpret_loop - .
    bl LIT_XT; .word LIT; bl COMMAXT; bl COMMA; bl BRANCH; .word interpret_loop - .
interpret_not_found:
    bl LIT; .word 0
    exit
interpret_eol:
    bl LIT; .word -1
    exit

    defword "EVALUATE", EVALUATE
    bl XSOURCE; bl STORE
    bl LIT; .word 0; bl STATE; bl STORE
1:  bl XSOURCE; bl FETCH;
5:  bl DUP; bl FETCHBYTE; bl DUP; bl ZNEQU; bl QBRANCH; .word 2f - .; bl LIT; .word 10; bl EQU; bl QBRANCH; .word 7f - .
    bl INCR; bl BRANCH; .word 5b - .
7:  bl DUP
6:  bl DUP; bl FETCHBYTE; bl LIT; .word 10; bl NEQU; bl QBRANCH; .word 4f - .
    bl INCR; bl BRANCH; .word 6b - .
4:  bl OVER; bl SUB
    bl TWODUP; bl TYPE; bl CR
    bl SOURCECOUNT; bl STORE; bl XSOURCE; bl STORE; bl LIT; .word 0; bl SOURCEINDEX; bl STORE
    bl XINTERPRET; bl QBRANCH; .word 3f - .; bl DROP
    bl SOURCECOUNT; bl FETCH; bl XSOURCE; bl ADDSTORE; bl BRANCH; .word 1b - .
2:  bl DROP
    exit
3:  bl DROP; bl DUP; bl DOT; bl SPACE; bl COUNT; bl TYPE; bl LIT; .word '?'; bl EMIT; bl CR
    exit

    defword "FORGET", FORGET
    bl BL; bl WORD; bl FIND; bl DROP; bl TOLINK; bl FETCH; bl LATEST; bl STORE
    exit

    defword "HIDE", HIDE
    bl LATEST; bl FETCH; bl LINKTONAME; bl DUP; bl FETCHBYTE; bl LIT; .word F_HIDDEN; bl OR; bl SWAP; bl STOREBYTE
    exit

    defword "REVEAL", REVEAL
    bl LATEST; bl FETCH; bl LINKTONAME; bl DUP; bl FETCHBYTE; bl LIT; .word F_HIDDEN; bl INVERT; bl AND; bl SWAP; bl STOREBYTE
    exit

    defword "IMMEDIATE", IMMEDIATE
    bl LATEST; bl FETCH; bl LINKTOFLAGS; bl DUP; bl FETCHBYTE; bl LIT; .word F_IMMED; bl OR; bl SWAP; bl STOREBYTE
    exit

    defword "[", LBRACKET, F_IMMED
    bl LIT; .word 0; bl STATE; bl STORE
    exit

    defword "]", RBRACKET
    bl LIT; .word -1; bl STATE; bl STORE
    exit

    defword ":", COLON
    bl BUILDS;
    movs r0, #0xb500; ppush r0; bl COMMAH;
    bl HIDE; bl RBRACKET;
    exit

    defword ";", SEMICOLON, F_IMMED
    movs r0, #0xbd00; ppush r0; bl COMMAH;
    bl REVEAL; bl LBRACKET
    exit

    end_target_conditional

    defword "WORDS", WORDS
    bl LATEST; bl FETCH
1:
    bl DUP; bl CELL; bl ADD; bl CHAR; bl ADD; bl COUNT; bl TYPE; bl SPACE
    bl FETCH; bl QDUP; bl ZEQU; bl QBRANCH; .word 1b - .
    exit

    defword "DEFINED?", DEFINEDQ
    bl BL; bl WORD; bl FIND; bl NIP
    exit

@ ---------------------------------------------------------------------
@ -- User variables  --------------------------------------------------

    defword "USER", USER
    bl CREATE; bl COMMA; bl XDOES
    .set USER_XT, .
    ldr r1, [pc]
    blx r1
    @ bl DODOES + 1; bl FETCH; bl UPFETCH; bl ADD;
    exit

    defword "UP@", UPFETCH
    bl UP; bl FETCH
    exit

    defword "UP!", UPSTORE
    bl UP; bl STORE
    exit

    defword "R0", RZ
    bl 0x04

    defword "S0", SZ
    bl 0x08

    defcode "DEPTH", DEPTH
    ldr r1, =addr_TASKZTOS
    mov r2, r6
    subs r2, r1
    subs r2, #4
    lsrs r2, #2
    ppush r2
    mov pc, lr

@ ---------------------------------------------------------------------
@ -- System variables -------------------------------------------------

    defvar "STATE", STATE
    defvar "RAM-DP", RAM_DP
    defvar "ROM-DP", ROM_DP
    defvar "ROM-ACTIVE", ROM_ACTIVE
    defvar "LATEST", LATEST
    defvar "BASE", BASE
    defvar "TIB", TIB, 132
    defvar ">TIB", TIBINDEX
    defvar "TIB#", TIBCOUNT
    defvar "(SOURCE)", XSOURCE
    defvar "SOURCE#", SOURCECOUNT
    defvar ">SOURCE", SOURCEINDEX
    defvar "UP", UP
    defvar "HP", HP
    defvar "\047KEY", TICKKEY
    defvar "\047ACCEPT", TICKACCEPT
    defvar "\047EMIT", TICKEMIT
    defvar "\047TYPE", TICKTYPE
    defvar "\047WAIT-KEY", TICKWAIT_KEY
    defvar "\047FINISH-OUTPUT", TICKFINISH_OUTPUT
    defvar "FARCALL", FARCALL, 16

@ ---------------------------------------------------------------------
@ -- Main task user variables -----------------------------------------

    defvar "TASK0WAKE-AT", TASKZWAKE_AT
    defvar "TASK0UTOS", TASKZUTOS
    defvar "TASK0STATUS", TASKZSTATUS
    defvar "TASK0", TASKZ, 0
    defvar "TASK0FOLLOWER", TASKZFOLLOWER
    defvar "TASK0RZ", TASKZRZ
    defvar "TASK0SZ", TASKZSZ
    defvar "TASK0TOS", TASKZTOS, 0
    defvar "TASK0STACK", TASKZSTACK, 512
    defvar "TASK0RTACK", TASKZRSTACK, 512
    defvar "TASK0RTOS", TASKZRTOS, 0

    .ltorg

@ ---------------------------------------------------------------------
@ -- Symbol aliases ---------------------------------------------------

    .set PLUS, ADD
    .set MINUS, SUB
    .set LPARENSOURCERPAREN, XSOURCE
    .set SOURCENUM, SOURCECOUNT
    .set GTSOURCE, SOURCEINDEX
    .set GTR, TOR
    .set RGT, RFROM
    .set LPARENSQUOTRPAREN, XSQUOTE
    .set GTTIB, TIBINDEX
    .set CMOVEGT, CMOVEUP
    .set CSTORE, STOREBYTE
    .set CFETCH, FETCHBYTE
    .set PLUSSTORE, ADDSTORE
    .set MINUSSTORE, SUBSTORE
    .set ONEPLUS, INCR
    .set ONEMINUS, DECR
    .set FOURPLUS, INCR4
    .set FOURMINUS, DECR4
    .set MINUSROT, ROTROT
    .set NUMTIB, TIBSIZE
    .set TIBNUM, TIBCOUNT
    .set LPARENINTERPRETRPAREN, XINTERPRET
    .set LPARENDORPAREN, XDO
    .set LPARENLOOPRPAREN, XLOOP
    .set LPARENDOESGTRPAREN, XDOES
    .set I, INDEX
    .set TWOSLASH, TWODIV
    .set LTGT, NEQU
    .set SLASHMOD, DIVMOD
    .set DOTS, PRINTSTACK
    .set LBRAC, LBRACKET
    .set RBRAC, RBRACKET
    .set LINKGT, FROMLINK
    .set ANYGTLINK, ANYTOLINK
    .set LINKGTNAME, LINKTONAME
    .set LINKGTFLAGS, LINKTOFLAGS
    .set SEMI, SEMICOLON
    .set SLASH, DIV
    .set LTEQU, LE
    .set ZLTGT, ZNEQU
    .set QNUMBER, ISNUMBER

@ ---------------------------------------------------------------------

    .set last_core_word, link
    .set end_of_core, .

