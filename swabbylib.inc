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
