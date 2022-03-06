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

pub fn saveAsTGA(self: Canvas, name: []const u8) !void {
    var cwd = std.fs.cwd();
    cwd.deleteFile(name) catch {};

    var out = try cwd.createFile(name, .{});
    defer out.close();
    errdefer cwd.deleteFile(name) catch {};
    var writer = out.writer();

    try writer.writeAll(&[_]u8{
        0, // ID length
        0, // No color map
        2, // Unmapped RGB
        0,
        0,
        0,
        0,
        0, // No color map
        0,
        0, // X origin
        0,
        0, // Y origin
    });
    
    try writer.writeIntLittle(u16, @truncate(u16, self.width));
    try writer.writeIntLittle(u16, @truncate(u16, self.height));

    try writer.writeAll(&[_]u8{
        32, // Bit depth
        0, // Image descriptor
    });

    for (self.data) |fcol| {
        const c32 = fcol.to32BitsColor();
        try writer.writeAll(std.mem.asBytes(&c32));
    }
}

pub fn adjustColors(self: *Canvas) void {
    var floats: []f32 = undefined;
    floats.ptr = @ptrCast([*]f32, &self.data[0]);
    floats.len = self.data.len * 3;
    var max = std.math.max(1, std.mem.max(f32, floats));
    const min = minMoreThan0(floats, max);

    //max *= 1.1;
    
    const range = max - min;

    std.debug.print("adjust colors: min: {}; max: {}\n", .{ min, max });

    for (self.data) |*col| {
        col.adjust(min, range);
    }
}

fn minMoreThan0(vals: []const f32, max: f32) f32 {
    var best: f32 = std.math.f32_max;
    for (vals) |v| {
        if (v < best and v > (max / 255))
            best = v;
    }
    return best;
}

//Guillaume Derex 2022