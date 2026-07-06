const std = @import("std");
const zlm = @import("zlm").as(f64);

const Ray = @import("Ray.zig");
const Canvas = @import("Canvas.zig");
const Renderable = @import("Renderable.zig");
const Camera = @import("Camera.zig");
const CacheMindfulIterator = @import("cache_mindful.zig").Iterator(Ray);

const RayLoad = @This();

alloc: std.mem.Allocator,
rays: std.ArrayList(Ray),
temp_rays: std.ArrayList(Ray),

/// Init the rayload with rays for each pixel
pub fn init(alloc: std.mem.Allocator) !RayLoad {
    var ret: RayLoad = undefined;
    ret.alloc = alloc;

    ret.rays = .empty;
    errdefer ret.rays.deinit(ret.alloc);

    ret.temp_rays = .empty;
    errdefer ret.temp_rays.deinit(ret.alloc);

    return ret;
}

pub fn deinit(self: *RayLoad) void {
    self.rays.deinit(self.alloc);
    self.temp_rays.deinit(self.alloc);
}

pub fn fillForCanvas(self: *RayLoad, canvas: *const Canvas, camera: *const Camera) !void {
    const fwidth: f64 = @floatFromInt(canvas.width);
    const fheight: f64 = @floatFromInt(canvas.height);

    try self.rays.ensureUnusedCapacity(self.alloc, canvas.height * canvas.width);
    try self.rays.ensureUnusedCapacity(self.alloc, canvas.height * canvas.width);

    for (0..canvas.height) |y| {
        const y_f: f64 = @floatFromInt(y);
        const ry: f64 = (y_f - fheight / 2.0) / fwidth;

        for (0..canvas.width) |x| {
            const x_f: f64 = @floatFromInt(x);
            const rx: f64 = (x_f - fwidth / 2.0) / fwidth;

            // TODO: could be multithreaded
            const direction = zlm.vec3(rx, ry, 1 / camera.fov_modifier);
            var actual_dir = zlm.Vec3.zero;
            actual_dir = actual_dir.add(camera.getX().scale(direction.x));
            actual_dir = actual_dir.add(camera.getY().scale(-direction.y));
            actual_dir = actual_dir.add(camera.getZ().scale(direction.z));

            self.rays.appendAssumeCapacity(.initForPixel(camera.origin, actual_dir, x, y, canvas));
        }
    }
}

// TODO: see what semantics are now happening for args (copy?)
/// Checks if we have rays to process
pub fn hasWork(self: *const RayLoad) bool {
    return self.rays.items.len != 0;
}

/// Update the minimum distance of each ray based on a scene element
pub fn computeDistances(self: *RayLoad, renderables: []const Renderable) void {
    // TODO: do not do all of that at once. Take in account cache size to avoid loading more rays
    // fill cache to the brim with rays, then do all renderables of the scene one by one on it
    // then onto next cachefull
    var slice_it = CacheMindfulIterator.init(self.rays.items);

    while (slice_it.next()) |slice| {
        for (renderables) |renderable| {
            for (slice) |*ray| {
                if (ray.stopped()) // Don't waste time on stuff that already hit
                    continue;

                const dist = renderable.object.distance(ray.pos);
                if (dist < ray.min_dist) {
                    ray.min_dist = dist;
                    ray.closest_mat = renderable.material_id;
                }
            }
        }
    }
}

// TODO: function does too much?
/// Progress each ray based on the minimum distance we found, instanciate new rays or collapse results and remove rays-
pub fn update(self: *RayLoad) !void {
    for (self.rays.items) |ray| {
        // Check for hit (use results)
        if (ray.stopped()) {
            ray.applyResult();
            continue;
        }

        // Progress ray
        try self.temp_rays.append(self.alloc, ray.progress());
    }

    // Swap two arrays
    self.rays.clearRetainingCapacity();
    const tmp = self.rays;
    self.rays = self.temp_rays;
    self.temp_rays = tmp;
}
