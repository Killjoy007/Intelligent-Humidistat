#make_bin#

#LOAD_SEGMENT=FFFFh#
#LOAD_OFFSET=0000h#

#CS=0000h#
#IP=0000h#

#DS=0000h#
#ES=0000h#

#SS=0000h#
#SP=FFFEh#

#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#

jmp	start       

		db	1024 dup(0)		

curr_temp	db	?			;current temperature
curr_humdt	db	?			;current humidity
ideal_humdt	db 	?			;ideal humidity
neg_flag	db	00h

print_temp	db	"Temperature"
print_humd	db	"Humidity   "

;8255_1 for LCD
port1A	equ	00h	;input to LCD
port1B	equ	02h	;controlling the LCD
port1C	equ	04h
creg1	equ	06h	;control register (8255_1)


;8255_2 for ADC
port2A	equ	08h	
port2B	equ	0ah	;taking output from ADC
port2C	equ	0ch	;PC0 - controlling whether to select temperature sensor or humidity sensor
			;PC7 - turning on the humidifier
creg2	equ	0eh	;control register (8255_2)


;8253 for generating clock signal to ADC
cnt0	equ	10h	;counter 0
creg3	equ	16h	;control register

	
start:	cli
	
	;intialize ds, es, ss to the start of ROM
	mov	ax, 0000h
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0fffeh
	
	;initializing 8255
	sti
	
	mov	al, 88h		;control word for 8255_1 (for LCD)	
	out	creg1, al	;Port-A for 8-bit data to be sent to LCD
				;PB0 to control RS of LCD
				;PB1 to control R/W of LCD
				;PB2 to control E of LCD
	
	mov	al, 82h		;control word for 8255_2 (for ADC)
	out 	creg2, al	;Port-B for output from ADC
				;PC0 to select from Temperature Sensor and Humidity Sensor
				;PC7 to control whether to switch on the humidifier or not
	
	;initializing 8253
	mov	al, 16h		;Counter 0 to work in mode-3
	out	creg3, al	;control word for 8253
	
	mov	al, 5
	out	cnt0, al	;count value of 5 given to Counter 0
	
	;initializing LCD
	
	
	;FUNCTION SET
	
	;D7	D6	D5	D4	D3	D2	D1	D0
	;0	0	1	DL	N	F	*	*
	
	;DL = Data Length (1: 8-bit, 0: 4-bit)
	;N  = Number of Display Lines (1: 2 lines, 0: 1 line)
	;F  = Character Font (1: 5x10 dots, 0: 5x7 dots)
	
	;Cannot display 2 lines with 5x10 dots character font
	
	mov	al, 38h		;function set
	call	cmndwrt
	
	
	;DISPLAY ON
	
	;D7	D6	D5	D4	D3	D2	D1	D0
	;0	0	0	0	1	D	C	B
	
	;D = Display (1: On, 0: Off)
	;C = Display Cursor (1: On, 0: Off)
	;B = Blink (1: On, 0: Off)
	
	mov	al, 0ch		;display on
	call 	cmndwrt
	
	
	;ENTRY MODE SET
	
	;D7	D6	D5	D4	D3	D2	D1	D0
	;0	0	0	0	0	1	I/D	S
	
	;I/D = Sets the cursor move direction
	;S   = Whether to shift the display after read/write operation
	
	mov	al, 06h
	call	cmndwrt
	
	

main:	call	getHumdt
	call	getTemp
	
	call	display_LCD
	
	mov	al, ideal_humdt
	mov	bl, curr_humdt
	cmp	bl, al
	jl	inc_hum
	jmp	rpt
	
inc_hum:	call	inc_humdt
		jmp	rpt
		
rpt:		call	delay_major
		jmp	main



delay_minor proc near			;0.1 ms delay

	push	cx

	mov    	cl, 30
d1:	dec 	cl
	jnz 	d1
	
	pop	cx
	
	ret
	
delay_minor endp
	
	
	
delay_std proc near			;3 ms delay

	push	cx
	
	mov	cx, 900
d2:	dec 	cx
	jnz 	d2
		
	pop	cx
	
	ret
	
delay_std endp 



delay_major proc near			;218 ms delay

	push	cx
	push	dx
	
	mov	dx, 2
d4:	mov	cx, 0ffffh
d3:	dec 	cx
	jnz 	d3
	dec	dx
	jnz	d4
	
	pop	dx
	pop	cx
	
	ret
	
delay_major endp 



getTemp proc	near			;get Temperature through ADC
	
	mov	al, 00h
	out	creg2, al		;PC0 = 0 (Using BSR)
					;to get the current temperature from the sensor via ADC
					;(ADD A = 0 in ADC is connected to temperature sensor)
	call 	delay_major
	mov     al,82h
        out     creg2,al
	in	al, port2B		;The ADC Output values shall be ranging from 00h - 64h (0 - 100 in decimals)
	
	mov	curr_temp, al
	mov	ideal_humdt, al
	
	sub	curr_temp, 40
	cmp	curr_temp, 0
	jge	pos
	
	mov	neg_flag, 01h
	mov	al, ideal_humdt
	mov	cl, 40
	sub	cl, al
	mov	al, cl
	jmp	con
	
pos:	mov	neg_flag, 00h
	mov	al, curr_temp
	
con:	call 	convBCD
	
	ret
	
getTemp	endp


getHumdt proc	near			;get Temperature through ADC
	
	mov	al, 01h
	out	creg2, al		;PC0 = 1 (Using BSR)
					;to get the current humidity from the sensor via ADC
					;(ADD A = 1 in ADC is connected to humidity sensor)
	call	delay_major
	
	mov     al,82h
        out     creg2,al
	in 	al, port2B
	
	mov	curr_humdt, al
	
	call	convBCD
	mov	dx, bx
	
	ret
	
getHumdt endp

inc_humdt proc	near

	
	
	mov	al, 0fh
	out	creg2, al
	
	ret
	
inc_humdt endp



display_LCD proc	near		;Displays temperature and humidity on LCD
	
	push	ax
	push	cx
	push	si
	
	lea	si, print_temp		;Displays the word "Temperature"
	mov	cx, 11
	
pt1:	mov	al, [si]
	call	datawrt
		
	inc	si
	dec	cx
	jnz	pt1
	
	;call 	delay_minor
	
	cmp	neg_flag, 00h
	jz	p1
	
	mov	al, "-"			;Displays '-' if the temperature is negative
	jmp	n1
p1:	mov	al, " "			;Displays space if the temperature is positive
n1:	call 	datawrt
	
	
	;BX register stores the value of current temperature
	;The contents in BH and BL registers are already converted to the corresponding ASCII values
	
	mov	al, bh			;Displays the contents of BH register
	call 	datawrt			
	
	mov	al, bl			;Displays the contents of BL register
	call 	datawrt	
	
	mov	al, 0dfh		;Displays "°C" (degree celsius)
	call 	datawrt	
	
	mov	al, "C"			
	call	datawrt
	

	;call	delay_std
	;call	delay_std
	
	mov	al, 0c0h		;Shift to next line of LCD Display
	call	cmndwrt
	
	
	lea	si, print_humd		;Displays the word "Humidity"
	mov	cx, 11
	
ph1:	mov	al, [si]
	call	datawrt
	
	inc	si
	dec	cx
	jnz	ph1
	
	
	;DX register stores the value of humidity
	;The contents in DH and DL registers are already converted to the corresponding ASCII values
	cmp	curr_humdt, 100
	jne	x1
	mov	al, "1"			;Displays "1" only if curr_humdt = 100%,
	jmp	x2			;else displays " "

x1:	mov	al, " "
x2:	call 	datawrt
	
	mov	al, dh			;Displays the contents of DH register
	call	datawrt	
	
	mov	al, dl			;Displays the contents of DL register
	call 	datawrt	

	mov	al, "%"			;Displays "%" symbol
	call 	datawrt	
	
	
	mov	al, 00h
	out	port1B, al
	call	delay_minor
	mov	al, 80h
	call	cmndwrt
	
	
	pop si
	pop cx
	pop ax
	
	ret
	
display_LCD endp


cmndwrt proc	near			;Writing the commands to LCD Display
	
	out	port1A, al
	call	delay_minor
	mov	al, 04h			;Giving high to low transition to Enable signal keeping RS = 0 and R/W = 0
	out	port1B, al
	call	delay_minor
	mov	al, 00h
	out	port1B, al
	call	delay_minor
	
	ret
	
cmndwrt endp

datawrt proc	near			;Writing the data to display on LCD Display

	out	port1A, al
	call	delay_minor
	mov	al, 05h			;Giving high to low transition to Enable signal keeping RS = 1 and R/W = 0
	out	port1B, al
	call	delay_minor
	mov	al, 01h
	out	port1B, al
	call	delay_minor
	
	ret
	
datawrt endp



;To convert Binary numbers to BCD form
;The binary number to be converted is stored in AL register
;The BCD form is stored in BX register
;This procedure has already converted the BCD form to its corresponding ASCII values to display them on LCD

convBCD proc	near                    ;convert Binary to BCD
		
	mov     bh,0ffH

c1:  	inc	bh
        sub	al, 0ah
	jnc	c1
	add	al, 0ah
	mov	bl, 30h
	add	bh, bl
	add	bl, al
	
	cmp	bh, 3ah			;if curr_humdt is equal to 100%, value of bh becomes 3ah
	jne	c2			
	mov	bh, 30h			;bh = 30h and bl = 30h, to display "00" of "100"
	
c2:	ret

convBCD endp