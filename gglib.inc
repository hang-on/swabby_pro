; gglib_base.inc - GG project boilerplate and standard library.
; Latest revision: Spring 2016/2017 for project swabby_pro.

; *****************************************************************************
;                              BASE LIBRARY
; *****************************************************************************
.equ ROMSIZE 128                      ; Make a 128k or 256k rom.
.equ INCLUDE_VDP_INTERRUPT_HANDLER    ; Comment out to exclude it.

; -----------------------------------------------------------------------------
; HARDWARE DEFINITIONS
; -----------------------------------------------------------------------------
; Video memory and initialization:
.equ NAME_TABLE_START $3800
.equ NAME_TABLE_SIZE 2*32*24          ; The whole 'effective area' (SMS/TV).
.equ SPRITE_BANK_START $2000
.equ BACKGROUND_BANK_START $0000
.equ SPRITE_PALETTE_START 16
.equ BACKGROUND_PALETTE_START 0
.equ SAT_Y_START $3f00
.equ SAT_XC_START SAT_Y_START+64+64
.equ SPRITE_TERMINATOR $d0

; Memory map and initialization:
.equ RAM_START $c000
.equ STACK_INIT_ADDRESS $dff0

; Port communication and control:
.equ SYSTEM_CONTROL_PORT $00          ; GG: start, region, ntsc/pal.
.equ START_BUTTON_BIT %10000000       ; 0 = Switch is on!
.equ INPUT_PORT_1 $dc
.equ INPUT_PORT_2 $dd
.equ PSG_PORT $7f
.equ V_COUNTER_PORT $7e
.equ CONTROL_PORT $BF
.equ DATA_PORT $BE
.equ VRAM_WRITE_COMMAND %01000000
.equ VRAM_READ_COMMAND %00000000
.equ REGISTER_WRITE_COMMAND %10000000
.equ CRAM_WRITE_COMMAND %11000000

; Register 0 settings:
.equ SCROLL_0_LINE_0_SPRITES_0 %00000110

; Register 1 settings:
.equ DISPLAY_1_FRAME_1_SIZE_0 %11100000
.equ DISPLAY_0_FRAME_1_SIZE_0 %10100000
.equ DISPLAY_0_FRAME_0_SIZE_0 %10000000
.equ DISPLAY_1_FRAME_1_SIZE_0_ZOOM %11100001

.equ HORIZONTAL_SCROLL_REGISTER 8
.equ VERTICAL_SCROLL_REGISTER 9
.equ RASTER_INTERRUPT_REGISTER 10

; Banks / ROM / External RAM control:
.equ SET_EXTRAM_BIT %00001000
.equ RESET_EXTRAM_BIT %11110111
.equ EXTRAM_START $8000
.equ EXTRAM_SIZE $4000
.equ SLOT_2_CONTROL $ffff
.equ BANK_CONTROL $fffc

; LCD screen values:
.equ LCD_RIGHT_BORDER (6*8)+(20*8)
.equ LCD_LEFT_BORDER 6*8
.equ LCD_TOP_BORDER 3*8
.equ LCD_BOTTOM_BORDER (3*8)+(18*8)
.equ LCD_WIDTH 20*8
.equ LCD_HEIGHT 18*8
; -----------------------------------------------------------------------------
; SOFTWARE DEFINITIONS
; -----------------------------------------------------------------------------
.equ TRUE $ff
.equ FALSE 0
.equ ENABLED $ff
.equ DISABLED 0

; =============================================================================
; M A C R O S
; =============================================================================
; -----------------------------------------------------------------------------
.macro SELECT_EXTRAM
; -----------------------------------------------------------------------------
  ; Select external RAM: Now memory addresses from $8000 - $c000 (slot 2)
  ; are mapped to the battery-backed RAM, and thus its contents are saved
  ; between sessions.
  push af
  ld a,(BANK_CONTROL)
  or SET_EXTRAM_BIT
  ld (BANK_CONTROL),a
  pop af
.endm
; -----------------------------------------------------------------------------
.macro SELECT_ROM
; -----------------------------------------------------------------------------
  ; Select ROM: Used to switch mapping in slot 2 ($8000 - $c000) back to ROM
  ; if external RAM was selected.
  push af
  ld a,(BANK_CONTROL)
  and RESET_EXTRAM_BIT
  ld (BANK_CONTROL),a
  pop af
.endm
; -----------------------------------------------------------------------------
.macro SELECT_BANK
; -----------------------------------------------------------------------------
  ; Select a bank for slot 2, i.e. SELECT_BANK 4.
  push af
  ld a,\1
  ld (SLOT_2_CONTROL),a
  pop af
.endm
; -----------------------------------------------------------------------------
.macro SAVE_REGISTERS
; -----------------------------------------------------------------------------
  ; Save all registers, except IX and IY
  push af
  push bc
  push de
  push hl
.endm
; -----------------------------------------------------------------------------
.macro RESTORE_REGISTERS
; -----------------------------------------------------------------------------
  ; Restore all registers, except IX and IY
  pop hl
  pop de
  pop bc
  pop af
.endm

; -----------------------------------------------------------------------------
.memorymap
; -----------------------------------------------------------------------------
  defaultslot 0
  slotsize $4000
  slot 0 $0000
  slot 1 $4000
  slot 2 $8000
  slotsize $2000
  slot 3 RAM_START
.endme
.if ROMSIZE == 128
  .rombankmap ; 128K rom
    bankstotal 8
    banksize $4000
    banks 8
  .endro
.endif
.if ROMSIZE == 256
  .rombankmap ; 256K rom
    bankstotal 16
    banksize $4000
    banks 16
  .endro
.endif

; -----------------------------------------------------------------------------
.ramsection "Global Variables" slot 3
; -----------------------------------------------------------------------------
  VDPStatus db
  input_ports dw
  rnd_generator_word dw   ; Used by the random number generator.
.ends

.org 0
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Boot" force
; -----------------------------------------------------------------------------
  boot:
  di
  im 1
  ld sp,STACK_INIT_ADDRESS

  ; Initialize the standard Sega mapper.
  ld de,$fffc
  ld hl,_MapperInitData
  ld bc,$0004
  ldir

  call ClearRam ; Except the top (stack, slot/bank registers, etc.)
  call ClearVRam
  call InitializeVDPRegisters
  jp init

  _MapperInitData:
    .db $00,$00,$01,$02
.ends

.ifdef INCLUDE_VDP_INTERRUPT_HANDLER
  .org $0038
  ; ---------------------------------------------------------------------------
  .section "!VDP interrupt" force
  ; ---------------------------------------------------------------------------
    push af
      in a,CONTROL_PORT
      ld (VDPStatus),a
    pop af
    ei
    reti
  .ends
.endif

.ifdef INCLUDE_PAUSE_BUTTON_HANDLER
  .org $0066
  ; ---------------------------------------------------------------------------
  .section "!Pause interrupt" force
  ; ---------------------------------------------------------------------------
    push af
      ld a,(PauseFlag)
      cpl
      ld (PauseFlag),a
    pop af
    retn
  .ends
.endif


; =============================================================================
; H E L P E R  F U N C T I O N S                        (sorted alphabetically)
; =============================================================================

; -----------------------------------------------------------------------------
.section "await_frame_interrupt" free
; -----------------------------------------------------------------------------
  ; Await frame interrupt.
  ; Repeatedly test bit 7 of VDPStatus until it is set (by the VDP interrupt
  ; handler). Then reset this bit and return.
  ; Entry: None
  ; Exit: Bit 7 of variable VDPStatus is cleared.
  ; Uses: VDPStatus (1 byte)
  await_frame_interrupt:
    push af
      -:
        ld a,(VDPStatus)
        bit 7,a
      jp z,-
      res 7,a
      ld (VDPStatus),a
    pop af
  ret
.ends

; -----------------------------------------------------------------------------
.section "clear_extram" free
; -----------------------------------------------------------------------------
  ; Clear external ram by writing zeroes to all bytes.
  ; Uses AF, BC, HL
  clear_extram:
    SELECT_EXTRAM
    ld bc,EXTRAM_SIZE               ; Every byte in external ram.
    ld hl,EXTRAM_START              ; Begin from the first byte.
    -:
      xor a                         ; Write zeroes over all external ram bytes.
      ld (hl),a
      inc hl
      dec bc
      ld a,b
      or c
    jp nz,-
    SELECT_ROM
  ret
.ends

; -----------------------------------------------------------------------------
.section "ClearRam" free
; -----------------------------------------------------------------------------
  ; Overwrite ram with zeroes from RAM_START to STACK_INIT_ADDRESS - 16
  ; Uses AF, BC, DE, HL
  ClearRam:
    ld hl,RAM_START
    ld bc,STACK_INIT_ADDRESS-16-RAM_START
    ld a,0
    call _FillMemory
  ret

  _FillMemory:
    ld (hl),a
    ld d,h
    ld e,l
    inc de
    dec bc
    ld a,b
    or c
    ret z
    ldir
  ret
.ends

; -----------------------------------------------------------------------------
.section "ClearVRam" free
; -----------------------------------------------------------------------------
  ; Write 00 to all vram positions. Assumes disabled display.
  ; Uses AF, BC
  ClearVRam:
    xor a
    out (CONTROL_PORT),a
    or VRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
    ld bc,$4000 ; 16K
    -:
      xor a
      out (DATA_PORT),a
      dec bc
      ld a,b
      or c
    jp nz,-
  ret
.ends

; -----------------------------------------------------------------------------
.section "cp_word" free
; -----------------------------------------------------------------------------
  cp_word:
    ; Compare a word-sized variable at HL to a word-sized value in DE.
    ; Entry: HL = Pointer to variable.
    ;        BC = Value to compare.
    ; Exit: Zero flag is set/reset.
    ;
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    sbc hl,bc
  ret
.ends

; -----------------------------------------------------------------------------
.section "dec_table_item" free
; -----------------------------------------------------------------------------
  dec_table_item:
    ; Decrement a byte-sized table item.
    ; Entry: A = index, HL = Pointer to table.
    ; Exit: None.
    ; Preserves all registers.
    push de
    push hl
    ld d,0
    ld e,a
    add hl,de
    dec (hl)
    pop hl
    pop de
  ret
.ends

; -----------------------------------------------------------------------------
.section "get_input_ports" free
; -----------------------------------------------------------------------------
  ; Set input_ports (word) to mirror current state of ports $dc and $dd.
  ; Uses: AF
  get_input_ports:
    in a,(INPUT_PORT_1)
    ld (input_ports),a
    in a,(INPUT_PORT_2)
    ld (input_ports+1),a
  ret
.ends

; -----------------------------------------------------------------------------
.section "get_random_number" free
; -----------------------------------------------------------------------------
  get_random_number:
    ; Uses a 16-bit RAM variable called rnd_generator_word
    ; Returns an 8-bit pseudo-random number in A
    push hl
      ld hl,(rnd_generator_word)
      ld a,h         ; get high byte
      rrca           ; rotate right by 2
      rrca
      xor h          ; xor with original
      rrca           ; rotate right by 1
      xor l          ; xor with low byte
      rrca           ; rotate right by 4
      rrca
      rrca
      rrca
      xor l          ; xor again
      rra            ; rotate right by 1 through carry
      adc hl,hl      ; add rnd_generator_word to itself
      jr nz,+
        ld hl,$733c   ; if last xor resulted in zero then re-seed.
      +:
      ld a,r         ; r = refresh register = semi-random number
      xor l          ; xor with l which is fairly random
      ld (rnd_generator_word),hl
    pop hl
  ret                ; return random number in a
.ends

; -----------------------------------------------------------------------------
.section "get_table_item" free
; -----------------------------------------------------------------------------
  get_table_item:
    ; Gets the byte at index [in A] in table [pointer in HL].
    ; Entry: A = Index, HL = Poiner to table
    ; Exit: Byte in A.
    ; Preserves all registers.
    push de
    push hl
    ld d,0
    ld e,a
    add hl,de
    ld a,(hl)
    pop hl
    pop de
  ret
.ends

; -----------------------------------------------------------------------------
.section "Get Word" free
; -----------------------------------------------------------------------------
  get_word:
    ; Load word-sized variable into HL.
    ; Entry: HL = Pointer to variable address.
    ; Exit: HL = Value of the variable.
    ; Preserves all registers.
    push af
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    pop af
  ret
.ends

; -----------------------------------------------------------------------------
.section "Increment Word" free
; -----------------------------------------------------------------------------
  inc_word:
    ; Increments a word-sized variable at HL.
    ; Entry: HL = Pointer to variable.
    ; Exit: None
    ; Preserves all registers.
    push af
    push hl
    ld a,(hl)
    inc a
    ld (hl),a
    jp nz,+
      inc hl
      inc (hl)
    +:
    pop hl
    pop af
  ret
.ends

; -----------------------------------------------------------------------------
.section "inc_table_item" free
; -----------------------------------------------------------------------------
  inc_table_item:
    ; Increments a byte-sized table item.
    ; Entry: A = index, HL = Pointer to table.
    ; Exit: None.
    ; Preserves all registers.
    push de
    push hl
    ld d,0
    ld e,a
    add hl,de
    inc (hl)
    pop hl
    pop de
  ret
.ends

; -----------------------------------------------------------------------------
.section "InitializeVDPRegisters" free
; -----------------------------------------------------------------------------
; Initialize the 11 VDP registers with the preset data block.
; Uses: AF, B, HL
  _VDPRegisterInitData:
    .db SCROLL_0_LINE_0_SPRITES_0
    .db DISPLAY_0_FRAME_0_SIZE_0
    .db $ff,$ff,$ff,$ff,$ff,$00,$00,$00,$ff

  InitializeVDPRegisters:
    ld hl,_VDPRegisterInitData
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
.ends

; -----------------------------------------------------------------------------
.section "is_dpad_pressed" free
; -----------------------------------------------------------------------------
  is_dpad_pressed:
    ld a,(input_ports)
    and %00001111   ; Isolate the dpad bits.
    cpl             ; Invert bits; now 1 = keypress!
    and %00001111   ; Get rid of garbage from cpl in last four bits.
    cp 0            ; Now, is any dpad key preseed?
    ret z           ; No, then return with carry flag reset (by the AND).
    scf             ; Yes, then set carry flag and...
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "is_button_1_pressed" free
; -----------------------------------------------------------------------------
  is_button_1_pressed:
    ld a,(input_ports)
    and %00010000
    ret nz            ; Return with carry flag reset
    scf
  ret                 ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "is_button_2_pressed" free
; -----------------------------------------------------------------------------
  is_button_2_pressed:
    ld a,(input_ports)
    and %00100000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends
; -----------------------------------------------------------------------------
.section "is_down_pressed" free
; -----------------------------------------------------------------------------
  is_down_pressed:
    ld a,(input_ports)
    and %00000010
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "is_left_pressed" free
; -----------------------------------------------------------------------------
  is_left_pressed:
    ld a,(input_ports)
    and %00000100
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "is_right_pressed" free
; -----------------------------------------------------------------------------
  is_right_pressed:
    ld a,(input_ports)
    and %00001000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "is_up_pressed" free
; -----------------------------------------------------------------------------
  is_up_pressed:
    ld a,(input_ports)
    and %00000001
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends


; -----------------------------------------------------------------------------
.section "is_start_pressed" free
; -----------------------------------------------------------------------------
  is_start_pressed:
    in a,(SYSTEM_CONTROL_PORT)
    and START_BUTTON_BIT
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "kill_psg" free
; -----------------------------------------------------------------------------
  ; Manually silence all sound.
  ; Entry: None.
  ; Saves registers used.
  kill_psg:
    push af
    ld a,$9f
    out (PSG_PORT),a
    ld a,$bf
    out (PSG_PORT),a
    ld a,$df
    out (PSG_PORT),a
    pop af
  ret
.ends

; -----------------------------------------------------------------------------
.section "load_cram" free
; -----------------------------------------------------------------------------
  ; Load a number of colors into color ram (SMS - not GG!).
  ; Entry: A = Palette index (0-31)
  ;        B = Number of colors to load
  ;        HL = Base address of source data (color words, GG)
  ; Uses: AF, BC, HL
  ; Assumes blanked display and interrupts off.
  load_cram:
    sla a
    out (CONTROL_PORT),a
    ld a,CRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
    -:
      ld a,(hl)
      out (DATA_PORT),a
      inc hl
      ld a,(hl)
      out (DATA_PORT),a
      inc hl
    djnz -
  ret
.ends

; -----------------------------------------------------------------------------
.section "load_vdp_registers" free
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
.section "load_vram" free
; -----------------------------------------------------------------------------
  ; Load a number of bytes from a source address into vram.
  ; Entry: BC = Number of bytes to load
  ;        DE = Destination address in vram
  ;        HL = Source address
  ; Exit:  DE = Next free byte in vram.
  ; Uses: AF, BC, DE, HL,
  load_vram:
    ld a,e
    out (CONTROL_PORT),a
    ld a,d
    or VRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
    -:
      ld a,(hl)
      out (DATA_PORT),a
      inc hl
      dec bc
      ld a,c
      or b
    jp nz,-
  ret
.ends

; -----------------------------------------------------------------------------
.section "ReadVRam" free
; -----------------------------------------------------------------------------
  ; Read a number of bytes from vram into a buffer.
  ; Entry: BC = Number of bytes to read
  ;        DE = Destination address in ram (buffer)
  ;        HL = Source address in vram
  ; Uses: AF, BC, DE, HL,
  ReadVRam:
    ld a,l
    out (CONTROL_PORT),a
    ld a,h
    or VRAM_READ_COMMAND
    out (CONTROL_PORT),a
    -:
      in a,(DATA_PORT)
      ld (de),a
      inc de
      dec bc
      ld a,c
      or b
    jp nz,-
  ret
.ends

; -----------------------------------------------------------------------------
.section "Set register (vdp)" free
; -----------------------------------------------------------------------------
  ; Write to target register.
  ; Entry: A = byte to be loaded into vdp register.
  ;        B = target register 0-10.
  ; Uses: AF, B
  set_register:
    out (CONTROL_PORT),a
    ld a,REGISTER_WRITE_COMMAND
    or b
    out (CONTROL_PORT),a
  ret
.ends

; -----------------------------------------------------------------------------
.section "set_table_item" free
; -----------------------------------------------------------------------------
  set_table_item:
    ; Set a byte at index [in A] in table [pointer in HL].
    ; Entry: A = Index, B = value, HL = Poiner to table
    ; Exit: None
    ; Preserves all registers.
    push de
    push hl
    ld d,0
    ld e,a
    add hl,de
    ld (hl),b
    pop hl
    pop de
  ret
.ends

; -----------------------------------------------------------------------------
; Legacy code (for SMS).

; .equ INCLUDE_PAUSE_BUTTON_HANDLER     ; Comment out to exclude it.
; .equ PAUSE_FLAG_RESET $00
; .equ PAUSE_FLAG_SET $ff
