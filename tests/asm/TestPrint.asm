; TestPrint
; Output a character via Monitor routine.
; This works only if called via G command from monitor.
;
; Use z80asm from the z88dk project to build binary file.
; Command line:
; z88dk-z80asm -b TestScroll.asm

include "MZ800.inc"
include "MZ800ROMMonitor.inc"

defc LoadingAddress = 02000h
org LoadingAddress

    ld a, 'A'
    call CALL_PRNT
    ld a, 0dh
    call CALL_PRNT
    ld de, message
    call CALL_MSG
    ret

message:
    defb "THIS IS A TEST"
    defb 0dh
