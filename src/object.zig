const zlm = @import("zlm").as(f64);
const std = @import("std");
const PrimitiveFn = @import("primitives.zig").PrimitiveFn;
const Material = @import("Material.zig");

const ObjectTypes = enum { primitive, transform, csg, repeat, meld };

pub const Object = union(ObjectTypes) {
    pub fn distance(self: Object, pos: zlm.Vec3) f64 {
        switch (self) {
            .primitive => return self.primitive(pos),
            .transform => |transform| {
                var transformed = pos;
                //rotate
                if (!transform.rotate.eql(zlm.Vec3.zero)) {
                    { //x
                        const sc = transform._xsincos;
                        const new_y = sc.y * transformed.y - sc.x * transformed.z;
                        const new_z = sc.x * transformed.y + sc.y * transformed.z;
                        transformed.y = new_y;
                        transformed.z = new_z;
                    }
                    { //y
                        const sc = transform._ysincos;
                        const new_x = sc.y * transformed.x + sc.x * transformed.z;
                        const new_z = sc.y * transformed.z - sc.x * transformed.x;
                        transformed.x = new_x;
                        transformed.z = new_z;
                    }
                    { //z
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
                const a = csg.a.distance(pos);
                const b = csg.b.distance(pos);

                return switch (csg.mode) {
                    .intersectionSDF => @max(a, b),
                    .unionSDF => @min(a, b),
                    .differenceSDF => @max(a, -b),
                };
            },
            .repeat => |repeat| {
                var transformed = pos;

                if (repeat.axis & 0b100 != 0) //x
                    transformed.x = mmodulo(transformed.x, repeat.modulo);
                if (repeat.axis & 0b010 != 0) //y
                    transformed.y = mmodulo(transformed.y, repeat.modulo);
                if (repeat.axis & 0b001 != 0) //z
                    transformed.z = mmodulo(transformed.z, repeat.modulo);

                return self.repeat.o.distance(transformed);
            },
            .meld => |meld| {
                const a = meld.a.distance(pos);
                const b = meld.b.distance(pos);

                return softmin(a, b, meld.meld_factor);
            },
        }
    }

    pub fn bakeTransform(object: *Object, rotate: zlm.Vec3, scale: zlm.Vec3, translate: zlm.Vec3) Object {
        return .{
            .transform = .{
                .o = object,
                .rotate = rotate,
                .scale = scale,
                .translate = translate,
                ._xsincos = .{ .x = @sin(rotate.x), .y = @cos(rotate.x) },
                ._ysincos = .{ .x = @sin(rotate.y), .y = @cos(rotate.y) },
                ._zsincos = .{ .x = @sin(rotate.z), .y = @cos(rotate.z) },
            },
        };
    }

    // TODO: find ways to reduce tree depth: always transform primitives, add parameters to primitives
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
        mode: CSGType,
    },
    repeat: struct {
        o: *Object,
        axis: u3, //flags for each axis
        modulo: f64,
    },
    meld: struct {
        a: *Object,
        b: *Object,
        meld_factor: f64,
    },
};

pub const CSGType = enum(u2) { intersectionSDF, unionSDF, differenceSDF };

inline fn mmodulo(f: f64, m: f64) f64 {
    return @mod(f + m / 2, m) - m / 2;
}

inline fn softmax(a: f64, b: f64, k: f64) f64 {
    const m = @max(a, b);
    return m + @log(@exp(k * (a - m)) + @exp(k * (b - m))) / k;
}

inline fn softmin(a: f64, b: f64, k: f64) f64 {
    return -softmax(-a, -b, k);
}

//Guillaume Derex 2020-2026
