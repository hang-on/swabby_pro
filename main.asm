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
    ; Load the pico-8 palette to colors 0-15.
    ld a,BACKGROUND_PALETTE_START
    ld b,PICO8_PALETTE_SIZE
    ld hl,pico8_palette
    call load_cram
    ; Load the font tiles.
    SELECT_BANK FONT_BANK
    ld bc,font_tiles_end-font_tiles
    ld de,$0000
    ld hl,font_tiles
    call load_vram
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
    .dw prepare_devmenu, run_devmenu, prepare_retro, run_retro
  ;
  ; ---------------------------------------------------------------------------
  ;
  ; ---------------------------------------------------------------------------
  prepare_retro:
    ; Andorra mode is a retro 16x16 sprite mode.
    SELECT_BANK RETRO_BANK
    ld bc,retro_tiles_end-retro_tiles
    ld de,SPRITE_BANK_START;-(16*32)         ; The first 16 tiles are the cols.
    ld hl,retro_tiles
    call load_vram                          ;
    ld a,BRIGHT_BLUE_TILE
    call reset_name_table
    ; Display test message
    ld hl,retro_msg
    ld a,7
    ld b,3
    ld c,6
    call print
    ; Initialize the variables.
    ld a,SWABBY_Y_INIT
    ld (swabby_y),a
    ld a,SWABBY_X_INIT
    ld (swabby_x),a
    ld a,SWABBY_IDLE
    ld (swabby_state),a
    ld a,SPRITE_0
    ld (swabby_sprite),a
    xor a
    ld (swabby_table_index),a
    ; The walker:
    ld a,WALKER_Y_INIT
    ld (walker_y),a
    ld a,WALKER_X_INIT
    ld (walker_x),a
    ld a,SPRITE_1
    ld (walker_sprite),a
    ; Turn on screen and frame interrupts.
    ld a,DISPLAY_1_FRAME_1_SIZE_0
    ld b,1
    call set_register
    ei
    ; When all is set, change the game state.
    ld a,GS_RUN_RETRO
    ld (game_state),a
  jp main_loop
  retro_msg:
    .asc "Press button (2)!#"
  swabby_table:
    .db SPRITE_1, SPRITE_2, SPRITE_3, SPRITE_4, SPRITE_0
  swabby_table_end:
  ;
  run_retro:
  ;
  call await_frame_interrupt
  call load_sat
  ;
  ; update()
  call get_input_ports
  ;
  ; Handle Swabby states.
  ld hl,swabby_state_timer
  ld a,255
  cp (hl)
  jp z,+
    inc (hl)
  +:
  ld a,(swabby_state)
  cp SWABBY_IDLE
  jp nz,++
  ; Handle Swabby idle state:
    call is_dpad_pressed
    jp nc,+
      ld a,SWABBY_MOVING
      ld (swabby_state),a
      xor a
      ld (swabby_state_timer),a
    +:
  ; End of swabby idle state.
  ++:
  ld a,(swabby_state)
  cp SWABBY_MOVING
  jp nz,++
  ; Handle Swabby moving state:
    call is_dpad_pressed
    jp c,+
      ld a,SWABBY_IDLE            ; If dpad is not pressed anymore, switch
      ld (swabby_state),a         ; out of move state, and back to idle.
      xor a
      ld (swabby_state_timer),a
      jp ++
    +:
    call is_right_pressed
    jp nc,+
      ld hl,swabby_x
      inc (hl)
    +:
    call is_left_pressed
    jp nc,+
      ld hl,swabby_x
      dec (hl)
    +:
    call is_up_pressed
    jp nc,+
      ld hl,swabby_y
      dec (hl)
    +:
    call is_down_pressed
    jp nc,+
      ld hl,swabby_y
      inc (hl)
    +:
  ++:
  call is_button_2_pressed
  jp nc,++
    ld a,(swabby_state_timer)
    cp 20
    jp c,++
      xor a
      ld (swabby_state_timer),a
      ld hl,swabby_table
      ld a,(swabby_table_index)
      ld d,0
      ld e,a
      add hl,de
      inc a
      cp swabby_table_end-swabby_table
      jr nz,+
        xor a
      +:
      ld (swabby_table_index),a
      ld a,(hl)
      ld (swabby_sprite),a
  ++:

  ;
  ; Handle the walker!

  ld ix,walker_y
  dec (ix+4)              ; The state timer.
  jp m,+
  dec (ix+1)
  +:
  ;
  call begin_sprites
  ld ix,swabby_y
  call add_metasprite
  ld ix,walker_y
  call add_metasprite

  ; Check for start button press
  call is_start_pressed
  jp nc,+
    di
    ld a,DISPLAY_0_FRAME_0_SIZE_0
    ld b,1
    call set_register
    ld a,GS_PREPARE_DEVMENU
    ld (game_state),a
    jp main_loop
  +:
  jp main_loop
  ;
  prepare_devmenu:
    ld a,0
    ld b,1
    call reset_name_table
    ; Display menu text
    ld hl,menu_title
    ld b,4
    ld c,7
    call print
    ; Item 1.
    ld hl,item_1
    ld b,6
    ld c,10
    call print
    ; Item 2.
    ld hl,item_2
    ld a,6
    ld b,8
    ld c,10
    call print
    ; Item 2.
    ld hl,item_3
    ld b,10
    ld c,10
    call print
    ; Item 4.
    ld hl,item_4
    ld b,12
    ld c,10
    call print
    ; Menu footer.
    ld hl,menu_footer
    ld b,18
    ld c,7
    call print
    ;
    ; Borrow sprite sheet from Copenhagen mode.
    SELECT_BANK COPENHAGEN_BANK
    ld bc,copenhagen_tiles_end-copenhagen_tiles
    ld de,$0e00                             ; Address of tile nr. 128 - 16
    ld hl,copenhagen_tiles                  ; This will load 127 tiles to the
    call load_vram                          ; first bank and 127 to the second.
    ; Set menu state
    xor a
    ld (menu_state),a
    ld (menu_timer),a
    ; Print external ram counter (counts title screen preps.).
    ld a,16
    ld b,21
    call set_cursor
    SELECT_EXTRAM
    ld hl,EXTRAM_START
    ld a,(hl)
    SELECT_ROM
    call print_register_a
    ; Turn on screen and frame interrupts.
    ld a,DISPLAY_1_FRAME_1_SIZE_0
    ld b,1
    call set_register
    ei
    ; When all is set, change the game state.
    ld a,GS_RUN_DEVMENU
    ld (game_state),a
  jp main_loop
  ; Menu item strings:
  menu_title:
    .asc "Swabby debug menu#"
  item_1:
    .asc "Title screen#"
  item_2:
    .asc "Low Res#"
  item_3:
    .asc "Hi Res#"
  item_4:
    .asc "Retro#"
  menu_footer:
    .asc "*Start* This menu#"
  ;
  run_devmenu:
    ;
    call await_frame_interrupt
    call load_sat
    ;
    ; update()
    call get_input_ports
    ;
    ld a,(menu_timer)                 ; If menu timer is up, then go on to
    cp MENU_DELAY                     ; check for keypresses. Otherwise, just
    jp z,+                            ; inc the timer (this timer goes from
      inc a                           ; 0 to MENU_DELAY) and stops there.
      ld (menu_timer),a               ; It is about anti-bouncing!
      jp menu_end
    +:
      call is_down_pressed       ; Move selector downwards if player
      jp nc,switch_menu_down_end      ; presses down. menu_state is the menu
        ld a,(menu_state)             ; item currently 'under' the selector.
        cp MENU_MAX
        jp z,switch_menu_down_end
          inc a
          ld (menu_state),a
          xor a
          ld (menu_timer),a
      switch_menu_down_end:
      call is_up_pressed         ; Move selector up, on dpad=up....
      jp nc,switch_menu_up_end
        ld a,(menu_state)
        cp MENU_MIN
        jp z,switch_menu_up_end
          dec a
          ld (menu_state),a
          xor a
          ld (menu_timer),a
      switch_menu_up_end:
      ; Check button 1 and 2 to see if user clicks menu item.
      call is_button_1_pressed
      jp c,handle_menu_click
      call is_button_2_pressed
      jp c,handle_menu_click
      jp menu_end
      ;
      handle_menu_click:
        ld hl,menu_state_to_game_state
        ld a,(menu_state)
        ld d,0
        ld e,a
        add hl,de
        ld a,(hl)
        ld (game_state),a                 ; Load game state for next loop,
        di                                ; based on menu item. Also disable
        ld a,DISPLAY_0_FRAME_0_SIZE_0     ; interrupts and turn screen off
        ld b,1                            ; so preparations of next mode are
        call set_register                 ; safely done.
      jp main_loop
      menu_state_to_game_state:           ; menu_item(0) == game_state(1), etc.
        .db 1, 5, 7, 11
      ;
    menu_end:
    ; Place menu sprite
    call begin_sprites
    ld hl,menu_table
    ld d,0
    ld a,(menu_state)
    ld e,a
    add hl,de
    ld b,(hl)
    ld a,3
    ld c,70
    call add_sprite
  jp main_loop
  menu_table:
    .db 46, 62, 78, 94                       ; Contains y-pos for menu selector.
  ;
  prepare_copenhagen:
    ; Prepare Copenhagen mode (large, unzoomed sprites)
    SELECT_BANK COPENHAGEN_BANK
    ld bc,copenhagen_tiles_end-copenhagen_tiles
    ld de,$0e00                             ; Address of tile nr. 128 - 16
    ld hl,copenhagen_tiles                  ; This will load 127 tiles to the
    call load_vram                          ; first bank and 127 to the second.
    ; Set background to blue.
    ld a,BRIGHT_BLUE_TILE
    ld b,2
    call reset_name_table
    ; Display test message
    ld hl,my_string
    ld a,7
    ld b,3
    ld c,6
    call print
    ; Initialize the variables.
    ld a,SWABBY_Y_INIT
    ld (swabby_y),a
    ld a,SWABBY_X_INIT
    ld (swabby_x),a
    ld a,SWABBY_IDLE
    ld (swabby_state),a
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
  my_string:
    .asc "Hi res!#"
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
    ; Handle Swabby states.
    ld a,(swabby_state)
    cp SWABBY_IDLE
    jp nz,swabby_idle_end
    ; Handle Swabby idle state:
      call is_dpad_pressed
      jp nc,swabby_idle_end
        ld a,SWABBY_MOVING
        ld (swabby_state),a
    swabby_idle_end:
    ld a,(swabby_state)
    cp SWABBY_MOVING
    jp nz,swabby_moving_end
    ; Handle Swabby moving state:
      call is_dpad_pressed
      jp c,+
        ld a,SWABBY_IDLE            ; If dpad is not pressed anymore, switch
        ld (swabby_state),a         ; out of move state, and back to idle.
        jp swabby_moving_end
      +:
      call is_right_pressed
      jp nc,+
        ld hl,swabby_x
        inc (hl)
      +:
      call is_left_pressed
      jp nc,+
        ld hl,swabby_x
        dec (hl)
      +:
      call is_up_pressed
      jp nc,+
        ld hl,swabby_y
        dec (hl)
      +:
      call is_down_pressed
      jp nc,+
        ld hl,swabby_y
        inc (hl)
      +:
    swabby_moving_end:
    call begin_sprites
    call is_dpad_pressed
    jp nc,+
      ld hl,swabby_flying_table
      jp ++
    +:
      ld hl,swabby_idle_table
    ++:
    ld d,9
    -:
      ld a,(swabby_y)
      add a,(hl)
      ld b,a
      inc hl
      ld a,(swabby_x)
      add a,(hl)
      ld c,a
      inc hl
      ld a,(hl)
      inc hl
      call add_sprite
      dec d
    jp nz,-
    ;
    ; Check for start button press
    call is_start_pressed
    jp nc,main_loop
      di
      ld a,DISPLAY_0_FRAME_0_SIZE_0
      ld b,1
      call set_register
      jp boot
  jp main_loop
  swabby_idle_table:
    ; Table to control Swabby meta sprite (y,x,charnum... repeat)
    .db 0, 0, 0, 0, 8, 1, 0, 16, 2
    .db 8, 0, 16, 8, 8, 17, 8, 16, 18
    .db 16, 0, 32, 16, 8, 33, 16, 16, 34
  swabby_flying_table:
  .db 0, 0, 48, 0, 8, 49, 0, 16, 50
  .db 8, 0, 64, 8, 8, 65, 8, 16, 66
  .db 16, 0, 80, 16, 8, 81, 16, 16, 82

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
  intro_tune_1:
    .incbin "bank_4\swabby_pro_intro.psg"
  intro_tune_2:
    .incbin "bank_4\swabby_pro_intro_2.psg"
.ends
;
.bank COPENHAGEN_BANK slot 2
; -----------------------------------------------------------------------------
.section "Copenhagen mode assets" free
; -----------------------------------------------------------------------------
  copenhagen_tiles:
    .include "bank_5\spritesheet3.png_tiles.inc"
  copenhagen_tiles_end:
.ends
;
.bank FONT_BANK slot 2
; -----------------------------------------------------------------------------
.section "Font assets" free
; -----------------------------------------------------------------------------
  ; Put this ascii map in header:
  ;   .asciitable
  ;      map " " to "z" = 0
  ;    .enda
  font_tiles:
    .include "bank_6\asciifont_atascii_tiles.inc"
  font_tiles_end:
.ends
;
.bank RETRO_BANK slot 2
; -----------------------------------------------------------------------------
.section "Retro mode assets" free
; -----------------------------------------------------------------------------
  retro_tiles:
    .include "bank_7\spritesheet.png_tiles.inc"
  retro_tiles_end:
.ends
