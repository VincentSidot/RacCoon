const std = @import("std");

const screen = @import("drivers/framebuffer.zig");
const text = @import("drivers/tty.zig");
const icons = @import("font/icons.zig");
const cpu = @import("arch/x86/cpu.zig");

const Color = screen.Color;
const Point = screen.Point;
const Rect = screen.Rect;
const Writer = text.Writer;
const Font = text.Font;

var buffer: [128]u8 = undefined;
const default_message = "Kernel Panic, something went really wrong...";

pub fn on_err(err: anyerror) noreturn {
    render(@errorName(err));
}

pub fn on_msg(msg: []const u8) noreturn {
    render(msg);
}

pub fn unknown() noreturn {
    render("Unknown error");
}

fn render(message: []const u8) noreturn {
    render_ext(message) catch {
        render_simp(message) catch {};
    };

    cpu.halt();
}

fn render_simp(message: []const u8) !void {

    // Kernel panic rendering goes wrong
    try screen.fill(.blue);
    const screen_rect = Rect.screen();

    const msg = std.fmt.bufPrint(
        &buffer,
        "Kernel panic, unable to render error screen: {s}",
        .{message},
    ) catch default_message;

    const msg_pixel = msg.len * Font.width;

    var writer: Writer = .{ .y = screen_rect.size[1] / 2, .x = (screen_rect.size[0] - msg_pixel) / 2 };

    try writer.write(msg);
}

fn render_ext(message: []const u8) !void {
    const W: usize = screen.info.width;
    const H: usize = screen.info.height;

    // Color scheme
    const bg = Color.rgb(14, 14, 24);
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
    const card_orig: Point = .{ W / 2 - card_w / 2, H / 2 - card_h / 2 };

    // Background + top accent bar
    try screen.fill(bg);

    try screen.fill_rect(.{
        .origin = .{ 0, 0 },
        .size = .{ W, 6 },
    }, accent);

    // Card fill
    try screen.fill_rect(.{ .origin = card_orig, .size = .{ card_w, card_h } }, card);

    // Card border
    try screen.fill_rect(.{
        .origin = card_orig,
        .size = .{ card_w, 1 },
    }, border);
    try screen.fill_rect(.{
        .origin = card_orig + @as(@Vector(2, usize), .{ 0, card_h - 1 }),
        .size = .{ card_w, 1 },
    }, border);
    try screen.fill_rect(.{
        .origin = card_orig,
        .size = .{ 1, card_h },
    }, border);
    try screen.fill_rect(.{
        .origin = card_orig + @as(@Vector(2, usize), .{ card_w - 1, 0 }),
        .size = .{ 1, card_h },
    }, border);

    // Raccoon
    try text.drawSprite(card_orig[0] + pad, card_orig[1] + pad, sprite, scale);

    // Text area
    const tx = card_orig[0] + pad + sprite_w + gap;
    var ty = card_orig[1] + pad;

    var title_writer = Writer{ .x = tx, .y = ty, .fg = title, .bg = null };
    try title_writer.write("KERNEL PANIC");
    ty += text.Font.height + 10;

    try screen.fill_rect(.{ .origin = .{ tx, ty }, .size = .{ text_w - pad, 1 } }, border);
    ty += 1 + 14;

    var msg_writer = Writer{ .x = tx, .y = ty, .fg = .white, .bg = null };
    try msg_writer.write("Error message: ");
    msg_writer.fg = .red;
    try msg_writer.write(message);
    ty += text.Font.height + 20;

    var footer_writer = Writer{ .x = tx, .y = ty, .fg = muted, .bg = null };
    try footer_writer.write("System halted.");
}
