const std = @import("std");
const color = @import("color.zig");

pub const Image = struct {
    pub fn init(allocator: *std.mem.Allocator, width: usize, height: usize) !Image {
        return Image{
            .width = width,
            .height = height,
            .data = try allocator.alloc(color.Color32, width * height),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Image) void {
        self.allocator.free(self.data);
    }

    pub fn saveAsTGA(self: Image, name: []const u8) !void {
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

        var data: []u8 = undefined;
        data.ptr = @ptrCast([*]u8, &self.data[0]);
        data.len = self.data.len * 4;

        try writer.writeAll(data);
    }

    width: usize,
    height: usize,
    data: []color.Color32,
    allocator: *std.mem.Allocator
};

//Guillaume Derex 2020
