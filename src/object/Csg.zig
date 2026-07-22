//! Constructive geometry object for scene tree
const std = @import("std");
const zlm = @import("zlm").as(f64);
const Object = @import("../object.zig").Object;
const vec = @import("../vector.zig");

const Csg = @This();

/// Types of constructions
pub const Type = enum { intersectionCsg, unionCsg, differenceCsg };

/// First object to construct with
a: *Object,
/// Second object to construct with
b: *Object,
/// Type of construction
mode: Type,

/// Inits a CSG object
pub fn init(objectA: *Object, objectB: *Object, mode: Type) Csg {
    return .{
        .a = objectA,
        .b = objectB,
        .mode = mode,
    };
}

/// Calculates the distance from this object
pub fn distance(self: Csg, pos: zlm.Vec3) f64 {
    const a = self.a.distance(pos);
    const b = self.b.distance(pos);

    return switch (self.mode) {
        .intersectionCsg => @max(a, b),
        .unionCsg => @min(a, b),
        .differenceCsg => @max(a, -b),
    };
}

/// Calculates the distance from this object (vectorized)
pub fn vDistance(self: Csg, x: vec.Vf64, y: vec.Vf64, z: vec.Vf64) vec.Vf64 {
    const a = self.a.vDistance(x, y, z);
    const b = self.b.vDistance(x, y, z);

    return switch (self.mode) {
        .intersectionCsg => @max(a, b),
        .unionCsg => @min(a, b),
        .differenceCsg => @max(a, -b),
    };
}

//Guillaume Derex 2020-2026
