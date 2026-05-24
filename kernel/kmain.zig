const std = @import("std");
const screen = @import("drivers/framebuffer.zig");
const text = @import("drivers/tty.zig");
const Writer = text.Writer;

pub fn kmain() !void {
    var buffer: [512]u8 = undefined;

    const message = try std.fmt.bufPrint(&buffer,
        \\ > Welcome...
        \\ > Fetching system information...
        \\ > Screen size: {d}x{d}
        \\ > BPP: {d}
        \\ > Framebuffer address: 0x{x}
    , .{ screen.info.width, screen.info.height, screen.info.bpp, screen.info.address });

    try screen.fill(.{ .r = 0x90, .g = 0xD5, .b = 0xFF });
    var writer: Writer = .{
        .fg = .{
            .r = 0x16,
            .g = 0x16,
            .b = 0x16,
        },
        .y = 16,
    };

    try writer.write(message);

    // const bad_ptr: *const u8 = @ptrFromInt(0x01);

    // var bad_value: u8 = bad_ptr.*;

    // while (bad_value > 0) : (bad_value -= 1) {
    //     try writer.write("Uzu\n");
    // }
}
