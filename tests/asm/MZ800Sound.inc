;
; SHARP MZ-800 PSG Sound Generator
;

; Port for setting registers in the PSG
defc PortSound = 0f2h

; Latch bit - should be set when addressing channel or setting attenuation
defc PSGLatch = 10000000b

; Channel addresses
defc PSGChannel0 = 00000000b ; tone channel
defc PSGChannel1 = 00100000b ; tone channel
defc PSGChannel2 = 01000000b ; tone channel
defc PSGChannel3 = 01100000b ; noise channel

; Attenuation bit - should be set when changing attenuation of a channel
defc PSGAttenuation = 00010000b

; Noise feedback type
defc PSGNoisePeriodic = 00000000b
defc PSGNoiseWhite = 00000100b

; Noise divider
defc PSGNoiseDivider0 = 00000000b
defc PSGNoiseDivider1 = 00000001b
defc PSGNoiseDivider2 = 00000010b
defc PSGNoiseDivider3 = 00000011b
