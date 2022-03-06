const Renderable = @import("Renderable.zig");
const LightSource = @import("LightSource.zig");

objects: []const Renderable,
lights: []const LightSource,
global_light: LightSource

//Guillaume Derex 2022