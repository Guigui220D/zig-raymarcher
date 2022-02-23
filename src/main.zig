const std = @import("std");
const z = @import("zlm");
const zlm = z.SpecializeOn(f64);
const raymarcher = @import("raymarcher.zig");
const Image = @import("image.zig").Image;
const Renderable = @import("Renderable.zig");
const obj = @import("object.zig");
const Material = @import("Material.zig");
const color = @import("color.zig");
const primitive = @import("primitives.zig");

const allocator = std.heap.page_allocator;

pub fn main() !void {
    // TODO: use arena allocator for scene
    // TODO: threads
    // TODO: animation
    // TODO: use a math lib
    // TODO: refactor classes and remove useless ones
    // TODO: scene from json
    // TODO: update footers
    const path = "test.tga";

    std.debug.print("Preparing the canvas...\n", .{});

    const canvas = try Image.init(allocator, 300, 300);
    defer canvas.deinit();

    std.debug.print("Preparing the scene...\n", .{});

    const red = Material{ .diffuse = color.Color{ .r = 1.0, .g = 0, .b = 0 }, .diffuse2 = color.Color{ .r = 0.5, .g = 0, .b = 0 }, .reflectivity = 0.5 };
    //const green = Material{ .diffuse = color.Color{ .r = 0, .g = 0.7, .b = 0 }, .reflectivity = 0 };
    const blue = Material{ .diffuse = color.Color{ .r = 0, .g = 0, .b = 1.0 }, .reflectivity = 0.8 };
    const mirror = Material{ .diffuse = color.Color{ .r = 1.0, .g = 1.0, .b = 1.0 }, .reflectivity = 0.8 };

    const scene = try allocator.alloc(Renderable, 3);
    defer allocator.free(scene);

    scene[0] = Renderable.init(red, 
        try obj.Object.initTransform(
            allocator,
            try obj.Object.initPrimitive(allocator, primitive.plainPlane),
            zlm.Vec3.zero,
            zlm.Vec3.one,
            zlm.vec3(0, -1, 4)
        ),
    );
    defer scene[0].deinit(allocator);

    scene[1] = Renderable.init(blue, 
        try obj.Object.initTransform(
            allocator,
            try obj.Object.initCSG(
                allocator,
                try obj.Object.initCSG(
                    allocator,
                    try obj.Object.initTransform(
                        allocator,
                        try obj.Object.initPrimitive(allocator, primitive.sphere),
                        zlm.Vec3.zero,
                        zlm.Vec3.all(1.2),
                        zlm.Vec3.zero
                    ),
                    try obj.Object.initPrimitive(allocator, primitive.cube),
                    .intersectionSDF
                ),
                try obj.Object.initTransform(
                    allocator,
                    try obj.Object.initPrimitive(allocator, primitive.infCylinder),
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
    );
    defer scene[1].deinit(allocator);

    scene[2] = Renderable.init(mirror, 
        try obj.Object.initTransform(
            allocator,
            try obj.Object.initPrimitive(allocator, primitive.testWall),
            zlm.vec3(z.toRadians(10.0), z.toRadians(10.0), 0),
            zlm.Vec3.one,
            zlm.vec3(0, 0, 3)
        )
    );
    defer scene[2].deinit(allocator);

    const cores = 4 * try std.Thread.getCpuCount();

    std.debug.print("Rendering...\n", .{});
    var timer = try std.time.Timer.start();
    try raymarcher.render(allocator, scene[0..], canvas, cores);
    std.debug.print("Render took {}ms.\n", .{timer.lap() / 1000000});

    try canvas.saveAsTGA(path);
    std.debug.print("File saved to {s}.\n", .{path});
}

//Guillaume Derex 2020
