; -------------------------------------------------------------------------
;
;	Bad Apple Sega CD Demo
;		By Ralakimus 2021
;
; -------------------------------------------------------------------------

	include	"../include/subcpu.asm"
	include	"cdsp/splib.asm"

; -------------------------------------------------------------------------
; FMV engine (Sub CPU)
; -------------------------------------------------------------------------

	org	PRG_RAM+$20000

	lea	PCM_BASE,a0			; Disable PCM channels
	move.b	#$FF,pcmOnOff(a0)
	moveq	#20,d0
	dbf	d0,*

	move.b	#$40,pcmCtrl(a0)		; Set up channel 1
	moveq	#20,d0
	dbf	d0,*
	move.b	#$FF,pcmEnv(a0)
	moveq	#20,d0
	dbf	d0,*
	move.b	#$FF,pcmPan(a0)
	moveq	#20,d0
	dbf	d0,*
	move.b	#3,pcmFDH(a0)
	moveq	#20,d0
	dbf	d0,*
	move.b	#$C6,pcmFDL(a0)
	moveq	#20,d0
	dbf	d0,*
	clr.b	pcmLSH(a0)
	moveq	#20,d0
	dbf	d0,*
	clr.b	pcmLSL(a0)
	moveq	#20,d0
	dbf	d0,*
	clr.b	pcmST(a0)
	moveq	#20,d0
	dbf	d0,*

	moveq	#$41,d1				; Silence other channels
	moveq	#7-1,d2

.Silence:
	move.b	d1,pcmCtrl(a0)			; Set up channel 1
	moveq	#20,d0
	dbf	d0,*
	clr.b	pcmEnv(a0)
	moveq	#20,d0
	dbf	d0,*

	addq.b	#1,d1				; Next channel
	dbf	d2,.Silence			; Loop until all the other channels are muted

	moveq	#16-1,d2			; Fill 16 banks
	moveq	#$FFFFFF80,d1			; Initial bank

.BankLoop:
	move.b	d1,pcmCtrl(a0)			; Select wave bank
	moveq	#20,d0
	dbf	d0,*
	move.b	d1,pcmCtrl(a0)
	moveq	#20,d0
	dbf	d0,*

	lea	pcmWaveData(a0),a1		; Fill wave data with stop flags
	move.w	#$1000-1,d0

.Copy:
	move.b	#$FF,(a1)
	addq.w	#2,a1
	dbf	d0,.Copy

	addq.b	#1,d1				; Next bank
	dbf	d2,.BankLoop			; Loop until all banks are filled

.Ready:
	move.b	GA_MEM_MODE+1.w,d0		; Set to 1M/1M mode
	bset	#2,d0
	move.b	d0,GA_MEM_MODE+1.w

	move.b	#"R",GA_SUB_FLAG.w		; Mark as ready

; -------------------------------------------------------------------------

.WaitCommand:
	moveq	#0,d0
	move.b	GA_MAIN_FLAG.w,d0		; Wait for command
	beq.s	.WaitCommand

	move.b	#"B",GA_SUB_FLAG.w		; Mark as busy
	
.WaitMain:
	tst.b	GA_MAIN_FLAG.w			; Is the Main CPU ready to send commands again?
	bne.s	.WaitMain			; If not, branch

	tst.b	d0				; Are we exiting?
	bmi.s	.Exit				; If so, branch

	add.w	d0,d0				; Go to command
	add.w	d0,d0
	jsr	.Commands-4(pc,d0.w)
	
	move.b	#"R",GA_SUB_FLAG.w		; Mark as ready
	bra.s	.WaitCommand			; Loop

.Exit:
	lea	PCM_BASE,a0			; Disable PCM channels
	move.b	#$40,pcmCtrl(a0)
	moveq	#20,d0
	dbf	d0,*
	clr.b	pcmEnv(a0)
	moveq	#20,d0
	dbf	d0,*
	move.b	#$FF,pcmOnOff(a0)
	moveq	#20,d0
	dbf	d0,*

	rts

; -------------------------------------------------------------------------
; Commands
; -------------------------------------------------------------------------

.Commands:
	bra.w	InitFMV				; Initialize FMV
	bra.w	ReadFMV				; Read more FMV data
	bra.w	SwapWordRAMBanks		; Swap Word RAM banks
	bra.w	PCMSilence			; Fill PCM bank with silence

; -------------------------------------------------------------------------
; Initialize an FMV
; -------------------------------------------------------------------------
; PARAMETERS:
;	Cmd 0-A	- File name
;	Cmd C	- Sector count
; RETURNS:
;	Stat 0	- 0 = Success, -1 = Failed
; -------------------------------------------------------------------------

InitFMV:
	lea	Buffer,a0			; Load file
	lea	GA_CMD_0.w,a1
	move.l	(a1)+,(a0)
	move.l	(a1)+,4(a0)
	move.l	(a1),8(a0)
	jsr	FindFile
	bcs.s	.Failed

	lea	CDReadVars,a6			; Read FMV data
	move.l	d0,(a6)
	clr.w	4(a6)
	move.w	GA_CMD_C.w,4+2(a6)
	move.l	#WORDRAM_1M,8(a6)
	jsr	ReadCD

	bsr.w	SwapWordRAMBanks		; Swap Word RAM banks

	move.l	#$F,4(a6)			; Get PCM data
	move.l	#PRG_RAM+$40000,8(a6)
	jsr	ReadCD

	lea	PCM_BASE,a0			; Begin streaming
	bsr.w	StreamPCM

	clr.b	started
	clr.l	GA_STAT_0.w
	rts

.Failed:
	move.l	#-1,GA_STAT_0.w			; Return -1 if not found
	rts

; -------------------------------------------------------------------------
; Read more FMV data
; -------------------------------------------------------------------------
; PARAMETERS:
;	Cmd 0	- Sector count
; -------------------------------------------------------------------------

ReadFMV:
	lea	PCM_BASE,a0			; Start playing PCM

	tst.b	started
	bne.s	.AlreadyStarted
	st	started

	move.b	#$40,pcmCtrl(a0)
	moveq	#20,d0
	dbf	d0,*
	move.b	#$FE,pcmOnOff(a0)
	moveq	#20,d0
	dbf	d0,*
	move.b	#$C0,pcmCtrl(a0)
	moveq	#20,d0
	dbf	d0,*

.AlreadyStarted:
	lea	CDReadVars,a6			; Read FMV data
	clr.w	4(a6)
	move.w	GA_CMD_0.w,4+2(a6)
	move.l	#WORDRAM_1M,8(a6)
	jsr	ReadCD

	move.l	#$F,4(a6)			; Get PCM data
	move.l	#PRG_RAM+$40000,8(a6)
	jsr	ReadCD
	
	lea	PCM_BASE,a0			; Stream PCM data

; -------------------------------------------------------------------------
; Stream PCM
; -------------------------------------------------------------------------

StreamPCM:
	lea	PRG_RAM+$40000,a2		; PCM data
	move.b	cur_wave_bank,d1		; Get wave bank

	lea	PCMCopyBank0(pc),a3		; Get copy data
	move.b	cur_wave_bank,d0
	andi.b	#$7F,d0
	beq.s	.StartCopy
	lea	PCMCopyBank1(pc),a3

.StartCopy:
	moveq	#8-1,d2				; Number of banks

.BankCopy:
	move.b	d1,pcmCtrl(a0)			; Select wave bank
	moveq	#20,d0
	dbf	d0,*
	move.b	d1,pcmCtrl(a0)
	moveq	#20,d0
	dbf	d0,*

	movea.l	(a3)+,a1			; Copy wave data
	move.w	(a3)+,d3

.Copy:
	rept	128
		move.b	(a2)+,(a1)
		addq.w	#2,a1
	endr
	dbf	d3,.Copy

	addq.b	#1,d1				; Next bank
	dbf	d2,.BankCopy			; Loop until all banks are copied

	eori.b	#7,cur_wave_bank		; Swap banks

.End:
	rts

; -------------------------------------------------------------------------
; Swap Word RAM banks
; -------------------------------------------------------------------------

SwapWordRAMBanks:
	move.b	GA_MEM_MODE+1.w,d0		; Swap Word RAM banks
	bchg	#0,d0
	move.b	d0,GA_MEM_MODE+1.w
	rts

; -------------------------------------------------------------------------
; Fill PCM bank with silence
; -------------------------------------------------------------------------

PCMSilence:
	lea	PRG_RAM+$40000,a0		; Fill PCM data with silence
	move.w	#$7800/4-1,d0

.Fill:
	clr.l	(a0)+
	dbf	d0,.Fill

	lea	PCM_BASE,a0			; Stream it
	bra.w	StreamPCM

; -------------------------------------------------------------------------
; PCM copy metadata
; -------------------------------------------------------------------------

PCMCopyBank0:
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$800/128-1

PCMCopyBank1:
	dc.l	PCM_BASE+pcmWaveData+($800*2)
	dc.w	$800/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1
	dc.l	PCM_BASE+pcmWaveData
	dc.w	$1000/128-1

; -------------------------------------------------------------------------
; Variables
; -------------------------------------------------------------------------

cur_wave_bank:					; Current wave bank
	dc.b	$80
started:					; Started flag
	dc.b	0

	align	$800

; -------------------------------------------------------------------------