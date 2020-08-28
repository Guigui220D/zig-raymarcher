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
    transform,
    csg
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
                return self.transform.o.distance(transformed);
            },
            .csg => {
                var a = self.csg.a.distance(pos);
                var b = self.csg.b.distance(pos);

                return switch (self.csg.csg) {
                    .intersectionSDF => std.math.max(a, b),
                    .unionSDF => std.math.min(a, b),
                    .differenceSDF => std.math.max(a, -b)
                };
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
            .o = object,
            .rotate = rotate,
            .scale = scale,
            .translate = translate
        }};
        return ptr;
    }

    pub fn initCSG(allocator: *std.mem.Allocator, obj_a: *Object, obj_b: *Object, csg: CSGType) !*Object {
        var ptr = try allocator.create(Object);
        errdefer allocator.destroy(ptr);
        ptr.* = .{ .csg = .{
            .a = obj_a,
            .b = obj_b,
            .csg = csg
        }};
        return ptr;
    }

    pub fn deinit(self: Object, allocator: *std.mem.Allocator) void {
        switch (self) {
            .primitive => {},
            .transform => { 
                self.transform.o.deinit(allocator);
                allocator.destroy(self.transform.o); 
            },
            .csg => {
                self.csg.a.deinit(allocator);
                self.csg.b.deinit(allocator);
                allocator.destroy(self.csg.a);
                allocator.destroy(self.csg.b);
            }
        }
    }

    primitive: PrimitiveFn,
    transform: struct {
        o: *Object,
        rotate: Vec3,
        scale: Vec3,
        translate: Vec3
    },
    csg: struct {
        a: *Object,
        b: *Object,
        csg: CSGType
    }
};

pub const CSGType = enum(u2) {
    intersectionSDF,
    unionSDF,
    differenceSDF
};

//Guillaume Derex 2020