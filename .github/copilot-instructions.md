# Copilot Instructions for mz800-emuz

This document provides essential guidance for AI coding agents working on the `mz800-emuz` project, a SHARP MZ-800 emulator written in Zig.

## Project Overview
- **Architecture:**
  - Main emulator logic is in `src/`, with subfolders for hardware chips (`chips/`), system logic (`system/`), and UI (`ui/`).
  - ROM binaries are in `src/system/roms/`.
  - Test programs and Z80 assembly sources are in `tests/asm/`.
- **Emulator Core:**
  - Uses [chipz](https://github.com/floooh/chipz) as the emulation infrastructure.
  - Entry point: `src/main.zig`.

## Developer Workflows
- **Build and Run:**
  - Use Zig 0.15.1 or later.
  - Build and run with:
    ```sh
    zig build run
    ```
- **Testing:**
  - Zig-based tests are in `tests/` (e.g., `tests/mz800.test.zig`).
  - Z80 assembly test programs are in `tests/asm/` and built with [z88dk](https://github.com/z88dk/z88dk):
    ```sh
    z88dk-z80asm -b TestCharacters.asm
    z88dk-appmake +mz --org 0x2000 --audio -b TestCharacters.bin
    ```

## Project-Specific Conventions
- **Debug Prints:**
  - Use the 🚨 emoji in all debug prints.
  - Format hex values with fixed width and leading zeros:
    ```zig
    std.debug.print("🚨 Value: 0x{x:0>2}\n", .{value});
    ```
  - Use consistent prefixes: `🚨 Value:`, `🚨 State:`, `🚨 Mode:`, `🚨 Format:`
  - For enums, use `@tagName`:
    ```zig
    std.debug.print("🚨 Mode: {s}\n", .{@tagName(mode)});
    ```
- **Import Statements:**
  - Do NOT modify import statements unless explicitly requested by the user.
  - Never change, add, or remove imports without confirmation.

## Integration Points
- Emulator loads MZF files via drag-and-drop in the UI.
- ROM and character generator binaries are required in `src/system/roms/`.

## Key Files & Directories
- `src/main.zig`: Emulator entry point
- `src/chips/`: Hardware chip emulation
- `src/system/`: System logic, ROMs, video, and file formats
- `src/ui/`: User interface logic
- `tests/`: Zig and Z80 test programs

## Additional Notes
- The project is a work in progress and may not fully boot yet.
- Refer to `README.md` and `tests/asm/README.md` for more details on usage and test program building.

---
For any unclear conventions or if you need to modify imports, ask the user for explicit instructions.