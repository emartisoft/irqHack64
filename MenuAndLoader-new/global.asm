;--------------------------------------------------------------
;	Global.asm
;--------------------------------------------------------------

	;vic-ii data locations
	SCREEN_RAM = $0400
	COLOR_RAM  = $d800
	SPRITES    = $2000
	CHARSET1   = $2800
	CHARSET2   = $3000

	;Kernel locations
	CHROUT    	= $FFD2

	;Music
	music		= $1000		;Müzik dosyasinin yuklenecegi adres
	musicPlay	= music+3	;Müzik player adresi
