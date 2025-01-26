/// Various frequencies used in the MZ-800.
/// All frequencies in Hz.
pub const Frequencies = struct {
    /// Cursor blink
    pub const CURSOR = osc556_frequency(1.5, 47, 10);
    /// Tempo (?)
    pub const TEMPO = osc556_frequency(1.8, 18, 1);
    /// System clock speed (PAL)
    pub const CLK0: comptime_float = 17.734475 * 1e6;
    /// CPU clock (PAL)
    pub const CPU_CLK: comptime_float = CLK0 / 5;
    /// CKMS,  i8253 CH0
    pub const CKMS: comptime_float = CLK0 / 16;
    /// Horizontal sync HSYN (PAL), i8253 CH1
    pub const HSYN: comptime_float = CLK0 / 1136;
    /// Vertical sync VSYN (PAL)
    pub const VSYN: comptime_float = CLK0 / 312;

    /// Calculate oscillation frquency of OSC556 based on two resistors and a capacitor.
    /// r1, r2: kOhm
    /// c: uFarad
    /// result: Hz
    fn osc556_frequency(r1: comptime_float, r2: comptime_float, c: comptime_float) comptime_float {
        return 1.44 / ((kO_to_O(r1) + 2 * kO_to_O(r2)) / uF_to_F(c));
    }

    /// Converts micro Farads into Farads
    fn uF_to_F(c: comptime_float) comptime_float {
        return c * 1e-6;
    }

    /// Converts kilo Ohms to Ohms
    fn kO_to_O(r: comptime_float) comptime_float {
        return r * 1000;
    }
};
