const std = @import("std");

const z = @import("zlm");
const zlm = z.SpecializeOn(f64);

const raymarcher = @import("raymarcher.zig");
const primitive = @import("primitives.zig");
const Color = @import("color.zig").Color;
const Object = @import("object.zig").Object;
const Image = @import("Image.zig");
const Renderable = @import("Renderable.zig");
const Material = @import("Material.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    Object.initArena(allocator);
    defer Object.freeArena();

    // TODO: use arena allocator for scene
    // TODO: animation
    // TODO: refactor classes and remove useless ones
    // TODO: scene from json
    // TODO: update footers
    const path = "test.tga";

    std.debug.print("Preparing the canvas...\n", .{});

    const canvas = try Image.init(allocator, 300, 300);
    defer canvas.deinit();

    std.debug.print("Preparing the scene...\n", .{});

    const red = Material{ .diffuse = Color{ .r = 1.0, .g = 0, .b = 0 }, .diffuse2 = Color{ .r = 0.5, .g = 0, .b = 0 }, .reflectivity = 0.5 };
    //const green = Material{ .diffuse = Color{ .r = 0, .g = 0.7, .b = 0 }, .reflectivity = 0 };
    const blue = Material{ .diffuse = Color{ .r = 0, .g = 0, .b = 1.0 }, .reflectivity = 0.8 };
    const mirror = Material{ .diffuse = Color{ .r = 1.0, .g = 1.0, .b = 1.0 }, .reflectivity = 0.8 };

    var scene: [3]Renderable = undefined;

    scene[0] = .{
        .material = red, 
        .object = try Object.initTransform(
            try Object.initPrimitive(primitive.plainPlane),
            zlm.Vec3.zero,
            zlm.Vec3.one,
            zlm.vec3(0, -1, 4)
        ),
    };

    scene[1] = .{
        .material = blue, 
        .object = try Object.initTransform(
            try Object.initCSG(
                try Object.initCSG(
                    try Object.initTransform(
                        try Object.initPrimitive(primitive.sphere),
                        zlm.Vec3.zero,
                        zlm.Vec3.all(1.2),
                        zlm.Vec3.zero
                    ),
                    try Object.initPrimitive(primitive.cube),
                    .intersectionSDF
                ),
                try Object.initTransform(
                    try Object.initPrimitive(primitive.infCylinder),
                    zlm.vec3(z.toRadians(90.0), 0, 0),
                    zlm.Vec3.all(0.5),
                    zlm.Vec3.zero
                ),
                .differenceSDF
            ),
            zlm.vec3(z.toRadians(10.0), 0, 0),
            zlm.Vec3.one,
            zlm.vec3(1, 0.5, 7)
        )
    };

    scene[2] = .{
        .material = mirror, 
        .object = try Object.initTransform(
            try Object.initPrimitive(primitive.testWall),
            zlm.vec3(z.toRadians(10.0), z.toRadians(10.0), 0),
            zlm.Vec3.one,
            zlm.vec3(0, 0, 3)
        )
    };

    const cores = 4 * try std.Thread.getCpuCount();

    std.debug.print("Rendering...\n", .{});
    var timer = try std.time.Timer.start();
    try raymarcher.render(allocator, &scene, canvas, cores);
    std.debug.print("Render took {}ms.\n", .{timer.lap() / 1000000});

    try canvas.saveAsTGA(path);
    std.debug.print("File saved to {s}.\n", .{path});
}

//Guillaume Derex 2020
