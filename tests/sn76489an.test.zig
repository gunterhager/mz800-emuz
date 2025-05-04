const std = @import("std");
const expect = std.testing.expect;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const sn76489an = @import("chips").sn76489an;

const Bus = u64;
const PSG = sn76489an.Type(.{
    .pins = sn76489an.DefaultPins,
    .bus = Bus,
});

test "init" {
    const sut = PSG.init();
    try expect(@as(PSG.ChannelType, sut.channel[0].generator) == .tone);
    try expect(@as(PSG.ChannelType, sut.channel[1].generator) == .tone);
    try expect(@as(PSG.ChannelType, sut.channel[2].generator) == .tone);
    try expect(@as(PSG.ChannelType, sut.channel[3].generator) == .noise);
}

test "reset" {
    var sut = PSG.init();
    for (sut.channel[0..3]) |*channel| {
        channel.*.attenuation = .DB0;
        switch (channel.generator) {
            .tone => |*generator| generator.*.divider = 3,
            .noise => |*generator| generator.*.type = .WHITE,
        }
    }

    for (sut.channel[0..3]) |channel| {
        try expect(channel.attenuation == .DB0);
        switch (channel.generator) {
            .tone => |generator| try expect(generator.divider == 3),
            .noise => |generator| try expect(generator.type == .WHITE),
        }
    }

    sut.reset();

    for (sut.channel[0..3]) |channel| {
        try expect(channel.attenuation == .OFF);
        switch (channel.generator) {
            .tone => |generator| try expect(generator.divider == 0),
            .noise => |generator| try expect(generator.type == .PERIODIC),
        }
    }
}
