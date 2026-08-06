const std = @import("std");
const Object = @import("object.zig").Object;
const Material = @import("Material.zig");
const Renderable = @This();

object: Object,
material_id: u8,
enabled: bool,

// Copyright Guillaume Derex 2020-2026 (GPL-3.0)
