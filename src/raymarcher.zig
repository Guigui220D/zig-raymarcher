const zlm = @import("zlm").as(f64);
const std = @import("std");
const math = std.math;

const Scene = @import("Scene.zig");
const Renderable = @import("Renderable.zig");
const Color = @import("color.zig").Color;
const Canvas = @import("Canvas.zig");
const Camera = @import("Camera.zig");
const csscolorparser = @import("csscolorparser");
const Skybox = @import("Skybox.zig");
const Ray = @import("Ray.zig");
const RayLoad = @import("RayLoad.zig");

const settings = @import("settings.zig");

var current_scene: Scene = undefined;
var current_canvas: Canvas = undefined;
var current_camera: Camera = .{};
var current_skybox: *const Skybox = undefined;

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

pub fn render(alloc: std.mem.Allocator, io: std.Io, scene: Scene, canvas: Canvas, camera: Camera, skybox: *const Skybox) !void {
    if (canvas.width == 0 or canvas.height == 0)
        return error.canvasWrongFormat;

    // TODO: do that somewhere else...
    if (settings.preview) {
        std.debug.print("/!\\ Running in preview mode!\n", .{});
        settings.max_steps /= 2;
        settings.max_reflections = 1;
        settings.max_steps_getting_closer = settings.max_steps * 2;
        settings.hit_distance *= 2;
    }

    current_scene = scene;
    current_canvas = canvas;
    current_camera = camera;
    current_skybox = skybox;

    // Init one ray per pixel
    var rayload: RayLoad = try .init(alloc, &canvas, &camera);
    defer rayload.deinit();

    var i: usize = 0;

    const clock: std.Io.Clock = .real;
    const start = std.Io.Timestamp.now(io, clock);

    // Progress each ray that exists once
    while (rayload.hasWork()) {
        // For each object, update the rays distance
        for (scene.objects) |scene_obj| {
            // TODO: avoid computing distance for rays that already hit
            rayload.computeDistances(&scene_obj);
        }

        // Progress each ray based on the distances we found (or collapse results)
        try rayload.update();

        i += 1;
    }

    const dur = std.Io.Timestamp.untilNow(start, io, clock);

    std.debug.print("Iterations: {}\n", .{i});
    std.debug.print("Duration: {} ms\n", .{dur.toMilliseconds()});
}

//Guillaume Derex 2020-2026
