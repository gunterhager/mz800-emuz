; MZ800Utils.inc - Reusable utility subroutines for MZ-800 test programs

; -----------------
; Wait loop (~1 second at 3.547 MHz)
; Modifies: a, bc, de
wait:
  ld bc, 1000h
outer:
  ld de, 10h
inner:
  dec de
  ld a, d
  or e
  jr nz, inner
  dec bc
  ld a, b
  or c
  jr nz, outer
  ret
