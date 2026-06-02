
.global __load_idt
__load_idt:
    // Load the IDT
    lidt (%rdi)
    ret

.global __isr0
__isr0: // Divide by zero
    push $0
    push $0
    jmp isr_common

.global __isr6
__isr6: // Invalid opcode
    push $0
    push $6
    jmp isr_common

.global __isr8
__isr8: // Double fault
    push $8
    jmp isr_common

.global __isr13
__isr13: // General protection fault
    push $13
    jmp isr_common

.global __isr14
__isr14: // Page fault
    push $14
    jmp isr_common

.global __isr33
__isr33: // Keyboard interrupt
    push $0
    push $33
    jmp isr_common

isr_common:
    push %rax
    push %rbx
    push %rcx
    push %rdx
    push %rsi
    push %rdi
    push %rbp
    push %r8
    push %r9
    push %r10
    push %r11
    push %r12
    push %r13
    push %r14
    push %r15

    mov %rsp, %rdi
    call zigInterruptDispatch

    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %r11
    pop %r10
    pop %r9
    pop %r8
    pop %rbp
    pop %rdi
    pop %rsi
    pop %rdx
    pop %rcx
    pop %rbx
    pop %rax

    // Remove both rsp values we pushed
    add $16, %rsp
    iretq
