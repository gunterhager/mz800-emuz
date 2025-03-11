pub const clock_dividers = struct {
    pub const CPU_CLK: comptime_int = 5;
    pub const CKMS: comptime_int = 16;
    pub const HSYN: comptime_int = 1136;
    pub const VSYN: comptime_int = 312;
};

/// Various frequencies used in the MZ-800.
/// All frequencies in Hz.
pub const frequencies = struct {
    /// Cursor blink
    pub const CURSOR = osc556Frequency(1.5, 47, 10);
    /// Tempo (?)
    pub const TEMPO = osc556Frequency(1.8, 18, 1);
    /// System clock speed (PAL)
    /// Frequency: 17.734475 MHz
    /// Period: 56.387347243152 nanoseconds
    pub const CLK0: comptime_float = 17.734475 * 1e6;
    /// CPU clock (PAL)
    pub const CPU_CLK: comptime_float = CLK0 / clock_dividers.CPU_CLK;
    /// CKMS,  i8253 CLK0 for counter 0
    /// Frequency: 1.10840469 MHz
    /// Period: 902.19755385553 nanoseconds
    pub const CKMS: comptime_float = CLK0 / clock_dividers.CKMS;
    /// Horizontal sync HSYN (PAL), i8253 CLK1 for counter 1
    pub const HSYN: comptime_float = CLK0 / clock_dividers.HSYN;
    /// Vertical sync VSYN (PAL)
    pub const VSYN: comptime_float = CLK0 / clock_dividers.VSYN;

    /// Calculate oscillation frquency of OSC556 based on two resistors and a capacitor.
    /// r1, r2: kOhm
    /// c: uFarad
    /// result: Hz
    fn osc556Frequency(r1: comptime_float, r2: comptime_float, c: comptime_float) comptime_float {
        return 1.44 / ((kOhmToOhm(r1) + 2 * kOhmToOhm(r2)) / uFaradToFarad(c));
    }

    /// Converts micro Farads into Farads
    fn uFaradToFarad(c: comptime_float) comptime_float {
        return c * 1e-6;
    }

    /// Converts kilo Ohms to Ohms
    fn kOhmToOhm(r: comptime_float) comptime_float {
        return r * 1000;
    }
};
