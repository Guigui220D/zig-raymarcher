usingnamespace @import("vector.zig");
const PrimitiveFn = @import("primitives.zig").PrimitiveFn;
const Material = @import("material.zig").Material;

pub const Renderable = struct {
    pub fn init(material: Material, object: Object) Renderable {
        return Renderable{
            .material = material,
            .object = object,
        };
    }

    material: Material,
    object: Object
};

const ObjectTypes = enum {
    primitive
};

pub const Object = union(ObjectTypes) {
    pub fn distance(self: Object, pos: Vec3) f64 {
        switch (self) {
            .primitive => return self.primitive(pos),
        }
    }

    pub fn initPrimitive(function: PrimitiveFn) Object {
        return Object{ .primitive = function };
    }

    primitive: PrimitiveFn
};
