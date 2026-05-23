const screen = @import("screen.zig");
const Color = screen.Color;

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
}

export fn _start() callconv(.c) noreturn {
    // Set up segment registers and stack pointer for protected mode
    asm volatile (
        \\movw $0x10, %ax
        \\movw %ax, %ds
        \\movw %ax, %es
        \\movw %ax, %fs
        \\movw %ax, %gs
        \\movw %ax, %ss
        \\movl $0x90000, %esp
    );

    // Call the main function
    kmain() catch {
        panic();
    };

    halt();
}

fn panic() noreturn {
    screen.fill(.{ .b = 255, .g = 0, .r = 0 }) catch {}; // Who care's if fill screen fails, we're panicking anyway
    halt();
}

fn halt() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
