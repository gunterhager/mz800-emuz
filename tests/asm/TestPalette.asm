; Test palette register (port 0xF0) in 320x200 4-colour mode.
;
; Draws four horizontal bands — one for each palette entry (PLT0-PLT3):
;   Band 0 (lines   0-49):  Plane I=0, II=0  →  PLT0
;   Band 1 (lines  50-99):  Plane I=1, II=0  →  PLT1
;   Band 2 (lines 100-149): Plane I=0, II=1  →  PLT2
;   Band 3 (lines 150-199): Plane I=1, II=1  →  PLT3
;
; Then cycles through four colour sets with a delay, so the bands
; change colour while the VRAM data remains unchanged.
;

include "MZ800.inc"

defc LoadingAddress = 02000h
org LoadingAddress

defc ScreenLines  = 200
defc BytesPerLine = 40
defc LinesPerBand = 50
defc BytesPerBand = BytesPerLine * LinesPerBand  ; 2000

  ; Set stack
  ld hl, StackStart
  ld sp, hl

  ; Set display mode: 320x200, 4 colours, Frame A.
  ; Any DMD value other than DisplayMode40x25_8ColorMZ700 selects MZ-800 mode.
  ld a, DisplayMode320x200_4ColorFrameA
  out (PortDisplayModeRegister), a

  ; Bank in VRAM (maps VRAM to 0x8000-0xBFFF)
  out (PortBank_ROM1_CGROM_VRAM_ROM2), a  ; value of a does not matter

  ; ---- Fill VRAM plane I ----
  ; Pattern: [0x00 * 2000] [0xFF * 2000] [0x00 * 2000] [0xFF * 2000]
  ;   → Band 0: PLT0 column, Band 1: PLT1 column,
  ;     Band 2: PLT2 column, Band 3: PLT3 column (plane I bit only)
  ld a, WriteFormatSingleWrite | FormatPlaneI
  out (PortWriteFormatRegister), a
  out (PortReadFormatRegister), a

  ld hl, MemoryVRAMStart
  ld bc, BytesPerBand
  ld a, 000h
  call fill
  ld bc, BytesPerBand
  ld a, 0ffh
  call fill
  ld bc, BytesPerBand
  ld a, 000h
  call fill
  ld bc, BytesPerBand
  ld a, 0ffh
  call fill

  ; ---- Fill VRAM plane II ----
  ; Pattern: [0x00 * 4000] [0xFF * 4000]
  ;   → Bands 0-1: PLT0/PLT1 (plane II bit = 0),
  ;     Bands 2-3: PLT2/PLT3 (plane II bit = 1)
  ld a, WriteFormatSingleWrite | FormatPlaneII
  out (PortWriteFormatRegister), a
  out (PortReadFormatRegister), a

  ld hl, MemoryVRAMStart
  ld bc, BytesPerBand * 2
  ld a, 000h
  call fill
  ld bc, BytesPerBand * 2
  ld a, 0ffh
  call fill

  ; ---- Main loop: cycle through 4 colour sets ----
main:

  ; Colour set 1: Black / Blue / Red / White
  ld a, Palette0 | ColorBlack
  out (PortPaletteRegister), a
  ld a, Palette1 | ColorBlue
  out (PortPaletteRegister), a
  ld a, Palette2 | ColorRed
  out (PortPaletteRegister), a
  ld a, Palette3 | ColorWhite
  out (PortPaletteRegister), a
  call wait

  ; Colour set 2: Black / Green / Cyan / Yellow
  ld a, Palette0 | ColorBlack
  out (PortPaletteRegister), a
  ld a, Palette1 | ColorGreen
  out (PortPaletteRegister), a
  ld a, Palette2 | ColorCyan
  out (PortPaletteRegister), a
  ld a, Palette3 | ColorYellow
  out (PortPaletteRegister), a
  call wait

  ; Colour set 3: Black / LightBlue / LightRed / LightWhite
  ld a, Palette0 | ColorBlack
  out (PortPaletteRegister), a
  ld a, Palette1 | ColorLightBlue
  out (PortPaletteRegister), a
  ld a, Palette2 | ColorLightRed
  out (PortPaletteRegister), a
  ld a, Palette3 | ColorLightWhite
  out (PortPaletteRegister), a
  call wait

  ; Colour set 4: Black / Purple / LightGreen / LightYellow
  ld a, Palette0 | ColorBlack
  out (PortPaletteRegister), a
  ld a, Palette1 | ColorPurple
  out (PortPaletteRegister), a
  ld a, Palette2 | ColorLightGreen
  out (PortPaletteRegister), a
  ld a, Palette3 | ColorLightYellow
  out (PortPaletteRegister), a
  call wait

  jr main

; -----------------
; Fill bc bytes at hl with value a.
; Uses ldir trick: write first byte, then copy it forward.
; On return, hl points one past the filled region.
; Modifies: a, bc, de, hl
fill:
  ld (hl), a
  ld d, h
  ld e, l
  inc de
  dec bc
  ldir
  ret

include "MZ800Utils.inc"

  defs 256  ; room for stack
StackStart:
