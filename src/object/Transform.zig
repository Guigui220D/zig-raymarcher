//! Transform object for the scene tree
const std = @import("std");
const zlm = @import("zlm").as(f64);
const Object = @import("../object.zig").Object;
const vec = @import("../vector.zig");

const Transform = @This();

/// Object being transformed
o: *Object,
/// Rotation along 3 axis
rotate: zlm.Vec3,
/// Scale along 3 axis
scale: zlm.Vec3,
/// Position offset
translate: zlm.Vec3,
// TODO: make a transform matrix instead
/// Rotation matrix for x (cache)
_xsincos: zlm.Vec2,
/// Rotation matrix for y (cache)
_ysincos: zlm.Vec2,
/// Rotation matrix for z (cache)
_zsincos: zlm.Vec2,

/// Inits a transform object
pub fn init(object: *Object, rotate: zlm.Vec3, scale: zlm.Vec3, translate: zlm.Vec3) Transform {
    return .{
        .o = object,
        .rotate = rotate,
        .scale = scale,
        .translate = translate,
        ._xsincos = .{ .x = @sin(rotate.x), .y = @cos(rotate.x) },
        ._ysincos = .{ .x = @sin(rotate.y), .y = @cos(rotate.y) },
        ._zsincos = .{ .x = @sin(rotate.z), .y = @cos(rotate.z) },
    };
}

/// Calculates the distance from this object
pub fn distance(self: Transform, pos: zlm.Vec3) f64 {
    var temp = pos;

    // Rotate
    if (!self.rotate.eql(zlm.Vec3.zero)) {
        { // x
            const scx = self._xsincos.x;
            const scy = self._xsincos.y;
            const new_y = scy * temp.y - scx * temp.z;
            const new_z = scx * temp.y + scy * temp.z;
            temp.y = new_y;
            temp.z = new_z;
        }
        { // y
            const scx = self._ysincos.x;
            const scy = self._ysincos.y;
            const new_x = scy * temp.x + scx * temp.z;
            const new_z = scy * temp.z - scx * temp.x;
            temp.x = new_x;
            temp.z = new_z;
        }
        { // z
            const scx = self._zsincos.x;
            const scy = self._zsincos.y;
            const new_x = scy * temp.x - scx * temp.y;
            const new_y = scx * temp.x + scy * temp.y;
            temp.x = new_x;
            temp.y = new_y;
        }
    }

    // Scale
    if (!self.scale.eql(zlm.Vec3.one)) {
        temp.x /= self.scale.x;
        temp.y /= self.scale.y;
        temp.z /= self.scale.z;
    }

    // Translate
    temp.x -= self.translate.x;
    temp.y -= self.translate.y;
    temp.z -= self.translate.z;

    return self.o.distance(temp);
}

/// Calculates the distance from this object (vectorized)
pub fn vDistance(self: Transform, x: vec.Vf64, y: vec.Vf64, z: vec.Vf64) vec.Vf64 {
    var tx = x;
    var ty = y;
    var tz = z;

    // Rotate
    if (!self.rotate.eql(zlm.Vec3.zero)) {
        { // x
            const scx: vec.Vf64 = @splat(self._xsincos.x);
            const scy: vec.Vf64 = @splat(self._xsincos.y);
            const new_y = scy * ty - scx * tz;
            const new_z = scx * ty + scy * tz;
            ty = new_y;
            tz = new_z;
        }
        { // y
            const scx: vec.Vf64 = @splat(self._ysincos.x);
            const scy: vec.Vf64 = @splat(self._ysincos.y);
            const new_x = scy * tx + scx * tz;
            const new_z = scy * tz - scx * tx;
            tx = new_x;
            tz = new_z;
        }
        { // z
            const scx: vec.Vf64 = @splat(self._zsincos.x);
            const scy: vec.Vf64 = @splat(self._zsincos.y);
            const new_x = scy * tx - scx * ty;
            const new_y = scx * tx + scy * ty;
            tx = new_x;
            ty = new_y;
        }
    }

    // scale
    if (!self.scale.eql(zlm.Vec3.one)) {
        tx /= @splat(self.scale.x);
        ty /= @splat(self.scale.y);
        tz /= @splat(self.scale.z);
    }

    // translate
    tx -= @splat(self.translate.x);
    ty -= @splat(self.translate.y);
    tz -= @splat(self.translate.z);

    return self.o.vDistance(tx, ty, tz);
}

//Guillaume Derex 2020-2026
