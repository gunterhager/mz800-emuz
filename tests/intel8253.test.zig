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
    try expectEqual(false, ctc.counter[0].write_msb_pending);
    try expectEqual(false, ctc.counter[0].read_msb_pending);
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

test "LSB_MSB write does not load on first byte" {
    var ctc = INTEL8253.init();
    var bus: Bus = 0;

    // Configure counter 0 for mode 0, LSB_MSB
    bus = INTEL8253.setData(bus, INTEL8253.CTRL.SC.COUNTER0 | INTEL8253.CTRL.RW.LSB_MSB | INTEL8253.CTRL.MODE.MODE0);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.CTRL);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Write both bytes of count 0x0010 (16)
    bus = INTEL8253.setData(bus, 0x10); // LSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);
    bus = INTEL8253.setData(bus, 0x00); // MSB
    bus = ctc.tick(bus);

    // Two clock pulses to get the counter running (gate=1 required for mode 0)
    bus = setGate(&ctc, bus, INTEL8253.GATE0, true);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0); // init -> load_done
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0); // load_done -> countdown, loads 16

    // Counter is now counting from 16. Write LSB of new count (0x05) but NOT the MSB yet.
    bus = INTEL8253.setData(bus, 0x05); // LSB only
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // write_msb_pending must be true — MSB not yet written
    try expectEqual(true, ctc.counter[0].write_msb_pending);
    // state should be .load (mode 0 resets OUT on first byte write while counting)
    try expectEqual(INTEL8253.State.load, ctc.counter[0].state);

    // Fire a clock pulse — counter should NOT reload with LSB-only preset (5)
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    // Still waiting for MSB
    try expectEqual(true, ctc.counter[0].write_msb_pending);

    // Now write MSB=0x00 => full count = 5
    bus = INTEL8253.setData(bus, 0x00); // MSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    try expectEqual(false, ctc.counter[0].write_msb_pending);
    try expectEqual(INTEL8253.State.load_done, ctc.counter[0].state);
    try expectEqual(@as(u17, 5), ctc.counter[0].preset_value);
}

test "Mode 3 odd count period and asymmetry" {
    var ctc = INTEL8253.init();
    var bus: Bus = 0;

    // Configure counter 0 for mode 3, count N=5 (odd)
    bus = INTEL8253.setData(bus, INTEL8253.CTRL.SC.COUNTER0 | INTEL8253.CTRL.RW.LSB_MSB | INTEL8253.CTRL.MODE.MODE3);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.CTRL);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    bus = INTEL8253.setData(bus, 5); // LSB
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);
    bus = INTEL8253.setData(bus, 0); // MSB
    bus = ctc.tick(bus);

    // Load: two clocks (init -> load_done -> preset with value=5, dest=floor(5/2)=2)
    bus = setGate(&ctc, bus, INTEL8253.GATE0, true);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);

    // OUT should be high after loading
    try expectEqual(@as(u1, 1), ctc.counter[0].out);

    // Clocks 1, 2: value counts 5->4->3, OUT stays HIGH
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0); // value=4
    try expectEqual(@as(u1, 1), ctc.counter[0].out);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0); // value=3
    try expectEqual(@as(u1, 1), ctc.counter[0].out);

    // Clock 3: value=2 == mode3_half_value(2) == destination -> toggle LOW
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    try expectEqual(@as(u1, 0), ctc.counter[0].out); // HIGH lasted ceil(5/2)=3 clocks ✓

    // Clock 4: value counts 2->1, OUT stays LOW
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    try expectEqual(@as(u1, 0), ctc.counter[0].out);

    // Clock 5: value=0 == destination(0) -> toggle HIGH: one full period done
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    try expectEqual(@as(u1, 1), ctc.counter[0].out); // LOW lasted floor(5/2)=2 clocks ✓

    // Run a second full period (5 clocks) to confirm it repeats correctly
    var i: u8 = 0;
    while (i < 5) : (i += 1) {
        bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    }
    try expectEqual(@as(u1, 1), ctc.counter[0].out);
}

test "Read while LSB_MSB write in progress" {
    var ctc = INTEL8253.init();
    var bus: Bus = 0;

    // Configure counter 0, mode 0, LSB_MSB
    bus = INTEL8253.setData(bus, INTEL8253.CTRL.SC.COUNTER0 | INTEL8253.CTRL.RW.LSB_MSB | INTEL8253.CTRL.MODE.MODE0);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.CTRL);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Load initial count 0x1234
    bus = INTEL8253.setData(bus, 0x34);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);
    bus = INTEL8253.setData(bus, 0x12);
    bus = ctc.tick(bus);

    // Start counting
    bus = setGate(&ctc, bus, INTEL8253.GATE0, true);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);

    // Begin a new 2-byte write: write LSB=0xAB only
    bus = INTEL8253.setData(bus, 0xAB);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);
    try expectEqual(true, ctc.counter[0].write_msb_pending);

    // Latch the current counter value for reading
    bus = INTEL8253.setData(bus, INTEL8253.CTRL.SC.COUNTER0 | INTEL8253.CTRL.RW.LATCH);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.CTRL);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    // Read LSB then MSB — uses read_msb_pending, must not disturb write_msb_pending
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    const read_lsb = INTEL8253.getData(bus);

    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.RD;
    bus = ctc.tick(bus);
    const read_msb = INTEL8253.getData(bus);

    // write_msb_pending must still be set — the read must not have cleared it
    try expectEqual(true, ctc.counter[0].write_msb_pending);
    try expectEqual(false, ctc.counter[0].read_msb_pending);
    // Latched value: loaded 0x1234 on the 2nd clock (no decrement on load tick).
    // The 3rd clock fired while state=.load so no decrement. Value is still 0x1234.
    try expectEqual(@as(u16, 0x1234), @as(u16, read_msb) << 8 | read_lsb);

    // Complete the write with MSB=0x00 => new count = 0x00AB = 171.
    // Clear RD first — tick() checks RD before WR, so leaving it set would cause a read.
    bus = bus & ~INTEL8253.RD;
    bus = INTEL8253.setData(bus, 0x00);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    try expectEqual(false, ctc.counter[0].write_msb_pending);
    try expectEqual(@as(u17, 0xAB), ctc.counter[0].preset_value);
}

test "reset clears counter state" {
    var ctc = INTEL8253.init();
    var bus: Bus = 0;

    // Configure and start counter 0 in mode 2
    bus = INTEL8253.setData(bus, INTEL8253.CTRL.SC.COUNTER0 | INTEL8253.CTRL.RW.LSB_MSB | INTEL8253.CTRL.MODE.MODE2);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.CTRL);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);

    bus = INTEL8253.setData(bus, 10);
    bus = INTEL8253.setABUS(bus, INTEL8253.ABUS_MODE.COUNTER0);
    bus = bus | INTEL8253.CS | INTEL8253.WR;
    bus = ctc.tick(bus);
    bus = INTEL8253.setData(bus, 0);
    bus = ctc.tick(bus);

    bus = setGate(&ctc, bus, INTEL8253.GATE0, true);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);
    bus = generateClockPulse(&ctc, bus, INTEL8253.CLK0);

    // Counter is now running. Reset.
    ctc.reset();

    // All counters should be back to power-on state
    try expectEqual(INTEL8253.State.init_done, ctc.counter[0].state);
    try expectEqual(INTEL8253.State.init_done, ctc.counter[1].state);
    try expectEqual(INTEL8253.State.init_done, ctc.counter[2].state);
    try expectEqual(false, ctc.counter[0].load_done);
    try expectEqual(false, ctc.counter[0].write_msb_pending);
    try expectEqual(false, ctc.counter[0].read_msb_pending);
    try expectEqual(@as(u1, 0), ctc.counter[0].out);
    try expectEqual(@as(u17, 0), ctc.counter[0].value);
}
