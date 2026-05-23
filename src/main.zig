const std = @import("std");
const screen = @import("screen.zig");
const text = @import("text.zig");

const Color = screen.Color;
const Writer = text.Writer;

fn kmain() !void {
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

    var writer: Writer = .{};

    try writer.write("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam lacus urna, tincidunt vitae mollis eget, lacinia eget turpis. Ut lacus dolor, bibendum a tincidunt ac, maximus finibus nunc. Vivamus posuere euismod augue, vel cursus magna vulputate quis. Proin lectus neque, mollis at mauris eget, suscipit feugiat libero. Aenean sed accumsan elit. Ut congue, enim vitae efficitur interdum, lacus leo feugiat ante, quis eleifend dui sem a magna. Proin sit amet ullamcorper nibh. Proin ultrices tincidunt dignissim. In hac habitasse platea dictumst. Suspendisse blandit iaculis porttitor. Sed at egestas ipsum, vitae pulvinar orci. Vestibulum et facilisis nisi. Mauris iaculis diam nec mauris commodo vestibulum. Phasellus hendrerit consectetur ipsum, sit amet mollis lacus dictum ut. ");
}

export fn kentry() callconv(.c) noreturn {
    // Call the main function
    kmain() catch |err| {
        panic(err);
    };

    halt();
}

fn start() callconv(.naked) noreturn {
    asm volatile (
        \\cli
        \\movw $0x10, %ax
        \\movw %ax, %ds
        \\movw %ax, %es
        \\movw %ax, %fs
        \\movw %ax, %gs
        \\movw %ax, %ss
        \\movl $0x90000, %esp
        \\movl $0x90000, %ebp
        \\jmp kentry
    );
}

comptime {
    @export(&start, .{
        .name = "_start",
        .linkage = .strong,
        .section = ".text.entry",
    });
}

fn panic(err: ?anyerror) noreturn {
    // Setup text content
    var buffer: [512]u8 = undefined;
    const undefined_panic_message = "Kernel panic: unrecoverable error occurred";

    var panic_message: []const u8 = undefined_panic_message;

    if (err) |e| {
        panic_message = std.fmt.bufPrint(
            &buffer,
            "Kernel panic: unrecoverable error occurred: '{s}'",
            .{@errorName(e)},
        ) catch undefined_panic_message;
    }

    bscreen(panic_message);
}

fn bscreen(message: []const u8) noreturn {
    // Blue screen
    screen.fill(.blue) catch {};

    // Setup text content
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

    halt();
}

fn halt() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
