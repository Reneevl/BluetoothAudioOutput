;
; calc.asm
;
; Created: 26-5-2020 13:26:56
; Author : renee
;

;-------------------DIGIT AND OPERANT DEFENITIONS-------------------
.equ	DIGIT0	= 0x00
.equ	DIGIT1	= 0x01
.equ	DIGIT2	= 0x02
.equ	DIGIT3	= 0x03
.equ	DIGIT4	= 0x04
.equ	DIGIT5	= 0x05
.equ	DIGIT6	= 0x06
.equ	DIGIT7	= 0x07
.equ	DIGIT8	= 0x08
.equ	DIGIT9	= 0x09
.equ	OPERAA	= 0x10
.equ	OPERAS	= 0x20
.equ	OPERAM	= 0x40
.equ	OPERAD	= 0x80
.equ	EMPTYB	= 0x0F

;-------------------REGISTER NAMES-------------------
.def    outL = r0
.def    outH = r1
.def    row1 = r2
.def    row2 = r3
.def    row3  = r4
.def    row4  = r5
.def    row1pr  = r6
.def    row2pr  = r7
.def    row3pr  = r8
.def    row4pr  = r9
.def    ret0  = r10
.def    ret1  = r11
.def    opdigi  = r12
.def    temp6  = r13
.def    temp7 = r14
.def    temp8  = r15
.def    param0  = r16
.def    param1  = r17
.def    param2  = r18
.def    param3  = r19
.def    temp0 = r20
.def    temp1 = r21
.def    temp2 = r22
.def    temp3 = r23
.def    temp4 = r24
.def	temp5 = r25

;.equ	sumend	= X
;.equ	sumcnt	= Y
;.equ	sumop	= Z

;-------------------STACK INIT AND SUMEND/INPUT RESET-------------------
start:
LDI	temp0,LOW(RAMEND)		; load low byte of RAMEND into r16
OUT	SPL,temp0				; store r16 in stack pointer low
LDI	temp0,HIGH(RAMEND)	; load high byte of RAMEND into r16
OUT	SPH,temp0				; store r16 in stack pointer high
LDI sumendL, 0x00
LDI sumendH, 0x01
CLR opdigi

;-------------------UART INITIALISATION-------------------
USART_Init:
; Set baud rate
LDI temp0, 0x67
STS UBRR0L, temp0
; Enable transmitter
LDI temp0, (1<<TXEN0)
STS UCSR0B,temp0
; Set frame format: 8data, 2stop bit
LDI temp0, (3<<UCSZ00)
STS UCSR0C, temp0

CALL Simuleer_oplosbare_som_1
CALL Solve
LDI param0, 0x0A
CALL UART_Transmit
LDI param0, 0x0D
CALL UART_Transmit

loop:
JMP loop


;-------------------SOLVING THE SUM IN MEMORY-------------------
Solve:
CBR sumcntL, 0xFF					; begining of the sum
LDI sumcntH, 0x01
loop_multiply_and_devide:
;LOOP TO FIND ALL THE MULTIPLY AND DEVIDE SUMS
CBR temp0, 0xFF
MOV ret0, temp0						; reset
LD  opdigi, Y						; load digit or operand from Y (AKA cumcnt)
SBRC opdigi, 6						; skip next if not multiply
CALL Calculate						; Calculate the sum
SBRC opdigi, 7						; skip next if not devide
CALL Calculate						; Calculate the sum
CALL sumcnt_increment				; increment the sumcnt
CALL sumcnt_end_check				; check if end is reached
SBRS ret0, 0						; if end is reached, skip next
RJMP loop_multiply_and_devide		; end is not reached, loop further

CBR sumcntL, 0xFF					; begining of the sum
LDI sumcntH, 0x01
loop_add_and_subtract:
;LOOP TO FIND ALL THE ADD AND SUBTRACT SUMS
CBR temp0, 0xFF
MOV ret0, temp0						; reset
LD  opdigi, Y						; load digit or operand from Y (AKA cumcnt)
SBRC opdigi, 4						; skip next if not add
CALL Calculate						; Calculate the sum
SBRC opdigi, 5						; skip next if not subtract
CALL Calculate						; Calculate the sum
CALL sumcnt_increment				; increment the sumcnt
CBR temp0, 0xFF
MOV ret0, temp0						; reset
CALL sumcnt_end_check				; check if end is reached
SBRS ret0, 0						; if end is reached, skip next
RJMP loop_add_and_subtract		; end is not reached, loop further

;-------------------PRINT ANSWER-------------------
CLR temp0
CLR temp1
CLR ret0
LDI sumcntL, 0x00					; Reset to begin
LDI sumcntH, 0x01

Printloop:
CALL sumcnt_end_check
SBRC ret0, 0						; if very end of the sum, do next
RET
LD temp0, Y+				
TST temp0							; If zero, check if it is the first zero
BREQ zero_print
CPI temp0, EMPTYB					; Skip this
BREQ Printloop
SBR temp1, 1						; Rembember we printed something
Print_my_byte:
MOV param0, temp0
LDI temp0, 0x30						; Make ASCII number
ADD param0, temp0
CALL UART_Transmit
CALL sumcnt_end_check
SBRC ret0, 0						; if very end of the sum, do next
RET
Throwback:
JMP Printloop

zero_print:
SBRC temp1, 0						; skip the next line if this is the first zero
JMP Print_my_byte
JMP Throwback

;-------------------CALCULATE A PART OF THE FULL SUM-------------------
Calculate:
PUSH sumcntL
PUSH sumcntH
; We've found an operator! Let's find out with numbers are around it
MOV sumopL, sumcntL						; Remember where the operator is
MOV sumopH, sumcnth

LDI temp0, 0x27						;store 10000
LDI temp1, 0x10
PUSH temp1
PUSH temp0
LDI temp0, 0x03						;store 1000
LDI temp1, 0xE8
PUSH temp1
PUSH temp0
LDI temp0, 0x00						;store 100
LDI temp1, 0x64
PUSH temp1
PUSH temp0
LDI temp0, 0x00						;store 10
LDI temp1, 0x0A
PUSH temp1
PUSH temp0
LDI temp0, 0x00						;store 1
LDI temp1, 0x01
PUSH temp1
PUSH temp0

CBR temp0, 0xFF						; clear operandH 1
CBR temp1, 0xFF						; clear operandL 1
CBR temp2, 0xFF						; clear counter

loop_operand_1:
;FIND THE FIRST OPERAND
CALL sumcnt_decrement
LD param0, Y
CPI param0, 0X0F					; chech if empty byte
BREQ loop_operand_1					; skip if empty byte
MOV temp4, param0					; make copy of reading
SUBI temp4, 0x10					; check if operant
BRSH rewind					; digit is operand, jump to encode the second operand
CALL sumcnt_begin_check
SBRC ret0, 0						; if end is begin, do next
RJMP rewind
CBR temp4, 0xFF						; clear number
MOV param1, temp4					; inserted digit (high) clear
POP param3							; multiplier (high)
POP param2							; multiplier (low)
INC temp2							; count the pops
CALL Multiply_16bit					; multiply digit with 1, 10, 100, 1000.....
MOVW param3:param2, ret1:ret0
MOVW param1:param0, temp1:temp0
CALL Add_16bit
BRVS Overflow_path1						; quit because overflow
MOVW temp1:temp0, ret1:ret0 
RJMP loop_operand_1


Overflow_path1:
JMP Overflow

;RESET SOME STUFF
rewind:								; clean up the stack
CPI temp2, 0x05
BREQ operand_2
POP temp3
POP temp3
INC temp2
RJMP rewind

operand_2:
;FIND THE SECOND OPERAND
MOV sumcntL, sumopL					; retreive the position of the operator
MOV sumcntH, sumopH					; retreive the position of the operator

PUSH temp0							; store previous operandL for a moment
PUSH temp1							; store previous operandH for a moment

CBR temp3, 0xFF						; clear operandH 2
CBR temp2, 0xFF						; clear operandL 2

MOV ret0, temp2
MOV ret1, temp2						; clear return values


loop_operand_2:
CALL sumcnt_increment
LD temp0, Y							; temp0 is what is read
MOV temp4, temp0					; make copy of reading
SUBI temp4, 0x10					; check if operant
BRSH Calc_sum						; digit is operand than this is end of the sum
CALL sumcnt_end_check
CPI temp0, 0X0F						; chech if empty byte
BREQ loop_operand_2					; skip if empty byte
SBRC ret0, 0						; if very end of the sum, do next
RJMP Calc_sum
CBR temp4, 0xFF	
MOV param1, temp3					; param0 is operandH
MOV param0, temp2					; param1 is operandL
CLR param3							; param 3 is multiplier (high) 0
LDI param2, 0x0A					; multiplier (low) 10
CALL Multiply_16bit					; multiply the operand with 10
MOVW param3:param2, ret1:ret0		; solution goes to parameters
CLR temp1							; the read value is always 1 byte and the add needs 2 bytes. Create some empty filling
MOVW param1:param0, temp1:temp0		; the read value goes to parameters
CALL Add_16bit						; add both
BRVS Overflow_path1					; quit because overflow
MOVW temp3:temp2, ret1:ret0			; store niew operator	
RJMP loop_operand_2

Calc_sum:
POP temp1
POP temp0
;CALCULATE THE SUM
LD temp4, Z							; read operator
MOVW param1:param0, temp1:temp0
MOVW param3:param2, temp2:temp3
SBRC temp4,7						; check devide bit
CALL Devide_16bit
SBRC temp4,6						; check multiply bit
CALL Multiply_16bit
SBRC temp4,5						; check subtract bit
CALL Sub_16bit
SBRC temp4,4						; check add bit
CALL Add_16bit
BRVS Overflow_path1					; quit because overflow

Store_in_memory:					; our answer will be stored in temp1 and temp0 from this point
; We will need Y again to scroll through the sum, but knowing the end of this sum will be usefull later
MOV temp7, sumcntL					; Nobody ever uses these
MOV temp8, sumcntH
MOVW temp1:temp0, ret1:ret0
MOV sumcntL, sumopL					; retreive the position of the operator
MOV sumcntH, sumopH					; retreive the position of the operator
CLR ret0


LDI temp2, 0x01
PUSH temp2
LDI temp2, 0x00						;store 1
PUSH temp2
LDI temp2, 0x0A
PUSH temp2
LDI temp2, 0x00						;store 10
PUSH temp2
LDI temp2, 0x64
PUSH temp2
LDI temp2, 0x00						;store 100
PUSH temp2
LDI temp2, 0xE8
PUSH temp2
LDI temp2, 0x03						;store 1000
PUSH temp2
LDI temp2, 0x10
PUSH temp2
LDI temp2, 0x27						;store 10000
PUSH temp2

LDI temp2, 0x05						; make counter
MOV temp6, temp2					; make temp6 the counter

Find_begin:
LD temp2, -Y
CALL sumcnt_begin_check
SBRC ret0, 0						; if we've hit the begin, start filling
RJMP Begin_found
CPI temp2, 0x10						; if temp2 is not an operators (operators are higher than 0x10) loop again
BRLO Find_Begin

Begin_found:
LD temp2, Y+
CLR temp5							; clear the 'a digit has been stored' check
Storing:
DEC temp6
POP temp3							; temp3 and temp2 are 10000, 1000, 100, 10 or 1
POP temp2
MOVW param3:param2, temp3:temp2
MOVW param1:param0, temp1:temp0
CALL Devide_16bit					; Devide the to be saved number by 10000, 1000, 100, 10, 1 to find each digit
MOV temp4, ret0						; Save the result somewhere
TST ret0							; Test if the result is zero, zero may not always need to be saved
BREQ Zero_digit


Store_digit:
; SPLIT NUMBER IN PARTS (TENTHOUSANDS, THOUSANDS, HUNDREDS...) TO STORE IN MEMORY
SBR temp5, 1
MOVW param3:param2, temp3:temp2		; move stack value in parameters
MOVW param1:param0, ret1:ret0		; Move devision answer in parameters
CALL Multiply_16bit
MOVW param1:param0, temp1:temp0		; Move the number we should store to parameters
MOVW param3:param2, ret1:ret0		; Move the digit we're going to store * its value to the parameters
CALL Sub_16bit						; our number that we want to save is now smaller
MOVW temp1:temp0, ret1:ret0			; Move our new to store number
MOVW param1:param0, ret1:ret0		; The new to store number should be compared to zero
ST Y+, temp4						; Store the digit
CALL Test_word_for_zero
TST temp6							; If we've tried to store 5 times, we're done
BREQ  Filler
JMP Storing

Zero_digit:
; DECIDE WHETHER TO STORE A 0
SBRS temp5, 0
JMP Storing
ST Y+, temp4
TST temp6							; If we've tried to store 5 times, we're done
BREQ  Filler
JMP Storing

Filler:
; RECALL THE POSITION OF THE OPERATOR
MOV sumopH, temp8
MOV sumopL, temp7
CLR ret0

Filler_loop:
; FILL UP MEMORY UNTIL OPERATOR OR SUMEND WITH 0X0F (EMPTYB)
LDI temp1, EMPTYB
LD temp0, Y
CALL sumcnt_op_check
SBRC ret0, 0						; if very end of the sum, do next
RJMP End_sum
CALL sumcnt_end_check
SBRC ret0, 0						; if very end of the sum, do next
RJMP End_sum
ST Y+, temp1 
JMP Filler_loop

End_sum:
POP sumcntH
POP sumcntL
RET

;-------------------OVERFLOW HAS OCCURD-------------------
Overflow:
LDI param0, 0x45					;E
CALL UART_Transmit
LDI param0, 0x52					;R
CALL UART_Transmit
LDI param0, 0x52					;R
CALL UART_Transmit
LDI param0, 0x4F					;O
CALL UART_Transmit
LDI param0, 0x52					;R
CALL UART_Transmit
CALL Reset
overflow_loop:
JMP overflow_loop

RET

;-------------------SUMCNT PLUS ONE-------------------
sumcnt_increment:
INC sumcntL
BRVC end
INC sumcntH
RET


;-------------------SUMCNT MINUS ONE-------------------
sumcnt_decrement:
DEC sumcntL
CPI sumcntL, 0xFF
BRNE end
DEC sumcntH
RET

;-------------------CHECK IF THE SUMCNT HAS REACHED THE END-------------------
sumcnt_end_check:
CLR ret0
CP sumendH, sumcntH		; compare the high registers
BRNE end				; if not equal, end the check
CP sumendL, sumcntL		; compare low registers
BRNE end				; if not equal, end the check
PUSH temp0
SBR temp0, 1				; if both are equal, set bit 0 or return
MOV ret0, temp0			; if both are equal, set bit 0 or return
POP temp0
end: RET

;-------------------CHECK IF THE SUMCNT HAS REACHED THE OPERATOR-------------------
sumcnt_op_check:
CLR ret0
CP sumopH, sumcntH		; compare the high registers
BRNE end				; if not equal, end the check
CP sumopL, sumcntL		; compare low registers
BRNE end				; if not equal, end the check
PUSH temp0
SBR temp0, 1			; if both are equal, set bit 0 or return
MOV ret0, temp0			; if both are equal, set bit 0 or return
POP temp0
RET

;-------------------CHECK IF THE SUMCNT HAS REACHED THE BEGIN-------------------
sumcnt_begin_check:
PUSH temp0
CLR ret0
CPI   sumcntH,0x00		; compare the high registers
BRNE not_equal			; if not equal, end the check
CPI   sumcntL,0xFF		; compare low registers
BRNE not_equal			; if not equal, end the check
equal:
SBR temp0, 1
MOV ret0, temp0
POP temp0
RET
not_equal:
CBR temp0, 1
MOV ret0, temp0
POP temp0
RET

;-------------------JMP TO OVERFLOW-------------------
Overflow_path:
JMP Overflow

;-------------------ADD PARAM1:PARAM0 with PARAM3:PARAM2-------------------
Add_16bit:
 ; Add param3:param2 to param1:param0
add param2, param0 ; Add low byte
adc param3, param1; Add with carry high byte
MOVW ret1:ret0, param3:param2
RET

;-------------------MULTIPLY PARAM1:PARAM0 BY PARAM3:PARAM2-------------------
Multiply_16bit:
PUSH temp0
PUSH temp1
PUSH temp2
PUSH temp3

CLR temp0 ; clear for carry operations
MUL param1,param3 ; Multiply MSBs
MOV temp1,outL ; copy to MSW Result
MOV temp2,outH
MUL param0,param2 ; Multiply LSBs
MOV ret0,outL ; copy to LSW Result
MOV ret1,outH
MUL param1,param2 ; Multiply 1M with 2L
ADD ret1,outL ; Add to Result
ADC temp1,outH
ADC temp2,temp0 ; add carry
MUL param0,param3 ; Multiply 1L with 2M
ADD ret1,outL ; Add to Result
ADC temp1,outH
ADC temp2,temp0

CLR temp3
INC temp3
CP temp1, temp3
BRGE Overflow_path

POP temp3
POP temp2
POP temp1
POP temp0

RET

;-------------------DEVIDE PARAM1:PARAM0 BY PARAM3:PARAM2-------------------
Devide_16bit:
PUSH temp0				; remainder low byte
PUSH temp1				; remainder high byte
PUSH temp2				; counter
div16u:	
CLR	temp0			;clear remainder Low byte
SUB	temp1,temp1		;clear remainder High byte and carry
LDI	temp2,17		;init loop counter
d16u_1:	
ROL	param0			; Low byte dividend shift left
ROL	param1			; High byte dividend shift left
DEC	temp2			;decrement counter
BRNE d16u_2			;if done
MOVW ret1:ret0, param1:param0
POP temp2
POP temp1
POP temp0
RET				;    return
d16u_2:	
ROL	temp0		;shift dividend into remainder
ROL	temp1
SUB	temp0,param2		;remainder = remainder - divisor
SBC	temp1,param3		;
BRCC	d16u_3			;if result negative
ADD	temp0,param2		;    restore remainder
ADC	temp1,param3
CLC				;    clear carry to be shifted into result
RJMP	d16u_1			;else
d16u_3:	
SEC				;    set carry to be shifted into result
RJMP	d16u_1

;-------------------SUBTRACT TWO WORDS-------------------
Sub_16bit:
SUB	param0, param2		;Subtract low bytes
SBC	param1, param3
MOVW ret1:ret0, param1:param0
RET

;-------------------TEST IF PARAM0 AND PARAM1 ARE 0-------------------
Test_word_for_zero:
PUSH temp0
CLR ret0
CLR temp0
TST param0
BRNE not_zero
TST param1
BRNE not_zero
SBR temp0, 1
MOV ret0, temp0
POP temp0
RET
not_zero:
CBR temp0, 1
MOV ret0, temp0
POP temp0
RET

 
;-------------------SEND BYTE UART-------------------  
UART_Transmit:
; Wait for empty transmit buffer
LDS temp4, UCSR0A
SBRS temp4, UDRE0
RJMP UART_Transmit
; Put data into buffer, sends the data
STS UDR0, param0
NOP
NOP
RET

;-------------------RESET SYSTEM-------------------
Reset:
CLR opdigi
LDI sumendH, 0x01
LDI sumendL, 0x00
LDI sumcntH, 0x01
LDI sumcntL, 0x00
CLR temp0
CLR temp1
CLR temp2
CLR temp3
CLR temp4
CLR temp5
CLR temp6
CLR temp7
CLR temp8
CLR outL
CLR outH
CLR row1
CLR row2
CLR row3
CLR row4
CLR row1
CLR row2
CLR row3pr
CLR row4pr
CLR ret0
CLR ret1
CLR param0
CLR param1
CLR param2
CLR param3
RET

;-------------------TEST SUM-------------------
Oplosbare_som_1:
; 629-20-4 = 605
; THIS PROVES THE ABILLITY TO
; - READ A THREE DIGIT NUMBER FROM MEMORY
; - READ A TWO DIGIT NUMBER FROM MEMORY
; - SOLVE A SUBTRACT
; - STORE A 3 DIGIT NUMBER WITH A 0
; - FILL UP THE GAPS UNTIL OPERATOR
; - READ A SECOND SUM (IGNORING THE FILLING)
; - READ A ONE DIGIT NUMBER
; - PRINT MEMORY WITH NUMBER 0
LDI temp0, DIGIT6
STS 0x0100, temp0					; 6
LDI temp0, DIGIT2
STS 0x0101, temp0					; 2
LDI temp0, DIGIT9
STS 0x0102, temp0					; 9
LDI temp0, OPERAS
STS 0x0103, temp0					; -
LDI temp0, DIGIT2
STS 0x0104, temp0					; 2
LDI temp0, DIGIT0
STS 0x0105, temp0					; 0
LDI temp0, OPERAS
STS 0x0106, temp0					; -
LDI temp0, DIGIT4
STS 0x0107, temp0					; 4
LDI sumendH, 0x01
LDI sumendL, 0x08
RET

Oplosbare_som_2:
; 20+1000/8 = 145
; THIS PROVES THE ABILLITY TO
; - READ A FOUR DIGIT NUMBER FROM MEMORY
; - READ A ONE DIGIT NUMBER FROM MEMORY
; - SOVE A MULTIPLY/DEVIDE BEFORE ADD/SUBTRACT
; - STORE A THREE DIGIT NUMBER
; - FILL UP THE GAPS UNTIL END
; - READ A SECOND SUM (IGNORING THE FILLING)
; - PRINT MEMORY
LDI temp0, DIGIT2
STS 0x0100, temp0					; 2
LDI temp0, DIGIT0
STS 0x0101, temp0					; 0
LDI temp0, OPERAA
STS 0x0102, temp0					; +
LDI temp0, DIGIT1
STS 0x0103, temp0					; 1
LDI temp0, DIGIT0
STS 0x0104, temp0					; 0
LDI temp0, DIGIT0
STS 0x0105, temp0					; 0
LDI temp0, DIGIT0
STS 0x0106, temp0					; 0
LDI temp0, OPERAD
STS 0x0107, temp0					; /
LDI temp0, DIGIT8
STS 0x0108, temp0					; 8
LDI sumendH, 0x01
LDI sumendL, 0x09
RET

Oplosbare_som_3:
; 1200*10-860/8 = 12000-107= 11893
; THIS PROVES THE ABILLITY TO
; - READ A FOUR DIGIT NUMBER FROM MEMORY
; - READ A TWO DIGIT NUMBER FROM MEMORY
; - SOVE A MULTIPLY/DEVIDE BEFORE ADD/SUBTRACT
; - STORE A FIVE DIGIT NUMBER
; - FILL UP THE GAPS UNTIL END
; - READ A THREE DIGIT NUMBER FROM MEMORY
; - READ A ONE DIGIT NUMBER FROM MEMORY
; - SOVE A MULTIPLY/DEVIDE BEFORE ADD/SUBTRACT
; - ROUND A DIVIDE
; - STORE A THREE DIGIT NUMBER
; - READ A FIVE DIGIT NUMBER
LDI temp0, DIGIT1
STS 0x0100, temp0					; 1
LDI temp0, DIGIT2
STS 0x0101, temp0					; 2
LDI temp0, DIGIT0
STS 0x0102, temp0					; 0
LDI temp0, DIGIT0
STS 0x0103, temp0					; 0
LDI temp0, OPERAM
STS 0x0104, temp0					; *
LDI temp0, DIGIT1
STS 0x0105, temp0					; 1
LDI temp0, DIGIT0
STS 0x0106, temp0					; 0
LDI temp0, OPERAS
STS 0x0107, temp0					; -
LDI temp0, DIGIT8
STS 0x0108, temp0					; 8
LDI temp0, DIGIT6
STS 0x0109, temp0					; 6
LDI temp0, DIGIT0
STS 0x010A, temp0					; 0
LDI temp0, OPERAD
STS 0x010B, temp0					; /
LDI temp0, DIGIT8
STS 0x010C, temp0					; 8
LDI sumendH, 0x01
LDI sumendL, 0x0D
RET

Onoplosbare_som_1:
; 99999-99000 = 999
; The system can't work with numbers this high
LDI temp0, DIGIT9
STS 0x0100, temp0					; 9
LDI temp0, DIGIT9
STS 0x0101, temp0					; 9
LDI temp0, DIGIT9
STS 0x0102, temp0					; 9
LDI temp0, DIGIT9
STS 0x0103, temp0					; 9
LDI temp0, DIGIT9
STS 0x0104, temp0					; 9
LDI temp0, OPERAS
STS 0x0105, temp0					; -
LDI temp0, DIGIT9
STS 0x0106, temp0					; 9
LDI temp0, DIGIT9
STS 0x0107, temp0					; 9
LDI temp0, DIGIT0
STS 0x0108, temp0					; 0
LDI temp0, DIGIT0
STS 0x0109, temp0					; 0
LDI temp0, DIGIT0
STS 0x010A, temp0					; 0
LDI sumendH, 0x01
LDI sumendL, 0x0B
RET

Onoplosbare_som_2:
; 10000*9= 900000
; The solution is too high
LDI temp0, DIGIT1
STS 0x0100, temp0					; 1
LDI temp0, DIGIT0
STS 0x0101, temp0					; 0
LDI temp0, DIGIT0
STS 0x0102, temp0					; 0
LDI temp0, DIGIT0
STS 0x0103, temp0					; 0
LDI temp0, DIGIT0
STS 0x0104, temp0					; 0
LDI temp0, OPERAM
STS 0x0105, temp0					; *
LDI temp0, DIGIT9
STS 0x0106, temp0					; 9
LDI sumendH, 0x01
LDI sumendL, 0x07
RET

Simuleer_oplosbare_som_1:
; 629-20-4 = 605
LDI param0, DIGIT6					; 6
CALL Save_digit
LDI param0, DIGIT2					; 2
CALL Save_digit
LDI param0, DIGIT9					; 9
CALL Save_digit
LDI param0, OPERAS					; -
CALL Save_operator
LDI param0, DIGIT2					; 2
CALL Save_digit
LDI param0, DIGIT0					; 0
CALL Save_digit
LDI param0, OPERAS					; -
CALL Save_operator
LDI param0, DIGIT4					; 4
CALL Save_digit
Call Enter
RET

Simuleer_oplosbare_som_1v2:
; 629-20 BACKSPACE 30-4 = 595
LDI param0, DIGIT6					; 6
CALL Save_digit
LDI param0, DIGIT2					; 2
CALL Save_digit
LDI param0, DIGIT9					; 9
CALL Save_digit
LDI param0, OPERAS					; -
CALL Save_operator
LDI param0, DIGIT2					; 2
CALL Save_digit
LDI param0, DIGIT0					; 0
CALL Save_digit
CALL Backspace
LDI param0, DIGIT3					; 3
CALL Save_digit
LDI param0, DIGIT0					; 0
CALL Save_digit
LDI param0, OPERAS					; -
CALL Save_operator
LDI param0, DIGIT4					; 4
CALL Save_digit
CALL Enter
RET

;-------------------DO SOME CHECKING AND SAVE THE INPUT (DIGIT)-------------------
Save_digit:
CPI sumendH, 0x01
BRNE later_digit
CPI sumendL, 0x00
BRNE later_digit			;check if this is the first digit that is stored
TST opdigi					; there is nothing in memory yet, is the opdigi is 0
BRNE later_digit			
fist_digit:
MOV opdigi, param0			; if this is the first digit, only store this in de opdigi
LDI param0, 0x30
ADD param0, opdigi
CALL UART_Transmit
RET
later_digit:
PUSH temp0
ST X+, opdigi				; if this is a later digit, the opditi can be stored in memory
MOV opdigi, param0
LDI temp0, 0x30				; make ascii number
ADD param0, temp0
CALL UART_Transmit
POP temp0
RET

;-------------------DO SOME CHECKING AND SAVE INPUT (OPERATOR)-------------------
Save_operator:
CPI sumendH, 0x01
BRNE not_first_digit
CPI sumendL, 0x00
BRNE not_first_digit			;check if this is the first digit that is stored
RET
not_first_digit:
LDI temp5, 0x10
CP opdigi, temp5				; check if previous was an operator too
BRGE second_operator
ST X+, opdigi
MOV opdigi, param0
JMP send_operator

second_operator:
MOV opdigi, param0
LDI param0, 0x08				; Backspace
CALL UART_Transmit
JMP send_operator

send_operator:
LDI temp5, 0x10
CP opdigi, temp5				; check if +
BREQ send_plus
LDI temp5, 0x20
CP opdigi, temp5				; check if -
BREQ send_minus
LDI temp5, 0x40
CP opdigi, temp5				; check if *
BREQ send_multiply
LDI temp5, 0x80
CP opdigi, temp5				; check if /
BREQ send_devide

send_plus:
LDI param0, 0x2B
CALL UART_Transmit
RET
send_minus:
LDI param0, 0x2D
CALL UART_Transmit
RET
send_multiply:
LDI param0, 0x2F
CALL UART_Transmit
RET
send_devide:
LDI param0, 0x2A
CALL UART_Transmit
RET

;-------------------DO BACKSPACE-------------------
Backspace:
PUSH temp0
scrollback:
LD opdigi, -X
LDI temp0, 0x10
CP opdigi, temp0				; check if previous was an operator too
BRGE op_found
CPI sumendH, 0x00
BRNE overwrite
CPI sumendL, 0xFF
BREQ op_found					; if begin of the sum has been met, end this routine
overwrite:
LDI temp0, EMPTYB
ST X, temp0
CALL Do_backspace
JMP scrollback
op_found:
CALL Do_backspace
LD temp0, X+
CLR opdigi
POP temp0
RET
;-------------------ERASE DIGIT OFF SCREEN-------------------
Do_backspace:
LDI param0, 0x08		;backspace sign
CALL UART_Transmit
LDI param0, 0x20		; space sign
CALL UART_Transmit
LDI param0, 0x08		;backspace sign
CALL UART_Transmit
RET

;-------------------FINISH THE SUM-------------------
Enter:
MOV temp0, opdigi					; copy last digit/operant
CPI temp0, 0x10						; check if operant
BRGE nextline						; opdigi is operand, don't save it
ST X+, opdigi
nextline:
LDI param0, 0x0A
CALL UART_Transmit
LDI param0, 0x0D
CALL UART_Transmit
RET