const std = @import("std");
const Object = @import("object.zig").Object;
const Material = @import("Material.zig");
const Renderable = @This();

material: Material,
object: *Object

//Guillaume Derex 2022