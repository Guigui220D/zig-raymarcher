const zlm = @import("zlm").SpecializeOn(f64);
const math = @import("std").math;

pub const PrimitiveFn = fn (zlm.Vec3) f64;

pub fn sphere(pos: zlm.Vec3) f64 {
    return pos.length() - 1;
}

pub fn cube(pos: zlm.Vec3) f64 {
    return math.max(math.max(math.fabs(pos.x) - 1, math.fabs(pos.y) - 1), math.fabs(pos.z) - 1);
}

pub fn plane(pos: zlm.Vec3) f64 {
    return math.fabs(pos.y);
}

pub fn plainPlane(pos: zlm.Vec3) f64 {
    return pos.y;
}

pub fn testWall(pos: zlm.Vec3) f64 {
    return math.fabs(pos.z - 10);
}

pub fn infCylinder(pos: zlm.Vec3) f64 {
    return pos.sub(zlm.vec3(0, pos.y, 0)).length() - 1;
}

//Guillaume Derex 2020
