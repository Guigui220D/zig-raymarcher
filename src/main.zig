const std = @import("std");

const scene_loader = @import("scene_loader.zig");
const default_scene = @import("default_scene.zig");
const raymarcher = @import("raymarcher.zig");
const Object = @import("object.zig").Object;
const Image = @import("Image.zig");
const Renderable = @import("Renderable.zig");

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

    // TODO: animation
    // TODO: update footers
    // TODO: bigger workloads for threads
    // TODO: skyboxes
    // TODO: png support
    // TODO: better prints (not debug)
    // TODO: matrix transforms
    const path = "test.tga";

    std.debug.print("Preparing the canvas...\n", .{});

    const canvas = try Image.init(allocator, 500, 500);
    defer canvas.deinit();

    std.debug.print("Rendering with {} threads...\n", .{cores});
    var timer = try std.time.Timer.start();
    try raymarcher.render(allocator, scene, canvas, .{ .direction = .{ .x = 1, .y = -0.5, .z = 1 } }, cores);
    std.debug.print("Render took {}s.\n", .{timer.lap() / std.time.ns_per_s});

    try canvas.saveAsTGA(path);
    std.debug.print("File saved to {s}.\n", .{path});
}



//Guillaume Derex 2020
