//! This struct is a temporary storage for the various values we are waiting for to calculate the color of a ray
const std = @import("std");
const zlm = @import("zlm").as(f64);
const Color = @import("color.zig").Color;
const Canvas = @import("Canvas.zig");
const Material = @import("Material.zig");
const settings = @import("settings.zig");
const Ray = @import("Ray.zig");

/// This struct stores all the needed intermediary results for the compute of a pixel
/// The resulting color will be sent to the target
pub const ResultStorage = struct {
    // TODO: encode the fact some rays don't need reflection or refraction (depending on the mat)
    /// Result of the initial ray (color of the material)
    material: Material,
    /// Results of the reflection ray. Null if it wasn't obtained yet
    reflected: ?Color,
    /// True if we sent a reflection ray
    expecting_reflection: bool,
    //refracted: ?Color,
    /// Number of lights rays we are waiting for yet. 0 indicates we are done
    remaining_lights: usize,
    /// Cumulative light level from the light rays we obtained
    light_sources: Color,
    /// Target of this storage
    target: Target,
    /// Number of times issued rays can recurse
    max_bounces: u8,

    pub fn init(material: Material, target: Target, bounces_left: u8) ResultStorage {
        return .{
            .material = material,
            .reflected = null,
            .expecting_reflection = false,
            .remaining_lights = 0, // TODO
            .light_sources = Color{},
            .target = target,
            .max_bounces = bounces_left,
        };
    }

    /// Returns true if we have the necessary information for the target
    pub fn isDone(self: ResultStorage) bool {
        return self.remaining_lights == 0 and (!self.expecting_reflection or self.reflected != null);
    }

    /// Computes the color and applies the result to the target
    /// Can only be called if isDone is true
    pub fn applyToTarget(self: ResultStorage) void {
        const col: Color = self.computeColor();
        self.target.apply(col);
    }

    /// Computes the color from the obtained data
    /// Can only be called if isDone is true
    fn computeColor(self: ResultStorage) Color {
        return Color.mix(self.material.diffuse, self.reflected orelse .{}, 1 - self.material.reflectivity);
    }
};

/// This union indicates what a ray is looking for
pub const Target = union(enum) {
    pixel: FinalPixel, // This ray is targetting a screen pixel
    reflected: *ResultStorage, // This ray is from a reflection
    //refracted: *ResultStorage, // This ray is from a refraction
    light_fetch: *ResultStorage, // This ray is aiming at a lightsource
    dummy: void,

    /// Called when the ray hits a surface. Sends more rays recursively for context.
    pub fn hit(self: Target, alloc: std.mem.Allocator, material: ?Material, ray: Ray, rays: *Ray.Rays, normal: zlm.Vec3) !bool {
        const bounces_left = self.getDepth();

        switch (settings.debug_mode) {
            .normal => {
                self.apply(.{
                    .a = 1.0,
                    .r = @floatCast(normal.x),
                    .g = @floatCast(normal.y),
                    .b = @floatCast(normal.z),
                });
                return false;
            },
            .reflection => {
                const reflection = ray.reflect(normal, .{ .dummy = {} });
                self.apply(.{
                    .a = 1.0,
                    .r = @floatCast(reflection.dir_x),
                    .g = @floatCast(reflection.dir_y),
                    .b = @floatCast(reflection.dir_z),
                });
                return false;
            },
            .rayinfo => {
                var r: f32 = @floatFromInt(ray.total_steps);
                r /= @floatFromInt(settings.max_steps);
                self.apply(.{
                    .a = 1.0,
                    .r = r,
                    .g = @floatFromInt(@intFromBool(ray.total_steps == settings.max_steps)),
                    .b = 0,
                });
                return false;
            },
            else => {},
        }

        if (material) |mat| {
            if (bounces_left == 0) {
                self.apply(mat.diffuse);
                return false;
            } else {
                // Instanciate new ResultStorage and throw rays
                const result_storage = try alloc.create(ResultStorage);
                errdefer alloc.destroy(result_storage);
                result_storage.* = ResultStorage.init(mat, self, bounces_left - 1);

                // TODO Send reflection only when material requires it
                if (mat.reflectivity != 0) {
                    var reflection = ray.reflect(normal, .{ .reflected = result_storage });
                    // Necessary to escape hitting the same thing again
                    reflection.pos_x += reflection.dir_x * 1.1;
                    reflection.pos_y += reflection.dir_y * 1.1;
                    reflection.pos_z += reflection.dir_z * 1.1;
                    rays.appendAssumeCapacity(reflection); // TODO: we cannot assume
                    result_storage.expecting_reflection = true;
                }

                if (result_storage.isDone()) {
                    // Turns out there is nothing to do
                    result_storage.applyToTarget();
                    alloc.destroy(result_storage);
                    return false;
                }

                return true;
            }
        } else {
            self.apply(Color{ .a = 1, .r = 0, .g = 0, .b = 0 });
            return false;
        }
    }

    /// Applies the obtained color to wherever it is needed
    fn apply(self: Target, col: Color) void {
        // Apply directly to the target
        switch (self) {
            .pixel => |pix| pix.apply(col),
            .reflected => |sto| sto.reflected = col,
            //.refracted => |sto| sto.refracted = col,
            .light_fetch => |sto| {
                sto.remaining_lights -= 1;
                sto.light_sources = .add(sto.light_sources, col);
            },
            .dummy => {},
        }

        // Collapse tree if needed
        switch (self) {
            .pixel => {},
            .dummy => {},
            inline else => |sto| if (sto.isDone()) {
                sto.applyToTarget();
                //alloc.destroy(sto); // TODO: can the arena allocator handle this?
            },
        }
    }

    /// Get how many more recursions we can do
    pub fn getDepth(self: Target) u8 {
        return switch (self) {
            .dummy => 0,
            .pixel => settings.max_reflections,
            .reflected => |sto| sto.max_bounces,
            .light_fetch => |sto| sto.max_bounces,
        };
    }
};

/// Reference to a pixel of the screen
pub const FinalPixel = struct {
    pix_x: usize,
    pix_y: usize,
    canvas: *const Canvas,

    /// Applies a color to the pixel targetted
    pub fn apply(self: FinalPixel, col: Color) void {
        self.canvas.data[self.pix_y * self.canvas.width + self.pix_x] = col;
    }
};
