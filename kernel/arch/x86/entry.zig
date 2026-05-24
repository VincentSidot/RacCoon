const kmain = @import("../../kmain.zig").kmain;
const kpanic = @import("../../panic.zig");
const cpu = @import("cpu.zig");

/// Zig kernel entry point, called from stage3.s.
///
/// CPU state on entry (guaranteed by stage3):
///   - 64-bit long mode, CS = 0x08
///   - Identity paging for 0–4 GiB
///   - Stack at 0x90000, RSP % 16 = 8  (x86-64 SysV ABI)
///   - FPU and SSE enabled
///   - Interrupts disabled (no IDT yet)
fn kentry() linksection(".text.entry") callconv(.c) noreturn {
    kmain() catch |err| kpanic.on_err(err);
    cpu.halt();
}

comptime {
    @export(&kentry, .{
        .name = "kentry",
        .linkage = .strong,
    });
}
