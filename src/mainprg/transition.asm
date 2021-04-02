
; -------------------------------------------------------------------------
;
;	Bad Apple Sega CD Demo
;		By Ralakimus 2021
;
; -------------------------------------------------------------------------

DoTransition:
	move	#$2700,sr			; Disable interrupts
	move.l	#VInterrupt,_LEVEL6+2.w		; Set interrupts
	move.l	#IntBlank,_LEVEL4+2.w
	move.w	#_LEVEL4,GA_HINT

	z80Stop					; Initialize controllers
	moveq	#$40,d0
	move.b	d0,IO_A_CTRL
	move.b	d0,IO_B_CTRL
	move.b	d0,IO_C_CTRL
	z80Start

	lea	vars_start.w,a0			; Clear variables
	move.w	#(vars_end-vars_start)/2-1,d0

.ClearRAM:
	clr.w	(a0)+
	dbf	d0,.ClearRAM

	lea	transition_vars(pc),a0
	move.w	#(transvars_end-transition_vars)/2-1,d0

.ClearRAM2:
	clr.w	(a0)+
	dbf	d0,.ClearRAM2

	lea	VDP_CTRL,a0			; Set VDP registers
	move.w	#$8004,(a0)
	move.w	#$8174,(a0)
	move.w	#$8D3F,(a0)
	move.w	#$9001,(a0)

	lea	palette.w,a1			; Prepare to copy palette
	moveq	#$80/2-1,d0

.WaitVBlank:
	move.w	(a0),d1				; Wait until we are in the VBlank period first
	andi.b	#8,d1
	beq.s	.WaitVBlank
	
	move.l	#$00000020,(a0)			; Now copy the palette

.CopyPal:
	move.w	-4(a0),(a1)+
	dbf	d0,.CopyPal

	move.w	#$002F,fade_info.w		; Fade certain colors to black
	bsr.w	FadeToBlack_Range

	move	#$2700,sr			; Disable interrupts
	move.l	#VIntTransition,_LEVEL6+2.w	; Set interrupts
	move.l	#HIntTransition,_LEVEL4+2.w
	
	lea	VDP_CTRL,a0			; Update VDP registers
	move.w	#$8014,(a0)
	move.w	#$8A00,(a0)
	move.w	#$857C,(a0)

	move.w	#$180,psg_freq			; Set up PSG
	bsr.w	VSync
	move.b	#$E7,PSG_CTRL
	move.b	#$98,PSG_CTRL
	move.b	#$F0,PSG_CTRL

	moveq	#0,d2				; Initial stretch value

.Stretch:
	bsr.w	GenHIntBuffer			; Generate H-INT buffer
	bsr.w	VSync				; VSync

	subi.w	#8,psg_freq			; Shift PSG frequency

	subq.w	#6,d2				; Stretch further
	cmpi.w	#-$F0,d2			; Have we stretched enough?
	bgt.s	.Stretch			; If not, keep stretching
	move.w	#-$F0,d2			; Cap stretch value

	moveq	#$30,d6				; Shrink accumulator
	moveq	#0,d7				; PSG frequency accumulator

.Shrink:
	bsr.w	GenHIntBuffer			; Generate H-INT buffer
	bsr.w	VSync				; VSync

	add.w	d7,psg_freq			; Shift PSG frequency
	addq.w	#1,d7

	add.w	d6,d2				; Shrink further
	addq.w	#8,d6
	cmpi.w	#$1800,d2			; Have we shrunk enough for fading?
	blt.s	.Shrink				; If not, keep shrinking
	
	move.w	#$003F,fade_info.w		; Fade the colors once
	bsr.w	FadeToBlack_Once

	cmpi.w	#$2000,d2			; Have we shrunk enough?
	blt.s	.Shrink				; If not, keep shrinking

	moveq	#$F*3,d0			; Initial PSG volume

.FadePSG:
	bsr.w	VSync				; VSync

	add.w	d7,psg_freq			; Shift PSG frequency

	subq.b	#1,d0				; Decrement volume
	bmi.s	.Exit				; If it's muted, branch
	
	moveq	#0,d3				; Get actual volume
	move.b	d0,d3
	divu.w	#3,d3

	moveq	#$F,d1				; Set PSG1 volume
	move.b	d3,d2
	lsr.b	#1,d2
	sub.b	d2,d1
	ori.b	#$90,d1
	move.b	d1,PSG_CTRL

	moveq	#$F,d1				; Set noise volume
	sub.b	d3,d1
	ori.b	#$F0,d1
	move.b	d1,PSG_CTRL			

	bra.s	.FadePSG			; Loop

.Exit:
	move	#$2700,sr			; Disable interrupts
	move.l	#VInterrupt,_LEVEL6+2.w		; Set interrupts
	move.l	#IntBlank,_LEVEL4+2.w

; -------------------------------------------------------------------------

	lea	.FMVFile(pc),a0			; Run FMV engine
	move.w	#filesize("_files/FMVMAIN.MCD")/4-1,d0
	bsr.w	LoadRAMFile
	jsr	RAM_START+$2000

	bra.w	*				; Halt

; -------------------------------------------------------------------------

.FMVFile:
	dc.b	"FMVMAIN.MCD", 0
	even

; -------------------------------------------------------------------------
; Load a file into RAM
; -------------------------------------------------------------------------
; PARAMETERS:
;	d0.w	- Size of file in longwords minus 1
;	a0.l	- Pointer to file name
; -------------------------------------------------------------------------

LoadRAMFile:
	move.w	d0,-(sp)			; Load file into Word RAM
	lea	Sub_WordRAM_2M,a1
	bsr.w	LoadFile
	bsr.w	SubCPUCmd_Wait
	move.w	(sp)+,d0

	lea	WordRAM_2M,a0			; Copy to work RAM
	lea	RAM_START+$2000,a1

.CopyFile:
	move.l	(a0)+,(a1)+
	dbf	d0,.CopyFile

	rts

; -------------------------------------------------------------------------
; Generate H-INT buffer
; -------------------------------------------------------------------------
; PARAMETERS:
;	d2.w	- Stretch value
; -------------------------------------------------------------------------

GenHIntBuffer:
	lea	hint_buffer,a0			; H-INT buffer
	move.w	#224-1,d0			; 224 lines
	moveq	#0,d4				; Current scanline

	move.w	#112,d1				; Center offset with accordance to stretching
	muls.w	d2,d1
	neg.l	d1

.Loop:
	move.l	d1,d3				; Get scanline value
	asr.l	#8,d3

	tst.w	d2				; Are we scaling?
	bmi.s	.Set				; If so, branch

	move.l	d3,d5				; Is this scanline past the top of the plane?
	add.l	d4,d5
	bmi.s	.Invisible			; If so, branch
	cmpi.l	#224,d5				; Is this scanline past the bottom of the plane?
	blt.s	.Set				; If not, branch

.Invisible:
	move.w	d4,d3				; Set this scanline to be nothing
	neg.w	d3

.Set:
	move.w	d3,(a0)+			; Set scanline value
	
	addq.w	#1,d4				; Get next scanline value
	add.l	d2,d1
	dbf	d0,.Loop			; Loop until finished

	rts

; -------------------------------------------------------------------------
; Transition V-INT
; -------------------------------------------------------------------------

VIntTransition:
	move	#$2700,sr			; Disable interrupts
	pusha					; Push all registers

	move.l	#$40000010,VDP_CTRL		; Set first H-INT line
	move.w	hint_buffer,VDP_DATA

	addq.w	#1,frame_count.w		; Increment frame counter
	move.w	#$8A00,VDP_CTRL			; Reset H-INT counter
	move.w	#2,hint_line			; Reset H-INT line

	tst.w	psg_freq			; Check for PSG cap
	bpl.s	.NoPSGMinCap
	clr.w	psg_freq

.NoPSGMinCap:
	cmpi.w	#$3FF,psg_freq
	bcs.s	.NoPSGMaxCap
	move.w	#$3FF,psg_freq

.NoPSGMaxCap:
	moveq	#2-1,d1				; 2 PSG channels
	moveq	#$FFFFFF80,d2			; Do PSG1 first

.SetPSGFreq:
	move.b	psg_freq+1,d0			; Set up PSG frequency
	andi.b	#$F,d0
	or.b	d2,d0
	move.b	d0,PSG_CTRL
	move.w	psg_freq,d0
	lsr.w	#4,d0
	move.b	d0,PSG_CTRL

	moveq	#$FFFFFFC0,d2			; Do noise next
	dbf	d1,.SetPSGFreq			; Loop until both channels are set

	z80Stop					; Stop Z80
	lea	VDP_CTRL,a6			; VDP control
	dma68k	palette,0,$80,CRAM,a6		; Transfer palette data
	z80Start				; Start Z80

	popa					; Pop all registers
	rte

; -------------------------------------------------------------------------
; Transition H-INT
; -------------------------------------------------------------------------

HIntTransition:
	move	#$2700,sr			; Disable interrupts

	move.l	a0,-(sp)			; Set line
	lea	hint_buffer,a0
	adda.w	hint_line,a0

	move.l	#$40000010,VDP_CTRL
	move.w	(a0),VDP_DATA
	move.l	(sp)+,a0

	addq.w	#2,hint_line			; Increment
	cmpi.w	#223*2,hint_line
	bcs.s	.NotDone
	move.w	#$8ADF,VDP_CTRL

.NotDone:
	rte

; -------------------------------------------------------------------------
; Data
; -------------------------------------------------------------------------

	rsset	(*)
transition_vars	rs.b	0
psg_freq	rs.w	1				; PSG frequency
hint_line	rs.w	1				; Current H-INT line
hint_buffer	rs.w	244				; H-INT buffer
transvars_end	rs.b	0

; -------------------------------------------------------------------------