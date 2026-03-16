; Test playing tones on the sound generator
;

include "MZ800.inc"

org 02000h

; -----------------
; Set stack
  ld hl, StackStart ; stack goes down from stack start
  ld sp, hl

; -----------------
; Set divider for channel 0 to 0x123
  ld a, PSGLatch | PSGChannel0 | 03h
  call set_sound_data
  ld a, 12h
  call set_sound_data

; Set divider for channel 1 to 0x456
  ld a, PSGLatch | PSGChannel1 | 04h
  call set_sound_data
  ld a, 56h
  call set_sound_data

; Set divider for channel 2 to 0x789
  ld a, PSGLatch | PSGChannel2 | 07h
  call set_sound_data
  ld a, 89h
  call set_sound_data

; -----------------
; Main loop
main:
; Set attenuation for channel 0 to 0
  ld a, PSGLatch | PSGChannel0 | PSGAttenuation
  call set_sound_data
  ld a, ColorRed
  call set_border
  call wait

; Set attenuation for channel 1 to 0
  ld a, PSGLatch | PSGChannel1 | PSGAttenuation
  call set_sound_data
  ld a, ColorLightRed
  call set_border
  call wait

; Set attenuation for channel 1 to 0
  ld a, PSGLatch | PSGChannel2 | PSGAttenuation
  call set_sound_data
  ld a, ColorYellow
  call set_border
  call wait

; Set attenuation for channel 3 to 0
  ld a, PSGLatch | PSGChannel3 | PSGAttenuation
  call set_sound_data
  ld a, ColorLightYellow
  call set_border
  call wait

; Set attenuation for all channels to OFF
  ld a, PSGLatch | PSGChannel0 | PSGAttenuation | 0fh
  call set_sound_data
  ld a, PSGLatch | PSGChannel1 | PSGAttenuation | 0fh
  call set_sound_data
  ld a, PSGLatch | PSGChannel2 | PSGAttenuation | 0fh
  call set_sound_data
  ld a, PSGLatch | PSGChannel3 | PSGAttenuation | 0fh
  call set_sound_data
  ld a, ColorBlack
  call set_border
  call wait
  jr main

; -----------------
; Set sound data
; a contains data
set_sound_data:
  out (PortSound), a
  ret

; -----------------
; Set border
; a contains color
set_border:
  ld b, PortBorderColorHigh ; b contains the upper part of the port address
  ld c, PortBorderColorLow ; c contains the lower part of the port address
  out (c), a
  ret

; -----------------
; Wait loop
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

  defs 256 ; room for stack
StackStart:
