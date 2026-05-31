const std = @import("std");
const kpanic = @import("panic.zig");
const kmain = @import("kmain.zig").kmain;
const halt = @import("arch.zig").halt;
const idt = @import("arch.zig").idt;

pub fn panic(
    msg: []const u8,
    error_return_trace: ?*std.builtin.StackTrace,
    error_return_address: ?usize,
) noreturn {
    _ = error_return_trace;
    _ = error_return_address;

    kpanic.on_msg(msg);
}

/// Zig kernel entry point, called from stage3.s.
///
/// CPU state on entry (guaranteed by stage3):
///   - 64-bit long mode, CS = 0x08
///   - Identity paging for 0–4 GiB
///   - Stack at 0x90000, RSP % 16 = 8  (x86-64 SysV ABI)
///   - FPU and SSE enabled
///   - Interrupts disabled (no IDT yet)
fn kentry() linksection(".text.entry") callconv(.c) noreturn {
    idt.init(); // Enable interrupts
    kmain() catch |err| kpanic.on_err(err);
    halt();
}

comptime {
    @export(&kentry, .{
        .name = "kentry",
        .linkage = .strong,
    });
}
