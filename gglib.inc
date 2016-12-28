; gglib_base.inc - GG project boilerplate and standard library.
; Latest revision: 2016-12-23 for project swabby_pro

; *****************************************************************************
;                              BASE LIBRARY
; *****************************************************************************
.equ ROMSIZE 128                      ; Make a 128k or 256k rom.
.equ INCLUDE_VDP_INTERRUPT_HANDLER    ; Comment out to exclude it.
.equ INCLUDE_PAUSE_BUTTON_HANDLER     ; Comment out to exclude it.

; -----------------------------------------------------------------------------
; HARDWARE DEFINITIONS
; -----------------------------------------------------------------------------
.equ NAME_TABLE_START $3800
.equ NAME_TABLE_SIZE 2*32*24          ; The whole 'effective area' (SMS/TV).

; The ribbon: The LCD display area + the 6x8 pixels to the left and right.
; This forms a wide 'ribbon' that is 32x18 tiles in size, going across the
; name table.
.equ RIBBON_START $38c0
.equ RIBBON_SIZE 32*18*2

.equ SAT_Y_START $3f00
.equ SAT_XC_START SAT_Y_START+64+64
.equ SPRITE_TERMINATOR $d0

.equ V_COUNTER_PORT $7e
.equ CONTROL_PORT $BF
.equ DATA_PORT $BE
.equ VRAM_WRITE_COMMAND %01000000
.equ VRAM_READ_COMMAND %00000000
.equ REGISTER_WRITE_COMMAND %10000000
.equ CRAM_WRITE_COMMAND %11000000

.equ SCROLL_0_LINE_0_SPRITES_0 %00000110
.equ DISPLAY_1_FRAME_1_SIZE_0 %11100000
.equ DISPLAY_0_FRAME_1_SIZE_0 %10100000
.equ DISPLAY_0_FRAME_0_SIZE_0 %10000000

.equ HORIZONTAL_SCROLL_REGISTER 8
.equ VERTICAL_SCROLL_REGISTER 9
.equ RASTER_INTERRUPT_REGISTER 10

.equ SLOT_2_CONTROL $ffff
.equ STACK_INIT_ADDRESS $dff0
.equ RAM_START $c000

.equ INPUT_PORT_1 $dc
.equ INPUT_PORT_2 $dd

.equ PAUSE_FLAG_RESET $00
.equ PAUSE_FLAG_SET $ff

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
.macro LOAD_RIBBON
; -----------------------------------------------------------------------------
  ; This macro makes it easy to load a ribbon. Call the macro like this:
  ; LOAD_RIBBON MockupAssets,MockupAssetsEnd
  ; Include format:
  ;    mockup_assets:
  ;      .include "mockup_assets.inc"
  ;    mockup_assets_end:
  ; Drop a 256x144 indexed color image on \Tools\bmp_2_ribbon.bat to quickly
  ; generate an include file formatted for this macro.
  ;
  ; Assume 16 colors (bmp2tile's -fullpalette option).
  ld a,0
  ld b,16
  ld hl,\1
  call load_cram
  ;.
  ld bc,RIBBON_SIZE
  ld de,RIBBON_START
  ld hl,\1+32
  call load_vram
  ; Amount of tiles can vary.
  ld bc,\2-(\1+32+RIBBON_SIZE)
  ld de,0
  ld hl,\1+32+RIBBON_SIZE
  call load_vram
.endm
; -----------------------------------------------------------------------------
.macro SAVE_REGISTERS
; -----------------------------------------------------------------------------
  push af
  push bc
  push de
  push hl
.endm
; -----------------------------------------------------------------------------
.macro RESTORE_REGISTERS
; -----------------------------------------------------------------------------
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
  VDPStatus db    ; Set by the VDP interrupt handler and AwaitFrameInterrupt.
  PauseFlag db    ; Toggled by the pause button interrupt handler.
  InputPorts dw
.ends

.org 0
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Boot" force
; -----------------------------------------------------------------------------
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
.section "GetInputPorts" free
; -----------------------------------------------------------------------------
  ; Set InputPorts (word) to mirror current state of ports $dc and $dd.
  ; Uses: AF
  GetInputPorts:
    in a,(INPUT_PORT_1)
    ld (InputPorts),a
    in a,(INPUT_PORT_2)
    ld (InputPorts+1),a
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
.section "IsPlayer1Button1Pressed" free
; -----------------------------------------------------------------------------
  IsPlayer1Button1Pressed:
    ld a,(InputPorts)
    and %00010000
    ret nz            ; Return with carry flag reset
    scf
  ret                 ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer1Button2Pressed" free
; -----------------------------------------------------------------------------
  IsPlayer1Button2Pressed:
    ld a,(InputPorts)
    and %00100000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer1DownPressed" free
; -----------------------------------------------------------------------------
  IsPlayer1DownPressed:
    ld a,(InputPorts)
    and %00000010
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer1LeftPressed" free
; -----------------------------------------------------------------------------
  IsPlayer1LeftPressed:
    ld a,(InputPorts)
    and %00000100
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer1RightPressed" free
; -----------------------------------------------------------------------------
  IsPlayer1RightPressed:
    ld a,(InputPorts)
    and %00001000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer1UpPressed" free
; -----------------------------------------------------------------------------
  IsPlayer1UpPressed:
    ld a,(InputPorts)
    and %00000001
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer2Button1Pressed" free
; -----------------------------------------------------------------------------
  IsPlayer2Button1Pressed:
    ld a,(InputPorts+1)
    and %00000100
    ret nz            ; Return with carry flag reset
    scf
  ret                 ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer2Button2Pressed" free
; -----------------------------------------------------------------------------
  IsPlayer2Button2Pressed:
    ld a,(InputPorts+1)
    and %00001000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer2DownPressed" free
; -----------------------------------------------------------------------------
  IsPlayer2DownPressed:
    ld a,(InputPorts)
    and %10000000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer2LeftPressed" free
; -----------------------------------------------------------------------------
  IsPlayer2LeftPressed:
    ld a,(InputPorts+1)
    and %00000001
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer2RightPressed" free
; -----------------------------------------------------------------------------
  IsPlayer2RightPressed:
    ld a,(InputPorts+1)
    and %00000010
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer2UpPressed" free
; -----------------------------------------------------------------------------
  IsPlayer2UpPressed:
    ld a,(InputPorts)
    and %01000000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsResetPressed" free
; -----------------------------------------------------------------------------
  IsResetPressed:
    ld a,(InputPorts+1)
    and %00010000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
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
.section "Set VDP Register" free
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