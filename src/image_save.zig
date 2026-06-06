const std = @import("std");

const img = @import("zigimg");
const Canvas = @import("Canvas.zig");

pub fn saveAs(alloc: std.mem.Allocator, io: std.Io, canvas: *Canvas, path: []const u8) !void {
    std.debug.print("Saving...\n", .{});
    var image = try img.Image.fromRawPixels(
        alloc,
        canvas.width,
        canvas.height,
        @ptrCast(canvas.data),
        .float32,
    );
    defer image.deinit(alloc);
    try image.convert(alloc, .rgb24);
    try image.writeToFilePath(alloc, io, path, &.{}, .{ .png = .{} });
}

//Guillaume Derex 2026
