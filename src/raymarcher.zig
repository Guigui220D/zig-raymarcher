//! Raymarcher file, the root of functions to raymarch
const std = @import("std");
const math = std.math;

const csscolorparser = @import("csscolorparser");

const Camera = @import("Camera.zig");
const Canvas = @import("Canvas.zig");
const Color = @import("color.zig").Color;
const Ray = @import("Ray.zig");
const RayLoad = @import("RayLoad.zig");
const Renderable = @import("Renderable.zig");
const Scene = @import("Scene.zig");
const Skybox = @import("Skybox.zig");
const Settings = @import("Settings.zig");

var current_scene: Scene = undefined;
var current_canvas: Canvas = undefined;
var current_camera: Camera = .{};
var current_skybox: *const Skybox = undefined;

/// Renders a scene to a canvas
pub fn render(alloc: std.mem.Allocator, io: std.Io, scene: Scene, canvas: Canvas, camera: Camera, skybox: *const Skybox, parent_node: std.Progress.Node) !i64 {
    if (canvas.width == 0 or canvas.height == 0)
        return error.canvasWrongFormat;

    current_scene = scene;
    current_canvas = canvas;
    current_camera = camera;
    current_skybox = skybox;

    const cwd = std.Io.Dir.cwd();
    var file = try cwd.createFile(io, "report.csv", .{});
    defer file.close(io);
    var buf: [512]u8 = undefined;

    var fwriter = file.writer(io, &buf);
    const writer = &fwriter.interface;

    // Init one ray per pixel
    var rayload: RayLoad = try .init(
        alloc,
        &canvas,
        &camera,
        &scene,
        if (Settings.report_rayload_composition) writer else null,
    );
    defer rayload.deinit();

    var total_rays = rayload.rays.len;
    var progress_node = parent_node.start("Render frame", total_rays);

    var i: usize = 0;

    const clock: std.Io.Clock = .real;
    const start = std.Io.Timestamp.now(io, clock);

    while (try rayload.refillFromCanvas()) {
        // Progress each ray that exists once
        while (rayload.hasWork()) {
            // Do several steps before checking to save some ressources
            for (0..Settings.steps_per_check) |_| {
                // For each object, update the rays distance
                rayload.computeDistances();

                // Then advance them
                rayload.advance();
            }

            // Progress each ray based on the distances we found (or collapse results)
            try rayload.update(io, clock);

            // Update progress bar
            {
                const current_ray_count = rayload.rays.len;
                if (current_ray_count > total_rays) {
                    total_rays = current_ray_count;
                    progress_node.increaseEstimatedTotalItems(total_rays);
                }
                progress_node.setCompletedItems(total_rays - current_ray_count);
            }

            i += 1;
        }
    }

    progress_node.end();

    const dur = std.Io.Timestamp.untilNow(start, io, clock);

    return dur.toMicroseconds();
}

// Copyright Guillaume Derex 2020-2026 (GPL-3.0)
