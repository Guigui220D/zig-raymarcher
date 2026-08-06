//! Struct describing a material
const Color = @import("color.zig").Color;

/// Albedo color
diffuse: Color = .{},
/// Reflectivity factor between 0 and 1
reflectivity: f32 = 0,
/// Smoothness factor between 0 and 1
smoothness: f32 = 0,
/// Second albedo color for patterns (TODO: rethink this)
diffuse2: ?Color = null

// Copyright Guillaume Derex 2020-2026 (GPL-3.0)
