; gglib_extended.inc - updated winter 2016/2017
;
;
.equ ONE_TILEMAP_ROW 32*2
.equ END_OF_TABLE $ff

; -----------------------------------------------------------------------------
.section "vdp_registers" free
; -----------------------------------------------------------------------------
  load_vdp_registers:
    ; Load all 11 vdp registers with preset values.
    ; Entry: HL pointing to init data block (11 bytes).
    xor b
    -:
      ld a,(hl)
      out (CONTROL_PORT),a
      inc hl
      ld a,b
      or REGISTER_WRITE_COMMAND
      out (CONTROL_PORT),a
      cp REGISTER_WRITE_COMMAND|10
      ret z
      inc b
    jr -
  ret
.ends

; -----------------------------------------------------------------------------
.section "tilemap_editing" free
; -----------------------------------------------------------------------------
  copy_tilemap_rect_to_buffer:
    ; Copy the tilemap words under a rectangle to a buffer.
    ; A = Rect width.
    ; B = Rect height.
    ; HL = Top left tile (address) of rectangle to copy.
    ; DE = Destination buffer.
    ; All registers are preserved.
    SAVE_REGISTERS
    add a,a                 ; Double width - the table elements are words.
    ld c,a                  ; Save width in C for counting.
    ; For each 'rect-height' do the following...
    --:
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_READ_COMMAND
      out (CONTROL_PORT),a
      push de
        ld de,ONE_TILEMAP_ROW
        add hl,de
      pop de
      push bc               ; Save rect width*2.
      ; For each 'rect-width*2' do the following...
        -:
          in a,(DATA_PORT)  ; Get byte from tilemap.
          ld (de),a         ; Store it in the buffer.
          inc de            ; Update buffer pointer.
          dec c             ; Decrement 'for counter'.
          xor a             ; Do the rect-width*2 for-loop logic...
          cp c
        jp nz,-
      pop bc                ; Restore rect-width*2.
    djnz --                 ; The rect-height for-loop.
    RESTORE_REGISTERS
  ret
  ; ---------------------------------------------------------------------------
  copy_buffer_to_tilemap_rect:
    ; Reverse of copy_tilemap_rect_to_buffer.
    ; A = Rect width.
    ; B = Rect height.
    ; HL = Base address of buffer.
    ; DE = Address of top left tile of tilemap rectangle.
    ; Preserves all registers used.
    ; Time: 11 lines.
    SAVE_REGISTERS
    add a,a                 ; Double width - the table elements are words.
    ld c,a                  ; Save width in C for counting.
    ; For each 'rect-height' do the following...
    --:
      ld a,e
      out (CONTROL_PORT),a
      ld a,d
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      push hl
        ld hl,ONE_TILEMAP_ROW
        add hl,de
        ex de,hl
      pop hl
      push bc               ; Save rect width*2.
      ; For each 'rect-width*2' do the following...
        -:
          ld a,(hl)
          out (DATA_PORT),a
          inc hl
          dec c             ; Decrement 'for counter'.
          xor a             ; Do the rect-width*2 for-loop logic...
          cp c
        jp nz,-
      pop bc                ; Restore rect-width*2.
    djnz --                 ; The rect-height for-loop.
    RESTORE_REGISTERS
  ret
  ; ---------------------------------------------------------------------------
  blank_tilemap_rect:
    ; Write $0000 to the tilemap words under a rectangle.
    ; A = Rect width.
    ; B = Rect height.
    ; HL = Address of first tile to blank.
    add a,a                 ; Double width - the table elements are words.
    ld c,a                  ; Save width in C for counting.
    ; For each 'rect-height' do the following...
    --:
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      ld de,ONE_TILEMAP_ROW
      add hl,de
      ld a,$00
      push bc               ; Save rect width*2.
      ; For each 'rect-width*2' do the following...
        -:
          out (DATA_PORT),a
          dec c             ; Decrement 'for counter'.
          cp c              ; A is already $00 = blanked.
        jp nz,-
      pop bc                ; Restore rect-width*2.
    djnz --                 ; The rect-height for-loop.
  ret
.ends

; -----------------------------------------------------------------------------
.section "spritebank handling" free
; -----------------------------------------------------------------------------
  load_spritebank:
    ; Batchload tiles from a table into the spritebank.
    ; Spritebank table format (byte, word, word):
    ; i nnnn pppp
    ; i = index, n = number of bytes to load, p = pointer to tile data.
    ; Terminate table with byte END_OF_TABLE ($ff).
    ; HL = Pointer to spritebank table.
    ; Uses: AF, BC, DE, HL
    ; N.B.: Disable interrupts and display before calling this function!
    ld a,(hl)                   ; Get byte from the spritebank table.
    cp END_OF_TABLE             ; Is it the table terminator char?
    ret z                       ; Yes? - then return, else continue.
    ; Setup DE, BC and HL for a call to function load_vram.
    push hl                     ; Save pointer to spritebank table.
      ld hl,SPRITE_BANK_START   ; Load the address of tile at index 0 into HL.
      cp 0                      ; Is this the index specified in the table?
      jp z,+                    ; Yes? - skip dest. address calculation.
        ld de,32                ; Each tile in the bank is 32 bytes.
        ld b,a                  ; Repeat [index] times...
        -:
          add hl,de             ; Add the size of one tile.
        djnz -
      +:                        ; Now the destination address is in HL.
      ex de,hl                  ; So switch it over to DE.
    pop hl                      ; Retrieve pointer to spritebank table.
    inc hl                      ; Read number of bytes to load from table and
    ld c,(hl)                   ; store it in BC...
    inc hl
    ld b,(hl)
    inc hl
    push hl                     ; Save pointer to spritebank table.
      ld a,(hl)                 ; Read pointer to tile data from table and
      inc hl                    ; store it in HL...
      ld h,(hl)
      ld l,a
      call load_vram            ; Load the tiles into vram.
    pop hl                      ; Retrieve pointer to spritebank table.
    inc hl                      ; Forward it twice to point to next table
    inc hl                      ; element's index or the END_OF_TABLE marker.
    ;
  jp load_spritebank
.ends
