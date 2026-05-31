
.global __outb
__outb:
    movw %di, %dx
    movb %sil, %al
    outb %al, %dx
    ret

.global __inb
__inb:
    movw %di, %dx
    inb %dx, %al
    ret

.global __sti
__sti:
    sti
    ret
