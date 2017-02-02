.include "gglib.inc"
.include "gglib_extended.inc"
;
; Misc. definitions:
  .equ PICO8_PALETTE_SIZE 16
; Game states:
  .equ GS_BOOT 0
  .equ GS_PREPARE_TITLESCREEN 1
  .equ GS_RUN_TITLESCREEN 2
  .equ GS_PREPARE_RECORDER 100
  .equ GS_RUN_RECORDER 101
  ;
  .equ INITIAL_GAME_STATE GS_PREPARE_RECORDER ; Where to go after boot?
; Titlesreen assets:
  .equ TITLESCREEN_BANK 2         ; Titlesreen assets are in bank 2.
  .equ BLINKER_WIDTH 18           ; The blinking "press start button" message
  .equ BLINKER_HEIGHT 1           ; is 18 tiles wide (and a single tile high).
  .equ BLINKER_ADDRESS $3b8e      ; Address of first name table element.
  .equ BLINKER_DURATION 100       ; Number of frames between on/off.
;
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Main variables" slot 3
  game_state db                   ; Contains game state.
  frame_counter db                ; Used in some loops.
  extram_header dw                 ; Points inside the external ram.
  ;
  blinker_timer db                ; The speed of the titlesreen blinker.
  ;
  temp_byte db
  temp_word dw
  temp_buffer dsb 32*2
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
    cp GS_PREPARE_TITLESCREEN
    jp z,prepare_titlescreen
    cp GS_RUN_TITLESCREEN
    jp z,run_titlescreen
    cp GS_PREPARE_RECORDER
    jp z,prepare_recorder
    cp GS_RUN_RECORDER
    jp z,run_recorder
  jp main_loop
  ;
  ; ---------------------------------------------------------------------------
  prepare_titlescreen:
    ; Load titlescreen tiles and tilemap to vram.
    SELECT_BANK TITLESCREEN_BANK
    ld bc,titlescreen_tiles_end-titlescreen_tiles
    ld de,BACKGROUND_BANK_START
    ld hl,titlescreen_tiles
    call load_vram
    ld bc,NAME_TABLE_SIZE
    ld de,NAME_TABLE_START
    ld hl,titlescreen_tilemap
    call load_vram
    ld hl,titlescreen_spritebank_table
    call load_spritebank
    ; Save the tilemap where "press start button" will blink.
    ld a,BLINKER_WIDTH
    ld b,BLINKER_HEIGHT
    ld hl,BLINKER_ADDRESS
    ld de,temp_buffer
    call copy_tilemap_rect_to_buffer
    ; Start timer.
    ld a,BLINKER_DURATION
    ld (blinker_timer),a
    ;
    ; Turn on screen and frame interrupts.
    ld a,DISPLAY_1_FRAME_1_SIZE_0
    ld b,1
    call set_register
    ei
    ; When all is set, change the game state.
    ld a,GS_RUN_TITLESCREEN
    ld (game_state),a
  jp main_loop
  ;
  ; ---------------------------------------------------------------------------
  run_titlescreen:
    call await_frame_interrupt
    ; Decrement blinker_timer and reset to BLINKER_DURATION if it reaches 0.
    ld a,(blinker_timer)
    dec a
    cp 0
    jp nz,+
      ld a,BLINKER_DURATION
    +:
    ld (blinker_timer),a
    cp BLINKER_DURATION/2
    jp c,+
      ; Remove "press start button".
      ld a,BLINKER_WIDTH
      ld b,BLINKER_HEIGHT
      ld hl,temp_buffer
      ld de,BLINKER_ADDRESS
      call copy_buffer_to_tilemap_rect
      jp ++
    +:
      ; Show "press start button".
      ld a,BLINKER_WIDTH
      ld b,BLINKER_HEIGHT
      ld hl,blinker_tilemap
      ld de,BLINKER_ADDRESS
      call copy_buffer_to_tilemap_rect
    ++:
    ;
    ; Non-VBlank stuff goes here...
    ld hl,frame_counter
    inc (hl)
  jp main_loop
  ;
  ; ---------------------------------------------------------------------------
  prepare_recorder:
    ld hl,EXTRAM_START              ; Point extram_header to the start
    ld (extram_header),hl           ; of external ram bank ($8000).
    ld a,1                          ; Set up frame counter to that it will
    ld (frame_counter),a            ; reach zero at first decrement.
    call clear_extram
    ; Turn on screen and frame interrupts.
    ld a,DISPLAY_1_FRAME_1_SIZE_0
    ld b,1
    call set_register
    ei
    ; When all is set, change the game state.
    ld a,GS_RUN_RECORDER
    ld (game_state),a
  jp main_loop
  ; ---------------------------------------------------------------------------
  run_recorder:
  ;
  call await_frame_interrupt
  call GetInputPorts
  ;
  ; Save the input ports at every 255th frame (4-5 sec).
  ld a,(frame_counter)
  dec a
  ld (frame_counter),a
  or a
  jp nz,+
    SELECT_EXTRAM
    ld hl,extram_header             ; Get extram header address.
    call word_get
    ld a,(InputPorts)               ; Read the variable set by GetInputPorts.
    ld (hl),a                       ; Write the InputPort state to extram.
    ld hl,extram_header             ; Increment the header (word).
    call word_inc
    SELECT_ROM
  +:
  jp main_loop
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
