CPU ?= cortex-m3

REVISION := $(shell git log -1 --abbrev=8 --pretty=format:%h)

%.bin: %.elf
	perl -pe "s/revision NNNNNNNN/revision $(REVISION)/" < $< > $<.bak && mv $<.bak $<
	arm-none-eabi-objcopy -Obinary $< $@

%.lst: %.elf
	arm-none-eabi-objdump -D $< >$@

.s.o:
	arm-none-eabi-as -gdwarf2 $(ASMFLAGS) -mcpu=$(CPU) -I../generic/ -o $@ $<

all: coreforth.bin coreforth.lst

listing: coreforth.lst

coreforth.bin: coreforth.elf

clean:
	rm -f *.elf *.bin *.o *.gen.s *.log *.lst
