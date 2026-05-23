ENTRY(_start)

SECTIONS {
    . = 0x8000;

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
