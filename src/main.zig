const std = @import("std");
const zlm = @import("zlm").SpecializeOn(f64);

//const scene_loader = @import("scene_loader.zig");
const default_scene = @import("default_scene.zig");
const raymarcher = @import("raymarcher.zig");
const Object = @import("object.zig").Object;
const Image = @import("Image.zig");
const Camera = @import("Camera.zig");
const Scene = @import("Scene.zig");

pub fn main() !void {
    // Allocator
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Threads count argument
    var cores = 4 * try std.Thread.getCpuCount();
    
    std.debug.print("Preparing the scene...\n", .{});

    Object.initArena(allocator);
    defer Object.freeArena();

    var scene: []Renderable = undefined;
    scene = try default_scene.get(allocator);
    defer allocator.free(scene);

    // What should be in the scene file: everything needed for a deterministic render
    //  canvas size, materials, iterations
    // What should be as args: things regarding performance, output place, and overrides
    //  threads count, override iterations

    // TODO: skyboxes
    // TODO: png output
    // TODO: better prints (not debug)
    // TODO: matrix transforms
    var pathbuf: [512]u8 = undefined;
    const canvas = try Image.init(allocator, 720, 576);
    defer canvas.deinit();
    var cam = Camera{};
    var point_a = zlm.Vec3.zero;
    var point_b = zlm.vec3(-4, 1, 3);

    var timer = try std.time.Timer.start();

    var frame: usize = 0;
    const n = 1;
    while (frame < n) : (frame += 1) {
        const lerp = @intToFloat(f32, frame) / @intToFloat(f32, n);
        const campos = zlm.Vec3.lerp(point_a, point_b, lerp);
        const camdir = zlm.vec3(0, -0.5, 1).sub(campos);
        cam.origin = campos;
        cam.direction = camdir;

        const path = try std.fmt.bufPrint(&pathbuf, "render/frame{:0>4}.tga", .{frame});

        std.debug.print("Rendering frame #{:0>4} with {} threads...\n", .{frame, cores});
        
        //try raymarcher.render(allocator, scene, canvas, cam, cores);
        try raymarcher.render(allocator, scene, canvas, .{}, cores);
        
        try canvas.saveAsTGA(path);
        std.debug.print("Frame saved to {s}.\n", .{path});
    }
    std.debug.print("Finished all frames. It took {}s.\n", .{timer.lap() / std.time.ns_per_s});
}

//Guillaume Derex 2020-2022
