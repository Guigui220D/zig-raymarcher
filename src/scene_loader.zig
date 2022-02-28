const std = @import("std");
const zlm = @import("zlm").SpecializeOn(f64);
const primitives = @import("primitives.zig");
const Color = @import("color.zig").Color;
const Object = @import("object.zig").Object;
const Renderable = @import("Renderable.zig");
const Material = @import("Material.zig");

pub fn loadSceneFromJson(json: []const u8, alloc: std.mem.Allocator) ![]Renderable {
    var parser = std.json.Parser.init(alloc, false);
    var values = try parser.parse(json);
    parser.deinit();
    defer values.deinit();

    if (values.root != .Object)
        return error.badContents;

    var root = &values.root.Object;

    if (root.get("contents")) |contents| {
        var scene_list = std.ArrayList(Renderable).init(alloc);
        errdefer scene_list.deinit();

        if (contents != .Array)
            return error.badContents;

        for (contents.Array.items) |renderable| {
            if (renderable != .Object) {
                std.debug.print("Scene element ignored because it is not a json object.\n", .{});
                continue;
            }
            // TODO: materials
            const object = (try objectFromJson(renderable.Object)) orelse continue;
            const blue = Material{ .diffuse = Color{ .r = 0, .g = 0, .b = 1.0 }, .reflectivity = 0.8 };

            try scene_list.append(.{ .object = object, .material = blue });
        }

        std.debug.print("Scene loaded with {} renderables.\n", .{ scene_list.items.len });
        return scene_list.toOwnedSlice();
    } else  
        return error.noSceneContents;
} 

fn objectFromJson(omap: std.json.ObjectMap) anyerror!?*Object {
    const no_transform = [3]zlm.Vec3{ zlm.Vec3.zero, zlm.Vec3.one, zlm.Vec3.zero };
    var transform = no_transform;

    var change = false;

    // TODO: support if those are ints
    if (omap.get("x")) |x| {
        change = true;
        if (x == .Float)
            transform[2].x = x.Float;
    }
    if (omap.get("y")) |y| {
        change = true;
        if (y == .Float)
            transform[2].y = y.Float;
    }
    if (omap.get("z")) |z| {
        change = true;
        if (z == .Float)
            transform[2].z = z.Float;
    }

    if (omap.get("roll")) |roll| {
        change = true;
        if (roll == .Float)
            transform[0].x = roll.Float;
    }
    if (omap.get("pitch")) |pitch| {
        change = true;
        if (pitch == .Float)
            transform[0].y = pitch.Float;
    }
    if (omap.get("yaw")) |yaw| {
        change = true;
        if (yaw == .Float)
            transform[0].z = yaw.Float;
    }

    if (omap.get("width")) |width| {
        change = true;
        if (width == .Float)
            transform[2].x = width.Float;
    }
    if (omap.get("height")) |height| {
        change = true;
        if (height == .Float)
            transform[2].y = height.Float;
    }
    if (omap.get("depth")) |depth| {
        change = true;
        if (depth == .Float)
            transform[2].z = depth.Float;
    }

    if (omap.get("scale")) |scale| {
        change = true;
        if (scale == .Float) {
            transform[2] = transform[2].scale(scale.Float);
        }
    }

    var obj: *Object = undefined;

    if (omap.get("primitive")) |primitive| {
        if (primitive != .String) {
            std.debug.print("Object with primitive that is not a string ignored.\n", .{});
            return null;
        }
        if (omap.get("csg")) |_|
            std.debug.print("CSG field ignored in object that is a primitive.\n", .{});

        const slice = primitive.String;
        const primitive_fn = primitives.primitiveFromName(slice);

        obj = try Object.initPrimitive(primitive_fn);
        // TODO: review memory management
    } else if (omap.get("csg")) |csg| {
        if (csg != .String) {
            std.debug.print("Object with CSG field that is not a string ignored.\n", .{});
            return null;
        }

        const a = omap.get("a") orelse {
            std.debug.print("CSG object missing a subobject ignored.\n", .{});
            return null;
        };
        const b = omap.get("b") orelse {
            std.debug.print("CSG object missing a subobject ignored.\n", .{});
            return null;
        };

        if (a != .Object or b != .Object) {
            std.debug.print("CSG object ignored because its subobjects are not objects.\n", .{});
            return null;
        }

        var obja = (try objectFromJson(a.Object)) orelse {
            std.debug.print("CSG object ignore because one of its subobjects is ill-formed.\n", .{});
            return null;
        };
        var objb = (try objectFromJson(b.Object)) orelse {
            std.debug.print("CSG object ignore because one of its subobjects is ill-formed.\n", .{});
            return null;
        };
        // TODO: other sdfs
        obj = try Object.initCSG(obja, objb, .unionSDF);
    } else {
        std.debug.print("Object which has no primitives nor CSGs ignored.\n", .{});
        return null;
    }

    if (change) {
        var obj_transform = try Object.initTransform(obj, transform[0], transform[1], transform[2]);
        obj = obj_transform;
    }

    return obj;
}