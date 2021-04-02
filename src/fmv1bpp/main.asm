
; -------------------------------------------------------------------------
;
;	Bad Apple Sega CD Demo
;		By Ralakimus 2021
;
; -------------------------------------------------------------------------

	include	"../include/maincpu.asm"
	include	"mainprg/libinc.asm"

; -------------------------------------------------------------------------
; FMV engine (Main CPU)
; -------------------------------------------------------------------------

	org	RAM_START+$2000

	lea	FMV_BadApple(pc),a3		; FMV data
	
	move.w	#$8134,VDP_CTRL			; Disable screen

	move	#$2700,sr			; Set up interrupts
	move.l	#FMV_VInt,_LEVEL6+2.w

	lea	FMV_SubModule(pc),a0		; Load FMV Sub CPU module
	lea	SUB_PRG_RAM+$20000,a1
	bsr.w	LoadFile
	bsr.w	SubCPUCmd_Wait
	bsr.w	RunSubCPUModule			; Run FMV Sub CPU module
	bsr.w	SubCPUCmd_Wait

	lea	VDP_CTRL,a0			; Clear VRAM
	move.w	#$8F01,(a0)
	dmaFill	0,0,$10000,a0
	move.w	#$8F02,(a0)

	lea	filename(pc),a1			; Load file name

.LoadFilename:
	move.b	(a3)+,d0
	beq.s	.GotFilename
	move.b	d0,(a1)+
	bra.s	.LoadFilename

.GotFilename:
	clr.b	(a1)+

	lea	filename(pc),a0			; Initialize FMV
	move.l	(a0)+,GA_CMD_0
	move.l	(a0)+,GA_CMD_4
	move.l	(a0),GA_CMD_8
	moveq	#0,d0
	move.b	(a3)+,d0
	bmi.w	.Exit
	move.w	d0,GA_CMD_C
	moveq	#1,d0
	bsr.w	SubCPUCmd
	bsr.w	SubCPUCmd_Wait

	tst.l	GA_STAT_0			; Was the file found?
	bmi.w	.Exit				; If not, branch

	lea	VDP_CTRL,a0			; Set up VDP registers
	move.w	#$8004,(a0)
	move.w	#$8200|($E000/$400),(a0)
	move.w	#$8400|($E000/$2000),(a0)
	move.w	#$8700,(a0)
	move.w	#$8B00,(a0)
	move.w	#$8C00,(a0)
	move.w	#$8D00|($FC00/$400),(a0)
	move.w	#$9001,(a0)

	move.l	#$00080008,vscroll.w		; Set VScroll

	move.l	#$60800003,d4			; Prepare tilemap
	moveq	#1,d0
	moveq	#2-1,d5

.LoadTileMap:
	moveq	#$20-1,d1
	moveq	#$1C-1,d2

.MapRow:
	move.l	d4,(a0)
	move.w	d1,d3

.MapTile:
	move.w	d0,-4(a0)
	addq.w	#1,d0
	dbf	d3,.MapTile
	addi.l	#$800000,d4
	dbf	d2,.MapRow

	move.l	#$60C00003,d4
	move.w	#$381,d0
	dbf	d5,.LoadTileMap

	clr.l	buffer_id			; Reset variables
	
	lea	WORDRAM_1M,a0			; Render first set of frames
	moveq	#14-1,d7
	bsr.w	FMV_RenderFrames
	move.w	#$8174,VDP_CTRL

; -------------------------------------------------------------------------

.MainLoop:
	moveq	#0,d0				; Read FMV data
	move.b	(a3)+,d0
	bpl.s	.NotDone

	st	fmv_done			; Mark as done
	moveq	#4,d0				; Fill last audio bank with silence
	bsr.w	SubCPUCmd
	bra.s	.PacketLoop

.NotDone:
	move.w	d0,GA_CMD_0
	moveq	#2,d0
	bsr.w	SubCPUCmd

.PacketLoop:
	cmpi.b	#1,fmv_done			; Are we quitting early?
	beq.s	.Exit				; If so, branch
	bsr.s	FMV_RenderFrames		; Render frames
	dbf	d7,.PacketLoop			; Loop until packet is done being processed

	bsr.w	SubCPUCmd_Wait			; Swap to next packet
	tst.b	fmv_done
	bne.s	.Exit				; Branch if we are done here
	moveq	#3,d0
	bsr.w	SubCPUCmd
	bsr.w	SubCPUCmd_Wait

	lea	WORDRAM_1M,a0			; Reset
	moveq	#15-1,d7

	bra.w	.MainLoop			; Loop until FMV is done

; -------------------------------------------------------------------------

.Exit:
	bsr.w	SubCPUCmd_Wait			; Wait for any Sub CPU processes to be finished
	
	move	#$2700,sr			; Set V-INT
	move.l	#VInterrupt,_LEVEL6+2.w

	lea	palette.w,a0			; Clear palette
	move.w	#$80/4-1,d0

.ClearPal:
	clr.l	(a0)+
	dbf	d0,.ClearPal
	jsr	VSync
	move	#$2700,sr

	moveq	#-1,d0				; Set to exit out of Sub CPU FMV module
	bsr.w	SubCPUCmd
	bsr.w	SubCPUCmd_Wait

	moveq	#0,d0				; Go back to 2M mode
	bra.w	SetWordRAMMode

; -------------------------------------------------------------------------
; Render a set of frames
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Pointer to FMV data
; -------------------------------------------------------------------------

FMV_RenderFrames:
	clr.b	frame				; Set to frame 0
	move	#$2000,sr			; Enable interrupts
	
	lea	art_buffer(pc),a1		; Decompress art
	bsr.w	CompDec

.Wait:
	cmpi.b	#1,fmv_done			; Are we quitting?
	beq.s	.Exit				; If so, branch

	cmpi.b	#8,frame			; Wait until the frames are done being displayed
	bcs.s	.Wait

	not.b	buffer_id			; Swap buffers

.Exit:
	rts

; -------------------------------------------------------------------------
; Vertical interrupt
; -------------------------------------------------------------------------

FMV_VInt:
	move	#$2700,sr			; Disable interrupts
	pusha					; Push all registers

	cmpi.b	#8,frame			; Are we done animation these frames?
	bcc.w	.NoAnimate			; If so, branch

	move.l	#$01000100,hscroll.w		; Set HScroll
	tst.b	buffer_id
	beq.s	.StartDMA
	clr.l	hscroll.w

.StartDMA:
	moveq	#0,d0				; DMA art
	move.b	frame,d0
	lsl.w	#4,d0
	lea	.DMAQueue(pc),a0
	lea	(a0,d0.w),a0

	z80Stop
	move.l	(a0)+,VDP_CTRL
	move.w	(a0)+,VDP_CTRL
	move.l	#$94079300,VDP_CTRL
	tst.b	buffer_id
	beq.s	.DoDMA
	addq.l	#4,a0

.DoDMA:
	move.w	(a0)+,VDP_CTRL
	move.w	(a0)+,-(sp)
	move.w	(sp)+,VDP_CTRL
	z80Start

	lea	FMV_PalFrames(pc),a1		; Update palette
	moveq	#0,d0
	move.b	frame,d0
	andi.w	#$FFFE,d0
	lsl.w	#3,d0
	adda.w	d0,a1

	lea	palette.w,a2
	move.w	#$20/2-1,d0

.Loop:
	moveq	#0,d2
	move.b	(a1)+,d1
	bne.s	.SetColor
	move.w	#$EEE,d2

.SetColor:
	move.w	d2,(a2)+
	dbf	d0,.Loop

	addq.b	#1,frame

.NoAnimate:
	move.l	#$40000010,VDP_CTRL		; Standard updates
	move.l	vscroll.w,VDP_DATA

	move.l	#$7C000003,VDP_CTRL
	move.l	hscroll.w,VDP_DATA
	
	z80Stop					; Standard updates
	jsr	ReadControllers
	dma68k	palette,0,$20,CRAM
	z80Start
	
	;tst.b	p1_press.w			; Was the start button pressed?
	;bpl.s	.NoExit				; If not, branch
	;move.b	#1,fmv_done			; Mark as quitting

.NoExit:
	addq.w	#1,frame_count.w		; Increment frame count
	popa					; Pop all registers
	rte

; -------------------------------------------------------------------------

.DMAQueue:
	dc.l	$97009600|((((art_buffer)>>17)&$FF)<<16)|(((art_buffer)>>9)&$FF)
	dc.w	$9500|((((art_buffer)>>1)&$FF))
	dc.l	$40200080, $70200081
	dc.w	0

	dc.l	$97009600|((((art_buffer+$E00)>>17)&$FF)<<16)|(((art_buffer+$E00)>>9)&$FF)
	dc.w	$9500|((((art_buffer+$E00)>>1)&$FF))
	dc.l	$4E200080, $7E200081
	dc.w	0

	dc.l	$97009600|((((art_buffer+$1C00)>>17)&$FF)<<16)|(((art_buffer+$1C00)>>9)&$FF)
	dc.w	$9500|((((art_buffer+$1C00)>>1)&$FF))
	dc.l	$5C200080, $4C200082
	dc.w	0

	dc.l	$97009600|((((art_buffer+$2A00)>>17)&$FF)<<16)|(((art_buffer+$2A00)>>9)&$FF)
	dc.w	$9500|((((art_buffer+$2A00)>>1)&$FF))
	dc.l	$6A200080, $5A200082
	dc.w	0

	dc.l	$97009600|((((art_buffer+$3800)>>17)&$FF)<<16)|(((art_buffer+$3800)>>9)&$FF)
	dc.w	$9500|((((art_buffer+$3800)>>1)&$FF))
	dc.l	$78200080, $68200082
	dc.w	0

	dc.l	$97009600|((((art_buffer+$4600)>>17)&$FF)<<16)|(((art_buffer+$4600)>>9)&$FF)
	dc.w	$9500|((((art_buffer+$4600)>>1)&$FF))
	dc.l	$46200081, $76200082
	dc.w	0

	dc.l	$97009600|((((art_buffer+$5400)>>17)&$FF)<<16)|(((art_buffer+$5400)>>9)&$FF)
	dc.w	$9500|((((art_buffer+$5400)>>1)&$FF))
	dc.l	$54200081, $44200083
	dc.w	0

	dc.l	$97009600|((((art_buffer+$6200)>>17)&$FF)<<16)|(((art_buffer+$6200)>>9)&$FF)
	dc.w	$9500|((((art_buffer+$6200)>>1)&$FF))
	dc.l	$62200081, $52200083
	dc.w	0

; -------------------------------------------------------------------------
; Data
; -------------------------------------------------------------------------

FMV_BadApple:
	incbin	"fmv1bpp/data/badapple.dat"
	even

FMV_PalFrames:
	dc.b	1, 0, 1, 0, 1, 0, 1, 0
	dc.b	1, 0, 1, 0, 1, 0, 1, 0

	dc.b	1, 1, 0, 0, 1, 1, 0, 0
	dc.b	1, 1, 0, 0, 1, 1, 0, 0
	
	dc.b	1, 1, 1, 1, 0, 0, 0, 0
	dc.b	1, 1, 1, 1, 0, 0, 0, 0

	dc.b	1, 1, 1, 1, 1, 1, 1, 1
	dc.b	0, 0, 0, 0, 0, 0, 0, 0

FMV_SubModule:
	dc.b	"FMVSUB.SCD", 0
	even

; -------------------------------------------------------------------------
; Variables
; -------------------------------------------------------------------------

	rsset	*
buffer_id	rs.b	1			; Buffer ID
frame		rs.b	1			; Frame ID
fmv_done	rs.w	1			; Done flag

filename	rs.b	$C			; File name buffer
art_buffer	rs.b	$7000			; Art buffer

	align	$800

; -------------------------------------------------------------------------