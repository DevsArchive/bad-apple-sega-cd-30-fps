
; -------------------------------------------------------------------------
;
;	Sega CD Base
;		By Ralakimus 2021
;
; -------------------------------------------------------------------------

	include	"mainprg/variables.asm"

; -------------------------------------------------------------------------
; Functions
; -------------------------------------------------------------------------

SubCPUCmd		EQU	$FF0604
SubCPUCmd_Wait		EQU	$FF0630
PlayCDDA		EQU	$FF063C
LoopCDDA		EQU	$FF064C
ReadSectors		EQU	$FF065C
ReadNextSectors		EQU	$FF0674
GetFileSector		EQU	$FF0686
LoadFile		EQU	$FF06AA
SetWordRAMMode		EQU	$FF06C8
SwapWordRAMBanks	EQU	$FF06D8
RunSubCPUModule		EQU	$FF06E2
StopCDDA		EQU	$FF06E8
VSync			EQU	$FF06F2
FadeToBlack		EQU	$FF0706
FadeToBlack_Range	EQU	$FF070C
FadeFromBlack		EQU	$FF0760
FadeFromBlack_Range	EQU	$FF0766
FadeToWhite		EQU	$FF07C0
FadeToWhite_Range	EQU	$FF07C6
FadeToWhite_Once	EQU	$FF07D8
FadeFromWhite		EQU	$FF082A
FadeFromWhite_Range	EQU	$FF0830
FadeFromWhite_Once	EQU	$FF0848
CompDec			EQU	$FF088E
ClearScreen		EQU	$FF08BC
VInterrupt		EQU	$FF0916
ReadControllers		EQU	$FF09B4

; -------------------------------------------------------------------------