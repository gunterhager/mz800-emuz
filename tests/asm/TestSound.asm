; Test full sound capabilities of the MZ-800 PSG (SN76489AN)
; Covers: tone frequency range, polyphony, attenuation sweep,
;         periodic/white noise at all divider rates, noise driven
;         by channel 2, and all four channels simultaneously.
; Border color changes at each stage as visual confirmation.
; Program halts after one full pass.

include "MZ800.inc"
include "MZ800Utils.inc"

org 02000h

; -----------------
; Set stack
  ld hl, StackStart
  ld sp, hl

; Silence all channels at startup
  call silence_all

; =================
; Section 1: Frequency range on channel 0
; Low note (divider 0x3FF), mid note (0x200), high note (0x050)
; =================

; Low note: divider 0x3FF
  ld a, PSGLatch | PSGChannel0 | 0fh ; lower 4 bits = 0xF
  call set_sound_data
  ld a, 3fh                           ; upper 6 bits = 0x3F
  call set_sound_data
  ld a, PSGLatch | PSGChannel0 | PSGAttenuation ; max volume
  call set_sound_data
  ld a, ColorBlue
  call set_border
  call wait

; Mid note: divider 0x200
  ld a, PSGLatch | PSGChannel0 | 00h  ; lower 4 bits = 0x0
  call set_sound_data
  ld a, 20h                            ; upper 6 bits = 0x20
  call set_sound_data
  ld a, ColorRed
  call set_border
  call wait

; High note: divider 0x050
  ld a, PSGLatch | PSGChannel0 | 00h  ; lower 4 bits = 0x0
  call set_sound_data
  ld a, 05h                            ; upper 6 bits = 0x05
  call set_sound_data
  ld a, ColorGreen
  call set_border
  call wait

; Silence channel 0
  ld a, PSGLatch | PSGChannel0 | PSGAttenuation | 0fh
  call set_sound_data

; =================
; Section 2: Three tone channels simultaneously (chord)
; Ch0: 0x123, Ch1: 0x189, Ch2: 0x1C7
; =================

; Channel 0: divider 0x123
  ld a, PSGLatch | PSGChannel0 | 03h
  call set_sound_data
  ld a, 12h
  call set_sound_data

; Channel 1: divider 0x189
  ld a, PSGLatch | PSGChannel1 | 09h
  call set_sound_data
  ld a, 18h
  call set_sound_data

; Channel 2: divider 0x1C7
  ld a, PSGLatch | PSGChannel2 | 07h
  call set_sound_data
  ld a, 1ch
  call set_sound_data

; Enable all three at max volume
  ld a, PSGLatch | PSGChannel0 | PSGAttenuation
  call set_sound_data
  ld a, PSGLatch | PSGChannel1 | PSGAttenuation
  call set_sound_data
  ld a, PSGLatch | PSGChannel2 | PSGAttenuation
  call set_sound_data
  ld a, ColorCyan
  call set_border
  call wait
  call wait

; Silence channels 0, 1, 2
  ld a, PSGLatch | PSGChannel0 | PSGAttenuation | 0fh
  call set_sound_data
  ld a, PSGLatch | PSGChannel1 | PSGAttenuation | 0fh
  call set_sound_data
  ld a, PSGLatch | PSGChannel2 | PSGAttenuation | 0fh
  call set_sound_data

; =================
; Section 3: Attenuation sweep on channel 0
; Fade in (0x0F -> 0x00) then fade out (0x00 -> 0x0F)
; =================

; Set channel 0 to mid note: divider 0x200
  ld a, PSGLatch | PSGChannel0 | 00h
  call set_sound_data
  ld a, 20h
  call set_sound_data
  ld a, ColorYellow
  call set_border

; Fade in: attenuation 15 down to 0
  ld b, 0fh
fade_in:
  ld a, PSGLatch | PSGChannel0 | PSGAttenuation
  or b
  call set_sound_data
  call wait
  dec b
  ld a, b
  cp 0ffh ; check for underflow (b wrapped from 0 to 0xFF)
  jr nz, fade_in
  ; Final step: set attenuation to 0 (max)
  ld a, PSGLatch | PSGChannel0 | PSGAttenuation
  call set_sound_data
  call wait

; Fade out: attenuation 1 up to 15
  ld b, 01h
fade_out:
  ld a, PSGLatch | PSGChannel0 | PSGAttenuation
  or b
  call set_sound_data
  call wait
  inc b
  ld a, b
  cp 10h
  jr nz, fade_out

; Silence channel 0
  ld a, PSGLatch | PSGChannel0 | PSGAttenuation | 0fh
  call set_sound_data

; =================
; Section 4: Periodic noise, all three fixed dividers
; =================

; Periodic noise, TYPE0 (divider 0x10 — ~6.9 kHz)
  ld a, PSGLatch | PSGChannel3 | PSGNoisePeriodic | PSGNoiseDivider0
  call set_sound_data
  ld a, PSGLatch | PSGChannel3 | PSGAttenuation   ; max volume
  call set_sound_data
  ld a, ColorPurple
  call set_border
  call wait

; Periodic noise, TYPE1 (divider 0x20 — ~3.5 kHz)
  ld a, PSGLatch | PSGChannel3 | PSGNoisePeriodic | PSGNoiseDivider1
  call set_sound_data
  ld a, ColorBlue
  call set_border
  call wait

; Periodic noise, TYPE2 (divider 0x40 — ~1.7 kHz)
  ld a, PSGLatch | PSGChannel3 | PSGNoisePeriodic | PSGNoiseDivider2
  call set_sound_data
  ld a, ColorRed
  call set_border
  call wait

; Silence noise channel
  ld a, PSGLatch | PSGChannel3 | PSGAttenuation | 0fh
  call set_sound_data

; =================
; Section 5: White noise, all three fixed dividers
; =================

; White noise, TYPE0
  ld a, PSGLatch | PSGChannel3 | PSGNoiseWhite | PSGNoiseDivider0
  call set_sound_data
  ld a, PSGLatch | PSGChannel3 | PSGAttenuation
  call set_sound_data
  ld a, ColorLightPurple
  call set_border
  call wait

; White noise, TYPE1
  ld a, PSGLatch | PSGChannel3 | PSGNoiseWhite | PSGNoiseDivider1
  call set_sound_data
  ld a, ColorLightBlue
  call set_border
  call wait

; White noise, TYPE2
  ld a, PSGLatch | PSGChannel3 | PSGNoiseWhite | PSGNoiseDivider2
  call set_sound_data
  ld a, ColorLightRed
  call set_border
  call wait

; Silence noise channel
  ld a, PSGLatch | PSGChannel3 | PSGAttenuation | 0fh
  call set_sound_data

; =================
; Section 6: Noise driven by channel 2 (TYPE3)
; Set channel 2 divider to 0x300, noise uses it as clock
; =================

; Channel 2: divider 0x300
  ld a, PSGLatch | PSGChannel2 | 00h  ; lower 4 bits = 0x0
  call set_sound_data
  ld a, 30h                            ; upper 6 bits = 0x30
  call set_sound_data

; White noise TYPE3 (driven by channel 2)
  ld a, PSGLatch | PSGChannel3 | PSGNoiseWhite | PSGNoiseDivider3
  call set_sound_data
  ld a, PSGLatch | PSGChannel3 | PSGAttenuation
  call set_sound_data
  ld a, ColorLightGreen
  call set_border
  call wait
  call wait

; Silence noise and channel 2
  ld a, PSGLatch | PSGChannel2 | PSGAttenuation | 0fh
  call set_sound_data
  ld a, PSGLatch | PSGChannel3 | PSGAttenuation | 0fh
  call set_sound_data

; =================
; Section 7: All four channels simultaneously
; Tones: Ch0 0x123, Ch1 0x189, Ch2 0x1C7 + white noise
; =================

; Channel 0: divider 0x123
  ld a, PSGLatch | PSGChannel0 | 03h
  call set_sound_data
  ld a, 12h
  call set_sound_data

; Channel 1: divider 0x189
  ld a, PSGLatch | PSGChannel1 | 09h
  call set_sound_data
  ld a, 18h
  call set_sound_data

; Channel 2: divider 0x1C7
  ld a, PSGLatch | PSGChannel2 | 07h
  call set_sound_data
  ld a, 1ch
  call set_sound_data

; White noise TYPE1
  ld a, PSGLatch | PSGChannel3 | PSGNoiseWhite | PSGNoiseDivider1
  call set_sound_data

; Enable all four channels at max volume
  ld a, PSGLatch | PSGChannel0 | PSGAttenuation
  call set_sound_data
  ld a, PSGLatch | PSGChannel1 | PSGAttenuation
  call set_sound_data
  ld a, PSGLatch | PSGChannel2 | PSGAttenuation
  call set_sound_data
  ld a, PSGLatch | PSGChannel3 | PSGAttenuation
  call set_sound_data
  ld a, ColorWhite
  call set_border
  call wait
  call wait

; =================
; Section 8: Silence all and halt
; =================

  call silence_all
  ld a, ColorBlack
  call set_border
  halt

; -----------------
; Silence all four channels
; Modifies: a
silence_all:
  ld a, PSGLatch | PSGChannel0 | PSGAttenuation | 0fh
  call set_sound_data
  ld a, PSGLatch | PSGChannel1 | PSGAttenuation | 0fh
  call set_sound_data
  ld a, PSGLatch | PSGChannel2 | PSGAttenuation | 0fh
  call set_sound_data
  ld a, PSGLatch | PSGChannel3 | PSGAttenuation | 0fh
  call set_sound_data
  ret

; -----------------
; Set sound data
; a contains data
set_sound_data:
  out (PortSound), a
  ret

; -----------------
; Set border color
; a contains color
set_border:
  ld b, PortBorderColorHigh
  ld c, PortBorderColorLow
  out (c), a
  ret

  defs 256 ; room for stack
StackStart:
