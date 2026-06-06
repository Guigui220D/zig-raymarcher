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

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;

    { // Check arguments
        var it = init.minimal.args.iterate();
        while (it.next()) |arg| {
            if (std.ascii.eqlIgnoreCase(arg, "preview"))
                raymarcher.settings.preview = true;
        }
    }

    { // Try to create render folder
        const cwd = std.Io.Dir.cwd();
        cwd.createDir(io, "render", .default_dir) catch {};
    }

    std.debug.print("Preparing the scene...\n", .{});

    const scene: Scene = try scene_loader.loadScene(alloc, io, "scenes/test_scene.json");
    defer scene.deinit();

    // What should be in the scene file: everything describing geometry
    //  primitives, combinations, materials
    // What should be in render setup file:
    //  canvas size, iterations, camera position/path, render settings
    // What should be as args: things regarding performance, output place, and overrides
    //  threads count, override iterations

    // TODO: skyboxes
    // TODO: png output
    // TODO: better prints (not debug)
    // TODO: matrix transforms
    var pathbuf: [512]u8 = undefined;

    var canvas = try Canvas.init(alloc, 1000, 1000);
    defer canvas.deinit();

    var cam = Camera{};
    const point_a = zlm.Vec3.zero;
    const point_b = zlm.vec3(-4, 1, 3);

    //var timer = try std.time.Timer.start();

    var frame: usize = 0;
    const n = 1;
    while (frame < n) : (frame += 1) {
        const lerp = @as(f32, @floatFromInt(frame)) / @as(f32, @floatFromInt(n));
        const campos = zlm.Vec3.lerp(point_a, point_b, lerp);
        const camdir = zlm.vec3(0, -0.5, 1).sub(campos);
        cam.origin = campos;
        cam.direction = camdir;

        const path = try std.fmt.bufPrint(&pathbuf, "render/frame{:0>4}.png", .{frame});

        std.debug.print("Rendering frame #{:0>4}...\n", .{frame});

        try raymarcher.render(alloc, io, scene, canvas, .{});

        //std.debug.print("Adjusting colors...\n", .{});
        canvas.adjustColors();

        std.debug.print("Saving...\n", .{});
        try image_save.saveAs(alloc, io, &canvas, path);
        std.debug.print("Frame saved to {s}.\n", .{path});
    }
    //std.debug.print("Finished all frames. It took {}s.\n", .{timer.lap() / std.time.ns_per_s});
    std.debug.print("Finished all frames.\n", .{});
}

//Guillaume Derex 2020-2026
