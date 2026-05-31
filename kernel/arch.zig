const builtin = @import("builtin");

// Define extern assembly functions
extern fn __halt() callconv(.c) noreturn;

// Export thoses functions
pub const halt = __halt;

pub const idt = blk: {
    switch (builtin.cpu.arch) {
        .x86_64 => break :blk @import("arch/x86_64/idt.zig"),
        else => @compileError("Unsupported architecture"),
    }
};
