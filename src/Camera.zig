const zlm = @import("zlm").SpecializeOn(f64);

origin: zlm.Vec3 = zlm.Vec3.zero,
direction: zlm.Vec3 = zlm.vec3(0, 0, 1),
fov_modifier: f64 = 1,

// ew i hate those
pub fn getZ(self: @This()) zlm.Vec3 {
    return self.direction.normalize();
}

pub fn getY(self: @This()) zlm.Vec3 {
    const v = self.getX();
    const u = self.getZ();
    return zlm.vec3(
        u.y * v.z - u.z * v.y,
        u.z * v.x - u.x * v.z,
        u.x * v.y - u.y * v.x
    );
}

pub fn getX(self: @This()) zlm.Vec3 {
    var dir = self.getZ();
    dir.y = 0;
    dir = dir.normalize();
    var x = dir.x;
    dir.x = dir.z;
    dir.z = -x;
    return dir;
}