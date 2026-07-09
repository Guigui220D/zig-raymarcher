const std = @import("std");
const zlm = @import("zlm").as(f64);

//const scene_loader = @import("scene_loader.zig");
const scene_loader = @import("scene_loader.zig");
const raymarcher = @import("raymarcher.zig");
const Object = @import("object.zig").Object;
const Canvas = @import("Canvas.zig");
const image_save = @import("image_save.zig");
const Camera = @import("Camera.zig");
const Scene = @import("Scene.zig");
const Skybox = @import("Skybox.zig");
const settings = @import("settings.zig");

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

// TODO: use logger

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;

    var scene_path: []const u8 = "scenes/default_scene.json";

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

    std.debug.print("Scene path: {s}\n", .{scene_path});

    { // Try to create render folder
        const cwd = std.Io.Dir.cwd();
        cwd.createDir(io, "render", .default_dir) catch {};
    }

    std.debug.print("Preparing the scene...\n", .{});

    const scene: Scene = try scene_loader.loadScene(alloc, io, scene_path);
    defer scene.deinit();

    // TODO: make configurable (no hardcode)
    var skybox: Skybox = try .init(alloc, io, "ressources/Yokohama2");
    defer skybox.deinit(alloc);

    // What should be in the scene file: everything describing geometry
    //  primitives, combinations, materials
    // What should be in render setup file:
    //  canvas size, iterations, camera position/path, render settings
    // What should be as args: things regarding performance, output place, and overrides
    //  threads count, override iterations

    // TODO: better prints (not debug)
    // TODO: matrix transforms

    var cam = Camera{};

    //var timer = try std.time.Timer.start();
    const campos = zlm.Vec3.zero;
    const camdir = zlm.vec3(0, -0.5, 1).sub(campos);
    cam.origin = campos;
    cam.direction = camdir;

    std.debug.print("Rendering frame...\n", .{});

    if (settings.benchmark) {
        var canvas = try Canvas.init(alloc, 200, 200);
        defer canvas.deinit();

        std.debug.print("Benchmarking!\nWarmup...\n", .{});
        // Warmup run
        _ = try raymarcher.render(alloc, io, scene, canvas, .{}, &skybox);

        std.debug.print("Doing {} runs...\n", .{settings.benchmark_it});
        var sum: i64 = 0;
        for (0..settings.benchmark_it) |_| {
            sum += try raymarcher.render(alloc, io, scene, canvas, .{}, &skybox);
        }
        std.debug.print("Done! Avg {} ms per run\n", .{@divFloor(sum, @as(i64, @intCast(settings.benchmark_it)) * 1000)});
    } else {
        var canvas = try Canvas.init(alloc, 1000, 1000);
        defer canvas.deinit();

        _ = try raymarcher.render(alloc, io, scene, canvas, .{}, &skybox);

        //std.debug.print("Adjusting colors...\n", .{});
        canvas.adjustColors();

        std.debug.print("Saving...\n", .{});
        try image_save.saveAs(alloc, io, &canvas, "render/frame.jpg");
        std.debug.print("Frame saved to render/frame.jpg.\n", .{});
    }
}

//Guillaume Derex 2020-2026
