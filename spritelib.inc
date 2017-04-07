; *****************************************************************************
;                           SPRITE LIBRARY
; *****************************************************************************
; Note: Spritelib depends on constants from gglib.inc.

.equ PLAYER_SIZE 9          ; Number of tiles not part of asc/desc flicker.
.equ ASCENDING 0
.equ DESCENDING $ff

; MetaSpriteFlags:
.equ RIGHT_MASK   %0000001
.equ LEFT_MASK    %0000010
.equ NO_MASKS     %0000000

.ramsection "Spritelib Variables" slot 3
  SpriteBufferY dsb 64
  SpriteBufferXC dsb 128
  NextFreeSprite db
  MasterY db
  MasterX db
  MetaSpriteFlags db
  MetaSpriteSize db
  SATLoadMode db             ; Ascending or descending - for flickering.
.ends

; -----------------------------------------------------------------------------
.section "add_sprite" free
; -----------------------------------------------------------------------------
  ; Add a sprite of size = 1 character to the SAT.
  ; Entry: A = Character code (character in bank 2).
  ;        B = vertical position, C = horizontal position.
  ; Exit:
  ; Uses: None - all registers saved
  add_sprite:
    ; Test for sprite overflow (more than 64 hardware sprites at once).
    SAVE_REGISTERS
    ld d,a                    ; Save the tile in unused register.
    ld a,(NextFreeSprite)
    inc a
    cp 65
    jp nc,exit_add_sprite
    ld a,d                    ; Restore tile in A.
    ;
    push af
    push bc
    ; Point DE to SpriteBufferY[NextFreeSprite].
    ld a,(NextFreeSprite)
    ld de,SpriteBufferY
    add a,e
    ld e,a
    ld a,0
    adc a,d
    ld d,a

    ; Retrieve Y and X coords.
    pop bc
    ld a,b
    ld (de),a               ; Write the Y to the sprite buffer.

    ; Point DE to SpriteBufferXC[NextFreeSprite].
    ld a,(NextFreeSprite)
    add a,a               ; Table elements are words!
    ld de,SpriteBufferXC
    add a,e
    ld e,a
    ld a,0
    adc a,d
    ld d,a


    ld a,c                ; Get the x-pos.
    ld (de),a             ; Write it to the buffer.
    inc de
    pop af                ; Retrieve the charcode.
    ld (de),a             ; Write it to the buffer

    ld hl,NextFreeSprite
    inc (hl)
    ;
    exit_add_sprite:
    RESTORE_REGISTERS
  ret
.ends

; -----------------------------------------------------------------------------
.section "begin_sprites" free
; -----------------------------------------------------------------------------
  WipeData:
    .rept 64
      .db LCD_BOTTOM_BORDER+1
    .endr

  begin_sprites:
    ; Reset the NextFreeSprite index at the beginning of every frame
    xor a
    ld (NextFreeSprite),a

    ; Toggle ascending/descending sat load mode.
    ld a,(SATLoadMode)
    cpl
    ld (SATLoadMode),a

    ; Wipe Y-buffer with $e0 to get unused sprites out of the way.
    ld hl,WipeData
    ld de,SpriteBufferY
    ld bc,64
    ldir
  ret
.ends

; -----------------------------------------------------------------------------
.section "load_sat" free
; -----------------------------------------------------------------------------
  ; Load the vram sat with the SatY and SatXC buffers.
  ; Sonic 2 inspired flicker engine is in place: Flicker sprites by loading the
  ; SAT in ascending/descending order every other frame.
  load_sat:
    ld a,(SATLoadMode)
    cp DESCENDING
    jp z,_DescendingLoad
      ; If not descending, then fall through to ascending load mode.

      ; Load y-coordinates.
      ld hl,SAT_Y_START
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      ld hl,SpriteBufferY
      ld c,DATA_PORT
      .rept 64
        outi
      .endr

      ; Load x-coordinates and character codes.
      ld hl,SAT_XC_START
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      ld hl,SpriteBufferXC
      ld c,DATA_PORT
      .rept 128
        outi
      .endr
  ret

    _DescendingLoad:
      ; Load y-coordinates.
      ld hl,SAT_Y_START
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      ld c,DATA_PORT
      ld hl,SpriteBufferY
      .rept PLAYER_SIZE
        outi
      .endr

      ld hl,SpriteBufferY+63    ; Point to last y-value in buffer.
      .rept 64-PLAYER_SIZE
        outd                    ; Output and decrement HL, thus going
      .endr                     ; backwards (descending) through the buffer.

      ; Load x-coordinates and character codes
      ld hl,SAT_XC_START
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      ld c,DATA_PORT
      ld hl,SpriteBufferXC
      .rept PLAYER_SIZE
        outi
        outi
      .endr

      ld hl,SpriteBufferXC+126
      ld de,-4
      .rept 64-PLAYER_SIZE
        outi
        outi
        add hl,de
      .endr
  ret
.ends
