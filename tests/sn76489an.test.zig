const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const sn76489an = @import("chips").sn76489an;

const Bus = u64;
const PSG = sn76489an.Type(.{
    .pins = sn76489an.DefaultPins,
    .bus = Bus,
});

test "init" {
    const sut = PSG.init();
    try expectEqual(.tone, @as(PSG.ChannelType, sut.channel[0].generator));
    try expectEqual(.tone, @as(PSG.ChannelType, sut.channel[1].generator));
    try expectEqual(.tone, @as(PSG.ChannelType, sut.channel[2].generator));
    try expectEqual(.noise, @as(PSG.ChannelType, sut.channel[3].generator));
}

test "reset" {
    var sut = PSG.init();
    for (sut.channel[0..3]) |*channel| {
        channel.*.attenuation = .DB0;
        switch (channel.generator) {
            .tone => |*generator| generator.*.divider = 3,
            .noise => |*generator| generator.*.feedback = .WHITE,
        }
    }

    for (sut.channel[0..3]) |channel| {
        try expect(channel.attenuation == .DB0);
        switch (channel.generator) {
            .tone => |generator| try expectEqual(3, generator.divider),
            .noise => |generator| try expectEqual(.WHITE, generator.feedback),
        }
    }

    sut.reset();

    for (sut.channel[0..3]) |channel| {
        try expectEqual(channel.attenuation, .OFF);
        switch (channel.generator) {
            .tone => |generator| try expectEqual(0, generator.divider),
            .noise => |generator| try expectEqual(.PERIODIC, generator.feedback),
        }
    }
}

test "attenuation" {
    var bus: Bus = 0;
    var sut = PSG.init();
    bus = bus | PSG.CE | PSG.WE;
    const flags: u8 = PSG.DATA.LATCH | PSG.DATA.ATTENUATION;
    for (0..3) |index| {
        const addr = @as(u8, @truncate(index));
        const attenuation = PSG.ATTENUATION.DB12;
        const value = flags | (addr << 5) | @intFromEnum(attenuation);
        bus = PSG.setData(bus, value);
        _ = sut.tick(bus);
        try expectEqual(attenuation, sut.channel[addr].attenuation);
    }
}

test "tone" {
    var bus: Bus = 0;
    var sut = PSG.init();
    bus = bus | PSG.CE | PSG.WE;
    const flags: u8 = PSG.DATA.LATCH;
    for (0..2) |index| {
        const addr = @as(u8, @truncate(index));
        const divider: u10 = 0b1010101010;
        const divider_low: u4 = @truncate(divider & PSG.DATA.VALUE_LOW);
        const divider_high: u6 = @truncate(divider >> 4);
        const divider_2: u10 = 0b1111111010;
        const divider_high_2: u6 = @truncate(divider_2 >> 4);
        // First we set the low 4 bits of the divider, also specifying the channel
        const value = flags | (addr << 5) | @as(u8, divider_low);
        bus = PSG.setData(bus, value);
        _ = sut.tick(bus);
        try expectEqual(divider_low, sut.channel[addr].generator.tone.divider);
        // Then we set the high 6 bits of the divider, not specifying the channel again
        bus = PSG.setData(bus, divider_high);
        _ = sut.tick(bus);
        try expectEqual(divider, sut.channel[addr].generator.tone.divider);
        // We set the high 6 bits of the divider again, channel stays the same
        bus = PSG.setData(bus, divider_high_2);
        _ = sut.tick(bus);
        try expectEqual(divider_2, sut.channel[addr].generator.tone.divider);
    }
}

test "noise" {
    var bus: Bus = 0;
    var sut = PSG.init();
    bus = bus | PSG.CE | PSG.WE;
    const flags: u8 = PSG.DATA.LATCH;
    const addr: u8 = 3;
    const feedback: PSG.NOISE_FB = .WHITE;
    const divider: PSG.NOISE_DIVIDER = .TYPE2;
    const value = flags | (addr << 5) | @as(u8, @intFromEnum(feedback)) << 2 | @as(u8, @intFromEnum(divider));
    try expectEqual(.PERIODIC, sut.channel[addr].generator.noise.feedback);
    try expectEqual(.TYPE0, sut.channel[addr].generator.noise.divider);
    bus = PSG.setData(bus, value);
    _ = sut.tick(bus);
    try expectEqual(feedback, sut.channel[addr].generator.noise.feedback);
    try expectEqual(divider, sut.channel[addr].generator.noise.divider);
}
