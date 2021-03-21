usingnamespace @import("scene.zig");
usingnamespace @import("vector.zig");
usingnamespace @import("object.zig");

const math = @import("std").math;

const color = @import("color.zig");
const Image = @import("image.zig").Image;

pub const settings = struct {
    var hit_distance: f64 = 0.02;
    var max_steps: usize = 96;
    var max_reflections: usize = 20;
};

pub fn distanceToScene(scene: Scene, pos: Vec3) f64 {
    var distance: f64 = math.f64_max;

    for (scene) |renderable| {
        var dist = renderable.object.distance(pos);
        distance = math.min(distance, dist);
    }

    return distance;
}

pub fn closestObject(scene: Scene, pos: Vec3) ?*const Renderable {
    var distance: f64 = math.f64_max;
    var obj: ?*const Renderable = null;

    for (scene) |*renderable| {
        var dist = renderable.object.distance(pos);

        if (dist < distance) {
            distance = dist;
            obj = renderable;
        }
    }

    return obj;
}

fn normal(rend: Renderable, pos: Vec3) Vec3 {
    var dist = rend.object.distance(pos);

    return Vec3.normalize(Vec3 {
        .x = rend.object.distance(pos.sum(Vec3{.x = settings.hit_distance / 100, .y = 0, .z = 0})) - dist,
        .y = rend.object.distance(pos.sum(Vec3{.x = 0, .y = settings.hit_distance / 100, .z = 0})) - dist,
        .z = rend.object.distance(pos.sum(Vec3{.x = 0, .y = 0, .z = settings.hit_distance / 100})) - dist
    });
}

fn reflect(incident: Vec3, normale: Vec3) Vec3 {
    return incident.difference(normale.factor(Vec3.dotProduct(incident, normale) * 2.0));
}

fn march(position: *Vec3, direction: Vec3, distance: f64) void {
    position.* = Vec3.sum(position.*, direction.factor(distance));
}

pub fn raymarch(scene: Scene, start: Vec3, direction: Vec3, recursion: usize) color.Color {
    var i: usize = 0;

    var ray = start;

    return while (i < settings.max_steps) : (i += 1) {
        var distance = distanceToScene(scene, ray);

        if (distance <= settings.hit_distance) {
            const obj = closestObject(scene, ray).?;
            const mat = obj.material;

            const norm_vec = normal(obj.*, ray);

            if (mat.reflectivity == 0.0 or recursion == 0)
                break mat.diffuse;

            const reflection = reflect(direction.normalize(), norm_vec);

            march(&ray, reflection, settings.hit_distance * 1.1);
            var refl_color = raymarch(scene, ray, reflection, recursion - 1);

            const diffuse = if (mat.diffuse2) |pattern| blk: {
                const sum = math.floor(ray.x * 3) + math.floor(ray.y * 5) + math.floor(ray.z * 3);
                if (@mod(sum, 2) < 0.1) {
                    break :blk mat.diffuse;
                }
                    break :blk pattern;
            } else
                mat.diffuse;

            break color.Color.mix(refl_color, diffuse, mat.reflectivity * @floatCast(f32, Vec3.dotProduct(norm_vec.normalize(), reflection)));
        }

        march(&ray, direction, distance - (settings.hit_distance / 2));
    } else
        color.Color{
        .r = 0,
        .g = 0,
        .b = 0,
    };
}

pub const renderError = error{canvasWrongFormat};

pub fn render(scene: Scene, canvas: Image) !void {
    if (canvas.width == 0 or canvas.height == 0)
        return renderError.canvasWrongFormat;

    var fwidth = @intToFloat(f64, canvas.width);
    var fheight = @intToFloat(f64, canvas.height);

    var y: usize = 0;
    while (y < canvas.height) : (y += 1) {
        var x: usize = 0;
        while (x < canvas.width) : (x += 1) {
            var rx = (@intToFloat(f64, x) - (fwidth / 2.0)) / fwidth;
            var ry = (@intToFloat(f64, y) - (fheight / 2.0)) / fwidth;

            var direction = Vec3{
                .x = rx,
                .y = ry,
                .z = 1.0,
            };

            var col = raymarch(scene, Vec3.nul, direction.normalize(), settings.max_reflections);

            canvas.data[x + y * canvas.width] = col.to32BitsColor();
        }
    }
}

//Guillaume Derex 2020