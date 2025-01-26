const std = @import("std");
const expect = std.testing.expect;
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
    try expect(sut.is_mz700 == false);
    try expect((sut.status & STATUS_MODE.MZ800) == STATUS_MODE.MZ800);
}

test "set MZ-700 mode" {
    var rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = &rgba8_buffer,
    });

    // Set MZ-800 mode
    sut.set_dmd(0x00);
    try expect(sut.is_mz700 == false);
    try expect((sut.status & STATUS_MODE.MZ800) == STATUS_MODE.MZ800);
    // Set MZ-700 mode
    sut.set_dmd(DMD_MODE.MZ700);
    try expect(sut.is_mz700 == true);
    try expect((sut.status & STATUS_MODE.MZ800) != STATUS_MODE.MZ800);
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
