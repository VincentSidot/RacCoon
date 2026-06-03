test {
    const std = @import("std");

    std.testing.refAllDecls(@import("data/ring_buffer.zig"));
    std.testing.refAllDecls(@import("data/spsc.zig"));
}
