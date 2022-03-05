const std = @import("std");
const args_parser = @import("args");
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

    var scene: Scene = undefined;
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
