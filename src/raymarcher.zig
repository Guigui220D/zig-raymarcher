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

pub fn render(alloc: std.mem.Allocator, io: std.Io, scene: Scene, canvas: Canvas, camera: Camera, skybox: *const Skybox) !i64 {
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
    var rayload: RayLoad = try .init(alloc, &canvas, &camera, scene.objects, scene.materials);
    defer rayload.deinit();

    var i: usize = 0;

    const clock: std.Io.Clock = .real;
    const start = std.Io.Timestamp.now(io, clock);

    while (try rayload.refillFromCanvas()) {
        // Progress each ray that exists once
        while (rayload.hasWork()) {
            // For each object, update the rays distance
            rayload.computeDistances();

            // Progress each ray based on the distances we found (or collapse results)
            try rayload.update();

            i += 1;
        }
    }

    const dur = std.Io.Timestamp.untilNow(start, io, clock);

    return dur.toMicroseconds();
}

//Guillaume Derex 2020-2026
