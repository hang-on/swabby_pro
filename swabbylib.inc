; swabbylib.inc

; -----------------------------------------------------------------------------
.ramsection "Swabby Library Variables" slot 3
; -----------------------------------------------------------------------------
  rnd_generator_word dw   ; Used by the random number generator.
.ends

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
  ret
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
  ret
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
; -----------------------------------------------------------------------------
.section "get_random_number" free
; -----------------------------------------------------------------------------
  get_random_number:
    ; Uses a 16-bit RAM variable called rnd_generator_word
    ; Returns an 8-bit pseudo-random number in A
    push hl
      ld hl,(rnd_generator_word)
      ld a,h         ; get high byte
      rrca           ; rotate right by 2
      rrca
      xor h          ; xor with original
      rrca           ; rotate right by 1
      xor l          ; xor with low byte
      rrca           ; rotate right by 4
      rrca
      rrca
      rrca
      xor l          ; xor again
      rra            ; rotate right by 1 through carry
      adc hl,hl      ; add rnd_generator_word to itself
      jr nz,+
        ld hl,$733c   ; if last xor resulted in zero then re-seed.
      +:
      ld a,r         ; r = refresh register = semi-random number
      xor l          ; xor with l which is fairly random
      ld (rnd_generator_word),hl
    pop hl
  ret                ; return random number in a
.ends
