;-------------------------------------------------------------------------------
; PicmasTree Code
; Copyright (c) 2008 by John A. Toebes
; All Rights Reserved
;-------------------------------------------------------------------------------
	LIST	p=16F685
	INCLUDE	"p16F685.inc"
	EXPAND
	LIST	X=ON,ST=ON,W=2
;-------------------------------------------------------------------------------
; BCALL - Call a function in a different bank
; Syntax:
;	BCALL	function
; Where:
;	function is the function to call.  This assumes that there is a stub
;       in bank zero called function0 which does the pagesel to get to the
;	right function
;
BCALL	MACRO	function
	PAGESEL	function#V(0)
	CALL	function#V(0)
	PAGESEL	start
	ENDM
	
REFRESH_INTERVAL	EQU	.14
MAX_ITERATIONS	EQU	.200
;-------------------------------------------------------------------------------
;
; DEFSCHEME - Define a table based scheme
; DEFCALLSCHEME - Define a function based scheme
;  Syntax:
;	DEFSCHEME	PAT_<name>,ITER,TIME,TABLEn,S1,S2,S3,S4,PAT_<next>,FLAGS
;	DEFCALLSCHEME	PAT_<name>,ITER,TIME,TABLEn,PARM1,PARM2,PAT_<next>,FLAGS
;  Where:
;	<name> is the name assigned to the pattern. This is assigned the pattern
;              index automatically by the macro.
;	ITER is how many iterations to run the full pattern for
;	TIME is how long an individual refresh cycle is for.  This controls the
;            speed of the glow
;	TABLEn is the start of the table defining the pattern
;	S1..S4 are the offsets from the start of the table where each bank
;              pattern starts
;	PARM1,PARM2 is the scheme specific values to pass to the functions
;	PAT_<next> is the scheme to follow this
;	FLAGS are the parameters to control running this pattern
;
;  Notes:
;	These macros assume that there are two tables, one for the initial and
;       one for the toggle value for the leds in a bank
;	DEFSCHEME assumes that there is a corresponding TABLE<n>9999 to define
;       the end of the table
;	DEFCALLSCHEME assumes that there are two entries in the initial table
;       which point to the Initialization and Refresh routines.  It also
;       assumes that there are two entries in the toggle table, the first of
;       which points to the advance routine and the other which is unused
;
;-------------------------------------------------------------------------------
	VARIABLE	_SCHEMENUM=0
DEFSCHEME	MACRO	NAME,ITER,TIME,BASE,B0,B1,B2,B3,NEXTSCHEME,FLAGS
SCHEME#V(_SCHEMENUM)	EQU	$
NAME	EQU	_SCHEMENUM
_SCHEMENUM	SET	_SCHEMENUM+1
	LOCAL	SPAN,REM1,SKIP1,REM2,SKIP2
SPAN	SET	MAX_ITERATIONS/TIME
REM1	SET	MAX_ITERATIONS-(TIME*SPAN)
	IF	REM1 < 1
SKIP1	SET	0
REM2	SET	0
	ELSE
SKIP1	SET	(TIME+REM1-1)/REM1	
REM2	SET	REM1-(TIME/SKIP1)
	ENDIF
	IF	REM2 < 1
SKIP2	SET	0
	ELSE
SKIP2	SET	(TIME+REM2-1)/REM2
	ENDIF

	RETLW	ITER			; Number of times to iterate the cycle
	RETLW	TIME			; Width of a Cycle
	RETLW	BASE-TABLE0		; Base of the cycle
	RETLW	BASE#V(.9999)-TABLE0	; Limit of the cycle
	RETLW	B0+BASE-TABLE0		; Bank 0 Initial Value
	RETLW	B1+BASE-TABLE0		; Bank 1 Initial Value
	RETLW	B2+BASE-TABLE0		; Bank 2 Initial Value
	RETLW	B3+BASE-TABLE0		; Bank 3 Initial Value
	RETLW	FLAGS|M_TABLE		; Flags to control the display
	RETLW	SPAN
	RETLW	(SKIP2<<4)|SKIP1
	RETLW	NEXTSCHEME*.12		; Next SCHEME offset
	ENDM
;
DEFCALLSCHEME	MACRO	NAME,ITER,BASE,PARM1,PARM2,NEXTSCHEME,FLAGS
SCHEME#V(_SCHEMENUM)	EQU	$
NAME	EQU	_SCHEMENUM
_SCHEMENUM	SET	_SCHEMENUM+1
	RETLW	ITER			; Number of times to iterate the cycle
	RETLW	.1			; Width of a Cycle
	RETLW	BASE-TABLE0		; Base of the cycle
	RETLW	BASE#V(.9999)-TABLE0	; Limit of the cycle
	RETLW	BASE-TABLE0		; Initialization/Advance Functions
	RETLW	BASE+1-TABLE0		; Refresh/Unused Functions
	RETLW	PARM1			; Scheme Parm 1
	RETLW	PARM2			; Scheme Parm 2
	RETLW	FLAGS			; Flags to control the display
	RETLW	.0			; Unused
	RETLW	.0			; Unused
	RETLW	NEXTSCHEME*.12		; Next SCHEME offset
	ENDM
;-------------------------------------------------------------------------------
;
;  STARTTABLE - Start of a table
;
;  Syntax:
;		STARTTABLE	<tablename>
;
;  This macro defines the start of a lookup table which is indexed
;  by the value in the W register
;
;-------------------------------------------------------------------------------
	VARIABLE	_TABBASE=0
STARTTABLE	MACRO	TABNAME
	LOCAL	PCHIGH
	IF	_TABBASE > 0
	ERROR	"STARTTABLE - Can not nest tables"
	ENDIF
TABNAME
PCHIGH	SET	$>>8
	IF	PCHIGH
	MOVWF	TABLE_TEMP
	MOVLW	PCHIGH
	MOVWF	PCLATH
	MOVF	TABLE_TEMP,W
	ELSE
	CLRF	PCLATH
	ENDIF
	ADDWF	PCL,F	; Use that to index into the table
TABNAME#V(.1)	EQU	$	
_TABBASE	SET	TABNAME#V(.1)
	ENDM

;-------------------------------------------------------------------------------
;
;  ENDTABLE - End of a table
;
;  Syntax:
;		ENDTABLE
;
;  This macro closes a table, ensuring that the table is
;  on an appropriate page boundary.
;  It also adds in code to catch attempts to index past the end of the table
;
;-------------------------------------------------------------------------------
ENDTABLE	MACRO
	LOCAL	STARTHIGH,ENDHIGH
	IF	_TABBASE == 0
	ERROR	"ENDTABLE - No table defined"
	ENDIF
STARTHIGH	SET	_TABBASE >> 8
ENDHIGH		SET	($-1)>>8
	IF	STARTHIGH != ENDHIGH
	ERROR	"ENDTABLE - Table spans page boundary" #V(_TABBASE)
	ENDIF
	PAGESEL	ERROR_INDEX	; Catch attempts to index beyond the end of the table
	GOTO	ERROR_INDEX	; This catches at least 1 and sometimes 2 beyond the end
_TABBASE	SET	0
	ENDM

;-------------------------------------------------------------------------------
; Flags for use with the Scheme Table
;-------------------------------------------------------------------------------
F_NOFADE	EQU	0	; Don't do a fade operation
M_NOFADE	EQU	(1<<F_NOFADE)
F_NOWRAP	EQU	1	; Don't use the wrapping rules
M_NOWRAP	EQU	(1<<F_NOWRAP)
F_DOSLEEP	EQU	2	; Go to sleep after this pattern
M_DOSLEEP	EQU	(1<<F_DOSLEEP)
F_STARTUP	EQU	3	; We are starting up
M_STARTUP	EQU	(1<<F_STARTUP)
F_TABLE		EQU	4	; Lights are table driven
M_TABLE		EQU	(1<<F_TABLE)

;-------------------------------------------------------------------------------
; System Flags for GLOBAL_FLAGS
;-------------------------------------------------------------------------------
F_DOSHUTDOWN	EQU	0	; Schedule shutdown on next restart
M_DOSHUTDOWN	EQU	(1<<F_DOSHUTDOWN)
F_DOINIT	EQU	1	; Don't use the wrapping rules
M_DOINIT	EQU	(1<<F_DOINIT)
F_COMPLETE	EQU	2	; This cycle is complete, so advance
M_COMPLETE	EQU	(1<<F_COMPLETE)
F_SHUTTING	EQU	3	; In the process of shutting down
M_SHUTTING	EQU	(1<<F_SHUTTING)
F_POWERON	EQU	4	; We are running on USB power
M_POWERON	EQU	(1<<F_POWERON)
;-------------------------------------------------------------------------------------
; Flags for use with the Scheme Table
;-------------------------------------------------------------------------------------
F_DARKCYCLE	EQU	.7	; We are not showing the lights
M_DARKCYCLE	EQU	(1<<F_DARKCYCLE)

;-------------------------------------------------------------------------------------
; Layout of the LEDs on the board
;-------------------------------------------------------------------------------------
LEDBANK_LEFT	EQU	.0
LEDBANK_RIGHT	EQU	.8
LEDBANK_SPLIT	EQU	.16
LEDBANK_CENTER	EQU	.24

LED_LEFT_TOP_O	EQU	LEDBANK_LEFT+.0
LED_LEFT_2_G	EQU	LEDBANK_LEFT+.1
LED_LEFT_3_Y	EQU	LEDBANK_LEFT+.2
LED_LEFT_4_R	EQU	LEDBANK_LEFT+.3
LED_LEFT_5_O	EQU	LEDBANK_LEFT+.4
LED_LEFT_6_G	EQU	LEDBANK_LEFT+.5
LED_LEFT_7_Y	EQU	LEDBANK_LEFT+.6
LED_LEFT_8_R	EQU	LEDBANK_LEFT+.7

LED_RIGHT_TOP_O	EQU	LEDBANK_RIGHT+.0
LED_RIGHT_2_G	EQU	LEDBANK_RIGHT+.1
LED_RIGHT_3_Y	EQU	LEDBANK_RIGHT+.2
LED_RIGHT_4_R	EQU	LEDBANK_RIGHT+.3
LED_RIGHT_5_O	EQU	LEDBANK_RIGHT+.4
LED_RIGHT_6_G	EQU	LEDBANK_RIGHT+.5
LED_RIGHT_7_Y	EQU	LEDBANK_RIGHT+.6
LED_RIGHT_8_R	EQU	LEDBANK_RIGHT+.7

LED_SPLIT_LTOP_Y	EQU	LEDBANK_SPLIT+.0
LED_SPLIT_L_R	EQU	LEDBANK_SPLIT+.1
LED_SPLIT_L_O	EQU	LEDBANK_SPLIT+.2
LED_SPLIT_L_G	EQU	LEDBANK_SPLIT+.3
LED_SPLIT_RTOP_Y	EQU	LEDBANK_SPLIT+.4
LED_SPLIT_R_R	EQU	LEDBANK_SPLIT+.5
LED_SPLIT_R_O	EQU	LEDBANK_SPLIT+.6
LED_SPLIT_R_G	EQU	LEDBANK_SPLIT+.7

LED_CENTER_TOP_Y	EQU	LEDBANK_CENTER+.0
LED_CENTER_2_R	EQU	LEDBANK_CENTER+.1
LED_CENTER_3_O	EQU	LEDBANK_CENTER+.2
LED_CENTER_4_G	EQU	LEDBANK_CENTER+.3
LED_CENTER_5_Y	EQU	LEDBANK_CENTER+.4
LED_CENTER_6_R	EQU	LEDBANK_CENTER+.5
LED_CENTER_7_O	EQU	LEDBANK_CENTER+.6
LED_CENTER_8_G	EQU	LEDBANK_CENTER+.7
;			
; Define our basic register file		
;		
	CBLOCK	0x20
	CYC_FLAGS	; Controls for how we run the cycles	
	TEMP		; Temporary variable	
	BASE		; Base for the current cycle

	CUR_SCHEME	; The scheme that we just loaded
	ITER_BANK	; The bank that we are working on to fill
	IDLE_CTR	; # times to cycle before enabling power down
	STAGE_COUNTER	; Used by Random routines to count run time

	EXTRA_CTR	; The number of iterations we want to run the 
	SCHEME		; The SCHEME that we are going to next	
	WHICH_PATTERN	; Flag to indicate which pattern we want to run

	SORT_J
	LEDTIMELIMIT
	SAVE_PLACE
	REFRESH_TIME	; Time that we will allow a refresh to continue

	BANK0		; Bank 0 Scheme Pat Index
	BANK1		; Bank 1 Scheme Pat Index
	BANK2		; Bank 2 Scheme Pat Index
	BANK3		; Bank 3 Scheme Pat Index
	
	TIME0		; Time to display MASK0 for current bank
	TIME1		; Time to display MASK1 for current bank
	TIME2		; Time to display MASK2 for current bank
	TIME3		; Time to display MASK3 for current bank
	
	TIME4		; Time to display MASK4 for current bank
	TIME5		; Time to display MASK5 for current bank
	TIME6		; Time to display MASK6 for current bank
	TIME7		; Time to display MASK7 for current bank

	MASK0		; Light mask for time slot 0
	MASK1		; Light mask for time slot 1
	MASK2		; Light mask for time slot 2
	MASK3		; Light mask for time slot 3
	
	MASK4		; Light mask for time slot 4
	MASK5		; Light mask for time slot 5
	MASK6		; Light mask for time slot 6
	MASK7		; Light mask for time slot 7

	SAVE_PATTERN	; Remembers what pattern we were on when we powered down
	CUR_SKIP
	CUR_SEQ1
	CUR_SEQ2
	
	SEL_SEQ1
	SEL_SEQ2
	
	ENDC
;*******************************************************************************
; Global variables available no matter what bank is selected
;*******************************************************************************
	CBLOCK	0x70
	CUR_BANK	; current bank which we are outputing to the port(1-4)
	ITER_CTR 	; The number of iterations to refresh the lights for
	ITER_LIMIT	; The total number of iterations that we want to have
	LIMIT		; Limit for the current cycle

	GLOBAL_FLAGS	; System state flags
	SCHEME_CTR	; The number of times we should do this SCHEME	
	TABLE_TEMP	; Temporary variable to hold table indexes
	RANDOMV		; Random Number

	LED0TIME	; Time to light LED0 in current bank
	LED1TIME	; Time to light LED1 in current bank
	LED2TIME	; Time to light LED2 in current bank
	LED3TIME	; Time to light LED3 in current bank

	LED4TIME	; Time to light LED4 in current bank
	LED5TIME	; Time to light LED5 in current bank
	LED6TIME	; Time to light LED6 in current bank
	LED7TIME	; Time to light LED7 in current bank
	ENDC

	CBLOCK	0xA0
;-------------------------------------------------------------------------------
;	These sets of variables are in pairs.
;	The first LEDxxPLACE indicates where in the Lights or Dark Cycle the
;	sequence from 0-255.  When it overflows it switches from Light to Dark
;	The second LEDxxSKIPDARK combines the Light/Dark state (as the high bit)
;	and the remainder is the amount to increment the corresponding
;	LEDxxPLACE value by.
;	When the High Bit of the LEDxxSKIPDARK is cleared then the value in the
;	LEDxxPLACE is ignored and the LED is not lit for that time.  When
;	it is set, the value is used for indicating how bright to light the LED
;-------------------------------------------------------------------------------
	LED01PLACE
	LED01SKIPDARK

	LED02PLACE
	LED02SKIPDARK

	LED03PLACE
	LED03SKIPDARK

	LED04PLACE
	LED04SKIPDARK

	LED05PLACE
	LED05SKIPDARK

	LED06PLACE
	LED06SKIPDARK

	LED07PLACE
	LED07SKIPDARK

	LED08PLACE
	LED08SKIPDARK

	LED09PLACE
	LED09SKIPDARK

	LED10PLACE
	LED10SKIPDARK

	LED11PLACE
	LED11SKIPDARK

	LED12PLACE
	LED12SKIPDARK

	LED13PLACE
	LED13SKIPDARK

	LED14PLACE
	LED14SKIPDARK

	LED15PLACE
	LED15SKIPDARK

	LED16PLACE
	LED16SKIPDARK

	LED17PLACE
	LED17SKIPDARK

	LED18PLACE
	LED18SKIPDARK

	LED19PLACE
	LED19SKIPDARK

	LED20PLACE
	LED20SKIPDARK

	LED21PLACE
	LED21SKIPDARK

	LED22PLACE
	LED22SKIPDARK

	LED23PLACE
	LED23SKIPDARK

	LED24PLACE
	LED24SKIPDARK

	LED25PLACE
	LED25SKIPDARK

	LED26PLACE
	LED26SKIPDARK

	LED27PLACE
	LED27SKIPDARK

	LED28PLACE
	LED28SKIPDARK

	LED29PLACE
	LED29SKIPDARK

	LED30PLACE
	LED30SKIPDARK

	LED31PLACE
	LED31SKIPDARK

	LED32PLACE
	LED32SKIPDARK

	LED_COUNT		; Loop count for iterating over LEDs
	LED_BANK		; Which set of 8 LEDs we are working on 
	LED_MASK		; Mask to select 
	CYC_FLAGS1		; 
	ENDC

	CBLOCK	0xA0
;-------------------------------------------------------------------------------
;	The DROPxxVALUE are the current light values for each of the LEDs
;-------------------------------------------------------------------------------
	DRIP_LED01VALUE
	DRIP_LED02VALUE
	DRIP_LED03VALUE
	DRIP_LED04VALUE
	DRIP_LED05VALUE
	DRIP_LED06VALUE
	DRIP_LED07VALUE
	DRIP_LED08VALUE

	DRIP_LED09VALUE
	DRIP_LED10VALUE
	DRIP_LED11VALUE
	DRIP_LED12VALUE
	DRIP_LED13VALUE
	DRIP_LED14VALUE
	DRIP_LED15VALUE
	DRIP_LED16VALUE

	DRIP_LED17VALUE
	DRIP_LED18VALUE
	DRIP_LED19VALUE
	DRIP_LED20VALUE
	DRIP_LED21VALUE
	DRIP_LED22VALUE
	DRIP_LED23VALUE
	DRIP_LED24VALUE

	DRIP_LED25VALUE
	DRIP_LED26VALUE
	DRIP_LED27VALUE
	DRIP_LED28VALUE
	DRIP_LED29VALUE
	DRIP_LED30VALUE
	DRIP_LED31VALUE
	DRIP_LED32VALUE
	
	DRIP_DRIP	; Which stage of teh DRIP we are on (40-1)
	DRIP_REP	; Which cycle of drips we are on.  30-2 are fill
			;   1 is for when we drain the tree
	DRIP_TEMP	
	DRIP_TEMP2
	DRIP_COUNT
	DRIP_LIMIT
	DRIP_RANGE
	DRIP_LIGHT
; DRIP_LINESTEPx are the sequences for the 7 LEDs in the center of the tree
; They are initialized 4 out of phase out of each other so that when one light
; is going off, the next one is going on.
	DRIP_LINESTEP1
	DRIP_LINESTEP2
	DRIP_LINESTEP3
	DRIP_LINESTEP4
	DRIP_LINESTEP5
	DRIP_LINESTEP6
	DRIP_LINESTEP7
	ENDC

	CBLOCK	0xA0
;-------------------------------------------------------------------------------
;	These sets of variables are in Triplets.
;	The first LEDxxPLACE indicates where in the Lights or Dark Cycle the
;	sequence from 0-255.  When it overflows it switches from Light to Dark
;	The second LEDxxSKIPDARK combines the Light/Dark state (as the high bit)
;	and the remainder is the amount to increment the corresponding
;	LEDxxPLACE value by.
;	When the High Bit of the LEDxxSKIPDARK is cleared then the value in the
;	LEDxxPLACE is ignored and the LED is not lit for that time.  When
;	it is set, the value is used for indicating how bright to light the LED
;-------------------------------------------------------------------------------
	STRIPE0HPLACE
	STRIPE0HSKIP
	STRIPE0HSTATE

	STRIPE0LPLACE
	STRIPE0LSKIP
	STRIPE0LSTATE

	STRIPE1HPLACE
	STRIPE1HSKIP
	STRIPE1HSTATE

	STRIPE1LPLACE
	STRIPE1LSKIP
	STRIPE1LSTATE

	STRIPE2HPLACE
	STRIPE2HSKIP
	STRIPE2HSTATE

	STRIPE2LPLACE
	STRIPE2LSKIP
	STRIPE2LSTATE

	STRIPE3HPLACE
	STRIPE3HSKIP
	STRIPE3HSTATE

	STRIPE3LPLACE
	STRIPE3LSKIP
	STRIPE3LSTATE

	STRIPE_MASK
	STRIPE_COUNT
	ENDC

;-------------------------------------------------------------------------------
; Parameters for our sort function
;-------------------------------------------------------------------------------
SORT_ARRAY	EQU	TIME0
SORT_LENGTH	EQU	8
;*******************************************************************************
;****                                                                       ****
;****	Code starts here                                                    ****
;****                                                                       ****
;****   000 is where the processor goes on a reset                          ****
;****   001 is unused                                                       ****
;****   002 is unused                                                       ****
;****   003 is unused                                                       ****
;****   004 is where the processor goes on an interrupt                     ****
;*******************************************************************************
	ORG	0	;start address 0
	GOTO	START
	org	4	;Interrupt start
	RETFIE			; Return / Enable Global Interrupts
;*******************************************************************************

ERROR_INDEX
	BANKSEL	FSR
	MOVLW	B'1001000'
	MOVWF	PORTB
	MOVLW	B'10101010'
	MOVWF	PORTC
	SLEEP
	GOTO	ERROR_INDEX
;-------------------------------------------------------------------------------
; Function:
;    GET_TOGGLE
;    GET_INITIAL
; Purpose:
;    These return the lights on for the slot and the toggle value
; Parameters:
;    CUR_BANK - The bank to get the data for
; Notes:
;    This changes the contents of FSR/INDF
;-------------------------------------------------------------------------------
GET_TOGGLE
	MOVLW	BANK0		; Get the base offset to the table lookup
	ADDWF	CUR_BANK,W	; Add in the current bank selected
	MOVWF	FSR		; Point to that slot
	MOVF	INDF,W		; And get the value stored there
	BTFSC	CYC_FLAGS,F_NOFADE	
	GOTO	LOOKUP_INITIAL
	GOTO	LOOKUP_TOGGLE	; Use that to index into the table

GET_INITIAL
	MOVLW	BANK0		; Get the base offset to the table lookup
	ADDWF	CUR_BANK,W	; Add in the current bank selected
	MOVWF	FSR		; Point to that slot
	MOVF	INDF,W		; And get the value stored there
	GOTO	LOOKUP_INITIAL
;-------------------------------------------------------------------------------
; Function:		
;    GET_INITIALSCHEME		
; Purpose:		
;    This returns the initial SCHEME number to use		
; Parameters:		
;    WHICH_PATTERN - Pattern number to choose from		
; Notes:		
;-------------------------------------------------------------------------------
GET_INITIALSCHEME
	CLRC
	RLF	WHICH_PATTERN,W	; Pattern * 2
	ADDWF	WHICH_PATTERN,W	; Pattern * 3
	MOVWF	TEMP
	CLRC
	RLF	TEMP,W		; Pattern * 6
	MOVWF	TEMP
	RLF	TEMP,W		; Pattern * 12
	RETURN
;-------------------------------------------------------------------------------
; Refresh a single row of LEDs
; Parameters:
;	CUR_BANK - Which of the 4 banks of LEDs we are refreshing
;	TIME0-TIME7 - Times for each step of refresh
;	MASK0-MASK7 - Masks to put in bank for each of the steps
;-------------------------------------------------------------------------------
REFRESHCOL
	CLRWDT
	MOVLW	0xFF		; Load the value for all lights off
	MOVWF	PORTC		; And then turn them off
	CALL	GETBANKMASK	; Get the mask for this bank
	MOVWF	PORTB		; Then set the port to the right value
	MOVLW	MASK0
	MOVWF	FSR
REFRESHCOL_1
	MOVFW	INDF		; Get the mask value
	MOVWF	PORTC		; And output it
	MOVLW	TIME0-MASK0	; We want to get to the corresponding time for this mask
	ADDWF	FSR,F
	TSTF	INDF		; Make sure there is a non-zero amount to delay
	SKPNZ
	GOTO	REFRESHCOL_3
	BTFSC	PORTA,0		; Are we on USB POWER?
	GOTO	REFRESHCOL_USB	; ; Yes

REFRESHCOL_2			; wait for the amount specified so the lights are on
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	DECFSZ	INDF,F		; See if we have delayed enough
	GOTO	REFRESHCOL_2
	GOTO	REFRESHCOL_3

REFRESHCOL_USB			; wait for the amount specified so the lights are on
	DECFSZ	INDF,F		; See if we have delayed enough
	GOTO	REFRESHCOL_USB

REFRESHCOL_3			; Advance to the next spot
	MOVLW	TIME7		; Have we hit the last timer
	SUBWF	FSR,W		;
	SKPNZ
	GOTO	REFRESHCOL_4	; Yes, so we are done
	MOVLW	MASK0-TIME0+1	; NO, more timers to hit, so keep going
	ADDWF	FSR,F		; Point to the next MASKx value
	GOTO	REFRESHCOL_1
REFRESHCOL_4
	MOVLW	0xFF		; Load the value for all lights off
	MOVWF	PORTC		; And then turn them off
	CLRF	PORTB		; Unselect all ports
	RETURN

;-------------------------------------------------------------------------------
; This is the main routine which starts the tree off
;-------------------------------------------------------------------------------
START
;
; Turn off all the LEDs immediately
;
	MOVLW	B'11111111'
	MOVWF	PORTC
	CLRF	PORTB
	CLRF	PORTA
	BCF	T1CON,TMR1ON	; Turn off Timer1
	CLRF	INTCON

	BANKSEL	ANSELH		;---BANK2
	CLRF	ANSEL&H'1F'	; Set up the Ports for Digital output
	CLRF	ANSELH&H'1F'
	CLRF	WPUB&H'1F'

	BANKSEL	TRISB		;---BANK1
	BCF	GLOBAL_FLAGS,F_POWERON
	BTFSS	PCON,NOT_POR
	BSF	GLOBAL_FLAGS,F_POWERON

	MOVLW	B'00000001'
	MOVWF	TRISA&H'1F'
	CLRF	TRISB&H'1F'
	CLRF	TRISC&H'1F'
	MOVLW	(1<<IRCF2)|(1<<IRCF1)|(1<<SCS)  ; Set processor to 4MhZ,
	MOVWF	OSCCON&H'1F'	; Internal oscillator
	CLRF	PIE1		; Disable all peripheral interrupts

; bit 7	T1GINV: Timer1 Gate Invert bit(1)
;	1 = Timer1 gate is active high (Timer1 counts when Timer1 gate signal is high)
;	0 = Timer1 gate is active low (Timer1 counts when gate is low)
; bit 6	TMR1GE: Timer1 Gate Enable bit(2)
;	If TMR1ON = 0:
;		This bit is ignored
;	If TMR1ON = 1:
;		1 = Timer1 counting is controlled by the Timer1 Gate function
;		0 = Timer1 is always counting
; bit 5-4 T1CKPS<1:0>: Timer1 Input Clock Prescale Select bits
;	11 = 1:8 Prescale Value
;	10 = 1:4 Prescale Value
;	01 = 1:2 Prescale Value
;	00 = 1:1 Prescale Value
; bit 3	T1OSCEN: LP Oscillator Enable Control bit
;	If INTOSC without CLKOUT oscillator is active:
;		1 = LP oscillator is enabled for Timer1 clock
;		0 = LP oscillator is off
;	Else:
;		This bit is ignored
; bit 2	T1SYNC: Timer1 External Clock Input Synchronization Control bit
;	TMR1CS = 1:
;		1 = Do not synchronize external clock input
;		0 = Synchronize external clock input
;	TMR1CS = 0:
;		This bit is ignored. Timer1 uses the internal clock
; bit 1	TMR1CS: Timer1 Clock Source Select bit
;	1 = External clock from T1CKI pin (on the rising edge)
;	0 = Internal clock (FOSC/4)
; bit 0	TMR1ON: Timer1 On bit
;	1 = Enables Timer1
;	0 = Stops Timer1
				;
;
; Initialize the Special Function Registers (SFR) interrupts
;
	BANKSEL	PIR1	;---BANK0
	CLRF	PIR1		;
	MOVLW	(0<<T1GINV)|(0<<TMR1GE)|(1<<T1CKPS1)|(0<<T1CKPS0)|(1<<T1OSCEN)|(0<<NOT_T1SYNC)|(0<<TMR1CS)|(0<<TMR1ON)
	MOVWF	T1CON		; Enable T1 Oscillator, Internal Clock Sync
				; prescaler = 1:4
	BSF	T1CON, TMR1ON	; Turn Timer1 ON

	BSF	RANDOMV,4	; Ensure non-zer random number seed

	MOVLW	.255
	MOVWF	IDLE_CTR	; Time to enable the power off switch
	BTFSS	GLOBAL_FLAGS,F_POWERON
	GOTO	NOTFIRST
;
;	First time we are running, so do the startup pattern first
;
	CLRF	GLOBAL_FLAGS
	MOVLW	PAT_STARTUP
	MOVWF	WHICH_PATTERN
	GOTO	RUNCODE

;
;	We are hitting the power button so just advance which pattern we are running
;
NOTFIRST
	BTFSS	GLOBAL_FLAGS,F_DOSHUTDOWN	; Time to shut down?
	GOTO	INC_PATTERN			; No
	BCF	GLOBAL_FLAGS,F_DOSHUTDOWN	; Yes, clear the shutdown
	MOVFW	WHICH_PATTERN			; Save the pattern
	MOVWF	SAVE_PATTERN
	BSF	GLOBAL_FLAGS,F_SHUTTING		; And remember we are shutting
	MOVLW	PAT_POWERDOWN			; Select the shutdown pattern
	MOVWF	WHICH_PATTERN
	GOTO	RUNCODE				; And run the pattern.

INC_PATTERN
	MOVFW	SAVE_PATTERN			; Retreive the last pattern
	BTFSC	GLOBAL_FLAGS,F_SHUTTING		; Were we shutting down?
	MOVWF	WHICH_PATTERN			; Yes so restore it
	BCF	GLOBAL_FLAGS,F_SHUTTING		; And clear shutting down
	INCF	WHICH_PATTERN,F			; Incremement to next pattern
	MOVF	WHICH_PATTERN,W			; And see if we 
	SUBLW	PAT_POWERDOWN-1			;  are past the last pattern
	SKPC
RUN_FIRSTSCHEME
;	If we overflow or somehow get past the last pattern, just reset
;	to the beginning.  This happens after we go to sleep and reset
	CLRF	WHICH_PATTERN

RUNCODE
	BANKSEL	PCON
	BSF	PCON,NOT_POR
	BANKSEL	FSR

	MOVLW	REFRESH_INTERVAL
	ADDWF	TMR1H,W		; Set the time for the next refresh
	MOVWF	REFRESH_TIME

MAIN
	CALL	GET_INITIALSCHEME	; Convert the scheme # to a pointer
	MOVWF	SCHEME			; And point to the table start

;-------------------------------------------------------------------------------
;		
;	Initialize the template data for this scheme. We start with the number
;	of times we will run the scheme separate so we can reload the other
;	data when we wrap without affecting the countdown
;
;-------------------------------------------------------------------------------
NEXT_SCHEME

	CALL	GET_SCHEMEDATA	; Point to the table start
	MOVWF	SCHEME_CTR	; Get the # of times we run this scheme

	MOVF	SCHEME,W	; Save pointer to rest of the data
	MOVWF	CUR_SCHEME	; So we can reload when we restart

	BSF	GLOBAL_FLAGS,F_DOINIT	; We need to init this scheme

RESTART_SCHEME
	MOVF	CUR_SCHEME,W	; Point to the data for this scheme
	MOVWF	SCHEME

	CALL	GET_SCHEMEDATA	; Get the number of loops for a cycle
	MOVWF	ITER_LIMIT
		
	CALL	GET_SCHEMEDATA	; The start of the table
	MOVWF	BASE

	CALL	GET_SCHEMEDATA	; The end of the table
	MOVWF	LIMIT

	CALL	GET_SCHEMEDATA	; Data for first LED Bank (or function pointer)
	MOVWF	BANK0

	CALL	GET_SCHEMEDATA	; Data for second LED Bank (or function pointer)
	MOVWF	BANK1

	CALL	GET_SCHEMEDATA	; Data for Third LED Bank (or Parm1)
	MOVWF	BANK2

	CALL	GET_SCHEMEDATA	; Data for Forth LED Bank (or Parm2)
	MOVWF	BANK3

	CALL	GET_SCHEMEDATA	; Flags for running this scheme
	MOVWF	CYC_FLAGS

	CALL	GET_SCHEMEDATA	; Flags for running this scheme
	MOVWF	CUR_SKIP

	CALL	GET_SCHEMEDATA	; Flags for running this scheme
	MOVWF	SEL_SEQ2
	ANDLW	B'00001111'
	MOVWF	SEL_SEQ1
	SWAPF	SEL_SEQ2,W
	ANDLW	B'00001111'
	MOVWF	SEL_SEQ2

	CALL	GET_SCHEMEDATA	; Pointer to next scheme
	MOVWF	SCHEME

	BTFSS	GLOBAL_FLAGS,F_DOINIT
	GOTO	BEGIN_SCHEME	; Already initialized
;
; For table functions we call the first entry anyway since there is really
; no harm in doing that - it only returns a value which we simply ignore
;
;;	BTFSC	CYC_FLAGS,F_TABLE
;;	GOTO	BEGIN_SCHEME	; Table driven, no init necessary
	MOVFW	BANK0
	CALL	LOOKUP_INITIAL	; Call the initialization function
BEGIN_SCHEME
;
;	Get the iteration limit values again.  Note that they may have
;	changed if we switched to/from USB power
;
	MOVFW	ITER_LIMIT
	MOVWF	ITER_CTR
	CLRF	EXTRA_CTR
	MOVFW	SEL_SEQ1
	MOVWF	CUR_SEQ1
	MOVFW	SEL_SEQ2
	MOVWF	CUR_SEQ2
;-------------------------------------------------------------------------------
;		
;       Walk through all the lights and set them to the current slot value		
;		
;-------------------------------------------------------------------------------
AGAIN_SCHEME
	MOVFW	REFRESH_TIME	; When are we supposed to wait until?
	SUBWF	TMR1H,W		; Is it that time now?
	SKPZ			; Yes, so on with the show
	GOTO	AGAIN_SCHEME	; No, so wait some more

	MOVLW	REFRESH_INTERVAL
	ADDWF	TMR1H,W		; Set the time for the next refresh
	MOVWF	REFRESH_TIME

;
; Refresh the lights
;
	CLRF	CUR_BANK
REFRESH_BANK
	BTFSS	CYC_FLAGS,F_TABLE
	GOTO	REFRESH_BANKFUNC
	
	CALL	GET_INITIAL
	MOVWF	MASK0
	CALL	GET_TOGGLE
	MOVWF	MASK1
	MOVLW	B'11111111'
	MOVWF	MASK2
	MOVWF	MASK3
	MOVWF	MASK4
	MOVWF	MASK5
	MOVWF	MASK6
	MOVWF	MASK7

	MOVFW	EXTRA_CTR
	MOVWF	TIME1
	SUBLW	MAX_ITERATIONS
	MOVWF	TIME0
	CLRF	TIME2
	CLRF	TIME3
	CLRF	TIME4
	CLRF	TIME5
	CLRF	TIME6
	CLRF	TIME7
	GOTO	REFRESH_1

REFRESH_BANKFUNC
	MOVFW	BANK1
	CALL	LOOKUP_INITIAL	; Call the Get function
	CALL	CALC_TIMES	; And then sort the array for refresh

REFRESH_1
	CALL	REFRESHCOL
	INCF	CUR_BANK,F	; And increment the bank pointer
	BTFSS	CUR_BANK,2	; Until we have hit all four of them
	GOTO	REFRESH_BANK

;
;	See if we have been running long enough to enable the powerdown
;
	DECF	IDLE_CTR,F		; Count down our idle timer
	SKPNZ
	BSF	GLOBAL_FLAGS,F_DOSHUTDOWN	; Powerdown on next button

;
;	Advance the Counter
;
	MOVFW	CUR_SKIP
	ADDWF	EXTRA_CTR,F
	DECFSZ	CUR_SEQ1
	GOTO	NOADV1
	INCF	EXTRA_CTR,F
	MOVFW	SEL_SEQ1
	MOVWF	CUR_SEQ1

NOADV1
	DECFSZ	CUR_SEQ2
	GOTO	NOADV2
	INCF	EXTRA_CTR,F
	MOVFW	SEL_SEQ2
	MOVWF	CUR_SEQ2

NOADV2
	DECFSZ	ITER_CTR
	GOTO	AGAIN_SCHEME
;
; Advance to the next spot
;
	BTFSS	CYC_FLAGS,F_TABLE
	GOTO	ADVANCE_FUNC

	CLRF	CUR_BANK	; Iterate through all 4 banks
	MOVLW	BANK0		; Point to the first bank
	MOVWF	FSR		; And make that our pointer
ADVANCE_BANK
	INCF	INDF,F		; Increment the bank slot for the cycle
	MOVF	INDF,W		; Get the result
	SUBWF	LIMIT,W		; Compare to the limit?
	SKPNC			; Skip if we are above the limit
	GOTO	ADVANCE_BANK_0	; No, we are fine
;
;	At this point, we have reached the end of the table for one of the slots
;	Remember that this happened
;
	MOVF	BASE,W		; Wrap back to the beginning
	MOVWF	INDF
	BSF	GLOBAL_FLAGS,F_COMPLETE	; And remember we hit the end

ADVANCE_BANK_0
	INCF	FSR		; Point to the next bank
	INCF	CUR_BANK,F	; And increment the bank pointer
	BTFSS	CUR_BANK,2	; Until we have hit all four of them
	GOTO	ADVANCE_BANK
	GOTO	ADVANCE_DONE
ADVANCE_FUNC
	MOVFW	BANK0
	CALL	LOOKUP_TOGGLE	; Call the Advance function

ADVANCE_DONE
	BTFSS	GLOBAL_FLAGS,F_COMPLETE	; Did we complete a cycle?
	GOTO	BEGIN_SCHEME	; No, so run the scheme again

CYCLE_COMPLETE
	BCF	GLOBAL_FLAGS,F_COMPLETE
	BTFSS	CYC_FLAGS,F_DOSLEEP	; Is this the powerdown sequence?
	GOTO	CHECK_STARTUP
;
;	If the powerdown bit is set for the current scheme we want to sleep
;
	BANKSEL	PCON
	BCF	PCON,NOT_POR
	BANKSEL	FSR
	CLRF	PORTB
	MOVLW	0xFF	; Load the value for all lights off
	MOVWF	PORTC	; And then turn them off
	SLEEP
	GOTO	START

CHECK_STARTUP
	BTFSC	CYC_FLAGS,F_STARTUP	; Is this the startup sequence
	GOTO	RUN_FIRSTSCHEME		; Yes, so just start all from scratch

	DECFSZ	SCHEME_CTR,F
	GOTO	CHECK_WRAP

	TSTF	WHICH_PATTERN	; Are we running the loop sequence of schemes?
	SKPNZ			; 
	GOTO	NEXT_SCHEME	; Yes, so advance to the next scheme

CHECK_WRAP
;		
;       For the NOWRAP items, we want to cycle back to the start of the scheme		
;		
	BTFSS	CYC_FLAGS,F_NOWRAP
	GOTO	BEGIN_SCHEME
	GOTO	RESTART_SCHEME
;*************************************************************************************			
;;ORG	H'100'	
;-------------------------------------------------------------------------------
;			
; This returns the appropriate mask for the selected bank			
;			
;-------------------------------------------------------------------------------
GETBANKMASK
	MOVF	CUR_BANK,W
	STARTTABLE	BANK_MASK
	DT	B'10000000'	; BANK_MASK0
	DT	B'01000000'	; BANK_MASK1
	DT	B'00100000'	; BANK_MASK2
	DT	B'00010000'	; BANK_MASK3
	ENDTABLE
;-------------------------------------------------------------------------------
;			
; Bank 1			
;			
;-------------------------------------------------------------------------------
	STARTTABLE	LOOKUP_INITIAL
;
; This is our basic on off scheme
;
TABLE0
TAB_ONOFF
TAB_STARTUP
TAB_STARTUP9999
	RETLW	B'11111111'	; 0 - Off, then turn on
	RETLW	B'00000000'	; 1 - On, then turn off
TAB_ONOFF9999
	RETLW	B'11111111'	; 2 - Off, stay off
;
; This is the single color scheme
;
TAB_ONECOLOR
	RETLW	B'11111111'	; 3
	RETLW	B'01110111'	; 4
	RETLW	B'01110111'	; 5
	RETLW	B'11111111'	; 6
	RETLW	B'10111011'	; 7
	RETLW	B'10111011'	; 8
	RETLW	B'11111111'	; 9
	RETLW	B'11011101'	; 10
	RETLW	B'11011101'	; 11
	RETLW	B'11111111'	; 12
	RETLW	B'11101110'	; 13
TAB_ONECOLOR9999
	RETLW	B'11101110'	; 14
;
; This is the cycling down
;
TAB_CYCLEDOWN
	RETLW	B'01110111'	; 15
	RETLW	B'01110111'	; 16
	RETLW	B'10111011'	; 17
	RETLW	B'10111011'	; 18
	RETLW	B'11011101'	; 19
	RETLW	B'11011101'	; 20
	RETLW	B'11101110'	; 21
TAB_CYCLEDOWN9999
	RETLW	B'11101110'	; 22
TAB_SWING
	RETLW	B'01111111'	; 23
	RETLW	B'01111111'	; 24
	RETLW	B'00001111'	; 25
	RETLW	B'00000000'	; 26
	RETLW	B'00001111'	; 27
	RETLW	B'01111111'	; 28
	RETLW	B'01111111'	; 29
	RETLW	B'00001111'	; 30
	RETLW	B'00000000'	; 31
	RETLW	B'00001111'	; 32

	RETLW	B'11111111'	; 33
	RETLW	B'11111111'	; 34
	RETLW	B'11110000'	; 35
	RETLW	B'11111111'	; 36
	RETLW	B'00001111'	; 37
	RETLW	B'11111111'	; 38
	RETLW	B'11111111'	; 39
	RETLW	B'00001111'	; 40
	RETLW	B'11111111'	; 41
	RETLW	B'11110000'	; 42

	RETLW	B'00000000'	; 43
	RETLW	B'00000000'	; 44
	RETLW	B'11111111'	; 45
	RETLW	B'11111111'	; 46
	RETLW	B'11111111'	; 47
	RETLW	B'11111111'	; 48
	RETLW	B'11111111'	; 49
	RETLW	B'11111111'	; 50
	RETLW	B'11111111'	; 51
	RETLW	B'11111111'	; 52

	RETLW	B'11111111'	; 53
	RETLW	B'11111111'	; 54
	RETLW	B'11111111'	; 55
	RETLW	B'11111111'	; 56
	RETLW	B'11111111'	; 57
	RETLW	B'00000000'	; 58
	RETLW	B'00000000'	; 59
	RETLW	B'11111111'	; 60
	RETLW	B'11111111'	; 61
TAB_SWING9999
	RETLW	B'11111111'	; 62

TAB_RANDOM
	GOTO	INIT_RANDOM	; 63
	GOTO	SHOW_RANDOM	; 64
TAB_RANDOM9999
;
; This is the fountain
;
TAB_FOUNTAIN
	RETLW	B'11111110'	; 65
	RETLW	B'11111100'	; 66
	RETLW	B'11111001'	; 67
	RETLW	B'11110011'	; 68
	RETLW	B'11100111'	; 69
	RETLW	B'11001111'	; 70
	RETLW	B'10011111'	; 71
	RETLW	B'00111111'	; 72
	RETLW	B'01111111'	; 73
	RETLW	B'01111111'	; 74
	RETLW	B'00111111'	; 75
	RETLW	B'00011111'	; 76
	RETLW	B'10101111'	; 77
	RETLW	B'01010111'	; 78
	RETLW	B'10101011'	; 79
	RETLW	B'01010101'	; 80
	RETLW	B'10101010'	; 81
	RETLW	B'00000000'	; 82

	RETLW	B'11111111'	;83
	RETLW	B'11111111'	;84
	RETLW	B'11111111'	;85
	RETLW	B'11111111'	;86
	RETLW	B'11111111'	;87
	RETLW	B'11111111'	;88
	RETLW	B'11111111'	;89
	RETLW	B'11111111'	;90
	RETLW	B'11111111'	;91
	RETLW	B'11111111'	;92
	RETLW	B'11111111'	;93
	RETLW	B'11111111'	;94
	RETLW	B'11111111'	;95
	RETLW	B'01110111'	;96
	RETLW	B'10111011'	;97
	RETLW	B'01010101'	;98
	RETLW	B'10101010'	;99
	RETLW	B'00000000'	;100

	RETLW	B'11111111'	; 101
	RETLW	B'11111111'	; 102
	RETLW	B'11111111'	; 103
	RETLW	B'11111111'	; 104
	RETLW	B'11111111'	; 105
	RETLW	B'11111111'	; 106
	RETLW	B'11111111'	; 107
	RETLW	B'11111111'	; 108
	RETLW	B'11111111'	; 109
	RETLW	B'01111111'	; 110
	RETLW	B'10111111'	; 111
	RETLW	B'01011111'	; 112
	RETLW	B'10101111'	; 113
	RETLW	B'01010111'	; 114
	RETLW	B'10101011'	; 115
	RETLW	B'01010101'	; 116
	RETLW	B'10101010'	; 117
TAB_FOUNTAIN9999
	RETLW	B'00000000'	; 118
;
; This is the marquis effect			
;
TAB_MARQUIS
	RETLW	B'11111111'	; 119
	RETLW	B'01111111'	; 120
	RETLW	B'01111111'	; 121
	RETLW	B'11111111'	; 122
	RETLW	B'11111111'	; 123
	RETLW	B'11111111'	; 124

	RETLW	B'11111111'	; 125
	RETLW	B'11101110'	; 126
	RETLW	B'11101110'	; 127
	RETLW	B'11111111'	; 128
	RETLW	B'11111111'	; 129
	RETLW	B'11111111'	; 130

	RETLW	B'10110110'	; 131
	RETLW	B'11011011'	; 132
	RETLW	B'11011011'	; 133
	RETLW	B'01101101'	; 134
	RETLW	B'01101101'	; 135
	RETLW	B'10110110'	; 136

	RETLW	B'01101101'	; 137
	RETLW	B'11011011'	; 138
	RETLW	B'11011011'	; 139
	RETLW	B'10110110'	; 140
	RETLW	B'10110110'	; 141
TAB_MARQUIS9999			
	RETLW	B'01101101'	; 142
;			
; This is the powerdown Scheme			
;			
TAB_POWERDOWN			
	RETLW	B'00000000'	; 143
	RETLW	B'00000000'	; 144
	RETLW	B'10000000'	; 145
	RETLW	B'10000011'	; 146
	RETLW	B'11000111'	; 147
	RETLW	B'11101111'	; 148
	RETLW	B'11101111'	; 149

	RETLW	B'00000000'	; 150
	RETLW	B'00000000'	; 151
	RETLW	B'00010001'	; 152
	RETLW	B'00110011'	; 153
	RETLW	B'01110111'	; 154
	RETLW	B'11111111'	; 155
	RETLW	B'11111111'	; 156

	RETLW	B'00000000'	; 157
	RETLW	B'00000000'	; 158
	RETLW	B'00000001'	; 159
	RETLW	B'10000011'	; 160
	RETLW	B'11000111'	; 161
	RETLW	B'11101111'	; 162
TAB_POWERDOWN9999			
	RETLW	B'11111111'	; 163
	
TAB_STAR
        RETLW   B'11111111'     ; 164
        RETLW   B'11110111'     ; 165
        RETLW   B'11111111'     ; 166
        RETLW   B'11101111'     ; 167
        RETLW   B'11011011'     ; 168
        RETLW   B'10111101'     ; 169
        RETLW   B'11111110'     ; 170
        RETLW   B'01111111'     ; 171

        RETLW   B'11111111'     ; 172
        RETLW   B'11111111'     ; 173
        RETLW   B'11111111'     ; 174
        RETLW   B'01110111'     ; 175
        RETLW   B'11111111'     ; 176
        RETLW   B'10111011'     ; 177
        RETLW   B'11011101'     ; 178
        RETLW   B'11111111'     ; 179

        RETLW   B'11111111'     ; 180
        RETLW   B'11111111'     ; 181
        RETLW   B'11111111'     ; 182
        RETLW   B'11111111'     ; 183
        RETLW   B'11000111'     ; 184
        RETLW   B'10111011'     ; 185
        RETLW   B'01111101'     ; 186
        RETLW   B'11111110'     ; 187

        RETLW   B'11111111'     ; 188
        RETLW   B'11111111'     ; 189
        RETLW   B'11111111'     ; 190
        RETLW   B'11111111'     ; 191
        RETLW   B'11000111'     ; 192
        RETLW   B'10111011'     ; 193
        RETLW   B'01111101'     ; 194
TAB_STAR9999
        RETLW   B'11111110'     ; 195

TAB_DRIP
	GOTO	INIT_DRIP	; 196
	GOTO	REFRESH_DRIP	; 197
TAB_DRIP9999

	ENDTABLE

;*******************************************************************************
	ORG	H'200'
;-------------------------------------------------------------------------------
;			
; Bank 2			
;			
;-------------------------------------------------------------------------------
	STARTTABLE	LOOKUP_TOGGLE
;
; This is our basic on off scheme
;
TOG_ONOFF
TOG_STARTUP
	RETLW	B'00000000'	; 0 - Off, then turn on
	RETLW	B'11111111'	; 1 - On, then turn off
	RETLW	B'11111111'	; 2 - Off, stay off
;
; This is the single color scheme
;
TOG_ONECOLOR
	RETLW	B'01110111'	; 3
	RETLW	B'01110111'	; 4
	RETLW	B'11111111'	; 5
	RETLW	B'10111011'	; 6
	RETLW	B'10111011'	; 7
	RETLW	B'11111111'	; 8
	RETLW	B'11011101'	; 9
	RETLW	B'11011101'	; 10
	RETLW	B'11111111'	; 11
	RETLW	B'11101110'	; 12
	RETLW	B'11101110'	; 13
	RETLW	B'11111111'	; 14
;
; This is the cycling down
;
TOG_CYCLEDOWN
	RETLW	B'01110111'	; 15
	RETLW	B'10111011'	; 16
	RETLW	B'10111011'	; 17
	RETLW	B'11011101'	; 18
	RETLW	B'11011101'	; 19
	RETLW	B'11101110'	; 20
	RETLW	B'11101110'	; 21
	RETLW	B'01110111'	; 22
TOG_SWING
	RETLW	B'01111111'	; 23
	RETLW	B'00001111'	; 24
	RETLW	B'00000000'	; 25
	RETLW	B'00001111'	; 26
	RETLW	B'01111111'	; 27
	RETLW	B'01111111'	; 28
	RETLW	B'00001111'	; 29
	RETLW	B'00000000'	; 30
	RETLW	B'00001111'	; 31
	RETLW	B'01111111'	; 32

	RETLW	B'11111111'	; 33
	RETLW	B'11110000'	; 34
	RETLW	B'11111111'	; 35
	RETLW	B'00001111'	; 36
	RETLW	B'11111111'	; 37
	RETLW	B'11111111'	; 38
	RETLW	B'00001111'	; 39
	RETLW	B'11111111'	; 40
	RETLW	B'11110000'	; 41
	RETLW	B'11111111'	; 42

	RETLW	B'00000000'	; 43
	RETLW	B'11111111'	; 44
	RETLW	B'11111111'	; 45
	RETLW	B'11111111'	; 46
	RETLW	B'11111111'	; 47
	RETLW	B'11111111'	; 48
	RETLW	B'11111111'	; 49
	RETLW	B'11111111'	; 50
	RETLW	B'11111111'	; 51
	RETLW	B'00000000'	; 52

	RETLW	B'11111111'	; 53
	RETLW	B'11111111'	; 54
	RETLW	B'11111111'	; 55
	RETLW	B'11111111'	; 56
	RETLW	B'00000000'	; 57
	RETLW	B'00000000'	; 58
	RETLW	B'11111111'	; 59
	RETLW	B'11111111'	; 60
	RETLW	B'11111111'	; 61
	RETLW	B'11111111'	; 62

TOG_RANDOM
	GOTO	ADVANCE_RANDOM	; 63
	RETURN			; 64
;
; This is the fountain
;
TOG_FOUNTAIN
	RETLW	B'11111100'	; 65
	RETLW	B'11111001'	; 66
	RETLW	B'11110011'	; 67
	RETLW	B'11100111'	; 68
	RETLW	B'11001111'	; 69
	RETLW	B'10011111'	; 70
	RETLW	B'00111111'	; 71
	RETLW	B'01111111'	; 72
	RETLW	B'01111111'	; 73
	RETLW	B'00111111'	; 74
	RETLW	B'00011111'	; 75
	RETLW	B'10101111'	; 76
	RETLW	B'01010111'	; 77
	RETLW	B'10101011'	; 78
	RETLW	B'01010101'	; 79
	RETLW	B'10101010'	; 80
	RETLW	B'00000000'	; 81
	RETLW	B'11111111'	; 82

	RETLW	B'11111111'	;83
	RETLW	B'11111111'	;84
	RETLW	B'11111111'	;85
	RETLW	B'11111111'	;86
	RETLW	B'11111111'	;87
	RETLW	B'11111111'	;88
	RETLW	B'11111111'	;89
	RETLW	B'11111111'	;90
	RETLW	B'11111111'	;91
	RETLW	B'11111111'	;92
	RETLW	B'11111111'	;93
	RETLW	B'11111111'	;94
	RETLW	B'01110111'	;95
	RETLW	B'10111011'	;96
	RETLW	B'01010101'	;97
	RETLW	B'10101010'	;98
	RETLW	B'00000000'	;99
	RETLW	B'11111111'	;100

	RETLW	B'11111111'	; 101
	RETLW	B'11111111'	; 102
	RETLW	B'11111111'	; 103
	RETLW	B'11111111'	; 104
	RETLW	B'11111111'	; 105
	RETLW	B'11111111'	; 106
	RETLW	B'11111111'	; 107
	RETLW	B'11111111'	; 108
	RETLW	B'01111111'	; 109
	RETLW	B'10111111'	; 110
	RETLW	B'01011111'	; 111
	RETLW	B'10101111'	; 112
	RETLW	B'01010111'	; 113
	RETLW	B'10101011'	; 114
	RETLW	B'01010101'	; 115
	RETLW	B'10101010'	; 116
	RETLW	B'00000000'	; 117
	RETLW	B'11111111'	; 118
;
; This is the marquis effect
;
TOG_MARQUIS
	RETLW	B'01111111'	; 119
	RETLW	B'01111111'	; 120
	RETLW	B'11111111'	; 121
	RETLW	B'11111111'	; 122
	RETLW	B'11111111'	; 123
	RETLW	B'11111111'	; 124

	RETLW	B'11101110'	; 125
	RETLW	B'11101110'	; 126
	RETLW	B'11111111'	; 127
	RETLW	B'11111111'	; 128
	RETLW	B'11111111'	; 129
	RETLW	B'11111111'	; 130

	RETLW	B'11011011'	; 131
	RETLW	B'11011011'	; 132
	RETLW	B'01101101'	; 133
	RETLW	B'01101101'	; 134
	RETLW	B'10110110'	; 135
	RETLW	B'10110110'	; 136

	RETLW	B'11011011'	; 137
	RETLW	B'11011011'	; 138
	RETLW	B'10110110'	; 139
	RETLW	B'10110110'	; 140
	RETLW	B'01101101'	; 141
	RETLW	B'01101101'	; 142
;
; This is the powerdown Scheme
;
TOG_POWERDOWN			
	RETLW	B'00000000'	; 143
	RETLW	B'10000000'	; 144
	RETLW	B'10000011'	; 145
	RETLW	B'11000111'	; 146
	RETLW	B'11101111'	; 147
	RETLW	B'11101111'	; 148
	RETLW	B'11111111'	; 149

	RETLW	B'00000000'	; 150
	RETLW	B'00010001'	; 151
	RETLW	B'00110011'	; 152
	RETLW	B'01110111'	; 153
	RETLW	B'11111111'	; 154
	RETLW	B'11111111'	; 155
	RETLW	B'11111111'	; 156

	RETLW	B'00000000'	; 157
	RETLW	B'00000001'	; 158
	RETLW	B'10000011'	; 159
	RETLW	B'11000111'	; 160
	RETLW	B'11101111'	; 161
	RETLW	B'11111111'	; 162
	RETLW	B'11111111'	; 163

TOG_STAR
        RETLW   B'11110111'     ; 164
        RETLW   B'11110111'     ; 165
        RETLW   B'11101111'     ; 166
        RETLW   B'11001011'     ; 167
        RETLW   B'10011001'     ; 168
        RETLW   B'10111100'     ; 169
        RETLW   B'01111110'     ; 170
        RETLW   B'01111111'     ; 171

        RETLW   B'11111111'     ; 172
        RETLW   B'11111111'     ; 173
        RETLW   B'01110111'     ; 174
        RETLW   B'01110111'     ; 175
        RETLW   B'10111011'     ; 176
        RETLW   B'10011001'     ; 177
        RETLW   B'11001100'     ; 178
        RETLW   B'11111111'     ; 179

        RETLW   B'11111111'     ; 180
        RETLW   B'11111111'     ; 181
        RETLW   B'11111111'     ; 182
        RETLW   B'11000111'     ; 183
        RETLW   B'10000011'     ; 184
        RETLW   B'00111001'     ; 185
        RETLW   B'01111100'     ; 186
        RETLW   B'11111110'     ; 187

        RETLW   B'11111111'     ; 188
        RETLW   B'11111111'     ; 189
        RETLW   B'11111111'     ; 190
        RETLW   B'11000111'     ; 191
        RETLW   B'10000011'     ; 192
        RETLW   B'00111001'     ; 193
        RETLW   B'01111100'     ; 194
        RETLW   B'11111110'     ; 195
TOG_DRIP
	GOTO	ADVANCE_DRIP	; 196
	RETURN			; 197

	ENDTABLE

	ORG	H'300'
;-------------------------------------------------------------------------------
; Function:		
;    GET_SCHEMEDATA
; Purpose:		
;    This returns current entry in the scheme table and advances to the next one		
; Parameters:		
;    SCHEME - The current entry to get the data for		
; Notes:		
;    Because this jumps to another bank, you must use the BCALL macro to		
;    get to the function - hence the addition of the 0 to the end of the name		
;-------------------------------------------------------------------------------
GET_SCHEMEDATA
	MOVF	SCHEME,W
	INCF	SCHEME,F
	GOTO	LOOKUP_SCHEMEDATA
	STARTTABLE	LOOKUP_SCHEMEDATA

;-------Marquis     38 Seconds
	DEFSCHEME	PAT_MARQUIS,.44,.8,TAB_MARQUIS,.18,.12,.6,.0,PAT_GLOW,M_NOWRAP
;-------Glowing Lights
	DEFCALLSCHEME	PAT_GLOW,.209,TAB_RANDOM,M_DARKCYCLE|B'111',.10,PAT_CYCLEDOWN,0
;-------Cycling down
	DEFSCHEME	PAT_CYCLEDOWN,.11,.24,TAB_CYCLEDOWN,.0,.0,.0,.0,PAT_FOUNTAIN,0
;-------Fountain
	DEFSCHEME	PAT_FOUNTAIN,.6,.20,TAB_FOUNTAIN,.36,.36,.18,.0,PAT_ONECOLOR,M_NOWRAP
;-------Single color cycle
; 	.200 for the second number gives us the long Anticipation time.
	DEFSCHEME	PAT_ONECOLOR,.10,.35,TAB_ONECOLOR,.0,.0,.6,.6,PAT_STAR,0
;-------Star Pattern
	DEFSCHEME	PAT_STAR,.12,.30,TAB_STAR,.24,.16,.8,0,PAT_BLINKING,M_NOWRAP
;-------Blinking Lights  52 seconds
	DEFCALLSCHEME	PAT_BLINKING,.209,TAB_RANDOM,M_DARKCYCLE|B'111',.10,PAT_SWING,M_NOFADE
;-------Swing Pattern
	DEFSCHEME	PAT_SWING,.12,.18,TAB_SWING,.30,.20,.10,0,PAT_FLASHING,M_NOWRAP
;-------Flashing Lights  22 Seconds
	DEFCALLSCHEME	PAT_FLASHING,.209,TAB_RANDOM,M_DARKCYCLE|B'11000',.10,PAT_DRIP,M_NOFADE
;-------Drip
;	NOTE: The init routine sets F_COMPLETE so you add one to the number of
;	      times to run it in cycle mode.
	DEFCALLSCHEME	PAT_DRIP,.3,TAB_DRIP,.0,.0,PAT_ONOFF,0
;-------Lights on/off cycle  14 seconds
	DEFSCHEME	PAT_ONOFF,.5,.140,TAB_ONOFF,.0,.0,.0,.0,PAT_MARQUIS,0
;-------Powerdown
	DEFSCHEME	PAT_POWERDOWN,.1,.8,TAB_POWERDOWN,.14,.14,.7,.0,PAT_STARTUP,M_DOSLEEP|M_NOWRAP
;-------Powerup
	DEFSCHEME	PAT_STARTUP,.1,.100,TAB_STARTUP,.0,.0,.0,.0,PAT_MARQUIS,M_STARTUP|M_NOWRAP
	
	ENDTABLE

	ORG	H'400'
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
	STARTTABLE	GETSIN	
	RETLW	.0
	RETLW	.1	; 0
	RETLW	.4
	RETLW	.6
	RETLW	.9
	RETLW	.11
	RETLW	.14
	RETLW	.16
	RETLW	.18
	RETLW	.21
	RETLW	.23
	RETLW	.26	; 10
	RETLW	.28
	RETLW	.31
	RETLW	.33
	RETLW	.36
	RETLW	.38
	RETLW	.40
	RETLW	.43
	RETLW	.45
	RETLW	.48
	RETLW	.50	;20
	RETLW	.52
	RETLW	.55
	RETLW	.57
	RETLW	.59
	RETLW	.62
	RETLW	.64
	RETLW	.66
	RETLW	.69
	RETLW	.71
	RETLW	.73	;30
	RETLW	.76
	RETLW	.78
	RETLW	.80
	RETLW	.82
	RETLW	.85
	RETLW	.87
	RETLW	.89
	RETLW	.91
	RETLW	.94
	RETLW	.96	;40
	RETLW	.98
	RETLW	.100
	RETLW	.102
	RETLW	.104
	RETLW	.106
	RETLW	.108
	RETLW	.110
	RETLW	.113
	RETLW	.115
	RETLW	.117	;50
	RETLW	.119
	RETLW	.121
	RETLW	.122
	RETLW	.124
	RETLW	.126
	RETLW	.128
	RETLW	.130
	RETLW	.132
	RETLW	.134
	RETLW	.136	;60
	RETLW	.137
	RETLW	.139
	RETLW	.141
	RETLW	.143
	RETLW	.144
	RETLW	.146
	RETLW	.148
	RETLW	.149
	RETLW	.151	;70
	RETLW	.153
	RETLW	.154
	RETLW	.156
	RETLW	.157
	RETLW	.159
	RETLW	.160
	RETLW	.162
	RETLW	.163
	RETLW	.165
	RETLW	.166	;80
	RETLW	.167
	RETLW	.169
	RETLW	.170
	RETLW	.171
	RETLW	.173
	RETLW	.174
	RETLW	.175
	RETLW	.176
	RETLW	.177
	RETLW	.178	;90
	RETLW	.180
	RETLW	.181
	RETLW	.182
	RETLW	.183
	RETLW	.184
	RETLW	.185
	RETLW	.186
	RETLW	.186
	RETLW	.187
	RETLW	.188	;100
	RETLW	.189
	RETLW	.190
	RETLW	.191
	RETLW	.191
	RETLW	.192
	RETLW	.193
	RETLW	.193
	RETLW	.194
	RETLW	.195
	RETLW	.195	;110
	RETLW	.196
	RETLW	.196
	RETLW	.197
	RETLW	.197
	RETLW	.197
	RETLW	.198
	RETLW	.198
	RETLW	.198
	RETLW	.199
	RETLW	.199	;120
	RETLW	.199	;121
	RETLW	.199	;122
	RETLW	.200	;123
	RETLW	.200	;124
	RETLW	.200	;125
	RETLW	.200	;126
	RETLW	.200	;127
	ENDTABLE
	NOP
;-------------------------------------------------------------------------------
; Function:
;	INIT_RANDOM
; Purpose:
;	Initialize random lights values
; Parameters:
;	BANK3 - Mask to apply for setting speed of random numbers
; Notes:
;	We use the mask to set the range.  When the resultant random value when
;	ANDed with the mask is zero, we use the value of the mask + 1 as the
;	increment value
;-------------------------------------------------------------------------------
INIT_RANDOM
	MOVFW	BANK2		; Get our mask since it is in a separate bank
	BANKSEL	LED01PLACE	; Switch to the first bank of registers
	MOVWF	LED_MASK	; And save the mask so we have access to it

	MOVLW	.1		; Start with the low bit
	MOVWF	CYC_FLAGS1	; Which we will increment until we find one
INIT_RANDOM_0
	MOVFW	LED_MASK	; Get the mask value
	ANDWF	CYC_FLAGS1,W	; and see if this bit is set
	SKPZ			; If it is
	GOTO	INIT_RANDOM_1	;  We are done so skip out
	CLRC 
	RLF	CYC_FLAGS1,F	; Move the mask to the next bit 
	GOTO	INIT_RANDOM_0	; and go back to test it
INIT_RANDOM_1
	MOVFW	LED_MASK	; Get the mask we are working from
	ADDWF	CYC_FLAGS1,F	; and add the lowest bit back
	CLRC
	RLF	CYC_FLAGS1,F	; And shift it left to allow for light/dark bit
INIT_RANDOM_2
	MOVLW	LED01PLACE	; Point to the first LED set
	MOVWF	FSR
	MOVLW	.32		; And we will count for 32 LEDs
	MOVWF	LED_COUNT
FILLRAND_LOOP
	CALL	RANDOM		; Get the random number
	MOVWF	INDF		; And save as the initial sequence spot
	INCF	FSR		; Point to the LIGHTDARKMASK for the LED

	CALL	RANDOM		; Get another random number
	ANDWF	LED_MASK,W	; And mask with the pattern mask
	MOVWF	INDF
	CLRC
	RLF	INDF,W		; Save the Light/dark state in carry
	XORLW	.0		; Test for a zero result
	SKPNZ			; Was the rest of it zero
	MOVFW	CYC_FLAGS1	; Yes, so use the high value
	MOVWF	INDF		; Save the increment value
	RRF	INDF,F		; And restore the light/dark state
	INCF	FSR		; Point to the next LED set

	DECFSZ	LED_COUNT	; Count down the LEDS
	GOTO	FILLRAND_LOOP	; If we aren't done, go again
	BANKSEL	BANK0		; Point to the registers
	PAGESEL	START
	MOVFW	BANK3		; Get the Stage counter
	MOVWF	STAGE_COUNTER	; So we know when we are doing with a cycle
	RETURN

;-------------------------------------------------------------------------------
; Function:
;	SHOW_RANDOM
; Purpose:
;	Get the light times for a bank of LEDs
; Parameters:
;	CUR_BANK - The bank of 8 LEDs to get the times for
;	LEDxxPLACE - The spot in the light CYCLE for each of 32 LEDs
;	LEDxxSKIPDARK - The Light/Dark Flag and skip amount for each of 32 LEDs
;	CYC_FLAGS - Indicates whether or not to Fade the LEDs
; Result:
;	LED0TIME..LED8TIME - Are filled in with the amount of time each LED
;		should be on.  A zero indicates that it should be dark
; Notes:
;	This uses the SIN function to make the lights have a slow glow on effect
;	This function changes/restores the register bank
;-------------------------------------------------------------------------------
SHOW_RANDOM
	MOVFW	CYC_FLAGS
;	CUR_BANK has which bank we are looking for
	BANKSEL	LED01PLACE
	MOVWF	CYC_FLAGS1
	CLRC
	RLF	CUR_BANK,W	; CUR_BANK*2
	MOVWF	LED_BANK
	RLF	LED_BANK,F	; CUR_BANK*4
	RLF	LED_BANK,F	; CUR_BANK*8
	RLF	LED_BANK,W	; CUR_BANK*16
	ADDLW	LED08SKIPDARK	; &LED08SKIPDARK[CUR_BANK*8]
	MOVWF	FSR		; And point to it

	MOVLW	.8
	MOVWF	LED_COUNT
SHOW_RANDOM_0
	CLRW			; Assume we won't turn on the LED
	BTFSC	INDF,F_DARKCYCLE; Are we in the dark spot of the cycle
	GOTO	SHOW_RANDOM_1	; Yes, so we are set and leave it off
	
	DECF	FSR		; Poin to LEDxxPLACE[]
	MOVFW	INDF		; Get the spot in the cycle where we are
	BTFSS	CYC_FLAGS1,F_NOFADE	; Do we want to not fade it?
	GOTO	SHOW_RANDOM_0A	; No, so jump to calculate the value
	CLRW			; Assume we will be off
	BTFSC	INDF,.7		; Unless we are in the second half of the cycle
	MOVLW	MAX_ITERATIONS	; in which case the light is on the entire time
	GOTO	SHOW_RANDOM_0B	; Need to restore the pointer
SHOW_RANDOM_0A
	BTFSC	INDF,.7		; If we are in the upper end...
	COMF	INDF,W		;   ..., we use the inverse of the sin
	CALL	GETSIN
SHOW_RANDOM_0B
	INCF	FSR		; Point back to the LEDxxSKIPDARK[]
SHOW_RANDOM_1
;	WREG has the amount of time the LED should be on
	MOVWF	LED_BANK	; Save it
	DECF	FSR,F
	DECF	FSR,W
	MOVWF	TABLE_TEMP
	MOVFW	LED_COUNT
	SUBLW	LED0TIME+8
	MOVWF	FSR
	MOVFW	LED_BANK
	MOVWF	INDF
	MOVFW	TABLE_TEMP
	MOVWF	FSR
	DECFSZ	LED_COUNT
	GOTO	SHOW_RANDOM_0

	BANKSEL	BANK0
	RETURN

;-------------------------------------------------------------------------------
; Function:
;	ADVANCE_RANDOM
; Purpose:
;	Advance the light times for all LEDs
; Parameters:
;	LEDxxPLACE - The spot in the light CYCLE for each of 32 LEDs
;	LEDxxSKIPDARK - The Light/Dark Flag and skip amount for each of 32 LEDs
; Notes:
;	This function changes/restores the register bank
;-------------------------------------------------------------------------------
ADVANCE_RANDOM
	BANKSEL	LED01PLACE	; Select secondary data bank
	MOVLW	.32
	MOVWF	LED_COUNT	; FOR LED_COUNT = 31 to 0 by -1
	MOVLW	LED32SKIPDARK	; Point to LEDxxSKIPDARK[LED_COUNT]
	MOVWF	FSR
ADVANCEONE
	MOVFW	INDF		; LED01SKIPDARK[LED_COUNT]
	ANDLW	B'01111111'	; Get the skip count
	DECF	FSR		; Point to &LED01PLACE[LED_COUNT]
	ADDWF	INDF,F		; LED01PLACE[LED_COUNT] += LED01SKIPDARK[LED_COUNT] & 7
	SKPC			; Did we overflow our count?
	GOTO	DONT_TOGGLE
;
; We are switching this LED from the light to the dark cycle so flip the bit
;
	INCF	FSR		; Point to &LED01SKIPDARK[LED_COUNT]
	MOVLW	M_DARKCYCLE	; Get the bit we are going to flip
	XORWF	INDF,F		; And flip it in the register
	DECF	FSR
DONT_TOGGLE
	DECF	FSR		; Point to the next LED
	DECFSZ	LED_COUNT
	GOTO	ADVANCEONE	; NEXT LED_COUNT
	BANKSEL	BANK0		; Restore to the original data bank
	DECFSZ	STAGE_COUNTER
	RETURN
	MOVFW	BANK3
	MOVWF	STAGE_COUNTER
	BSF	GLOBAL_FLAGS,F_COMPLETE
	RETURN

;-------------------------------------------------------------------------------
; Function:
;	RANDOM
; Purpose:
;	Generate a randon mumber
;
;	Random Number generator from:
;	 http://www.piclist.com/techref/microchip/rand8bit.htm
; Parameters:
;	RANDOMV - Random seed
; Notes:
;	This generator does not like to see a zero
;
;;RANDOM00
;;	CLRC
;;	RLF	RANDOMV, 1
;;	SWAPF	RANDOMV, 0
;;	ANDLW	H'E0'
;;	RRF	RANDOMV,1
;;	ADDWF	RANDOMV,0
;;	ADDWF	RANDOMV,0
;;	ADDWF	RANDOMV,0
;;	SUBLW	H'35'
;;	MOVWF	RANDOMV
;;	RETURN
;-------------------------------------------------------------------------------
	
RANDOM
	RLF	RANDOMV,W
	RLF	RANDOMV,W
	BTFSC	RANDOMV,4
	XORLW	1
	BTFSC	RANDOMV,5
	XORLW	1
	BTFSC	RANDOMV,3
	XORLW	1
	MOVWF	RANDOMV
	RETURN

;-------------------------------------------------------------------------------
; Function:
;	Sort
; Purpose:
;	Sort an array of numbers :-)
;
;	Gnome sort - From Wikipedia, the free encyclopedia
;	http://en.wikipedia.org/wiki/Gnome_sort
;
;	Gnome sort is a sorting algorithm which is similar to insertion sort,
;	except that moving an element to its proper place is accomplished by a
;	series of swaps, as in bubble sort. The name comes from the supposed
;	behavior of the Dutch garden gnome in sorting a line of flowerpots.
;       It is conceptually simple, requiring no nested loops. The running time is O(n²),
;	but in practice the algorithm can run as fast as Insertion sort.
;	function gnomeSort(a[0..size-1]) {
;	i := 1
;	j := 2
;	while i < size
;	   if a[i-1] >= a[i]
;	      i := j
;	      j := j + 1 
;	else
;	   swap a[i-1] and a[i]
;	   i := i - 1
;	   if i = 0
;	      i := 1
;	}
;
; PARAMETERS
;	SORT_ARRAY - Array to be sorted
;	SORT_LENGTH - Number of bytes in the array to sort
;	SORT_J - Temporary variable to hold the end sort pointer
;
; NOTES on implementation
;	This uses the typical XOR trick to swap the two array elements
;	FSR points to the second of the two array elements that we are comparing.
;	
;-------------------------------------------------------------------------------
SORT
	MOVLW	SORT_ARRAY+1
	MOVWF	FSR		;  i = 1
	INCF	FSR,W
	MOVWF	SORT_J		;  j := 2
SORT_1				;  while i < size
	MOVFW	INDF		;  a[i]
	DECF	FSR
	SUBWF	INDF,W
	SKPNC
	GOTO	SORT_2
				;    if a[i-1] >= a[i]
SORT_1A
	MOVFW	SORT_J		;        i := j
	MOVWF	FSR
	SUBLW	SORT_ARRAY+SORT_LENGTH-1
	SKPC
	RETURN
	INCF	SORT_J,F	;        j := j + 1 
	GOTO	SORT_1
SORT_2				;    else
	SKPNZ
	GOTO	SORT_1A
	SUBWF	INDF,W		; Recover a[i]
	XORWF	INDF,W		; Swap a[i] and value for a[i-1]
	XORWF	INDF,F
	XORWF	INDF,W
	INCF	FSR		; point to a[i]
	MOVWF	INDF		; store a[i]
	DECF	FSR		;        i := i - 1
	MOVLW	SORT_ARRAY
	SUBWF	FSR,W		;        if i = 0
	SKPNZ
	INCF	FSR,F		;          i := 1
	GOTO	SORT_1		; }	

;-------------------------------------------------------------------------------
; Function:
;	CALC_TIMES
; Purpose:
;	Sort the LED times and generate masks for the REFRESHCOL routine
; Parameters
;	LED0TIME..LED7TIME - Times for each LED to be on
; Registers Used
;	TEMP
;	SORT_J
;	SAVE_PLACE
;	LEDTIMELIMIT
; Result
;	TIME0..TIME7 - times at which to apply a successive mask
;	MASK0..MASK7 - LED Lighting mask to apply
; Notes
;	Remember that a 1 BIT is off.  So this algorithm runs as follows:
;	   Fill the Masks with B'11111111'
;	   Copy the times int the sort array and then sort it
;	   For each LED, get the originl time and walk through the sort array
;	      flipping the corresponding Mask bit as long as the time is less
;	      than the corresponding sorted time.
;	Because the LED0TIME is generated by the called routines which need
;	more data registers than are available, it is expected that the LED0TIME
;	array is in the 16 bytes of shared data registers.
;-------------------------------------------------------------------------------
CALC_TIMES
;
; Copy the light times into the sort array
;
	MOVLW	LED0TIME	; Point to the source array
	MOVWF	FSR
	MOVLW	.8		; We will look through 8 items
	MOVWF	SORT_J
CALC_TIMES_0
	MOVFW	INDF		; Get the source value
	MOVWF	TEMP		; And save it
	MOVLW	MASK0-LED0TIME	; offset to the corresponding mask element
	ADDWF	FSR		;    and point to it
	MOVLW	B'11111111'	; All LEDs off
	MOVWF	INDF		; Maskx[LED] := B'11111111'
	MOVLW	TIME0-MASK0	; offset to the corresponding time element
	ADDWF	FSR		;    and point to it
	MOVFW	TEMP		; Retreive the source value
	MOVWF	INDF		; TIMEx[LED] := LEDxTIME[LED]
	MOVLW	LED0TIME+1-TIME0; Offset back to the NEXT source array element
	ADDWF	FSR		;    and point to it
	DECFSZ	SORT_J		; Decrement our count
	GOTO	CALC_TIMES_0	; and if not zero, go back for the next LED
;
; Sort the TIMEx Array
;
	CALL	SORT
;
; Now figure out what lights should be on at each stage
;
	MOVLW	B'10000000'	; Mask for the first LED
	MOVWF	SORT_J
	MOVLW	LED0TIME	; Point to the first time
	MOVWF	FSR
CALC_TIMES_1			; For LED = 0 to 7
	MOVFW	INDF		; Get LEDxTIME[LED]
	SKPNZ			; If it is zero we don't have to flip any bits
	GOTO	CALC_TIMES_4	; So just skip all this work
;
; We have a non-zero value for this LED. Figure out how far we need to flip the bit for
;
	MOVWF	LEDTIMELIMIT	; Save the time so we can compare against it
	MOVFW	FSR		; As well as where we are in the source
	MOVWF	SAVE_PLACE
	MOVLW	TIME0		; Point to the start of the Time array
	MOVWF	FSR
CALC_TIMES_2			; For LOOPLED = 0 to 7
	MOVFW	INDF		; Get TIMEx[LOOPLED]
	SUBWF	LEDTIMELIMIT,W	; Is this LED time > TIMEx[LOOPLED]
	SKPC			;   No....
	GOTO	CALC_TIMES_3	;	so we go to the next LED
	MOVLW	MASK0-TIME0	; Offset to MASKx[LOOPLED]
	ADDWF	FSR,F		; and point to it
	MOVFW	SORT_J		; Get our LED Mask
	XORWF	INDF		; Turn off the LED for this cycle time
	MOVLW	TIME0-MASK0+1	; Offset TIMEx[LOOPLED+1]
	ADDWF	FSR,F		; and point to it
	MOVLW	TIME7+1		; Are we at the end of the TIMEx array?
	SUBWF	FSR,W
	SKPZ			; No
	GOTO	CALC_TIMES_2	;    Next LOOPLED
CALC_TIMES_3
	MOVFW	SAVE_PLACE	; Restore LEDxTIME[LED] pointer
	MOVWF	FSR		; and point to it
CALC_TIMES_4
	INCF	FSR,F		; Poin to next LEDxTIME[LED]
	CLRC
	RRF	SORT_J,F	; Adjust mask for the next LED
	SKPC			; Did we get the last LED?
	GOTO	CALC_TIMES_1	; No.. NEXT LED
;
; Lastly we need to make all TIME values a delta from the previous one
;
	MOVLW	.7		; FOR LED = 6 to 0 by -1
	MOVWF	SORT_J
	MOVLW	TIME6		; Point to TIMEx[LED]
	MOVWF	FSR
CALC_TIMES_5
	MOVFW	INDF		; Get TIMEx[LED]
	INCF	FSR,F		; Point to TIMEx[LED+1]
	SUBWF	INDF		; TIMEx[LED+1] -= TIMEx[LED]
	DECF	FSR,F		; Point to next TIMEx for loop
	DECF	FSR,F
	DECFSZ	SORT_J		; Decrement LED, are we done?
	GOTO	CALC_TIMES_5	; NO.. NEXT LED
	RETURN

;-------------------------------------------------------------------------------
; Function:
;	INIT_STRIPES
; Purpose:
;	Initialize random lights values
; Parameters:
;	BANK2 - Mask to apply for setting speed of random numbers
;	BANK3 - The number of cycles in a stage
; Notes:
;	We use the mask to set the range.  When the resultant random value when
;	ANDed with the mask is zero, we use the value of the mask + 1 as the
;	increment value
;-------------------------------------------------------------------------------
INIT_STRIPES
	MOVFW	BANK3		; Get the Stage counter
	MOVWF	STAGE_COUNTER	; So we know when we are doing with a cycle
	MOVFW	BANK2		; Get our mask since it is in a separate bank
	BANKSEL	STRIPE0HPLACE	; Switch to the first bank of registers
	MOVWF	STRIPE_MASK	; And save the mask so we have access to it

	MOVLW	STRIPE0HPLACE	; Point to the first LED set
	MOVWF	FSR
	MOVLW	.8		; And we will count for 8 Stripes of LEDs
	MOVWF	STRIPE_COUNT
FILLSTRIPES_LOOP
	CALL	RANDOM		; Get the random number
	MOVWF	INDF		; And save as the initial sequence spot
	INCF	FSR		; Point to the STRIPExxSKIP for the LED

	CALL	RANDOM		; Get another random number
	ANDWF	STRIPE_MASK,W	; And mask with the pattern mask
	ADDLW	.1		; And add one so we we ensure a non-zero inc
	MOVWF	INDF

	INCF	FSR		; Point to the STRIPEXXSTATE
	CALL	RANDOM		; Get one more random number
	ANDLW	.7
	ADDLW	.6		; Ensure that it is at least a full cycle
	MOVWF	INDF		; Save the state value
	INCF	FSR		; Point to the next LED set

	DECFSZ	LED_COUNT	; Count down the LEDS
	GOTO	FILLSTRIPES_LOOP; If we aren't done, go again
	BANKSEL	BANK0		; Point to the registers
	PAGESEL	START
	RETURN

;-------------------------------------------------------------------------------
; Function:
;	SHOW_STRIPES
; Purpose:
;	Get the light times for a bank of LEDs
; Parameters:
;	CUR_BANK - The bank of 8 LEDs to get the times for
;	LEDxxPLACE - The spot in the light CYCLE for each of 32 LEDs
;	LEDxxSKIPDARK - The Light/Dark Flag and skip amount for each of 32 LEDs
;	CYC_FLAGS - Indicates whether or not to Fade the LEDs
; Result:
;	LED0TIME..LED8TIME - Are filled in with the amount of time each LED
;		should be on.  A zero indicates that it should be dark
; Notes:
;	This uses the SIN function to make the lights have a slow glow on effect
;	This function changes/restores the register bank
;-------------------------------------------------------------------------------
SHOW_STRIPES
	MOVFW	CYC_FLAGS
;	CUR_BANK has which bank we are looking for
	BANKSEL	LED01PLACE
	MOVWF	CYC_FLAGS1
	CLRC
	RLF	CUR_BANK,W	; CUR_BANK*2
	MOVWF	LED_BANK
	RLF	LED_BANK,W	; CUR_BANK*4
	ADDWF	LED_BANK,F	; CUR_BANK*6
	ADDLW	STRIPE0LSTATE	; &STRIPE0LSTATE[CUR_BANK*6]
	MOVWF	FSR		; And point to it

	MOVLW	.2
	MOVWF	STRIPE_COUNT
SHOW_STRIPES_0
	CLRW
	BTFSC	INDF,F_DARKCYCLE
	GOTO	SHOW_STRIPES_1
	
	DECF	FSR		; Poin to LEDxxPLACE[]
	MOVFW	INDF		; Get the spot in the cycle where we are
	BTFSC	INDF,.7		; If we are in the upper end...
	COMF	INDF,W		;   ..., we use the inverse of the sin
	CALL	GETSIN		
	INCF	FSR
	BTFSC	CYC_FLAGS1,F_NOFADE
	MOVLW	MAX_ITERATIONS
SHOW_STRIPES_1
;	WREG has the amount of time the LED should be on
	MOVWF	LED_BANK	; Save it
	DECF	FSR,F
	DECF	FSR,W
	MOVWF	TABLE_TEMP
	MOVFW	LED_COUNT
	SUBLW	LED0TIME+8
	MOVWF	FSR
	MOVFW	LED_BANK
	MOVWF	INDF
	MOVFW	TABLE_TEMP
	MOVWF	FSR
	DECFSZ	LED_COUNT
	GOTO	SHOW_RANDOM_0

	BANKSEL	BANK0
	RETURN

;-------------------------------------------------------------------------------
; Function:
;	ADVANCE_STRIPES
; Purpose:
;	Advance the light times for all LEDs
; Parameters:
;	LEDxxPLACE - The spot in the light CYCLE for each of 32 LEDs
;	LEDxxSKIPDARK - The Light/Dark Flag and skip amount for each of 32 LEDs
; Notes:
;	This function changes/restores the register bank
;-------------------------------------------------------------------------------
ADVANCE_STRIPES
	BANKSEL	LED01PLACE	; Select secondary data bank
	MOVLW	.32
	MOVWF	LED_COUNT	; FOR LED_COUNT = 31 to 0 by -1
	MOVLW	LED32SKIPDARK	; Point to LEDxxSKIPDARK[LED_COUNT]
	MOVWF	FSR
ADVANCESTRIPE1
	MOVFW	INDF		; LED01SKIPDARK[LED_COUNT]
	ANDLW	B'01111111'	; Get the skip count
	DECF	FSR		; Point to &LED01PLACE[LED_COUNT]
	ADDWF	INDF,F		; LED01PLACE[LED_COUNT] += LED01SKIPDARK[LED_COUNT] & 7
	SKPC			; Did we overflow our count?
	GOTO	DONT_TOGGLE_STRIPE
;
; We are switching this LED from the light to the dark cycle so flip the bit
;
	INCF	FSR		; Point to &LED01SKIPDARK[LED_COUNT]
	MOVLW	M_DARKCYCLE	; Get the bit we are going to flip
	XORWF	INDF,F		; And flip it in the register
	DECF	FSR
DONT_TOGGLE_STRIPE
	DECF	FSR		; Point to the next LED
	DECFSZ	LED_COUNT
	GOTO	ADVANCESTRIPE1	; NEXT LED_COUNT
	BANKSEL	BANK0		; Restore to the original data bank
	DECFSZ	STAGE_COUNTER
	RETURN
	MOVFW	BANK3
	MOVWF	STAGE_COUNTER
	BSF	GLOBAL_FLAGS,F_COMPLETE
	RETURN
	
;-------------------------------------------------------------------------------
; Function:
;	INIT_DRIP
; Purpose:
;	Initialize drip sequence values
; Parameters:
;	None
; Notes:
;	All of the real work is done in the Advance_Drip routine, this just sets
;       it up so that we pretend we are at the end of a cycle
;	This function changes/restores the register bank
;-------------------------------------------------------------------------------
INIT_DRIP
	BANKSEL	DRIP_LED01VALUE
	MOVLW	.1
	MOVWF	DRIP_REP
	MOVWF	DRIP_DRIP
	GOTO	ADVANCE_DRIP
;-------------------------------------------------------------------------------
; Function:
;	REFRESH_DRIP
; Purpose:
;	Get the LED light values for the current drip cycle
; Parameters:
;	DRIP_LEDxx - The calculated LED values to display
; Notes:
;	This function changes/restores the register bank
;-------------------------------------------------------------------------------
REFRESH_DRIP
	BANKSEL	DRIP_LED01VALUE
	MOVLW	.8
	MOVWF	DRIP_COUNT
	CLRC
	RLF	CUR_BANK,W	; CUR_BANK * 2
	MOVWF	DRIP_TEMP
	RLF	DRIP_TEMP,F	; CUR_BANK * 4
	RLF	DRIP_TEMP,W	; CUR_BANK * 8
	ADDLW	DRIP_LED08VALUE	; DRIP_LED08VALUE[CUR_BANK*8]
REFRESH_DRIP0
	MOVWF	DRIP_TEMP	; Point to DRIP_LED01VALUE[CUR_BANK*8+DRIP_COUNT]
	MOVWF	FSR
	MOVFW	INDF		; Get DRIP_LED01VALUE[CUR_BANK*8+DRIP_COUNT]
	MOVWF	DRIP_TEMP2	; And save it
	MOVFW	DRIP_COUNT
	ADDLW	LED0TIME-1	; Point to LED0TIME[DRIP_COUNT-1]
	MOVWF	FSR
	MOVFW	DRIP_TEMP2	; Get the saved value
	MOVWF	INDF		; And store it into the final destination
	DECF	DRIP_TEMP,W	; Point to previous DRIP_LED value
	DECFSZ	DRIP_COUNT	; Are we done with all LEDs?
	GOTO	REFRESH_DRIP0	; No so go back
	BANKSEL	BANK0
	RETURN

;-------------------------------------------------------------------------------
; Function:
;	ADVANCE_DRIP
; Purpose:
;	Advance the light times for all LEDs
; Parameters:
;	LEDxxPLACE - The spot in the light CYCLE for each of 32 LEDs
;	LEDxxSKIPDARK - The Light/Dark Flag and skip amount for each of 32 LEDs
; Notes:
;	This function changes/restores the register bank
;-------------------------------------------------------------------------------
ADVANCE_DRIP
	BANKSEL	DRIP_LED01VALUE
	DECFSZ	DRIP_DRIP	; Are we at the end of a drip cycle?
	GOTO	ADVANCE_DRIP0	; No, So carry on
	MOVLW	.40		; Yes, so start the drip over
	MOVWF	DRIP_DRIP
	DECFSZ	DRIP_REP	; Advance to the next rep
	GOTO	ADVANCE_DRIP0	; If we didn't wrap then Go on with it
RESET_DRIP
	BSF	GLOBAL_FLAGS,F_COMPLETE	; remember we hit the end
	MOVLW	.30
	MOVWF	DRIP_REP	; Reps := 30
	MOVLW	.7
	MOVWF	DRIP_COUNT	; For (DRIP_COUNT=7 to 1)
	MOVLW	DRIP_LINESTEP1	; Point at the first LINESTEP
	MOVWF	FSR
	MOVLW	.45		; First fill value is 45 (going up by 4)
RESET_DRIP0
; Initialize the linesteps 4 steps out of phase starting at 45 and going up.
; It is only on the first itersting that they are above 40 so that they aren't
; dripping while the top led is filling up for the first time.
	MOVWF	INDF		; LINESTEP[x] := fill value
	INCF	FSR,F
	ADDLW	.4		; Fillvalue += 4
	DECFSZ	DRIP_COUNT,F	; NEXT DRIP_COUNT
	GOTO	RESET_DRIP0
; Initialize all the lights to off
	MOVLW	.32
	MOVWF	DRIP_COUNT	; For (DRIP_COUNT=32 to 1)
	MOVLW	DRIP_LED01VALUE
	MOVWF	FSR		; Point to LEDxxVALUE
RESET_DRIP1
	CLRF	INDF		; LEDxxVALUE[DRIP_COUNT] := 0
	INCF	FSR,F		; point to next LEDxxVALUE
	DECFSZ	DRIP_COUNT,F	; NEXT DRIP_COUNT
	GOTO	RESET_DRIP1
	GOTO	FILL_DRIP	; Proceed to fill it up for the first time

ADVANCE_DRIP0
	DECFSZ	DRIP_REP,W	; We are on the next rep
	GOTO	FILL_DRIP	; if not the last we go to fill it up
DRAIN_DRIP
; This is the last DRIP so we need to drain it
	CLRF	DRIP_LED01VALUE+LED_LEFT_TOP_O	; Top 3 LEDS are always off
	CLRF	DRIP_LED01VALUE+LED_RIGHT_TOP_O
	CLRF	DRIP_LED01VALUE+LED_CENTER_TOP_Y
	MOVLW	.29
	MOVWF	DRIP_LIMIT	; Limit := 29
	MOVLW	.4		;    # of times we will decrement light by 50
	MOVWF	DRIP_RANGE	; Range := 4
	MOVLW	.200		;    Full on lights
	MOVWF	DRIP_LIGHT	; Light := 200 
	MOVLW	.30
	SUBWF	DRIP_DRIP,W	; Do we have less than 30 drips left
	MOVFW	DRIP_DRIP	; Get number of drips just in case
	SKPC			; No, we do nothing
	MOVWF	DRIP_LIMIT	; Yes reset the limit to number of drips left
DRAIN_DRIP0
	GOTO	DRAIN_DRIP2
; Adjust the starting light value down if we have less than 4 drips
DRAIN_DRIP1
	MOVLW	-.50
	ADDWF	DRIP_LIGHT	; Light -= 50
	DECF	DRIP_RANGE	; And drop our range of decrements
DRAIN_DRIP2
	BTFSC	DRIP_RANGE,7	; Is our range < 0
	GOTO	DRAIN_DRIP1	; Yes so adjust the starting light down
	CLRF	DRIP_TEMP	; Drip_Temp is the LED we are working on
	MOVLW	.29
	MOVWF	DRIP_COUNT	; FOR (DRIP_COUNT = 29 to 1)
DRAIN_DRIP3
	MOVFW	DRIP_TEMP	; Get the current LED
	INCF	DRIP_TEMP	; and advance it for the next iteration
	CALL	DRIP_POINTTO	; Point to the current LED
	MOVFW	DRIP_LIGHT	; Get the current light value
	MOVWF	INDF		; and set that LED to it
	DECF	DRIP_LIMIT	; Are we past the lights which are on?
	BTFSS	DRIP_LIMIT,7
	GOTO	DRAIN_DRIP4	; yes, so skip out
DRAIN_DRIP3A
	DECF	DRIP_RANGE	; Is it time to start decreasing the light?
	BTFSC	DRIP_RANGE,7
	GOTO	DRAIN_DRIP4	; No, so skip out
DRAIN_DRIP3B
	MOVLW	-.50		; Yes, drop it by 1/4 intensity
	ADDWF	DRIP_LIGHT
DRAIN_DRIP4
	DECFSZ	DRIP_COUNT	; NEXT DRIP_COUNT
	GOTO	DRAIN_DRIP3
	GOTO	ADVANCE_DRIP_EXIT

FILL_DRIP
; The top LED gets filled in as follows:
;   DRIP        LED VALUE
;    40,39,38   0,1,2  (40-Drip)
;    37 .. 5    8, 14, 20 ...  188, 194, 200 (Previous value + 6)
;    4 .. 1     150,100,50,0 (Previous value - 50)
	MOVLW	.38
	SUBWF	DRIP_DRIP,W	; WREG = DRIP - 38
	SKPC			; Are we past DRIP 38?
	GOTO	DRIP_FILL0A	; Yes
; We are at the first three three drips so compute 40-DRIP
	SUBLW	.2		; We already subtracted 38, so 2-DRIP works
	MOVWF	DRIP_LED01VALUE+LED_CENTER_TOP_Y	; Set the TOP LED value
	GOTO	DRIP_FILL0
DRIP_FILL0A
; Drips 37 and below come here
	ADDLW	.38-.5		; Are we past drip 5 (adding 38 to calculation)
	MOVLW	.6		; We are going to add 6
	SKPC			; Unless we are below drip 5
	MOVLW	-.50		; In which case we make it -50
	ADDWF	DRIP_LED01VALUE+LED_CENTER_TOP_Y,F	; Adjust top LED value
DRIP_FILL0
;
; Now we want to fil in the 7 LEDs in the center based on the LINESTEPx values
; This goes as follows:
;  LINESTEPx         LED VALUE
;    > 9             0
;    8, 7, 6, 5      50, 100, 150, 200 (Previous value + 50)
;    4, 3, 2, 1      150, 100, 50, 0 (Previous value - 50)
;
	MOVLW	.7
	MOVWF	DRIP_COUNT	; There are 7 other LEDs in the center row
	MOVLW	DRIP_LINESTEP7	; And we start at the bottom
	MOVWF	FSR
DRIP_FILL1
	CLRF	DRIP_TEMP	; Assume we won't be adding anything
	DECFSZ	INDF		; count down our LINESTEPx value
	GOTO	DRIP_FILL1A	; If it is non-zero we have more work to do
	MOVLW	.40
	MOVWF	INDF		; Reset the count down cycle to 40
	GOTO	DRIP_FILL3
DRIP_FILL1A
	MOVLW	.9
	SUBWF	INDF,W		; Are we at steps 8 or below?
	SKPNC
	GOTO	DRIP_FILL3	; No so we will set the LED to 0
	MOVLW	.50
	MOVWF	DRIP_TEMP	; Assume we will increment the LED by 50
	MOVLW	.5
	SUBWF	INDF,W		; Check to see if we are steps 4 or below
	MOVLW	-.50		; get ready with the -50
	SKPC			
	MOVWF	DRIP_TEMP	; And we will decrement the LED by 50
DRIP_FILL3
	DECF	FSR,W		; Save the pointer to the next LINESTEPx
	MOVWF	DRIP_TEMP2
	MOVFW	DRIP_COUNT	; Figure out which LED we are working on
	ADDLW	DRIP_LED01VALUE+LEDBANK_CENTER	; get it's offset
	MOVWF	FSR		; and point to it
	MOVFW	DRIP_TEMP	; Get the delta amount
	ADDWF	INDF,F		; And adjust the LED by that amount
	MOVFW	DRIP_TEMP2	; Restore the pointer to the next LINESTEPx
	MOVWF	FSR
	DECFSZ	DRIP_COUNT	; Count down
	GOTO	DRIP_FILL1	; and loop back for the next LINESTEPx

DRIP_FILL2
	MOVFW	DRIP_REP
	SUBLW	.29		; We fill more lights as we go on
	SKPC			; Except is this the first round?
	GOTO	DRIP_FILL7	; Yes, so skip out
	MOVWF	DRIP_LIMIT	; Save the limit
	MOVLW	.6		; Did the last LED just start to turn off?
	SUBWF	DRIP_LINESTEP7,W	; 
	SKPNC			; Yes, we will use it 
	GOTO	DRIP_FILL4	;    No, so we don't start turning one on
	MOVFW	DRIP_LIMIT	; See which LED we are working on
	CALL	DRIP_POINTTO	; And point to it
	MOVFW	DRIP_LED01VALUE+LED_CENTER_8_G	; Get the value of the last LED in the row
	SUBLW	.200		; and invert it
	MOVWF	INDF		; To set the new LED
DRIP_FILL4
	DECF	DRIP_LINESTEP7,W
	ADDLW	-.28		; Are we past where the LED should have stayed on?
	SKPNC
	INCF	DRIP_LIMIT	; Yes. so let the other loop set it on instead
DRIP_FILL5
	MOVFW	DRIP_LIMIT	; Do we have at least one LED to turn on?
	SKPNZ
	GOTO	DRIP_FILL7	; No so head out
DRIP_FILL6			; while {
	DECF	DRIP_LIMIT,W	;   Get the current LED we are working on
				;     (that is the position not the count)
	CALL	DRIP_POINTTO	;   And point to it
	MOVLW	.200		;   Light is on full
	MOVWF	INDF		;   Set it to that value
	DECFSZ	DRIP_LIMIT	; } Drip_limit-- > 0
	GOTO	DRIP_FILL6
DRIP_FILL7
ADVANCE_DRIP_EXIT
	BANKSEL	BANK0
	RETURN

;-------------------------------------------------------------------------------
; Function:
;	DRIP_POINTTO
; Purpose:
;	Get the LED light values for the current drip cycle
; Parameters:
;	WREG - Led sequence number to find
;-------------------------------------------------------------------------------
DRIP_POINTTO
	CALL	GET_FILLORDER
	MOVWF	FSR
	RETURN

	STARTTABLE	GET_FILLORDER
	RETLW	DRIP_LED01VALUE+LED_LEFT_8_R
	RETLW	DRIP_LED01VALUE+LED_RIGHT_8_R
	RETLW	DRIP_LED01VALUE+LED_SPLIT_L_G
	RETLW	DRIP_LED01VALUE+LED_SPLIT_R_G
	RETLW	DRIP_LED01VALUE+LED_LEFT_7_Y

	RETLW	DRIP_LED01VALUE+LED_RIGHT_7_Y
	RETLW	DRIP_LED01VALUE+LED_CENTER_8_G
	RETLW	DRIP_LED01VALUE+LED_SPLIT_L_O
	RETLW	DRIP_LED01VALUE+LED_SPLIT_R_O
	RETLW	DRIP_LED01VALUE+LED_LEFT_6_G

	RETLW	DRIP_LED01VALUE+LED_RIGHT_6_G
	RETLW	DRIP_LED01VALUE+LED_CENTER_7_O
	RETLW	DRIP_LED01VALUE+LED_SPLIT_L_R
	RETLW	DRIP_LED01VALUE+LED_SPLIT_R_R
	RETLW	DRIP_LED01VALUE+LED_CENTER_6_R

	RETLW	DRIP_LED01VALUE+LED_LEFT_5_O
	RETLW	DRIP_LED01VALUE+LED_RIGHT_5_O
	RETLW	DRIP_LED01VALUE+LED_SPLIT_LTOP_Y
	RETLW	DRIP_LED01VALUE+LED_SPLIT_RTOP_Y
	RETLW	DRIP_LED01VALUE+LED_CENTER_5_Y

	RETLW	DRIP_LED01VALUE+LED_LEFT_4_R
	RETLW	DRIP_LED01VALUE+LED_RIGHT_4_R
	RETLW	DRIP_LED01VALUE+LED_CENTER_4_G
	RETLW	DRIP_LED01VALUE+LED_LEFT_3_Y
	RETLW	DRIP_LED01VALUE+LED_RIGHT_3_Y

	RETLW	DRIP_LED01VALUE+LED_CENTER_3_O
	RETLW	DRIP_LED01VALUE+LED_LEFT_2_G
	RETLW	DRIP_LED01VALUE+LED_RIGHT_2_G
	RETLW	DRIP_LED01VALUE+LED_CENTER_2_R
	RETLW	DRIP_LED01VALUE+LED_LEFT_TOP_O

	RETLW	DRIP_LED01VALUE+LED_RIGHT_TOP_O
	RETLW	DRIP_LED01VALUE+LED_CENTER_TOP_Y

	ENDTABLE
END	END
