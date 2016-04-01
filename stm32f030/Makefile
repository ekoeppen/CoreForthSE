CPU := cortex-m0
ASMFLAGS := -defsym THUMB1=1

include ../generic/Makefile

OBJS = stm32f030_board.o stm32f030_words.o

stm32f030_board.s: ../generic/CoreForthSE.s

coreforth.elf: $(OBJS)
	arm-none-eabi-ld $(OBJS) -o $@ -Tstm32f030.ld
	
coreforth.bin: coreforth.elf
	arm-none-eabi-objcopy -Obinary $< $@
	LC_CTYPE=C && LANG=C && sed -e "s/revision NNNNNNNN/revision $(REVISION)/" < $@ > $@.bak && mv $@.bak $@
