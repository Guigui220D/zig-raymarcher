usingnamespace @import("vector.zig");
const std = @import("std");
const PrimitiveFn = @import("primitives.zig").PrimitiveFn;
const Material = @import("material.zig").Material;

pub const Renderable = struct {
    pub fn init(material: Material, object: *Object) Renderable {
        return Renderable{
            .material = material,
            .object = object,
        };
    }

    pub fn deinit(self: Renderable, allocator: *std.mem.Allocator) void {
        self.object.deinit(allocator);
        allocator.destroy(self.object);
    }

    material: Material,
    object: *Object
};

const ObjectTypes = enum {
    primitive,
    transform
};

pub const Object = union(ObjectTypes) {
    pub fn distance(self: Object, pos: Vec3) f64 {
        switch (self) {
            .primitive => return self.primitive(pos),
            .transform => {
                var transformed = pos;
                //rotate
                //TODO
                //scale
                transformed = transformed.divide(self.transform.scale);
                //translate
                transformed = transformed.difference(self.transform.translate);
                return self.transform.object.distance(transformed);
            }
        }
    }

    pub fn initPrimitive(allocator: *std.mem.Allocator, function: PrimitiveFn) !*Object {
        var ptr = try allocator.create(Object);
        errdefer allocator.destroy(ptr);
        ptr.* = .{ .primitive = function };
        return ptr;
    }

    pub fn initTransform(allocator: *std.mem.Allocator, object: *Object, rotate: Vec3, scale: Vec3, translate: Vec3) !*Object {
        var ptr = try allocator.create(Object);
        errdefer allocator.destroy(ptr);
        ptr.* = .{ .transform = .{
            .object = object,
            .rotate = rotate,
            .scale = scale,
            .translate = translate
        }};
        return ptr;
    }

    pub fn deinit(self: Object, allocator: *std.mem.Allocator) void {
        switch (self) {
            .primitive => {},
            .transform => { 
                self.transform.object.deinit(allocator);
                allocator.destroy(self.transform.object); 
            }
        }
    }

    primitive: PrimitiveFn,
    transform: struct {
        object: *Object,
        rotate: Vec3,
        scale: Vec3,
        translate: Vec3
    }
};
