
const std = @import("std");
const z = @import("zlm");
const zlm = z.SpecializeOn(f64);
const primitive = @import("primitives.zig");
const Color = @import("color.zig").Color;
const Object = @import("object.zig").Object;
const Renderable = @import("Renderable.zig");
const Material = @import("Material.zig");

pub fn get(alloc: std.mem.Allocator) ![]Renderable {
    const red = Material{ .diffuse = Color{ .r = 1.0, .g = 0, .b = 0 }, .diffuse2 = Color{ .r = 0.5, .g = 0, .b = 0 }, .reflectivity = 0.5 };
    const green = Material{ .diffuse = Color{ .r = 0, .g = 0.7, .b = 0 }, .reflectivity = 0 };
    const blue = Material{ .diffuse = Color{ .r = 0, .g = 0, .b = 1.0 }, .reflectivity = 0.8 };
    const mirror = Material{ .diffuse = Color{ .r = 1.0, .g = 1.0, .b = 1.0 }, .reflectivity = 0.8 };

    var scene: [4]Renderable = undefined;

    scene[0] = .{
        .material = red, 
        .object = try Object.initTransform(
            try Object.initCSG(
                try Object.initPrimitive(primitive.half),
                try Object.initTransform(
                    try Object.initPrimitive(primitive.cylinder),
                    zlm.Vec3.zero,
                    zlm.Vec3.all(7),
                    zlm.Vec3.zero
                ),
                .differenceSDF
            ),
            zlm.Vec3.zero,
            zlm.Vec3.one,
            zlm.vec3(0, -1, 4)
        ),
    };

    scene[1] = .{
        .material = blue, 
        .object = try Object.initTransform(
            try Object.initRepeat(
                try Object.initPrimitive(primitive.sphere),
                0b101,
                2.2
            ),
            zlm.vec3(z.toRadians(0.0), z.toRadians(10.0), 0),
            zlm.Vec3.one,
            zlm.vec3(2, -3, 7)
        )
    };

    scene[2] = .{
        .material = mirror, 
        .object = try Object.initTransform(
            try Object.initPrimitive(primitive.cube),
            zlm.vec3(z.toRadians(10.0), z.toRadians(10.0), z.toRadians(-10.0)),
            zlm.Vec3.all(6),
            zlm.vec3(0, 1.5, 3)
        )
    };

    scene[3] = .{
        .material = green, 
        .object = try Object.initTransform(
            try Object.initPrimitive(primitive.cylinder),
            zlm.vec3(z.toRadians(10.0), z.toRadians(10.0), z.toRadians(10.0)),
            zlm.Vec3.all(2),
            zlm.vec3(3, 0, 6)
        )
    };

    return alloc.dupe(Renderable, &scene);
}