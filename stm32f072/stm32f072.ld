OUTPUT_FORMAT("elf32-littlearm", "elf32-bigarm", "elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(reset_handler)

MEMORY
{
    FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 64K
    HOST  (rx) : ORIGIN = 0x08010000, LENGTH = 0x007F0000
    SRAM (rwx) : ORIGIN = 0x20000000, LENGTH = 16K
}

SECTIONS
{
    .target : {
        *(.text)
        *(.rodata)
        compiled_dp = .;
        . = 0x00010000;
    } > FLASH =0xff

    _start = reset_handler;

    .host : {
        *(.host)
    } > HOST

    .data : {
        ram_start = . ;
        *(.data)
        *(.bss)
    } >SRAM AT> FLASH

    ram_top = 0x20000000 + 16K;
    rom_top = 0x08000000 + 64K;
}
