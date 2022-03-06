const math = @import("std").math;

pub const Color = packed struct {
    pub fn to32BitsColor(self: Color) Color32 {
        return Color32{
            .r = @floatToInt(u8, math.clamp(self.r, 0.0, 1.0) * 255.0),
            .g = @floatToInt(u8, math.clamp(self.g, 0.0, 1.0) * 255.0),
            .b = @floatToInt(u8, math.clamp(self.b, 0.0, 1.0) * 255.0),
            .a = 0xff,
        };
    }

    pub fn mix(a: Color, b: Color, ratio: f32) Color {
        const r2: f32 = 1.0 - ratio;

        return Color{
            .r = a.r * ratio + b.r * r2,
            .g = a.g * ratio + b.g * r2,
            .b = a.b * ratio + b.b * r2 
        };
    }

    pub fn adjust(self: *Color, min: f32, range: f32) void {
        self.r -= min;
        self.g -= min;
        self.b -= min;
        
        self.r /= range;
        self.g /= range;
        self.b /= range;
    }

    r: f32,
    g: f32,
    b: f32
};

pub const Color32 = packed struct {
    b: u8, g: u8, r: u8, a: u8
};

//Guillaume Derex 2020-2022
