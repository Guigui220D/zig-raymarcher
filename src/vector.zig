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

    pub fn multiply(self: Vec3, other: Vec3) Vec3 {
        return Vec3{
            .x = self.x * other.x,
            .y = self.y * other.y,
            .z = self.z * other.z,
        };
    }

    pub fn divide(self: Vec3, other: Vec3) Vec3 {
        return Vec3{
            .x = self.x / other.x,
            .y = self.y / other.y,
            .z = self.z / other.z,
        };
    }

    pub fn length(self: Vec3) f64 {
        return @sqrt(self.x * self.x +
            self.y * self.y +
            self.z * self.z);
    }

    pub fn factor(self: Vec3, x: f64) Vec3 {
        return Vec3{
            .x = self.x * x,
            .y = self.y * x,
            .z = self.z * x,
        };
    }

    pub fn distance(self: Vec3, other: Vec3) f64 {
        const diff = self.difference(other);
        return diff.length();
    }

    pub fn normalize(self: Vec3) Vec3 {
        const len = self.length();
        return Vec3{
            .x = self.x / len,
            .y = self.y / len,
            .z = self.z / len,
        };
    }

    pub fn dotProduct(self: Vec3, other: Vec3) f64 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub const nul = Vec3{ .x = 0, .y = 0, .z = 0 };
    pub const one = Vec3{ .x = 1, .y = 1, .z = 1 };

    x: f64,
    y: f64,
    z: f64
};

//Guillaume Derex 2020