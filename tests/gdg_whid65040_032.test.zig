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

test "colors" {
    const colors = [16]u32{ 0xff000000, 0xff780000, 0xff000078, 0xff780078, 0xff007800, 0xff787800, 0xff007878, 0xff787878, 0xff000000, 0xffdf0000, 0xff0000df, 0xffdf00df, 0xff00df00, 0xffdfdf00, 0xff00dfdf, 0xffdfdfdf };
    for (colors, COLOR.all) |exp_color, color| {
        try expect(exp_color == color);
    }
}

test "reset" {
    const rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    const sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = rgba8_buffer,
    });
    try expect(sut.is_mz700 == false);
    try expect((sut.status & STATUS_MODE.MZ800) == STATUS_MODE.MZ800);
}

test "set MZ-700 mode" {
    const rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = rgba8_buffer,
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

test "single write" {
    const rgba8_buffer = [_]u32{0} ** GDG_WHID65040_032.FRAMEBUFFER_SIZE_PIXEL;
    const cgrom = [_]u8{0} ** 64;
    var sut = GDG_WHID65040_032.init(.{
        .cgrom = &cgrom,
        .rgba8_buffer = rgba8_buffer,
    });

    // Set MZ-800 mode, 320x200, 16 colors
    sut.set_dmd(DMD_MODE.HICOLOR);

    const plane_data = [_]u8{ 0x0f, 0x33, 0x3c, 0x80 };
    for (0..4) |bit| {
        sut.set_wf(@as(u8, 1) << @truncate(bit));
        sut.mem_wr(0x0000, plane_data[bit]);
    }
    try expect(sut.vram1[0] == plane_data[0]);
    try expect(sut.vram1[VRAM_PLANE_OFFSET] == plane_data[1]);
    try expect(sut.vram2[0] == plane_data[2]);
    try expect(sut.vram2[VRAM_PLANE_OFFSET] == plane_data[3]);
}
