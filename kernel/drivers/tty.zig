const screen = @import("framebuffer.zig");
const Color = screen.Color;
const icons = @import("../font/icons.zig");

const glyph_table = @import("../font/font8x8.zig").font8x8_basic;

pub const Font = struct {
    pub const width = 8;
    pub const height = 8;
};

pub const Writer = struct {
    x: usize = 0,
    y: usize = 0,
    fg: ?Color = .white,
    bg: ?Color = null,

    pub fn putchar(self: *Writer, ch: u8) !void {
        switch (ch) {
            '\n' => {
                self.x = 0;
                self.y += Font.height;
                return;
            },
            '\r' => {
                self.x = 0;
                return;
            },
            else => {},
        }

        try drawchar(self.x, self.y, ch, self.fg, self.bg);

        self.x += Font.width;
        if (self.x + Font.width > screen.info.width) {
            self.x = 0;
            self.y += Font.height;
        }
    }

    pub fn write(self: *Writer, text: []const u8) !void {
        for (text) |ch| {
            try self.putchar(ch);
        }
    }
};

pub fn draw_sprite(px: usize, py: usize, sprite: icons.Sprite, scale: usize) !void {
    const Ctx = struct {
        origin: screen.Point,
        sprite: icons.Sprite,
        scale: usize,

        inline fn call(self: *@This(), p: screen.Point) ?Color {
            const sx = (p[0] - self.origin[0]) / self.scale;
            const sy = (p[1] - self.origin[1]) / self.scale;
            const idx = self.sprite.pixels[sy * self.sprite.width + sx];
            if (idx == icons.transparent) return null;
            return self.sprite.palette[idx];
        }
    };

    var ctx: Ctx = .{
        .origin = .{ px, py },
        .sprite = sprite,
        .scale = scale,
    };

    try screen.render(Ctx, .{
        .origin = .{ px, py },
        .size = .{ sprite.width * scale, sprite.height * scale },
    }, &ctx, Ctx.call);
}

pub fn drawchar(px: usize, py: usize, ch: u8, fg: ?Color, bg: ?Color) !void {
    if (ch >= 128) return error.InvalidCharacter;

    const Ctx = struct {
        origin: screen.Point,
        glyph: [Font.height]u8,
        fg: ?Color,
        bg: ?Color,

        inline fn call(self: *@This(), p: screen.Point) ?Color {
            const dx = p[0] - self.origin[0];
            const dy = p[1] - self.origin[1];
            const mask: u8 = @as(u8, 1) << @intCast(dx);
            return if ((self.glyph[dy] & mask) != 0) self.fg else self.bg;
        }
    };

    var ctx: Ctx = .{
        .origin = .{ px, py },
        .glyph = glyph_table[ch],
        .fg = fg,
        .bg = bg,
    };

    try screen.render(Ctx, .{
        .origin = .{ px, py },
        .size = .{ Font.width, Font.height },
    }, &ctx, Ctx.call);
}
