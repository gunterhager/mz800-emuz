const std = @import("std");
const chipz = @import("chipz");
const sokol = @import("sokol");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"mz-800"});
}
