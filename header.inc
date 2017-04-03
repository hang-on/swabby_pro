;
  .asciitable
    map " " to "z" = 0
  .enda
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
  .equ GS_PREPARE_COPENHAGEN 7    ; Copenhagen mode: Pro sprites!
  .equ GS_RUN_COPENHAGEN 8
  .equ GS_PREPARE_DEVMENU 9
  .equ GS_RUN_DEVMENU 10
  ;
  .equ INITIAL_GAME_STATE GS_PREPARE_DEVMENU ; Where to go after boot?
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
; Demons:
  .equ MAX_ACTIVE_DEMONS 5        ; Must be 5!
  .equ DEMON_ACTIVE_UNITS_INIT 1
  .equ DEMON_FLYING_1 32          ; Demon tiles.
  .equ DEMON_FLYING_2 34
  .equ DEMON_ATTACKING 33
  .equ DEMON_SLEEPING_STATE 2     ; Demon states.
  .equ DEMON_ATTACKING_STATE 1
  .equ DEMON_FLYING_STATE 0
; Copenhagen mode:
  .equ COPENHAGEN_BANK 5
; Font:
  .equ FONT_BANK 6
  .equ STRING_TERMINATOR 3        ; Terminate strings with #
  ; Development menu:
  .equ MENU_MIN 0
  .equ MENU_MAX 2
  .equ MENU_DELAY 50
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
  ;
  active_demons db
  active_demons_timer dw
  demon_timer_table dsb MAX_ACTIVE_DEMONS
  demon_state_table dsb MAX_ACTIVE_DEMONS
  demon_y_table dsb MAX_ACTIVE_DEMONS
  demon_x_table dsb MAX_ACTIVE_DEMONS
  demon_sprite_table dsb MAX_ACTIVE_DEMONS
  ;
  menu_timer db
  menu_state db
.ends
