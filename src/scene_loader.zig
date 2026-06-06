const std = @import("std");

const Material = @import("Material.zig");
const Object = @import("object.zig").Object;
const Renderable = @import("Renderable.zig");
const Scene = @import("Scene.zig");

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

    // TODO: better error management from unexpected/absent json values

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
        var new_mat = Material{};
        const mat_def = mat_entry.value_ptr.object;

        // Get color
        if (mat_def.get("diffuse")) |dif_entry| {
            const r = dif_entry.object.get("r").?.float;
            const g = dif_entry.object.get("g").?.float;
            const b = dif_entry.object.get("b").?.float;
            new_mat.diffuse.r = @floatCast(r);
            new_mat.diffuse.g = @floatCast(g);
            new_mat.diffuse.b = @floatCast(b);
        }
        // Reflectivity
        if (mat_def.get("reflectivity")) |refl_entry| {
            const refl = refl_entry.float;
            new_mat.reflectivity = @floatCast(refl);
        }
        // TODO: diffuse2 or advanced textures

        // Id for names
        const mat_id = mats.items.len;
        // Add material
        try mats.append(arena_alloc, new_mat);
        errdefer _ = mats.pop();
        // Get name
        try mat_names.put(mat_entry.key_ptr.*, mat_id);
        errdefer _ = mat_names.remove(mat_id);
    }

    const contents = json.value.object.get("contents").?;
    _ = contents;

    const camera = json.value.object.get("camera").?;
    _ = camera;

    return .{
        .arena = arena,
        .materials = try mats.toOwnedSlice(arena_alloc),
        .objects = &.{},
        .lights = &.{},
        .global_light = .{},
    };
}

//Guillaume Derex
