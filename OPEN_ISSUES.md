# Open Issues

Known gaps and bugs in the emulator, roughly grouped by area. Issues marked **[blocks boot]** are likely preventing the monitor ROM from starting.

---

## System / Boot

- **Does not boot into the monitor** — the primary goal. Test programs run, but the full ROM boot sequence does not complete. The issues below are likely contributors.

- **CTC GATE pins never driven high** **[blocks boot]** — `mz800.zig` defines `CTC_GATE0/1/2` masks but never sets them on the bus. All three i8253 counters will stay in `wait_gate_high` for Modes 0, 2, and 3 and never count. On real hardware the GATE inputs are likely pulled high. Fix: set the relevant GATE pins unconditionally on the bus, or wire them to the appropriate hardware signals.

- **CTC CLK2 never driven** — `mz800.zig` drives CLK0 (CKMS ≈ 1.1 MHz) and CLK1 (HSYN ≈ 15.6 kHz) but never toggles CLK2. Counter 2 never ticks. Identify the correct clock source for counter 2 and connect it.

- **Keyboard input not wired** — `self.updateKeyboard(micro_seconds)` is commented out in `exec()` (`mz800.zig:387`). Keyboard state is never fed into the PPI, so programs cannot receive key input.

- **Soft vs hard reset not distinguished** — `reset()` has a `TODO` noting it does not differentiate between soft and hard reset (`mz800.zig:340`). Soft reset (CTRL + reset button) should map RAM differently from a cold power-on reset.

---

## Unimplemented Hardware (will `panic` if accessed)

- **FDC — Floppy Disk Controller** (`0xd8–0xdf`) — `mz800.zig:653`
- **QDC — Quick Disk Controller** (`0xf4–0xf7`) — `mz800.zig:667`
- **Serial I/O** (`0xb0–0xb3`) — `mz800.zig:645`
- **i8253 Mode 4 (software triggered strobe)** — `intel8253.zig:373`
- **i8253 Mode 5 (hardware triggered strobe)** — `intel8253.zig:377`
- **Cassette I/O** — the PPI is described as "keyboard and cassette driver" but only keyboard scanning is planned; cassette read/write signals are not implemented.

---

## Timing / Video

- **HSYNC uses approximate position** — the horizontal sync signal is triggered at a fixed pixel offset (`x == 950`) rather than derived from the real HSYNC signal (`mz800.zig:475`). This may cause timing drift for software that relies on precise HSYNC timing.

- **MZ-700 memory-mapped I/O at `0xe008` unclear** — the semantics of writes to this address are uncertain; currently forwarded to `0xd8` (FDC range) which will panic (`mz800.zig:620`).

---

## Debug UI

- **CPU Debugger window** — menu item exists, no window (`main.zig:321`)
- **Breakpoints window** — menu item exists, no window (`main.zig:324`)
- **VRAM viewer window** — menu item exists, no window (`main.zig:328`)
