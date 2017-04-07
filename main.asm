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
    .dw prepare_devmenu, run_devmenu
  ;
  ; ---------------------------------------------------------------------------
  ;
  ; ---------------------------------------------------------------------------
  prepare_devmenu:

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
        .db 1, 5, 7
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
    .db 46, 62, 78                          ; Contains y-pos for menu selector.
  ;
  prepare_copenhagen:
    ; Prepare Copenhagen mode (large, unzoomed sprites)
    SELECT_BANK COPENHAGEN_BANK
    ld bc,copenhagen_tiles_end-copenhagen_tiles
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
    .asc "SWABBY!#"
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
