;**********************************************************************
;   This file is a basic code template for object module code         *
;   generation on the PIC16F877A. This file contains the              *
;   basic code building blocks to build upon.                         *
;                                                                     *
;   Refer to the MPASM User's Guide for additional information on     *
;   features of the assembler and linker (Document DS33014).          *
;                                                                     *
;   Refer to the respective PIC data sheet for additional             *
;   information on the instruction set.                               *
;                                                                     *
;**********************************************************************
;                                                                     *
;    Filename:      Lab 9.asm                                         *
;    Date:          11/16/17                                          *
;    File Version:  0.0.1                                             *
;                                                                     *
;    Author:        Andrew W. Harn                                    *
;    Company:       Geneva College                                    *
;                                                                     * 
;                                                                     *
;**********************************************************************
;                                                                     *
;    Files required: P16F877A.INC                                     *
;		     P16F877A_LCDWDBMOD.ASM			      *   
;                                                                     *
;                                                                     *
;**********************************************************************
;                                                                     *
;    Notes:                                                           *
;                                                                     *
;                                                                     *
;                                                                     *
;                                                                     *
;**********************************************************************


    list        p=16f877a   ; list directive to define processor
    #include    <p16f877a.inc>  ; processor specific variable definitions
    
    __CONFIG _CP_OFF & _WDT_OFF & _BODEN_OFF & _PWRTE_OFF & _HS_OSC & _WRT_OFF & _LVP_OFF & _CPD_OFF & _DEBUG_OFF

; '__CONFIG' directive is used to embed configuration data within .asm file.
; The labels following the directive are located in the respective .inc file.
; See respective data sheet for additional information on configuration word.

;***** VARIABLE DEFINITIONS (examples)

; example of using Shared Uninitialized Data Section
INT_VAR     UDATA_SHR      
w_temp      RES     1       ; variable used for context saving 
status_temp RES     1       ; variable used for context saving
pclath_temp RES	    1       ; variable used for context saving
pattern	    RES	    1

; example of using Uninitialized Data Section
TEMP_VAR    UDATA           ; explicit address specified is not required
temp_count  RES     1       ; temporary variable (example)
ASCII	    RES	    1
add	    RES	    1
	    
; example of using Overlayed Uninitialized Data Section
; in this example both variables are assigned the same GPR location by linker
G_DATA      UDATA_OVR       ; explicit address can be specified
flag        RES 2           ; temporary variable (shared locations - G_DATA)

G_DATA      UDATA_OVR   
count       RES 2           ; temporary variable (shared locations - G_DATA)

extern	    LCDInit
extern	    temp_wr
extern	    i_write
extern	    d_write
;**********************************************************************
RESET_VECTOR    CODE    0x0000 ; processor reset vector
    nop                        ; nop for icd
    pagesel start
    goto    start              ; go to beginning of program


INT_VECTOR      CODE    0x0004 ; interrupt vector location

INTERRUPT

    movwf   w_temp          ; save off current W register contents
    movf    STATUS,w        ; move status register into W register
    movwf   status_temp     ; save off contents of STATUS register
    movf    PCLATH,w        ; move pclath register into w register
    movwf   pclath_temp     ; save off contents of PCLATH register

; isr code can go here or be located as a call subroutine elsewhere

    movf    pclath_temp,w   ; retrieve copy of PCLATH register
    movwf   PCLATH          ; restore pre-isr PCLATH register contents
    movf    status_temp,w   ; retrieve copy of STATUS register
    movwf   STATUS          ; restore pre-isr STATUS register contents
    swapf   w_temp,f
    swapf   w_temp,w        ; restore pre-isr W register contents
    retfie                  ; return from interrupt

MAIN_PROG       CODE

start
    movlw   0x07
    banksel ADCON1
    movwf   ADCON1
    
    pagesel LCDInit		; Initialize LCD
    call    LCDInit
    
    banksel temp_wr		; Clear display instruction to temp_wr
    movlw   0x01	
    movwf   temp_wr	
    
    pagesel i_write		; Write instruction to LCD
    call    i_write
       
    pagesel kpreset		; Prepare keypad for use
    call    kpreset
    
loop
    pagesel kpread
    banksel PORTC
    clrf    PORTC
    btfss   PORTC,4		; Start reading if rows are pressed
    goto    kpread 
    btfss   PORTC,5
    goto    kpread
    btfss   PORTC,6
    goto    kpread
    btfss   PORTC,7
    goto    kpread
    pagesel loop		; Go back to looping if nothing happened
    goto    loop		
    
kpread
    banksel PORTC
    movlw   0x00
    movwf   PORTC
    movfw   PORTC		; Read Port C value, this will be row pattern
    andlw   B'11110000' 	; Ensure unwanted bits are suppressed
    movwf   pattern
    banksel TRISC
    movlw   B'00001110'
    movwf   TRISC
    banksel PORTC
    movlw   00
    movwf   PORTC		; Ensure output values still zero
    movfw   PORTC		; Read Port C value, this will be column pattern
    andlw   B'00001110' 	; Ensure unwanted bits are suppressed
    iorwf   pattern,1		; OR those results into the pattern
    
convert 	
    bcf		STATUS,0
    rrf		pattern,1	    ; Discard bit 0 which is not used
    banksel	add
    clrf	add
    pagesel	kp1
    btfsc	pattern,6
    goto	kp1
    pagesel	col_find
    goto	col_find	    ; Here if row 1, kpad_add stays as is
    
kp1
    pagesel	kp2
    btfsc	pattern,5
    goto	kp2
    movlw	B'00000100'	    ; Here if row 2
    banksel	add
    iorwf	add,1		    ; Form table address
    pagesel	col_find
    goto	col_find
    
kp2
    pagesel	kp3
    btfsc	pattern,4
    goto	kp3
    movlw	B'00001000'	    ; Here if row 3
    banksel	add
    iorwf	add,1		    ; Form table address
    pagesel	col_find
    goto	col_find
    
kp3
    pagesel	kp4
    btfsc	pattern,3
    goto	kp4
    movlw	B'00001100'	    ; Here if row 4
    banksel	add
    iorwf	add,1		    ; Form table address
    pagesel	col_find
    goto	col_find
    
kp4
    movlw	D'16'		    ; No row detected, return "E" via Table
    pagesel	keypad_op
    goto 	keypad_op
    
col_find 	
    pagesel	cf1
    btfsc	pattern,2
    goto	cf1
    pagesel	keypad_op
    goto	keypad_op	    ; Here if column 1, kpad_add stays as is
    
cf1
    pagesel	cf2
    btfsc	pattern,1
    goto	cf2
    movlw	B'00000001'	    ; Here if column 2
    banksel	add
    iorwf	add,1		    ; Form table address
    pagesel	keypad_op
    goto   	keypad_op

cf2		
    movlw	B'00000010'			
    banksel	add
    iorwf	add,1		    ; Form table address	
    
keypad_op 	
    banksel	add
    movf	add,0
    pagesel	kplookup
    call	kplookup
    banksel	ASCII
    movwf	ASCII		    ; Save the character
    bcf		STATUS,Z
    sublw	0x80
    pagesel	rst
    btfsc	STATUS,Z
    goto	rst		    ; ASCII is an error code. Clear it out.
    
display
    banksel ASCII		    ; Move ASCII into temp_wr
    movfw   ASCII
    banksel temp_wr	
    movwf   temp_wr
    pagesel d_write		    ; Write ASCII to LCD
    call    d_write
    banksel temp_wr
    movlw   0x10		    ; Move cursor 1 to the left
    movwf   temp_wr
    pagesel i_write		    ; Write it to the LCD
    call    i_write
    pagesel rst
    goto    rst
    
rst				    ; Reset and go back to loop
    banksel ASCII
    clrf    ASCII	
    clrf    pattern
    pagesel wait
    call    wait
    pagesel kpreset
    call    kpreset
    pagesel loop
    goto    loop
    
kpreset
    banksel TRISC
    movlw   b'11110000'		    ; Read columns
    movwf   TRISC
    banksel PORTC
    movlw   0x00
    movwf   PORTC		    ; Make sure outputs are off
    return
    
wait
    pagesel kpreset		    ; Wait until all buttons are not pressed.
    call    kpreset
    banksel PORTC
    pagesel wait
    btfss   PORTC,4		
    goto    wait
    btfss   PORTC,5
    goto    wait
    btfss   PORTC,6
    goto    wait
    btfss   PORTC,7
    goto    wait
    return
    
kplookup			
    banksel add
    movfw   add
    pageselw kp_table		;Special assembly directive used 'pageselw' so that 
						;all 5 upper bits are written. 
						;Get the byte read and use it to
    movlw    kp_table		;index into our jump table. If
    addwf    add,w		;we crossed a 256-byte boundary,
    btfsc    STATUS,C                ;then increment PCLATH. Then load the
    incf     PCLATH,f                 ;program counter with computed goto.
    movwf    PCL    
    
kp_table
    retlw	0x31		;row 1
    retlw	0x32
    retlw	0x33
    retlw	0x80		;Error code
    retlw	0x34		;row 2
    retlw	0x35
    retlw	0x36
    retlw	0x80		;Error code
    retlw	0x37		;row 3
    retlw	0x38
    retlw	0x39
    retlw	0x80		;Error code
    retlw	0x2A		;row 4
    retlw	0x30
    retlw	0x23
    retlw	0x80		;Error code
    retlw	0x80		;Error code
    
    END                       ; directive 'end of program'