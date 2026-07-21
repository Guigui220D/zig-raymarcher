//! This struct is a temporary storage for the various values we are waiting for to calculate the color of a ray
const std = @import("std");
const zlm = @import("zlm").as(f64);
const Color = @import("color.zig").Color;
const Canvas = @import("Canvas.zig");
const settings = @import("settings.zig");
const Ray = @import("Ray.zig");

/// This struct stores all the needed intermediary results for the compute of a pixel
/// The resulting color will be sent to the target
pub const ResultStorage = struct {
    // TODO: encode the fact some rays don't need reflection or refraction (depending on the mat)
    /// Result of the initial ray (color of the material)
    albedo: Color,
    /// Results of the reflection ray. Null if it wasn't obtained yet
    reflected: ?Color,
    //refracted: ?Color,
    /// Number of lights rays we are waiting for yet. 0 indicates we are done
    remaining_lights: usize,
    /// Cumulative light level from the light rays we obtained
    light_sources: Color,
    /// Target of this storage
    target: Target,
    /// Number of times issued rays can recurse
    max_bounces: usize,

    pub fn init(albedo: Color, target: Target, bounces_left: usize) ResultStorage {
        return .{
            .albedo = albedo,
            .reflected = null,
            .remaining_lights = 0, // TODO
            .light_sources = Color{},
            .target = target,
            .max_bounces = bounces_left,
        };
    }

    /// Returns true if we have the necessary information for the target
    pub fn isDone(self: ResultStorage) bool {
        return self.remaining_lights == 0 and self.reflected != null;
    }

    /// Computes the color and applies the result to the target
    /// Can only be called if isDone is true
    pub fn applyToTarget(self: ResultStorage) void {
        std.debug.assert(self.remaining_lights == 0);
        std.debug.assert(self.reflected != null);

        const col: Color = self.computeColor();

        self.target.apply(col);
    }

    /// Computes the color from the obtained data
    /// Can only be called if isDone is true
    fn computeColor(self: ResultStorage) Color {
        return self.albedo; // TODO
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
    pub fn hit(self: Target, alloc: std.mem.Allocator, col: Color, ray: Ray, rays: *Ray.Rays) !bool {
        const bounces_left = switch (self) {
            .dummy => 0,
            //.pixel => settings.max_reflections,
            .pixel => 0, // TODO: temporary
            .reflected => |sto| sto.max_bounces,
            .light_fetch => |sto| sto.max_bounces,
        };

        if (bounces_left == 0) {
            self.apply(col);
            return false;
        } else {
            // Instanciate new ResultStorage and throw rays
            const result_storage = try alloc.create(ResultStorage);
            errdefer alloc.destroy(result_storage);
            result_storage.* = ResultStorage.init(col, self, bounces_left - 1);

            // TODO Send reflection
            // TODO: do not send when material doesn't require it
            //var reflection = ray.reflect(normal);
            //reflection.target = .{ .reflected = result_storage };
            //rays.append(reflection);
            _ = rays;
            _ = ray;

            return true;
        }
    }

    /// Applies the obtained color to wherever it is needed
    fn apply(self: Target, col: Color) void {
        // TODO: check for result storages that we are done to further collapse tree
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
