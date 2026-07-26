//! Negation of signed distance fields (inside out)
const std = @import("std");
const zlm = @import("zlm").as(Ft);
const Object = @import("../object.zig").Object;
const types = @import("../types.zig");
const VFt = types.VFt;
const Ft = types.Ft;

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
pub fn vDistance(self: Negate, x: VFt, y: VFt, z: VFt) VFt {
    return -self.o.vDistance(x, y, z);
}

// Copyright Guillaume Derex 2020-2026 (GPL-3.0)
