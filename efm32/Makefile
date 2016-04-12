CPU := cortex-m0
ASMFLAGS := -defsym THUMB1=1

include ../generic/Makefile

OBJS = efm32_board.o efm32_words.o

efm32__board.s: ../generic/CoreForthSE.s

stamp:
	LC_CTYPE=C && LANG=C && sed -e "s/revision NNNNNNNN/revision $(REVISION)/" < $@ > $@.bak && mv $@.bak $@

coreforth.elf: $(OBJS)
	arm-none-eabi-ld $(OBJS) -o $@ -Tefm32hg.ld
	arm-none-eabi-size $@ 
	
coreforth.bin: coreforth.elf
	arm-none-eabi-objcopy -Obinary $< $@
