const std = @import("std");

const Renderable = @import("Renderable.zig");
const LightSource = @import("LightSource.zig");
const Material = @import("Material.zig");

arena: std.heap.ArenaAllocator,
materials: []const Material,
objects: []const Renderable,
lights: []const LightSource,
global_light: LightSource,

const Scene = @This();

pub fn deinit(self: Scene) void {
    self.arena.deinit();
}

//Guillaume Derex 2026
