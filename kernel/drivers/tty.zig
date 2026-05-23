const screen = @import("framebuffer.zig");
const Color = screen.Color;

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

    pub fn putChar(self: *Writer, ch: u8) !void {
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

        try drawChar(self.x, self.y, ch, self.fg, self.bg);

        self.x += Font.width;
        if (self.x + Font.width > screen.info.width) {
            self.x = 0;
            self.y += Font.height;
        }
    }

    pub fn write(self: *Writer, text: []const u8) !void {
        for (text) |ch| {
            try self.putChar(ch);
        }
    }
};

pub fn drawChar(px: usize, py: usize, ch: u8, fg: ?Color, bg: ?Color) !void {
    if (ch >= 128) {
        return error.InvalidCharacter;
    }

    const glyph: [8]u8 = glyph_table[ch];

    var dy: u8 = 0;
    while (dy < Font.height) : (dy += 1) {
        const row: u8 = glyph[dy];

        var dx: u8 = 0;
        while (dx < Font.width) : (dx += 1) {
            const mask: u8 = @as(u8, 1) << @intCast(dx);
            const maybe_color: ?Color = if ((row & mask) != 0) fg else bg;

            if (maybe_color) |color| {
                try screen.set(
                    px + @as(usize, dx),
                    py + @as(usize, dy),
                    color,
                );
            }
        }
    }
}
