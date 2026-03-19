; Write "ABCDEFG" to the screen using MZ-700 text mode
;
; Reproduces the ROM monitor's character printing method (CALL_PRNT)
; without calling any ROM code.
;
; ROM monitor flow:
;   CALL_PRNT ($0012) -> PRNT ($0935) -> PRNT_CHAR ($0946)
;     -> QADCN_LOOKUP ($0BB9): ASCII to display code via table
;     -> QDSP_PUTCHAR ($096C) -> QDSP_CHAR ($0DB5):
;       -> QPOINT ($0FB1): VRAM address = $D000 + row*40 + col
;       -> ld (hl), a: write display code to character VRAM
;       -> advance cursor (col++, wrap at 40)
;
; This program reimplements each step:
;   printString  -> CALL_MSG    : print null-terminated string
;   printChar    -> QDSP_CHAR   : write display code to VRAM, advance cursor
;   asciiToDisp  -> QADCN_LOOKUP: ASCII to display code via lookup table
;   getCursorAddr-> QPOINT      : calculate VRAM address from cursor position
;

include "MZ800.inc"

defc LoadingAddress = 02000h
org LoadingAddress

  ; Set stack
  ld hl, StackStart
  ld sp, hl

  ; -----------------
  ; Hardware setup - same sequence the ROM monitor uses at cold start
  ; -----------------

  ; Set MZ-700 text display mode (40x25, 8 colors)
  ld a, DisplayMode40x25_8ColorMZ700
  out (PortDisplayModeRegister), a

  ; Bank in VRAM (value of a is irrelevant for bank switching)
  out (PortBank_ROM1_CGROM_VRAM_ROM2), a

  ; Set MZ-700 write format
  ld a, WriteFormatMZ700
  out (PortWriteFormatRegister), a

  ; Set MZ-700 read format
  ld a, ReadFormatMZ700
  out (PortReadFormatRegister), a

  ; -----------------
  ; Clear screen - reproduces ROM's QDPCT_CLR ($0E3A)
  ; -----------------

  ; Clear character VRAM with $00 (space in display code)
  ld hl, MemoryMZ700VRAMStart
  ld de, MemoryMZ700VRAMStart + 1
  ld bc, MemoryMZ700VRAMEnd - MemoryMZ700VRAMStart
  ld (hl), 000h
  ldir

  ; Fill color VRAM with $71 (white foreground, blue background)
  ; This matches the ROM monitor's default color scheme.
  ld hl, MemoryMZ700VRAMColorStart
  ld de, MemoryMZ700VRAMColorStart + 1
  ld bc, MemoryMZ700VRAMColorEnd - MemoryMZ700VRAMColorStart
  ld (hl), 071h
  ldir

  ; -----------------
  ; Initialize cursor at top-left (row 0, col 0)
  ; ROM monitor stores this at MON_CURPOS ($1171): L=col, H=row
  ; -----------------
  xor a
  ld (cursorCol), a
  ld (cursorRow), a

  ; -----------------
  ; Print "ABCDEFG"
  ; -----------------
  ld de, message
  call printString

  halt

; =================
; printString
; Print a null-terminated string starting at address DE.
; Reproduces ROM's CALL_MSG but uses null terminator instead of CR.
; Input: DE = address of null-terminated string
; Modifies: a, bc, de, hl
; =================
printString:
  ld a, (de)
  or a              ; check for null terminator
  ret z
  call printChar
  inc de
  jr printString

; =================
; printChar
; Convert ASCII character to display code and write it to VRAM
; at the current cursor position, then advance the cursor.
; Reproduces ROM's QDSP_CHAR ($0DB5) + QADCN_LOOKUP ($0BB9).
; Input: A = ASCII character code
; Modifies: a, bc, hl
; =================
printChar:
  push de

  ; Convert ASCII to display code (QADCN_LOOKUP)
  call asciiToDisp

  ; Calculate VRAM address for current cursor position (QPOINT)
  push af
  call getCursorAddr  ; HL = VRAM address
  pop af

  ; Write display code to character VRAM (the key operation)
  ld (hl), a

  ; Advance cursor
  ld a, (cursorCol)
  inc a
  cp 40             ; at end of line?
  jr c, noWrap
  xor a             ; wrap to column 0
  ld (cursorCol), a
  ld a, (cursorRow)
  inc a
  cp 25             ; past bottom of screen?
  jr c, noRowClamp
  ld a, 24          ; clamp to last row (no scroll in this version)
noRowClamp:
  ld (cursorRow), a
  pop de
  ret

noWrap:
  ld (cursorCol), a
  pop de
  ret

; =================
; asciiToDisp
; Convert an ASCII character code to the MZ-800 display code.
; Reproduces ROM's QADCN_LOOKUP ($0BB9) using a 64-byte table
; for printable ASCII $20-$5F. Lowercase $61-$7A maps to uppercase.
; Input: A = ASCII character ($20-$7F)
; Output: A = display code
; Modifies: a, hl
; =================
asciiToDisp:
  push bc

  ; Map lowercase to uppercase
  cp 061h           ; 'a'
  jr c, notLower
  cp 07bh           ; past 'z'?
  jr nc, notLower
  sub 020h          ; convert to uppercase
notLower:

  ; Table covers ASCII $20-$5F (64 entries)
  sub 020h          ; offset from space
  cp 64             ; within table?
  jr c, inTable
  xor a             ; out of range -> space (display code $00)
  pop bc
  ret

inTable:
  ld hl, asciiTable
  ld c, a
  ld b, 0
  add hl, bc
  ld a, (hl)

  pop bc
  ret

; =================
; getCursorAddr
; Calculate the VRAM address for the current cursor position.
; Reproduces ROM's QPOINT ($0FB1):
;   HL = $CFD8 + (row+1)*40 + col = $D000 + row*40 + col
; The ROM starts at $CFD8 ($D000 - 40) and adds 40 per row,
; looping row+1 times. We use the same algorithm.
; Output: HL = character VRAM address ($D000 + row*40 + col)
; Modifies: a, bc, de, hl
; =================
getCursorAddr:
  ld a, (cursorRow)
  ld b, a           ; B = row counter
  ld a, (cursorCol)
  ld c, a           ; C = column
  ld de, 40         ; bytes per row
  ld hl, 0cfd8h     ; $D000 - 40 (same base as ROM's QPOINT)
addRow:
  add hl, de        ; add one row
  dec b
  jp p, addRow      ; loop while B >= 0
  ld b, 0
  add hl, bc        ; add column offset
  ret

; =================
; Data
; =================

message:
  defm "ABCDEFG"
  defb 0            ; null terminator

; ASCII-to-display-code lookup table for printable ASCII $20-$5F.
; Derived from the ROM's KEY_TBL_NORMAL at $0A92 (offsets $20-$5F).
; Index 0 = ASCII $20 (space), index 63 = ASCII $5F (underscore).
;
; Key mappings:
;   Space ($20) -> $00      Digits 0-9 ($30-$39) -> $20-$29
;   A-Z ($41-$5A) -> $01-$1A
;
asciiTable:
  ;       +0    +1    +2    +3    +4    +5    +6    +7
  defb   000h, 061h, 062h, 063h, 064h, 065h, 066h, 067h  ; $20: SP  !   "   #   $   %   &   '
  defb   068h, 069h, 06bh, 06ah, 02fh, 02ah, 02eh, 02dh  ; $28: (   )   *   +   ,   -   .   /
  defb   020h, 021h, 022h, 023h, 024h, 025h, 026h, 027h  ; $30: 0   1   2   3   4   5   6   7
  defb   028h, 029h, 04fh, 02ch, 051h, 02bh, 057h, 049h  ; $38: 8   9   :   ;   <   =   >   ?
  defb   055h, 001h, 002h, 003h, 004h, 005h, 006h, 007h  ; $40: @   A   B   C   D   E   F   G
  defb   008h, 009h, 00ah, 00bh, 00ch, 00dh, 00eh, 00fh  ; $48: H   I   J   K   L   M   N   O
  defb   010h, 011h, 012h, 013h, 014h, 015h, 016h, 017h  ; $50: P   Q   R   S   T   U   V   W
  defb   018h, 019h, 01ah, 052h, 059h, 054h, 050h, 045h  ; $58: X   Y   Z   [   \   ]   ^   _

; -----------------
; Cursor state
; -----------------
cursorCol:
  defb 0
cursorRow:
  defb 0

  defs 256 ; room for stack
StackStart:
