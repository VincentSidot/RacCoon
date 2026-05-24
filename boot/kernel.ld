ENTRY(kentry)
_start = kentry;  /* silence LLD's default _start search */

SECTIONS {
    . = 0x8400;  /* stage3.s trampoline occupies 0x8200–0x83FF (512 bytes) */

    .text : {
        KEEP(*(.text.entry))
        *(.text*)
    }

    .rodata : {
        *(.rodata*)
    }

    .data : {
        *(.data*)
    }

    .bss : {
        *(COMMON)
        *(.bss*)
    }

    /DISCARD/ : {
        *(.eh_frame*)
        *(.comment*)
        *(.note*)
    }
}
