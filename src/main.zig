//! Entry point
const std = @import("std");

pub const tracy = @import("tracy");
pub const tracy_impl = @import("tracy_impl");

const Camera = @import("Camera.zig");
const Canvas = @import("Canvas.zig");
const types = @import("types.zig");
const Ft = types.Ft;
const image_save = @import("image_save.zig");
const Object = @import("object.zig").Object;
const raymarcher = @import("raymarcher.zig");
const Scene = @import("Scene.zig");
const scene_loader = @import("scene_loader.zig");
const Settings = @import("Settings.zig");
const Skybox = @import("Skybox.zig");

const zlm = @import("zlm").as(Ft);

const CssColor = @import("csscolorparser").Color(f32);

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;

    var scene_path: []const u8 = "scenes/default_scene.json";

    var preview_mode: bool = false;
    var benchmark_mode: bool = false;
    // TODO: add an argument parsing library
    { // Check arguments
        var first = true;
        var it = init.minimal.args.iterate();
        while (it.next()) |arg| {
            if (first) {
                first = false;
                continue;
            }
            if (std.ascii.eqlIgnoreCase(arg, "preview")) {
                preview_mode = true;
            } else if (std.ascii.eqlIgnoreCase(arg, "benchmark")) {
                benchmark_mode = true;
            } else {
                scene_path = arg;
            }
        }
    }

    // Select settings
    // TODO: settings from file
    if (preview_mode) {
        if (benchmark_mode) {
            std.log.err("Can't use both preview and benchmark modes!", .{});
            return;
        }
        std.log.warn("Running in preview mode!", .{});
        Settings.current = Settings.preview;
    }

    if (benchmark_mode) {
        std.log.warn("Running in benchmark mode", .{});
        Settings.current = Settings.benchmark;
    }

    // Report settings
    std.log.debug("Vector length: {}", .{types.vec_len});
    Settings.current.reportSettings();

    const node = std.Progress.start(io, .{ .root_name = "Render", .disable_printing = false });
    defer node.end();

    std.log.info("Scene path: {s}", .{scene_path});

    { // Try to create render folder
        const cwd = std.Io.Dir.cwd();
        cwd.createDir(io, "render", .default_dir) catch {};
    }

    std.log.info("Preparing the scene...", .{});

    const scene: Scene = try scene_loader.loadSceneFromPath(alloc, io, scene_path);
    defer scene.deinit();

    // TODO: make configurable (no hardcode)
    var skybox: Skybox = try .initColor(alloc, io, try CssColor.parse("blue"));
    defer skybox.deinit(alloc);

    // What should be in the scene file: everything describing geometry
    //  primitives, combinations, materials
    // What should be in render setup file:
    //  canvas size, iterations, camera position/path, render settings
    // What should be as args: things regarding performance, output place, and overrides
    //  threads count, override iterations

    // TODO: better prints (not debug)
    var cam = Camera{};

    const campos = zlm.Vec3.zero;
    const camdir = zlm.vec3(0, -0.5, 1).sub(campos);
    cam.origin = campos;
    cam.direction = camdir;

    std.log.info("Rendering frame...", .{});

    if (benchmark_mode) {
        var canvas = try Canvas.init(alloc, 200, 200);
        defer canvas.deinit();

        std.log.info("Benchmarking!", .{});
        std.log.info("Warmup...", .{});
        // Warmup run
        const warmup_time = try raymarcher.render(alloc, io, scene, canvas, .{}, &skybox, node);
        std.log.debug("Benchmark done ({} ms)", .{@divFloor(warmup_time, 1000)});

        std.log.info("Doing {} runs...", .{Settings.benchmark_it});
        var sum: i64 = 0;
        for (0..Settings.benchmark_it) |i| {
            const time = try raymarcher.render(alloc, io, scene, canvas, .{}, &skybox, node);
            sum += time;
            std.log.debug("Run #{} done ({} ms)", .{ i, @divFloor(time, 1000) });
        }
        std.log.info("Done! Avg {} ms per run", .{@divFloor(sum, @as(i64, @intCast(Settings.benchmark_it)) * 1000)});
    } else {
        var canvas = try Canvas.init(alloc, Settings.current.pic_width, Settings.current.pic_height);
        defer canvas.deinit();

        const time = try raymarcher.render(alloc, io, scene, canvas, .{}, &skybox, node);

        std.log.info("Done in {} ms", .{@divFloor(time, 1000)});
        canvas.adjustColors();

        std.log.info("Saving...", .{});
        // TODO: by default, include date in file output name
        // TODO: make a text file with metadata on the picture? settings, performance etc
        try image_save.saveAs(alloc, io, &canvas, "render/frame.png");
        std.log.info("Frame saved to render/frame.png.", .{});
    }
}

//Guillaume Derex 2020-2026
