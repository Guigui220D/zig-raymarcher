const std = @import("std");
const raymarcher = @import("raymarcher.zig");
const Image = @import("image.zig").Image;
const obj = @import("object.zig");
const Material = @import("material.zig").Material;
const color = @import("color.zig");
const primitive = @import("primitives.zig");

const allocator = std.heap.page_allocator;

pub fn main() !void {
    const canvas = try Image.init(allocator, 100, 100);
    defer canvas.deinit();

    //std.mem.set(color.Color32, canvas.data, color.Color32{ .r = 0, .g = 255, .b = 255, .a = 255 });

    const mat = Material{ .diffuse = color.Color{ .r = 1.0, .g = 0, .b = 0 } };

    const scene = try allocator.alloc(obj.Renderable, 1);
    defer allocator.free(scene);

    scene[0] = obj.Renderable.init(mat, obj.Object.initPrimitive(primitive.sphere));

    try raymarcher.render(scene, canvas);

    try canvas.saveAsTGA("test.tga");
}
