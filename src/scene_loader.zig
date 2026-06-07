const std = @import("std");
const zlm = @import("zlm").as(f64);

const Material = @import("Material.zig");
const Object = @import("object.zig").Object;
const Renderable = @import("Renderable.zig");
const Scene = @import("Scene.zig");
const Color = @import("color.zig").Color;
const primitives = @import("primitives.zig");
const csscolorparser = @import("csscolorparser");

pub fn loadScene(alloc: std.mem.Allocator, io: std.Io, path: []const u8) !Scene {
    const cwd = std.Io.Dir.cwd();
    var file = try cwd.openFile(io, path, .{ .mode = .read_only });
    defer file.close(io);

    var freader = file.reader(io, &.{});
    const reader = &freader.interface;

    const data = try reader.allocRemaining(alloc, .unlimited);
    defer alloc.free(data);

    const json = try std.json.parseFromSlice(std.json.Value, alloc, data, .{});
    defer json.deinit();

    // TODO: better error management from unexpected/absent json values: avoid .?, check union values

    // Arena for the scene
    var arena: std.heap.ArenaAllocator = .init(alloc);
    const arena_alloc = arena.allocator();
    errdefer arena.deinit();

    // Parse materials
    var mats: std.ArrayList(Material) = .empty;
    errdefer mats.deinit(arena_alloc);

    var mat_names: std.StringHashMap(usize) = .init(alloc);
    defer mat_names.deinit();

    const materials = json.value.object.get("materials").?;
    var mat_it = materials.object.iterator();
    while (mat_it.next()) |mat_entry| {
        // Read material
        const new_mat = try readMaterial(mat_entry.value_ptr);
        // Id for names
        const mat_id = mats.items.len;
        // Add material
        try mats.append(arena_alloc, new_mat);
        errdefer _ = mats.pop();
        // Get name
        try mat_names.put(mat_entry.key_ptr.*, mat_id);
        errdefer _ = mat_names.remove(mat_id);
    }

    // Parse objects
    var objs: std.ArrayList(Renderable) = .empty;
    errdefer mats.deinit(arena_alloc);

    const contents = json.value.object.get("contents").?;
    const obj_items = contents.array.items;
    for (obj_items) |obj_entry| {
        // Read renderable
        const new_obj = try readRenderable(arena_alloc, &obj_entry, &mat_names);
        try objs.append(arena_alloc, new_obj);
    }

    const camera = json.value.object.get("camera").?;
    _ = camera;

    return .{
        .arena = arena,
        .materials = try mats.toOwnedSlice(arena_alloc),
        .objects = try objs.toOwnedSlice(arena_alloc),
        .lights = &.{},
        .global_light = .{},
    };
}

// TODO: add errors on unexpected fields (rather than ignore them)

fn readRenderable(alloc: std.mem.Allocator, value: *const std.json.Value, material_names: *std.StringHashMap(usize)) !Renderable {
    if (value.* != .object)
        return error.BadRenderableJson;

    const ren_def = &value.object;

    // Get material
    // TODO: default material for recovery
    const mat_name = ren_def.get("material") orelse return error.BadRenderableJson;
    if (mat_name != .string)
        return error.BadRenderableJson;
    const mat_id = material_names.get(mat_name.string) orelse return error.NoSuchMaterial;

    // Get object
    const obj_def = ren_def.get("object") orelse return error.BadRenderableJson;
    const obj = try readObject(alloc, &obj_def);
    errdefer obj.deinit(alloc);

    return .{
        .material_id = mat_id,
        .object = obj,
    };
}

fn readObject(alloc: std.mem.Allocator, value: *const std.json.Value) !Object {
    if (value.* != .object)
        return error.BadObjectJson;

    const obj_def = &value.object;

    // Get type
    const type_name = obj_def.get("type") orelse return error.BadObjectJson;
    if (type_name != .string)
        return error.BadObjectJson;

    var ret: ?Object = null;

    // Read depending on type
    if (std.mem.eql(u8, "transform", type_name.string))
        ret = try readTransformObject(alloc, obj_def);

    if (std.mem.eql(u8, "primitive", type_name.string))
        ret = try readPrimitiveObject(alloc, obj_def);

    return ret orelse error.BadObjectJson;
}

fn readMaterial(value: *std.json.Value) !Material {
    if (value.* != .object)
        return error.BadMaterialJson;

    var new_mat = Material{};
    const mat_def = &value.object;

    // Get color
    if (mat_def.get("diffuse")) |dif_entry| {
        new_mat.diffuse = try readColor(&dif_entry);
    }
    // Reflectivity
    if (mat_def.get("reflectivity")) |refl_entry| {
        const refl = refl_entry.float;
        new_mat.reflectivity = @floatCast(refl);
    }
    // TODO: diffuse2 or advanced textures

    return new_mat;
}

fn readColor(value: *const std.json.Value) !Color {
    if (value.* != .string)
        return error.BadColorJson;

    const color = csscolorparser.Color(f32).parse(value.string) catch |e| {
        std.debug.print("Error {} while parsing color \"{s}\".\n", .{ e, value.string });
        return error.BadColorJson;
    };

    return .{
        .a = color.alpha,
        .r = color.red,
        .g = color.green,
        .b = color.blue,
    };
}

// TODO: avoid anyerror, define set
fn readTransformObject(alloc: std.mem.Allocator, object: *const std.json.ObjectMap) anyerror!Object {
    //std.debug.print("Reading transform object...\n", .{});
    // Get object
    const obj_def = object.get("object") orelse return error.BadTransformJson;
    const obj = try readObject(alloc, &obj_def);

    // Default values
    var rotate: zlm.Vec3 = .zero;
    var scale: zlm.Vec3 = .one;
    var translate: zlm.Vec3 = .zero;

    // Translation
    if (object.get("x")) |x| {
        if (x != .float)
            return error.BadTransformJson;
        translate.x = x.float;
    }
    if (object.get("y")) |y| {
        if (y != .float)
            return error.BadTransformJson;
        translate.y = y.float;
    }
    if (object.get("z")) |z| {
        if (z != .float)
            return error.BadTransformJson;
        translate.z = z.float;
    }

    // Rotation
    if (object.get("roll")) |roll| {
        if (roll != .float)
            return error.BadTransformJson;
        rotate.x = roll.float;
    }
    if (object.get("yaw")) |yaw| {
        if (yaw != .float)
            return error.BadTransformJson;
        rotate.y = yaw.float;
    }
    if (object.get("pitch")) |pitch| {
        if (pitch != .float)
            return error.BadTransformJson;
        rotate.z = pitch.float;
    }

    // Scale
    if (object.get("scale")) |fullscale| {
        if (fullscale != .float)
            return error.BadTransformJson;
        scale.x = fullscale.float;
        scale.y = fullscale.float;
        scale.z = fullscale.float;
    }
    if (object.get("sx")) |x| {
        if (x != .float)
            return error.BadTransformJson;
        scale.x = x.float;
    }
    if (object.get("sy")) |y| {
        if (y != .float)
            return error.BadTransformJson;
        scale.y = y.float;
    }
    if (object.get("sz")) |z| {
        if (z != .float)
            return error.BadTransformJson;
        scale.z = z.float;
    }

    const obj_copy = try alloc.create(Object);
    errdefer alloc.destroy(obj_copy);
    obj_copy.* = obj;
    return Object.bakeTransform(obj_copy, rotate, scale, translate);
}

fn readPrimitiveObject(_: std.mem.Allocator, object: *const std.json.ObjectMap) anyerror!Object {
    //std.debug.print("Reading primitive object...\n", .{});
    // Get type
    const type_name = object.get("primitive") orelse return error.BadPrimitiveJson;
    if (type_name != .string)
        return error.BadPrimitiveJson;

    // Read depending on type
    const primitive = try primitives.primitiveFromName(type_name.string);
    return .{
        .primitive = primitive,
    };
}

//Guillaume Derex
