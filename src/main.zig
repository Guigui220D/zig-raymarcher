const std = @import("std");
const args_parser = @import("args");

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

    // Arguments parsing
    const args = args_parser.parseForCurrentProcess(struct {
        // This declares long options for double hyphen
        output: []const u8 = "test.tga",
        threads: ?usize = null,
        scene: ?[]const u8 = null,
        preview: bool = false,

        // This declares short-hand options for single hyphen
        pub const shorthands = .{
            .o = "output",
            .t = "threads",
            .s = "scene",
            .p = "preview",
        };
    }, allocator, .print) catch return;
    defer args.deinit();

    raymarcher.settings.preview = args.options.preview;

    // Threads count argument
    var cores = 4 * try std.Thread.getCpuCount();
    if (args.options.threads) |t| {
        if (t == 0) {
            cores = 1;
        } else if (t > 256) {
            std.debug.print("Threads count too big, defaulting to {}.\n", .{cores});
        } else
            cores = t;
    }
    
    std.debug.print("Preparing the scene...\n", .{});

    Object.initArena(allocator);
    defer Object.freeArena();

    var scene: []Renderable = undefined;
    if (args.options.scene) |scene_file| {
        _ = scene_file;
        @panic("not implemented yet");
    } else {
        scene = try default_scene.get(allocator);
        //scene = try scene_loader.loadSceneFromJson(@embedFile("test_scene.json"), allocator);
    }
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
