const Vec3 = @import("vector.zig").Vec3;
const math = @import("std").math;

pub const PrimitiveFn = fn (Vec3) f64;

pub fn sphere(pos: Vec3) f64 {
    return pos.distance(Vec3.nul) - 1;
}

pub fn cube(pos: Vec3) f64 {
    return math.max(math.max(math.fabs(pos.x) - 1, math.fabs(pos.y) - 1), math.fabs(pos.z) - 1);
}

pub fn plane(pos: Vec3) f64 {
    return math.fabs(pos.y);
}

pub fn plainPlane(pos: Vec3) f64 {
    return pos.y;
}

pub fn testWall(pos: Vec3) f64 {
    return math.fabs(pos.z - 10);
}

pub fn infCylinder(pos: Vec3) f64 {
    return pos.distance(Vec3{.x = 0, .y = pos.y, .z = 0}) - 1;
}

//Guillaume Derex 2020
