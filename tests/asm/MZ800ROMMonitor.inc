;
; SHARP MZ-800 ROM Monitor 9Z-504M routines
;

; CALL_LETNL
; Moves the cursor to the beginning of the next line. 
; Registers saved: All except AF
defc CALL_LETNL = 00006h

; CALL_PRNTS
; Displays a space at the cursor position. 
; Registers saved: All except AF
defc CALL_PRNTS = 0000ch

; CALL_PRNT
; Displays the character corresponding to the ASCII code 
; stored in the ACC at the cursor position. See Appendix J for
; the ASCII codes. No character is displayed when code OD
; (carriage return) or codes 11 to 16 (the cursor control codes)
; are entered, but the corresponding function is still performed
; (a carriage return for OD and cursor movement for 11 to 16).
; Registers saved: All except AF
defc CALL_PRNT  = 00012h

; CALL_MSG
; Displays a message, starting at the position of the cursor. The 
; starting address of the area in which the message is
; stored must be loaded into the DE register before calling this
; code (OD).
; The carriage return is not executed.
; The cursor is moved if any cursor control codes (11 to 16) are
; subroutine, and the message must end with a carriage return
; included in the message.
; Registers saved: All except AF
defc CALL_MSG   = 00015h

