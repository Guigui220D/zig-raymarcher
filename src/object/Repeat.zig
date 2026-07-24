//! Repetition of scene objects
const std = @import("std");
const zlm = @import("zlm").as(f64);
const Object = @import("../object.zig").Object;
const vec = @import("../vector.zig");

const Repeat = @This();

/// Object being repeated
o: *Object,
/// Axis along which we are repeating
axis: packed struct {
    x: bool,
    y: bool,
    z: bool,
},
/// Period of the repetition
modulo: f64,

/// Inits a repeat object
pub fn init(object: *Object, repeat_x: bool, repeat_y: bool, repeat_z: bool, modulo: f64) Repeat {
    return .{
        .o = object,
        .axis = .{
            .x = repeat_x,
            .y = repeat_y,
            .z = repeat_z,
        },
        .modulo = modulo,
    };
}

/// Calculates the distance from this object
pub fn distance(self: Repeat, pos: zlm.Vec3) f64 {
    var temp = pos;

    if (self.axis.x)
        temp.x = repeatFunction(temp.x, self.modulo);
    if (self.axis.y)
        temp.y = repeatFunction(temp.y, self.modulo);
    if (self.axis.z)
        temp.z = repeatFunction(temp.z, self.modulo);

    return self.o.distance(temp);
}

/// Calculates the distance from this object (vectorized)
pub fn vDistance(self: Repeat, x: vec.Vf64, y: vec.Vf64, z: vec.Vf64) vec.Vf64 {
    var tx = x;
    var ty = y;
    var tz = z;

    if (self.axis.x)
        tx = vRepeatFunction(tx, self.modulo);
    if (self.axis.y)
        ty = vRepeatFunction(ty, self.modulo);
    if (self.axis.z)
        tz = vRepeatFunction(tz, self.modulo);

    return self.o.vDistance(tx, ty, tz);
}

/// Function that acts like modulo but centered
inline fn repeatFunction(val: f64, mod: f64) f64 {
    return @mod(val + mod / 2, mod) - mod / 2;
}

/// Function that acts like modulo but centered (vectorized)
inline fn vRepeatFunction(val: vec.Vf64, mod: f64) vec.Vf64 {
    return @mod(val + @as(vec.Vf64, @splat(mod / 2)), @as(vec.Vf64, @splat(mod))) - @as(vec.Vf64, @splat(mod / 2));
}

//Guillaume Derex 2020-2026
