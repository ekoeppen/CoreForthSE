@ -- vim:syntax=asm:foldmethod=marker:foldmarker=@\ --\ ,@\ ---:

@ ---------------------------------------------------------------------
@ -- Definitions ------------------------------------------------------

    .include "efm32_definitions.s"

@ ---------------------------------------------------------------------
@ -- Interrupt vectors ------------------------------------------------

    .text
    .syntax unified
    .code 16

    .global _start
    .global putchar
    .global init_board
    .global readkey
    .global reset_handler
_start:
    .long addr_TASKZTOS               /* Top of Stack                 */
    .long reset_handler + 1           /* Reset Handler                */
    .long nmi_handler + 1             /* NMI Handler                  */
    .long hardfault_handler + 1       /* Hard Fault Handler           */
    .long memmanage_handler + 1       /* MPU Fault Handler            */
    .long busfault_handler + 1        /* Bus Fault Handler            */
    .long usagefault_handler + 1      /* Usage Fault Handler          */
    .long 0                           /* Reserved                     */
    .long 0                           /* Reserved                     */
    .long 0                           /* Reserved                     */
    .long 0                           /* Reserved                     */
    .long svc_handler + 1             /* SVCall Handler               */
    .long debugmon_handler + 1        /* Debug Monitor Handler        */
    .long 0                           /* Reserved                     */
    .long pendsv_handler + 1          /* PendSV Handler               */
    .long systick_handler + 1         /* SysTick Handler              */
end_of_irq:

    .org 0x150

@ ---------------------------------------------------------------------
@ -- Board specific code and initialization ---------------------------

init_board:
    ldr r0, =CPUID
    ldr r0, [r0]
    cmp r0, #0
    bne 3f
    bx lr
3:  push {lr}

    @ enable SYSTICK
    ldr r0, =STRELOAD
    ldr r1, =0x00ffffff
    str r1, [r0]
    ldr r0, =STCTRL
    movs r1, #5
    str r1, [r0]

    @ enable USART1
    ldr r0, =CMU_HFPERCLKEN0
    ldr r1, =#0x110
    str r1, [r0]
    ldr r0, =USART1_CMD
    ldr r1, =#0xc05
    str r1, [r0]
    ldr r0, =USART1_ROUTE
    movs r1, #3
    str r1, [r0]
    ldr r0, =USART1_CLKDIV
    ldr r1, =0x698
    str r1, [r0]
    ldr r0, =GPIO_PC_MODEL
    ldr r1, [r0]
    ldr r2, =0xffffff00
    ands r1, r2
    movs r2, #0x14
    orrs r1, r2
    str r1, [r0]

    pop {pc}
    .ltorg

readkey:
    ldr r0, =CPUID
    ldr r0, [r0]
    cmp r0, #0
    bne 2f
    ldr r0, =EMULATOR_UART
    ldr r0, [r0]
    bx lr
2:  push {r1, r2}
    ldr r1, =USART1
    movs r0, #0x80
1:  ldr r2, [r1, #USART_STATUS]
    ands r2, r0
    beq 1b
    ldrb r0, [r1, #USART_RXDATA]
    pop {r1, r2}
    bx lr

putchar:
    push {r1, r2, r3}
    ldr r1, =CPUID
    ldr r1, [r1]
    cmp r1, #0
    bne 1f
    ldr r1, =EMULATOR_UART
    str r0, [r1]
    b 2f
1:  ldr r1, =USART1
    movs r3, #0x40
3:  ldr r2, [r1, #USART_STATUS]
    ands r2, r3
    beq 3b
    str r0, [r1, #USART_TXDATA]
2:  pop {r1, r2, r3}
    bx lr

@ ---------------------------------------------------------------------
@ -- IRQ handlers -----------------------------------------------------

@ Generic handler which checks if a Forth word is defined to handle the
@ IRQ. If not, this handler will simply return. Note that this will
@ usually lock up the system as the interrupt will be retriggered, the
@ generic handler is not clearing the interrupt.

generic_forth_handler:
    b .

nmi_handler:
    b .

hardfault_handler:
    @tst lr, #4
    @ite eq
    @mrseq r0, msp
    @mrsne r0, psp
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
    b generic_forth_handler

