; TestKeyboard
; Scans the keyboard matrix via PPI and displays pressed keys.
; Run via G 2000 from the MZ-800 monitor.
; Uses MZ-800 native display mode (no display mode register written).
;

include "MZ800.inc"
include "MZ800ROMMonitor.inc"

defc LoadingAddress = 02000h
org LoadingAddress

    ld de, msg_prompt
    call CALL_MSG

main_loop:
    call wait_release
    call scan_key           ; returns B=column, C=bit_pos
    call get_char           ; returns A=ASCII char (0=non-printable)
    or a
    jr z, main_loop
    call CALL_PRNT
    jr main_loop

;------------------------------------------
; wait_release
; Waits until all keyboard columns read 0xFF (no keys pressed).
; Restarts the full scan if any key is still held.
;
wait_release:
    ld b, 0
wr_col:
    ld a, b
    out (PortKeyboardColumnSelect), a
    in a, (PortKeyboardRowData)
    cpl                         ; invert: 1=pressed
    or a
    jr nz, wait_release         ; key still held, restart
    inc b
    ld a, b
    cp KeyboardColumnCount
    jr nz, wr_col
    ret

;------------------------------------------
; scan_key
; Polls keyboard columns until a pressed key is detected.
; Returns: B = column (0-9), C = bit position (0=bit7 .. 7=bit0)
;
scan_key:
    ld b, 0
sk_col:
    ld a, b
    out (PortKeyboardColumnSelect), a
    in a, (PortKeyboardRowData)
    cpl                         ; invert: 1=pressed
    or a
    jr nz, sk_found
    inc b
    ld a, b
    cp KeyboardColumnCount
    jr nz, sk_col
    jr scan_key                 ; no key found, keep polling
sk_found:
    ; A = pressed bits (active high), B = column
    ; Find the highest set bit: repeated RLCA shifts bit7 into carry
    ld c, 0
sk_bit:
    rlca                        ; old bit7 -> carry
    jr c, sk_done
    inc c
    jr sk_bit
sk_done:
    ret

;------------------------------------------
; get_char
; Looks up the printable character for a key position.
; Input:  B = column (0-9), C = bit position (0=bit7 .. 7=bit0)
; Output: A = ASCII character, or 0 if non-printable
;
get_char:
    ld hl, char_table
    ld a, b
    add a, a                    ; col * 2
    add a, a                    ; col * 4
    add a, a                    ; col * 8
    ld e, a
    ld d, 0
    add hl, de                  ; start of column entries
    ld e, c
    add hl, de                  ; entry for this bit position
    ld a, (hl)
    ret

;------------------------------------------
; Data

msg_prompt:
    defb "KEYBOARD TEST - PRESS A KEY:"
    defb 0dh

; Character lookup table: 10 columns x 8 bits = 80 bytes
; Index = col*8 + bit_pos  (bit_pos 0=bit7, 1=bit6, ... 7=bit0)
; 0 = non-printable key
char_table:
    ; Col 0: BLANK, GRAPH, POUND(F9), ALPHA, TAB, ;, :, CR
    defb 0, 0, 0, 0, 0, ';', ':', 0dh
    ; Col 1: Y, Z, -, [, ], -, -, -
    defb 'Y', 'Z', 0, '[', ']', 0, 0, 0
    ; Col 2: Q, R, S, T, U, V, W, X
    defb 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X'
    ; Col 3: I, J, K, L, M, N, O, P
    defb 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P'
    ; Col 4: A, B, C, D, E, F, G, H
    defb 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'
    ; Col 5: 1, 2, 3, 4, 5, 6, 7, 8
    defb '1', '2', '3', '4', '5', '6', '7', '8'
    ; Col 6: -, =, -, SPC, 0, 9, ',', '.'
    defb 0, '=', '-', ' ', '0', '9', ',', '.'
    ; Col 7: INS, DEL, UP, DOWN, RIGHT, LEFT, -, /
    defb 0, 0, 0, 0, 0, 0, 0, '/'
    ; Col 8: ESC, CTRL, -, -, -, -, -, SHIFT
    defb 0, 0, 0, 0, 0, 0, 0, 0
    ; Col 9: F1, F2, F3, F4, F5, -, -, -
    defb 0, 0, 0, 0, 0, 0, 0, 0
