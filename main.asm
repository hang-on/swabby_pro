.include "gglib.inc"
.include "gglib_extended.inc"
.include "header.inc"
.include "spritelib.inc"
.include "swabbylib.inc"
.include "psglib.inc"
;
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
    call PSGInit
    ;
    ld a,INITIAL_GAME_STATE
    ld (game_state),a
  jp main_loop
  ;
  pico8_palette:
    .dw $0000 $0521 $0527 $0580 $035A $0455 $0CCC $0EFF
    .dw $040F $00AF $02EF $03E0 $0FA2 $0978 $0A7F $0ACF
  ; ---------------------------------------------------------------------------
  main_loop:
    ; Note: This loop can begin on any line - wait for vblank in the states!
    ld a,(game_state)
    add a,a
    ld h,0
    ld l,a
    ld de,jump_table
    add hl,de
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    jp (hl)
    ;
  jump_table:
    ; Check the game state constants.
    .dw init, prepare_titlescreen, run_titlescreen
    .dw prepare_recorder, run_recorder, prepare_sandbox, run_sandbox
    .dw prepare_copenhagen, run_copenhagen
  ;
  ; ---------------------------------------------------------------------------
  ;
  ; ---------------------------------------------------------------------------
  prepare_copenhagen:
    ; Prepare the sandbox mode
    SELECT_BANK COPENHAGEN_BANK
    ld bc,sandbox_tiles_end-sandbox_tiles
    ld de,$0e00                             ; Address of tile nr. 128 - 16
    ld hl,copenhagen_tiles                  ; This will load 127 tiles to the
    call load_vram                          ; first bank and 127 to the second.
    ; Dirty hack for setting background color to blue.
    ld hl,NAME_TABLE_START
    ld a,l
    out (CONTROL_PORT),a
    ld a,h
    or VRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
    ld h,124                                 ; Index of light blue color tile.
    ld l,%00001000                           ; 2nd byte, select sprite palette.
    ld de,32*28                              ; 32 columns, 28 rows.
    -:
      ld a,h
      out (DATA_PORT),a                      ; Write 1st word to name table.
      ld a,l
      out (DATA_PORT),a                      ; Write 2nd word to name table.
      dec de
      ld a,e
      or d
    jp nz,-
    ; Initialize the variables.
    ld a,SWABBY_Y_INIT
    ld (swabby_y),a
    ld a,SWABBY_X_INIT
    ld (swabby_x),a
    ;
    ; Turn on screen and frame interrupts.
    ld a,DISPLAY_1_FRAME_1_SIZE_0
    ld b,1
    call set_register
    ei
    ; When all is set, change the game state.
    ld a,GS_RUN_COPENHAGEN
    ld (game_state),a
  jp main_loop
  ;
  ; ---------------------------------------------------------------------------
  run_copenhagen:
    ; Run sandbox mode...
    call await_frame_interrupt
    call load_sat
    ;
    ; update()
    call get_input_ports
    ;
    call begin_sprites

    ;
  jp main_loop
  swabby_table:
    ; Table to control Swabby meta sprite (charnum, x, y... repeat)
    .db 0, 0, 0, 1, 8, 0, 2, 16, 0
    .db 3, 0, 8, 4, 8, 8, 5, 16, 8
    .db 6, 0, 16, 7, 8, 16, 8, 16, 16

.ends
;
.bank 1 slot 1
;
;
.bank TITLESCREEN_BANK slot 2
; -----------------------------------------------------------------------------
.section "Title screen assets" free
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
  blinker_tilemap:                        ; Adjust BLINKER_WIDTH and
    .include "bank_2\blinker_tilemap.inc" ; BLINKER_HEIGHT on changes to the
  blinker_tilemap_end:                    ; blinker asset.
  blinker_tiles:
    .include "bank_2\blinker_tiles.inc"
  blinker_tiles_end:
.ends
;
.bank SANDBOX_BANK slot 2
; -----------------------------------------------------------------------------
.section "Sandbox assets" free
; -----------------------------------------------------------------------------
  sandbox_tiles:
    .include "bank_3\spritesheet.png_tiles.inc"
  sandbox_tiles_end:
.ends
;
.bank SOUND_BANK slot 2
; -----------------------------------------------------------------------------
.section "Sound assets" free
; -----------------------------------------------------------------------------
  shot_1:
    .incbin "bank_4\shot_1.psg"
  demon_attack:
    .incbin "bank_4\demon_attack.psg"
.ends
;
.bank 5 slot 2
; -----------------------------------------------------------------------------
.section "Copenhagen mode assets" free
; -----------------------------------------------------------------------------
  copenhagen_tiles:
    .include "bank_5\spritesheet.png_tiles.inc"
  copenhagen_tiles_end:
.ends
