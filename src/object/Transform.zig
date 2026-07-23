//! Transform object for the scene tree
const std = @import("std");
const zlm = @import("zlm").as(f64);
const Object = @import("../object.zig").Object;
const vec = @import("../vector.zig");

const Transform = @This();

/// Object being transformed
o: *Object,
/// Transform matrix
transform: zlm.Mat4,

/// Inits a transform object
pub fn init(object: *Object, rotate: zlm.Vec3, scale: zlm.Vec3, translate: zlm.Vec3) Transform {
    var mat: zlm.Mat4 = .identity;
    mat = mat.mul(zlm.Mat4.createTranslation(translate.neg()));
    mat = mat.mul(zlm.Mat4.createScale(1 / scale.x, 1 / scale.y, 1 / scale.z));
    mat = mat.mul(zlm.Mat4.createAngleAxis(.{ .x = 1, .y = 0, .z = 0 }, rotate.x));
    mat = mat.mul(zlm.Mat4.createAngleAxis(.{ .x = 0, .y = 1, .z = 0 }, rotate.y));
    mat = mat.mul(zlm.Mat4.createAngleAxis(.{ .x = 0, .y = 0, .z = 1 }, rotate.z));
    return .{
        .o = object,
        .transform = mat,
    };
}

/// Calculates the distance from this object
pub fn distance(self: Transform, pos: zlm.Vec3) f64 {
    var pos4 = zlm.Vec4{ .x = pos.x, .y = pos.y, .z = pos.z, .w = 1 };
    pos4 = pos4.transform(self.transform);
    return self.o.distance(.{ .x = pos4.x, .y = pos4.y, .z = pos4.z });
}

/// Calculates the distance from this object (vectorized)
pub fn vDistance(self: Transform, x: vec.Vf64, y: vec.Vf64, z: vec.Vf64) vec.Vf64 {
    var rx: vec.Vf64 = @splat(0);
    var ry: vec.Vf64 = @splat(0);
    var rz: vec.Vf64 = @splat(0);

    rx += x * @as(vec.Vf64, @splat(self.transform.fields[0][0]));
    ry += x * @as(vec.Vf64, @splat(self.transform.fields[0][1]));
    rz += x * @as(vec.Vf64, @splat(self.transform.fields[0][2]));

    rx += y * @as(vec.Vf64, @splat(self.transform.fields[1][0]));
    ry += y * @as(vec.Vf64, @splat(self.transform.fields[1][1]));
    rz += y * @as(vec.Vf64, @splat(self.transform.fields[1][2]));

    rx += z * @as(vec.Vf64, @splat(self.transform.fields[2][0]));
    ry += z * @as(vec.Vf64, @splat(self.transform.fields[2][1]));
    rz += z * @as(vec.Vf64, @splat(self.transform.fields[2][2]));

    rx += @as(vec.Vf64, @splat(self.transform.fields[3][0]));
    ry += @as(vec.Vf64, @splat(self.transform.fields[3][1]));
    rz += @as(vec.Vf64, @splat(self.transform.fields[3][2]));

    return self.o.vDistance(rx, ry, rz);
}

//Guillaume Derex 2020-2026
