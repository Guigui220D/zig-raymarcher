//! General settings for render that may affect performance and image quality
// TODO: make this an object and add current_settings and default_settings
const std = @import("std");
const Ft = @import("types.zig").Ft;

const Settings = @This();

/// Image rendering debug modes
pub const DebugMode = enum {
    /// The actual render will be the output
    none,
    /// The output colors objects depending on the material ID
    material_ids,
    /// The normal of the hit point will be used with xyz as rgb
    normal,
    /// The direction of reflection vectors will be used with xyz as rgb
    reflection,
    /// The number of steps is used to color
    rayinfo,
};

/// Number of renders we perform when benchmark is true
pub const benchmark_it: usize = 5;
/// Output info of the rays of a rayload at each update
/// Slows down everything!!! only for analysis
pub const report_rayload_composition: bool = false;
/// Changes what the output image will represent (see DebugMode)
pub const debug_mode: DebugMode = .none;
/// Minimum contribution for a ray to be worth it
pub const min_contribution: f32 = 1.0 / 256.0;

/// Current selected settings
pub var current: Settings = default;

/// Default settings
pub const default: Settings = .{
    .name = "default",
};
/// Preview settings for fast result
pub const preview: Settings = .{
    .name = "preview",
    .hit_distance = default.hit_distance * 2,
    .max_steps = default.max_steps / 2,
    .max_steps_getting_closer = default.max_steps_getting_closer / 2,
    .max_recursions = 1,
    .pic_height = 500,
    .pic_width = 500,
};
/// High quality settings (much longer render)
pub const high_quality: Settings = .{
    .name = "high_quality",
    .hit_distance = 0.01,
    .max_steps = 2048,
    .max_steps_getting_closer = 4096,
    .max_recursions = 8,
    .pic_height = 2000,
    .pic_width = 2000,
};
/// Benchmarking settings (image will be no good)
pub const benchmark: Settings = .{
    .name = "benchmark",
    .max_steps = 512,
    .max_steps_getting_closer = 1024,
    .max_recursions = 3,
    .pic_height = 200,
    .pic_width = 200,
};

/// Name of the preset
name: []const u8 = "custom",
/// Distance from an object at which we consider we hit it
hit_distance: Ft = 0.02,
/// Number of steps forward a ray can take before giving up
max_steps: usize = 1024,
/// Number of steps forward a ray can take before giving up, when it's getting closer to something
/// Larger value because we don't want to give up as easily when theres probably somehting
max_steps_getting_closer: usize = 2048,
/// Number of recursive reflections a ray can have
max_recursions: u8 = 6,
/// Width of the image output in pixels (doesn't apply when benchmarking)
pic_width: usize = 1000,
/// Height of the image output in pixels (doesn't apply when benchmarking)
pic_height: usize = 1000,
/// Max x,y,z coordinates until a ray is given up on
scene_boundaries: Ft = 100,

/// Dump to the logs the important settings
pub fn reportSettings(self: Settings) void {
    std.log.info("Settings (preset: {s}):", .{self.name});
    //std.log.info("- Vector length: {}", .{self.vec_len});
    std.log.info("- Hit distance: {}", .{self.hit_distance});
    std.log.info("- Max ray steps: {} (getting closer: {})", .{ self.max_steps, self.max_steps_getting_closer });
    std.log.info("- Max recursions: {}", .{self.max_recursions});
    std.log.info("- Max ray distance: {}", .{self.scene_boundaries});
    // TODO: indicate if a file will be outputted, where, and what format
    std.log.info("- Output format (width, height): {},{}", .{ self.pic_width, self.pic_height });
}

// Copyright Guillaume Derex 2020-2026 (GPL-3.0)
