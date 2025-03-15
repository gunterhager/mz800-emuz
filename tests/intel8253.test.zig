const std = @import("std");
const expect = std.testing.expect;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const intel8253 = @import("chips").intel8253;

const Bus = u64;
const INTEL8253 = intel8253.Type(.{
    .pins = intel8253.DefaultPins,
    .bus = Bus,
});

test "Int from BCD" {
    try expect(intel8253.intFromBCD(0x0) == 0);
    try expect(intel8253.intFromBCD(0x9999) == 9999);
    try expect(intel8253.intFromBCD(0x1234) == 1234);
}

test "BCD from Int" {
    try expect(intel8253.bcdFromInt(0) == 0x0);
    try expect(intel8253.bcdFromInt(1234) == 0x1234);
    try expect(intel8253.bcdFromInt(9999) == 0x9999);
}
