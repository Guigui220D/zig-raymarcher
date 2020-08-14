usingnamespace @import("vector.zig");
const color = @import("color.zig");

pub const Material = struct {
    diffuse: color.Color
};
