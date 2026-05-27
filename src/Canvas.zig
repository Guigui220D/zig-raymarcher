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

pub fn saveAsTGA(self: Canvas, io: std.Io, name: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    cwd.deleteFile(io, name) catch {};

    var out = try cwd.createFile(io, name, .{});
    defer out.close(io);
    errdefer cwd.deleteFile(io, name) catch {};
    var writer = out.writer(io, &.{});
    const interf = &writer.interface;

    try interf.writeAll(&[_]u8{
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

    try interf.writeInt(u16, @truncate(self.width), .little);
    try interf.writeInt(u16, @truncate(self.height), .little);

    try interf.writeAll(&[_]u8{
        32, // Bit depth
        0, // Image descriptor
    });

    for (self.data) |fcol| {
        const c32 = fcol.to32BitsColor();
        try interf.writeAll(std.mem.asBytes(&c32));
    }
}

pub fn adjustColors(self: *Canvas) void {
    var floats: []f32 = undefined;
    floats.ptr = @ptrCast(&self.data[0]);
    floats.len = self.data.len * 3;
    const max = @max(1, std.mem.max(f32, floats));
    const min = minMoreThan0(floats, max);

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
    return best;
}

//Guillaume Derex 2022
