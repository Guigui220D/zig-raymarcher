const zlm = @import("zlm").SpecializeOn(f64);
const Color = @import("color.zig").Color;

color: Color = .{ .r = 1, .g = 1, .b = 1 },
position: zlm.Vec3 = zlm.Vec3.zero,

//Guillaume Derex 2022