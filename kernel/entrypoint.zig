const std = @import("std");
const kpanic = @import("panic.zig");
const screen = @import("drivers/framebuffer.zig");
const arch = @import("arch.zig");
const _kmain = @import("kmain.zig");
const _writer = @import("drivers/tty.zig");
const keyboard = @import("drivers/keyboard.zig");

const Writer = _writer.Writer;
const font = _writer.font;
const idle = arch.idle;
const idt = arch.idt;
const io = arch.io;
const kmain = _kmain.kmain;
const pic = arch.pic;

pub fn panic(
    msg: []const u8,
    error_return_trace: ?*std.builtin.StackTrace,
    error_return_address: ?usize,
) noreturn {
    _ = error_return_trace;
    _ = error_return_address;

    kpanic.onMsg(msg);
}

fn shutdown() noreturn {
    _ = screen.fill(.black) catch {};

    var writer: Writer = .{
        .foreground = .white,
        .y = screen.info.height / 2 - font.height / 2,
    };

    const message = "System halted, ...";

    _ = writer.write(message) catch {};

    idle();
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
    // Initialize the system
    idt.init();
    pic.initKeyboardOnly();

    // Initialize IDT registers
    keyboard.registerKeyboardInterruptHandler();
    kpanic.registerPanicIDTHandlers();

    // Done with initialization, enable interrupts and go to the main kernel code
    io.sti();

    // Main kernel code
    kmain() catch |err| kpanic.onErr(err);

    // Shutdown the system
    shutdown();
}

comptime {
    @export(&kentry, .{
        .name = "kentry",
        .linkage = .strong,
    });
}
