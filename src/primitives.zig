usingnamespace @import("vector.zig");
const math = @import("std").math;

pub const PrimitiveFn = fn (Vec3) f64;

pub fn sphere(pos: Vec3) f64 {
    return pos.distance(Vec3.nul) - 1.0;
}

pub fn plane(pos: Vec3) f64 {
    return math.fabs(pos.y);
}

pub fn testWall(pos: Vec3) f64 {
    return math.fabs(pos.z - 10);
}

//Guillaume Derex 2020
