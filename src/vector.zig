pub const Vec3 = packed struct {
    pub fn sum(self: Vec3, other: Vec3) Vec3 {
        return Vec3{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn difference(self: Vec3, other: Vec3) Vec3 {
        return Vec3{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
        };
    }

    pub fn length(self: Vec3) f64 {
        return @sqrt(self.x * self.x +
            self.y * self.y +
            self.z * self.z);
    }

    pub fn multiply(self: Vec3, factor: f64) Vec3 {
        return Vec3{
            .x = self.x * factor,
            .y = self.y * factor,
            .z = self.z * factor,
        };
    }

    pub fn distance(self: Vec3, other: Vec3) f64 {
        const diff = self.difference(other);
        return diff.length();
    }

    pub fn normalize(self: Vec3) f64 {
        const len = self.length();
        return Vec3{
            .x = self.x / len,
            .y = self.y / len,
            .z = self.z / len,
        };
    }

    pub const nul = Vec3{ .x = 0, .y = 0, .z = 0 };

    x: f64,
    y: f64,
    z: f64
};
