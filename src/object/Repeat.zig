//! Repetition of scene objects
const std = @import("std");
const zlm = @import("zlm").as(Ft);
const Object = @import("../object.zig").Object;
const types = @import("../types.zig");
const VFt = types.VFt;
const Ft = types.Ft;

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
/// Reciprocical of the modulo
modulo_r: Ft,
/// Half of the modulo
modulo_h: Ft,
// TODO: in some cases the modulo is trivial

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
        .modulo_r = 1.0 / modulo,
        .modulo_h = modulo / 2.0, // Is it worth storing at all
    };
}

/// Calculates the distance from this object
pub fn distance(self: Repeat, pos: zlm.Vec3) Ft {
    var temp = pos;

    if (self.axis.x)
        temp.x = fastMod(temp.x + self.modulo_h, self.modulo, self.modulo_r) - self.modulo_h;
    if (self.axis.y)
        temp.y = fastMod(temp.y + self.modulo_h, self.modulo, self.modulo_r) - self.modulo_h;
    if (self.axis.z)
        temp.z = fastMod(temp.z + self.modulo_h, self.modulo, self.modulo_r) - self.modulo_h;

    return self.o.distance(temp);
}

/// Calculates the distance from this object (vectorized)
pub fn vDistance(self: Repeat, x: VFt, y: VFt, z: VFt) VFt {
    var tx = x;
    var ty = y;
    var tz = z;

    const mod_h = @as(VFt, @splat(self.modulo_h));

    if (self.axis.x)
        tx = vFastMod(tx + mod_h, self.modulo, self.modulo_r) - mod_h;
    if (self.axis.y)
        ty = vFastMod(ty + mod_h, self.modulo, self.modulo_r) - mod_h;
    if (self.axis.z)
        tz = vFastMod(tz + mod_h, self.modulo, self.modulo_r) - mod_h;

    return self.o.vDistance(tx, ty, tz);
}

/// Function that acts like modulo
inline fn fastMod(val: Ft, mod: Ft, mod_r: Ft) Ft {
    return val - @floor(val * mod_r) * mod;
}

/// Function that acts like modulo (vectorized)
inline fn vFastMod(val: VFt, mod: Ft, mod_r: Ft) VFt {
    return val - @floor(val * @as(VFt, @splat(mod_r))) * @as(VFt, @splat(mod));
}

// Copyright Guillaume Derex 2020-2026 (GPL-3.0)
