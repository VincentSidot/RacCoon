const screen = @import("drivers/framebuffer.zig");
const text = @import("drivers/tty.zig");
const Writer = text.Writer;

pub fn kmain() !void {

    // Let's draw a gradient on screen
    const width: usize = screen.info.width;
    const height: usize = screen.info.height;

    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            try screen.set(x, y, .{
                .r = @intCast((x * 255) / width),
                .g = @intCast((y * 255) / height),
                .b = 64,
            });
        }
    }

    var writer: Writer = .{
        .x = 0,
        .y = 0,
        .fg = .red,
        .bg = null,
    };

    try writer.write("Lorem ipsum dolor sit amet...");
}
