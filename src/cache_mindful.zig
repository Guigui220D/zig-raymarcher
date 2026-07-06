const std = @import("std");

// TODO: get programatically
pub const l1_setting = 600000; // yes the cache of the 9700X is huge!!

/// thingybob that tries to give you a view of the full slice to work on, but one that fits in the l1 cache
/// so that cpu doesn't need to refetch several times the same memory area
pub fn Iterator(T: type) type {
    return struct {
        pub const elem_per_slice = l1_setting / @sizeOf(T);

        slice: []T,

        pub fn init(slice: []T) @This() {
            //std.debug.print("Elems per slice: {}, total elems: {}, number of slices: {}\n", .{ elem_per_slice, slice.len, slice.len / elem_per_slice });
            return .{ .slice = slice };
        }

        pub fn next(self: *@This()) ?[]T {
            if (self.slice.len == 0)
                return null;
            if (self.slice.len < elem_per_slice) {
                const copy = self.slice;
                self.slice.len = 0;
                return copy;
            } else {
                const copy = self.slice[0..elem_per_slice];
                self.slice = self.slice[elem_per_slice..];
                return copy;
            }
        }
    };
}
