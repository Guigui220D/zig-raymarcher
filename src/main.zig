const std = @import("std");
const raymarcher = @import("raymarcher.zig");
const Image = @import("image.zig").Image;
const obj = @import("object.zig");
const Material = @import("material.zig").Material;
const color = @import("color.zig");
usingnamespace @import("vector.zig");
const primitive = @import("primitives.zig");

const allocator = std.heap.page_allocator;

pub fn main() !void {
    const path = "test.tga";

    std.debug.print("Preparing the canvas...\n", .{});

    const canvas = try Image.init(allocator, 300, 300);
    defer canvas.deinit();

    std.debug.print("Preparing the scene...\n", .{});

    const red = Material{ .diffuse = color.Color{ .r = 1.0, .g = 0, .b = 0 }, .diffuse2 = color.Color{ .r = 0.5, .g = 0, .b = 0 }, .reflectivity = 0.5 };
    const green = Material{ .diffuse = color.Color{ .r = 0, .g = 0.7, .b = 0 }, .reflectivity = 0 };
    const blue = Material{ .diffuse = color.Color{ .r = 0, .g = 0, .b = 1.0 }, .reflectivity = 0.8 };
    const mirror = Material{ .diffuse = color.Color{ .r = 1.0, .g = 1.0, .b = 1.0 }, .reflectivity = 0.8 };

    const scene = try allocator.alloc(obj.Renderable, 3);
    defer allocator.free(scene);

    scene[0] = obj.Renderable.init(red, 
        try obj.Object.initTransform(
            allocator,
            try obj.Object.initPrimitive(allocator, primitive.plainPlane),
            Vec3.nul,
            Vec3.one,
            Vec3{ .x = 0, .y = -1, .z = 4 }
        ),
    );
    defer scene[0].deinit(allocator);

    scene[1] = obj.Renderable.init(blue, 
        try obj.Object.initTransform(
            allocator,
            try obj.Object.initCSG(
                allocator,
                try obj.Object.initCSG(
                    allocator,
                    try obj.Object.initTransform(
                        allocator,
                        try obj.Object.initPrimitive(allocator, primitive.sphere),
                        Vec3.nul,
                        Vec3{ .x = 1.2, .y = 1.2, .z = 1.2 },
                        Vec3.nul
                    ),
                    try obj.Object.initPrimitive(allocator, primitive.cube),
                    .intersectionSDF
                ),
                try obj.Object.initTransform(
                    allocator,
                    try obj.Object.initPrimitive(allocator, primitive.infCylinder),
                    Vec3{ .x = deg2rad(90), .y = 0, .z = 0 },
                    Vec3{ .x = 0.5, .y = 0.5, .z = 0.5 },
                    Vec3.nul
                ),
                .differenceSDF
            ),
            Vec3{ .x = deg2rad(10), .y = 0, .z = 0 },
            Vec3.one,
            Vec3{ .x = 1, .y = 0.5, .z = 7 }
        )
    );
    defer scene[1].deinit(allocator);

    scene[2] = obj.Renderable.init(mirror, 
        try obj.Object.initTransform(
            allocator,
            try obj.Object.initPrimitive(allocator, primitive.testWall),
            Vec3{ .x = deg2rad(10), .y = deg2rad(10), .z = 0 },
            Vec3.one,
            Vec3{ .x = 0, .y = 0, .z = 3 }
        )
    );
    defer scene[2].deinit(allocator);

    const cores =  4 * try std.Thread.cpuCount();

    std.debug.print("Rendering...\n", .{});
    var timer = try std.time.Timer.start();
    try raymarcher.render(allocator, scene[0..], canvas, cores);
    std.debug.print("Render took {}ms.\n", .{timer.lap() / 1000000});

    try canvas.saveAsTGA(path);
    std.debug.print("File saved to {s}.\n", .{path});
}

fn deg2rad(comptime deg: comptime_float) @TypeOf(deg) {
    return (deg / 180.0) * std.math.pi;
}

//Guillaume Derex 2020
