# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SHARP MZ-800 emulator written in Zig, built on Andre Weissflog's [chipz](https://github.com/floooh/chipz) emulation infrastructure. Work in progress — does not yet fully boot into the monitor, but test programs can run. MZF files can be loaded via drag-and-drop.

Requires ROM binaries in `src/system/roms/`: `MZ800_ROM1.bin`, `MZ800_CGROM.bin`, `MZ800_ROM2.bin`.

## Commands

**Build and run:**
```sh
zig build run
```

**Run all Zig tests:**
```sh
zig build test
```

**Build Z80 assembly test programs** (requires [z88dk](https://github.com/z88dk/z88dk)):
```sh
z88dk-z80asm -b TestCharacters.asm
z88dk-appmake +mz --org 0x2000 --audio -b TestCharacters.bin
```

## Architecture

The codebase has four main modules defined in `build.zig`:

- **`chips`** (`src/chips/`) — Custom chip emulations not in chipz: `intel8253` (PIT), `gdg_whid65040_032` (CRT controller), `sn76489an` (PSG).
- **`system`** (`src/system/`) — Full MZ-800 system integration: `mz800.zig` wires all chips together on a shared 128-bit bus. Also includes `mzf.zig` (MZF file format), `mzascii.zig`, `video.zig` (timing/geometry constants), `frequencies.zig` (clock dividers).
- **`ui`** (`src/ui/`) — ImGui debug windows for chips, built on sokol + cimgui.
- **`main`** (`src/main.zig`) — Sokol app entry point: init/frame/cleanup/input callbacks.

**Bus architecture:** All chips share a single `u128` bus. Each chip has pin assignments defined as compile-time constants in `mz800.zig`. Chip-select lines (PIO, PPI, CTC, GDG, PSG) occupy bus bits 36–40. The `tick()` function in `mz800.zig` dispatches memory and I/O requests each CPU cycle.

**Clock:** The master clock (`CLK0` ~17.7 MHz) drives everything. Different chips tick at divided rates (`frequencies.zig`). The `exec()` function runs `N` master clock ticks per frame.

**Tests** (`tests/`) are independent Zig test executables, each importing `chips` and `system` modules. Assembly test programs in `tests/asm/` produce `.mzf` files for drag-and-drop loading.

## Conventions

**Debug prints** — always use the 🚨 emoji and fixed-width hex formatting:
```zig
std.debug.print("🚨 Value: 0x{x:0>2}\n", .{value});
std.debug.print("🚨 Mode: {s}\n", .{@tagName(mode)});
```

**Import statements** — do NOT modify import statements unless explicitly requested.
