# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SHARP MZ-800 emulator written in Zig, built on Andre Weissflog's [chipz](https://github.com/floooh/chipz) emulation infrastructure. The system boots into the ROM monitor; loading **SHARP BASIC 1Z-016** doesn't work yet. MZF and WAV files can be loaded via drag-and-drop.

Requires ROM binaries in `src/system/roms/`: `MZ800_ROM1.bin`, `MZ800_CGROM.bin`, `MZ800_ROM2.bin`.

## Commands

**Build and run** (requires Zig 0.16.0-dev or later):
```sh
zig build run
# optimized build:
zig build --release=fast run
```

**Run all Zig tests:**
```sh
zig build test
```

**Run a single test** (e.g. `mz800`):
```sh
zig build test --test-filter mz800
```

**Build Z80 assembly test programs** (requires [z88dk](https://github.com/z88dk/z88dk)):
```sh
z88dk-z80asm -b TestCharacters.asm
z88dk-appmake +mz --org 0x2000 --audio -b TestCharacters.bin -o TestCharacters.mzf
```

## Architecture

The codebase has four main modules defined in `build.zig`:

- **`chips`** (`src/chips/`) — Custom chip emulations not in chipz: `intel8253` (PIT), `gdg_whid65040_032` (CRT controller), `sn76489an` (PSG).
- **`system`** (`src/system/`) — Full MZ-800 system integration. Entry point is `system.zig`; `mz800.zig` wires all chips together on a shared 128-bit bus. Also includes `cmt.zig` (CMT/tape emulation), `mzf.zig` (MZF file format), `mzascii.zig`, `video.zig` (timing/geometry constants), `frequencies.zig` (clock dividers).
- **`ui`** (`src/ui/`) — ImGui debug windows for chips, built on sokol + cimgui.
- **`main`** (`src/main.zig`) — Sokol app entry point: init/frame/cleanup/input/drag-drop callbacks.

**Bus architecture:** All chips share a single `u128` bus. Each chip has pin assignments defined as compile-time constants in `mz800.zig`. Chip-select lines (PIO, PPI, CTC, GDG, PSG) occupy bus bits 36–40. The `tick()` function in `mz800.zig` dispatches memory and I/O requests each CPU cycle.

**Clock:** The master clock (`CLK0` ~17.7 MHz) drives everything. Different chips tick at divided rates (`frequencies.zig`). The `exec()` function runs `N` master clock ticks per frame.

**CMT (tape):** `cmt.zig` implements CMT emulation. It accepts WAV files (8-bit mono PCM, any sample rate) or synthesizes PCM from MZF files using the MZ-800 "SANE" tape protocol at 4096 Hz. Raw PCM is fed directly to PPI Port C bit 5 (RDATA); the ROM monitor decodes pulse widths. Motor control is via PC3 (M-ON, rising edge activates) with PC4 readback.

**Tests** (`tests/`) are independent Zig test executables, each importing `chips` and `system` modules. Assembly test programs in `tests/asm/` produce `.mzf` files for drag-and-drop loading.

## Conventions

**Debug prints** — always use the 🚨 emoji and fixed-width hex formatting:
```zig
std.debug.print("🚨 Value: 0x{x:0>2}\n", .{value});
std.debug.print("🚨 Mode: {s}\n", .{@tagName(mode)});
```

**Import statements** — do NOT modify import statements unless explicitly requested.
