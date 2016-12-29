.include "gglib.inc"
.include "gglib_extended.inc"
;
; Misc. definitions:
  .equ PICO8_PALETTE_SIZE 16
; Game states:
  .equ GS_BOOT 0
  .equ GS_PREPARE_TITLESCREEN 1
  .equ GS_RUN_TITLESCREEN 2
;
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Main variables" slot 3
  game_state db
  frame_counter db
.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "main" free
; -----------------------------------------------------------------------------
  init:
    ; Run this function once (on game load).
    ; Load the pico-8 palette to colors 16-31.
    ld a,SPRITE_PALETTE_START
    ld b,PICO8_PALETTE_SIZE
    ld hl,pico8_palette
    call load_cram
    ;
    ld a,GS_PREPARE_TITLESCREEN
    ld (game_state),a
  jp main_loop

  pico8_palette:
    .dw $0000 $0521 $0527 $0580 $035A $0455 $0CCC $0EFF
    .dw $040F $00AF $02EF $03E0 $0FA2 $0978 $0A7F $0ACF
  ; ---------------------------------------------------------------------------
  main_loop:
    ; Note: Wait for vblank in the loops!
    ld a,(game_state)
    cp GS_PREPARE_TITLESCREEN
    jp z,prepare_titlescreen
    cp GS_RUN_TITLESCREEN
    jp z,run_titlescreen
    ;
  jp main_loop
  ;
  ; ---------------------------------------------------------------------------
  prepare_titlescreen:
    SELECT_BANK 2
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
    ld hl,titlescreen_spritebank_table
    call load_spritebank
    ;
    ld a,GS_RUN_TITLESCREEN
    ld (game_state),a
    ; Turn on screen and frame interrupts.
    ld a,DISPLAY_1_FRAME_1_SIZE_0
    ld b,1
    call set_register
    ei
  jp main_loop
  ;
  ; ---------------------------------------------------------------------------
  run_titlescreen:
    ; Draw the graphics.
    call await_frame_interrupt
    ;
    ;
    ; Update the game objects.
    ld hl,frame_counter
    inc (hl)
  jp main_loop
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
  titlescreen_spritebank_table:           ; Used by function load_spritebank.
    .db 0                                 ; Index in spritebank.
    .dw blinker_tiles_end-blinker_tiles   ; Number of bytes to load.
    .dw blinker_tiles                     ; Pointer to tile data.
    .db END_OF_TABLE                      ; Table terminator.
  ;
  titlescreen_tilemap:
    .include "bank_2\titlescreen_tilemap.inc"
  titlescreen_tiles:
    .include "bank_2\titlescreen_tiles.inc"
  titlescreen_tiles_end:
  ;
  blinker_tilemap:
    .include "bank_2\blinker_tilemap.inc"
  blinker_tilemap_end:
  blinker_tiles:
    .include "bank_2\blinker_tiles.inc"
  blinker_tiles_end:

.ends
