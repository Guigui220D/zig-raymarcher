const zlm = @import("zlm").as(f64);
const std = @import("std");
const math = std.math;

const Scene = @import("Scene.zig");
const Renderable = @import("Renderable.zig");
const Color = @import("color.zig").Color;
const Canvas = @import("Canvas.zig");
const Camera = @import("Camera.zig");
const csscolorparser = @import("csscolorparser");

pub const DebugMode = enum {
    none,
    material_ids,
    mat_reflectivity,
    actual_reflectivity,
    dot,
};

// TODO: make this an object and add current_settings and default_settings
pub const settings = struct {
    pub var hit_distance: f64 = 0.02;
    pub var max_steps: usize = 128;
    pub var max_reflections: usize = 6;
    pub var preview: bool = false;
    pub var debug_mode: DebugMode = .none;
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

            if (settings.debug_mode == .material_ids) {
                const hue = @as(f32, @floatFromInt(obj.material_id)) / @as(f32, @floatFromInt(scene.materials.len));
                const col = csscolorparser.Color(f32).fromHsl(hue * 360, 1.0, 0.5, 1.0);
                break Color{
                    .a = col.alpha,
                    .r = col.red,
                    .g = col.green,
                    .b = col.blue,
                };
            }

            const mat = scene.materials[obj.material_id];

            const norm_vec = normal(obj.*, ray);

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

            if (recursion == 0)
                break diffuse;

            const reflection = reflect(direction.normalize(), norm_vec);
            march(&ray, reflection, settings.hit_distance * 1.1);
            const refl_color = raymarch(scene, ray, reflection, recursion - 1);

            const dot: f32 = @floatCast(@abs(norm_vec.normalize().dot(reflection)));
            const refl = 1 - dot * (1 - mat.reflectivity);

            if (settings.debug_mode == .mat_reflectivity)
                break Color{ .r = mat.reflectivity, .g = mat.reflectivity, .b = mat.reflectivity };

            if (settings.debug_mode == .actual_reflectivity)
                break Color{ .r = refl, .g = refl, .b = refl };

            if (settings.debug_mode == .dot)
                break Color{ .r = dot, .g = dot, .b = dot };

            break Color.mix(refl_color, diffuse, refl);
        }
        march(&ray, direction, distance - (settings.hit_distance * 0.9));
    } else Color{
        // TODO: return skybox color instead or default color
        .r = 1.0,
        .g = 1.0,
        .b = 1.0,
    };
}

pub fn render(_: std.mem.Allocator, io: std.Io, scene: Scene, canvas: Canvas, camera: Camera) !void {
    if (canvas.width == 0 or canvas.height == 0)
        return error.canvasWrongFormat;

    if (settings.preview) {
        std.debug.print("/!\\ Running in preview mode!\n", .{});
        settings.max_steps /= 2;
        settings.max_reflections /= 2;
        settings.hit_distance *= 2;
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

    var x: usize = 0;
    while (x < width) : (x += 1) {
        const x_f: f64 = @floatFromInt(x);
        const rx: f64 = (x_f - fwidth / 2.0) / fwidth;

        const direction = zlm.vec3(rx, ry, 1);
        var actual_dir = zlm.Vec3.zero;
        actual_dir = actual_dir.add(current_camera.getX().scale(direction.x));
        actual_dir = actual_dir.add(current_camera.getY().scale(-direction.y));
        actual_dir = actual_dir.add(current_camera.getZ().scale(direction.z));

        // TODO: the first distance from the camera is the same for every ray: optimize away the first closest search
        const col = raymarch(
            current_scene,
            current_camera.origin,
            actual_dir.normalize(),
            settings.max_reflections,
        );
        current_canvas.data[begin + x] = col;
    }
}

//Guillaume Derex 2020-2026
