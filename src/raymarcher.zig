const zlm = @import("zlm").as(f64);
const std = @import("std");
const math = std.math;

const Scene = @import("Scene.zig");
const Renderable = @import("Renderable.zig");
const Color = @import("color.zig").Color;
const Canvas = @import("Canvas.zig");
const Camera = @import("Camera.zig");

// TODO: make this an object and add current_settings and default_settings
pub const settings = struct {
    pub var hit_distance: f64 = 0.02;
    pub var max_steps: usize = 128;
    pub var max_reflections: usize = 6;
    pub var preview: bool = false;
};

var current_scene: Scene = undefined;
var current_canvas: Canvas = undefined;
var current_camera: Camera = .{};
var fwidth: f64 = undefined;
var fheight: f64 = undefined;
var next_slice: usize = 0;

fn distanceToScene(scene: []const Renderable, pos: zlm.Vec3) f64 {
    var distance: f64 = math.floatMax(f64);

    for (scene) |renderable| {
        const dist = renderable.object.distance(pos);
        distance = @min(distance, dist);
    }

    return distance;
}

fn closestObject(scene: []const Renderable, pos: zlm.Vec3) ?*const Renderable {
    var distance: f64 = math.floatMax(f64);
    var obj: ?*const Renderable = null;

    for (scene) |*renderable| {
        const dist = renderable.object.distance(pos);

        if (dist < distance) {
            distance = dist;
            obj = renderable;
        }
    }

    return obj;
}

fn normal(rend: Renderable, pos: zlm.Vec3) zlm.Vec3 {
    const dist = rend.object.distance(pos);

    return zlm.Vec3.normalize(zlm.vec3(
        rend.object.distance(pos.add(zlm.vec3(settings.hit_distance / 2, 0, 0))) - dist,
        rend.object.distance(pos.add(zlm.vec3(0, settings.hit_distance / 2, 0))) - dist,
        rend.object.distance(pos.add(zlm.vec3(0, 0, settings.hit_distance / 2))) - dist,
    ));
}

fn reflect(incident: zlm.Vec3, normale: zlm.Vec3) zlm.Vec3 {
    return incident.sub(normale.scale(incident.dot(normale) * 2.0));
}

fn march(position: *zlm.Vec3, direction: zlm.Vec3, distance: f64) void {
    position.* = position.add(direction.scale(distance));
}

// TODO: return info about how occluded is the path to the point instead of just bool
// TODO: consider reflections? (that may be rly hard)
fn raymarchToPoint(scene: []const Renderable, goal: zlm.Vec3, start: zlm.Vec3) bool {
    const dir = goal.sub(start).normalize();
    var ray = start;
    march(&ray, dir, settings.hit_distance * 1.1);

    while (true) {
        if (goal.sub(ray).dot(dir) <= 0)
            return true; // We got past the light
        const distance = distanceToScene(scene, ray);
        if (distance <= settings.hit_distance)
            return false; // We hit an object

        march(&ray, dir, distance - (settings.hit_distance * 0.9));
    }
}

fn raymarch(scene: Scene, start: zlm.Vec3, direction: zlm.Vec3, recursion: usize) Color {
    var i: usize = 0;

    var ray = start;

    return while (i < settings.max_steps) : (i += 1) {
        const distance = distanceToScene(scene.objects, ray);

        if (distance <= 3 * settings.hit_distance)
            i = 0;

        if (distance <= settings.hit_distance) {
            const obj = closestObject(scene.objects, ray).?;
            const mat = obj.material;

            const norm_vec = normal(obj.*, ray);
            const reflection = reflect(direction.normalize(), norm_vec);

            var diffuse = if (mat.diffuse2) |pattern| blk: {
                const sum = math.floor(ray.x * 3) + math.floor(ray.y * 5) + math.floor(ray.z * 3);
                if (@mod(sum, 2) < 0.1) {
                    break :blk mat.diffuse;
                }
                break :blk pattern;
            } else mat.diffuse;

            var light_sum: Color = scene.global_light.color;
            for (scene.lights) |light| {
                const dir = light.position.sub(ray).normalize();
                const dot: f32 = @floatCast(norm_vec.dot(dir));
                if (dot < 0)
                    continue;
                if (raymarchToPoint(scene.objects, light.position, ray)) {
                    light_sum = light_sum.add(light.color.scale(dot));
                }
            }

            diffuse = diffuse.mul(light_sum);

            if (mat.reflectivity == 0.0 or recursion == 0)
                break diffuse;

            march(&ray, reflection, settings.hit_distance * 1.1);
            const refl_color = raymarch(scene, ray, reflection, recursion - 1);

            break Color.mix(refl_color, diffuse, mat.reflectivity * @as(f32, @floatCast(norm_vec.normalize().dot(reflection))));
        }
        march(&ray, direction, distance - (settings.hit_distance * 0.9));
    } else
    // TODO: return skybox color instead
    Color{
        .r = 0,
        .g = 0,
        .b = 0,
    };
}

pub fn render(_: std.mem.Allocator, io: std.Io, scene: Scene, canvas: Canvas, camera: Camera) !void {
    if (canvas.width == 0 or canvas.height == 0)
        return error.canvasWrongFormat;

    if (settings.preview) {
        std.debug.print("/!\\ Running in preview mode!\n", .{});
        settings.max_steps = 100;
    }

    current_scene = scene;
    current_canvas = canvas;
    current_camera = camera;

    fwidth = @floatFromInt(canvas.width);
    fheight = @floatFromInt(canvas.height);

    next_slice = 0;

    var group: std.Io.Group = .init;
    defer group.cancel(io);

    for (0..current_canvas.height) |slice_y| {
        group.async(io, renderSlice, .{slice_y});
    }

    try group.await(io);
}

fn renderSlice(my_slice: usize) !void {
    const width = current_canvas.width;
    const begin = width * my_slice;

    if (settings.preview and my_slice % 2 == 0) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            current_canvas.data[begin + x] = .{ .r = 0, .g = 0, .b = 0 };
        }
        return;
    }

    const slice_f: f64 = @floatFromInt(my_slice);
    const ry: f64 = (slice_f - fheight / 2.0) / fwidth;

    const refls = if (settings.preview) 2 else settings.max_reflections;

    var x: usize = 0;
    while (x < width) : (x += 1) {
        const x_f: f64 = @floatFromInt(x);
        const rx: f64 = (x_f - fwidth / 2.0) / fwidth;

        const direction = zlm.vec3(rx, ry, 1);
        var actual_dir = zlm.Vec3.zero;
        actual_dir = actual_dir.add(current_camera.getX().scale(direction.x));
        actual_dir = actual_dir.add(current_camera.getY().scale(direction.y));
        actual_dir = actual_dir.add(current_camera.getZ().scale(direction.z));

        const col = raymarch(current_scene, current_camera.origin, actual_dir.normalize(), refls);
        current_canvas.data[begin + x] = col;
    }
}

//Guillaume Derex 2020-2022
