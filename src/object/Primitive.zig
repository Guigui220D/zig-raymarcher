//! Primitives for scene construction
const std = @import("std");
const zlm = @import("zlm").as(Ft);
const Object = @import("../object.zig").Object;
const types = @import("../types.zig");
const VFt = types.VFt;
const Ft = types.Ft;

const Primitive = @This();
/// Primitive distance function signature
const RegularPrimitiveFn = *const fn (zlm.Vec3) Ft;
/// Primitive vectorized distance function signature
const VectorizedPrimitiveFn = *const fn (VFt, VFt, VFt) VFt;

/// Set of all primitives to obtain with strings
pub const all = std.StaticStringMap(Primitive).initComptime(.{
    .{ "sphere", Primitive.init(sphere, vSphere) },
    .{ "cube", Primitive.init(cube, vCube) },
    .{ "plane", Primitive.init(plane, vPlane) },
    .{ "half", Primitive.init(half, vHalf) },
    .{ "cylinder", Primitive.init(cylinder, vCylinder) },
});

/// Distance function for this primitive
distanceFn: RegularPrimitiveFn,
/// Distance function for this primitive (vectorized)
vDistanceFn: VectorizedPrimitiveFn,

/// Inits a primitive. Only used at comptime in the primitive set construction
fn init(distanceFn: RegularPrimitiveFn, vDistanceFn: VectorizedPrimitiveFn) Primitive {
    return .{
        .distanceFn = distanceFn,
        .vDistanceFn = vDistanceFn,
    };
}

// DISTANCE FUNCTIONS

fn sphere(pos: zlm.Vec3) Ft {
    return pos.length() - 1;
}

fn vSphere(x: VFt, y: VFt, z: VFt) VFt {
    return @sqrt(x * x + y * y + z * z) - @as(VFt, @splat(1));
}

fn cube(pos: zlm.Vec3) Ft {
    return @max(@max(@abs(pos.x) - 1, @abs(pos.y) - 1), @abs(pos.z) - 1);
}

fn vCube(x: VFt, y: VFt, z: VFt) VFt {
    return @max(@max(
        @abs(x) - @as(VFt, @splat(1)),
        @abs(y) - @as(VFt, @splat(1)),
    ), @abs(z) - @as(VFt, @splat(1)));
}

fn plane(pos: zlm.Vec3) Ft {
    return @abs(pos.y);
}

fn vPlane(x: VFt, y: VFt, z: VFt) VFt {
    _ = x;
    _ = z;
    return @abs(y);
}

fn half(pos: zlm.Vec3) Ft {
    return pos.y;
}

fn vHalf(x: VFt, y: VFt, z: VFt) VFt {
    _ = x;
    _ = z;
    return y;
}

fn cylinder(pos: zlm.Vec3) Ft {
    return pos.sub(zlm.vec3(0, pos.y, 0)).length() - 1;
}

fn vCylinder(x: VFt, y: VFt, z: VFt) VFt {
    _ = y;
    return @sqrt(x * x + z * z) - @as(VFt, @splat(1));
}

//Guillaume Derex 2020-2026
