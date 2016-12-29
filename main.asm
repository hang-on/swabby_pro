.include "gglib.inc"
.include "gglib_extended.inc"
;
; Definitions:
.equ PICO8_PALETTE_SIZE 16
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
    SELECT_BANK 2
    ; Load the pico-8 palette to colors 16-31.
    ld a,SPRITE_PALETTE_START
    ld b,PICO8_PALETTE_SIZE
    ld hl,pico8_palette
    call load_cram
    ; Load titlescreen tiles and tilemap to vram.
    ld bc,titlescreen_tiles_end-titlescreen_tiles
    ld de,BACKGROUND_BANK_START
    ld hl,titlescreen_tiles
    call load_vram
    ld bc,NAME_TABLE_SIZE
    ld de,NAME_TABLE_START
    ld hl,titlescreen_tilemap
    call load_vram
    ;
    ld bc,press_start_button_tiles_end-press_start_button_tiles
    ld de,SPRITE_BANK_START
    ld hl,press_start_button_tiles
    call load_vram
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
.section "title_screen" free
; -----------------------------------------------------------------------------
  titlescreen_tilemap:
    .include "bank_2\titlescreen_tilemap.inc"
  titlescreen_tiles:
    .include "bank_2\titlescreen_tiles.inc"
  titlescreen_tiles_end:
  ;
  press_start_button_tilemap:
    .include "bank_2\press_start_button_tilemap.inc"
  press_start_button_tilemap_end:
  press_start_button_tiles:
    .include "bank_2\press_start_button_tiles.inc"
  press_start_button_tiles_end:

.ends
