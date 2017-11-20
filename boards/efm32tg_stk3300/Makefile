CPU := cortex-m0
ASMFLAGS := -defsym THUMB1=1

include ../generic/Makefile

OBJS = efm32_board.o efm32_words.o

efm32__board.s: ../generic/CoreForthSE.s

coreforth.elf: $(OBJS)
	arm-none-eabi-ld $(OBJS) -e reset_handler -o $@ -Tefm32tg.ld
	
coreforth.bin: coreforth.elf
	arm-none-eabi-objcopy -Obinary $< $@
	perl -pe "s/revision NNNNNNNN/revision $(REVISION)/" < $@ > $@.bak && mv $@.bak $@
