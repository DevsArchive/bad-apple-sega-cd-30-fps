
; -------------------------------------------------------------------------
;
;	Sega CD Base
;		By Ralakimus 2021
;
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; Send a command to the Sub CPU
; -------------------------------------------------------------------------
; PARAMETERS
;	d0.b	- Command ID
;	d1.b	- Wait flag
; -------------------------------------------------------------------------

SubCPUCmd:
	btst	#2,GA_MEM_MODE+1		; Are we in 1M/1M mode?
	bne.s	.NoSend				; If so, branch

.SendWordRAM:
	bset	#1,GA_MEM_MODE+1		; Give Word RAM access to the Sub CPU
	beq.s	.SendWordRAM

.NoSend:
	move.b	d0,GA_MAIN_FLAG			; Set command

.WaitSub:
	cmpi.b	#"B",GA_SUB_FLAG		; Did the Sub CPU get it?
	bne.s	.WaitSub			; If so, branch

	clr.b	GA_MAIN_FLAG			; Reset command
	rts

; -------------------------------------------------------------------------
; Wait for a Sub CPU command to finish
; -------------------------------------------------------------------------

SubCPUCmd_Wait:
	cmpi.b	#"R",GA_SUB_FLAG		; Is the Sub CPU finished?
	bne.s	SubCPUCmd_Wait			; If not, branch
	rts

; -------------------------------------------------------------------------
; Play CDDA music
; -------------------------------------------------------------------------
; PARAMETERS:
;	d0.w	- Track ID
; -------------------------------------------------------------------------

PlayCDDA:
	move.w	d0,GA_CMD_0
	moveq	#1,d0
	bsr.w	SubCPUCmd
	bra.w	SubCPUCmd_Wait

; -------------------------------------------------------------------------
; Loop CDDA music
; -------------------------------------------------------------------------
; PARAMETERS:
;	d0.w	- Track ID
; -------------------------------------------------------------------------

LoopCDDA:
	move.w	d0,GA_CMD_0
	moveq	#2,d0
	bsr.w	SubCPUCmd
	bra.w	SubCPUCmd_Wait

; -------------------------------------------------------------------------
; Read sectors
; -------------------------------------------------------------------------
; PARAMETERS:
;	d0.w	- Starting sector
;	d1.w	- Sector count
;	a0.l	- Destination buffer
; -------------------------------------------------------------------------

ReadSectors:
	move.w	d0,GA_CMD_0			; Read sectors
	move.w	d1,GA_CMD_2
	move.l	a0,GA_CMD_4
	moveq	#3,d0
	bra.w	SubCPUCmd

; -------------------------------------------------------------------------
; Read next sectors
; -------------------------------------------------------------------------
; PARAMETERS:
;	d0.w	- Sector count
;	a0.l	- Destination buffer
; -------------------------------------------------------------------------

ReadNextSectors:
	move.w	d0,GA_CMD_0			; Read next sectors
	move.l	a0,GA_CMD_2
	moveq	#4,d0
	bra.w	SubCPUCmd

; -------------------------------------------------------------------------
; Get file sector
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l	- File name
; RETURNS:
;	d0.l	- File sector (-1 if not found)
; -------------------------------------------------------------------------

GetFileSector:
	move.l	(a0)+,GA_CMD_0			; Find file sector
	move.l	(a0)+,GA_CMD_4
	move.l	(a0),GA_CMD_8
	moveq	#5,d0
	bsr.w	SubCPUCmd
	bsr.w	SubCPUCmd_Wait

	move.l	GA_STAT_0,d0			; Return found file sector
	rts

; -------------------------------------------------------------------------
; Load file
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l	- File name
;	a1.l	- Destination buffer
; -------------------------------------------------------------------------

LoadFile:
	move.l	(a0)+,GA_CMD_0			; Load file
	move.l	(a0)+,GA_CMD_4
	move.l	(a0),GA_CMD_8
	move.l	a1,GA_CMD_C
	moveq	#6,d0
	bra.w	SubCPUCmd

; -------------------------------------------------------------------------
; Set Word RAM mode
; -------------------------------------------------------------------------
; PARAMETERS:
;	d0.w	- 0 = 2M, 1 = 1M/1M
; -------------------------------------------------------------------------

SetWordRAMMode:
	move.w	d0,GA_CMD_0			; Set Word RAM mode
	moveq	#7,d0
	bsr.w	SubCPUCmd
	bra.w	SubCPUCmd_Wait

; -------------------------------------------------------------------------
; Swap Word RAM banks
; -------------------------------------------------------------------------

SwapWordRAMBanks:
	moveq	#8,d0				; Swap Word RAM banks
	bsr.w	SubCPUCmd
	bra.w	SubCPUCmd_Wait

; -------------------------------------------------------------------------
; Run Sub CPU module
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l	- File name
;	a1.l	- Destination buffer
; -------------------------------------------------------------------------

RunSubCPUModule:
	moveq	#9,d0				; Run Sub CPU module
	bra.w	SubCPUCmd

; -------------------------------------------------------------------------
; Stop CDDA music
; -------------------------------------------------------------------------

StopCDDA:
	moveq	#$A,d0
	bsr.w	SubCPUCmd
	bra.w	SubCPUCmd_Wait

; -------------------------------------------------------------------------
; VSync
; -------------------------------------------------------------------------

VSync:
	move.w	d0,-(sp)
	
	move	#$2000,sr			; Enable interrupts
	move.w	frame_count.w,d0		; Get frame count

.Wait:
	cmp.w	frame_count.w,d0		; Did it change?
	beq.s	.Wait				; If not, wait
	
	move.w	(sp)+,d0
	rts

; -------------------------------------------------------------------------
; Fade the palette to black
; -------------------------------------------------------------------------

FadeToBlack:
	move.w	#$003F,fade_info.w		; Set to fade everything

FadeToBlack_Range:
	moveq	#7,d4				; Set repeat times
		
.FadeLoop:
	bsr.w	VSync				; VSync
	bsr.w	VSync
	bsr.s	FadeToBlack_Once		; Fade the colors once
	dbf	d4,.FadeLoop			; Loop until we are done
	rts

; -------------------------------------------------------------------------

FadeToBlack_Once:
	moveq	#0,d0
	lea	palette.w,a0			; Palette buffer
	move.b	fade_start.w,d0			; Add starting index offset
	adda.w	d0,a0
	move.b	fade_length.w,d0		; Get fade size

.FadeLoop:
	bsr.s	.FadeColor			; Fade a color			
	dbf	d0,.FadeLoop			; Loop
	rts

.FadeColor:
	move.w	(a0),d5				; Load color
	beq.s	.NoRed				; If the color is already black, branch
	move.w	d5,d1				; Copy color
	move.b	d1,d2				; Load green and red
	move.b	d1,d3				; Load only red

	andi.w	#$E00,d1			; Get only blue
	beq.s	.NoBlue				; If blue is finished, branch
	subi.w	#$200,d5			; Decrease blue

.NoBlue:
	andi.b	#$E0,d2				; Get only green
	beq.s	.NoGreen			; If green is finished, branch
	subi.w	#$20,d5				; Decrease green

.NoGreen:
	andi.b	#$E,d3				; Get only red
	beq.s	.NoRed				; If red is finished, branch
	subq.w	#2,d5				; Decrease red

.NoRed:
	move.w	d5,(a0)+			; Save the color
	rts

; -------------------------------------------------------------------------
; Fade the palette from black to the target palette
; -------------------------------------------------------------------------

FadeFromBlack:
	move.w	#$003F,fade_info.w		; Set to fade everything

FadeFromBlack_Range:
	moveq	#$E,d4				; Maximum color check

.FadeLoop:
	bsr.w	VSync				; VSync
	bsr.w	VSync
	bsr.s	FadeFromBlack_Once		; Fade the colors once
	subq.b	#2,d4				; Decrement color check
	bne.s	.FadeLoop			; If we are not done, branch
	bra.w	VSync				; Do VSync so that the colors transfer

; -------------------------------------------------------------------------

FadeFromBlack_Once:
	moveq	#0,d0
	lea	palette.w,a0			; Palette buffer
	lea	fade_palette.w,a1		; Target palette buffer
	move.b	fade_start.w,d0			; Add starting index offset
	adda.w	d0,a0
	adda.w	d0,a1
	move.b	fade_length.w,d0		; Get fade size

.FadeLoop:
	bsr.s	.FadeColor			; Fade a color			
	dbf	d0,.FadeLoop			; Loop
	rts

.FadeColor:
	move.b	(a1),d5				; Load blue
	move.w	(a1)+,d1			; Load green and red
	move.b	d1,d2				; Load red
	lsr.b	#4,d1				; Get only green
	andi.b	#$E,d2				; Get only red

	move.w	(a0),d3				; Load current color
	cmp.b	d5,d4				; Should the blue fade?
	bhi.s	.NoBlue				; If not, branch
	addi.w	#$200,d3			; Increase blue

.NoBlue:
	cmp.b	d1,d4				; Should the green fade?
	bhi.s	.NoGreen			; If not, branch
	addi.w	#$20,d3				; Increase green

.NoGreen:
	cmp.b	d2,d4				; Should the red fade?
	bhi.s	.NoRed				; If not, branch
	addq.w	#2,d3				; Increase red

.NoRed:
	move.w	d3,(a0)+			; Save the color
	rts

; -------------------------------------------------------------------------
; Fade the palette to white
; -------------------------------------------------------------------------

FadeToWhite:
	move.w	#$003F,fade_info.w		; Set to fade everything

FadeToWhite_Range:
	moveq	#7,d4				; Set repeat times
		
.FadeLoop:
	bsr.w	VSync				; VSync
	bsr.w	VSync
	bsr.s	FadeToWhite_Once		; Fade the colors once
	dbf	d4,.FadeLoop			; Loop until we are done
	rts

; -------------------------------------------------------------------------

FadeToWhite_Once:
	moveq	#0,d0
	lea	palette.w,a0			; Palette buffer
	move.b	fade_start.w,d0			; Add starting index offset
	adda.w	d0,a0
	move.b	fade_length.w,d0		; Get fade size

.FadeLoop:
	bsr.s	.FadeColor			; Fade a color			
	dbf	d0,.FadeLoop			; Loop
	rts

.FadeColor:
	move.w	(a0),d5				; Load color
	cmpi.w	#$EEE,d5
	beq.s	.NoRed				; If the color is already white, branch
	move.w	d5,d1				; Copy color
	move.b	d1,d2				; Load green and red
	move.b	d1,d3				; Load only red

	andi.w	#$E00,d1			; Get only blue
	cmpi.w	#$E00,d1			; Is blue finished?
	beq.s	.NoBlue				; If do, branch
	addi.w	#$200,d5			; Increase blue

.NoBlue:
	andi.b	#$E0,d2				; Get only green
	cmpi.b	#$E0,d2				; Is green finished?
	beq.s	.NoGreen			; If so, branch
	addi.w	#$20,d5				; Increase green

.NoGreen:
	andi.b	#$E,d3				; Get only red
	cmpi.b	#$E,d3				; Is red finished?
	beq.s	.NoRed				; If so, branch
	addq.w	#2,d5				; Increase red

.NoRed:
	move.w	d5,(a0)+			; Save the color
	rts

; -------------------------------------------------------------------------
; Fade the palette from white to the target palette
; -------------------------------------------------------------------------

FadeFromWhite:
	move.w	#$003F,fade_info.w		; Set to fade everything

FadeFromWhite_Range:
	moveq	#0,d4				; Minimum color check

.FadeLoop:
	bsr.w	VSync				; VSync
	bsr.w	VSync
	bsr.s	FadeFromWhite_Once		; Fade the colors once
	addq.b	#2,d4				; Decrement color check
	cmpi.w	#$E,d4				; Are we done?
	bne.s	.FadeLoop			; If we are not done, branch
	bra.w	VSync				; Do VSync so that the colors transfer

; -------------------------------------------------------------------------

FadeFromWhite_Once:
	moveq	#0,d0
	lea	palette.w,a0			; Palette buffer
	lea	fade_palette.w,a1		; Target palette buffer
	move.b	fade_start.w,d0			; Add starting index offset
	adda.w	d0,a0
	adda.w	d0,a1
	move.b	fade_length.w,d0		; Get fade size

.FadeLoop:
	bsr.s	.FadeColor			; Fade a color			
	dbf	d0,.FadeLoop			; Loop
	rts

.FadeColor:
	move.b	(a1),d5				; Load blue
	move.w	(a1)+,d1			; Load green and red
	move.b	d1,d2				; Load red
	lsr.b	#4,d1				; Get only green
	andi.b	#$E,d2				; Get only red

	move.w	(a0),d3				; Load current color
	cmp.b	d5,d4				; Should the blue fade?
	bcs.s	.NoBlue				; If not, branch
	subi.w	#$200,d3			; Increase blue

.NoBlue:
	cmp.b	d1,d4				; Should the green fade?
	bcs.s	.NoGreen			; If not, branch
	subi.w	#$20,d3				; Increase green

.NoGreen:
	cmp.b	d2,d4				; Should the red fade?
	bcs.s	.NoRed				; If not, branch
	subq.w	#2,d3				; Increase red

.NoRed:
	move.w	d3,(a0)+			; Save the color
	rts

; -------------------------------------------------------------------------
; Comper decompressor
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Source data
;	a1.l	- Destination buffer
; -------------------------------------------------------------------------
 
CompDec:
.NewBlock:
	move.w	(a0)+,d0			; Fetch description field
	moveq	#15,d3				; set bits counter to 16
 
.MainLoop
	add.w	d0,d0				; Roll description field
	bcs.s	.Flag				; If a flag issued, branch
	move.w	(a0)+,(a1)+			; Otherwise, do uncompressed data
	dbf	d3,.MainLoop			; If bits counter remains, parse the next word
	bra.s	.NewBlock			; Start a new block

; -------------------------------------------------------------------------

.Flag:
	moveq	#-1,d1				; Init displacement
	move.b	(a0)+,d1			; Load displacement
	add.w	d1,d1
	moveq	#0,d2				; Init copy count
	move.b	(a0)+,d2			; Load copy length
	beq.s	.End				; If zero, branch
	lea	(a1,d1),a2			; Load start copy address
 
.Loop:
	move.w	(a2)+,(a1)+			; Copy given sequence
	dbf	d2,.Loop			; Repeat
	dbf	d3,.MainLoop			; If bits counter remains, parse the next word
	bra.s	.NewBlock			; Start a new block
 
.End:
	rts

; -------------------------------------------------------------------------
; Clear the screen
; -------------------------------------------------------------------------

ClearScreen:
	move	#$2700,sr			; Disable interrupts

	z80Stop
	lea	VDP_CTRL,a0
	move.w	#$8F01,(a0)			; Set autoincrement to 1
	dmaFill	0,$8000,$8000,a0		; Clear planes, sprites, and HScroll
	move.w	#$8F02,(a0)			; Set autoincrement to 2
	z80Start

	lea	hscroll.w,a0			; Clear scroll RAM
	move.w	#(scroll_end-hscroll)/2-1,d0

.ClearScroll:
	clr.w	(a0)+
	dbf	d0,.ClearScroll
	rts

; -------------------------------------------------------------------------
; Vertical interrupt
; -------------------------------------------------------------------------

VInterrupt:
	move	#$2700,sr			; Disable interrupts
	pusha					; Push all registers
	
	z80Stop					; Stop Z80
	bsr.w	ReadControllers			; Read controllers

	lea	VDP_CTRL,a6			; VDP control
	dma68k	palette,0,$80,CRAM,a6		; Transfer palette data
	dma68k	hscroll,$FC00,$380,VRAM,a6	; Transfer HScroll data
	dma68k	vscroll,0,$50,VSRAM,a6		; Transfer VScroll data
	dma68k	sprites,$F800,$280,VRAM,a6	; Transfer sprites
	z80Start				; Start Z80
	
	addq.w	#1,frame_count.w		; Increment frame counter

	popa					; Pop all registers

IntBlank:
	rte

; -------------------------------------------------------------------------
; Read controller data
; -------------------------------------------------------------------------

ReadControllers:
	lea	p1_ctrl.w,a0			; Start with player 1
	lea	IO_A_DATA,a1
	bsr.s	.Read
	addq.w	#2,a1				; Then do player 2

.Read:
	move.b	#0,(a1)				; Start and A
	nop	
	nop	
	move.b	(a1),d0
	lsl.b	#2,d0
	andi.b	#$C0,d0

	move.b	#$40,(a1)			; D-pad, B, and C
	nop	
	nop	
	move.b	(a1),d1
	andi.b	#$3F,d1

	or.b	d1,d0				; Set up final controller data
	not.b	d0
	move.b	(a0),d1
	eor.b	d0,d1
	move.b	d0,(a0)+
	and.b	d0,d1
	move.b	d1,(a0)+
	rts	

; -------------------------------------------------------------------------