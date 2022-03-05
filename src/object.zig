const zlm = @import("zlm").SpecializeOn(f64);
const std = @import("std");
const PrimitiveFn = @import("primitives.zig").PrimitiveFn;
const Material = @import("Material.zig");

const ObjectTypes = enum {
    primitive,
    transform,
    csg,
    repeat
};

pub const Object = union(ObjectTypes) {
    var arena: std.heap.ArenaAllocator = undefined;
    var alloc: std.mem.Allocator = undefined;

    pub fn initArena(allocator: std.mem.Allocator) void {
        arena = std.heap.ArenaAllocator.init(allocator);
        alloc = arena.allocator();
    }

    pub fn freeArena() void {
        arena.deinit();
        arena = undefined;
        alloc = undefined;
    }

    pub fn distance(self: Object, pos: zlm.Vec3) f64 {
        switch (self) {
            .primitive => return self.primitive(pos),
            .transform => |transform| {
                var transformed = pos;
                //rotate
                if (!transform.rotate.eql(zlm.Vec3.zero)) {
                    {   //x
                        const sc = transform._xsincos;
                        const new_y = sc.y * transformed.y - sc.x * transformed.z;
                        const new_z = sc.x * transformed.y + sc.y * transformed.z;
                        transformed.y = new_y;
                        transformed.z = new_z;
                    }
                    {   //y
                        const sc = transform._ysincos;
                        const new_x = sc.y * transformed.x + sc.x * transformed.z;
                        const new_z = sc.y * transformed.z - sc.x * transformed.x;
                        transformed.x = new_x;
                        transformed.z = new_z;
                    }
                    {   //z
                        const sc = transform._zsincos;
                        const new_x = sc.y * transformed.x - sc.x * transformed.y;
                        const new_y = sc.x * transformed.x + sc.y * transformed.y;
                        transformed.x = new_x;
                        transformed.y = new_y;
                    }
                }
                //scale
                if (!transform.scale.eql(zlm.Vec3.one))
                    transformed = transformed.div(transform.scale);
                //translate
                transformed = transformed.sub(transform.translate);
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

                if (repeat.axis & 0b100 != 0)  //x
                    transformed.x = mmodulo(transformed.x, repeat.modulo);
                if (repeat.axis & 0b010 != 0)  //y
                    transformed.y = mmodulo(transformed.y, repeat.modulo);
                if (repeat.axis & 0b001 != 0)  //z
                    transformed.z = mmodulo(transformed.z, repeat.modulo);

                return self.repeat.o.distance(transformed);
            }
        }
    }

    pub fn initPrimitive(function: PrimitiveFn) !*Object {
        var ptr = try alloc.create(Object);
        errdefer alloc.destroy(ptr);
        ptr.* = .{ .primitive = function };
        return ptr;
    }

    pub fn initTransform(object: *Object, rotate: zlm.Vec3, scale: zlm.Vec3, translate: zlm.Vec3) !*Object {
        var ptr = try alloc.create(Object);
        errdefer alloc.destroy(ptr);
        const cos = std.math.cos;
        const sin = std.math.sin;
        ptr.* = .{ .transform = .{
            .o = object,
            .rotate = rotate,
            .scale = scale,
            .translate = translate,
            ._xsincos = .{ .x = sin(rotate.x), .y = cos(rotate.x) },
            ._ysincos = .{ .x = sin(rotate.y), .y = cos(rotate.y) },
            ._zsincos = .{ .x = sin(rotate.z), .y = cos(rotate.z) },
        }};
        return ptr;
    }

    pub fn initCSG(obj_a: *Object, obj_b: *Object, csg: CSGType) !*Object {
        var ptr = try alloc.create(Object);
        errdefer alloc.destroy(ptr);
        ptr.* = .{ .csg = .{
            .a = obj_a,
            .b = obj_b,
            .mode = csg
        }};
        return ptr;
    }

    pub fn initRepeat(object: *Object, axis: u3, modulo: f64) !*Object {
        var ptr = try alloc.create(Object);
        errdefer alloc.destroy(ptr);
        ptr.* = .{ .repeat = .{
            .o = object,
            .axis = axis,
            .modulo = modulo
        }};
        return ptr;
    }

    pub fn deinit(self: Object) void {
        switch (self) {
            .primitive => {},
            .transform => |transform| { 
                transform.o.deinit();
                alloc.destroy(transform.o); 
            },
            .csg => |csg| {
                csg.a.deinit();
                csg.b.deinit();
                alloc.destroy(csg.a);
                alloc.destroy(csg.b);
            },
            .repeat => |repeat| {
                repeat.o.deinit();
                alloc.destroy(repeat.o); 
            }
        }
    }

    primitive: PrimitiveFn,
    transform: struct {
        o: *Object,
        rotate: zlm.Vec3,
        scale: zlm.Vec3,
        translate: zlm.Vec3,
        _xsincos: zlm.Vec2,
        _ysincos: zlm.Vec2,
        _zsincos: zlm.Vec2,
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

fn mmodulo(f: f64, m: f64) f64 {
    return @mod(f + m / 2, m) - m / 2;
}

//Guillaume Derex 2020-2022