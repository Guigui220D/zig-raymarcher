//! Negation of signed distance fields (inside out)
const std = @import("std");
const zlm = @import("zlm").as(f64);
const Object = @import("../object.zig").Object;
const vec = @import("../vector.zig");

const Negate = @This();

/// Object being inverted
o: *Object,

/// Inits a repeat object
pub fn init(object: *Object) Negate {
    return .{
        .o = object,
    };
}

/// Calculates the distance from this object
pub fn distance(self: Negate, pos: zlm.Vec3) f64 {
    return -self.o.distance(pos);
}

/// Calculates the distance from this object (vectorized)
pub fn vDistance(self: Negate, x: vec.Vf64, y: vec.Vf64, z: vec.Vf64) vec.Vf64 {
    return -self.o.vDistance(x, y, z);
}

//Guillaume Derex 2020-2026
