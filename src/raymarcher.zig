usingnamespace @import("scene.zig");
usingnamespace @import("vector.zig");
usingnamespace @import("object.zig");

const math = @import("std").math;

const color = @import("color.zig");
const Image = @import("image.zig").Image;

pub const settings = struct {
    var hit_distance: f64 = 0.01;
    var max_steps: usize = 10000;
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

    for (scene) |renderable| {
        var dist = renderable.object.distance(pos);

        if (dist < distance) {
            distance = dist;
            obj = &renderable;
        }
    }

    return obj;
}

pub fn march(position: *Vec3, direction: Vec3, distance: f64) void {
    position.* = Vec3.sum(position.*, direction.multiply(distance));
}

pub fn raymarch(scene: Scene, start: Vec3, direction: Vec3) color.Color {
    var i: usize = 0;

    var ray = start;

    return while (i < settings.max_steps) : (i += 1) {
        var distance = distanceToScene(scene, ray);

        if (distance <= settings.hit_distance) {
            break closestObject(scene, ray).?.material.diffuse;
        }

        march(&ray, direction, distance);
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

    var x: usize = 0;
    var y: usize = 0;

    var fwidth = @intToFloat(f64, canvas.width);
    var fheight = @intToFloat(f64, canvas.height);

    while (y < canvas.height) : (y += 1) {
        x = 0;
        while (x < canvas.width) : (x += 1) {
            var rx = (@intToFloat(f64, x) - (fwidth / 2.0)) / fwidth;
            var ry = (@intToFloat(f64, y) - (fheight / 2.0)) / fwidth;

            var direction = Vec3{
                .x = rx,
                .y = ry,
                .z = 1.0,
            };

            var col = raymarch(scene, Vec3.nul, direction).to32BitsColor();

            canvas.data[x + y * canvas.width] = col;
        }
    }
}
