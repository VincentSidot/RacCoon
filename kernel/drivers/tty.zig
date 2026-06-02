const screen = @import("framebuffer.zig");
const Color = screen.Color;
const icons = @import("../font/icons.zig");

const glyph_table = @import("../font/font8x8.zig").font8x8_basic;

pub const font = struct {
    pub const width = 8;
    pub const height = 8;
};

pub const Error = error{InvalidCharacter} || screen.Error;

pub const Writer = struct {
    x: usize = 0,
    y: usize = 0,
    foreground: ?Color = .white,
    background: ?Color = null,

    pub fn putchar(self: *Writer, ch: u8) Error!void {
        switch (ch) {
            '\n' => {
                self.x = 0;
                self.y += font.height;
                return;
            },
            '\r' => {
                self.x = 0;
                return;
            },
            else => {},
        }

        try drawchar(self.x, self.y, ch, self.foreground, self.background);

        self.x += font.width;
        if (self.x + font.width > screen.info.width) {
            self.x = 0;
            self.y += font.height;
        }
    }

    pub fn write(self: *Writer, text: []const u8) Error!void {
        for (text) |ch| {
            try self.putchar(ch);
        }
    }
};

pub fn drawSprite(px: usize, py: usize, sprite: icons.Sprite, scale: usize) screen.Error!void {
    const Ctx = struct {
        origin: screen.Point,
        sprite: icons.Sprite,
        scale: usize,

        inline fn call(self: *@This(), p: screen.Point) ?Color {
            const src_x = (p[0] - self.origin[0]) / self.scale;
            const src_y = (p[1] - self.origin[1]) / self.scale;
            const idx = self.sprite.pixels[src_y * self.sprite.width + src_x];
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

pub fn drawchar(px: usize, py: usize, ch: u8, foreground: ?Color, background: ?Color) Error!void {
    if (ch >= 128) return error.InvalidCharacter;

    const Ctx = struct {
        origin: screen.Point,
        glyph: [font.height]u8,
        foreground: ?Color,
        background: ?Color,

        inline fn call(self: *@This(), p: screen.Point) ?Color {
            const col = p[0] - self.origin[0];
            const row = p[1] - self.origin[1];
            const mask: u8 = @as(u8, 1) << @intCast(col);
            return if ((self.glyph[row] & mask) != 0) self.foreground else self.background;
        }
    };

    var ctx: Ctx = .{
        .origin = .{ px, py },
        .glyph = glyph_table[ch],
        .foreground = foreground,
        .background = background,
    };

    try screen.render(Ctx, .{
        .origin = .{ px, py },
        .size = .{ font.width, font.height },
    }, &ctx, Ctx.call);
}
