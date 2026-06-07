const std = @import("std");

const img = @import("zigimg");
const Canvas = @import("Canvas.zig");

pub fn saveAs(alloc: std.mem.Allocator, io: std.Io, canvas: *Canvas, path: []const u8) !void {
    // TODO: try to make that async
    var image = try img.Image.fromRawPixels(
        alloc,
        canvas.width,
        canvas.height,
        @ptrCast(canvas.data),
        .float32,
    );
    defer image.deinit(alloc);
    try image.convert(alloc, .rgb24);
    try image.writeToFilePath(alloc, io, path, &.{}, .{ .jpeg = .{ .quality = 100 } });
}

//Guillaume Derex 2026
