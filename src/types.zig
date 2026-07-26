//! Types used throughout the project
const std = @import("std");

/// Type of float used for geometry
pub const Ft = f32;
// Benchmarks showed that this works best with u16
/// Vector length used for all vectorized operations
pub const vec_len = std.simd.suggestVectorLength(u16) orelse 8;

pub const VFt = @Vector(vec_len, Ft);
pub const Vusize = @Vector(vec_len, usize);
pub const Vbool = @Vector(vec_len, bool);
pub const Vu16 = @Vector(vec_len, u16);
pub const Vu8 = @Vector(vec_len, u8);
