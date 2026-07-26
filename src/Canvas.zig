//! Canvas for the renderer to write on
const std = @import("std");
const Canvas = @import("Canvas.zig");
const Color = @import("color.zig").Color;

/// Width of the image in pixels
width: usize,
/// Height of the image in pixels
height: usize,
/// Data as an row-major array
data: []Color,
/// Allocator for easy deinit
allocator: std.mem.Allocator,

/// Initializes a new canvas (pixels are undefined)
pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Canvas {
    return Canvas{
        .width = width,
        .height = height,
        .data = try allocator.alloc(Color, width * height),
        .allocator = allocator,
    };
}

/// Deinits the canvas
pub fn deinit(self: Canvas) void {
    self.allocator.free(self.data);
}

/// Makes sure all the colors fit within [0,1]
pub fn adjustColors(self: *Canvas) void {
    var floats: []f32 = undefined;
    floats.ptr = @ptrCast(&self.data[0]);
    floats.len = self.data.len * 3;
    const max = @max(1, std.mem.max(f32, floats));
    const min = @min(0, std.mem.min(f32, floats));

    const range = max - min;

    std.log.debug("Adjust colors: min: {}; max: {}", .{ min, max });

    for (self.data) |*col| {
        col.adjust(min, range);
    }
}

// Copyright Guillaume Derex 2020-2026 (GPL-3.0)
