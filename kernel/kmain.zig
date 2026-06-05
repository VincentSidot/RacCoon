const screen = @import("drivers/framebuffer.zig");
const text = @import("drivers/tty.zig");
const keyboard = @import("drivers/keyboard.zig");
const tformat = @import("lib/temp_string.zig").tformat;

const Writer = text.Writer;

pub fn kmain() (error{NoSpaceLeft} || text.Error)!void {
    const bg_color: screen.Color = .{ .r = 0x90, .g = 0xD5, .b = 0xFF };
    const tx_color: screen.Color = .{ .r = 0x16, .g = 0x16, .b = 0x16 };

    const message = try tformat(
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

    var should_quit: bool = false;
    while (!should_quit) {
        const event = keyboard.readRawEvent() orelse continue;

        if (keyboard.convertKeycodeToChar(event)) |char| {
            if (char == 'c' and event.modifiers.ctrl) {
                should_quit = true;
                continue;
            }

            _ = try writer.putchar(char);
        }

        // const maybe_char = keyboard.readCharEvent();

        // if (maybe_char) |char| {
        //     _ = try writer.putchar(char);
        // }
    }
}
