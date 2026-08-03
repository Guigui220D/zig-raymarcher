//! Test for a whole object tree inside a function (no calls)
const std = @import("std");
const zlm = @import("zlm").as(Ft);
const Object = @import("../object.zig").Object;
const types = @import("../types.zig");
const Primitive = @import("Primitive.zig");
const Transform = @import("Transform.zig");
const VFt = types.VFt;
const Ft = types.Ft;

const CompiledScene = @This();

const top_transform = zlm.Mat4.identity
    .mul(zlm.Mat4.createTranslation(.{ .x = 0, .y = 0, .z = -5 }))
    .mul(zlm.Mat4.createAngleAxis(.{ .x = 1, .y = 0, .z = 0 }, zlm.toRadians(10)))
    .mul(zlm.Mat4.createAngleAxis(.{ .x = 0, .y = 1, .z = 0 }, zlm.toRadians(10)))
    .mul(zlm.Mat4.createAngleAxis(.{ .x = 0, .y = 0, .z = 1 }, zlm.toRadians(10)));

const sphere_transform = zlm.Mat4.identity
    .mul(zlm.Mat4.createScale(1.0 / 1.5, 1.0 / 1.5, 1.0 / 1.5));

const cylinders_transform = zlm.Mat4.identity
    .mul(zlm.Mat4.createScale(1.0 / 0.75, 1.0 / 0.75, 1.0 / 0.75));

const cylinder1_transform = zlm.Mat4.identity
    .mul(zlm.Mat4.createAngleAxis(.{ .x = 0, .y = 0, .z = 1 }, zlm.toRadians(90)));

const cylinder2_transform = zlm.Mat4.identity
    .mul(zlm.Mat4.createAngleAxis(.{ .x = 1, .y = 0, .z = 0 }, zlm.toRadians(90)));

/// Calculates the distance from this object
pub fn distance(_: CompiledScene, pos: zlm.Vec3) Ft {
    const pos_ = zlm.Vec4{ .x = pos.x, .y = pos.y, .z = pos.z, .w = 1 };

    const pos1 = pos_.transform(top_transform); // All of it (cube)
    const pos2 = pos1.transform(sphere_transform); // Sphere
    const pos3 = pos1.transform(cylinders_transform); // Cylinder 0
    const pos4 = pos3.transform(cylinder1_transform); // Cylinder 1
    const pos5 = pos3.transform(cylinder2_transform); // Cylinder 2

    const cube_dist = @call(.always_inline, Primitive.cube, .{pos1.swizzle("xyz")});
    const sphere_dist = @call(.always_inline, Primitive.sphere, .{pos2.swizzle("xyz")});
    const cylinder0_dist = @call(.always_inline, Primitive.cylinder, .{pos3.swizzle("xyz")});
    const cylinder1_dist = @call(.always_inline, Primitive.cylinder, .{pos4.swizzle("xyz")});
    const cylinder2_dist = @call(.always_inline, Primitive.cylinder, .{pos5.swizzle("xyz")});

    // CSG
    const cyls = @min(cylinder0_dist, @min(cylinder1_dist, cylinder2_dist));
    const dist = @max(@max(cube_dist, sphere_dist), -cyls);

    return dist;
}

/// Calculates the distance from this object (vectorized)
pub fn vDistance(_: CompiledScene, x: VFt, y: VFt, z: VFt) VFt {
    const x1, const y1, const z1 = Transform.vTransform(x, y, z, top_transform);
    const x2, const y2, const z2 = Transform.vTransform(x1, y1, z1, sphere_transform);
    const x3, const y3, const z3 = Transform.vTransform(x1, y1, z1, cylinders_transform);
    const x4, const y4, const z4 = Transform.vTransform(x3, y3, z3, cylinder1_transform);
    const x5, const y5, const z5 = Transform.vTransform(x3, y3, z3, cylinder2_transform);

    const cube_dist = @call(.always_inline, Primitive.vCube, .{ x1, y1, z1 });
    const sphere_dist = @call(.always_inline, Primitive.vSphere, .{ x2, y2, z2 });
    const cylinder0_dist = @call(.always_inline, Primitive.vCylinder, .{ x3, y3, z3 });
    const cylinder1_dist = @call(.always_inline, Primitive.vCylinder, .{ x4, y4, z4 });
    const cylinder2_dist = @call(.always_inline, Primitive.vCylinder, .{ x5, y5, z5 });

    const cyls = @min(cylinder0_dist, @min(cylinder1_dist, cylinder2_dist));
    const dist = @max(@max(cube_dist, sphere_dist), -cyls);

    return dist;
}

// Copyright Guillaume Derex 2020-2026 (GPL-3.0)
