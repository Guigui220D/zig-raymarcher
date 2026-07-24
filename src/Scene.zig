//! A struct with all the elements of a scene
const std = @import("std");

const Renderable = @import("Renderable.zig");
const LightSource = @import("LightSource.zig");
const Material = @import("Material.zig");

/// Arena allocator to easily deinit everything at the end
arena: std.heap.ArenaAllocator,
/// Materials used by the scene (indexed with usize by objects)
materials: []const Material,
/// Scene tree (list of recursive objects with their metadata)
objects: []const Renderable,
/// Point light sources
lights: []const LightSource,
/// Global light source that every object receives no matter their position
global_light: LightSource,

const Scene = @This();

/// Deinits a scene object. Initialization is done by the scene loader
pub fn deinit(self: Scene) void {
    self.arena.deinit();
}

//Guillaume Derex 2026
