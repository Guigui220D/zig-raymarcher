//! Struct representing a point light source
const zlm = @import("zlm").as(Ft);
const Ft = @import("types.zig").Ft;
const Color = @import("color.zig").Color;

color: Color = .{ .r = 1, .g = 1, .b = 1 },
pos: zlm.Vec3 = zlm.Vec3.zero,

// Copyright Guillaume Derex 2020-2026 (GPL-3.0)
