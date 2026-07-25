/// Vector types
const vec_len = @import("settings.zig").vec_len;

pub const Vf64 = @Vector(vec_len, f64);
pub const Vusize = @Vector(vec_len, usize);
pub const Vbool = @Vector(vec_len, bool);
pub const Vu16 = @Vector(vec_len, u16);
pub const Vu8 = @Vector(vec_len, u8);
