const Scene = @import("scene.zig").Scene;
const zlm = @import("zlm").SpecializeOn(f64);
const Renderable = @import("Renderable.zig");

const std = @import("std");
const math = std.math;

const color = @import("color.zig");
const Image = @import("image.zig").Image;

pub const settings = struct {
    var hit_distance: f64 = 0.02;
    var max_steps: usize = 128;
    var max_reflections: usize = 20;
};

var current_scene: Scene = undefined;
var current_canvas: Image = undefined;
var fwidth: f64 = undefined;
var fheight: f64 = undefined;
var next_slice: usize = 0;

pub fn distanceToScene(scene: Scene, pos: zlm.Vec3) f64 {
    var distance: f64 = math.f64_max;

    for (scene) |renderable| {
        const dist = renderable.object.distance(pos);
        distance = math.min(distance, dist);
    }

    return distance;
}

pub fn closestObject(scene: Scene, pos: zlm.Vec3) ?*const Renderable {
    var distance: f64 = math.f64_max;
    var obj: ?*const Renderable = null;

    for (scene) |*renderable| {
        var dist = renderable.object.distance(pos);

        if (dist < distance) {
            distance = dist;
            obj = renderable;
        }
    }

    return obj;
}

fn normal(rend: Renderable, pos: zlm.Vec3) zlm.Vec3 {
    var dist = rend.object.distance(pos);

    return zlm.Vec3.normalize(zlm.vec3(
        rend.object.distance(pos.add(zlm.vec3(settings.hit_distance / 2, 0, 0))) - dist,
        rend.object.distance(pos.add(zlm.vec3(0, settings.hit_distance / 2, 0))) - dist,
        rend.object.distance(pos.add(zlm.vec3(0, 0, settings.hit_distance / 2))) - dist
    ));
}

fn reflect(incident: zlm.Vec3, normale: zlm.Vec3) zlm.Vec3 {
    return incident.sub(normale.scale(incident.dot(normale) * 2.0));
}

fn march(position: *zlm.Vec3, direction: zlm.Vec3, distance: f64) void {
    position.* = position.add(direction.scale(distance));
}

pub fn raymarch(scene: Scene, start: zlm.Vec3, direction: zlm.Vec3, recursion: usize) color.Color {
    var i: usize = 0;

    var ray = start;

    return while (i < settings.max_steps) : (i += 1) {
        var distance = distanceToScene(scene, ray);

        if (distance <= settings.hit_distance) {
            const obj = closestObject(scene, ray).?;
            const mat = obj.material;

            const norm_vec = normal(obj.*, ray);

            if (mat.reflectivity == 0.0 or recursion == 0)
                break mat.diffuse;

            const reflection = reflect(direction.normalize(), norm_vec);

            march(&ray, reflection, settings.hit_distance * 1.1);
            var refl_color = raymarch(scene, ray, reflection, recursion - 1);

            const diffuse = if (mat.diffuse2) |pattern| blk: {
                const sum = math.floor(ray.x * 3) + math.floor(ray.y * 5) + math.floor(ray.z * 3);
                if (@mod(sum, 2) < 0.1) {
                    break :blk mat.diffuse;
                }
                    break :blk pattern;
            } else
                mat.diffuse;

            break color.Color.mix(refl_color, diffuse, mat.reflectivity * @floatCast(f32, norm_vec.normalize().dot(reflection)));
        }
        march(&ray, direction, distance - (settings.hit_distance * 0.9));
    } else
        color.Color{
        .r = 0,
        .g = 0,
        .b = 0,
    };
}

pub fn render(allocator: std.mem.Allocator, scene: Scene, canvas: Image, thread_count: usize) !void {
    if (canvas.width == 0 or canvas.height == 0)
        return error.canvasWrongFormat;

    current_scene = scene;
    current_canvas = canvas;

    fwidth = @intToFloat(f64, canvas.width);
    fheight = @intToFloat(f64, canvas.height);

    next_slice = 0;

    var threads = try allocator.alloc(std.Thread, thread_count);
    defer allocator.free(threads);

    for (threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, renderSlice, .{});
    }
    for (threads) |thread| {
        thread.join();
    }
}

fn renderSlice() !void {
    while (true) {
        const my_slice = @atomicRmw(usize, &next_slice, .Add, 1, .SeqCst); //Atomically increment and get task
        if (my_slice >= current_canvas.height)
            break;

        std.debug.print("Slice {} out of {}\n", .{ my_slice, current_canvas.height });

        const width = current_canvas.width;
        const begin = width * my_slice;

        const ry = (@intToFloat(f64, my_slice) - (fheight / 2.0)) / fwidth;

        var x: usize = 0;
        while (x < width) : (x += 1) {
            const rx = (@intToFloat(f64, x) - (fwidth / 2.0)) / fwidth;

            const direction = zlm.vec3(rx, ry, 1);

            const col = raymarch(current_scene, zlm.Vec3.zero, direction.normalize(), settings.max_reflections);
            current_canvas.data[begin + x] = col.to32BitsColor();
        }
    }
}

//Guillaume Derex 2020