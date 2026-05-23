const screen = @import("drivers/framebuffer.zig");
const text = @import("drivers/tty.zig");
const Writer = text.Writer;

pub fn kmain() !void {
    var writer: Writer = .{
        .x = 0,
        .y = 0,
        .fg = .red,
        .bg = null,
    };

    try writer.write("Lorem ipsum dolor sit amet...");
}
