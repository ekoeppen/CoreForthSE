CPU := cortex-m3
ASMFLAGS := 

include ../generic/Makefile

OBJS = stm32f103_board.o stm32f103_words.o

stm32f103__board.s: ../generic/CoreForthSE.s

stamp:
	LC_CTYPE=C && LANG=C && sed -e "s/revision NNNNNNNN/revision $(REVISION)/" < $@ > $@.bak && mv $@.bak $@

coreforth.elf: $(OBJS)
	arm-none-eabi-ld $(OBJS) -o $@ -Tstm32f103x8.ld
	
coreforth.bin: coreforth.elf
	arm-none-eabi-objcopy -Obinary $< $@
