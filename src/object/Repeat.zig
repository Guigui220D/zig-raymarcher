//! Repetition of scene objects
const std = @import("std");
const zlm = @import("zlm").as(Ft);
const Object = @import("../object.zig").Object;
const Ft = @import("../settings.zig").Ft;
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
modulo: Ft,

/// Inits a repeat object
pub fn init(object: *Object, repeat_x: bool, repeat_y: bool, repeat_z: bool, modulo: Ft) Repeat {
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
pub fn distance(self: Repeat, pos: zlm.Vec3) Ft {
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
pub fn vDistance(self: Repeat, x: vec.VFt, y: vec.VFt, z: vec.VFt) vec.VFt {
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
inline fn repeatFunction(val: Ft, mod: Ft) Ft {
    return @mod(val + mod / 2, mod) - mod / 2;
}

/// Function that acts like modulo but centered (vectorized)
inline fn vRepeatFunction(val: vec.VFt, mod: Ft) vec.VFt {
    return @mod(val + @as(vec.VFt, @splat(mod / 2)), @as(vec.VFt, @splat(mod))) - @as(vec.VFt, @splat(mod / 2));
}

//Guillaume Derex 2020-2026
