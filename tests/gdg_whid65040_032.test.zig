const std = @import("std");
const expect = std.testing.expect;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const gdg_whid65040_032 = @import("mz800-emuz").chips.gdg_whid65040_032;

const Bus = u64;
const GDG_WHID65040_032 = gdg_whid65040_032.Type(.{
    .pins = gdg_whid65040_032.DefaultPins,
    .bus = Bus,
});
