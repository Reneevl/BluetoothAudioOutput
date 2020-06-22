;-------------------GPIO INITIALISATION-------------------
GPIO_Init:
LDI temp0, (1 << PD2 )|(1 << PD3 )|(1 << PD4 )|(1 << PD5 )|(1 << PD6 )
OUT PORTD, temp0
LDI temp0, (1 << DDB1 )|(1 << DDB2 )|(1 << DDB3 )|(1 << DDB4 )
OUT DDRB, temp0


;-------------------MULTIPLEXING LOOP-------------------
loop:
;CHECK BUTTON 1 2 3 4
LDI temp0, (1 << PB2)|(1 << PB3)|(1 << PB4)		; Button	1	2	3	4	high
OUT PORTB, temp0			
NOP
NOP
IN row1, PIND				;			PD7 PD6 PD5 PD4
MOV param1, row1pr
MOV param0, row1
CALL ToggleCheck		; Do the togglecheck
MOV param0, ret0
CALL decode_row1
MOV row1pr, row1				; Update old and new
;CHECK BUTTON 5 6 7 8
LDI temp0, (1 << PB1)|(1 << PB3)|(1 << PB4)			; Button	5	6	7	8	high
OUT PORTB, temp0
NOP
NOP
IN row2, PIND				;			PD7 PD6 PD5 PD4
MOV param1, row2pr
MOV param0, row2
CALL ToggleCheck		; Do the togglecheck
MOV param0, ret0
CALL decode_row2
MOV row2pr, row2			; Update old and new
;CHECK BUTTON 9 0 + -
LDI temp0, (1 << PB1)|(1 << PB2)|(1 << PB4)			; Button	9	0	+	-	high
OUT PORTB, temp0
NOP
NOP
IN row3, PIND				;			PD7 PD6 PD5 PD4
MOV param1, row3pr
MOV param0, row3
CALL ToggleCheck		; Do the togglecheck
MOV param0, ret0
CALL decode_row3
MOV row3pr, row3				; Update old and new
;CHECK BUTTON * / BACKSPACE ERASE =
LDI temp0, (1 << PB1)|(1 << PB2)|(1 << PB3)			; Button	*	/	Erase	Backspace	=	high
OUT PORTB, temp0
NOP
NOP
IN row4, PIND				;			PD7 PD6 PD5		PD4			PD3
MOV param1, row4pr
MOV param0, row4
CALL ToggleCheck		; Do the togglecheck
MOV param0, ret0
CALL decode_row4
MOV row4pr, row4			; Update old and new

RJMP loop

;-------------------CHECK FOR A TOGGLE-------------------
ToggleCheck:
CLR ret0
CP param0, param1			; param0 is new param1 is old
BRLT end_check				; branch if new is smaller than old
BREQ end_check				;
greateq:
MOV ret0, param0
SUB ret0, param1
end_check: 
RET

;-------------------DECODE BUTTON INPUT-------------------
decode_row1:
TST ret0
BRNE decode
RET
decode:
CPI param0, (1 << PD2)
BREQ send_1
CPI param0, (1 << PD3)
BREQ send_2
CPI param0, (1 << PD4)
BREQ send_3
CPI param0, (1 << PD5)
BREQ send_4
RET
send_1:
LDI param0, 0x01
CALL Save_digit
RET
send_2:
LDI param0, 0x02
CALL  Save_digit
RET
send_3:
LDI param0, 0x03
CALL  Save_digit
RET
send_4:
LDI param0, 0x04
CALL  Save_digit
RET

decode_row2:
TST ret0
BRNE decode2
RET
decode2:
CPI param0, (1 << PD2)
BREQ send_5
CPI param0, (1 << PD3)
BREQ send_6
CPI param0, (1 << PD4)
BREQ send_7
CPI param0, (1 << PD5)
BREQ send_8
RET
send_5:
LDI param0, 0x05
CALL Save_digit
RET
send_6:
LDI param0, 0x06
CALL Save_digit 
RET
send_7:
LDI param0, 0x07
CALL Save_digit 
RET
send_8:
LDI param0, 0x08
CALL Save_digit
RET

decode_row3:
TST ret0
BRNE decode3
RET
decode3:
CPI param0, (1 << PD2)
BREQ send_9
CPI param0, (1 << PD3)
BREQ send_0
CPI param0, (1 << PD4)
BREQ send_A
CPI param0, (1 << PD5)
BREQ send_S
RET
send_9:
LDI param0, 0x09
CALL Save_digit 
RET
send_0:
LDI param0, 0x00
CALL Save_digit 
RET
send_A:
LDI param0, 0x10
CALL Save_operator
RET
send_S:
LDI param0, 0x20
CALL Save_operator
RET

decode_row4:
TST ret0
BRNE decode4
RET
decode4:
CPI param0, (1 << PD2)
BREQ send_M
CPI param0, (1 << PD3)
BREQ send_D
CPI param0, (1 << PD4)
BREQ send_BS
CPI param0, (1 << PD5)
BREQ send_E
CPI param0, (1 << PD6)
CALL Solve
CALL Reset
RET
send_M:
LDI param0, 0x40
CALL Save_operator
RET
send_D:
LDI param0, 0x80
CALL Save_operator 
RET
send_BS:
CALL Backspace
RET
send_E:
CALL Erase
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
LD temp0, X+
POP temp0
RET
;-------------------ERASE SUM-------------------
Erase:
PUSH temp0
LDI param0, 0x45
CALL UART_Transmit
Eraseloop:
LD opdigi, -X
CPI sumendH, 0x00
BRNE delete
CPI sumendL, 0xFF
BREQ begin
delete:
CALL Do_backspace
LDI temp0, EMPTYB
ST X, temp0
JMP Eraseloop
begin:
LD temp0, X+
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

;-------------------RESET MEMORY-------------------
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