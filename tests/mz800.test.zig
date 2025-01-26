const std = @import("std");
const expect = std.testing.expect;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const mz800 = @import("system").mz800;
const MZ800 = mz800.Type();
const MEM_CONFIG = MZ800.MEM_CONFIG.MZ800;

const content = struct {
    const rom1: u8 = 0xf1;
    const cgrom: u8 = 0xf2;
    const rom2: u8 = 0xf3;
};

fn mz800Options() MZ800.Options {
    const rom1 = [_]u8{content.rom1} ** MEM_CONFIG.ROM1_SIZE;
    const cgrom = [_]u8{content.cgrom} ** MEM_CONFIG.CGROM_SIZE;
    const rom2 = [_]u8{content.rom2} ** MEM_CONFIG.ROM2_SIZE;
    return MZ800.Options{ .roms = .{
        .rom1 = &rom1,
        .cgrom = &cgrom,
        .rom2 = &rom2,
    } };
}

fn checkMem(sut: MZ800, start: u16, size: u17, even: u8, odd: u8) bool {
    const end = start + size;
    for (start..end) |index| {
        const addr: u16 = @intCast(index);
        const mem_data = sut.mem.rd(addr);
        const expected_data = if ((addr & 1) == 0) even else odd;
        if (expected_data != mem_data) {
            std.debug.print("🚨 checkMem: addr: 0x{x:0>4} 0x{x} != 0x{x}\n", .{ addr, expected_data, mem_data });
            return false;
        }
    }
    return true;
}

fn checkRAM(sut: MZ800, start: u16, size: u17) bool {
    return checkMem(sut, start, size, 0x00, 0xff);
}

fn checkROM(sut: MZ800, start: u16, size: u17, data: u8) bool {
    return checkMem(sut, start, size, data, data);
}

fn checkROM1(sut: MZ800) bool {
    return checkROM(sut, MEM_CONFIG.ROM1_START, MEM_CONFIG.ROM1_SIZE, content.rom1);
}

fn checkCGROM(sut: MZ800) bool {
    return checkROM(sut, MEM_CONFIG.CGROM_START, MEM_CONFIG.CGROM_SIZE, content.cgrom);
}

fn checkROM2(sut: MZ800) bool {
    return checkROM(sut, MEM_CONFIG.ROM2_START, MEM_CONFIG.ROM2_SIZE, content.rom2);
}

test "init" {
    var sut: MZ800 = undefined;
    sut.initInPlace(mz800Options());
    // Check memory layout after boot
    try expect(checkROM1(sut));
    try expect(checkCGROM(sut));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));
}
