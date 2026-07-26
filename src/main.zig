const std = @import("std");
const zlm = @import("zlm").as(Ft);

const scene_loader = @import("scene_loader.zig");
const raymarcher = @import("raymarcher.zig");
const Object = @import("object.zig").Object;
const Canvas = @import("Canvas.zig");
const image_save = @import("image_save.zig");
const Camera = @import("Camera.zig");
const Scene = @import("Scene.zig");
const Skybox = @import("Skybox.zig");
const settings = @import("settings.zig");
const Ft = settings.Ft;
const CssColor = @import("csscolorparser").Color(f32);

pub const tracy_impl = @import("tracy_impl");

pub const tracy = @import("tracy");
pub const tracy_options: tracy.Options = .{
    .on_demand = false,
    .no_broadcast = false,
    .only_localhost = false,
    .only_ipv4 = false,
    .delayed_init = false,
    .manual_lifetime = false,
    .verbose = false,
    .data_port = null,
    .broadcast_port = null,
    .default_callstack_depth = 0,
};

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;

    var scene_path: []const u8 = "scenes/default_scene.json";

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
                settings.preview = true;
            } else if (std.ascii.eqlIgnoreCase(arg, "benchmark")) {
                settings.benchmark = true;
            } else {
                scene_path = arg;
            }
        }
    }

    // TODO: do that elsewhere
    if (settings.preview) {
        std.log.warn("Running in preview mode!", .{});
        settings.max_steps /= 2;
        settings.max_recursions /= 2;
        settings.max_steps_getting_closer = settings.max_steps * 2;
        settings.hit_distance *= 2;
        settings.pic_height /= 2;
        settings.pic_width /= 2;
    }

    const node = std.Progress.start(io, .{ .root_name = "render", .disable_printing = false });
    settings.reportSettings();

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

    if (settings.benchmark) {
        var canvas = try Canvas.init(alloc, 200, 200);
        defer canvas.deinit();

        std.log.info("Benchmarking!", .{});
        std.log.info("Warmup...", .{});
        // Warmup run
        _ = try raymarcher.render(alloc, io, scene, canvas, .{}, &skybox, node);

        std.log.info("Doing {} runs...", .{settings.benchmark_it});
        var sum: i64 = 0;
        for (0..settings.benchmark_it) |_| {
            sum += try raymarcher.render(alloc, io, scene, canvas, .{}, &skybox, node);
        }
        std.log.info("Done! Avg {} ms per run", .{@divFloor(sum, @as(i64, @intCast(settings.benchmark_it)) * 1000)});
    } else {
        var canvas = try Canvas.init(alloc, settings.pic_width, settings.pic_height);
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
