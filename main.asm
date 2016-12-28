.include "gglib.inc"
.include "gglib_extended.inc"
;
; Definitions:
; [none]
;
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Main variables" slot 3
  ; [no variables]
.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "main" free
; -----------------------------------------------------------------------------
  init:
    ; Run this function once (on game load).
    ;
    LOAD_RIBBON titlescreen_ribbon,titlescreen_ribbon_end
    ;
    ; Turn on screen and frame interrupts.
    ld a,DISPLAY_1_FRAME_1_SIZE_0
    ld b,1
    call set_register
    ; Skip a frame to make sure that we start main at vblank.
    ei
    call await_frame_interrupt
  jp main_loop
  ;
  ; ---------------------------------------------------------------------------
  main_loop:
    call await_frame_interrupt
    call draw
    ;
    call update
    ;
  jp main_loop
  ;
  ; ---------------------------------------------------------------------------
  draw:
    ; Draw sprites and background.
  ret
  ;
  ; ---------------------------------------------------------------------------
  update:
    ; Update the game objects.
  ret
  ;
.ends
;
.bank 1 slot 1
; -----------------------------------------------------------------------------
.section "title_screen_ribbon" free
; -----------------------------------------------------------------------------
  titlescreen_ribbon:
    .include "ribbons\titlescreen_ribbon.inc"
  titlescreen_ribbon_end:
  ;
.ends
;
.bank 2 slot 2
