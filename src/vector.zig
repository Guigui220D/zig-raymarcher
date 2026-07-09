const std = @import("std");

pub const vec_len = std.simd.suggestVectorLength(f64) orelse 8;
pub const Vf64 = @Vector(vec_len, f64);
pub const Vusize = @Vector(vec_len, usize);
pub const Vbool = @Vector(vec_len, bool);
