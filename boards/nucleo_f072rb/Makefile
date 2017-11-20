CPU := cortex-m0
ROOT = ../..
ASMFLAGS := -defsym THUMB1=1 -I$(ROOT)/cpus/stm32/stm32f072/ -I$(ROOT)/cpus/stm32/stm32f0/ -I$(ROOT)/cpus/stm32/common/

include $(ROOT)/generic/Makefile

OBJS = stm32f072_board.o stm32f072_words.o

stm32f030_board.s: $(ROOT)/generic/CoreForthSE.s

coreforth.elf: $(OBJS)
	arm-none-eabi-ld $(OBJS) -e reset_handler -o $@ -Tstm32f072rb.ld
	
coreforth.bin: coreforth.elf
	arm-none-eabi-objcopy -Obinary $< $@
	perl -pe "s/revision NNNNNNNN/revision $(REVISION)/" < $@ > $@.bak && mv $@.bak $@
