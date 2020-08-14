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

    const canvas = try Image.init(allocator, 800, 600);
    defer canvas.deinit();

    std.debug.print("Preparing the scene...\n", .{});

    const red = Material{ .diffuse = color.Color{ .r = 1.0, .g = 0, .b = 0 }, .reflectivity = 0.5 };
    const green = Material{ .diffuse = color.Color{ .r = 0, .g = 1.0, .b = 0 }, .reflectivity = 0.5 };
    const blue = Material{ .diffuse = color.Color{ .r = 0, .g = 0, .b = 1.0 }, .reflectivity = 0.9 };

    const scene = try allocator.alloc(obj.Renderable, 3);
    defer allocator.free(scene);

    scene[0] = obj.Renderable.init(red, 
        try obj.Object.initTransform(
            allocator,
            try obj.Object.initPrimitive(allocator, primitive.sphere),
            Vec3.nul,
            Vec3.one,
            Vec3{ .x = 0, .y = -1, .z = 6 }
        )
    );
    defer scene[0].deinit(allocator);

    scene[1] = obj.Renderable.init(green, 
        try obj.Object.initTransform(
            allocator,
            try obj.Object.initPrimitive(allocator, primitive.plane),
            Vec3.nul,
            Vec3.one,
            Vec3{ .x = 0, .y = -1, .z = 0 }
        )
    );
    defer scene[1].deinit(allocator);

    scene[2] = obj.Renderable.init(blue, 
        try obj.Object.initTransform(
            allocator,
            try obj.Object.initPrimitive(allocator, primitive.sphere),
            Vec3.nul,
            Vec3.one,
            Vec3{ .x = 2, .y = 1, .z = 5 }
        )
    );
    defer scene[2].deinit(allocator);

    std.debug.print("Rendering...\n", .{});
    var timer = try std.time.Timer.start();
    try raymarcher.render(scene, canvas);
    std.debug.print("Render took {}ms.\n", .{timer.lap() / 1000000});

    try canvas.saveAsTGA(path);
    std.debug.print("File saved to {}.\n", .{path});
}

//Guillaume Derex 2020
