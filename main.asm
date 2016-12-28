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
    ld a,0
    ld b,16
    ld hl,pico8_palette
    call load_cram
    ;
    ; Turn on screen and frame interrupts.
    ld a,DISPLAY_1_FRAME_1_SIZE_0
    ld b,1
    call set_register
    ; Skip a frame to make sure that we start main at vblank.
    ei
    call await_frame_interrupt
  jp main_loop
  pico8_palette:
    .dw $0000 $0521 $0527 $0580 $035A $0455 $0CCC $0EFF
    .dw $040F $00AF $02EF $03E0 $0FA2 $0978 $0A7F $0ACF
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
;
;
.bank 2 slot 2
; -----------------------------------------------------------------------------
.section "title_screen_ribbon" free
; -----------------------------------------------------------------------------
  titlescreen_ribbon:
    .include "bank_2\titlescreen_ribbon.inc"
  titlescreen_ribbon_end:
  ;
.ends
