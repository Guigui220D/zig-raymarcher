/// Vector types
const settings = @import("settings.zig");
const vec_len = settings.vec_len;

pub const VFt = @Vector(vec_len, settings.Ft);
pub const Vusize = @Vector(vec_len, usize);
pub const Vbool = @Vector(vec_len, bool);
pub const Vu16 = @Vector(vec_len, u16);
pub const Vu8 = @Vector(vec_len, u8);
