const std = @import("std");
const zlm = @import("zlm").as(Ft);

const Canvas = @import("Canvas.zig");
const settings = @import("settings.zig");
const Ft = settings.Ft;
const Color = @import("color.zig").Color;
const csscolorparser = @import("csscolorparser");
const vec = @import("vector.zig");
const RayTarget = @import("ray_reason.zig").Target;
const Renderable = @import("Renderable.zig");
const Material = @import("Material.zig");

const Ray = @This();
/// SoA array of rays for vectorization
pub const Rays = std.MultiArrayList(Ray);

/// Dummy ray that has nothing to do
/// Used as padding for vectorized operations on rays
pub const dummy = Ray{
    .pos_x = 0,
    .pos_y = 0,
    .pos_z = 0,
    .dir_x = 1,
    .dir_y = 0,
    .dir_z = 0,
    .target = .{ .dummy = {} },
    .min_dist = 0,
};

/// Current position of the ray (x)
pos_x: Ft,
/// Current position of the ray (y)
pos_y: Ft,
/// Current position of the ray (z)
pos_z: Ft,
/// Current direction of the ray (x)
dir_x: Ft,
/// Current direction of the ray (y)
dir_y: Ft,
/// Current direction of the ray (z)
dir_z: Ft,
/// Minimum distance found in the current step
min_dist: Ft = std.math.floatMax(Ft),
/// Renderable index of the minimum distance found
closest_object: u8 = 0,
/// Number of steps forward achieved
total_steps: u16 = 0,
/// Number steps for which we have been getting closer to the scene
steps_closer: u16 = 0,
/// Metadata of the ray (what are throwing a ray for?)
target: RayTarget,

/// Init a ray for a pixel
pub fn initForPixel(pos: zlm.Vec3, dir: zlm.Vec3, px: usize, py: usize, canvas: *const Canvas) Ray {
    return .{
        .pos_x = pos.x,
        .pos_y = pos.y,
        .pos_z = pos.z,
        .dir_x = dir.x,
        .dir_y = dir.y,
        .dir_z = dir.z,
        .target = .{
            .pixel = .{
                .canvas = canvas,
                .pix_x = px,
                .pix_y = py,
            },
        },
    };
}

/// Makes a new ray for a reflection from this one and a normal
pub fn reflect(self: Ray, normal: zlm.Vec3, target: RayTarget) Ray {
    const incident = zlm.Vec3{ .x = self.dir_x, .y = self.dir_y, .z = self.dir_z };
    const reflection = incident.sub(normal.scale(incident.dot(normal) * 2.0)).normalize();
    return .{
        .pos_x = self.pos_x,
        .pos_y = self.pos_y,
        .pos_z = self.pos_z,
        .dir_x = reflection.x,
        .dir_y = reflection.y,
        .dir_z = reflection.z,
        .min_dist = settings.hit_distance * 1.01,
        .target = target,
    };
}

/// Returns true if the ray is done working
pub fn stopped(self: Ray) bool {
    const oob = @abs(self.pos_x) > settings.scene_boundaries or @abs(self.pos_y) > settings.scene_boundaries or @abs(self.pos_z) > settings.scene_boundaries;
    return self.min_dist < settings.hit_distance or self.total_steps >= settings.max_steps or self.steps_closer >= settings.max_steps_getting_closer or oob;
}

/// Returns true if the ray is done working (vectorized)
pub fn vStopped(x: vec.VFt, y: vec.VFt, z: vec.VFt, min_dist: vec.VFt, total_steps: vec.Vusize, steps_closer: vec.Vusize) vec.Vbool {
    const oob = (x > @as(vec.VFt, @splat(settings.scene_boundaries))) |
        (y > @as(vec.VFt, @splat(settings.scene_boundaries))) |
        (z > @as(vec.VFt, @splat(settings.scene_boundaries)));
    return (min_dist < @as(vec.VFt, @splat(settings.hit_distance))) |
        (total_steps >= @as(vec.Vusize, @splat(settings.max_steps))) |
        (steps_closer > @as(vec.Vusize, @splat(settings.max_steps_getting_closer))) |
        oob;
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
        .target = self.target,
    };
}

/// Update all rays in the set of rays (vectorized)
pub fn vProgress(slice: *const std.MultiArrayList(Ray).Slice) void {
    const xp_s = slice.items(.pos_x);
    const yp_s = slice.items(.pos_y);
    const zp_s = slice.items(.pos_z);
    const xd_s = slice.items(.dir_x);
    const yd_s = slice.items(.dir_y);
    const zd_s = slice.items(.dir_z);
    const ts_s = slice.items(.total_steps);
    const sc_s = slice.items(.steps_closer);
    const md_s = slice.items(.min_dist);

    var i: usize = 0;
    while (i < slice.len) : (i += settings.vec_len) {
        var xp: vec.VFt = xp_s[i..][0..settings.vec_len].*;
        var yp: vec.VFt = yp_s[i..][0..settings.vec_len].*;
        var zp: vec.VFt = zp_s[i..][0..settings.vec_len].*;
        const xd: vec.VFt = xd_s[i..][0..settings.vec_len].*;
        const yd: vec.VFt = yd_s[i..][0..settings.vec_len].*;
        const zd: vec.VFt = zd_s[i..][0..settings.vec_len].*;
        var ts: vec.Vu16 = ts_s[i..][0..settings.vec_len].*;
        var sc: vec.Vu16 = sc_s[i..][0..settings.vec_len].*;
        const md: vec.VFt = md_s[i..][0..settings.vec_len].*;

        xp += xd * md;
        yp += yd * md;
        zp += zd * md;
        ts += @as(vec.Vu16, @splat(1));
        sc += @as(vec.Vu16, @splat(1));

        xp_s[i..][0..settings.vec_len].* = xp;
        yp_s[i..][0..settings.vec_len].* = yp;
        zp_s[i..][0..settings.vec_len].* = zp;
        xd_s[i..][0..settings.vec_len].* = xd;
        yd_s[i..][0..settings.vec_len].* = yd;
        zd_s[i..][0..settings.vec_len].* = zd;
        ts_s[i..][0..settings.vec_len].* = ts;
        sc_s[i..][0..settings.vec_len].* = sc;
    }
}

// TODO: get context for normal for hit function
/// Selects a color from the closest material or skybox and applies it to the target
pub fn hit(self: Ray, alloc: std.mem.Allocator, rays: *Rays, obj: *const Renderable, materials: []const Material, normal: zlm.Vec3) !bool {
    const mat = if (self.min_dist <= settings.hit_distance * 1.1) materials[obj.material_id] else null;

    return try self.target.hit(alloc, mat, self, rays, normal);
}
