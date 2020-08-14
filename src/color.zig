const clamp = @import("std").math.clamp;

pub const Color = packed struct {
    pub fn to32BitsColor(self: Color) Color32 {
        return Color32{
            .r = @floatToInt(u8, clamp(self.r, 0.0, 1.0) * 255.0),
            .g = @floatToInt(u8, clamp(self.g, 0.0, 1.0) * 255.0),
            .b = @floatToInt(u8, clamp(self.b, 0.0, 1.0) * 255.0),
            .a = 0xff
        };
    }

    r: f32,
    g: f32,
    b: f32
};

pub const Color32 = packed struct {
    b: u8, g: u8, r: u8, a: u8
};
