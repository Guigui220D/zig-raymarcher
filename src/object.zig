const zlm = @import("zlm").as(f64);
const std = @import("std");
const PrimitiveFn = @import("primitives.zig").PrimitiveFn;
const Material = @import("Material.zig");
const Vf64 = @import("vector.zig").Vf64;

const ObjectTypes = enum { primitive, transform, csg, repeat, meld };

pub const Object = union(ObjectTypes) {
    pub fn vDistance(self: Object, xs: Vf64, ys: Vf64, zs: Vf64) Vf64 {
        switch (self) {
            .primitive => |primitive| {
                var tx = xs;
                var ty = ys;
                var tz = zs;

                // rotate TODO
                if (!primitive.rotate.eql(zlm.Vec3.zero)) {
                    { //x
                        const scx: Vf64 = @splat(primitive._xsincos.x);
                        const scy: Vf64 = @splat(primitive._xsincos.y);
                        const new_y = scy * ty - scx * tz;
                        const new_z = scx * ty + scy * tz;
                        ty = new_y;
                        tz = new_z;
                    }
                    { //y
                        const scx: Vf64 = @splat(primitive._ysincos.x);
                        const scy: Vf64 = @splat(primitive._ysincos.y);
                        const new_x = scy * tx + scx * tz;
                        const new_z = scy * tz - scx * tx;
                        tx = new_x;
                        tz = new_z;
                    }
                    { //z
                        const scx: Vf64 = @splat(primitive._zsincos.x);
                        const scy: Vf64 = @splat(primitive._zsincos.y);
                        const new_x = scy * tx - scx * ty;
                        const new_y = scx * tx + scy * ty;
                        tx = new_x;
                        ty = new_y;
                    }
                }

                // scale
                if (!primitive.scale.eql(zlm.Vec3.one)) {
                    tx /= @splat(primitive.scale.x);
                    ty /= @splat(primitive.scale.y);
                    tz /= @splat(primitive.scale.z);
                }

                // translate
                tx -= @splat(primitive.translate.x);
                ty -= @splat(primitive.translate.y);
                tz -= @splat(primitive.translate.z);

                return primitive.p(tx, ty, tz);
            },
            .transform => |transform| {
                var tx = xs;
                var ty = ys;
                var tz = zs;

                // rotate TODO
                if (!transform.rotate.eql(zlm.Vec3.zero)) {
                    { //x
                        const scx: Vf64 = @splat(transform._xsincos.x);
                        const scy: Vf64 = @splat(transform._xsincos.y);
                        const new_y = scy * ty - scx * tz;
                        const new_z = scx * ty + scy * tz;
                        ty = new_y;
                        tz = new_z;
                    }
                    { //y
                        const scx: Vf64 = @splat(transform._ysincos.x);
                        const scy: Vf64 = @splat(transform._ysincos.y);
                        const new_x = scy * tx + scx * tz;
                        const new_z = scy * tz - scx * tx;
                        tx = new_x;
                        tz = new_z;
                    }
                    { //z
                        const scx: Vf64 = @splat(transform._zsincos.x);
                        const scy: Vf64 = @splat(transform._zsincos.y);
                        const new_x = scy * tx - scx * ty;
                        const new_y = scx * tx + scy * ty;
                        tx = new_x;
                        ty = new_y;
                    }
                }

                // scale
                if (!transform.scale.eql(zlm.Vec3.one)) {
                    tx /= @splat(transform.scale.x);
                    ty /= @splat(transform.scale.y);
                    tz /= @splat(transform.scale.z);
                }

                // translate
                tx -= @splat(transform.translate.x);
                ty -= @splat(transform.translate.y);
                tz -= @splat(transform.translate.z);

                return transform.o.vDistance(tx, ty, tz);
            },
            .csg => |csg| {
                const a = csg.a.vDistance(xs, ys, zs);
                const b = csg.b.vDistance(xs, ys, zs);

                return switch (csg.mode) {
                    .intersectionSDF => @max(a, b),
                    .unionSDF => @min(a, b),
                    .differenceSDF => @max(a, -b),
                };
            },
            .repeat => |repeat| {
                // TODO
                return repeat.o.vDistance(xs, ys, zs);
            },
            .meld => |meld| {
                // TODO
                return meld.a.vDistance(xs, ys, zs);
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

    pub fn bakePrimitive(primitive: PrimitiveFn, rotate: zlm.Vec3, scale: zlm.Vec3, translate: zlm.Vec3) Object {
        return .{
            .primitive = .{
                .p = primitive,
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
    primitive: struct {
        p: PrimitiveFn,
        rotate: zlm.Vec3,
        scale: zlm.Vec3,
        translate: zlm.Vec3,
        _xsincos: zlm.Vec2,
        _ysincos: zlm.Vec2,
        _zsincos: zlm.Vec2,
    },
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

pub const CSGType = enum { intersectionSDF, unionSDF, differenceSDF };

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
