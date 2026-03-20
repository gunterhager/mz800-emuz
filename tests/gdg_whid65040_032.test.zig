const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const gdg_whid65040_032 = @import("chips").gdg_whid65040_032;

const Bus = u64;
const GDG_WHID65040_032 = gdg_whid65040_032.Type(.{
    .pins = gdg_whid65040_032.DefaultPins,
    .bus = Bus,
});
const COLOR = GDG_WHID65040_032.COLOR;
const DMD_MODE = GDG_WHID65040_032.DMD_MODE;
const STATUS_MODE = GDG_WHID65040_032.STATUS_MODE;
const VRAM_PLANE_OFFSET = GDG_WHID65040_032.VRAM_PLANE_OFFSET;
const WF_MODE = GDG_WHID65040_032.WF_MODE;
const RF_MODE = GDG_WHID65040_032.RF_MODE;

test "colors" {
    const colors = [16]u32{ 0xff000000, 0xff780000, 0xff000078, 0xff780078, 0xff007800, 0xff787800, 0xff007878, 0xff787878, 0xff000000, 0xffdf0000, 0xff0000df, 0xffdf00df, 0xff00df00, 0xffdfdf00, 0xff00dfdf, 0xffdfdfdf };
    for (colors, COLOR.all) |exp_color, color| {
        try expect(exp_color == color);
    }
}

test "reset" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    const sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });
    // Hardware power-on default is MZ-700 compat mode.
    // The ROM reads the DIP switch via status bit 1 and programs DMD to enter MZ-800 if needed.
    try expect(sut.is_mz700 == true);
    // DIP switch defaults to MZ-800 (dip_is_mz700 == false).
    try expect(sut.dip_is_mz700 == false);
}

test "softReset preserves VRAM, hard reset clears VRAM" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });

    sut.vram1[0] = 0xAB;
    sut.vram2[0] = 0xCD;

    // Soft reset must preserve VRAM content.
    sut.softReset();
    try expectEqual(sut.vram1[0], @as(u8, 0xAB));
    try expectEqual(sut.vram2[0], @as(u8, 0xCD));

    // Hard reset must zero VRAM.
    sut.reset();
    try expectEqual(sut.vram1[0], @as(u8, 0x00));
    try expectEqual(sut.vram2[0], @as(u8, 0x00));
}

test "softReset resets control registers" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });

    sut.set_dmd(0x00); // MZ-800 mode
    sut.wf = 0xFF;
    sut.rf = 0xFF;
    sut.bcol = 0x07;

    sut.softReset();

    try expectEqual(sut.wf, @as(u8, 0));
    try expectEqual(sut.rf, @as(u8, 0));
    try expectEqual(sut.bcol, @as(u8, 0));
    // DMD reset to MZ-700 compat (hardware default after RST).
    try expect(sut.is_mz700 == true);
}

test "set MZ-700 mode" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });

    // set_dmd() controls the runtime is_mz700 flag.
    // Status register bit 1 reflects dip_is_mz700 (the DIP switch), not the DMD value.
    sut.set_dmd(0x00);
    try expect(sut.is_mz700 == false);
    sut.set_dmd(DMD_MODE.MZ700);
    try expect(sut.is_mz700 == true);

    // DIP switch (dip_is_mz700) controls status bit 1 independently of set_dmd().
    sut.dip_is_mz700 = false; // MZ-800 DIP position
    try expect(sut.dip_is_mz700 == false);
    sut.dip_is_mz700 = true; // MZ-700 DIP position
    try expect(sut.dip_is_mz700 == true);
}

test "mem wr single write" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });

    // Set MZ-800 mode, 320x200, 16 colors
    sut.set_dmd(DMD_MODE.HICOLOR);

    const plane_data = [_]u8{ 0x0f, 0x33, 0x3c, 0x80 };
    for (0..4) |bit| {
        const planes = @as(u8, 1) << @truncate(bit);
        const wmd = @as(u8, WF_MODE.WMD.SINGLE) << 5;
        sut.set_wf(wmd | planes);
        sut.mem_wr(0x0000, plane_data[bit]);
    }
    // Plane I
    try expect(sut.vram1[0] == plane_data[0]);
    // Plane II
    try expect(sut.vram1[VRAM_PLANE_OFFSET] == plane_data[1]);
    // Plane III
    try expect(sut.vram2[0] == plane_data[2]);
    // Plane IV
    try expect(sut.vram2[VRAM_PLANE_OFFSET] == plane_data[3]);
}

test "mem wr replace" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });

    // Set MZ-800 mode, 320x200, 16 colors
    sut.set_dmd(DMD_MODE.HICOLOR);

    // Pixels: black / black / yellow / yellow / magenta / magenta / cyan /cyan
    const plane_data = [_]u8{ 0x0f, 0x33, 0x3c, 0x00 };

    // Plane I
    sut.vram1[0] = plane_data[0];
    // Plane II
    sut.vram1[VRAM_PLANE_OFFSET] = plane_data[1];
    // Plane III
    sut.vram2[0] = plane_data[2];
    // Plane IV
    sut.vram2[VRAM_PLANE_OFFSET] = plane_data[3];

    // Replace with: black / light yellow / black / light yellow / black / light yellow / black / light yellow
    const planes = WF_MODE.PLANE_IV | WF_MODE.PLANE_III | WF_MODE.PLANE_II;
    const wmd = @as(u8, WF_MODE.WMD.REPLACE0) << 5;
    sut.set_wf(wmd | planes);
    sut.mem_wr(0x0000, 0x55);

    // Plane I
    try expect(sut.vram1[0] == 0x00);
    // Plane II
    try expect(sut.vram1[VRAM_PLANE_OFFSET] == 0x55);
    // Plane III
    try expect(sut.vram2[0] == 0x55);
    // Plane IV
    try expect(sut.vram2[VRAM_PLANE_OFFSET] == 0x55);
}

test "mem wr PSET" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });

    // Set MZ-800 mode, 320x200, 16 colors
    sut.set_dmd(DMD_MODE.HICOLOR);

    // Pixels: black / black / yellow / yellow / magenta / magenta / cyan /cyan
    const plane_data = [_]u8{ 0x0f, 0x33, 0x3c, 0x00 };

    // Plane I
    sut.vram1[0] = plane_data[0];
    // Plane II
    sut.vram1[VRAM_PLANE_OFFSET] = plane_data[1];
    // Plane III
    sut.vram2[0] = plane_data[2];
    // Plane IV
    sut.vram2[VRAM_PLANE_OFFSET] = plane_data[3];

    // Replace with: black / light yellow / black / light yellow / black / light yellow / black / light yellow
    const planes = WF_MODE.PLANE_IV | WF_MODE.PLANE_III | WF_MODE.PLANE_II;
    const wmd = @as(u8, WF_MODE.WMD.PSET0) << 5;
    sut.set_wf(wmd | planes);
    sut.mem_wr(0x0000, 0x55);

    // Plane I
    try expect(sut.vram1[0] == 0x0a);
    // Plane II
    try expect(sut.vram1[VRAM_PLANE_OFFSET] == 0x77);
    // Plane III
    try expect(sut.vram2[0] == 0x7d);
    // Plane IV
    try expect(sut.vram2[VRAM_PLANE_OFFSET] == 0x55);
}

test "palette color write" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });

    // Palette2 | red: 0x20 | 0x02 = 0x22 (bit 5-4 = 0b10 = index 2, bits 3-0 = 0b0010 = red)
    var bus: Bus = GDG_WHID65040_032.IORQ | GDG_WHID65040_032.WR;
    bus = GDG_WHID65040_032.setData(bus, 0x22);
    bus = GDG_WHID65040_032.setABUS(bus, 0xF0);
    _ = sut.tick(bus);

    try expectEqual(sut.plt[2], @as(u4, 0x02));
    try expectEqual(sut.plt_rgba8[2], COLOR.all[2]);
}

test "palette switch write" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });

    // PaletteBlock2 = 0x42 (bit 6 = 1 = palette switch, bits 1-0 = 2 = block select)
    var bus: Bus = GDG_WHID65040_032.IORQ | GDG_WHID65040_032.WR;
    bus = GDG_WHID65040_032.setData(bus, 0x42);
    bus = GDG_WHID65040_032.setABUS(bus, 0xF0);
    _ = sut.tick(bus);

    try expectEqual(sut.plt_sw, @as(u2, 2));
}

test "palette applied in decode_vram_mz800 with non-zero plt_sw" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });

    // 320x200 16-color mode
    sut.set_dmd(DMD_MODE.HICOLOR);

    // Set plt_sw = 1 (PaletteBlock1 = 0x41)
    var bus: Bus = GDG_WHID65040_032.IORQ | GDG_WHID65040_032.WR;
    bus = GDG_WHID65040_032.setABUS(bus, 0xF0);
    bus = GDG_WHID65040_032.setData(bus, 0x41);
    _ = sut.tick(bus);

    // Set plt[1] = green (Palette1 | green = 0x10 | 0x04 = 0x14)
    bus = GDG_WHID65040_032.setData(bus, 0x14);
    _ = sut.tick(bus);

    // Set VRAM: plane I=all-1, plane II=all-0, plane III=all-1, plane IV=all-0
    // → value = 0b0101 = 5 for each pixel bit
    // (5 >> 2) & 0x03 = 1 = plt_sw → palette lookup: plt[5 & 0x03] = plt[1] = green
    sut.vram1[0] = 0xFF; // plane I
    sut.vram1[VRAM_PLANE_OFFSET] = 0x00; // plane II
    sut.vram2[0] = 0xFF; // plane III
    sut.vram2[VRAM_PLANE_OFFSET] = 0x00; // plane IV

    sut.decode_vram_mz800(0, 0);

    // Lores mode writes 2 fb entries per pixel; all 8 pixels map to green
    try expectEqual(sut.rgba8_buffer[0], COLOR.all[4]); // first of the doubled pixel
    try expectEqual(sut.rgba8_buffer[1], COLOR.all[4]); // second of the doubled pixel
}

test "mem rd searching + mem wr PSET" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });

    // Set MZ-800 mode, 320x200, 16 colors
    sut.set_dmd(DMD_MODE.HICOLOR);

    // Pixels: black / black / yellow / yellow / magenta / magenta / cyan /cyan
    const plane_data = [_]u8{ 0x0f, 0x33, 0x3c, 0x00 };

    // Plane I
    sut.vram1[0] = plane_data[0];
    // Plane II
    sut.vram1[VRAM_PLANE_OFFSET] = plane_data[1];
    // Plane III
    sut.vram2[0] = plane_data[2];
    // Plane IV
    sut.vram2[VRAM_PLANE_OFFSET] = plane_data[3];

    // Replace with light yellow
    // Pixels: black / light yellow / yellow / light yellow / magenta / light yellow / cyan / light yellow
    const planes_light_yellow = WF_MODE.PLANE_IV | WF_MODE.PLANE_III | WF_MODE.PLANE_II;
    const wmd = @as(u8, WF_MODE.WMD.PSET0) << 5;
    sut.set_wf(wmd | planes_light_yellow);
    sut.mem_wr(0x0000, 0x55);

    // Plane I
    try expect(sut.vram1[0] == 0x0a);
    // Plane II
    try expect(sut.vram1[VRAM_PLANE_OFFSET] == 0x77);
    // Plane III
    try expect(sut.vram2[0] == 0x7d);
    // Plane IV
    try expect(sut.vram2[VRAM_PLANE_OFFSET] == 0x55);

    // Read: searching for light yellow
    sut.set_rf(RF_MODE.SEARCH | (1 << 3) | (1 << 2) | (1 << 1));
    const data = sut.mem_rd(0x0000);
    try expect(data == 0x55);

    // Write: set all pixels found above to red
    const planes_red = WF_MODE.PLANE_II;
    sut.set_wf(wmd | planes_red);
    sut.mem_wr(0x0000, data);

    // Result: black / red / yellow / red / magenta / red / cyan / red
    // Plane I
    try expect(sut.vram1[0] == 0x0a);
    // Plane II
    try expect(sut.vram1[VRAM_PLANE_OFFSET] == 0x77);
    // Plane III
    try expect(sut.vram2[0] == 0x28);
    // Plane IV
    try expect(sut.vram2[VRAM_PLANE_OFFSET] == 0x00);
}

test "VRAM lores: full 8KB plane (0x0000-0x1FFF) is writable and readable" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });
    sut.set_dmd(0); // MZ-800 lores mode
    // Enable plane I for writes (SINGLE mode) and reads.
    sut.set_wf(WF_MODE.PLANE_I);
    sut.set_rf(RF_MODE.PLANE_I);

    // Addresses in the displayable area must be accessible.
    sut.mem_wr(0x0000, 0xAB);
    try expectEqual(sut.mem_rd(0x0000), @as(u8, 0xAB));

    // Addresses above the last displayable pixel (0x1F3F) but within the
    // physical plane (0x1FFF) must also be accessible. These were previously
    // treated as illegal, causing VRAM test failures on real hardware.
    sut.mem_wr(0x1F40, 0xCD);
    try expectEqual(sut.mem_rd(0x1F40), @as(u8, 0xCD));

    sut.mem_wr(0x1F80, 0xEF);
    try expectEqual(sut.mem_rd(0x1F80), @as(u8, 0xEF));

    sut.mem_wr(0x1FFF, 0x55);
    try expectEqual(sut.mem_rd(0x1FFF), @as(u8, 0x55));
}
