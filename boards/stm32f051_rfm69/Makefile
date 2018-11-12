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
	thumbulator -o $@ -d $@ -m 00010000 \
		-d ../../generic/mecrisp-compat.ft \
		-d ../../cpus/stm32/stm32f051/rcc.fs \
		-d ../../cpus/stm32/stm32f051/io.fs \
		-d ../../cpus/stm32/stm32f051/hal.fs \
		-d ../../cpus/stm32/stm32f051/pwr.ft \
		-d ../../cpus/stm32/stm32f051/spi.fs \
		-d ../../generic/systick.ft \
		-d ../../generic/multitasking.ft \
		-d board.ft \
		-d ../../generic/rom-dump.ft
	perl -pe "s/revision NNNNNNNN/revision $(REVISION)/" < $@ > $@.bak && mv $@.bak $@
