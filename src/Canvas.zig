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
    const min = minMoreThan0(floats, max); // TODO: this is really bad logic. Sometimes annihilate colors

    //max *= 1.1;

    const range = max - min;

    std.debug.print("adjust colors: min: {}; max: {}\n", .{ min, max });

    for (self.data) |*col| {
        col.adjust(min, range);
    }
}

fn minMoreThan0(vals: []const f32, max: f32) f32 {
    var best: f32 = std.math.floatMax(f32);
    for (vals) |v| {
        if (v < best and v > (max / 255))
            best = v;
    }
    if (best == std.math.floatMax(f32))
        return 0;
    return best;
}

//Guillaume Derex 2026
