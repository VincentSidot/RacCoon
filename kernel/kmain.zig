const std = @import("std");
const screen = @import("drivers/framebuffer.zig");
const text = @import("drivers/tty.zig");
const keyboard = @import("drivers/keyboard.zig");

const Writer = text.Writer;

pub fn kmain() (error{NoSpaceLeft} || text.Error)!void {
    const bg_color: screen.Color = .{ .r = 0x90, .g = 0xD5, .b = 0xFF };
    const tx_color: screen.Color = .{ .r = 0x16, .g = 0x16, .b = 0x16 };

    var buffer: [512]u8 = undefined;

    const message = try std.fmt.bufPrint(&buffer,
        \\ > Welcome...
        \\ > Fetching system information...
        \\ > Screen size: {d}x{d}
        \\ > BPP: {d}
        \\ > Framebuffer address: 0x{x}
        \\ >
    , .{ screen.info.width, screen.info.height, screen.info.bpp, screen.info.address });

    try screen.fill(bg_color);
    var writer: Writer = .{
        .foreground = tx_color,
        .y = 18,
    };

    try writer.write(message);

    while (true) {
        const maybe_char = keyboard.readCharEvent();

        if (maybe_char) |char| {
            _ = try writer.putchar(char);
        }
    }
}
