const std = @import("std");
const intel8253 = @import("chips").intel8253;
const Bus = u128;
const INTEL8253 = intel8253.Type(.{
    .pins = intel8253.DefaultPins,
    .bus = Bus,
});

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn generateClockPulse(ctc: *INTEL8253, bus: Bus, clock: Bus) Bus {
    var new_bus = bus | clock;
    new_bus = switch (clock) {
        INTEL8253.CLK0 => ctc.setCLK0(new_bus),
        INTEL8253.CLK1 => ctc.setCLK1(new_bus),
        INTEL8253.CLK2 => ctc.setCLK2(new_bus),
        else => unreachable,
    };
    new_bus = new_bus & ~clock;
    new_bus = switch (clock) {
        INTEL8253.CLK0 => ctc.setCLK0(new_bus),
        INTEL8253.CLK1 => ctc.setCLK1(new_bus),
        INTEL8253.CLK2 => ctc.setCLK2(new_bus),
        else => unreachable,
    };
    return new_bus;
}

fn setGate(ctc: *INTEL8253, bus: Bus, gate: Bus, high: bool) Bus {
    var new_bus = if (high) bus | gate else bus & ~gate;
    new_bus = switch (gate) {
        INTEL8253.GATE0 => ctc.setGATE0(new_bus),
        INTEL8253.GATE1 => ctc.setGATE1(new_bus),
        INTEL8253.GATE2 => ctc.setGATE2(new_bus),
        else => unreachable,
    };
    return new_bus;
}

test "BCD to int conversion" {
    try expectEqual(@as(u16, 9999), intel8253.intFromBCD(0x9999));
    try expectEqual(@as(u16, 1234), intel8253.intFromBCD(0x1234));
}

test "Int to BCD conversion" {
    try expectEqual(@as(u16, 0x9999), intel8253.bcdFromInt(9999));
    try expectEqual(@as(u16, 0x1234), intel8253.bcdFromInt(1234));
}

test "Counter initialization" {
    var ctc = INTEL8253.init();
    var bus: Bus = 0;

    // Write control word for counter 0
    bus = INTEL8253.setData(bus, INTEL8253.CTRL.SC.COUNTER0 | INTEL8253.CTRL.RW.LSB_MSB | INTEL8253.CTRL.MODE.MODE0);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.CTRL);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    try expectEqual(INTEL8253.MODE.MODE0, ctc.counter[0].mode);
    try expectEqual(INTEL8253.READ_LOAD_FORMAT.LSB_MSB, ctc.counter[0].read_load_format);
    try expectEqual(false, ctc.counter[0].bcd);
    try expectEqual(false, ctc.counter[0].latch_operation);
    try expectEqual(false, ctc.counter[0].read_load_msb);
    try expectEqual(false, ctc.counter[0].load_done);
    try expectEqual(0, ctc.counter[0].out);
    try expectEqual(0, ctc.counter[0].gate);
}

test "Control word write" {
    var ctc = INTEL8253.init();
    var bus: Bus = 0;

    // Write control word
    const ctrl_word = INTEL8253.CTRL.SC.COUNTER1 | INTEL8253.CTRL.RW.LSB_MSB | INTEL8253.CTRL.MODE.MODE0;
    bus = INTEL8253.setData(bus, ctrl_word);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.CTRL);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    try expectEqual(INTEL8253.MODE.MODE0, ctc.counter[1].mode);
    try expectEqual(INTEL8253.READ_LOAD_FORMAT.LSB_MSB, ctc.counter[1].read_load_format);
}

test "Counter value write and read" {
    var ctc = INTEL8253.init();
    var bus: Bus = 0;

    // Set up counter 0 in mode 0
    bus = INTEL8253.setData(bus, INTEL8253.CTRL.SC.COUNTER0 | INTEL8253.CTRL.RW.LSB_MSB | INTEL8253.CTRL.MODE.MODE0);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.CTRL);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Write value 0x1234 to counter 0
    bus = INTEL8253.setData(bus, 0x34); // LSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    bus = INTEL8253.setData(bus, 0x12); // MSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Generate two CLK0 pulses to load the counter
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);

    // Read back the value
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 0x34), INTEL8253.getData(bus)); // LSB

    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 0x12), INTEL8253.getData(bus)); // MSB
}

test "Mode 0 operation" {
    var ctc = INTEL8253.init();
    var bus: Bus = 0;

    // Configure counter 0 for mode 0
    bus = INTEL8253.setData(bus, INTEL8253.CTRL.SC.COUNTER0 | INTEL8253.CTRL.RW.LSB_MSB | INTEL8253.CTRL.MODE.MODE0);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.CTRL);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Write count value 5
    bus = INTEL8253.setData(bus, 5); // LSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    bus = INTEL8253.setData(bus, 0); // MSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Generate two CLK0 pulses to load the counter
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);

    // Check initial value
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 5), INTEL8253.getData(bus)); // LSB

    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 0), INTEL8253.getData(bus)); // MSB

    bus = setGate(&ctc, bus, INTEL8253.GATE0, true);

    // Run for 5 cycles and check output
    var i: u8 = 0;
    while (i < 5) : (i += 1) {
        bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    }

    // Read final value
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 0xff), INTEL8253.getData(bus)); // LSB

    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 0xff), INTEL8253.getData(bus)); // MSB
    // Check OUT0 is 1
    try expectEqual(INTEL8253.OUT0, bus & INTEL8253.OUT0);
}

test "Mode 1 operation" {
    var ctc = INTEL8253.init();
    var bus: Bus = 0;

    // Configure counter 0 for mode 1
    bus = INTEL8253.setData(bus, INTEL8253.CTRL.SC.COUNTER0 | INTEL8253.CTRL.RW.LSB_MSB | INTEL8253.CTRL.MODE.MODE1);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.CTRL);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Write count value 3
    bus = INTEL8253.setData(bus, 3); // LSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    bus = INTEL8253.setData(bus, 0); // MSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Generate two CLK0 pulses to load the counter
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);

    bus = setGate(&ctc, bus, INTEL8253.GATE0, true);

    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);

    // Check initial value
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 3), INTEL8253.getData(bus)); // LSB

    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 0), INTEL8253.getData(bus)); // MSB

    // Run for 3 cycles and check output
    var i: u8 = 0;
    while (i < 3) : (i += 1) {
        bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    }

    // Read final value
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 0), INTEL8253.getData(bus)); // LSB

    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 0), INTEL8253.getData(bus)); // MSB
}

test "Mode 2 operation" {
    var ctc = INTEL8253.init();
    var bus: Bus = 0;

    // Configure counter 0 for mode 2
    bus = INTEL8253.setData(bus, INTEL8253.CTRL.SC.COUNTER0 | INTEL8253.CTRL.RW.LSB_MSB | INTEL8253.CTRL.MODE.MODE2);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.CTRL);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Write count value 4
    bus = INTEL8253.setData(bus, 4); // LSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    bus = INTEL8253.setData(bus, 0); // MSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Generate two CLK0 pulses to load the counter
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);

    // Check initial value
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 4), INTEL8253.getData(bus)); // LSB

    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 0), INTEL8253.getData(bus)); // MSB

    // Run for 8 cycles (2 complete periods) and check output
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    }

    // Read final value
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 4), INTEL8253.getData(bus)); // LSB

    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 0), INTEL8253.getData(bus)); // MSB
}

test "Mode 3 operation" {
    var ctc = INTEL8253.init();
    var bus: Bus = 0;

    // Configure counter 0 for mode 3
    bus = INTEL8253.setData(bus, INTEL8253.CTRL.SC.COUNTER0 | INTEL8253.CTRL.RW.LSB_MSB | INTEL8253.CTRL.MODE.MODE3);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.CTRL);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Write count value 6
    bus = INTEL8253.setData(bus, 6); // LSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    bus = INTEL8253.setData(bus, 0); // MSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Generate two CLK0 pulses to load the counter
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);

    // Check initial value
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 6), INTEL8253.getData(bus)); // LSB

    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 0), INTEL8253.getData(bus)); // MSB

    // Run for 12 cycles (2 complete periods) and check output
    var i: u8 = 0;
    while (i < 12) : (i += 1) {
        bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    }

    // Read final value
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 6), INTEL8253.getData(bus)); // LSB

    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    try expectEqual(@as(u8, 0), INTEL8253.getData(bus)); // MSB
}
