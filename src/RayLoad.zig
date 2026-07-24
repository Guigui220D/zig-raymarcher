//! Set of rays that the renderer is working on
//! This class contains the methods to evolve that set of rays
// TODO: this class actually does many things. It's pretty much the renderer. Does it make
// sense for it to have this class name?
const std = @import("std");
const zlm = @import("zlm").as(f64);

const Ray = @import("Ray.zig");
const Canvas = @import("Canvas.zig");
const Scene = @import("Scene.zig");
const Camera = @import("Camera.zig");
const CacheMindfulIterator = @import("cache_mindful.zig").Iterator(Ray);
const vector = @import("vector.zig");
const settings = @import("settings.zig");

const RayLoad = @This();

alloc: std.mem.Allocator,
info_arena: std.heap.ArenaAllocator,
rays: Ray.Rays,
canvas: *const Canvas,
camera: *const Camera,
current_work_cursor: usize,
work_len: usize,
scene: *const Scene,
report: ?*std.Io.Writer,

/// Init the rayload with rays for each pixel
pub fn init(alloc: std.mem.Allocator, canvas: *const Canvas, camera: *const Camera, scene: *const Scene, report: ?*std.Io.Writer) !RayLoad {
    var ret: RayLoad = undefined;
    ret.alloc = alloc;

    ret.rays = .empty;
    errdefer ret.rays.deinit(ret.alloc);

    ret.canvas = canvas;
    ret.camera = camera;
    ret.current_work_cursor = 0;
    //ret.work_len = 300000 / @sizeOf(Ray);
    ret.work_len = std.math.maxInt(usize);
    ret.scene = scene;

    ret.info_arena = .init(alloc);
    ret.report = report;

    return ret;
}

pub fn deinit(self: *RayLoad) void {
    self.info_arena.deinit();
    self.rays.deinit(self.alloc);
}

pub fn refillFromCanvas(self: *RayLoad) !bool {
    if (self.current_work_cursor >= self.canvas.width * self.canvas.height)
        return false;

    const fwidth: f64 = @floatFromInt(self.canvas.width);
    const fheight: f64 = @floatFromInt(self.canvas.height);

    try self.rays.ensureUnusedCapacity(self.alloc, self.canvas.height * self.canvas.width * 2);

    //std.debug.print("Work cursor at {}\n", .{self.current_work_cursor});
    // TODO: vectorized version
    //self.rays.resize(self.alloc, self.work_len);
    for (self.current_work_cursor..@min((self.current_work_cursor + self.work_len), self.canvas.height * self.canvas.width)) |i| {
        const x = i % self.canvas.width;
        const y = i / self.canvas.width;

        const y_f: f64 = @floatFromInt(y);
        const ry: f64 = (y_f - fheight / 2.0) / fwidth;

        const x_f: f64 = @floatFromInt(x);
        const rx: f64 = (x_f - fwidth / 2.0) / fwidth;

        // TODO: could be multithreaded
        const direction = zlm.vec3(rx, ry, 1 / self.camera.fov_modifier);
        var actual_dir = zlm.Vec3.zero;
        actual_dir = actual_dir.add(self.camera.getX().scale(direction.x));
        actual_dir = actual_dir.add(self.camera.getY().scale(-direction.y));
        actual_dir = actual_dir.add(self.camera.getZ().scale(direction.z));

        self.rays.appendAssumeCapacity(.initForPixel(self.camera.origin, actual_dir.normalize(), x, y, self.canvas));
    }

    while (self.rays.len % vector.vec_len != 0) // TODO: can be assumed if work_len is the right size
        self.rays.appendAssumeCapacity(.dummy);

    self.current_work_cursor += self.work_len;

    return true;
}

// TODO: see what semantics are now happening for args (copy?)
/// Checks if we have rays to process
pub fn hasWork(self: *const RayLoad) bool {
    return self.rays.len != 0;
}

/// Update the minimum distance of each ray based on a scene element
pub fn computeDistances(self: *RayLoad) void {
    const slice = self.rays.slice();
    for (self.scene.objects, 0..) |renderable, ren_id| {
        const x: []const f64 = slice.items(.pos_x);
        const y: []const f64 = slice.items(.pos_y);
        const z: []const f64 = slice.items(.pos_z);
        const d: []f64 = slice.items(.min_dist);
        const m: []usize = slice.items(.closest_object);
        const ts: []usize = slice.items(.total_steps);
        const sc: []usize = slice.items(.steps_closer);

        var i: usize = 0;
        while (i < x.len) : (i += vector.vec_len) {
            const v_x: vector.Vf64 = x[i..][0..vector.vec_len].*;
            const v_y: vector.Vf64 = y[i..][0..vector.vec_len].*;
            const v_z: vector.Vf64 = z[i..][0..vector.vec_len].*;
            var v_d: vector.Vf64 = d[i..][0..vector.vec_len].*;
            var v_m: vector.Vusize = m[i..][0..vector.vec_len].*;
            const v_ts: vector.Vusize = ts[i..][0..vector.vec_len].*;
            const v_sc: vector.Vusize = sc[i..][0..vector.vec_len].*;

            if (@reduce(.And, Ray.vStopped(v_x, v_y, v_z, v_d, v_ts, v_sc)))
                continue;

            const v_newd: vector.Vf64 = renderable.object.vDistance(v_x, v_y, v_z);

            const v_pred = v_newd < v_d;
            v_d = @select(f64, v_pred, v_newd, v_d);
            v_m = @select(usize, v_pred, @as(vector.Vusize, @splat(ren_id)), v_m);

            d[i..][0..vector.vec_len].* = v_d;
            m[i..][0..vector.vec_len].* = v_m;
        }
    }
}

/// Progress each ray based on the minimum distance we found, instanciate new rays or collapse results and remove rays-
pub fn update(self: *RayLoad, io: std.Io, clock: std.Io.Clock) !void {
    // Disgusting function! TODO: make it easier to understand
    var i: usize = 0;
    while (i < self.rays.len) {
        // Make sure we can fill vectors
        while (i + vector.vec_len > self.rays.len)
            self.rays.appendAssumeCapacity(.dummy);

        const slice = self.rays.slice();
        const v_d: vector.Vf64 = slice.items(.min_dist)[i..][0..vector.vec_len].*;
        const v_ts: vector.Vusize = slice.items(.total_steps)[i..][0..vector.vec_len].*;
        const v_sc: vector.Vusize = slice.items(.steps_closer)[i..][0..vector.vec_len].*;
        const v_x: vector.Vf64 = slice.items(.pos_x)[i..][0..vector.vec_len].*;
        const v_y: vector.Vf64 = slice.items(.pos_y)[i..][0..vector.vec_len].*;
        const v_z: vector.Vf64 = slice.items(.pos_z)[i..][0..vector.vec_len].*;

        const v_stop = Ray.vStopped(v_x, v_y, v_z, v_d, v_ts, v_sc);
        var all_stop = true; // Flags that the whole vector will be removed
        var progress: usize = vector.vec_len;

        // could use VPCOMPRESSD on AVX512
        // For each stopped ray, apply results
        // Not great!!! we are checking some values several times
        // TODO: can we do that without an inline loop?
        inline for (0..vector.vec_len) |j| {
            if (v_stop[j]) {
                const index = j + i;
                // TODO: we could do it several time until we get a non finished vector
                // That would allow always progressing by vec_len, and avoiding re-checks
                const ray = self.rays.get(index);

                // TODO: get material info from the ray
                // decide or not to recurse
                // apply the color obtained from the ray to the
                const ren = self.scene.objects[ray.closest_object];
                const normal = ren.object.normal(.{ .x = ray.pos_x, .y = ray.pos_y, .z = ray.pos_z });
                // TODO: there is unpredictable behavior on whether or not a newly inserted reflection ray will be progressed during this iteration
                const continued = try ray.hit(self.info_arena.allocator(), &self.rays, &ren, self.scene.materials, normal);
                if (continued)
                    all_stop = false;
                if (i + vector.vec_len >= self.rays.len) {
                    self.rays.set(index, .dummy);
                } else {
                    if (i < progress)
                        progress = i;
                    self.rays.swapRemove(index);
                }
            } else {
                all_stop = false;
            }
        }

        if (i + vector.vec_len == self.rays.len and all_stop) // TODO: is this still correct now that stopped vectors can reflect?
            self.rays.shrinkRetainingCapacity(self.rays.len - vector.vec_len);

        // We can safely advance the cursor by how many non finished rays there were first
        i += progress;
        //std.debug.print("Left: {}\n", .{self.rays.len});
    }

    if (self.report) |writer| {
        // bins for counting rays of each depth
        const now = clock.now(io).toMicroseconds();
        var bins: [10]usize = undefined;
        @memset(&bins, 0);

        const targets = self.rays.slice().items(.target);
        for (targets) |target| {
            if (target == .dummy)
                continue;
            const depth = target.getDepth();
            bins[depth] += 1;
        }

        try writer.print("{}, ", .{now});
        for (bins, 0..) |bin_val, j| {
            if (j > settings.max_reflections)
                break;
            try writer.printInt(bin_val, 10, .lower, .{});
            try writer.writeAll(", ");
        }
        try writer.writeByte('\n');
        try writer.flush();
    }

    std.debug.print("Progress ({})\n", .{self.rays.len});
    // TODO Could this be before? I don't think it would cost anything
    // Would avoid ambiguities with added rays
    Ray.vProgress(&self.rays.slice());
}
