;###############################################################################
; SUBROUTINES
;###############################################################################

!zone printPage { 	
;Prints the initial filenames that's added to the program by the micro.
printPage: 
	ldx numberOfItems
--	ldy #20
	.fetchPointer=*+1
-	lda itemList-1,y
	.fillPointer=*+1
	sta SCREEN_RAM+121,y

	dey
	bne -

	clc
	lda .fetchPointer
	adc #32
	sta .fetchPointer
	lda .fetchPointer+1
	adc #00
	sta .fetchPointer+1

	clc
	lda .fillPointer
	adc #40
	sta .fillPointer
	lda .fillPointer+1
	adc #00
	sta .fillPointer+1

	dex
	bne --

	rts
}

;-------------------------------------------------------
!zone enter {
;Launches the selected item	
enter:
	;Transfer starts with the lowest bit
	lda #$00
	sta BITPOS

	;Clear 8th bit of raster line
	lda #$7F
	and $D011
	sta $D011

	;Kill cia interrupts
	jsr killCIA

	;Decide if it's a file selection or special command (previous / next)
	lda COMMANDBYTE
	and #$40
	bne SPECIALCMD
	jsr GETCURRENTROW
	inx
	txa
	sec
	rol
	tax
	stx COMMANDBYTE

SPECIALCMD		
	; Last bit is not used and always sent as 1. This was tested to be less problematic.
	; Init code for S0 state is redundant in the code.
	SEC
	BCC S0INIT	

	;Raster interrupt to occur at A0 line.
S160INIT
	LDA #$7F
	AND $D011
	STA $D011 
	LDA #$A0
	STA $D012
	LDA #<IRQHANDLER2
	STA IRQVECTOR
	LDA #>IRQHANDLER2
	STA IRQVECTOR+1

WAITRASTER1 		;Wait till A1 line
	LDA $D012
	CMP #$A1
	BNE WAITRASTER1
		
	JMP ENABLERASTER	

S0INIT 				;S0	
	LDA #$7F
	AND $D011
	STA $D011 		
	LDA #$00
	STA $D012
	LDA #<IRQHANDLER1
	STA IRQVECTOR
	LDA #>IRQHANDLER1
	STA IRQVECTOR+1

WAITRASTER2
	LDA $D012
	CMP #$01
	BNE WAITRASTER2
	
ENABLERASTER	
	LDA #$01
	STA $D01A	;Enable raster interrupts

	LDY #$00	
	CLV	
	STY BITTARGET

WAITIRQ 		; Wait till the command byte transferred to the micro
	BIT BITTARGET	
	BVC WAITIRQ	
	CLV		

; Command is transferred. Prepare loader for the transferring of the actual stuff
; If it's a program then micro resets c64 so below code is not relevant.
; If micro will be transferring a directory transfers a directory dump 	
	SEI
	JSR SETUPTRANSFER

	LDA #$06
	STA $d020
	
; Init transfer variables that loader will use. 	
	JSR INITTRANSVAR
	LDY #$00	
	CLV	
	STY BITTARGET

; Wait signal from loader that the transfer is finished
WAITNMI
	BIT BITTARGET	
	BVC WAITNMI	
	CLV
		
	jsr printPage ;Update the screen with the new content got from micro		

	cli
	;jmp INPUT_GET
  	
 	rts	
}

COMMANDBYTE !by 0
BITPOS !by 0
;-------------------------------------------------------
;IRQ Handlers
;-------------------------------------------------------
; Use IRQ as a covert channel to send selected file information
; Arduino has attached an interrupt on it's end 
; It will measure time between falling edges of IRQ
IRQHANDLER1
	SEI	
	INC $D020	
	ASL $D019	;Acknowledge interrupt
	LDA COMMANDBYTE
	LDY BITPOS					
	CPY #$08
	BEQ FINISHSENDING1
	INC BITPOS
	INY 
SHIFTBYTE1	
	LSR			;Move rightmost bit right moving it to carry
	DEY
	BNE SHIFTBYTE1
	BCC IRQHANDLE1CONT
	
	LDA #$7F
	AND $D011
	STA $D011 
			
	LDA #$A0
	STA $D012			
	LDA #<IRQHANDLER2
	STA IRQVECTOR
	LDA #>IRQHANDLER2
	STA IRQVECTOR+1

	DEC $D020	
	CLI
	;JMP $EA31 
	PLA
	TAY
	PLA
	TAX
	PLA 
	RTI
;-------------------------------------------------------
IRQHANDLE1CONT	
	LDA #$7F
	AND $D011
	STA $D011 
	LDA #$00
	STA $D012		

	DEC $D020
	CLI	
	;JMP $EA31 
	PLA
	TAY
	PLA
	TAX
	PLA 
	RTI	
;-------------------------------------------------------
FINISHSENDING1
	LDA #$64
	STA BITTARGET		; Break foreground wait
	
	;LDA #$00
	;STA $D01A
		
	CLI
	;JMP $EA31 
	PLA
	TAY
	PLA
	TAX
	PLA 
	RTI
;-------------------------------------------------------
IRQHANDLER2
	SEI
	INC $D020	
	ASL $D019	;Acknowledge interrupt
	LDA COMMANDBYTE
	LDY BITPOS					
	CPY #$08
	BEQ FINISHSENDING2
	INC BITPOS
	INY 
SHIFTBYTE2	
	LSR			;Move rightmost bit right moving it to carry
	DEY
	BNE SHIFTBYTE2
	BCC IRQHANDLE2CONT
	
	LDA #$7F
	AND $D011
	STA $D011 		
	LDA #$00
	STA $D012			
	LDA #<IRQHANDLER1
	STA IRQVECTOR
	LDA #>IRQHANDLER1
	STA IRQVECTOR+1
	
	DEC $D020
	
	CLI
	;JMP $EA31 
	PLA
	TAY
	PLA
	TAX
	PLA 
	RTI	
;-------------------------------------------------------
FINISHSENDING2
	
	LDA #$64
	STA BITTARGET		; Break foreground wait
	
	;LDA #$00
	;STA $D01A
	
	;JMP $EA31
	PLA
	TAY
	PLA
	TAX
	PLA 
	RTI		
;-------------------------------------------------------
IRQHANDLE2CONT	
	LDA #$7F
	AND $D011
	STA $D011 
	LDA #$A0
	STA $D012		

	DEC $D020
		
	CLI	
	;JMP $EA31 
	PLA
	TAY
	PLA
	TAX
	PLA 
	RTI		

;-------------------------------------------------------
;Other Subs
;-------------------------------------------------------
killCIA
	LDY #$7f    ; $7f = %01111111 
    STY $dc0d   ; Turn off CIAs Timer interrupts 
    STY $dd0d   ; Turn off CIAs Timer interrupts 
    LDA $dc0d   ; cancel all CIA-IRQs in queue/unprocessed 
    LDA $dd0d   ; cancel all CIA-IRQs in queue/unprocessed 
	RTS	

DISABLEINTERRUPTS
    LDY #$7f    			; $7f = %01111111 
    STY $dc0d   			; Turn off CIAs Timer interrupts 
    STY $dd0d  				; Turn off CIAs Timer interrupts 
    LDA $dc0d  				; cancel all CIA-IRQs in queue/unprocessed 
    LDA $dd0d   			; cancel all CIA-IRQs in queue/unprocessed 

GETCURRENTROW	; Input : None, Output : X (current row)
	LDX ACTIVE_ITEM
	RTS	

SETUPTRANSFER	
	JSR DISABLEINTERRUPTS
	JSR DISABLEDISPLAY
	LDA #$37
	STA $01	
	; Do not Disable kernal & basic rom	
	
	LDA #<CARTRIDGENMIHANDLER
	STA SOFTNMIVECTOR
	LDA #>CARTRIDGENMIHANDLER
	STA SOFTNMIVECTOR+1
		
    LDA #01					
   	STA $d020
   	LDY #$00	;Setup for transfer routine   	   	
   	;JSR WAITLINE   	
	RTS

WAITLINE   	
   	LDA #$80
   	CMP $D012
   	BNE WAITLINE
   	JSR WASTELINES 
   	INY
   	BNE WAITLINE
   	RTS	
WASTELINES
	LDX #$00
CONSUME	
	NOP
	INX
	BNE CONSUME		
	RTS

INITTRANSVAR
	LDA #$F0
	STA DATA_LOW
	STA ACTUAL_LOW
	LDA #$1C
	STA DATA_HIGH
	STA ACTUAL_HIGH	
	LDA #$03
	STA DATA_LENGTH
	TAX		
	LDY #$00
	RTS

ENDTRANSFER
	LDA #<ROMNMIHANDLER
	STA SOFTNMIVECTOR
	LDA #>ROMNMIHANDLER
	STA SOFTNMIVECTOR+1
	RTS
		
NMIROUTINE
	PHA
	TXA
	PHA
	TYA
	PHA
	
	JSR $C000	; Call play
	
	LDA $DD0D	; Acknowledge
	PLA
	TAY
	PLA 
	TAX
	PLA
	RTI	

DISABLEDISPLAY
	LDA #$0B				;%00001011 ; Disable VIC display until the end of transfer
	STA $D011	
	RTS

ENABLEDISPLAY
	LDA #$1B				;%00001011 ; Disable VIC display until the end of transfer
	STA $D011	
	RTS				
	