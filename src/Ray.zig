const std = @import("std");
const zlm = @import("zlm").as(f64);

const Canvas = @import("Canvas.zig");
const settings = @import("settings.zig");
const Color = @import("color.zig").Color;
const csscolorparser = @import("csscolorparser");

const Ray = @This();

/// Current position of the ray
pos: zlm.Vec3,
/// Direction it's going
dir: zlm.Vec3,
/// Minimum distance found in the current step
min_dist: f64 = std.math.floatMax(f64),
/// Material of the minimum distance found
closest_mat: usize = 0,
/// Number of steps forward achieved
total_steps: usize = 0,
/// Number steps for which we have been getting closer to the scene
steps_closer: usize = 0,
/// Metadata of the ray (what are throwing a ray for?)
meta: Meta,

/// Init a ray for a pixel
pub fn initForPixel(pos: zlm.Vec3, dir: zlm.Vec3, px: usize, py: usize, canvas: *const Canvas) Ray {
    return .{
        .pos = pos,
        .dir = dir,
        .meta = .{
            .pix_x = px,
            .pix_y = py,
            .canvas = canvas,
        },
    };
}

/// Returns true if the ray isn't done working
pub fn stopped(self: Ray) bool {
    return self.min_dist < settings.hit_distance or self.total_steps >= settings.max_steps or self.steps_closer >= settings.max_steps_getting_closer;
}

/// Update a ray (creates a copy because more convinient with the way things are done)
pub fn progress(self: Ray) Ray {
    const getting_closer = false; // TODO: determine that
    return .{
        .pos = self.pos.add(self.dir.scale(self.min_dist)),
        .dir = self.dir,
        .total_steps = self.total_steps + 1,
        .steps_closer = if (getting_closer) self.steps_closer + 1 else 0,
        .meta = self.meta,
    };
}

/// For rays that have reached the end of their work, apply the results of the calculations
pub fn applyResult(self: Ray) void {
    // Material id based coloring for debug

    const hue = @as(f32, @floatFromInt(self.closest_mat)) / @as(f32, @floatFromInt(6));

    // TODO: would this logic really be here?
    var col = csscolorparser.Color(f32).fromHsl(hue * 360, 1.0, 0.5, 1.0);

    if (self.min_dist > settings.hit_distance)
        col = csscolorparser.Color(f32).fromRgba8(0, 0, 0, 255);

    self.meta.canvas.data[self.meta.pix_y * self.meta.canvas.width + self.meta.pix_x] = Color{
        .a = col.alpha,
        .r = col.red,
        .g = col.green,
        .b = col.blue,
    };
}

/// Metadata of a ray (what are throwing a ray for?)
pub const Meta = struct {
    // Will be different later
    pix_x: usize,
    pix_y: usize,
    canvas: *const Canvas,
};
