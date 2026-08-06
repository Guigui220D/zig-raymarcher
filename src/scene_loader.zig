//! Loader class for JSON scenes
const std = @import("std");

const csscolorparser = @import("csscolorparser");

const Color = @import("color.zig").Color;
const Ft = @import("types.zig").Ft;
const LightSource = @import("LightSource.zig");
const Material = @import("Material.zig");
const Object = @import("object.zig").Object;
const CsgType = @import("object/Csg.zig").Type;
const Primitive = @import("object/Primitive.zig");
const Renderable = @import("Renderable.zig");
const Scene = @import("Scene.zig");

const zlm = @import("zlm").as(Ft);

/// Loads a scene from a JSON file at a certain path
pub fn loadSceneFromPath(alloc: std.mem.Allocator, io: std.Io, path: []const u8) !Scene {
    const cwd = std.Io.Dir.cwd();
    var file = try cwd.openFile(io, path, .{ .mode = .read_only });
    defer file.close(io);

    var freader = file.reader(io, &.{});
    const reader = &freader.interface;

    // Read all file into a slice
    const data = try reader.allocRemaining(alloc, .unlimited);
    defer alloc.free(data);

    return loadSceneFromString(alloc, data);
}

/// Loads a scene from a JSON string
pub fn loadSceneFromString(alloc: std.mem.Allocator, json_str: []const u8) !Scene {
    // TODO: better error management from unexpected/absent json values: avoid .?, check union values
    const json = try std.json.parseFromSlice(std.json.Value, alloc, json_str, .{});
    defer json.deinit();
    const json_obj = &json.value.object;

    // Arena for the scene
    var arena: std.heap.ArenaAllocator = .init(alloc);
    const arena_alloc = arena.allocator();
    errdefer arena.deinit();

    // Material names stringmap
    var mat_names: std.StringHashMap(u8) = .init(arena_alloc);
    defer mat_names.deinit();

    // Load materials
    const materials = json_obj.get("materials") orelse return error.BadSceneJson;
    const mats = try readMaterialSection(arena_alloc, &materials, &mat_names);

    // Parse objects
    const contents = json_obj.get("contents") orelse return error.BadSceneJson;
    const objs = try readContentsSection(arena_alloc, &contents, &mat_names);

    // Parse camera TODO
    const camera = json_obj.get("camera").?;
    _ = camera;

    // Parse global light
    const global_light = try readGlobalLightSection(json_obj);

    // Parse lights
    const lights = try readLightsSection(arena_alloc, json_obj);

    return .{
        .arena = arena,
        .materials = mats,
        .objects = objs,
        .lights = lights,
        .global_light = global_light,
    };
}

// TODO: add errors on unexpected fields (rather than ignore them)

/// Reads the contents section of the scene JSON
/// Passed allocator must be an arena allocator: unused objects will be allocated but won't be in the slice
fn readContentsSection(alloc: std.mem.Allocator, value: *const std.json.Value, mat_names: *std.StringHashMap(u8)) ![]const Renderable {
    if (value.* != .array)
        return error.BadSceneJson;

    // Temporary storage for renderables
    var objs: std.ArrayList(Renderable) = .empty;
    errdefer objs.deinit(alloc);

    // Iterate on renderable definitions
    for (value.array.items) |ren_entry| {
        // Read renderable
        const new_obj = try readRenderable(alloc, &ren_entry, mat_names);
        if (new_obj.enabled)
            try objs.append(alloc, new_obj);
    }

    const ren_slice = try objs.toOwnedSlice(alloc);
    return ren_slice;
}

/// Reads the materials list section of the scene JSON
fn readMaterialSection(alloc: std.mem.Allocator, value: *const std.json.Value, mat_names: *std.StringHashMap(u8)) ![]const Material {
    if (value.* != .object)
        return error.BadSceneJson;

    // Temporary storage for materials
    var mats: std.ArrayList(Material) = .empty;
    errdefer mats.deinit(alloc);

    // Iterate on material definitions
    var mat_it = value.object.iterator();
    while (mat_it.next()) |mat_entry| {
        // Read material
        const new_mat = try readMaterial(mat_entry.value_ptr);
        // Id for names
        const mat_id = mats.items.len;
        if (mat_id >= 256)
            return error.TooManyMaterials;
        // Add material
        try mats.append(alloc, new_mat);
        errdefer _ = mats.pop();
        // Get name
        try mat_names.put(mat_entry.key_ptr.*, @truncate(mat_id));
        errdefer _ = mat_names.remove(mat_id);
    }

    const mat_slice = try mats.toOwnedSlice(alloc);
    return mat_slice;
}

/// Reads the global light section from the JSON
/// Unlike other sections, the whole scene JSON is passed
/// because global light source is optional
fn readGlobalLightSection(value: *const std.json.ObjectMap) !LightSource {
    const global_light_json = value.get("global_light") orelse return LightSource{};

    // Parse light (note: here the position of the light is irrelevant)
    return try readLightSource(&global_light_json);
}

/// Reads the light list section from the JSON
/// The whole scene JSON is passed as this section is optional
fn readLightsSection(alloc: std.mem.Allocator, value: *const std.json.ObjectMap) ![]LightSource {
    const light_json = value.get("lights") orelse return &[0]LightSource{};
    if (light_json != .array)
        return error.BadSceneJson;

    // Temporary storage for lights
    var lights: std.ArrayList(LightSource) = .empty;
    errdefer lights.deinit(alloc);

    // Iterate on light definitions
    for (light_json.array.items) |light_entry| {
        // Read light
        const new_light = try readLightSource(&light_entry);
        try lights.append(alloc, new_light);
    }

    const light_slice = try lights.toOwnedSlice(alloc);
    return light_slice;
}

/// Read renderable object entry from the scene JSON
fn readRenderable(alloc: std.mem.Allocator, value: *const std.json.Value, material_names: *std.StringHashMap(u8)) !Renderable {
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

    // Check enabled
    var enabled = true;
    if (ren_def.get("enabled")) |en| {
        if (en != .bool)
            return error.BadRenderableJson;
        enabled = en.bool;
    }

    return .{
        .material_id = mat_id,
        .object = obj,
        .enabled = enabled,
    };
}

/// Read object tree from the scene JSON (recursive)
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

    if (std.mem.eql(u8, "csg", type_name.string))
        ret = try readCSGObject(alloc, obj_def);

    if (std.mem.eql(u8, "repeat", type_name.string))
        ret = try readRepeatObject(alloc, obj_def);

    if (std.mem.eql(u8, "meld", type_name.string))
        ret = try readMeldObject(alloc, obj_def);

    if (std.mem.eql(u8, "negate", type_name.string))
        ret = try readNegateObject(alloc, obj_def);

    return ret orelse error.BadObjectJson;
}

/// Read material entry from the scene JSON
fn readMaterial(value: *std.json.Value) !Material {
    if (value.* != .object)
        return error.BadMaterialJson;

    var new_mat = Material{};
    const mat_def = &value.object;

    // Get colors
    if (mat_def.get("diffuse")) |dif_entry|
        new_mat.diffuse = try readColor(&dif_entry);
    if (mat_def.get("diffuse2")) |dif_entry|
        new_mat.diffuse2 = try readColor(&dif_entry);

    // Reflectivity
    if (mat_def.get("reflectivity")) |refl_entry|
        new_mat.reflectivity = try readScalar(f32, &refl_entry);
    // Smoothness
    if (mat_def.get("smoothness")) |smooth_entry|
        new_mat.smoothness = try readScalar(f32, &smooth_entry);
    // TODO: more advanced textures

    return new_mat;
}

// TODO: avoid anyerror, define set
/// Read transform object from the JSON scene
fn readTransformObject(alloc: std.mem.Allocator, object: *const std.json.ObjectMap) anyerror!Object {
    std.log.debug("Reading transform object...", .{});

    // Default values
    var rotate: zlm.Vec3 = .zero;
    var scale: zlm.Vec3 = .one;
    var translate: zlm.Vec3 = .zero;

    // Translation
    if (object.get("x")) |x|
        translate.x = try readScalar(Ft, &x);
    if (object.get("y")) |y|
        translate.y = try readScalar(Ft, &y);
    if (object.get("z")) |z|
        translate.z = try readScalar(Ft, &z);

    // Rotation
    if (object.get("roll")) |roll|
        rotate.x = zlm.toRadians(try readScalar(Ft, &roll));
    if (object.get("yaw")) |yaw|
        rotate.y = zlm.toRadians(try readScalar(Ft, &yaw));
    if (object.get("pitch")) |pitch|
        rotate.z = zlm.toRadians(try readScalar(Ft, &pitch));

    // Scale
    if (object.get("scale")) |fullscale| {
        const scale_val = try readScalar(Ft, &fullscale);
        scale.x = scale_val;
        scale.y = scale_val;
        scale.z = scale_val;
    }
    if (object.get("sx")) |x|
        scale.x = try readScalar(Ft, &x);
    if (object.get("sy")) |y|
        scale.y = try readScalar(Ft, &y);
    if (object.get("sz")) |z|
        scale.z = try readScalar(Ft, &z);

    // Get object
    const obj_def = object.get("object") orelse return error.BadTransformJson;
    const obj = try readObject(alloc, &obj_def);

    const obj_copy = try alloc.create(Object);
    errdefer alloc.destroy(obj_copy);
    obj_copy.* = obj;

    return .{ .transform = .init(obj_copy, rotate, scale, translate) };
}

/// Read primitive object from the JSON scene
fn readPrimitiveObject(_: std.mem.Allocator, object: *const std.json.ObjectMap) anyerror!Object {
    std.log.debug("Reading primitive object...", .{});
    // Get type
    const type_name = object.get("primitive") orelse return error.BadPrimitiveJson;
    if (type_name != .string)
        return error.BadPrimitiveJson;

    // Read depending on type
    const primitive = Primitive.all.get(type_name.string) orelse return error.UnknownPrimitiveName;
    return .{ .primitive = primitive };
}

/// Read CSG object from the JSON scene
fn readCSGObject(alloc: std.mem.Allocator, object: *const std.json.ObjectMap) anyerror!Object {
    std.log.debug("Reading CSG object...", .{});
    // Get type
    const type_name = object.get("csg") orelse return error.BadCsgJson;
    if (type_name != .string)
        return error.BadCsgJson;

    // Get CSG type
    var csg_type: ?CsgType = null;

    if (std.ascii.eqlIgnoreCase("union", type_name.string))
        csg_type = .unionCsg;
    if (std.ascii.eqlIgnoreCase("intersection", type_name.string))
        csg_type = .intersectionCsg;
    if (std.ascii.eqlIgnoreCase("difference", type_name.string))
        csg_type = .differenceCsg;

    if (csg_type == null)
        return error.BadCsgJson;

    // Get objects
    const obj_def1 = object.get("object1") orelse return error.BadCsgJson;
    const obj1 = try readObject(alloc, &obj_def1);

    const obj1_copy = try alloc.create(Object);
    errdefer alloc.destroy(obj1_copy);
    obj1_copy.* = obj1;

    const obj_def2 = object.get("object2") orelse return error.BadCsgJson;
    const obj2 = try readObject(alloc, &obj_def2);

    const obj2_copy = try alloc.create(Object);
    errdefer alloc.destroy(obj2_copy);
    obj2_copy.* = obj2;

    return .{ .csg = .init(obj1_copy, obj2_copy, csg_type.?) };
}

/// Read repeat object from the JSON scene
fn readRepeatObject(alloc: std.mem.Allocator, object: *const std.json.ObjectMap) anyerror!Object {
    std.log.debug("Reading repeat object...", .{});
    // Get axis
    const axis = object.get("axis") orelse return error.BadRepeatJson;
    if (axis != .string)
        return error.BadRepeatJson;

    var repeat_x: bool = false;
    var repeat_y: bool = false;
    var repeat_z: bool = false;
    for (axis.string) |ax| {
        switch (ax) {
            'x' => repeat_x = true,
            'y' => repeat_y = true,
            'z' => repeat_z = true,
            else => return error.BadRepeatJson,
        }
    }

    // Get period
    const period = object.get("period") orelse return error.BadRepeatJson;
    const period_val = try readScalar(Ft, &period);

    // Get object
    const obj_def = object.get("object") orelse return error.BadTransformJson;
    const obj = try readObject(alloc, &obj_def);

    const obj_copy = try alloc.create(Object);
    errdefer alloc.destroy(obj_copy);
    obj_copy.* = obj;

    return Object{ .repeat = .init(obj_copy, repeat_x, repeat_y, repeat_z, period_val) };
}

/// Read meld object from the JSON scene
fn readMeldObject(alloc: std.mem.Allocator, object: *const std.json.ObjectMap) anyerror!Object {
    std.log.debug("Reading meld object...", .{});

    // Get objects
    const obj_def1 = object.get("object1") orelse return error.BadMeldJson;
    const obj1 = try readObject(alloc, &obj_def1);

    const obj1_copy = try alloc.create(Object);
    errdefer alloc.destroy(obj1_copy);
    obj1_copy.* = obj1;

    const obj_def2 = object.get("object2") orelse return error.BadMeldJson;
    const obj2 = try readObject(alloc, &obj_def2);

    const obj2_copy = try alloc.create(Object);
    errdefer alloc.destroy(obj2_copy);
    obj2_copy.* = obj2;

    // Get meld factor
    const meld_fac = object.get("factor") orelse return error.BadMeldJson;
    const meld_factor = try readScalar(Ft, &meld_fac);

    return .{ .meld = .init(obj1_copy, obj2_copy, meld_factor) };
}

/// Read negate object from the JSON scene
fn readNegateObject(alloc: std.mem.Allocator, object: *const std.json.ObjectMap) anyerror!Object {
    std.log.debug("Reading negate object...", .{});
    // Get object
    const obj_def = object.get("object") orelse return error.BadTransformJson;
    const obj = try readObject(alloc, &obj_def);

    const obj_copy = try alloc.create(Object);
    errdefer alloc.destroy(obj_copy);
    obj_copy.* = obj;

    return Object{ .negate = .init(obj_copy) };
}

/// Read light source from the JSON scene
fn readLightSource(value: *const std.json.Value) !LightSource {
    if (value.* != .object)
        return error.BadLightJson;
    const light_def = &value.object;

    // Default value
    var light = LightSource{};

    // Position
    if (light_def.get("x")) |x|
        light.pos.x = try readScalar(Ft, &x);
    if (light_def.get("y")) |y|
        light.pos.y = try readScalar(Ft, &y);
    if (light_def.get("z")) |z|
        light.pos.z = try readScalar(Ft, &z);

    // Color
    if (light_def.get("color")) |col_entry|
        light.color = try readColor(&col_entry);

    return light;
}

/// Read color value (css syntax) from a JSON string
fn readColor(value: *const std.json.Value) !Color {
    if (value.* != .string)
        return error.BadColorJson;

    const color = csscolorparser.Color(f32).parse(value.string) catch |e| {
        std.log.err("Error {} while parsing color \"{s}\".", .{ e, value.string });
        return error.BadColorJson;
    };

    return .{
        .a = color.alpha,
        .r = color.red,
        .g = color.green,
        .b = color.blue,
    };
}

/// Read scalar value from a JSON float or int
fn readScalar(FloatT: type, value: *const std.json.Value) !FloatT {
    return switch (value.*) {
        .float => |val| @floatCast(val),
        .integer => |val| @floatFromInt(val),
        else => error.BadScalarJson,
    };
}

// Copyright Guillaume Derex 2020-2026 (GPL-3.0)
