const screen = @import("drivers/framebuffer.zig");
const text = @import("drivers/tty.zig");

const Writer = text.Writer;
const Color = screen.Color;
const Point = screen.Point;
const Rect = screen.Rect;

const SIN: [32]i32 = .{
    0,    50,   98,   142,  181,  213,  237,  251,
    256,  251,  237,  213,  181,  142,  98,   50,
    0,    -50,  -98,  -142, -181, -213, -237, -251,
    -256, -251, -237, -213, -181, -142, -98,  -50,
};

fn sin32(a: usize) i32 {
    return SIN[a & 31];
}

fn cos32(a: usize) i32 {
    return SIN[(a + 8) & 31];
}

fn absI(v: i32) i32 {
    return if (v < 0) -v else v;
}

fn clampU8(v: i32) u8 {
    if (v < 0) return 0;
    if (v > 255) return 255;
    return @intCast(v);
}

const Donut = struct {
    cx: i32,
    cy: i32,

    // Major radius, minor radius.
    r_major: i32,
    r_minor: i32,

    // Animation angles.
    angle_a: usize,
    angle_b: usize,

    inline fn call(self: *@This(), p: Point) ?Color {
        const px: i32 = @intCast(p[0]);
        const py: i32 = @intCast(p[1]);

        var x = px - self.cx;
        var y = py - self.cy;

        // Rotate screen-space coordinates around Z.
        const ca = cos32(self.angle_a);
        const sa = sin32(self.angle_a);

        const rx = (x * ca + y * sa) >> 8;
        const ry = (-x * sa + y * ca) >> 8;

        x = rx;
        y = ry;

        // Correct 3D tilt: unproject Y by dividing by cos(angle_b) to get ring-space coords.
        // Capped to prevent extreme distortion near edge-on view.
        const cb = cos32(self.angle_b);
        const sb = sin32(self.angle_b);
        const abs_cb = @max(absI(cb), 32);
        const ty = @divTrunc(y * 256, abs_cb);

        // Z-depth component: how far this point is into/out of the screen.
        const tz = @divTrunc(y * sb, 256);

        // Distance from center in tilted space.
        const d2 = x * x + ty * ty;

        const outer = self.r_major + self.r_minor;
        const inner = self.r_major - self.r_minor;

        if (d2 > outer * outer or d2 < inner * inner) {
            return .black;
        }

        // Approximate radial distance without sqrt.
        // Good enough for fake donut shading.
        const ax = absI(x);
        const ay = absI(ty);
        const approx_dist = if (ax > ay)
            ax + (ay >> 1)
        else
            ay + (ax >> 1);

        const tube_pos = absI(approx_dist - self.r_major);

        if (tube_pos > self.r_minor) {
            return .black;
        }

        // Tube shading: brighter near center of tube.
        const tube_light = 255 - @divTrunc(tube_pos * 180, self.r_minor);

        // Fake directional light from upper-left/front.
        const light_x = @divTrunc(-x * 48, outer);
        const light_y = @divTrunc(-ty * 64, outer);

        // Z-depth shading: front face (toward viewer) is brighter, back is darker.
        const light_z = @divTrunc(tz * 80, outer);

        // Rotation-dependent shimmer.
        const shimmer = @divTrunc((x * sin32(self.angle_b) + ty * cos32(self.angle_b)) >> 8, 3);

        const brightness = tube_light + light_x + light_y + light_z + shimmer;

        // Give it a warm orange/yellow shaded material.
        return Color.rgb(
            clampU8(brightness + 30),
            clampU8(@divTrunc(brightness * 3, 5) + 40),
            clampU8(@divTrunc(brightness * 1, 5)),
        );
    }
};

pub fn drawDonut(frame: usize) !void {
    var donut = Donut{
        .cx = @intCast(screen.info.width / 2),
        .cy = @intCast(screen.info.height / 2),
        .r_major = 72,
        .r_minor = 24,
        .angle_a = frame,
        .angle_b = frame * 2,
    };

    const w: usize = 240;
    const h: usize = 180;

    const rect = Rect{
        .origin = .{
            screen.info.width / 2 - w / 2,
            screen.info.height / 2 - h / 2,
        },
        .size = .{ w, h },
    };

    try screen.render(Donut, rect, &donut, Donut.call);
}

pub fn kmain() !void {
    try screen.fill(Color.black);
    var frame: usize = 0;

    var writer: Writer = .{};

    try writer.write("I'm a good text :)");

    while (true) : (frame += 1) {
        try drawDonut(frame);

        var delay: usize = 0;
        while (delay < 500_000) : (delay += 1) {
            asm volatile ("pause");
        }
    }
}
