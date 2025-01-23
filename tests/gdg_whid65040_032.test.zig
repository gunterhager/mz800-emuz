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
}
