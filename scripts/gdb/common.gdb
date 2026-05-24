set pagination off
set confirm off
set disassembly-flavor intel

# ── Architecture helpers ──────────────────────────────────────────────────────
define mode16
    set architecture i8086
    printf "[gdb] 16-bit real mode\n"
end
document mode16
Switch GDB to 16-bit real-mode disassembly.
end

define mode32
    set architecture i386
    printf "[gdb] 32-bit protected mode\n"
end
document mode32
Switch GDB to 32-bit protected-mode disassembly.
end

define mode64
    set architecture i386:x86-64
    printf "[gdb] 64-bit long mode\n"
end
document mode64
Switch GDB to 64-bit long-mode disassembly.
end

# ── Register dumps ────────────────────────────────────────────────────────────
define regs16
    info registers ax bx cx dx si di bp sp cs ds es ss ip eflags
end
document regs16
Print 16-bit real-mode registers.
end

define regs32
    info registers eax ebx ecx edx esi edi ebp esp cs ds es ss eip eflags
end
document regs32
Print 32-bit protected-mode registers.
end

define regs64
    info registers rax rbx rcx rdx rsi rdi rbp rsp cs ss rip eflags
end
document regs64
Print 64-bit long-mode registers.
end

# ── Instruction views ─────────────────────────────────────────────────────────
define xip16
    x/12i ($cs * 16 + $pc)
end
document xip16
Disassemble 12 instructions at CS:IP (real mode).
end

define xip32
    x/12i $eip
end
document xip32
Disassemble 12 instructions at EIP.
end

define xip64
    x/12i $rip
end
document xip64
Disassemble 12 instructions at RIP.
end
