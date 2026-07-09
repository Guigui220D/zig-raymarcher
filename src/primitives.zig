const zlm = @import("zlm").as(f64);
const std = @import("std");
const math = std.math;
const Vf64 = @import("vector.zig").Vf64;

pub const PrimitiveFn = *const fn (Vf64, Vf64, Vf64) Vf64;

pub fn primitiveFromName(name: []const u8) !PrimitiveFn {
    // TODO: use comptime goodness
    if (std.ascii.eqlIgnoreCase("sphere", name))
        return vSphere;
    if (std.ascii.eqlIgnoreCase("cube", name))
        return vCube;
    if (std.ascii.eqlIgnoreCase("plane", name))
        return vPlane;
    if (std.ascii.eqlIgnoreCase("half", name))
        return vHalf;
    if (std.ascii.eqlIgnoreCase("cylinder", name))
        return vCylinder;
    return error.UnknownPrimitiveName;
}

pub fn sphere(pos: zlm.Vec3) f64 {
    return pos.length() - 1;
}

pub fn vSphere(x: Vf64, y: Vf64, z: Vf64) Vf64 {
    return @sqrt(x * x + y * y + z * z) - @as(Vf64, @splat(1));
}

pub fn cube(pos: zlm.Vec3) f64 {
    return @max(@max(@abs(pos.x) - 1, @abs(pos.y) - 1), @abs(pos.z) - 1);
}

pub fn vCube(x: Vf64, y: Vf64, z: Vf64) Vf64 {
    return @max(@max(
        @abs(x) - @as(Vf64, @splat(1)),
        @abs(y) - @as(Vf64, @splat(1)),
    ), @abs(z) - @as(Vf64, @splat(1)));
}

pub fn plane(pos: zlm.Vec3) f64 {
    return @abs(pos.y);
}

pub fn vPlane(x: Vf64, y: Vf64, z: Vf64) Vf64 {
    _ = x;
    _ = z;
    return @abs(y);
}

pub fn half(pos: zlm.Vec3) f64 {
    return pos.y;
}

pub fn vHalf(x: Vf64, y: Vf64, z: Vf64) Vf64 {
    _ = x;
    _ = z;
    return y;
}

pub fn cylinder(pos: zlm.Vec3) f64 {
    return pos.sub(zlm.vec3(0, pos.y, 0)).length() - 1;
}

pub fn vCylinder(x: Vf64, y: Vf64, z: Vf64) Vf64 {
    _ = y;
    return @sqrt(x * x + z * z) - @as(Vf64, @splat(1));
}

pub fn none(_: zlm.Vec3) f64 {
    return std.math.floatMax(f64);
}

pub fn vNone(_: Vf64, _: Vf64, _: Vf64) Vf64 {
    return @splat(std.math.floatMax(f64));
}

//Guillaume Derex 2020-2026
