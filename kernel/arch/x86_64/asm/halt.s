// Halt the CPU indefinitely.
.global __halt
__halt:
    cli
    hlt
    jmp __halt
