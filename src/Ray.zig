const std = @import("std");
const zlm = @import("zlm").as(f64);

const Canvas = @import("Canvas.zig");
const settings = @import("settings.zig");
const Color = @import("color.zig").Color;
const csscolorparser = @import("csscolorparser");
const vector = @import("vector.zig");

const Ray = @This();

pub const dummy = Ray{
    .pos_x = 0,
    .pos_y = 0,
    .pos_z = 0,
    .dir_x = 1,
    .dir_y = 0,
    .dir_z = 0,
    .meta = null,
};

/// Current position of the ray (x)
pos_x: f64,
/// Current position of the ray (y)
pos_y: f64,
/// Current position of the ray (z)
pos_z: f64,
/// Current direction of the ray (x)
dir_x: f64,
/// Current direction of the ray (y)
dir_y: f64,
/// Current direction of the ray (z)
dir_z: f64,
/// Minimum distance found in the current step
min_dist: f64 = std.math.floatMax(f64),
/// Material of the minimum distance found
closest_mat: usize = 0,
/// Number of steps forward achieved
total_steps: usize = 0,
/// Number steps for which we have been getting closer to the scene
steps_closer: usize = 0,
/// Metadata of the ray (what are throwing a ray for?)
meta: ?Meta,

/// Init a ray for a pixel
pub fn initForPixel(pos: zlm.Vec3, dir: zlm.Vec3, px: usize, py: usize, canvas: *const Canvas) Ray {
    return .{
        .pos_x = pos.x,
        .pos_y = pos.y,
        .pos_z = pos.z,
        .dir_x = dir.x,
        .dir_y = dir.y,
        .dir_z = dir.z,
        .meta = .{
            .pix_x = px,
            .pix_y = py,
            .canvas = canvas,
        },
    };
}

/// Returns true if the ray isn't done working
pub fn stopped(self: Ray) bool {
    if (self.meta == null)
        return true; // TODO: better system (meta will change anyways)
    return self.min_dist < settings.hit_distance or self.total_steps >= settings.max_steps or self.steps_closer >= settings.max_steps_getting_closer;
}

pub fn vStopped(min_dist: vector.Vf64, total_steps: vector.Vusize, steps_closer: vector.Vusize) vector.Vbool {
    return (min_dist < @as(vector.Vf64, @splat(settings.hit_distance))) &
        (total_steps >= @as(vector.Vusize, @splat(settings.max_steps))) &
        (steps_closer > @as(vector.Vusize, @splat(settings.max_steps_getting_closer)));
}

/// Update a ray (creates a copy because more convinient with the way things are done)
pub fn progress(self: Ray) Ray {
    const getting_closer = false; // TODO: determine that
    return .{
        .pos_x = self.pos_x + self.dir_x * self.min_dist,
        .pos_y = self.pos_y + self.dir_y * self.min_dist,
        .pos_z = self.pos_z + self.dir_z * self.min_dist,
        .dir_x = self.dir_x,
        .dir_y = self.dir_y,
        .dir_z = self.dir_z,
        .total_steps = self.total_steps + 1,
        .steps_closer = if (getting_closer) self.steps_closer + 1 else 0,
        .meta = self.meta,
    };
}

/// For rays that have reached the end of their work, apply the results of the calculations
pub fn applyResult(self: Ray) void {
    // Material id based coloring for debug
    if (self.meta) |meta| {
        const hue = @as(f32, @floatFromInt(self.closest_mat)) / @as(f32, @floatFromInt(6));

        // TODO: would this logic really be here?
        var col = csscolorparser.Color(f32).fromHsl(hue * 360, 1.0, 0.5, 1.0);

        if (self.min_dist > settings.hit_distance)
            col = csscolorparser.Color(f32).fromRgba8(0, 0, 0, 255);

        meta.canvas.data[meta.pix_y * meta.canvas.width + meta.pix_x] = Color{
            .a = col.alpha,
            .r = col.red,
            .g = col.green,
            .b = col.blue,
        };
    }
}

/// Metadata of a ray (what are throwing a ray for?)
pub const Meta = struct {
    // Will be different later
    pix_x: usize,
    pix_y: usize,
    canvas: *const Canvas,
};
