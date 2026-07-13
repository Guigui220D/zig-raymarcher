const std = @import("std");
const zlm = @import("zlm").as(f64);
const img = @import("zigimg");

const Color = @import("color.zig").Color;
const CssColor = @import("csscolorparser").Color(f32);

const Skybox = @This();

up: img.Image,
down: img.Image,
left: img.Image,
right: img.Image,
front: img.Image,
back: img.Image,
single_img: bool,

pub fn init(alloc: std.mem.Allocator, io: std.Io, base_path: []const u8) !Skybox {
    const up_path = try std.fmt.allocPrint(alloc, "{s}/posy.jpg", .{base_path});
    defer alloc.free(up_path);
    const dn_path = try std.fmt.allocPrint(alloc, "{s}/negy.jpg", .{base_path});
    defer alloc.free(dn_path);
    const lf_path = try std.fmt.allocPrint(alloc, "{s}/negx.jpg", .{base_path});
    defer alloc.free(lf_path);
    const rt_path = try std.fmt.allocPrint(alloc, "{s}/posx.jpg", .{base_path});
    defer alloc.free(rt_path);
    const ft_path = try std.fmt.allocPrint(alloc, "{s}/posz.jpg", .{base_path});
    defer alloc.free(ft_path);
    const bk_path = try std.fmt.allocPrint(alloc, "{s}/negz.jpg", .{base_path});
    defer alloc.free(bk_path);

    var up_img = try loadImageCheck(alloc, io, up_path);
    errdefer up_img.deinit(alloc);
    var dn_img = try loadImageCheck(alloc, io, dn_path);
    errdefer dn_img.deinit(alloc);
    var lf_img = try loadImageCheck(alloc, io, lf_path);
    errdefer lf_img.deinit(alloc);
    var rt_img = try loadImageCheck(alloc, io, rt_path);
    errdefer rt_img.deinit(alloc);
    var ft_img = try loadImageCheck(alloc, io, ft_path);
    errdefer ft_img.deinit(alloc);
    var bk_img = try loadImageCheck(alloc, io, bk_path);
    errdefer bk_img.deinit(alloc);

    return .{
        .up = up_img,
        .down = dn_img,
        .left = lf_img,
        .right = rt_img,
        .front = ft_img,
        .back = bk_img,
        .single_img = false,
    };
}

pub fn initColor(alloc: std.mem.Allocator, _: std.Io, color: CssColor) !Skybox {
    const image = try img.Image.create(alloc, 1, 1, .bgra32);
    image.pixels.bgra32[0] = .{
        .a = 255,
        .r = @trunc(color.red * 255.0),
        .g = @trunc(color.green * 255.0),
        .b = @trunc(color.blue * 255.0),
    };
    return .{
        .up = image,
        .down = image,
        .back = image,
        .front = image,
        .left = image,
        .right = image,
        .single_img = true,
    };
}

fn loadImageCheck(alloc: std.mem.Allocator, io: std.Io, path: []const u8) !img.Image {
    var buf: [1024]u8 = undefined;

    std.debug.print("Skybox: loading {s}\n", .{path});
    var image = try img.Image.fromFilePath(alloc, io, path, &buf);
    errdefer image.deinit(alloc);

    if (image.width != image.height)
        return error.InvalidSkyboxImage;

    if (image.pixels != .rgb24 and image.pixels != .rgba32)
        return error.InvalidSkyboxImage;

    return image;
}

pub fn deinit(self: *Skybox, alloc: std.mem.Allocator) void {
    self.up.deinit(alloc);
    if (!self.single_img) {
        self.down.deinit(alloc);
        self.left.deinit(alloc);
        self.right.deinit(alloc);
        self.front.deinit(alloc);
        self.back.deinit(alloc);
    }
}

pub const Direction = enum {
    up,
    down,
    left,
    right,
    front,
    back,
};

fn getDirection(vector: zlm.Vec3) Direction {
    // Find greater direction
    if (@abs(vector.x) > @abs(vector.y)) {
        if (@abs(vector.x) > @abs(vector.z)) {
            // x wins
            return if (vector.x > 0) .right else .left;
        } else {
            // z wins
            return if (vector.z > 0) .front else .back;
        }
    } else {
        if (@abs(vector.y) > @abs(vector.z)) {
            // y wins
            return if (vector.y > 0) .up else .down;
        } else {
            // z wins
            return if (vector.z > 0) .front else .back;
        }
    }
}

pub fn fetchColor(self: *const Skybox, vector: zlm.Vec3) Color {
    const dir = getDirection(vector);

    // Edge case
    if (vector.eql(.zero))
        return .{ .r = 0, .g = 0, .b = 0 };

    // Get relevant texture
    const tex = switch (dir) {
        .up => &self.up,
        .down => &self.down,
        .left => &self.left,
        .right => &self.right,
        .front => &self.front,
        .back => &self.back,
    };

    // Get float coordinates on texture
    const vec = switch (dir) {
        .up => vector.scale(1 / vector.y),
        .down => vector.scale(1 / vector.y),
        .left => vector.scale(1 / vector.x),
        .right => vector.scale(1 / vector.x),
        .front => vector.scale(1 / vector.z),
        .back => vector.scale(1 / vector.z),
    };

    var im_vec: zlm.Vec2 = switch (dir) {
        .up => .{ .x = vec.x, .y = vec.z },
        .down => .{ .x = -vec.x, .y = vec.z },
        .left => .{ .x = -vec.z, .y = vec.y },
        .right => .{ .x = -vec.z, .y = -vec.y },
        .front => .{ .x = vec.x, .y = -vec.y },
        .back => .{ .x = vec.x, .y = vec.y },
    };

    // Clamp and find nearest
    im_vec = im_vec.add(.{ .x = 1, .y = 1 }).scale(0.5).scale(@floatFromInt(tex.width));
    var px_x: usize = @intFromFloat(im_vec.x);
    px_x = std.math.clamp(px_x, 0, tex.width - 1);
    var px_y: usize = @intFromFloat(im_vec.y);
    px_y = std.math.clamp(px_y, 0, tex.width - 1);

    switch (tex.pixels) {
        .rgb24 => |rgb_pixels| {
            const pix = rgb_pixels[px_x + px_y * tex.width];
            return .{
                .r = @as(f32, @floatFromInt(pix.r)) / 255.0,
                .g = @as(f32, @floatFromInt(pix.g)) / 255.0,
                .b = @as(f32, @floatFromInt(pix.b)) / 255.0,
            };
        },
        .rgba32 => |rgba_pixels| {
            const pix = rgba_pixels[px_x + px_y * tex.width];
            return .{
                .r = @as(f32, @floatFromInt(pix.r)) / 255.0,
                .g = @as(f32, @floatFromInt(pix.g)) / 255.0,
                .b = @as(f32, @floatFromInt(pix.b)) / 255.0,
            };
        },
        else => unreachable,
    }
}

//Guillaume Derex
