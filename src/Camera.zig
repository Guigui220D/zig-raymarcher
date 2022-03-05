const zlm = @import("zlm").SpecializeOn(f64);

origin: zlm.Vec3 = zlm.Vec3.zero,
direction: zlm.Vec3 = zlm.vec3(0, 0, 1),
fov_modifier: f64 = 1,

// Those are here to create a vector base for the camera POV
pub fn getZ(self: @This()) zlm.Vec3 {
    return self.direction.normalize();
}

pub fn getY(self: @This()) zlm.Vec3 {
    const v = self.getX();
    const u = self.getZ();
    return zlm.Vec3.cross(u, v);
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

//Guillaume Derex 2022