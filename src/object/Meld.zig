//! Object made of two objects merged in a gooey way
const std = @import("std");
const zlm = @import("zlm").as(Ft);
const Object = @import("../object.zig").Object;
const types = @import("../types.zig");
const VFt = types.VFt;
const Ft = types.Ft;

const Meld = @This();

/// First object to meld
a: *Object,
/// Second object to meld
b: *Object,
/// How much we are melding the two elements
/// Lower is more deformation and at longer distances
meld_factor: Ft,

/// Inits a meld object
pub fn init(objectA: *Object, objectB: *Object, factor: Ft) Meld {
    return .{
        .a = objectA,
        .b = objectB,
        .meld_factor = factor,
    };
}

/// Calculates the distance from this object
pub fn distance(self: Meld, pos: zlm.Vec3) Ft {
    const a = self.a.distance(pos);
    const b = self.b.distance(pos);

    return softmin(a, b, self.meld_factor);
}

/// Calculates the distance from this object (vectorized)
pub fn vDistance(self: Meld, x: VFt, y: VFt, z: VFt) VFt {
    const a = self.a.vDistance(x, y, z);
    const b = self.b.vDistance(x, y, z);

    return vSoftmin(a, b, self.meld_factor);
}

/// Function that acts like modulo but centered
inline fn repeatFunction(val: Ft, mod: Ft) Ft {
    return @mod(val + mod / 2, mod) - mod / 2;
}

/// Softmax function that the meld is based on
inline fn softmax(a: Ft, b: Ft, k: Ft) Ft {
    const m = @max(a, b);
    return m + @log(@exp(k * (a - m)) + @exp(k * (b - m))) / k;
}

/// Softmin function using softmax
inline fn softmin(a: Ft, b: Ft, k: Ft) Ft {
    return -softmax(-a, -b, k);
}

/// Softmax function that the meld is based on
inline fn vSoftmax(a: VFt, b: VFt, k: Ft) VFt {
    const m = @max(a, b);
    return m + @log(@exp(@as(VFt, @splat(k)) * (a - m)) + @exp(@as(VFt, @splat(k)) * (b - m))) / @as(VFt, @splat(k));
}

/// Softmin function using softmax
inline fn vSoftmin(a: VFt, b: VFt, k: Ft) VFt {
    return -vSoftmax(-a, -b, k);
}

//Guillaume Derex 2020-2026
