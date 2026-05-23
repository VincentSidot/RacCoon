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

pub fn set(x: usize, y: usize, color: Color) !void {
    const fb_addr: usize = fb_info.address;
    const pitch: usize = fb_info.pitch;
    const width: usize = fb_info.width;
    const height: usize = fb_info.height;
    const bpp: u8 = fb_info.bpp;

    if (x >= width or y >= height) {
        return error.OutOfBounds;
    }

    switch (bpp) {
        BPP_24 => {
            const offset = y * pitch + x * 3;
            const p: [*]volatile u8 = @ptrFromInt(fb_addr + offset);

            p[0] = color.b;
            p[1] = color.g;
            p[2] = color.r;
        },
        BPP_32 => {
            const offset = y * pitch + x * 4;
            const p: *volatile u32 = @ptrFromInt(fb_addr + offset);

            p.* = color.as_bpp32();
        },
        else => return error.UnsupportedBPP,
    }
}

pub fn fill(color: Color) !void {
    const fb_addr: usize = fb_info.address;
    const width: usize = fb_info.width;
    const height: usize = fb_info.height;
    const pitch: usize = fb_info.pitch;
    const bpp: u8 = fb_info.bpp;

    switch (bpp) {
        BPP_24 => {
            const fb: [*]volatile u8 = @ptrFromInt(fb_addr);

            var y: usize = 0;
            while (y < height) : (y += 1) {
                const row = y * pitch;

                var x: usize = 0;
                while (x < width) : (x += 1) {
                    const off = row + x * 3;

                    fb[off + 0] = color.b;
                    fb[off + 1] = color.g;
                    fb[off + 2] = color.r;
                }
            }
        },
        BPP_32 => {
            const fb: [*]volatile u8 = @ptrFromInt(fb_addr);

            var y: usize = 0;
            while (y < height) : (y += 1) {
                const row = y * pitch;

                var x: usize = 0;
                while (x < width) : (x += 1) {
                    const off = row + x * 4;

                    fb[off + 0] = color.b;
                    fb[off + 1] = color.g;
                    fb[off + 2] = color.r;
                    fb[off + 3] = 0;
                }
            }
        },
        else => return error.UnsupportedBPP,
    }
}
