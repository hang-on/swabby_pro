; swabbylib.inc

; -----------------------------------------------------------------------------
.section "Swabby lib" free
; -----------------------------------------------------------------------------
  change_swabby_state:
    ; Change the state of Swabby and reset the state timer.
    ; Entry: A = state
    ld (swabby_state),a
    xor a
    ld (swabby_state_timer),a
  ret
.ends

; -----------------------------------------------------------------------------
.section "inc_array_element" free
; -----------------------------------------------------------------------------
  inc_array_element:
    ; Increments a byte-sized array element.
    ; Entry: A = index, HL = Pointer to table.
    ; Exit: None.
    ; Preserves all registers.
    push de
    push hl
    ld d,0
    ld e,a
    add hl,de
    inc (hl)
    pop hl
    pop de
.ends

; -----------------------------------------------------------------------------
.section "get_byte" free
; -----------------------------------------------------------------------------
  get_array_element:
    ; Gets the byte at index [in A] in table [pointer in HL].
    ; Entry: A = Index, HL = Poiner to table
    ; Exit: Byte in A.
    ; Preserves all registers.
    push de
    push hl
    ld d,0
    ld e,a
    add hl,de
    ld a,(hl)
    pop hl
    pop de
  ret
.ends

; -----------------------------------------------------------------------------
.section "set_byte" free
; -----------------------------------------------------------------------------
  set_array_element:
    ; Set a byte at index [in A] in table [pointer in HL].
    ; Entry: A = Index, B = value, HL = Poiner to table
    ; Exit: None
    ; Preserves all registers.
    push de
    push hl
    ld d,0
    ld e,a
    add hl,de
    ld (hl),b
    pop hl
    pop de
  ret
.ends
