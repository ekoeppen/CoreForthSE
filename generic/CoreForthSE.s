@ -- vim:syntax=armasm:foldmethod=marker:foldmarker=@\ --\ ,@\ ---:

    .global reset_handler
    .global main

@ ---------------------------------------------------------------------
@ -- Variable definitions ---------------------------------------------

    .set F_IMMED,           0xFE
    .set F_INLINE,          0xFD
    .set F_BUFFER,          0xFB
    .set F_HIDDEN,          0xF7
    .set F_MARKER,          0xFF

    .set link,                 0
    .set link_host,            0
    .set ram_here, ram_start

    .set ENABLE_COMPILER,      1
    .set WORDBUF_SIZE,        32

TOS .req r0
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
    subs PSP, #4
    str r0, [PSP]
    movs r0, \reg
    .endm

    .macro ppop reg
    movs \reg, r0
    ldr r0, [PSP]
    adds PSP, #4
    .endm

    .macro zpfetch reg
    movs \reg, r0
    .endm

    .macro pdrop
    ldr r0, [PSP]
    adds PSP, #4
    .endm

    .macro pdup
    subs PSP, #4
    str r0, [PSP]
    .endm

    .macro pswap
    ldr r1, [PSP]
    str r0, [PSP]
    movs r0, r1
    .endm

    .macro pnip
    adds PSP, #4
    .endm

    .macro padd
    ldr r1, [PSP]
    adds PSP, #4
    adds r0, r1
    .endm

    .macro psub
    ldr r1, [PSP]
    adds PSP, #4
    subs r0, r1, r0
    .endm

    .macro pmul
    ldr r1, [PSP]
    adds PSP, #4
    muls r0, r1
    .endm

    .macro pincr
    adds r0, #1
    .endm

    .macro pdecr
    subs r0, #1
    .endm

    .macro pincr4
    adds r0, #4
    .endm

    .macro pdecr4
    subs r0, #4
    .endm

    .macro pcelladd
    adds r0, #4
    .endm

    .macro pcellsub
    subs r0, #4
    .endm

    .macro pcharadd
    adds r0, #1
    .endm

    .macro pcharsub
    subs r0, #1
    .endm

    .macro ptwomul
    .ifndef THUMB1
    lsls r0, r0, #1
    .else
    adds r0, r0
    .endif
    .endm

    .macro ptwodiv
    asrs r0, r0, #1
    .endm

    .macro pinvert
    mvns r0, r0
    .endm

    .macro pand
    ldr r1, [PSP]
    adds PSP, #4
    ands r0, r1
    .endm

    .macro por
    ldr r1, [PSP]
    adds PSP, #4
    orrs r0, r1
    .endm

    .macro pxor
    ldr r1, [PSP]
    adds PSP, #4
    eors r0, r1
    .endm

    .macro pfetch
    ldr r0, [r0]
    .endm

    .macro pfetchbyte
    ldrb r0, [r0]
    .endm

    .macro phfetch
    ldrh r0, [r0]
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

    .macro defword name, label, flags=0xFF
    .align 2, 0
    checkdef \label
    .global name_\label
    .set name_\label , .
    .int link
    .set link, name_\label
    .byte \flags
    .byte F_MARKER
    .byte (99f - 98f)
98:
    .ascii "\name"
99:
    .align  2, 0
    .global \label
    .type \label, %function
    .set \label , .
    enter
    @ code field follows
    .endm

    .macro defcode name, label, flags=0xFF
    .align 2, 0
    .global name_\label
    checkdef \label
    .set name_\label , .
    .int link
    .set link, name_\label
    .byte \flags
    .byte F_MARKER
    .byte (99f - 98f)
98:
    .ascii "\name"
99:
    .align 2, 0
    .global \label
    .type \label, %function
    checkdef \label
    .set \label , .
    @ code field follows
    .endm

    .macro defconst name, label, value, flags=0xFF
    .align 2, 0
    .global name_\label
    checkdef \label
    .type \label, %function
    .set name_\label , .
    .int link
    .set link, name_\label
    .byte \flags
    .byte F_MARKER
    .byte (99f - 98f)
98:
    .ascii "\name"
99:
    .align 2, 0
    .global \label
    .set \label , .
    ldr r1, [pc, #8]
    ppush r1
    mov pc, lr
    .align 2, 0
    .set constaddr_\label , .
    .word \value
    .endm

    .macro defvar name, label, size=4
    defconst \name,\label,ram_here, F_BUFFER
    .short \size
    .set addr_\label, ram_here
    .global addr_\label
    .type \label, %function
    .set ram_here, ram_here + \size
    .endm

    .macro defdata name, label
    defword \name,\label
    .endm

    .macro lit8, value
    .if \value >= 0
    subs PSP, #4
    str r0, [PSP]
    movs r0, \value
    .else
    .if \value < 0
    .if \value > -255
    movs r2, -\value
    movs r1, #0
    subs r1, r2
    ppush r1
    .endif
    .endif
    .endif
    .endm

    .macro lit32, value
    ldr r1, =\value
    ppush r1
    .endm

@ ---------------------------------------------------------------------
@ -- Helper code ------------------------------------------------------

    @ Busy delay with three ticks per count
    .type delay, %function
delay:
    subs r0, #1
    bne delay
    mov pc, lr

haskey_emulator:
    ldr r1, =EMULATOR_UART + 4
    ldr r1, [r1]
    ppush r1
    bx lr

waitkey_emulator:
    movs r1, #0x82; push {r1}; bkpt 0xab
    bx lr

readkey_emulator:
    movs r1, #0x82; push {r1}; bkpt 0xab
    ldr r1, =EMULATOR_UART
    ldr r1, [r1]
    ppush r1
    bx lr

putchar_emulator:
    ldr r1, =EMULATOR_UART
    ppop r2
    str r2, [r1]
    bx lr

    .ltorg

@ ---------------------------------------------------------------------
@ -- Stack manipulation -----------------------------------------------

    defcode "DROP", DROP, F_INLINE
    pdrop
    mov pc, lr

    defcode "SWAP", SWAP, F_INLINE
    pswap
    mov pc, lr

    defcode "OVER", OVER, F_INLINE
    subs PSP, #4
    str r0, [PSP]
    ldr r0, [PSP, #4]
    mov pc, lr

    defcode "ROT", ROT
    ldr r3, [PSP, #4]
    ldr r2, [PSP]
    movs r1, r0
    str r2, [PSP, #4]
    str r1, [PSP]
    movs r0, r3
    mov pc, lr

    defcode "?DUP", QDUP
    cmp r0, #0
    beq 1f
    pdup
1:  mov pc, lr

    defcode "DUP", DUP, F_INLINE
    pdup
    mov pc, lr

    defcode "NIP", NIP, F_INLINE
    pnip
    mov pc, lr

    defcode "TUCK", TUCK
    ldr r1, [PSP]
    str r0, [PSP]
    subs PSP, #4
    str r1, [PSP]
    mov pc, lr

    defcode "2DUP", TWODUP
    ldr r1, [PSP]
    subs PSP, #8
    str r0, [PSP, #4]
    str r1, [PSP]
    mov pc, lr

    defcode "2SWAP", TWOSWAP
    ldr r3, [PSP, #8]
    ldr r2, [PSP, #4]
    ldr r1, [PSP]
    str r1, [PSP, #8]
    str r0, [PSP, #4]
    str r3, [PSP]
    movs r0, r2
    mov pc, lr

    defcode "2DROP", TWODROP
    pdrop
    pdrop
    mov pc, lr

    defcode "2OVER", TWOOVER
    ppop r1
    ppop r2
    ppop r3
    ppop r4
    ppush r4
    ppush r3
    ppush r2
    ppush r1
    ppush r4
    ppush r3
    mov pc, lr

    defcode "PICK", PICK
    mov r1, PSP
    lsls r0, #2
    adds r1, r0
    ldr r0, [r1]
1:  mov pc, lr

    defcode ">R", TOR, F_INLINE
    ppop r1
    push {r1}
    mov pc, lr

    defcode "R>", RFROM, F_INLINE
    pop {r1}
    ppush r1
    mov pc, lr

    defcode "R@", RFETCH, F_INLINE
    ldr r1, [RSP]
    ppush r1
    mov pc, lr

    defcode "RDROP", RDROP, F_INLINE
    pop {r4}
    mov pc, lr

    defcode "SP@", SPFETCH
    mov r1, PSP
    ppush r1
    mov pc, lr

    defcode "RP@", RPFETCH
    mov r1, RSP
    ppush r1
    mov pc, lr

    defcode "SP!", SPSTORE
    mov PSP, r0
    mov r1, PSP
    subs r1, #4
    ldr r0, [r1]
    mov pc, lr

    defcode "RP!", RPSTORE
    ppop r1
    mov RSP, r1
    mov pc, lr

    defword "-ROT", ROTROT
    bl ROT; bl ROT
    exit

@ ---------------------------------------------------------------------
@ -- Memory operations -----------------------------------------------

    defconst "CELL", CELL, 4

    defcode "CELLS", CELLS, F_INLINE
    movs r1, #4
    muls r0, r1
    mov pc, lr

    defcode "CHARS", CHARS, F_INLINE
    mov pc, lr

    defcode "ALIGNED", ALIGNED, F_INLINE
    adds r0, r0, #3
    movs r1, #3
    mvns r1, r1
    ands r0, r0, r1
    mov pc, lr

    defcode "C@", FETCHBYTE, F_INLINE
    pfetchbyte
    mov pc, lr

    defcode "C!", STOREBYTE
    ldr r1, [PSP]
    strb r1, [r0]
    ldr r0, [PSP, #4]
    adds PSP, #8
    mov pc, lr

    defcode "IC!", ICSTORE
    ldr r1, [PSP]
    strb r1, [r0] @ :FIXME:
    b .
    ldr r0, [PSP, #4]
    adds PSP, #8
    mov pc, lr

    defcode "H@", HFETCH, F_INLINE
    phfetch
    mov pc, lr

    defcode "H!", HSTORE
    ldr r1, [PSP]
    strh r1, [r0]
    ldr r0, [PSP, #4]
    adds PSP, #8
    mov pc, lr

    defcode "IH!", IHSTORE
    ldr r1, [PSP]
    strh r1, [r0]
    ldr r0, [PSP, #4]
    adds PSP, #8
    mov pc, lr

    defcode "~@", MISALIGNEDFETCH
    .ifndef THUMB1
    ldr r0, [r0]
    .else
    ldrh r1, [r0]
    adds r0, #2
    ldrh r0, [r0]
    lsls r0, #16
    orrs r0, r1
    .endif
    mov pc, lr

    defcode "@", FETCH, F_INLINE
    .ifdef THUMB1
    movs r2, #3
    ands r2, r0
    beq 1f
    b .
    .endif
1:  pfetch
    mov pc, lr

    defcode "!", STORE
    ppop r2
    ppop r1
    .ifndef THUMB1
    str r1, [r2]
    mov pc, lr
    .else
    movs r3, #3
    ands r3, r2
    bne 1f
    str r1, [r2]
    mov pc, lr
1:  strh r1, [r2]
    adds r2, #2
    lsrs r1, #16
    strh r1, [r2]
    mov pc, lr
    .endif

    defcode "I!", ISTORE
    ppop r2
    ppop r1
    strh r1, [r2]
    adds r2, #2
    lsrs r1, #16
    strh r1, [r2]
    mov pc, lr

    defword "2!", TWOSTORE
    pswap; bl OVER; bl STORE; bl CELLADD; bl STORE
    exit

    defword "2@", TWOFETCH
    pdup; bl CELLADD; pfetch; pswap; pfetch
    exit

    defcode "+!", ADDSTORE
    ppop r2
    ppop r1
    ldr r3, [r2]
    adds r3, r1
    str r3, [r2]
    mov pc, lr

    defcode "-!", SUBSTORE
    ppop r2
    ppop r1
    ldr r3, [r2]
    subs r3, r1
    str r3, [r2]
    mov pc, lr

    defcode "BIS!", BISSTORE
    ldr r1, [PSP]
    ldr r2, [r0]
    orrs r1, r2
    str r1, [r0]
    ldr r0, [PSP, #4]
    adds PSP, #8
    mov pc, lr

    defcode "BIC!", BITCLEARSTORE
    ldr r1, [PSP]
    ldr r2, [r0]
    bics r2, r1
    str r2, [r0]
    ldr r0, [PSP, #4]
    adds PSP, #8
    mov pc, lr

    defcode "XOR!", XORSTORE
    ldr r1, [PSP]
    ldr r2, [r0]
    eors r2, r1
    str r2, [r0]
    ldr r0, [PSP, #4]
    adds PSP, #8
    mov pc, lr

    defcode "BIS", BITSET, F_INLINE
    por
    mov pc, lr

    defcode "BIC", BITCLEAR, F_INLINE
    ldr r1, [PSP]
    bics r1, r0
    mov r0, r1
    adds PSP, #4
    mov pc, lr

    defcode "BIT@", BITFETCH
    ldr r1, [PSP]
    adds PSP, #4
    ldr r2, [r0]
    movs r0, #0
    ands r1, r2
    beq 1f
    mvns r0, r0
1:  mov pc, lr

    defcode "FILL", FILL
    ppop r3
    ppop r2
    ppop r1
    cmp r2, #0
    beq 1f
2:  strb r3, [r1]
    adds r1, #1
    subs r2, #1
    bne 2b
1:  mov pc, lr

    defword "BLANK", BLANK
    bl BL; bl FILL
    exit

    defcode "CMOVE>", CMOVEUP
    ppop r1
    ppop r2
    ppop r3
2:  subs r1, #1
    cmp r1, #0
    blt 1f
    ldrb r4, [r3, r1]
    strb r4, [r2, r1]
    b 2b
1:  mov pc, lr

    defcode "CMOVE", CMOVE
    ppop r1
    ppop r2
    ppop r3
3:  subs r1, #1
    cmp r1, #0
    blt 4f
    ldrb r4, [r3]
    strb r4, [r2]
    adds r2, #1
    adds r3, #1
    b 3b
4:  mov pc, lr

    defcode "IMOVE", IMOVE
    ppop r1
    ppop r2
    ppop r3
    movs r4, #1
    mvns r4, r4
    adds r1, #1
    ands r1, r4
3:  subs r1, #2
    cmp r1, #0
    blt 4f
    ldrh r4, [r3]
    strh r4, [r2]
    adds r2, #2
    adds r3, #2
    b 3b
4:  mov pc, lr

    defcode "MOVE", MOVE
    ppop r1
    ppop r2
    ppop r3
    cmp r3, r2
    blt 2b
    bgt 3b
    mov pc, lr


    defcode "ALIGNED-MOVE>", ALIGNED_MOVEGT
    ppop r1
    ppop r2
    ppop r3
2:  subs r1, r1, #4
    cmp r1, #0
    blt 1f
    ldr r4, [r3, r1]
    str r4, [r2, r1]
    b 2b
1:  mov pc, lr

    defcode "S=", SEQU
    ppop r3
    ppop r2
    ppop r1
    push {r4, r5}
1:  cmp r3, #0
    beq 2f
    ldrb r4, [r1]
    adds r1, r1, #1
    ldrb r5, [r2]
    adds r2, r2, #1
    subs r5, r5, r4
    bne 3f
    subs r3, r3, #1
    b 1b
3:  mov r3, r5
2:  pop {r4, r5}
    ppush r3
    mov pc, lr

    .ltorg

    defword "/STRING", TRIMSTRING
    bl ROT; bl OVER; padd; bl ROT; bl ROT; psub
    exit

    defword "COUNT", COUNT
    pdup; pincr; pswap; pfetchbyte
    exit

    defword "(S\")", XSQUOTE
    bl RFROM; pdecr; bl COUNT; bl TWODUP; padd; bl ALIGNED; pincr; bl TOR
    exit

    defword ">>SOURCE", GTGTSOURCE
    lit8 1; bl SOURCEINDEX; bl ADDSTORE
    exit

    target_conditional ENABLE_COMPILER

    defword "S\"", SQUOT, F_IMMED
    bl LIT_XT; .word XSQUOTE; bl COMMAXT; lit8 '"'; bl WORD
    pdup; pdup; pfetchbyte; pincr; bl HERE; pswap; bl IMOVE
    pfetchbyte; pincr; bl ALLOT; bl ALIGN
    bl GTGTSOURCE
    exit

    defword ".\"", DOTQUOT, F_IMMED
    bl SQUOT; bl LIT_XT; .word TYPE; bl COMMAXT
    exit

    defword ".(", DOTPAREN, F_IMMED
    lit8 ')'; bl WORD; bl COUNT; bl TYPE
    exit

    defword "SZ\"", SZQUOT, F_IMMED
    bl LIT_XT; .word XSQUOTE; bl COMMAXT; lit8 '"'; bl WORD; pdup
    lit8 1; bl OVER; bl ADDSTORE; lit8 0; bl OVER; pdup; pfetchbyte; padd; bl STOREBYTE
    pdup; pfetchbyte; pincr; bl HERE; pswap; bl IMOVE
    pfetchbyte; pincr; bl ALLOT; bl ALIGN
    bl GTGTSOURCE
    exit

    defword "CHAR", CHAR, F_IMMED
    bl BL; bl WORD; pcharadd; bl FETCHBYTE
    exit

    end_target_conditional

    defword "[CHAR]", BRACKETCHAR, F_IMMED
    bl CHAR; bl LIT_XT; .word LIT; bl COMMAXT; bl COMMA
    exit

    defword "PAD", PAD
    bl RAM_DP; bl FETCH; lit8 128; padd
    exit

    defword "ROM-UNLOCK", ROM_UNLOCK
    bl unlock_flash
    exit

    defword "ROM-LOCK", ROM_LOCK
    bl lock_flash
    exit

    defword "ROM-ERASE", ROM_ERASE
    bl erase_flash
    ppop r0
    exit

    defword "FORGET", FORGET
    bl BL; bl WORD; bl FIND; ppop r1; cmp r1, #0; beq 1f
    bl TOLINK; bl DUP; bl DUP; bl FETCH; bl SWAP;
    bl ROM_ERASE
    bl LATEST; bl STORE
    bl ORG
    beq 2f
1:  pdrop; lit8 '?'; bl EMIT;
2:  exit

    .ltorg

@ ---------------------------------------------------------------------
@ -- Arithmetic ------------------------------------------------------

    defcode "1+", INCR, F_INLINE
    pincr
    mov pc, lr

    defcode "CHAR+", CHARADD, F_INLINE
    pcharadd
    mov pc, lr

    defcode "1-", DECR, F_INLINE
    pdecr
    mov pc, lr

    defcode "CHAR-", CHARSUB, F_INLINE
    pcharsub
    mov pc, lr

    defcode "4+", INCR4, F_INLINE
    pincr4
    mov pc, lr

    defcode "CELL+", CELLADD, F_INLINE
    pcelladd
    mov pc, lr

    defcode "4-", DECR4, F_INLINE
    pdecr4
    mov pc, lr

    defcode "CELL-", CELLSUB, F_INLINE
    pcellsub
    mov pc, lr

    defcode "+", ADD, F_INLINE
    padd
    mov pc, lr

    defcode "-", SUB, F_INLINE
    psub
    mov pc, lr

    defcode "*", MUL, F_INLINE
    pmul
    mov pc, lr

    .ifndef THUMB1
    defcode "U/MOD", UDIVMOD
    ppop r2
    ppop r1
    udiv r3, r1, r2
    mls r1, r2, r3, r1
    ppush r1
    ppush r3
    mov pc, lr

    defcode "/MOD", DIVMOD
    ppop r2
    ppop r1
    sdiv r3, r1, r2
    mls r1, r2, r3, r1
    ppush r1
    ppush r3
    mov pc, lr

    defcode "/", DIV
    ppop r2
    ppop r1
    sdiv r1, r1, r2
    ppush r1
    mov pc, lr

    defcode "MOD", MOD
    ppop r2
    ppop r1
    sdiv r3, r1, r2
    mls r1, r2, r3, r1
    ppush r1
    mov pc, lr

    defcode "UMOD", UMOD
    ppop r2
    ppop r1
    udiv r3, r1, r2
    mls r1, r2, r3, r1
    ppush r1
    mov pc, lr

    .else

unsigned_div_mod:               @ r1 / r2 = r3, remainder = r1
    mov     r4, r2              @ put divisor in r4
    mov     r3, r1
    lsrs    r3, #1
1:  cmp     r4, r3
    bhi     3f
    lsls    r4, #1              @ until r4 > r3 / 2
    b       1b
3:  movs    r3, #0              @ initialize quotient
2:  adds    r3, r3              @ double quotien
    cmp     r1, r4              @ can we subtract r4?
    blo     4f
    adds    r3, #1              @ if we can, increment quotiend
    subs    r1, r1, r4          @ and substract
4:  lsrs    r4, #1              @ halve r4,
    cmp     r4, r2              @ and loop until
    bhs     2b                  @ less than divisor
    bx      lr

    defword "U/MOD", UDIVMOD
    ppop r2
    ppop r1
    bl unsigned_div_mod
    ppush r1
    ppush r3
    exit

    defword "/MOD", DIVMOD
    ppop r2
    ppop r1
    bl unsigned_div_mod
    ppush r1
    ppush r3
    exit

    defword "/", DIV
    ppop r2
    ppop r1
    movs r3, #0
    movs r5, #1
    movs r7, #1
    cmp r1, r3
    bge 1f
    subs r5, #2
    muls r1, r5
1:  cmp r2, r3
    bge 2f
    subs r7, #2
    muls r2, r7
2:  bl unsigned_div_mod
    muls r3, r5
    muls r3, r7
    ppush r3
    exit

    defword "MOD", MOD
    ppop r2
    ppop r1
    movs r3, #0
    movs r4, #1
    movs r5, #0
    subs r5, #1
    cmp r1, r3
    bge 1f
    subs r4, #2
    muls r1, r4
1:  cmp r2, r3
    bge 2f
    muls r2, r5
2:  bl unsigned_div_mod
    muls r1, r4
    ppush r1
    exit

    defword "UMOD", UMOD
    ppop r2
    ppop r1
    bl unsigned_div_mod
    ppush r1
    exit
    .endif

    defcode "2*", TWOMUL
    ptwomul
    mov pc, lr

    defcode "2/", TWODIV
    ptwodiv
    mov pc, lr

    defcode "ABS", ABS
    cmp r0, #0
    bge 1f
    mvns r0, r0
    adds r0, #1
1:  mov pc, lr

    defcode "MAX", MAX
    ppop r1
    ppop r2
    cmp r1, r2
    bge 1f
    mov r1, r2
1:  ppush r1
    mov pc, lr

    defcode "MIN", MIN
    ppop r1
    ppop r2
    cmp r1, r2
    ble 1f
    mov r1, r2
1:  ppush r1
    mov pc, lr

    defcode "ROR", ROR
    ppop r1
    ppop r2
1:  rors r2, r1
    ppush r2
    mov pc, lr

    defword "ROTATE", ROTATE
    pdup; bl ZGT; ppop r1; cmp r1, #0; beq 1f; lit8 32; pswap; psub; bl ROR
    exit
1:  bl NEGATE; bl ROR
    exit

    defcode "LSHIFT", LSHIFT
    ldr r1, [PSP]
    adds PSP, #4
    lsls r1, r0
    movs r0, r1
    mov pc, lr

    defcode "RSHIFT", RSHIFT
    movs r0, r0
    ldr r1, [PSP]
    adds PSP, #4
    lsrs r1, r0
    movs r0, r1
    mov pc, lr

    defcode "SHL", SHL, F_INLINE
    lsls r0, #1
    mov pc, lr

    defcode "SHR", SHR, F_INLINE
    lsrs r0, #1
    mov pc, lr

    defword "NEGATE", NEGATE
    lit8 -1; pmul
    exit

    defword "WITHIN", WITHIN
    bl OVER; psub; bl TOR; psub; bl RFROM; bl ULT
    exit

    defword "BITE", BITE
    pdup; lit8 0xff; pand; pswap; lit8 8; bl ROR
    exit

    defword "CHEW", CHEW
    bl BITE; bl BITE; bl BITE; bl BITE; pdrop
    exit

    defcode "BIT", BIT, F_INLINE
    movs r1, #1
    lsls r1, r0
    movs r0, r1
    mov pc, lr

@ ---------------------------------------------------------------------
@ -- Boolean operators -----------------------------------------------

    defcode "TRUE", TRUE
    movs r1, #0
    mvns r1, r1
    ppush r1
    mov pc, lr

    defcode "FALSE", FALSE
    movs r1, #0
    ppush r1
    mov pc, lr

    defcode "AND", AND, F_INLINE
    pand
    mov pc, lr

    defcode "OR", OR, F_INLINE
    por
    mov pc, lr

    defcode "XOR", XOR, F_INLINE
    pxor
    mov pc, lr

    defcode "INVERT", INVERT, F_INLINE
    pinvert
    mov pc, lr

    defcode "NOT", NOT, F_INLINE
    pinvert
    mov pc, lr

@ ---------------------------------------------------------------------
@ -- Comparisons -----------------------------------------------------

    defcode "=", EQU
    ldr r1, [PSP]
    adds PSP, #4
    movs r3, #0
    cmp r0, r1
    bne 1f
    mvns r3, r3
1:  movs r0, r3
    mov pc, lr

    defcode "<", LT
    ldr r1, [PSP]
    adds PSP, #4
    movs r3, #0
    cmp r1, r0
    bge 1f
    mvns r3, r3
1:  movs r0, r3
    mov pc, lr

    defcode "U<", ULT
    ldr r1, [PSP]
    adds PSP, #4
    movs r3, #0
    cmp r1, r0
    bcs 1f
    mvns r3, r3
1:  movs r0, r3
    mov pc, lr

    defword ">", GT
    pswap; bl LT
    exit

    defword "U>", UGT
    pswap; bl ULT
    exit

    defword "<>", NEQU
    bl EQU; pinvert
    exit

    defword "<=", LE
    bl GT; pinvert
    exit

    defword ">=", GE
    bl LT; pinvert
    exit

    defword "0=", ZEQU
    movs r3, #0
    cmp r0, #0
    bne 1f
    mvns r3, r3
1:  movs r0, r3
    exit

    defword "0<>", ZNEQU
    movs r3, #0
    cmp r0, #0
    beq 1f
    mvns r3, r3
1:  movs r0, r3
    exit

    defword "0<", ZLT
    movs r3, #0
    cmp r0, #0
    bge 1f
    mvns r3, r3
1:  movs r0, r3
    exit

    defword "0>", ZGT
    movs r3, #0
    cmp r0, #0
    ble 1f
    mvns r3, r3
1:  movs r0, r3
    exit

    defword "0<=", ZLE
    movs r3, #0
    cmp r0, #0
    bgt 1f
    mvns r3, r3
1:  movs r0, r3
    exit

    defword "0>=", ZGE
    movs r3, #0
    cmp r0, #0
    blt 1f
    mvns r3, r3
1:  movs r0, r3
    exit

@ ---------------------------------------------------------------------
@ -- Input/output ----------------------------------------------------

    defconst "#TIB", TIBSIZE, 128
    defconst "C/BLK", CSLASHBLK, 1024

    defword "SOURCE", SOURCE
    bl XSOURCE; pfetch; bl SOURCECOUNT; pfetch
    exit

    .ltorg

    defword "(.S)", XPRINTSTACK
1:  bl TWODUP; bl LE; ppop r1; cmp r1, #0; beq 2f; pdup; pfetch; bl DOT; bl CELLSUB;
    b 1b
2:  bl TWODROP
    exit

    defword ".S", PRINTSTACK
    bl DEPTH; ppop r1; cmp r1, #0; beq 1f; blt 2f
    bl SPFETCH; bl S0; pcellsub; pcellsub; bl XPRINTSTACK; pdup; bl DOT;
    bl CR
1:  exit
2:  lit32 underflow_error; lit8 17; bl TYPE
    exit
underflow_error:
    .ascii "Stack underflow!\n"

    defword ".R", PRINTRSTACK
    bl RPFETCH; bl R0; pfetch; pcellsub; bl XPRINTSTACK
    bl CR
    exit

    defword "PUTCHAR", PUTCHAR
    bl putchar
    ldr r0, [PSP]
    adds PSP, #4
    exit

    defword "LF", LF
    lit8 10; bl EMIT
    exit

    defword "CR", CR
    lit8 13; bl EMIT; bl LF
    exit

    defconst "BL", BL, 32

    defword "SPACE", SPACE
    bl BL; bl EMIT
    exit

    defword "SPACES", SPACES
2:  cmp r0, #0
    beq 1f
    subs r0, #1
    bl SPACE
    b 2b
1:  pdrop
    exit

    defword "HOLD", HOLD
    lit8 1; bl HP; bl SUBSTORE; bl HP; pfetch; bl STOREBYTE
    exit

    defword "<#", LTNUM
    bl PAD; bl HP; bl STORE
    exit

    defword ">DIGIT", TODIGIT
    pdup; lit8 9; bl GT; lit8 7; pand; bl ADD; lit8 48; bl ADD
    exit

    defword "#", NUM
    bl BASE; pfetch; bl UDIVMOD; pswap; bl TODIGIT; bl HOLD
    exit

    defword "#S", NUMS
1:  bl NUM; pdup; bl ZEQU; ppop r1; cmp r1, #0; beq 1b
    exit

    defword "#>", NUMGT
    pdrop; bl HP; pfetch; bl PAD; bl OVER; psub
    exit

    defword "SIGN", SIGN
    bl ZLT; ppop r1; cmp r1, #0; beq 1f
    lit8 '-'; bl HOLD
1:  exit

    defword "U.", UDOT
    bl LTNUM; bl NUMS; bl NUMGT; bl TYPE; bl SPACE
    exit

    defword ".", DOT
    bl LTNUM; pdup; bl ABS; bl NUMS; pswap; bl SIGN; bl NUMGT; bl TYPE; bl SPACE
    exit

    defword "HEX.", HEXDOT
    bl BASE; bl FETCH; bl SWAP; bl HEX
    bl LTNUM;
    bl NUM; bl NUM; bl NUM; bl NUM;
    bl NUM; bl NUM; bl NUM; bl NUM;
    bl NUMGT; bl TYPE
    bl BASE; bl STORE
    exit

    .ltorg

    defword "KEY?", KEYQ
    bl TICKKEYQ; pfetch; bl EXECUTE
    exit

    defword "KEY", KEY
    bl TICKKEY; pfetch; bl EXECUTE
    exit

    defword "FINISH-OUTPUT", FINISH_OUTPUT
    bl TICKFINISH_OUTPUT; pfetch; bl EXECUTE
    exit

    defword "EMIT", EMIT
    bl TICKEMIT; pfetch; bl EXECUTE
    exit

    defword "SERIAL-CON", SERIAL_CON
    bl EMULATIONQ; ppop r1; cmp r1, #0; beq 1f
    bl LIT_XT; .word haskey_emulator; bl TICKKEYQ; bl STORE
    bl LIT_XT; .word readkey_emulator; bl TICKKEY; bl STORE
    bl LIT_XT; .word NOOP; bl TICKFINISH_OUTPUT; bl STORE
    bl LIT_XT; .word putchar_emulator; bl TICKEMIT; bl STORE
    exit
1:  bl LIT_XT; .word haskey; bl TICKKEYQ; bl STORE
    bl LIT_XT; .word readkey; bl TICKKEY; bl STORE
    bl LIT_XT; .word NOOP; bl TICKFINISH_OUTPUT; bl STORE
    bl LIT_XT; .word putchar; bl TICKEMIT; bl STORE
    exit

    defword "TYPE", TYPE
2:  cmp r0, #0
    ble 1f
    pswap; pdup; ldrb r0, [r0]; bl EMIT; adds r0, #1; pswap; subs r0, #1
    b 2b
1:  pdrop; pdrop
    exit

    defword "ACCEPT", ACCEPT
    bl TOR
    lit8 0
2:  bl RFETCH; bl OVER; bl EQU; ppop r1; cmp r1, #0; bne 1f
    bl TWODUP; bl ADD; bl KEY; cmp r0, #10; beq 3f
    movs r1, #127; cmp r0, r1; beq 4f
    pdup; bl EMIT
    bl SWAP; bl STOREBYTE; adds r0, #1
    b 2b
4:  pdrop; pdrop; cmp r0, #0; beq 2b
    subs r0, #1; lit8 8; bl EMIT; lit8 32; bl EMIT; lit8 8; bl EMIT
    b 2b
3:  pdrop; pdrop
1:  bl NIP
    bl RDROP
    exit

    defword "4NUM", FOURNUM
    bl NUM; bl NUM; bl NUM; bl NUM
    exit

    defword "(DUMP-ADDR)", XDUMP_ADDR
    bl CR; pdup; bl LTNUM; bl FOURNUM; bl FOURNUM; bl NUMGT; bl TYPE; lit8 58; bl EMIT; bl SPACE
    exit

    defword "DUMP", DUMP
    bl BASE; pfetch; bl TOR; bl HEX; bl QDUP; ppop r1; cmp r1, #0; beq dump_end
    pswap
dump_start_line:
    bl XDUMP_ADDR
dump_line:
    pdup; pfetchbyte; bl LTNUM; bl NUM; bl NUM; bl NUMGT; bl TYPE; bl SPACE; pincr
    pswap; pdecr; bl QDUP; ppop r1; cmp r1, #0; beq dump_end
    pswap; pdup; lit8 7; pand; ppop r1; cmp r1, #0; beq dump_start_line
    b dump_line
dump_end:
    pdrop; bl RFROM; bl BASE; bl STORE
    exit

    defword "DUMPW", DUMPW
    bl BASE; pfetch; bl TOR; bl HEX; bl QDUP; ppop r1; cmp r1, #0; beq dumpw_end_final
    pswap
dumpw_start_line:
    bl XDUMP_ADDR
dumpw_line:
    pdup; pfetch; bl LTNUM; bl FOURNUM; bl FOURNUM; bl NUMGT; bl TYPE; bl SPACE; pincr4
    pswap; pdecr4; pdup; bl ZGT; ppop r1; cmp r1, #0; beq dumpw_end
    pswap; pdup; lit8 0x1f; pand; ppop r1; cmp r1, #0; beq dumpw_start_line
    b dumpw_line
dumpw_end:
    pdrop
dumpw_end_final:
    pdrop; bl RFROM; bl BASE; bl STORE
    exit

    defword "SKIP", SKIP
    bl TOR
1:  bl OVER; pfetchbyte; bl RFETCH; bl EQU; bl OVER; bl ZGT; pand; ppop r1; cmp r1, #0; beq 2f
    lit8 1; bl TRIMSTRING;
    b 1b
2:  bl RDROP
    exit

    defword "SCAN", SCAN
    bl TOR
1:  bl OVER; pfetchbyte; bl RFETCH; bl NEQU; bl OVER; bl ZGT; pand; ppop r1; cmp r1, #0; beq 2f
    lit8 1; bl TRIMSTRING;
    b 1b
2:  bl RDROP
    exit

    defword "?SIGN", ISSIGN
    bl OVER; pfetchbyte; lit8 0x2c; psub; pdup; bl ABS
    lit8 1; bl EQU; pand; pdup; ppop r1; cmp r1, #0; beq 1f
    pincr; bl TOR; lit8 1; bl TRIMSTRING; bl RFROM
1:  exit

    defword "DIGIT?", ISDIGIT
    pdup; lit8 '9'; bl GT; lit32 0x100; pand; padd
    pdup; lit32 0x140; bl GT; lit32 0x107; pand; psub; lit8 0x30; psub
    pdup; bl BASE; pfetch; bl ULT
    exit

    defword "SETBASE", SETBASE
    bl OVER; pfetchbyte
    pdup; lit8 '$'; bl EQU; ppop r1; cmp r1, #0; beq 1f; bl HEX; b 4f
1:  pdup; lit8 '#'; bl EQU; ppop r1; cmp r1, #0; beq 2f; bl DECIMAL; b 4f
2:  pdup; lit8 '%'; bl EQU; ppop r1; cmp r1, #0; beq 3f; bl BINARY; b 4f
3:  pdrop
    exit
4:  pdrop; lit8 1; bl TRIMSTRING
    exit

    defword ">NUMBER", TONUMBER
    bl BASE; pfetch; bl TOR; bl SETBASE
tonumber_loop:
    pdup; ppop r1; cmp r1, #0; beq tonumber_done
    bl OVER; pfetchbyte; bl ISDIGIT
    bl ZEQU; ppop r1; cmp r1, #0; beq tonumber_cont
    pdrop; b tonumber_done
tonumber_cont:
    bl TOR; bl ROT; bl BASE; pfetch; pmul
    bl RFROM; padd; bl ROT; bl ROT
    lit8 1; bl TRIMSTRING
    b tonumber_loop
tonumber_done:
    bl RFROM; bl BASE; bl STORE
    exit

    defword "?NUMBER", ISNUMBER /* ( c-addr -- n true | c-addr false ) */
    pdup; lit8 0; pdup; bl ROT; bl COUNT;
    bl ISSIGN; bl TOR; bl TONUMBER; ppop r1; cmp r1, #0; beq is_number
    bl RDROP; bl TWODROP; pdrop; lit8 0
    exit
is_number:
    bl TWOSWAP; bl TWODROP; pdrop; bl RFROM; bl ZNEQU; ppop r1; cmp r1, #0; beq is_positive; bl NEGATE
is_positive:
    lit8 -1
    exit

    .ltorg

    defword "DECIMAL", DECIMAL
    lit8 10; bl BASE; bl STORE
    exit

    defword "HEX", HEX
    lit8 16; bl BASE; bl STORE
    exit

    defword "OCTAL", OCTAL
    lit8 8; bl BASE; bl STORE
    exit

    defword "BINARY", BINARY
    lit8 2; bl BASE; bl STORE
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
    .ifndef THUMB1
    mov r1, lr
    subs r1, r1, #1
    ldr r2, [r1]
    adds r1, r2
    adds r1, r1, #1
    mov pc, r1
    .else
    mov r3, lr
    mov r1, lr
    subs r3, #1
    ldrh r2, [r3]
    adds r3, #2
    ldrh r3, [r3]
    lsls r3, #16
    orrs r2, r3
    adds r1, r2
    mov pc, r1
    .endif
    @ .endif

    defcode "?BRANCH", QBRANCH
    ppop r1
    cmp r1, #0
    beq BRANCH
    @ .ifndef THUMB1
    @ adds lr, lr, #4
    @ mov pc, lr
    @ .else
    mov r1, lr
    adds r1, r1, #4
    mov pc, r1
    @ .endif

    defcode "(FARCALL)", XFARCALL
    .ifndef THUMB1
    mov r1, lr
    subs r1, #1
    ldr r2, [r1]
    adds r1, #5
    .else
    mov r3, lr
    mov r1, lr
    subs r3, #1
    ldrh r2, [r3]
    adds r3, #2
    ldrh r3, [r3]
    lsls r3, #16
    orrs r2, r3
    adds r1, #4
    .endif
    mov lr, r1
    mov pc, r2

    defcode "COPY-FARCALL", COPY_FARCALL
    ldr r1, =addr_FARCALL
    ldr r2, =XFARCALL
    .ifndef THUMB1
    movs r3, #4
    .else
    movs r3, #6
    .endif
1:  ldr r4, [r2]
    str r4, [r1]
    adds r1, #4
    adds r2, #4
    subs r3, #1
    bne 1b
    mov pc, lr
    .ltorg

    target_conditional ENABLE_COMPILER

    defword "POSTPONE", POSTPONE, F_IMMED
    bl BL; bl WORD; bl FIND
    bl ZLT; ppop r1; cmp r1, #0; beq 1f
    bl LIT_XT; .word LIT_XT; bl COMMAXT; bl COMMA
    bl LIT_XT; .word COMMAXT; bl COMMAXT; b 2f
1:  bl COMMAXT
2:  exit

    defword "LITERAL", LITERAL, F_IMMED
    cmp r0, #255
    bgt 1f
    cmp r0, #0
    ble 1f
    ppop r1
    movs r2, #0x21
    lsls r2, #8
    orrs r1, r2
    ppush r1
    bl COMMAH
    ldr r4, =2f
    ldr r1, [r4]
    ppush r1
    bl COMMA
    ldrh r1, [r4, #4]
    ppush r1
    bl COMMAH
    exit
1:  bl LIT_XT; .word LIT; bl COMMAXT; bl COMMA
    exit
    .align 2
2:  ppush r1

    defword "BEGIN", BEGIN, F_IMMED
    bl HERE
    exit

    defword "AGAIN", AGAIN, F_IMMED
    bl HERE; psub; ppop r2; subs r2, #4; lsrs r2, #1
    ldr r3, =0x07ff; ands r2, r3;
    movs r1, #0xe0; lsls r1, #8
    orrs r1, r2; ppush r1; bl COMMAH
    exit

    .ltorg

    defword "UNTIL", UNTIL, F_IMMED
    bl LIT_XT; .word QBRANCH; bl COMMAXT; bl HERE; psub; bl COMMA
    exit

    defword "IF", IF, F_IMMED
    ldr r4, =1f;
    ldr r2, [r4]; ppush r2; bl COMMA
    ldr r2, [r4, #4]; ppush r2; bl COMMA
    ldrh r2, [r4, #8]; ppush r2; bl COMMAH
    bl HERE; pdecr; pdecr
    exit
    .align 2
1:  ppop r1
    cmp r1, #0
    .short 0xffff

    defword "ELSE", ELSE, F_IMMED
    movs r1, #0; subs r1, #1; ppush r1; bl COMMAH
    bl HERE; pdecr; pdecr; mvns r0, r0
    pswap; bl THEN
    exit

    defword "THEN", THEN, F_IMMED
    cmp r0, #0; blt 1f
    movs r1, #0xd0; b 2f
1:  mvns r0, r0
    movs r1, #0xe0
2:  lsls r1, #8; ppush r1
    bl OVER; bl HERE; pswap
    psub; pcellsub; ptwodiv; por
    pswap
    bl IHSTORE
    exit

    defword "WHILE", WHILE, F_IMMED
    bl IF
    exit

    defword "REPEAT", REPEAT, F_IMMED
    pswap; bl LIT_XT; .word BRANCH; bl COMMAXT; bl HERE; psub; bl COMMA
    bl THEN
    exit

    .ltorg

    defword "CASE", CASE, F_IMMED
    lit8 0
    exit

    defword "OF", OF, F_IMMED
    bl LIT_XT; .word OVER; bl COMMAXT; bl LIT_XT; .word EQU; bl COMMAXT; bl IF; bl LIT_XT; .word DROP; bl COMMAXT
    exit

    defword "ENDCASE", ENDCASE, F_IMMED
    bl LIT_XT; .word DROP; bl COMMAXT
1:  pdup; ppop r1; cmp r1, #0; beq 2f
    bl THEN; b 1b
2:  pdrop
    exit

    end_target_conditional

    defcode "(DO)", XDO
    ppop r1
    ppop r2
    pop {r3}
    push {r2}
    push {r1}
    push {r3}
    mov pc, lr

    defcode "I", INDEX
    .ifndef THUMB1
    ldr r1, [RSP, #4]
    .else
    mov r1, RSP
    adds r1, #4
    ldr r1, [r1]
    .endif
    ppush r1
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
    mov r4, RSP
    adds r4, #4
    ldr r2, [r4]
    adds r2, r2, #1
    mov r1, RSP
    adds r1, #8
    ldr r1, [r1]
    cmp r2, r1
    bge 1f
    str r2, [r4]
    .endif
    movs r4, #0
    ppush r4
    mov pc, lr
1:  pop {r1, r2, r3}
    push {r1}
    movs r1, #0
    mvns r1, r1
    ppush r1
    mov pc, lr

    defcode "UNLOOP", UNLOOP
    pop {r1, r2, r3}
    push {r1}
    mov pc, lr

    target_conditional ENABLE_COMPILER

    defword "DO", DO, F_IMMED
    bl LIT_XT; .word XDO; bl COMMAXT; bl HERE
    exit

    defword "LOOP", LOOP, F_IMMED
    bl LIT_XT; .word XLOOP; bl COMMAXT; bl LIT_XT; .word QBRANCH; bl COMMAXT; bl HERE; psub; bl COMMA
    exit

    defword "DELAY", DELAY
    bl delay
    pdrop
    exit

    defword "RECURSE", RECURSE, F_IMMED
    bl LATEST; pfetch; bl FROMLINK; bl COMMAXT
    exit

    end_target_conditional

@ ---------------------------------------------------------------------
@ -- Compiler and interpreter ----------------------------------------

    defcode "EMULATION?", EMULATIONQ
    ldr r4, =0xe000ed00
    ldr r4, [r4]
    movs r1, #0
    cmp r4, r1
    bne 1f
    subs r1, #1
1:  ppush r1
    mov pc, lr

    defcode "EMULATOR-BKPT", EMULATOR_BKPT
    ppop r1
    push {r1}
    bkpt 0xab
    mov pc, lr

    target_conditional ENABLE_COMPILER

    defword "ROM-DUMP", ROM_DUMP
    bl HERE; lit32 init_here; bl STORE
    bl RAM_DP; pfetch; lit32 init_data_start; bl STORE
    bl LATEST; pfetch; lit32 init_last_word; bl STORE
    ldr r1, =rom_start; push {r1}
    bl ROM_DP; pfetch; ppop r1; push {r1}
    movs r1, #0x80; push {r1}; bkpt 0xab
    exit

    end_target_conditional

    defword "BYE", BYE
    bl EMULATIONQ
    ppop r1; cmp r1, #0; beq 1f
    movs r1, #0x18; push {r1}; bkpt 0xab
1:  b .
    exit

    defcode "WFI", WFI, F_INLINE
    wfi
    mov pc, lr

    defcode "WFE", WFE, F_INLINE
    wfe
    mov pc, lr

    defcode "RESET", RESET
    ldr r4, =0xe000ed0c
    ldr r1, =0x05fa0004
    str r1, [r4]

    defcode "HALT", HALT
    b .

    .ltorg

    defcode "LIT", LIT
    mov r4, lr
    subs r4, r4, #1
    .ifdef THUMB1
    ldrh r1, [r4]
    adds r4, #2
    ldrh r2, [r4]
    lsls r2, #16
    orrs r1, r2
    adds r4, #3
    .else
    ldr r1, [r4]
    adds r4, #5
    .endif
    ppush r1
    mov pc, r4

    defcode "LIT_XT", LIT_XT
    b LIT

    defword "ROM", ROM
    bl TRUE; bl ROM_ACTIVE; bl STORE
    exit

    defword "RAM", RAM
    bl FALSE; bl ROM_ACTIVE; bl STORE
    exit

    defword "ROM?", ROMQ
    bl ROM_ACTIVE; pfetch
    exit

    defword "DP", DP
    bl ROMQ; ppop r1; cmp r1, #0; beq 1f
    bl ROM_DP
    exit
1:  bl RAM_DP
    exit

    defword "HERE", HERE
    bl DP; pfetch
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
    bl HERE; bl ISTORE; bl CELL; bl ALLOT
    exit

    defword ",H", COMMAH
    bl HERE; bl IHSTORE; lit8 2; bl ALLOT
    exit

    defword ",XT-FAR", COMMAXT_FAR
    bl LIT_XT; .word addr_FARCALL; bl COMMAXT; bl COMMA;
    exit

    defword ",XT", COMMAXT
    pdup;
    bl HERE; bl CELLADD; psub;
    ppop r4
    ldr r1, =0x00400000
    cmp r1, r4
    ble 1f
    ldr r1, =0xffc00000
    cmp r1, r4
    ble 1f
    bl COMMAXT_FAR
    exit

1:  pdrop
    asrs r4, r4, #1;
    ldr r1, =0xf800f400

    movs r2, r4
    asrs r2, #11
    ldr r3, =0x000003ff
    ands r2, r3
    orrs r1, r2

    movs r2, r4
    lsls r2, #16
    ldr r3, =0x7fff0000
    ands r2, r3
    orrs r1, r2

    movs r4, r1
    ppush r4
    bl COMMA
    exit
    .align 2,0
    .ltorg

    defword ",LINK", COMMALINK
    bl COMMA
    exit

    defword "C,", CCOMMA
    bl HERE; bl ICSTORE; lit8 1; bl ALLOT
    exit

    defword ">UPPER", GTUPPER
    bl OVER; bl ADD; pswap
1:  bl XDO; bl INDEX; bl FETCHBYTE; bl UPPERCASE; bl INDEX; bl STOREBYTE; bl XLOOP; ppop r1; cmp r1, #0; beq 1b
    exit

    defword "UPPERCASE", UPPERCASE
    pdup; lit8 0x61; lit8 0x7b; bl WITHIN; lit8 0x20; pand; pxor
    exit

    defword "SI=", SIEQU
    bl TOR
1:  bl RFETCH; pdup; ppop r1; cmp r1, #0; beq 2f; pdrop; bl TWODUP; bl FETCHBYTE; bl UPPERCASE
    pswap; bl FETCHBYTE; bl UPPERCASE; bl EQU
2:  ppop r1; cmp r1, #0; beq 3f
    bl INCR; pswap; bl INCR; bl RFROM; bl DECR; bl TOR; b 1b
3:  bl TWODROP; bl RFROM; bl ZEQU
    exit

    defword "LINK>", FROMLINK
    bl LINKTONAME; pdup; pfetchbyte; padd; pincr; bl ALIGNED
    exit

    defcode ">FLAGS", TOFLAGS
    subs r0, #2
1:  subs r0, #1
    ldrb r1, [r0]
    cmp r1, #F_MARKER
    bne 1b
    subs r0, #1
    mov pc, lr

    defword ">NAME", TONAME
    bl TOFLAGS; adds r0, #2
    exit

    .ltorg

    defword ">LINK", TOLINK
    bl TONAME; subs r0, #6
    exit

    defcode ">BODY", TOBODY
    adds r0, #16
    mov pc, lr

    defcode "LINK>NAME", LINKTONAME
    adds r0, #6
    mov pc, lr

    defcode "LINK>FLAGS", LINKTOFLAGS
    adds r0, #4
    mov pc, lr

    defword "ANY>LINK", ANYTOLINK
    bl LATEST
1:  pfetch; bl TWODUP; bl GT; ppop r1; cmp r1, #0; beq 1b
    pnip
    exit

    defcode "EXECUTE", EXECUTE
    ppop r1
    @.ifndef THUMB1
    @orr r0, r0, #1
    @.else
    movs r2, #1
    orrs r1, r2
    @.endif
    mov pc, r1

    target_conditional ENABLE_COMPILER

    defword "MARKER", MARKER
    bl CREATE; bl LATEST; pfetch; pfetch; bl COMMA; bl XDOES
    pfetch; bl LATEST; bl STORE
    exit

    defword "\'", TICK
    bl BL; bl WORD; bl FIND; pdrop
    exit

    defword "[\']", BRACKETTICK, F_IMMED
    bl TICK; bl LIT_XT; .word LIT; bl COMMAXT; bl COMMA
    exit

    defword "(DOES>)", XDOES
    bl HERE
    pop {r1}; subs r1, #1; ppush r1
    bl LATEST; pfetch; bl FROMLINK; adds r0, #10; bl ORG
    lit32 0xb500; bl COMMAH
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
    bl LATEST; pfetch
    bl HERE; bl LATEST; bl STORE
    bl COMMALINK
    lit32 0xffff; bl COMMAH
    bl BL; bl WORD; pdup;
    pdup; pfetchbyte; pincr; bl HERE; pswap; bl IMOVE
    pfetchbyte; pincr; bl ALLOT; bl ALIGN
    exit

    defword "(CONSTANT)", XCONSTANT
    bl BUILDS;
    ldr r4, =DOCON;
    ldr r1, [r4]; ppush r1; bl COMMA;
    ldr r1, [r4, #4]; ppush r1; bl COMMA;
    ldr r1, [r4, #8]; ppush r1; bl COMMA;
    exit
    .ltorg
    .align 2, 0
DOCON:
    ldr	r1, [pc, #8]
    ppush r1
    mov pc, lr

    defword "CONSTANT", CONSTANT
    bl XCONSTANT; bl COMMA;
    exit

    defword "CREATE", CREATE
    bl BUILDS;
    ldr r4, =DODATA;
    ldr r1, [r4]; ppush r1; bl COMMA;
    ldr r1, [r4, #4]; ppush r1; bl COMMA;
    ldr r1, [r4, #8]; ppush r1; bl COMMA;
    ldr r1, [r4, #12]; ppush r1; bl COMMA;
    exit
    .ltorg
    .align 2, 0
DODATA:
    mov r1, pc
    adds r1, #12
    ppush r1
    mov pc, lr
    exit

    defword "BUFFER:", BUFFER
    bl ROMQ; bl RAM; bl HERE;
    bl ROT; bl DUP; bl ALLOT;
    bl ROT; bl ROM_ACTIVE; bl STORE
    bl SWAP; bl CONSTANT; bl COMMA
    exit

    defword "VARIABLE", VARIABLE
    bl ROMQ; bl RAM; bl HERE; lit8 4; bl ALLOT; bl SWAP; bl ROM_ACTIVE; bl STORE
    bl CONSTANT
    exit

    defword "DEFER", DEFER
    /*
    bl CREATE; bl LIT_XT
    exit
    .set DEFER_XT, .
    ldr r1, [pc]
    blx r1
    bl DODOES + 1; pfetch; bl EXECUTE;
    */
    exit

    /*
    defword "IS", IS
    bl TICK; bl TOBODY; bl STORE
    exit

    defword "DECLARE", DECLARE
    bl CREATE; bl LATEST; pfetch; bl LINKTOFLAGS; pdup; pfetch; lit8 F_NODISASM; por; pswap; bl STORE
    exit
    */

    defword "(FIND)", XFIND
2:  bl TWODUP; bl LINKTONAME; bl OVER; bl FETCHBYTE; bl INCR; bl SIEQU; bl ZEQU; pdup; ppop r1; cmp r1, #0; beq 1f
    pdrop; pfetch; pdup
1:  bl ZEQU; ppop r1; cmp r1, #0; beq 2b
    pdup; ppop r1; cmp r1, #0; beq 3f
    pnip; pdup; bl FROMLINK; pswap; bl LINKTOFLAGS; bl FETCHBYTE; lit8 F_IMMED; bl NEQU; lit8 0x1; por
3:  exit

    defword "FIND", FIND
    bl LATEST; pfetch; bl XFIND; bl QDUP; ppop r1; cmp r1, #0; beq 1f
    exit
1:  lit32 last_host; bl QDUP; ppop r1; cmp r1, #0; beq 2f; bl XFIND
    exit
2:  lit8 0
    exit

    defword "\\", BACKSLASH, F_IMMED
    bl SOURCECOUNT; pfetch; bl SOURCEINDEX; bl STORE
    exit

    defword "(", LPAREN, F_IMMED
    lit8 ')'; bl WORD; pdrop
    exit

    defword "WORD", WORD
    pdup; bl SOURCE; bl SOURCEINDEX; pfetch; bl TRIMSTRING
    pdup; bl TOR; bl ROT; bl SKIP
    bl OVER; bl TOR; bl ROT; bl SCAN
    pdup; bl ZNEQU; ppop r1; cmp r1, #0; beq noskip_delim; pdecr
noskip_delim:
    bl RFROM; bl RFROM; bl ROT; psub; bl SOURCEINDEX; bl ADDSTORE
    bl TUCK; psub
    pdup; bl WORDBUF; bl STOREBYTE
    bl WORDBUF; pincr; pswap; bl MOVE
    bl WORDBUF
    exit

    defword "(COMPILE)", XCOMPILE @ TODO: Faulty
    pdup; bl TOFLAGS; pfetchbyte; movs r2, #F_INLINE; ands r0, r2; beq 1f
    ldr r2, =0x46f7; pdrop
    movs r3, r0
4:  ldrh r1, [r3]
    cmp r1, r2
    beq 3f
    push {r2, r3}
    ppush r1
    bl COMMAH
    pop {r2, r3}
    adds r3, #2
    b 4b
3:  pdrop; exit
1:  pdrop; bl COMMAXT; exit
    .ltorg
2:  .hword 0
    mov pc, lr

    defword "(INTERPRET)", XINTERPRET
    bl ROM_UNLOCK
interpret_loop:
    bl BL; bl WORD; pdup; pfetchbyte; ppop r1; cmp r1, #0; beq interpret_eol
    bl FIND; bl QDUP; ppop r1; cmp r1, #0; beq interpret_check_number
    bl STATE; pfetch; ppop r1; cmp r1, #0; beq interpret_execute
    pincr; ppop r1; cmp r1, #0; beq interpret_compile_word
    bl EXECUTE; b interpret_loop
interpret_compile_word:
    bl COMMAXT; b interpret_loop
interpret_execute:
    pdrop; bl EXECUTE; b interpret_loop
interpret_check_number:
    bl ISNUMBER; ppop r1; cmp r1, #0; beq interpret_not_found
    bl STATE; pfetch; ppop r1; cmp r1, #0; beq interpret_loop
    bl LITERAL; b interpret_loop
interpret_not_found:
    bl ROM_LOCK
    lit8 0
    exit
interpret_eol:
    bl ROM_LOCK
    lit8 -1
    exit

    .ltorg

    defword "EVALUATE", EVALUATE
    bl XSOURCE; bl STORE
    lit8 0; bl STATE; bl STORE
1:  bl XSOURCE; pfetch;
5:  pdup; pfetchbyte
          pdup; bl ZNEQU; ppop r1; cmp r1, #0; beq 2f
          pdup; lit32 255; bl EQU; ppop r1; cmp r1, #0; bne 2f
          lit8 10; bl EQU; ppop r1; cmp r1, #0; beq 7f
    pincr; b 5b
7:  pdup
6:  pdup; pfetchbyte; lit8 10; bl NEQU; ppop r1; cmp r1, #0; beq 4f
    pincr; b 6b
4:  bl OVER; psub
    bl TWODUP; bl TYPE; bl CR
    bl SOURCECOUNT; bl STORE; bl XSOURCE; bl STORE; lit8 0; bl SOURCEINDEX; bl STORE
    bl XINTERPRET; ppop r1; cmp r1, #0; beq 3f; pdrop
    bl SOURCECOUNT; pfetch; bl XSOURCE; bl ADDSTORE; b 1b
2:  bl TWODROP
    exit
3:  pdup; bl DOT; bl SPACE; bl COUNT; bl TYPE; lit8 '?'; bl EMIT; bl CR
    exit

    .ltorg

    defword "HIDE", HIDE
    @ bl LATEST; pfetch; bl LINKTOFLAGS; pincr; pdup; pfetchbyte; lit8 F_HIDDEN; por; pswap; bl ICSTORE
    exit

    defword "REVEAL", REVEAL
    @ bl LATEST; pfetch; bl LINKTOFLAGS; pincr; pdup; pfetchbyte; lit8 F_HIDDEN; pinvert; pand; pswap; bl ICSTORE
    exit

    defword "IMMEDIATE", IMMEDIATE
    lit32 (0xff00 | F_IMMED); bl LATEST; pfetch; bl LINKTOFLAGS; bl IHSTORE
    exit

    defword "INLINE", INLINE
    lit32 (0xff00 | F_INLINE); bl LATEST; pfetch; bl LINKTOFLAGS; bl IHSTORE
    exit

    defword "[", LBRACKET, F_IMMED
    lit8 0; bl STATE; bl STORE
    exit

    defword "]", RBRACKET
    lit8 -1; bl STATE; bl STORE
    exit

    defword ":", COLON
    bl BUILDS;
    movs r1, #0xb5; lsls r1, #8; ppush r1; bl COMMAH;
    bl HIDE; bl RBRACKET;
    exit

    defword ";", SEMICOLON, F_IMMED
    movs r1, #0xbd; lsls r1, #8; ppush r1; bl COMMAH;
    bl REVEAL; bl LBRACKET
    exit

    end_target_conditional

    defword "WORDS", WORDS
    bl LATEST; pfetch
1:  pdup; bl LINKTONAME; bl COUNT; bl TYPE; bl SPACE
    pfetch; bl QDUP; bl ZEQU; ppop r1; cmp r1, #0; beq 1b
    exit

    defword "LIST", LIST
    bl LATEST; pfetch
1:
    pdup; bl FROMLINK; bl UDOT; pdup; bl CELLADD; adds r0, #2; bl COUNT; bl TYPE; bl CR
    pfetch; bl QDUP; bl ZEQU; ppop r1; cmp r1, #0; beq 1b
    exit

    defword "DEFINED?", DEFINEDQ
    bl BL; bl WORD; bl FIND; pnip
    exit

    defword "ERASED-START", ERASED_START
    ppush r0
    ldr r0, =rom_top
    movs r2, #0
    subs r2, #1
1:  subs r0, #4
    ldr r1, [r0]
    cmp r1, r2
    beq 1b
    adds r0, #4
    exit

    defword "SEEK-LATEST", SEEK_LATEST
    ldr r3, =rom_top
    ldr r0, =last_core_word
3:  movs r4, r0
2:  adds r4, #4
    cmp r4, r3
    beq 1f
    ldr r2, [r4]
    cmp r2, r0
    bne 2b
    movs r0, r4
    b 3b
1:  ppush r0
    exit

    defword "INTERPRET", INTERPRET
    lit8 0; bl SOURCEINDEX; bl STORE;
    bl TIB; pdup; bl XSOURCE; bl STORE;
    lit8 0x13; bl EMIT;
    bl TIBSIZE; bl ACCEPT; bl SOURCECOUNT; bl STORE; bl SPACE;
    bl XINTERPRET; ppop r1; cmp r1, #0; beq 1f
    pdrop; lit32 3f; lit8 4; bl TYPE; b 2f
1:  bl COUNT; bl TYPE; lit8 63; bl EMIT;
2:  bl CR;
    lit8 0x11; bl EMIT;
    exit
3:  .ascii " ok "

@ ---------------------------------------------------------------------
@ -- Entry point ------------------------------------------------------

    defword "TURNKEY", TURNKEY
    bl ABORT
    exit

    defcode "COLD", reset_handler
main:
    bl init_board
    ldr r0, =ram_top
    mov RSP, r0
    ldr r0, =ram_top - 0x200
    mov PSP, r0
    movs r0, #0
    subs r0, #1
    lit8 16; bl BASE; bl STORE
    bl ROM
    bl ERASED_START; bl ROM_DP; bl STORE
    bl SEEK_LATEST; bl LATEST; bl STORE
    lit32 init_data_start; pfetch; bl RAM_DP; bl STORE
    bl SERIAL_CON
    bl EMULATIONQ; ppop r1; cmp r1, #0; beq 1f
    lit32 eval_words; bl EVALUATE
1:  bl COPY_FARCALL;
    ldr r1, =2f; ppush r1; bl FIND; bl DROP; bl EXECUTE
    b ABORT

2:
    .byte 7
    .ascii "TURNKEY"
    .ltorg

init_here:
    .word here
init_data_start:
    .word data_start
init_last_word:
    .word last_word

    defword "QUIT", QUIT
    lit8 0; bl STATE; bl STORE;
1:  bl INTERPRET
    b 1b

    defword "ABORT", ABORT
    lit32 1f; lit8 34; bl TYPE; bl CR;
    b QUIT
1:
    .ascii "CoreForth revision NNNNNNNN ready."

    defconst "COMPILED-DP", COMPILED_DP, compiled_dp
    defconst "RAM-TOP", RAM_TOP, ram_top
    defconst "ROM-TOP", ROM_TOP, rom_top

    .ltorg

    defconst "R0", R0, ram_top
    defconst "S0", S0, ram_top - 0x200

    defword "DEPTH", DEPTH
    bl S0
    subs r0, PSP
    subs r0, #4
    blt 1f
    lsrs r0, #2
1:  exit

    .ltorg

@ ---------------------------------------------------------------------
@ -- System variables -------------------------------------------------

    defvar "STATE", STATE
    defvar "RAM-DP", RAM_DP
    defvar "ROM-DP", ROM_DP
    defvar "ROM-ACTIVE", ROM_ACTIVE
    defvar "LATEST", LATEST
    defvar "BASE", BASE
    defvar "TIB", TIB, 132
    defvar "(SOURCE)", XSOURCE
    defvar "SOURCE#", SOURCECOUNT
    defvar ">IN", SOURCEINDEX
    defvar "HP", HP
    defvar "\047KEY", TICKKEY
    defvar "\047KEY?", TICKKEYQ
    defvar "\047EMIT", TICKEMIT
    defvar "\047FINISH-OUTPUT", TICKFINISH_OUTPUT
    defvar "FARCALL", FARCALL, 32
    defvar "WORDBUF", WORDBUF, WORDBUF_SIZE

    .ltorg

@ ---------------------------------------------------------------------

    .set last_core_word, link
    .set end_of_core, .

