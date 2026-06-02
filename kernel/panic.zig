const std = @import("std");

const screen = @import("drivers/framebuffer.zig");
const text = @import("drivers/tty.zig");
const icons = @import("font/icons.zig");
const halt = @import("arch.zig").halt;

const Color = screen.Color;
const Point = screen.Point;
const Rect = screen.Rect;
const Writer = text.Writer;
const font = text.font;

var buffer: [128]u8 = undefined;
const default_message = "Kernel Panic, something went really wrong...";

pub fn onErr(err: anyerror) noreturn {
    render(@errorName(err), null);
}

pub fn onMsg(name: []const u8) noreturn {
    render(name, null);
}

pub fn onMsgExt(name: []const u8, message: ?[]const u8) noreturn {
    render(name, message);
}

pub fn unknown() noreturn {
    render("Unknown error", null);
}

fn render(name: []const u8, message: ?[]const u8) noreturn {
    renderExt(name, message) catch {
        renderSimp(name, message) catch {};
    };

    halt();
}

fn renderSimp(name: []const u8, message: ?[]const u8) !void {

    // Kernel panic rendering goes wrong
    try screen.fill(.blue);
    const screen_rect = Rect.screen();

    const msg = std.fmt.bufPrint(
        &buffer,
        "Kernel panic, unable to render error screen: {s}",
        .{name},
    ) catch default_message;

    var msg_pixel = msg.len * font.width;

    var writer: Writer = .{ .y = screen_rect.size[1] / 2, .x = (screen_rect.size[0] - msg_pixel) / 2 };
    try writer.write(msg);

    if (message) |msg2| {
        msg_pixel = msg2.len * font.width;
        writer.y += font.height + 20;
        writer.x = (screen_rect.size[0] - msg_pixel) / 2;
        try writer.write(msg2);
    }
}

fn renderExt(name: []const u8, message: ?[]const u8) !void {
    const screen_w: usize = screen.info.width;
    const screen_h: usize = screen.info.height;

    // Color scheme
    const background = Color.rgb(14, 14, 24);
    const accent = Color.rgb(200, 40, 40);
    const card = Color.rgb(24, 24, 40);
    const border = Color.rgb(70, 70, 110);
    const title = Color.rgb(230, 70, 70);
    const muted = Color.rgb(130, 130, 160);

    // Sprite
    const sprite = icons.raccoon;
    const scale: usize = 2;
    const sprite_w = sprite.width * scale;
    const sprite_h = sprite.height * scale;

    // Card layout
    const pad: usize = 28;
    const gap: usize = 32;
    const text_w: usize = 300;

    const card_w = pad + sprite_w + gap + text_w + pad;
    const card_h = pad + sprite_h + pad;
    const card_orig: Point = .{ screen_w / 2 - card_w / 2, screen_h / 2 - card_h / 2 };

    // Background + top accent bar
    try screen.fill(background);

    try screen.fillRect(.{
        .origin = .{ 0, 0 },
        .size = .{ screen_w, 6 },
    }, accent);

    // Card fill
    try screen.fillRect(.{ .origin = card_orig, .size = .{ card_w, card_h } }, card);

    // Card border
    try screen.fillRect(.{
        .origin = card_orig,
        .size = .{ card_w, 1 },
    }, border);
    try screen.fillRect(.{
        .origin = card_orig + @as(@Vector(2, usize), .{ 0, card_h - 1 }),
        .size = .{ card_w, 1 },
    }, border);
    try screen.fillRect(.{
        .origin = card_orig,
        .size = .{ 1, card_h },
    }, border);
    try screen.fillRect(.{
        .origin = card_orig + @as(@Vector(2, usize), .{ card_w - 1, 0 }),
        .size = .{ 1, card_h },
    }, border);

    // Raccoon
    try text.drawSprite(card_orig[0] + pad, card_orig[1] + pad, sprite, scale);

    // Text area
    const text_x = card_orig[0] + pad + sprite_w + gap;
    var text_y = card_orig[1] + pad;

    var title_writer = Writer{ .x = text_x, .y = text_y, .foreground = title, .background = null };
    try title_writer.write("KERNEL PANIC");
    text_y += text.font.height + 10;

    try screen.fillRect(.{ .origin = .{ text_x, text_y }, .size = .{ text_w - pad, 1 } }, border);
    text_y += 1 + 14;

    var msg_writer = Writer{ .x = text_x, .y = text_y, .foreground = .white, .background = null };
    try msg_writer.write("Error message: ");
    msg_writer.foreground = .red;
    try msg_writer.write(name);
    text_y += text.font.height + 20;

    if (message) |msg| {
        msg_writer.x = text_x;
        msg_writer.y += text.font.height + 20;
        msg_writer.foreground = muted;
        try msg_writer.write(msg);
        text_y += text.font.height + 20;
    }

    var footer_writer = Writer{ .x = text_x, .y = text_y, .foreground = muted, .background = null };
    try footer_writer.write("System halted.");
}
