const Vec3 = @import("vector.zig").Vec3;
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

    pub fn deinit(self: Renderable, allocator: std.mem.Allocator) void {
        self.object.deinit(allocator);
        allocator.destroy(self.object);
    }

    material: Material,
    object: *Object
};

const ObjectTypes = enum {
    primitive,
    transform,
    csg,
    repeat
};

pub const Object = union(ObjectTypes) {
    pub fn distance(self: Object, pos: Vec3) f64 {
        switch (self) {
            .primitive => return self.primitive(pos),
            .transform => |transform| {
                var transformed = pos;
                //rotate
                if (!transform.rotate.eql(Vec3.nul)) {
                    const cos = std.math.cos;
                    const sin = std.math.sin;
                    {   //x
                        const theta = transform.rotate.x;
                        const ct = cos(theta);
                        const st = sin(theta);
                        const new_y = ct * transformed.y - st * transformed.z;
                        const new_z = st * transformed.y + ct * transformed.z;
                        transformed.y = new_y;
                        transformed.z = new_z;
                    }
                    {   //y
                        const theta = transform.rotate.y;
                        const ct = cos(theta);
                        const st = sin(theta);
                        const new_x = ct * transformed.x + st * transformed.z;
                        const new_z = ct * transformed.z - st * transformed.x;
                        transformed.x = new_x;
                        transformed.z = new_z;
                    }
                    {   //z
                        const theta = transform.rotate.z;
                        const ct = cos(theta);
                        const st = sin(theta);
                        const new_x = ct * transformed.x - st * transformed.y;
                        const new_y = st * transformed.x + ct * transformed.y;
                        transformed.x = new_x;
                        transformed.y = new_y;
                    }
                }
                //scale
                if (!transform.scale.eql(Vec3.one))
                    transformed = transformed.divide(transform.scale);
                //translate
                transformed = transformed.difference(transform.translate);
                return transform.o.distance(transformed);
            },
            .csg => |csg| {
                var a = csg.a.distance(pos);
                var b = csg.b.distance(pos);

                return switch (csg.mode) {
                    .intersectionSDF => std.math.max(a, b),
                    .unionSDF => std.math.min(a, b),
                    .differenceSDF => std.math.max(a, -b)
                };
            },
            .repeat => |repeat| {
                var transformed = pos;

                if (repeat.axis & 0b001 != 0)  //x
                    transformed.x = std.math.modf(transformed.x / repeat.modulo).fpart * repeat.modulo;
                if (repeat.axis & 0b010 != 0)  //y
                    transformed.y = std.math.modf(transformed.y / repeat.modulo).fpart * repeat.modulo;
                if (repeat.axis & 0b100 != 0)  //z
                    transformed.z = std.math.modf(transformed.z / repeat.modulo).fpart * repeat.modulo;

                return self.repeat.o.distance(transformed);
            }
        }
    }

    pub fn initPrimitive(allocator: std.mem.Allocator, function: PrimitiveFn) !*Object {
        var ptr = try allocator.create(Object);
        errdefer allocator.destroy(ptr);
        ptr.* = .{ .primitive = function };
        return ptr;
    }

    pub fn initTransform(allocator: std.mem.Allocator, object: *Object, rotate: Vec3, scale: Vec3, translate: Vec3) !*Object {
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

    pub fn initCSG(allocator: std.mem.Allocator, obj_a: *Object, obj_b: *Object, csg: CSGType) !*Object {
        var ptr = try allocator.create(Object);
        errdefer allocator.destroy(ptr);
        ptr.* = .{ .csg = .{
            .a = obj_a,
            .b = obj_b,
            .mode = csg
        }};
        return ptr;
    }

    pub fn initRepeat(allocator: std.mem.Allocator, axis: u3, modulo: f64, object: *Object) !*Object {
        var ptr = try allocator.create(Object);
        errdefer allocator.destroy(ptr);
        ptr.* = .{ .repeat = .{
            .o = object,
            .axis = axis,
            .modulo = modulo
        }};
        return ptr;
    }

    pub fn deinit(self: Object, allocator: std.mem.Allocator) void {
        switch (self) {
            .primitive => {},
            .transform => |transform| { 
                transform.o.deinit(allocator);
                allocator.destroy(transform.o); 
            },
            .csg => |csg| {
                csg.a.deinit(allocator);
                csg.b.deinit(allocator);
                allocator.destroy(csg.a);
                allocator.destroy(csg.b);
            },
            .repeat => |repeat| {
                repeat.o.deinit(allocator);
                allocator.destroy(repeat.o); 
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
        mode: CSGType
    },
    repeat: struct {
        o: *Object,
        axis: u3,   //flags for each axis
        modulo: f64
    }
};

pub const CSGType = enum(u2) {
    intersectionSDF,
    unionSDF,
    differenceSDF
};

//Guillaume Derex 2020