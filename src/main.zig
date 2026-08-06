//! Entry point
const std = @import("std");

const clap = @import("clap");

const Camera = @import("Camera.zig");
const Canvas = @import("Canvas.zig");
const image_save = @import("image_save.zig");
const Object = @import("object.zig").Object;
const raymarcher = @import("raymarcher.zig");
const Scene = @import("Scene.zig");
const scene_loader = @import("scene_loader.zig");
const Settings = @import("Settings.zig");
const Skybox = @import("Skybox.zig");
const types = @import("types.zig");
const Ft = types.Ft;

const zlm = @import("zlm").as(Ft);

const CssColor = @import("csscolorparser").Color(f32);

/// Program arguments, used both as help and parsed by clap
const args_description =
    \\-h, --help             Display this help and exit.
    \\-s, --scene <str>      Scene json that will be rendered. Otherwise a default test scene will be used
    \\-o, --output <str>     Path of the output file that will be generated. Extension defines the file format
    \\-b, --benchmark        Enable benchmark mode: image will be rendered 5 times, no render image will occur
    \\-p, --preview          Use much lower image quality settings to preview scene geometry
    \\-H, --hit-dist <f64>   Distance at which we consider a hit happened
    \\-S, --steps <usize>    Maximum number of steps per ray
    \\-r, --recurse <usize>  Maximum number of recursions per ray
    \\-w, --width <usize>    Width of the output in pixels
    \\-h, --height <usize>   Height of the output in pixels
    \\-i, --iterations <u8>  Iterations of the benchmak (not including warmup)
    \\-c, --contrib <f64>    Percentage of a contribution we consider a ray useless
    \\-a, --steps-check <u8> Number of steps before each check
;

/// Entry point
pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;

    std.debug.print("\n{s}\n", .{@embedFile("splash.txt")});
    std.debug.print("Randonnée: Optimized Zig CPU Raymarcher\n", .{});
    std.debug.print("Version {f}\n\n", .{Settings.version});

    // Parse command line arguments
    const params = comptime clap.parseParamsComptime(args_description);
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, init.minimal.args, .{
        .diagnostic = &diag,
        .allocator = init.gpa,
    }) catch |err| {
        // Report useful error and exit.
        try diag.reportToFile(init.io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    // Print help
    if (res.args.help != 0) {
        std.debug.print("{s}\n", .{args_description});
        return;
    }

    std.log.info("Starting!", .{});

    // Select settings
    const preview_mode = res.args.preview != 0;
    const benchmark_mode = res.args.benchmark != 0;
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
        if (res.args.output) |_|
            std.log.warn("An output path was specified but benchmark mode won't produce an image", .{});
        std.log.warn("Running in benchmark mode", .{});
        Settings.current = Settings.benchmark;
    }

    // Setting overrides
    var settings_overridden = false;
    if (res.args.@"hit-dist") |hit_dist| {
        Settings.current.hit_distance = @floatCast(hit_dist);
        settings_overridden = true;
    }
    if (res.args.steps) |steps| {
        Settings.current.max_steps = steps;
        Settings.current.max_steps_getting_closer = steps * 2;
        settings_overridden = true;
    }
    if (res.args.recurse) |recurse| {
        Settings.current.max_recursions = @intCast(recurse);
        settings_overridden = true;
    }
    if (res.args.width) |width| {
        Settings.current.pic_width = width;
        settings_overridden = true;
    }
    if (res.args.height) |height| {
        Settings.current.pic_height = height;
        settings_overridden = true;
    }
    if (res.args.contrib) |contrib| {
        Settings.current.min_contribution = @floatCast(contrib);
        settings_overridden = true;
    }
    if (res.args.iterations) |iterations| {
        Settings.benchmark_it = iterations;
    }
    if (res.args.@"steps-check") |steps_check| {
        Settings.steps_per_check = steps_check;
    }

    if (settings_overridden)
        Settings.current.name = "custom";

    // Select input and output
    const scene_path = res.args.scene orelse null;
    const default_output_path = try defaultOutputPath(alloc, io);
    defer alloc.free(default_output_path);
    const output_path = res.args.output orelse default_output_path;

    // Report settings
    std.log.debug("Vector length: {}", .{types.vec_len});
    Settings.current.reportSettings();

    const node = std.Progress.start(io, .{ .root_name = "Render", .disable_printing = false });
    defer node.end();

    std.log.info("Scene path: {s}", .{scene_path orelse "none (default scene)"});

    std.log.info("Preparing the scene...", .{});

    const scene: Scene = if (scene_path) |path|
        try scene_loader.loadSceneFromPath(alloc, io, path)
    else
        try scene_loader.loadSceneFromString(alloc, @embedFile("default_scene.json"));
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
        try image_save.saveAs(alloc, io, &canvas, output_path);
        std.log.info("Frame saved to {s}.", .{output_path});
    }

    std.log.info("Goobye.", .{});
}

/// Returns the suggested output path
/// Caller must dealloc
pub fn defaultOutputPath(alloc: std.mem.Allocator, io: std.Io) ![]const u8 {
    const timestamp = std.Io.Clock.real.now(io);
    return try std.fmt.allocPrint(alloc, "{}.png", .{timestamp.toSeconds()});
}

// Copyright (C) 2026 Guillaume DEREX

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.
