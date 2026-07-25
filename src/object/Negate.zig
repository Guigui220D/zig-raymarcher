//! Negation of signed distance fields (inside out)
const std = @import("std");
const zlm = @import("zlm").as(Ft);
const Object = @import("../object.zig").Object;
const vec = @import("../vector.zig");
const Ft = @import("../settings.zig").Ft;

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
pub fn distance(self: Negate, pos: zlm.Vec3) Ft {
    return -self.o.distance(pos);
}

/// Calculates the distance from this object (vectorized)
pub fn vDistance(self: Negate, x: vec.VFt, y: vec.VFt, z: vec.VFt) vec.VFt {
    return -self.o.vDistance(x, y, z);
}

//Guillaume Derex 2020-2026
