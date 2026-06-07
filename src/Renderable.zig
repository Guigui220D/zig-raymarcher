const std = @import("std");
const Object = @import("object.zig").Object;
const Material = @import("Material.zig");
const Renderable = @This();

material_id: usize,
object: Object,
enabled: bool,

//Guillaume Derex 2026
