CPU := cortex-m0
ROOT = ../..
ASMFLAGS := -defsym THUMB1=1 \
	-I$(ROOT)/cpus/stm32/stm32f051/ \
	-I$(ROOT)/cpus/stm32/stm32f0/ \
	-I$(ROOT)/cpus/stm32/common/ \
	-I$(ROOT)/generic/

include $(ROOT)/generic/Makefile

OBJS = board.o

board.s: $(ROOT)/generic/CoreForthSE.s

coreforth.elf: $(OBJS)
	arm-none-eabi-ld $(OBJS) -e reset_handler -o $@ -L$(ROOT)/cpus/stm32/stm32f051/ -Tstm32f051x8.ld
	
coreforth.bin: coreforth.elf
	arm-none-eabi-objcopy -Obinary $< $@
	perl -pe "s/revision NNNNNNNN/revision $(REVISION)/" < $@ > $@.bak && mv $@.bak $@
