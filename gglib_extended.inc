; gglib_extended.inc - updated winter 2016/2017
;
;
.equ ONE_TILEMAP_ROW 32*2
.equ END_OF_TABLE $ff
.equ ASCII_ZERO 16        ; Where in the tilebank is the ASCII zero?

; -----------------------------------------------------------------------------
.ramsection "gglib_extended_vars" slot 3
; -----------------------------------------------------------------------------
  cursor_y db
  cursor_x db
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
;
; -----------------------------------------------------------------------------
.section "Printing" free
; -----------------------------------------------------------------------------
  print:
    ; Print a string to the name table. Terminate with # (ascii).
    ; N.B. Make sure that this function is not interrupted!
    ; Entry:
    ;        B = row, C = column.
    ;        HL = Pointer to string.
    ; Uses: AF, BC, DE, HL
    push hl                       ; Save pointer and string length for later.
    ld hl,NAME_TABLE_START        ; Get ready to calculate destination address.
    ld a,b
    cp 0
    jp z,add_row_offset_end
      ld de,$40                   ; For each row, add $40 to the dest. address.
      -:
        add hl,de
      djnz -
    add_row_offset_end:
    ld a,c
    cp 0
    jp z,add_column_offset_end
      ld b,a
      ld de,2                     ; Each column adds 1 word to dest. address.
      -:
        add hl,de
      djnz -
    add_column_offset_end:
    ld a,l                        ; Setup vram to load bytes at dest. address.
    out (CONTROL_PORT),a
    ld a,h
    or VRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
    ;
    pop hl                          ; Get pointer to string from stack.
    -:
      ld a,(hl)                     ; Get character from string.
      cp STRING_TERMINATOR
      ret z
      out (DATA_PORT),a             ; Write it to name table.
      ld a,%00001000                ; Select sprite palette for this char.
      out (DATA_PORT),a             ; Write 2nd byte to name table.
      inc hl                        ; Point to next char.
    djnz -
  ret

  set_cursor:
    ; Set cursor used by put_char.
    ; Entry: A = cursor_y / row, B = cursor_x / column.
    ld (cursor_y),a
    ld a,b
    ld (cursor_x),a
  ret

  put_char:
    ; Put char at cursor y,x and move cursor right.
    ; N.B. Make sure that this function is not interrupted!
    ; Entry: A = tile number (0-255 - in tile bank 1).
    ; Uses: A, B and C, but saves the rest.
    SAVE_REGISTERS
    push af                       ;
    ld hl,NAME_TABLE_START        ; Get ready to calculate destination address.
    ld a,(cursor_y)
    ld b,a
    cp 0
    jp z,+
      ld de,$40                   ; For each row, add $40 to the dest. address.
      -:
        add hl,de
      djnz -
    +:
    ld a,(cursor_x)
    cp 0
    jp z,+
      ld b,a
      ld de,2                     ; Each column adds 1 word to dest. address.
      -:
        add hl,de
      djnz -
    +:
    inc a
    ld (cursor_x),a               ; Inc cursor x position.
    ld a,l                        ; Setup vram to load bytes at dest. address.
    out (CONTROL_PORT),a
    ld a,h
    or VRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
    ;
    pop af                        ; Get tile.
    out (DATA_PORT),a             ; Write it to name table.
    ld a,%00001000                ; Select sprite palette for this char.
    out (DATA_PORT),a             ; Write 2nd byte to name table.
  RESTORE_REGISTERS
  ret

  print_register_hl:
    ; Print the contents of register HL as 5 ascii digits using put_char at
    ; position cursor (y,x).
    ; Entry: HL = value to print.
    ; Uses AF, BC, HL
  	ld	bc,-10000
  	call	+
  	ld	bc,-1000
  	call	+
    ld	bc,-100
  	call	+
  	ld	c,-10
  	call +
  	ld	c,-1
    +:
      ld	a,ASCII_ZERO-1 ; Maybe 16 here?
      -:
        inc	a
  	    add	hl,bc
  	  jr	c,-
  	sbc	hl,bc
  	call put_char
  ret

  print_register_a:
    ; Print the contents of register A as 3 ascii digits using put_char at
    ; position cursor (y,x).
    ; Entry: A = value to print.
    ; Uses AF, BC, HL
    ld h,0
    ld l,a
    ld	bc,-100
  	call	+
  	ld	c,-10
  	call +
  	ld	c,-1
    +:
      ld	a,ASCII_ZERO-1 ;
      -:
        inc	a
  	    add	hl,bc
  	  jr	c,-
  	sbc	hl,bc
  	call put_char
  ret
.ends
