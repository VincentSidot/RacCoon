const builtin = @import("builtin");

// Define extern assembly functions
extern fn __halt() callconv(.c) noreturn;
extern fn __idle() callconv(.c) noreturn;

// Export thoses functions
pub const halt = __halt;
pub const idle = __idle;

const arch = switch (builtin.cpu.arch) {
    .x86_64 => struct {
        pub const idt = @import("arch/x86_64/idt.zig");
        pub const io = @import("arch/x86_64/io.zig");
        pub const pic = @import("arch/x86_64/pic.zig");
    },
    else => @compileError("Unsupported architecture"),
};

pub const idt = arch.idt;
pub const io = arch.io;
pub const pic = arch.pic;
