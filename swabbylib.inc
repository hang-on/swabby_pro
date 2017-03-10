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
.section "inc_table_item" free
; -----------------------------------------------------------------------------
  inc_table_item:
    ; Increments a byte-sized table item.
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
.section "dec_table_item" free
; -----------------------------------------------------------------------------
  dec_table_item:
    ; Decrement a byte-sized table item.
    ; Entry: A = index, HL = Pointer to table.
    ; Exit: None.
    ; Preserves all registers.
    push de
    push hl
    ld d,0
    ld e,a
    add hl,de
    dec (hl)
    pop hl
    pop de
.ends

; -----------------------------------------------------------------------------
.section "get_table_item" free
; -----------------------------------------------------------------------------
  get_table_item:
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
.section "set_table_item" free
; -----------------------------------------------------------------------------
  set_table_item:
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
