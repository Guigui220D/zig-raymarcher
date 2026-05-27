const std = @import("std");
const zlm = @import("zlm").as(f64);

//const scene_loader = @import("scene_loader.zig");
const default_scene = @import("default_scene.zig");
const raymarcher = @import("raymarcher.zig");
const Object = @import("object.zig").Object;
const Canvas = @import("Canvas.zig");
const Camera = @import("Camera.zig");
const Scene = @import("Scene.zig");

pub fn main(init: std.process.Init) !void {
    var allocator = init.gpa;
    const io = init.io;

    std.debug.print("Preparing the scene...\n", .{});

    Object.initArena(allocator);
    defer Object.freeArena();

    var scene: Scene = undefined;
    scene = try default_scene.get(allocator);
    defer allocator.free(scene.objects);
    defer allocator.free(scene.lights);

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

    var canvas = try Canvas.init(allocator, 1000, 1000);
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

        const path = try std.fmt.bufPrint(&pathbuf, "render/frame{:0>4}.tga", .{frame});

        std.debug.print("Rendering frame #{:0>4}...\n", .{frame});

        //try raymarcher.render(allocator, scene, canvas, cam, cores);
        try raymarcher.render(allocator, io, scene, canvas, .{});

        //std.debug.print("Adjusting colors...\n", .{});

        canvas.adjustColors();

        std.debug.print("Saving...\n", .{});

        try canvas.saveAsTGA(io, path);
        std.debug.print("Frame saved to {s}.\n", .{path});
    }
    //std.debug.print("Finished all frames. It took {}s.\n", .{timer.lap() / std.time.ns_per_s});
    std.debug.print("Finished all frames.\n", .{});
}

//Guillaume Derex 2020-2022
