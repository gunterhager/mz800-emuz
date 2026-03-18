;
; SHARP MZ-800 Keyboard (PPI Intel 8255)
;

defc PortKeyboardColumnSelect = 0d0h  ; Port A: write column number (0-9)
defc PortKeyboardRowData      = 0d1h  ; Port B: read row bits (active low, 0=pressed)
defc PortKeyboardPortC        = 0d2h  ; Port C
defc PortKeyboardControl      = 0d3h  ; PPI control word

defc KeyboardColumnCount = 10         ; 10 keyboard matrix columns
