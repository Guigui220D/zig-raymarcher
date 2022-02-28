const zlm = @import("zlm").SpecializeOn(f64);
const std = @import("std");
const math = std.math;

pub const PrimitiveFn = fn (zlm.Vec3) f64;

pub fn primitiveFromName(name: []const u8) PrimitiveFn {
    // TODO: use comptime goodness
    if (std.ascii.eqlIgnoreCase("sphere", name))
        return sphere;
    if (std.ascii.eqlIgnoreCase("cube", name))
        return cube;
    if (std.ascii.eqlIgnoreCase("plane", name))
        return plane;
    if (std.ascii.eqlIgnoreCase("half", name))
        return half;
    if (std.ascii.eqlIgnoreCase("testWall", name))
        return testWall;
    if (std.ascii.eqlIgnoreCase("cylinder", name))
        return cylinder;
    return none;
}

pub fn sphere(pos: zlm.Vec3) f64 {
    return pos.length() - 1;
}

pub fn cube(pos: zlm.Vec3) f64 {
    return math.max(math.max(math.fabs(pos.x) - 1, math.fabs(pos.y) - 1), math.fabs(pos.z) - 1);
}

pub fn plane(pos: zlm.Vec3) f64 {
    return math.fabs(pos.y);
}

pub fn half(pos: zlm.Vec3) f64 {
    return pos.y;
}

pub fn testWall(pos: zlm.Vec3) f64 {
    return math.fabs(pos.z - 10);
}

pub fn cylinder(pos: zlm.Vec3) f64 {
    return pos.sub(zlm.vec3(0, pos.y, 0)).length() - 1;
}

pub fn none(pos: zlm.Vec3) f64 {
    _ = pos;
    return 10000000000;
}

//Guillaume Derex 2020
