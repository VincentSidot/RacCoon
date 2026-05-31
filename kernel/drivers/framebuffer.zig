const utils = @import("../lib/math.zig");
const clamp = utils.clamp;

const BPP_24: u8 = 24;
const BPP_32: u8 = 32;

const fb_info: *const FrameBufferInfo = @ptrFromInt(0x7000);

pub const info = fb_info;

const FrameBufferInfo = extern struct {
    address: u32,
    pitch: u16,
    width: u16,
    height: u16,
    bpp: u8,
};

pub const Color = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,

    pub const black: Color = .{ .r = 0, .g = 0, .b = 0 };
    pub const white: Color = .{ .r = 255, .g = 255, .b = 255 };
    pub const red: Color = .{ .r = 255, .g = 0, .b = 0 };
    pub const green: Color = .{ .r = 0, .g = 255, .b = 0 };
    pub const blue: Color = .{ .r = 0, .g = 0, .b = 255 };

    fn as_bpp32(self: Color) u32 {
        return (@as(u32, self.r) << 16) |
            (@as(u32, self.g) << 8) |
            @as(u32, self.b);
    }

    fn as_bpp24(self: Color) u24 {
        return (@as(u24, self.r) << 16) | (@as(u24, self.g) << 8) | @as(u24, self.b);
    }

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return Color{ .r = r, .g = g, .b = b };
    }

    pub fn rgbf(r: f32, g: f32, b: f32) Color {
        return Color{
            .r = @intFromFloat(
                clamp(f32, r, 0.0, 1.0) * 255.0,
            ),
            .g = @intFromFloat(
                clamp(f32, g, 0.0, 1.0) * 255.0,
            ),
            .b = @intFromFloat(
                clamp(f32, b, 0.0, 1.0) * 255.0,
            ),
        };
    }
};

pub const Point = @Vector(2, usize);

pub const Rect = struct {
    origin: Point,
    size: Point,

    pub fn contains(self: Rect, p: Point) bool {
        return p[0] >= self.origin[0] and
            p[1] >= self.origin[1] and
            p[0] < self.origin[0] + self.size[0] and
            p[1] < self.origin[1] + self.size[1];
    }

    pub fn screen() Rect {
        return Rect{
            .origin = .{ 0, 0 },
            .size = .{ fb_info.width, fb_info.height },
        };
    }

    pub fn far_corner(self: Rect) Point {
        return self.origin + self.size;
    }
};

fn apply_fn(comptime T: type) type {
    return fn (ctx: *T, p: Point) callconv(.@"inline") ?Color;
}

pub fn render(comptime T: type, rect: Rect, ctx: *T, colorFn: apply_fn(T)) !void {
    const fb_addr: usize = fb_info.address;
    const pitch: usize = fb_info.pitch;
    const bpp: u8 = fb_info.bpp;

    const screen_rect = Rect.screen();
    const rect_far_corner = rect.far_corner();

    if (rect_far_corner[0] > screen_rect.size[0] or
        rect_far_corner[1] > screen_rect.size[1])
    {
        return error.OutOfBounds;
    }

    const x = rect.origin[0];
    const y = rect.origin[1];

    switch (bpp) {
        BPP_24 => {
            var offset = y * pitch + x * 3;
            var dy: usize = y;
            while (dy < rect_far_corner[1]) : (dy += 1) {
                var dx: usize = x;
                while (dx < rect_far_corner[0]) : (dx += 1) {
                    if (colorFn(ctx, .{ dx, dy })) |color| {
                        const p: [*]volatile u8 = @ptrFromInt(fb_addr + offset);
                        p[0] = color.b;
                        p[1] = color.g;
                        p[2] = color.r;
                    }

                    // Advance offset
                    offset += 3;
                }

                // Move to next row
                offset += pitch - (rect_far_corner[0] - x) * 3;
            }
        },
        BPP_32 => {
            var offset = y * pitch + x * 4;

            var dy: usize = y;
            while (dy < rect_far_corner[1]) : (dy += 1) {
                var dx: usize = x;
                while (dx < rect_far_corner[0]) : (dx += 1) {
                    if (colorFn(ctx, .{ dx, dy })) |color| {
                        const p: *volatile u32 = @ptrFromInt(fb_addr + offset);
                        p.* = color.as_bpp32();
                    }

                    // Advance offset
                    offset += 4;
                }

                // Move to next row
                offset += pitch - (rect_far_corner[0] - x) * 4;
            }
        },
        else => return error.UnsupportedBPP,
    }
}

pub fn set(x: usize, y: usize, color: Color) !void {
    const Ctx = struct {
        _color: Color,

        inline fn call(self: *@This(), p: Point) ?Color {
            _ = p;
            return self._color;
        }
    };

    var ctx: Ctx = .{ ._color = color };

    try render(Ctx, .{
        .origin = .{ x, y },
        .size = .{ 1, 1 },
    }, &ctx, Ctx.call);
}

pub fn fill_rect(rect: Rect, color: Color) !void {
    const P = struct {
        const Self = @This();
        _color: Color,

        inline fn call(self: *Self, p: Point) ?Color {
            _ = p;
            return self._color;
        }
    };

    var p: P = .{ ._color = color };

    try render(P, rect, &p, P.call);
}

pub fn fill(color: Color) !void {
    try fill_rect(Rect.screen(), color);
}
