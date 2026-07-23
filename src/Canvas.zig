const std = @import("std");
const Canvas = @import("Canvas.zig");
const Color = @import("color.zig").Color;

width: usize,
height: usize,
data: []Color,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Canvas {
    return Canvas{
        .width = width,
        .height = height,
        .data = try allocator.alloc(Color, width * height),
        .allocator = allocator,
    };
}

pub fn deinit(self: Canvas) void {
    self.allocator.free(self.data);
}

pub fn adjustColors(self: *Canvas) void {
    var floats: []f32 = undefined;
    floats.ptr = @ptrCast(&self.data[0]);
    floats.len = self.data.len * 3;
    const max = @max(1, std.mem.max(f32, floats));
    const min = @min(0, std.mem.min(f32, floats));

    const range = max - min;

    std.debug.print("adjust colors: min: {}; max: {}\n", .{ min, max });

    for (self.data) |*col| {
        col.adjust(min, range);
    }
}

//Guillaume Derex 2026
