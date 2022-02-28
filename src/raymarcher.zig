const zlm = @import("zlm").SpecializeOn(f64);
const std = @import("std");
const math = std.math;

const Renderable = @import("Renderable.zig");
const Color = @import("color.zig").Color;
const Image = @import("Image.zig");

// TODO: make this an object and add current_settings and default_settings
pub const settings = struct {
    pub var hit_distance: f64 = 0.02;
    pub var max_steps: usize = 128;
    pub var max_reflections: usize = 6;
    pub var preview: bool = false;
};

var render_node: *std.Progress.Node = undefined;
var current_scene: []const Renderable = undefined;
var current_canvas: Image = undefined;
var fwidth: f64 = undefined;
var fheight: f64 = undefined;
var next_slice: usize = 0;

pub fn distanceToScene(scene: []const Renderable, pos: zlm.Vec3) f64 {
    var distance: f64 = math.f64_max;

    for (scene) |renderable| {
        const dist = renderable.object.distance(pos);
        distance = math.min(distance, dist);
    }

    return distance;
}

pub fn closestObject(scene: []const Renderable, pos: zlm.Vec3) ?*const Renderable {
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

pub fn raymarch(scene: []const Renderable, start: zlm.Vec3, direction: zlm.Vec3, recursion: usize) Color {
    var i: usize = 0;

    var ray = start;

    return while (i < settings.max_steps) : (i += 1) {
        var distance = distanceToScene(scene, ray);

        if (distance <= 3 * settings.hit_distance)
            i = 0;

        if (distance <= settings.hit_distance) {
            const obj = closestObject(scene, ray).?;
            const mat = obj.material;

            const norm_vec = normal(obj.*, ray);
            const reflection = reflect(direction.normalize(), norm_vec);

            var diffuse = if (mat.diffuse2) |pattern| blk: {
                const sum = math.floor(ray.x * 3) + math.floor(ray.y * 5) + math.floor(ray.z * 3);
                if (@mod(sum, 2) < 0.1) {
                    break :blk mat.diffuse;
                }
                    break :blk pattern;
            } else
                mat.diffuse;

            diffuse = Color.mix(diffuse, .{ .r = 0, .g = 0, .b = 0 }, @sqrt(@floatCast(f32, norm_vec.normalize().dot(reflection))));

            if (mat.reflectivity == 0.0 or recursion == 0)
                break diffuse;

            march(&ray, reflection, settings.hit_distance * 1.1);
            var refl_color = raymarch(scene, ray, reflection, recursion - 1);

            break Color.mix(refl_color, diffuse, mat.reflectivity * @floatCast(f32, norm_vec.normalize().dot(reflection)));
        }
        march(&ray, direction, distance - (settings.hit_distance * 0.9));
    } else
        Color{
        .r = 0,
        .g = 0,
        .b = 0,
    };
}

pub fn render(allocator: std.mem.Allocator, scene: []const Renderable, canvas: Image, thread_count: usize) !void {
    if (canvas.width == 0 or canvas.height == 0)
        return error.canvasWrongFormat;

    if (settings.preview) {
        std.debug.print("/!\\ Running in preview mode!\n", .{});
        settings.max_steps = 100;
    }

    current_scene = scene;
    current_canvas = canvas;

    fwidth = @intToFloat(f64, canvas.width);
    fheight = @intToFloat(f64, canvas.height);

    next_slice = 0;

    var threads = try allocator.alloc(std.Thread, thread_count);
    defer allocator.free(threads);

    var progress = std.Progress{};
    render_node = try progress.start("Render", current_canvas.height);
    defer render_node.end();
    render_node.activate();

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

        const width = current_canvas.width;
        const begin = width * my_slice;

        if (settings.preview and my_slice % 2 == 0) {
            var x: usize = 0;
            while (x < width) : (x += 1) {
                current_canvas.data[begin + x] = .{ .r = 0, .g = 0, .b = 0, .a = 127 };
            }
            render_node.completeOne();
            continue;
        }

        const ry = (@intToFloat(f64, my_slice) - (fheight / 2.0)) / fwidth;

        const refls = if (settings.preview) 2 else settings.max_reflections;

        var x: usize = 0;
        while (x < width) : (x += 1) {
            const rx = (@intToFloat(f64, x) - (fwidth / 2.0)) / fwidth;

            const direction = zlm.vec3(rx, ry, 1);

            const col = raymarch(current_scene, zlm.Vec3.zero, direction.normalize(), refls);
            current_canvas.data[begin + x] = col.to32BitsColor();
        }

        render_node.completeOne();
    }
}

//Guillaume Derex 2020