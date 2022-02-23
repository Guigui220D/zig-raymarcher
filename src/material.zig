const Vec3 = @import("vector.zig").Vec3;
const color = @import("color.zig");

pub const Material = struct {
    diffuse: color.Color,
    reflectivity: f32,
    diffuse2: ?color.Color = null,
};

//Guillaume Derex 2020
