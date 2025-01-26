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

test "MZ800 bank switching" {
    var sut: MZ800 = undefined;
    sut.initInPlace(mz800Options());

    // Initial layout (all ROMs and VRAM banked in)
    try expect(checkROM1(sut));
    try expect(checkCGROM(sut));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));
    try expect(sut.vram_banked_in == true);

    const iorq_wr: mz800.Bus = mz800.IORQ | mz800.WR;
    const iorq_rd: mz800.Bus = mz800.IORQ | mz800.RD;
    const WR_MEM = MZ800.IO_ADDR.WR.MEM;
    const RD_MEM = MZ800.IO_ADDR.RD.MEM;

    // WR SW0: ROM1 and CGROM banked out
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW0);
    sut.updateMemoryMap(sut.bus);
    try expect(checkRAM(sut, 0x0000, 0x2000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));

    // WR SW1: ROM2 banked out
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW1);
    sut.updateMemoryMap(sut.bus);
    try expect(checkRAM(sut, 0x0000, 0x2000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkRAM(sut, 0xe000, 0x2000));

    // WR SW2: ROM1 banked in
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW2);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkRAM(sut, 0x1000, 0x1000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkRAM(sut, 0xe000, 0x2000));

    // WR SW3: ROM2 banked in
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW3);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkRAM(sut, 0x1000, 0x1000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));

    // WR SW4: Initial layout banked in
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW4);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkCGROM(sut));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));

    // WR SW0: ROM1 and CGROM banked out (needed for next tests)
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW0);
    sut.updateMemoryMap(sut.bus);
    try expect(checkRAM(sut, 0x0000, 0x2000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));

    // RD SW0: CGROM and VRAM banked in (VRAM not tested here)
    sut.bus = iorq_rd;
    sut.bus = mz800.setAddr(sut.bus, RD_MEM.SW0);
    sut.updateMemoryMap(sut.bus);
    try expect(checkRAM(sut, 0x0000, 0x1000));
    try expect(checkCGROM(sut));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));

    // RD SW1: CGROM and VRAM banked out
    sut.bus = iorq_rd;
    sut.bus = mz800.setAddr(sut.bus, RD_MEM.SW1);
    sut.updateMemoryMap(sut.bus);
    try expect(checkRAM(sut, 0x0000, 0x1000));
    try expect(checkRAM(sut, 0x1000, 0x1000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));
    try expect(sut.vram_banked_in == false);

    // RD SW0: CGROM and VRAM banked in (test only for VRAM)
    sut.bus = iorq_rd;
    sut.bus = mz800.setAddr(sut.bus, RD_MEM.SW0);
    sut.updateMemoryMap(sut.bus);
    try expect(sut.vram_banked_in == true);
}

test "MZ700 bank switching" {
    var sut: MZ800 = undefined;
    sut.initInPlace(mz800Options());
    sut.gdg.is_mz700 = true;

    // Initial layout (all ROMs and VRAM banked in)
    try expect(checkROM1(sut));
    try expect(checkCGROM(sut));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));
    try expect(sut.vram_banked_in == true);

    const iorq_wr: mz800.Bus = mz800.IORQ | mz800.WR;
    const iorq_rd: mz800.Bus = mz800.IORQ | mz800.RD;
    const WR_MEM = MZ800.IO_ADDR.WR.MEM;
    const RD_MEM = MZ800.IO_ADDR.RD.MEM;

    // WR SW0: ROM1 and CGROM banked out
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW0);
    sut.updateMemoryMap(sut.bus);
    try expect(checkRAM(sut, 0x0000, 0x2000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));

    // WR SW1: ROM2 and VRAM banked out
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW1);
    sut.updateMemoryMap(sut.bus);
    try expect(checkRAM(sut, 0x0000, 0x2000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkRAM(sut, 0xe000, 0x2000));
    try expect(sut.vram_banked_in == false);

    // WR SW2: ROM1 banked in
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW2);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkRAM(sut, 0x1000, 0x1000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkRAM(sut, 0xe000, 0x2000));

    // WR SW3: ROM2 and VRAM banked in
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW3);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkRAM(sut, 0x1000, 0x1000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));
    try expect(sut.vram_banked_in == true);

    // WR SW0: ROM1 and CGROM banked out (to test WR SW4)
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW0);
    sut.updateMemoryMap(sut.bus);
    try expect(checkRAM(sut, 0x0000, 0x2000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));

    // WR SW1: ROM2 and VRAM banked out (to test WR SW4)
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW1);
    sut.updateMemoryMap(sut.bus);
    try expect(checkRAM(sut, 0x0000, 0x2000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkRAM(sut, 0xe000, 0x2000));
    try expect(sut.vram_banked_in == false);

    // WR SW4: ROM1, ROM2, VRAM banked in, CGROM banked out
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW4);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkRAM(sut, 0x1000, 0x1000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));
    try expect(sut.vram_banked_in == true);

    // WR SW1: ROM2 and VRAM banked out (to test RD SW0)
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW1);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkRAM(sut, 0x1000, 0x1000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkRAM(sut, 0xe000, 0x2000));
    try expect(sut.vram_banked_in == false);

    // RD SW0: CGROM and VRAM banked in
    sut.bus = iorq_rd;
    sut.bus = mz800.setAddr(sut.bus, RD_MEM.SW0);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkCGROM(sut));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkRAM(sut, 0xe000, 0x2000));
    try expect(sut.vram_banked_in == true);

    // RD SW1: CGROM and VRAM banked out
    sut.bus = iorq_rd;
    sut.bus = mz800.setAddr(sut.bus, RD_MEM.SW1);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkRAM(sut, 0x1000, 0x1000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkRAM(sut, 0xe000, 0x2000));
    try expect(sut.vram_banked_in == false);
}
