//! Object made of two objects merged in a gooey way
const std = @import("std");
const zlm = @import("zlm").as(f64);
const Object = @import("../object.zig").Object;
const vec = @import("../vector.zig");

const Meld = @This();

/// First object to meld
a: *Object,
/// Second object to meld
b: *Object,
/// How much we are melding the two elements
/// Lower is more deformation and at longer distances
meld_factor: f64,

/// Inits a meld object
pub fn init(objectA: *Object, objectB: *Object, factor: f64) Meld {
    return .{
        .a = objectA,
        .b = objectB,
        .meld_factor = factor,
    };
}

/// Calculates the distance from this object
pub fn distance(self: Meld, pos: zlm.Vec3) f64 {
    const a = self.a.distance(pos);
    const b = self.b.distance(pos);

    return softmin(a, b, self.meld_factor);
}

/// Calculates the distance from this object (vectorized)
pub fn vDistance(self: Meld, x: vec.Vf64, y: vec.Vf64, z: vec.Vf64) vec.Vf64 {
    const a = self.a.vDistance(x, y, z);
    const b = self.b.vDistance(x, y, z);

    return vSoftmin(a, b, self.meld_factor);
}

/// Function that acts like modulo but centered
inline fn repeatFunction(val: f64, mod: f64) f64 {
    return @mod(val + mod / 2, mod) - mod / 2;
}

/// Softmax function that the meld is based on
inline fn softmax(a: f64, b: f64, k: f64) f64 {
    const m = @max(a, b);
    return m + @log(@exp(k * (a - m)) + @exp(k * (b - m))) / k;
}

/// Softmin function using softmax
inline fn softmin(a: f64, b: f64, k: f64) f64 {
    return -softmax(-a, -b, k);
}

/// Softmax function that the meld is based on
inline fn vSoftmax(a: vec.Vf64, b: vec.Vf64, k: f64) vec.Vf64 {
    const m = @max(a, b);
    return m + @log(@exp(@as(vec.Vf64, @splat(k)) * (a - m)) + @exp(@as(vec.Vf64, @splat(k)) * (b - m))) / @as(vec.Vf64, @splat(k));
}

/// Softmin function using softmax
inline fn vSoftmin(a: vec.Vf64, b: vec.Vf64, k: f64) vec.Vf64 {
    return -vSoftmax(-a, -b, k);
}

//Guillaume Derex 2020-2026
