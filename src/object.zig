//! Object union for the scene tree. See object/ folder for object types
const zlm = @import("zlm").as(f64);
const std = @import("std");
const Primitive = @import("object/Primitive.zig");
const Transform = @import("object/Transform.zig");
const Csg = @import("object/Csg.zig");
const Repeat = @import("object/Repeat.zig");
const Meld = @import("object/Meld.zig");
const Negate = @import("object/Negate.zig");
const Vf64 = @import("vector.zig").Vf64;

/// Object union for the scene tree
pub const Object = union(enum) {
    // TODO: does the switch have an impact when called repeatedly?
    /// Obtain distance to object
    /// Non-vectorized version which is only used for some specific, rarer operations
    pub fn distance(self: Object, pos: zlm.Vec3) f64 {
        return switch (self) {
            .primitive => |pri| pri.distanceFn(pos),
            inline else => |obj| obj.distance(pos),
        };
    }

    /// Obtain distance to object (vectorized)
    pub fn vDistance(self: Object, xs: Vf64, ys: Vf64, zs: Vf64) Vf64 {
        return switch (self) {
            .primitive => |pri| pri.vDistanceFn(xs, ys, zs),
            inline else => |obj| obj.vDistance(xs, ys, zs),
        };
    }

    /// Calculates the normal of that object from a point that is (near) the surface
    pub fn normal(self: Object, pos: zlm.Vec3) zlm.Vec3 {
        const dist = self.distance(pos);

        return zlm.Vec3.normalize(zlm.vec3(
            self.distance(pos.add(zlm.vec3(0.01, 0, 0))) - dist,
            self.distance(pos.add(zlm.vec3(0, 0.01, 0))) - dist,
            self.distance(pos.add(zlm.vec3(0, 0, 0.01))) - dist,
        ));
    }

    // TODO: find ways to reduce tree depth: always transform primitives, add parameters to primitives (would this actually help?)
    /// Primitive object
    primitive: Primitive,
    /// Transform of an other object in 3D space
    transform: Transform,
    /// Constructive geometry between two objects
    csg: Csg,
    /// Repetition of an object along select axes
    repeat: Repeat,
    /// Gooey meld between two objects
    meld: Meld,
    /// Inside out object
    negate: Negate,
};

//Guillaume Derex 2020-2026
