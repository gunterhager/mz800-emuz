![MZ-800](misc/cgrom_dump.png)

# mz800-emuz

**SHARP MZ-800 Emulator** using Andre Weissflog's https://github.com/floooh/chipz emulator infrastructure written in Zig (https://ziglang.org).

![MZ-800 Boot Screen](misc/boot_screen.png)

**NOTE:** This project is work in progress. While it does successfully boot into the ROM monitor there are still bugs and unimplemented features. E.g. loading **SHARP BASIC 1Z-016** doesn't work currently.

## Loading MZF or WAV files

You can load MZF or WAV files through the original CMT loading routines of the monitor. Just start the loading either from the IPL or the monitor and then drop the file onto the emulator window. 
The file loads showing a progress bar that simulates the CMT running. This takes exactly the same time as on the original hardware.

## Run the emulator

Build and run (tested with `zig-aarch64-macos-0.16.0-dev.2979+e93834410`):

```bash
zig build --release=fast run
```
