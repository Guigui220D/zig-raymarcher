usingnamespace @import("vector.zig");

pub const PrimitiveFn = fn (Vec3) f64;

pub fn sphere(pos: Vec3) f64 {
    return pos.distance(Vec3.nul);
}

pub fn plane(pos: Vec3) f64 {
    return pos.y;
}
