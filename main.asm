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
  setup_main:
    ;
    LOAD_RIBBON title_screen_assets,title_screen_assets_end

    ; Turn on screen, etc.
    ld hl,register_data
    call load_vdp_registers
    ; Skip a frame to make sure that we start main at vblank.
    ei
    call AwaitFrameInterrupt
  jp main
  ;
  ; ---------------------------------------------------------------------------
  main:
    call AwaitFrameInterrupt
    ; NTSC vblank is lines 194-262 = 68 lines in total.
    ;
    ;
    jp main
.ends
;
.bank 1 slot 1
; -----------------------------------------------------------------------------
.section "title_screen_assets" free
; -----------------------------------------------------------------------------
  title_screen_assets:
    .include "titlescreen_assets.inc"
  title_screen_assets_end:
  ;
  register_data:
    .db FULL_SCROLL_BLANK_LEFT_COLUMN_SHIFT_SPRITES_NO_RASTER_INT
    .db ENABLE_DISPLAY_ENABLE_FRAME_INTERRUPTS_NORMAL_SPRITES
    .db $ff,$ff,$ff,$ff,$ff,$00,$00,$00,$ff
.ends
;
.bank 2 slot 2
