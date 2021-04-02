
; -------------------------------------------------------------------------
;
;	Sega CD Base
;		By Ralakimus 2021
;
; -------------------------------------------------------------------------

	include	"../include/maincpu.asm"
	include	"mainprg/variables.asm"

; -------------------------------------------------------------------------
; Main program
; -------------------------------------------------------------------------

	obj	RAM_START+$600
	bra.w	DoTransition			; Do transition

; -------------------------------------------------------------------------

	include	"mainprg/library.asm"
	include	"mainprg/transition.asm"

; -------------------------------------------------------------------------

	if (*)>=(RAM_START+$2000)
		inform 3,"Main program is too large!"
	endif

	objend
	align	$800

; -------------------------------------------------------------------------