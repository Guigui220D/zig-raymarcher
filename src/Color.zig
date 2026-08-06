//! Float color
const csscolorparser = @import("csscolorparser");

const zlm = @import("zlm").as(f32);

const Color = @This();

/// Backing type used by colors
const Rgba = zlm.Vec4;

/// RGBA components of the color as respectively XYZW
rgba: Rgba,

/// Black color
pub const black = Color{ .rgba = .{ .x = 0, .y = 0, .z = 0, .w = 1 } };
/// White color
pub const white = Color{ .rgba = .{ .x = 1, .y = 1, .z = 1, .w = 1 } };
/// Gray color
pub const gray = Color{ .rgba = .{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 1 } };
/// Transparent (zero opacity)
pub const transparent = Color{ .rgba = .{ .x = 0, .y = 0, .z = 0, .w = 0 } };
/// Red color
pub const red = Color{ .rgba = .{ .x = 1, .y = 0, .z = 0, .w = 1 } };
/// Green color
pub const green = Color{ .rgba = .{ .x = 0, .y = 1, .z = 0, .w = 1 } };
/// Blue color
pub const blue = Color{ .rgba = .{ .x = 0, .y = 0, .z = 1, .w = 1 } };
/// Yellow color
pub const yellow = Color{ .rgba = .{ .x = 1, .y = 1, .z = 0, .w = 1 } };
/// Magenta color
pub const magenta = Color{ .rgba = .{ .x = 1, .y = 0, .z = 1, .w = 1 } };
/// Cyan color
pub const cyan = Color{ .rgba = .{ .x = 0, .y = 1, .z = 1, .w = 1 } };

/// Helper to build a color from RGBA values
pub inline fn fromRGBA(r: f32, g: f32, b: f32, a: f32) Color {
    return .{
        .x = r,
        .y = g,
        .z = b,
        .w = a,
    };
}

/// Makes a color from a string (CSS syntax)
/// Returns null if parsing failed
pub fn fromString(str: []const u8) ?Color {
    const css_col = csscolorparser.Color(f32).parse(str) catch return null;
    return .fromRGBA(css_col.red, css_col.green, css_col.blue, css_col.alpha);
}

// Copyright Guillaume Derex 2020-2026 (GPL-3.0)
