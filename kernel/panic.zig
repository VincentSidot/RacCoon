const std = @import("std");
const screen = @import("drivers/framebuffer.zig");
const text = @import("drivers/tty.zig");
const cpu = @import("arch/x86/cpu.zig");

const Writer = text.Writer;

pub fn panic(err: ?anyerror) noreturn {
    var buffer: [512]u8 = undefined;
    const fallback = "Kernel panic: unrecoverable error occurred";

    const message = if (err) |e|
        std.fmt.bufPrint(
            &buffer,
            "Kernel panic: unrecoverable error occurred: '{s}'",
            .{@errorName(e)},
        ) catch fallback
    else
        fallback;

    bscreen(message);
}

fn bscreen(message: []const u8) noreturn {
    screen.fill(.blue) catch {};

    const message_width_px = text.Font.width * message.len;
    const x = if (message_width_px < screen.info.width)
        screen.info.width / 2 - message_width_px / 2
    else
        0;

    var writer = Writer{
        .x = x,
        .y = screen.info.height / 2 - text.Font.height / 2,
        .bg = null,
    };

    writer.write(message) catch {};

    cpu.halt();
}
