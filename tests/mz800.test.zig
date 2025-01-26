const std = @import("std");
const expect = std.testing.expect;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const mz800 = @import("system").mz800;
const MZ800 = mz800.Type();

test "init" {
    var sut: MZ800 = undefined;
    sut.initInPlace();
    try expect(sut.ram[0] == 0x00);
    try expect(sut.ram[1] == 0xff);
}
