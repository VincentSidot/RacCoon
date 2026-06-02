const std = @import("std");
const kpanic = @import("panic.zig");
const idle = @import("arch.zig").idle;
const idt = @import("arch.zig").idt;
const io = @import("arch.zig").io;
const kmain = @import("kmain.zig").kmain;
const pic = @import("arch.zig").pic;

pub fn panic(
    msg: []const u8,
    error_return_trace: ?*std.builtin.StackTrace,
    error_return_address: ?usize,
) noreturn {
    _ = error_return_trace;
    _ = error_return_address;

    kpanic.onMsg(msg);
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
    idt.init();
    pic.initKeyboardOnly();
    io.sti();

    kmain() catch |err| kpanic.onErr(err);
    idle();
}

comptime {
    @export(&kentry, .{
        .name = "kentry",
        .linkage = .strong,
    });
}
