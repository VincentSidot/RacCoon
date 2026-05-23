const std = @import("std");
const screen = @import("drivers/framebuffer.zig");
const text = @import("drivers/tty.zig");

const Color = screen.Color;
const Writer = text.Writer;

fn debugWriter(writer: *const Writer) !void {
    if (writer.x != 0) return error.BadX;
    if (writer.y != 0) return error.BadY;

    if (writer.fg == null) return error.FgNull;
    if (writer.bg != null) return error.BgNotNull;

    if (writer.fg) |fg| {
        if (fg.b != 0) return error.FgBlueNotZero;
        if (fg.g != 0) return error.FgGreenNotZero;
        if (fg.r != 255) return error.FgRedNot255;
    }
}

fn kmain() !void {
    // const width: usize = screen.info.width;
    // const height: usize = screen.info.height;

    // var y: usize = 0;
    // while (y < height) : (y += 1) {
    //     var x: usize = 0;
    //     while (x < width) : (x += 1) {
    //         try screen.set(x, y, .{
    //             .r = @intCast((x * 255) / width),
    //             .g = @intCast((y * 255) / height),
    //             .b = 64,
    //         });
    //     }
    // }

    var writer: Writer = .{
        .x = 0,
        .y = 0,
        .fg = .red,
        .bg = null,
    };

    try debugWriter(&writer);

    writer.write("Lorem ipsum dolor sit amet...") catch |err| {
        bscreen(@errorName(err));
    };
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
        \\ cli
        \\ movw $0x10, %ax
        \\ movw %ax, %ds
        \\ movw %ax, %es
        \\ movw %ax, %fs
        \\ movw %ax, %gs
        \\ movw %ax, %ss
        \\ movl $0x90000, %esp
        \\ movl $0x90000, %ebp
        \\
        \\ // Enable FPU/SSE support expected by compiler-generated code
        \\ movl %cr0, %eax
        \\ andl $0xFFFB, %eax    // clear EM
        \\ orl  $0x0002, %eax    // set MP
        \\ movl %eax, %cr0
        \\
        \\ movl %cr4, %eax
        \\ orl  $0x0600, %eax    // OSFXSR | OSXMMEXCPT
        \\ movl %eax, %cr4
        \\ jmp kentry
    );
    // Note: as SSE is enabled, later code that use multitasking, interrupts or FPU must save and restore FPU/SSE state per task.
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
