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
    ; Turn on screen, etc.
    ld hl,init_register_data
    call load_vdp_registers
    ; Skip a frame to make sure that we start main at vblank.
    ei
    call await_frame_interrupt
  jp main_loop
  init_register_data:
    .db FULL_SCROLL_BLANK_LEFT_COLUMN_SHIFT_SPRITES_NO_RASTER_INT
    .db ENABLE_DISPLAY_ENABLE_FRAME_INTERRUPTS_NORMAL_SPRITES
    .db $ff,$ff,$ff,$ff,$ff,$00,$00,$00,$ff
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
