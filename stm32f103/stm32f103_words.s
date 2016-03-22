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

    defword "COLD", COLD
    b .

    .set last_word, link
    .set last_host, link_host
    .set data_start, ram_here
    .set here, .

