const std = @import("std");
const Object = @import("object.zig").Object;
const Material = @import("Material.zig");
const Renderable = @This();

pub fn init(material: Material, object: *Object) Renderable {
    return Renderable{
        .material = material,
        .object = object,
    };
}

pub fn deinit(self: Renderable, allocator: std.mem.Allocator) void {
    self.object.deinit(allocator);
    allocator.destroy(self.object);
}

material: Material,
object: *Object