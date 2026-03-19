const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const mz800 = @import("system").mz800;
const MZ800 = mz800.Type();
const MEM_CONFIG = MZ800.MEM_CONFIG.MZ800;
const video_consts = @import("system").video.video;
// GDG STATUS_MODE.HSYNC = bit 5 (low-active: 0 = asserted, 1 = inactive)
const sts_hsync_bit: u8 = 1 << 5;

const content = struct {
    const rom1: u8 = 0xf1;
    const cgrom: u8 = 0xf2;
    const rom2: u8 = 0xf3;
};

fn mz800Options() MZ800.Options {
    const rom1 = [_]u8{content.rom1} ** MEM_CONFIG.ROM1_SIZE;
    const cgrom = [_]u8{content.cgrom} ** MEM_CONFIG.CGROM_SIZE;
    const rom2 = [_]u8{content.rom2} ** MEM_CONFIG.ROM2_SIZE;
    return MZ800.Options{
        .audio = .{
            .sample_rate = 1000,
            .callback = null,
        },
        .roms = .{
            .rom1 = &rom1,
            .cgrom = &cgrom,
            .rom2 = &rom2,
        },
    };
}

fn checkMem(sut: *const MZ800, start: u16, size: u17, even: u8, odd: u8) bool {
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

fn checkRAM(sut: *const MZ800, start: u16, size: u17) bool {
    return checkMem(sut, start, size, 0x00, 0xff);
}

fn checkROM(sut: *const MZ800, start: u16, size: u17, data: u8) bool {
    return checkMem(sut, start, size, data, data);
}

fn checkROM1(sut: *const MZ800) bool {
    return checkROM(sut, MEM_CONFIG.ROM1_START, MEM_CONFIG.ROM1_SIZE, content.rom1);
}

fn checkCGROM(sut: *const MZ800) bool {
    return checkROM(sut, MEM_CONFIG.CGROM_START, MEM_CONFIG.CGROM_SIZE, content.cgrom);
}

fn checkROM2(sut: *const MZ800) bool {
    return checkROM(sut, MEM_CONFIG.ROM2_START, MEM_CONFIG.ROM2_SIZE, content.rom2);
}

test "init" {
    var sut: MZ800 = undefined;
    sut.initInPlace(mz800Options());
    // Check memory layout after boot
    try expect(checkROM1(&sut));
    try expect(checkCGROM(&sut));
    try expect(checkRAM(&sut, 0x2000, 0xc000));
    try expect(checkROM2(&sut));
}

test "soft reset sets vram_banked_in false" {
    const sut = try std.testing.allocator.create(MZ800);
    defer std.testing.allocator.destroy(sut);
    sut.initInPlace(mz800Options());

    // After hard reset (initInPlace calls reset(false)), VRAM is banked in.
    try expectEqual(sut.vram_banked_in, true);

    // After soft reset, all memory is flat RAM, VRAM must NOT be intercepted.
    sut.reset(true);
    try expectEqual(sut.vram_banked_in, false);

    // After hard reset again, VRAM is banked back in.
    sut.reset(false);
    try expectEqual(sut.vram_banked_in, true);
}

test "soft reset preserves RAM, hard reset fills RAM" {
    const sut = try std.testing.allocator.create(MZ800);
    defer std.testing.allocator.destroy(sut);
    sut.initInPlace(mz800Options());

    const test_addr: u16 = 0x4000;
    sut.ram[test_addr] = 0x42;

    // Soft reset: RAM must be preserved.
    sut.reset(true);
    try expectEqual(sut.ram[test_addr], @as(u8, 0x42));

    // Hard reset: RAM is filled with 0x00/0xFF alternating (even addr = 0x00).
    sut.reset(false);
    try expectEqual(sut.ram[test_addr], @as(u8, 0x00));
}

test "MZ800 bank switching" {
    const sut = try std.testing.allocator.create(MZ800);
    defer std.testing.allocator.destroy(sut);
    sut.initInPlace(mz800Options());
    // GDG resets to MZ-700 mode (hardware default). In a running system the ROM reads the
    // DIP switch via status bit 1 and programs DMD to MZ-800. Simulate that here.
    sut.gdg.set_dmd(0);

    // Initial layout (all ROMs and VRAM banked in)
    try expect(checkROM1(sut));
    try expect(checkCGROM(sut));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));
    try expectEqual(sut.vram_banked_in, true);

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

    // RD SW1: CGROM banked out (RAM at $1000 restored). VRAM is unaffected:
    // reading $E1 only controls the $1000–$1FFF window, not $D000–$DBFF VRAM.
    sut.bus = iorq_rd;
    sut.bus = mz800.setAddr(sut.bus, RD_MEM.SW1);
    sut.updateMemoryMap(sut.bus);
    try expect(checkRAM(sut, 0x0000, 0x1000));
    try expect(checkRAM(sut, 0x1000, 0x1000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));
    // vram_banked_in must remain true: the ROM continues to write to VRAM after
    // this point (boot menu, command prompt) without an explicit SW0/SW4 re-enable.
    try expectEqual(sut.vram_banked_in, true);

    // RD SW0: CGROM and VRAM banked in (test only for VRAM)
    sut.bus = iorq_rd;
    sut.bus = mz800.setAddr(sut.bus, RD_MEM.SW0);
    sut.updateMemoryMap(sut.bus);
    try expectEqual(sut.vram_banked_in, true);
}

test "MZ700 bank switching" {
    const sut = try std.testing.allocator.create(MZ800);
    defer std.testing.allocator.destroy(sut);
    sut.initInPlace(mz800Options());
    sut.gdg.is_mz700 = true;

    // Initial layout (all ROMs and VRAM banked in)
    try expect(checkROM1(sut));
    try expect(checkCGROM(sut));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));
    try expectEqual(sut.vram_banked_in, true);

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
    try expectEqual(sut.vram_banked_in, false);

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
    try expectEqual(sut.vram_banked_in, true);

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
    try expectEqual(sut.vram_banked_in, false);

    // WR SW4: ROM1, ROM2, VRAM banked in, CGROM banked out
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW4);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkRAM(sut, 0x1000, 0x1000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkROM2(sut));
    try expectEqual(sut.vram_banked_in, true);

    // WR SW1: ROM2 and VRAM banked out (to test RD SW0)
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW1);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkRAM(sut, 0x1000, 0x1000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkRAM(sut, 0xe000, 0x2000));
    try expectEqual(sut.vram_banked_in, false);

    // RD SW0: CGROM and VRAM banked in
    sut.bus = iorq_rd;
    sut.bus = mz800.setAddr(sut.bus, RD_MEM.SW0);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkCGROM(sut));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkRAM(sut, 0xe000, 0x2000));
    try expectEqual(sut.vram_banked_in, true);

    // RD SW1: CGROM banked out (RAM at $1000 restored). VRAM is unaffected:
    // reading $E1 only controls the $1000–$1FFF window, not $D000–$DBFF VRAM.
    sut.bus = iorq_rd;
    sut.bus = mz800.setAddr(sut.bus, RD_MEM.SW1);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkRAM(sut, 0x1000, 0x1000));
    try expect(checkRAM(sut, 0x2000, 0xc000));
    try expect(checkRAM(sut, 0xe000, 0x2000));
    // vram_banked_in must remain true: the ROM continues to write to VRAM after
    // this point (boot menu, command prompt) without an explicit SW0/SW4 re-enable.
    try expectEqual(sut.vram_banked_in, true);
}

test "PROHIBIT hides all ROMs, RAM is accessible everywhere" {
    const sut = try std.testing.allocator.create(MZ800);
    defer std.testing.allocator.destroy(sut);
    sut.initInPlace(mz800Options());
    sut.gdg.set_dmd(0); // MZ-800 mode

    // Initial state: ROM1, CGROM, ROM2 all mapped.
    try expect(checkROM1(sut));
    try expect(checkCGROM(sut));
    try expect(checkROM2(sut));
    try expectEqual(sut.rom1_mapped, true);
    try expectEqual(sut.cgrom_mapped, true);
    try expectEqual(sut.rom2_mapped, true);
    try expectEqual(sut.prohibit_active, false);

    const iorq_wr: mz800.Bus = mz800.IORQ | mz800.WR;
    const WR_MEM = MZ800.IO_ADDR.WR.MEM;

    // PROHIBIT (0xE5): all ROMs must be hidden, RAM accessible everywhere.
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.PROHIBIT);
    sut.updateMemoryMap(sut.bus);
    try expectEqual(sut.prohibit_active, true);
    try expectEqual(sut.rom1_mapped, false);
    try expectEqual(sut.cgrom_mapped, false);
    try expectEqual(sut.rom2_mapped, false);
    try expect(checkRAM(sut, 0x0000, 0x2000)); // ROM1+CGROM area now RAM
    try expect(checkRAM(sut, 0xe000, 0x2000)); // ROM2 area now RAM
}

test "RETURN after PROHIBIT restores previous ROM mapping" {
    const sut = try std.testing.allocator.create(MZ800);
    defer std.testing.allocator.destroy(sut);
    sut.initInPlace(mz800Options());
    sut.gdg.set_dmd(0); // MZ-800 mode

    const iorq_wr: mz800.Bus = mz800.IORQ | mz800.WR;
    const WR_MEM = MZ800.IO_ADDR.WR.MEM;

    // Issue PROHIBIT from the standard SW4 layout (ROM1+CGROM+ROM2 all mapped).
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.PROHIBIT);
    sut.updateMemoryMap(sut.bus);
    try expectEqual(sut.prohibit_active, true);

    // Write to the ROM areas while they are RAM (simulate monitor writing to high RAM).
    sut.ram[0x0000] = 0xAA;
    sut.ram[0xe000] = 0xBB;
    try expectEqual(sut.mem.rd(0x0000), @as(u8, 0xAA));
    try expectEqual(sut.mem.rd(0xe000), @as(u8, 0xBB));

    // RETURN (0xE6): ROMs must be restored; the ROM content must be visible again.
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.RETURN);
    sut.updateMemoryMap(sut.bus);
    try expectEqual(sut.prohibit_active, false);
    try expectEqual(sut.rom1_mapped, true);
    try expectEqual(sut.cgrom_mapped, true);
    try expectEqual(sut.rom2_mapped, true);
    try expect(checkROM1(sut));
    try expect(checkCGROM(sut));
    try expect(checkROM2(sut));
}

test "PROHIBIT saves partial ROM state; RETURN restores only what was mapped" {
    const sut = try std.testing.allocator.create(MZ800);
    defer std.testing.allocator.destroy(sut);
    sut.initInPlace(mz800Options());
    sut.gdg.set_dmd(0); // MZ-800 mode

    const iorq_wr: mz800.Bus = mz800.IORQ | mz800.WR;
    const WR_MEM = MZ800.IO_ADDR.WR.MEM;

    // Bank out ROM1+CGROM with SW0, leaving only ROM2.
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.SW0);
    sut.updateMemoryMap(sut.bus);
    try expectEqual(sut.rom1_mapped, false);
    try expectEqual(sut.cgrom_mapped, false);
    try expectEqual(sut.rom2_mapped, true);

    // PROHIBIT: hides ROM2 too.
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.PROHIBIT);
    sut.updateMemoryMap(sut.bus);
    try expectEqual(sut.prohibit_active, true);
    try expect(checkRAM(sut, 0x0000, 0x2000));
    try expect(checkRAM(sut, 0xe000, 0x2000));

    // RETURN: only ROM2 should be restored (ROM1+CGROM were not mapped before PROHIBIT).
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.RETURN);
    sut.updateMemoryMap(sut.bus);
    try expectEqual(sut.prohibit_active, false);
    try expectEqual(sut.rom1_mapped, false);
    try expectEqual(sut.cgrom_mapped, false);
    try expectEqual(sut.rom2_mapped, true);
    try expect(checkRAM(sut, 0x0000, 0x2000)); // ROM1+CGROM still RAM
    try expect(checkROM2(sut));                 // ROM2 restored
}

test "RETURN without prior PROHIBIT is a no-op" {
    const sut = try std.testing.allocator.create(MZ800);
    defer std.testing.allocator.destroy(sut);
    sut.initInPlace(mz800Options());
    sut.gdg.set_dmd(0); // MZ-800 mode

    const iorq_wr: mz800.Bus = mz800.IORQ | mz800.WR;
    const WR_MEM = MZ800.IO_ADDR.WR.MEM;

    // RETURN without PROHIBIT: memory layout must remain unchanged.
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.RETURN);
    sut.updateMemoryMap(sut.bus);
    try expect(checkROM1(sut));
    try expect(checkCGROM(sut));
    try expect(checkROM2(sut));
}

test "hard reset clears prohibit_active" {
    const sut = try std.testing.allocator.create(MZ800);
    defer std.testing.allocator.destroy(sut);
    sut.initInPlace(mz800Options());
    sut.gdg.set_dmd(0); // MZ-800 mode

    const iorq_wr: mz800.Bus = mz800.IORQ | mz800.WR;
    const WR_MEM = MZ800.IO_ADDR.WR.MEM;

    // Issue PROHIBIT, then hard reset.
    sut.bus = iorq_wr;
    sut.bus = mz800.setAddr(sut.bus, WR_MEM.PROHIBIT);
    sut.updateMemoryMap(sut.bus);
    try expectEqual(sut.prohibit_active, true);

    sut.reset(false);
    try expectEqual(sut.prohibit_active, false);
    try expectEqual(sut.rom1_mapped, true);
    try expectEqual(sut.cgrom_mapped, true);
    try expectEqual(sut.rom2_mapped, true);
    try expect(checkROM1(sut));
    try expect(checkCGROM(sut));
    try expect(checkROM2(sut));
}

test "sts_Hsync asserts at h_tick=950" {
    const sut = try std.testing.allocator.create(MZ800);
    defer std.testing.allocator.destroy(sut);
    sut.initInPlace(mz800Options());

    // Place beam one tick before the assert trigger and ensure HSYNC is currently inactive.
    sut.video.h_ticks = video_consts.screen.horizontal.sts_hsync_h_start - 1;
    sut.gdg.status |= sts_hsync_bit;

    // Advance 17 master ticks (1 µs), passing h_tick=950.
    _ = sut.exec(1);

    // HSYNC must be active (low-active: bit clear = asserted).
    try expectEqual(@as(u8, 0), sut.gdg.status & sts_hsync_bit);
}

test "sts_Hsync deasserts at h_tick=1078" {
    const sut = try std.testing.allocator.create(MZ800);
    defer std.testing.allocator.destroy(sut);
    sut.initInPlace(mz800Options());

    // Place beam one tick before the deassert trigger and ensure HSYNC is currently active.
    sut.video.h_ticks = video_consts.screen.horizontal.sts_hsync_h_end - 1;
    sut.gdg.status &= ~sts_hsync_bit;

    // Advance 17 master ticks (1 µs), passing h_tick=1078.
    _ = sut.exec(1);

    // HSYNC must be inactive (low-active: bit set = deasserted).
    try expect(sut.gdg.status & sts_hsync_bit != 0);
}

test "sts_Hsync asserts during VBLANK" {
    const sut = try std.testing.allocator.create(MZ800);
    defer std.testing.allocator.destroy(sut);
    sut.initInPlace(mz800Options());

    // video.ticks=0 is in the VSYNC region (before video_enable_start ≈ 24994),
    // so videoTickToFrameY() returns null — the beam is in VBLANK.
    // The old code gated sts_Hsync updates inside the visible-area check, so it
    // would have silently skipped the update here.
    sut.video.ticks = 0;
    sut.video.h_ticks = video_consts.screen.horizontal.sts_hsync_h_start - 1;
    sut.gdg.status |= sts_hsync_bit;

    _ = sut.exec(1);

    // HSYNC must assert even on a non-visible (VBLANK) line.
    try expectEqual(@as(u8, 0), sut.gdg.status & sts_hsync_bit);
}
