const kmain = @import("../../kmain.zig").kmain;
const panic = @import("../../panic.zig").panic;
const cpu = @import("cpu.zig");

/// x86 protected-mode entry: loads data segments, sets up the stack, and
/// enables FPU/SSE before handing off to kentry.
///
/// Note: since SSE is now active, any future multitasking or interrupt handler
/// code must save and restore FPU/SSE state per task.
fn start() callconv(.naked) noreturn {
    asm volatile (
        \\ cli
        \\ movw $0x10, %ax
        \\ movw %ax, %ds
        \\ movw %ax, %es
        \\ movw %ax, %fs
        \\ movw %ax, %gs
        \\ movw %ax, %ss
        \\ movl $0x90000, %esp
        \\ movl $0x90000, %ebp
        \\
        \\ // Enable FPU/SSE support expected by compiler-generated code
        \\ movl %cr0, %eax
        \\ andl $0xFFFB, %eax    // clear EM
        \\ orl  $0x0002, %eax    // set MP
        \\ movl %eax, %cr0
        \\
        \\ movl %cr4, %eax
        \\ orl  $0x0600, %eax    // OSFXSR | OSXMMEXCPT
        \\ movl %eax, %cr4
        \\ jmp kentry
    );
}

comptime {
    @export(&start, .{
        .name = "_start",
        .linkage = .strong,
        .section = ".text.entry",
    });
}

export fn kentry() callconv(.c) noreturn {
    kmain() catch |err| panic(err);
    cpu.halt();
}
