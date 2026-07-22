//! Primitives for scene construction
const std = @import("std");
const zlm = @import("zlm").as(f64);
const Object = @import("../object.zig").Object;
const vec = @import("../vector.zig");

const Primitive = @This();
/// Primitive distance function signature
const RegularPrimitiveFn = *const fn (zlm.Vec3) f64;
/// Primitive vectorized distance function signature
const VectorizedPrimitiveFn = *const fn (vec.Vf64, vec.Vf64, vec.Vf64) vec.Vf64;

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

fn sphere(pos: zlm.Vec3) f64 {
    return pos.length() - 1;
}

fn vSphere(x: vec.Vf64, y: vec.Vf64, z: vec.Vf64) vec.Vf64 {
    return @sqrt(x * x + y * y + z * z) - @as(vec.Vf64, @splat(1));
}

fn cube(pos: zlm.Vec3) f64 {
    return @max(@max(@abs(pos.x) - 1, @abs(pos.y) - 1), @abs(pos.z) - 1);
}

fn vCube(x: vec.Vf64, y: vec.Vf64, z: vec.Vf64) vec.Vf64 {
    return @max(@max(
        @abs(x) - @as(vec.Vf64, @splat(1)),
        @abs(y) - @as(vec.Vf64, @splat(1)),
    ), @abs(z) - @as(vec.Vf64, @splat(1)));
}

fn plane(pos: zlm.Vec3) f64 {
    return @abs(pos.y);
}

fn vPlane(x: vec.Vf64, y: vec.Vf64, z: vec.Vf64) vec.Vf64 {
    _ = x;
    _ = z;
    return @abs(y);
}

fn half(pos: zlm.Vec3) f64 {
    return pos.y;
}

fn vHalf(x: vec.Vf64, y: vec.Vf64, z: vec.Vf64) vec.Vf64 {
    _ = x;
    _ = z;
    return y;
}

fn cylinder(pos: zlm.Vec3) f64 {
    return pos.sub(zlm.vec3(0, pos.y, 0)).length() - 1;
}

fn vCylinder(x: vec.Vf64, y: vec.Vf64, z: vec.Vf64) vec.Vf64 {
    _ = y;
    return @sqrt(x * x + z * z) - @as(vec.Vf64, @splat(1));
}

//Guillaume Derex 2020-2026
