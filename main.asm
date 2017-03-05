.include "gglib.inc"
.include "gglib_extended.inc"
.include "spritelib.inc"
.include "swabbylib.inc"
.include "psglib.inc"
;
; Misc. definitions:
  .equ PICO8_PALETTE_SIZE 16
; Game states:
  .equ GS_BOOT 0
  .equ GS_PREPARE_TITLESCREEN 1
  .equ GS_RUN_TITLESCREEN 2
  .equ GS_PREPARE_RECORDER 3
  .equ GS_RUN_RECORDER 4
  .equ GS_PREPARE_SANDBOX 5
  .equ GS_RUN_SANDBOX 6
  ;
  .equ INITIAL_GAME_STATE GS_PREPARE_SANDBOX ; Where to go after boot?
; Titlesreen assets:
  .equ TITLESCREEN_BANK 2         ; Titlesreen assets are in bank 2.
  .equ BLINKER_WIDTH 18           ; The blinking "press start button" message
  .equ BLINKER_HEIGHT 1           ; is 18 tiles wide (and a single tile high).
  .equ BLINKER_ADDRESS $3b8e      ; Address of first name table element.
  .equ BLINKER_DURATION 100       ; Number of frames between on/off.
; Swabby:
  .equ SANDBOX_BANK 3             ; Pico-8 sandbox assets are in bank 3.
  .equ SWABBY_IDLE 0
  .equ SWABBY_MOVING 1
  .equ SWABBY_SHOOTING 16
  .equ SWABBY_X_INIT 48
  .equ SWABBY_Y_INIT $40
  .equ SWABBY_IDLE_SPRITE 0
  .equ SWABBY_MOVING_SPRITE 1
  .equ SWABBY_SPEED_INIT 1
  .equ SWABBY_MAX_Y 152           ; How low can Swabby go?
  .equ SWABBY_MIN_Y 22            ; ... and how high?
  .equ SWABBY_MIN_X 6*8
  .equ SWABBY_MAX_X (6*8)+(18*8)
; Sound:
  .equ SOUND_BANK 4
; Bullets:
  .equ BULLET_MAX 10              ; Maximum number of bullets. Will wrap!
  .equ BULLET_SPEED 3
  .equ BULLET_TILE 2
  .equ FIRE_DELAY_INIT 14
;
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Main variables" slot 3
  game_state db                   ; Contains game state.
  frame_counter db                ; Used in some loops.
  extram_header dw                ; Points inside the external ram.
  ;
  blinker_timer db                ; The speed of the titlesreen blinker.
  ;
  temp_byte db
  temp_word dw
  temp_buffer dsb 32*2
.ends
.ramsection "Sandbox variables" slot 3
  swabby_y db                     ; The order of these vars cannot change!
  swabby_x db
  swabby_sprite db
  swabby_state db
  swabby_state_timer db
  swabby_direction db
  swabby_speed db
  swabby_fire_timer db
  swabby_fire_lock db
  swabby_fire_delay db
  ;
  bullet_y_table dsb BULLET_MAX   ; Keep table vars in order!
  bullet_x_table dsb BULLET_MAX
  next_bullet db
.ends
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
  call get_input_ports
  ;
  ; Save the input ports at every 255th frame (4-5 sec).
  ld a,(frame_counter)
  dec a
  ld (frame_counter),a
  or a
  jp nz,+
    SELECT_EXTRAM
    ld hl,extram_header             ; Get extram header address.
    call get_word
    ld a,(InputPorts)               ; Read the variable set by GetInputPorts.
    ld (hl),a                       ; Write the InputPort state to extram.
    ld hl,extram_header             ; Increment the header (word).
    call inc_word
    SELECT_ROM
  +:
  jp main_loop
  ;
  ; ---------------------------------------------------------------------------
  prepare_sandbox:
    ; Prepare the sandbox mode
    SELECT_BANK SANDBOX_BANK
    ld bc,sandbox_tiles_end-sandbox_tiles
    ld de,$0e00                             ; Address of tile nr. 128 - 16
    ld hl,sandbox_tiles                     ; This will load 127 tiles to the
    call load_vram                          ; first bank and 127 to the second.
    ; Initialize the variables.
    ld a,SWABBY_Y_INIT
    ld (swabby_y),a
    ld a,SWABBY_X_INIT
    ld (swabby_x),a
    ld a,SWABBY_IDLE_SPRITE
    ld (swabby_sprite),a
    ld a,SWABBY_SPEED_INIT
    ld (swabby_speed),a
    ld a,FALSE
    ld (swabby_fire_lock),a
    ld a,FIRE_DELAY_INIT
    ld (swabby_fire_delay),a
    ld a,100
    ld (swabby_fire_timer),a                ; To avoid initial shooting anim.
    ; -- Variables initialized to zero.
    xor a
    ld (next_bullet),a
    ld b,(BULLET_MAX+1)*2                   ; Clear the bullet y,x tables.
    ld hl,bullet_y_table
    -:
      ld (hl),a
      inc hl
    djnz -
    ; Turn on screen and frame interrupts.
    ld a,DISPLAY_1_FRAME_1_SIZE_0_ZOOM
    ld b,1
    call set_register
    ei
    ; When all is set, change the game state.
    ld a,GS_RUN_SANDBOX
    ld (game_state),a
  jp main_loop
  ; ---------------------------------------------------------------------------
  run_sandbox:
    ; Run sandbox mode...
    call await_frame_interrupt
    ; draw() ----- operations during vblank.
    call load_sat
    ;
    ; update()
    call get_input_ports
    ld hl,swabby_state_timer
    inc (hl)
    ;
    ld a,(swabby_state)
    cp SWABBY_IDLE
    jp nz,skip_idle
      ; Handle Swabby idle state.
      ld a,SWABBY_IDLE_SPRITE
      ld (swabby_sprite),a
      call is_dpad_pressed
      jp nc,skip_idle
        ; If dpad is pressed while idle, change state to moving.
        ld a,SWABBY_MOVING
        call change_swabby_state
    skip_idle:
    ld a,(swabby_state)
    cp SWABBY_MOVING
    jp nz,skip_moving
      ; Handle Swabby moving state.
      ld a,SWABBY_MOVING_SPRITE
      ld (swabby_sprite),a
      call IsPlayer1RightPressed  ; Move right?
      jp nc,+
        ld a,(swabby_speed)
        ld b,a
        ld a,(swabby_x)
        add a,b
        cp SWABBY_MAX_X
        jp c,skip_max_x
          ld a,SWABBY_MAX_X
        skip_max_x:
        ld (swabby_x),a
      +:
      call IsPlayer1LeftPressed   ; Move left?
      jp nc,+
        ld a,(swabby_speed)
        ld b,a
        ld a,(swabby_x)
        sub b
        cp SWABBY_MIN_X
        jp nc,skip_min_x
          ld a,SWABBY_MIN_X
        skip_min_x:
        ld (swabby_x),a
      +:
      call IsPlayer1DownPressed   ; Move down?
      jp nc,+
        ld a,(swabby_speed)       ; Get Swabby's current spped.
        ld b,a                    ; Save in B.
        ld a,(swabby_y)           ; Get Swabby's current y-pos.
        add a,b                   ; Add speed to y-pos.
        cp SWABBY_MAX_Y           ; Will Swabby go through the floor?
        jp c, skip_max_y          ; No?, then skip forward.
          ld a,SWABBY_MAX_Y       ; Yes?, then set Swabby Y to max Y.
        skip_max_y:
        ld (swabby_y),a           ; Save this new y-pos in the variable.
      +:
      call IsPlayer1UpPressed     ; Move up?
      jp nc,+
        ld a,(swabby_speed)
        ld b,a
        ld a,(swabby_y)
        sub b
        cp SWABBY_MIN_Y
        jp nc,skip_min_y
          ld a,SWABBY_MIN_Y
        skip_min_y:
        ld (swabby_y),a
      +:
      call is_dpad_pressed
      jp c,skip_moving
        ; If no dpad action while moving, then change back to idle.
        ld a,SWABBY_IDLE
        call change_swabby_state
    skip_moving:
    ;
    ; Swabby's fire.
      ld hl,swabby_fire_timer
      inc (hl)
      ; Prevent auto fire.
      call is_button_1_pressed
      jp c,+
        ld a,FALSE
        ld (swabby_fire_lock),a
      +:
      ; Fire new bullet if conditions are right.
      ld a,(swabby_fire_lock)       ; 1st check - is fire lock off?
      cp FALSE
      jp nz,skip_new_bullet         ; If not, skip bullet creation.
        call is_button_1_pressed    ; 2nd check - is fire button pressed?
        jp nc,skip_new_bullet       ; If not, skip bullet creation.
          ld a,(swabby_fire_delay)  ; 3rd check - is timer past delay?
          ld hl,swabby_fire_timer
          cp (hl)
          jp nc,skip_new_bullet
            ; OK - everything is good. Fire new bullet.
            ld hl,bullet_y_table
            ld a,(next_bullet)
            ld d,0
            ld e,a
            add hl,de
            ld a,(swabby_y)
            inc a
            inc a
            ld (hl),a                 ; Write bullet's initial y-pos to table.
            ld e,BULLET_MAX
            add hl,de                 ; Forward to x-pos table.
            ld a,(swabby_x)
            ld b,8
            add a,b
            ld (hl),a                 ; Write bullet's initial x-pos to table.
            ;
            xor a
            ld (swabby_fire_timer),a  ; Reset fire timer.
            ld a,TRUE
            ld (swabby_fire_lock),a   ; Set fire lock (reset on button release).
            ;
            SELECT_BANK SOUND_BANK    ; Select the sound assets bank.
            ld hl,shot_1
            call PSGSFXPlay           ; Play the swabby shot sound effect.
            ;
            ld a,(next_bullet)        ; Increment or reset bullet table index.
            inc a
            cp BULLET_MAX-1
            jp nz,+
              xor a
            +:
            ld (next_bullet),a
            ;
      skip_new_bullet:
      ; Move all bullets.
      ld b,BULLET_MAX
      ld hl,bullet_x_table
      -:
        ld a,(hl)
        add a,BULLET_SPEED
        cp LCD_RIGHT_BORDER
        jp c,+                        ;
          ld a,LCD_RIGHT_BORDER+8     ; Keep bullets out of sight.
        +:                            ;
        ld (hl),a
        inc hl
      djnz -
      ; Set Swabby sprite to shooting!
      ld a,(swabby_fire_timer)
      cp 8
      jp nc,+
        ld a,SWABBY_SHOOTING
        ld (swabby_sprite),a
      +:
    end_of_swabby_fire:
    ;
    ;
    call begin_sprites                ; No sprites before this line!
    ; Put the swabby sprite in the buffer.
    ld hl,swabby_y
    ld b,(hl)
    inc hl
    ld c,(hl)
    inc hl
    ld a,(hl)
    call add_sprite
    ; Put relevant bullets on screen.
    ; ----
    ld ix,bullet_y_table
    ld b,BULLET_MAX
    -:
      ld a,(ix+BULLET_MAX)
      cp LCD_RIGHT_BORDER
      jp nc,+
        push bc
          ld b,(ix+0)
          ld c,a
          ld a,BULLET_TILE
          call add_sprite
        pop bc
      +:
      inc ix
    djnz -
    ;
    SELECT_BANK SOUND_BANK
    call PSGFrame
    call PSGSFXFrame
    jp main_loop
    ;
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
.ends
