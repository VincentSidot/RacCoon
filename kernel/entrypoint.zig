const std = @import("std");
const kpanic = @import("panic.zig");

pub fn panic(
    msg: []const u8,
    error_return_trace: ?*std.builtin.StackTrace,
    error_return_address: ?usize,
) noreturn {
    _ = error_return_trace;
    _ = error_return_address;

    kpanic.on_msg(msg);
}

comptime {
    _ = @import("arch/x86/entry.zig");
}
