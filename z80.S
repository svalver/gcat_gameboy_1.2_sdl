@
@ GCat's Gameboy Emulator
@ Copyright (c) 2012 James Perry
@
@ This program is free software: you can redistribute it and/or modify
@ it under the terms of the GNU General Public License as published by
@ the Free Software Foundation, either version 3 of the License, or
@ (at your option) any later version.
@
@ This program is distributed in the hope that it will be useful,
@ but WITHOUT ANY WARRANTY; without even the implied warranty of
@ MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
@ GNU General Public License for more details.
@
@ You should have received a copy of the GNU General Public License
@ along with this program.  If not, see <http://www.gnu.org/licenses/>.
@

@
@ Main part of ARM Z80 emulation core
@

@
@ Flags on Gameboy:
@   - d7 - zero
@   - d6 - subtract
@   - d5 - half-carry
@   - d4 - carry
@   - d3-d0 - unused
@

#define GAMEBOY
	
@============================================================
@
@ Macros to simplify instruction implementations
@
@============================================================
@ General
#define END_INSN(cycles) \
	adds	r10, r10, cycles ; \
	bpl	done_execute	 ; \
	b	check_interrupt	 ; \

@ Memory access
@
@ For reading, should be able to divide into 8K pages and read normally.
@ (Possibly need to do special things when reading some registers (FF00+))
@ For writing, need to handle:
@   - paging (when writing to ROM addresses)
@   - RAM writes (VRAM, cartridge, internal)
@   - Register writes
@ Register writes may be special (and VRAM?)
@
@ r11 should point to read page table followed by write page table
@
#define READ_BYTE(dest, addr, scratch1, scratch2) \
	mov	scratch1, addr, lsr #13 ; \
	ldr	scratch2,[r11, scratch1, lsl #2] ; \
	cmp	addr, #0xfe00			 ; \
	ldrge	scratch2, [r11, #72]		 ; \
	bic	scratch1, addr, #0xe000     ; \
	ldrb	dest, [scratch2, scratch1]	     ; \

#define READ_SIGNED_BYTE(dest, addr, scratch1, scratch2) \
	mov	scratch1, addr, lsr #13 ; \
	ldr	scratch2,[r11, scratch1, lsl #2] ; \
	cmp	addr, #0xfe00			 ; \
	ldrge	scratch2, [r11, #72]		 ; \
	bic	scratch1, addr, #0xe000     ; \
	ldrsb	dest, [scratch2, scratch1]	     ; \

#define WRITE_BYTE(src, addr, scratch1, scratch2) \
	/* check for writes to ROM addresses - paging */ \
	mov	scratch1, addr, lsr #13		 ; \
	cmp	scratch1, #0x4			 ; \
	/* get paging registers base */ \
	add	scratch2, r0, #108		 ; \
	strltb	src, [scratch2, scratch1]	 ; \
	bllt	paging_write			 ; \
	/* do normal paged write */ \
	mov	scratch1, addr, lsr #13		 ; \
	add	scratch1, scratch1, #8		 ; \
	ldr	scratch2, [r11, scratch1, lsl #2] ; \
	cmp	addr, #0xfe00			  ; \
	ldrge	scratch2, [r11, #72]		  ; \
	bic	scratch1, addr, #0xe000		  ; \
	strb	src, [scratch2, scratch1]	  ; \
	/* check for I/O register writes */ \
	cmp	addr, #0xff00	       ; \
	/* store address of register just written and call io_write */ \
	strgeb	addr, [r0, #74]			  ; \
	blge	io_write			  ; \

	
	
@ 8-bit arithmetic and logical
#define INC8_HI(reg, scratch1) \
	add	reg, reg, #256	; \
	bic	reg, reg, #65536 ; \
	/* need to set Z and H and clear N */\
	/* clear N, Z, H */\
	bic	r4, r4, #0xe000 ; \
	/* set Z */\
	tst	reg, #0xff00 	; \
	orreq	r4, r4, #0x8000 ; \
	/* set H */\
	tst	scratch1, #0x0f00	    ; \
	orreq	r4, r4, #0x2000		    ; \

	
#define INC8_LO(reg, scratch1) \
	add	scratch1, reg, #1	; \
	and	scratch1, scratch1, #0xff ; \
	bic	reg, reg, #0xff		  ; \
	orr	reg, reg, scratch1	  ; \
	/* first clear N, Z, H */\
	bic	r4, r4, #0xe000 ; \
	/* set Z */\
	tst	reg, #0xff 	; \
	orreq	r4, r4, #0x8000 ; \
	/* set H */\
	tst	scratch1, #0x0f	; \
	orreq	r4, r4, #0x2000	; \

	
#define DEC8_HI(reg, scratch1) \
	sub	reg, reg, #256	; \
	bic	reg, reg, #0xff000000 ; \
	bic	reg, reg, #0xff0000   ; \
	/* clear Z, H and set N */\
	bic	r4, r4, #0xe000 ; \
	orr	r4, r4, #0x4000 ; \
	/* set Z */\
	tst	reg, #0xff00 	; \
	orreq	r4, r4, #0x8000 ; \
	/* set H */\
	and	scratch1, scratch1, #0x0f00 ; \
	cmp	scratch1, #0x0f00 ; \
	orreq	r4, r4, #0x2000		    ; \


#define DEC8_LO(reg, scratch1) \
	sub	scratch1, reg, #1	; \
	and	scratch1, scratch1, #0xff ; \
	bic	reg, reg, #0xff		  ; \
	orr	reg, reg, scratch1	  ; \
	/* first clear Z, H, set N */\
	bic	r4, r4, #0xe000 ; \
	orr	r4, r4, #0x4000 	; \
	/* set Z */\
	tst	reg, #0xff 	; \
	orreq	r4, r4, #0x8000 ; \
	/* set H */\
	and	scratch1, scratch1, #0x0f ; \
	cmp	scratch1, #0x0f		  ; \
	orreq	r4, r4, #0x2000		  ; \
	

#define RRC8_HI(reg, scratch1, scratch2) \
	mov	scratch1, reg, lsr #8 ; \
	mov	scratch2, scratch1, lsr #1 ; \
	orr	scratch2, scratch2, scratch1, lsl #7 ; \
	ands	scratch2, scratch2, #0xff	     ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	/* zero */\
	orreq	r4, r4, #0x8000		       ; \
	/* carry */\
	and	scratch1, scratch2, #0x80 ; \
	orr	r4, r4, scratch1, lsl #5  ; \
	/* store result back in register*/\
	bic	reg, reg, #0xff00 ; \
	orr	reg, reg, scratch2, lsl #8 ; \


#define RRC8_LO(reg, scratch1, scratch2) \
	and	scratch1, reg, #0xff ; \
	mov	scratch2, scratch1, lsr #1 ; \
	orr	scratch2, scratch2, scratch1, lsl #7 ; \
	ands	scratch2, scratch2, #0xff	     ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	/* zero */\
	orreq	r4, r4, #0x8000		       ; \
	/* carry */\
	and	scratch1, scratch2, #0x80 ; \
	orr	r4, r4, scratch1, lsl #5  ; \
	/* store result back in register*/\
	bic	reg, reg, #0xff ; \
	orr	reg, reg, scratch2 ; \

	
	
	@ RLC:
	@ - Carry set by bit 7 of source
	@ - H and N set to 0
	@ - S, Z, P, undoc set from logic table
#define RLC8_HI(reg, scratch1, scratch2) \
	mov	scratch1, reg, lsr #8 ; \
	mov	scratch2, scratch1, lsl #1 ; \
	orr	scratch2, scratch2, scratch1, lsr #7 ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	/* zero */\
	tst	scratch2, #0xff     ; \
	orreq	r4, r4, #0x8000		      ; \
	/* carry */\
	and	scratch1, scratch2, #0x100 ; \
	and	scratch2, scratch2, #0xff  ; \
	orr	r4, r4, scratch1, lsl #4	   ; \
	/* store result back in register*/\
	bic	reg, reg, #0xff00		     ; \
	orr	reg, reg, scratch2, lsl #8	     ; \
	
	
#define RLC8_LO(reg, scratch1, scratch2) \
	and	scratch1, reg, #0xff ; \
	mov	scratch2, scratch1, lsl #1 ; \
	orr	scratch2, scratch2, scratch1, lsr #7 ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	/* zero */\
	tst	scratch2, #0xff		      ; \
	orreq	r4, r4, #0x8000		      ; \
	/* carry */\
	and	scratch1, scratch2, #0x100 ; \
	and	scratch2, scratch2, #0xff  ; \
	orr	r4, r4, scratch1, lsl #4	   ; \
	/* store result back in register*/\
	bic	reg, reg, #0xff		     ; \
	orr	reg, reg, scratch2	     ; \


#define RL8_HI(reg, scratch1, scratch2) \
	mov	scratch2, reg, lsr #7 ; \
	and	scratch2, scratch2, #0xfe ; \
	and	scratch1, r4, #0x1000	  ; \
	orr	scratch2, scratch2, scratch1, lsr #12 ; \
	mov	scratch1, reg, lsr #7		     ; \
	and	scratch1, scratch1, #0x100	     ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	/* zero */\
	tst	scratch2, #0xff		      ; \
	orreq	r4, r4, #0x8000		      ; \
	/* carry */\
	orr	r4, r4, scratch1, lsl #4	   ; \
	/* store result back in register*/\
	bic	reg, reg, #0xff00		     ; \
	orr	reg, reg, scratch2, lsl #8	     ; \
	

#define RL8_LO(reg, scratch1, scratch2) \
	mov	scratch2, reg, lsl #1 ; \
	and	scratch2, scratch2, #0xfe ; \
	and	scratch1, r4, #0x1000	  ; \
	orr	scratch2, scratch2, scratch1, lsr #12 ; \
	mov	scratch1, reg, lsl #1		     ; \
	and	scratch1, scratch1, #0x100	     ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	/* zero */\
	tst	scratch2, #0xff		      ; \
	orreq	r4, r4, #0x8000		      ; \
	/* carry */\
	orr	r4, r4, scratch1, lsl #4	   ; \
	/* store result back in register*/\
	bic	reg, reg, #0xff		     ; \
	orr	reg, reg, scratch2	     ; \

	
#define RR8_HI(reg, scratch1, scratch2) \
	mov 	scratch2, reg, lsr #9 ; \
	and	scratch1, r4, #0x1000  ; \
	orr	scratch2, scratch2, scratch1, lsr #5 ; \
	and	scratch1, reg, #0x100		     ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	/* zero */\
	tst	scratch2, #0xff		      ; \
	orreq	r4, r4, #0x8000		      ; \
	/* carry */\
	orr	r4, r4, scratch1, lsl #4	   ; \
	/* store result back in register*/\
	bic	reg, reg, #0xff00		     ; \
	orr	reg, reg, scratch2, lsl #8	     ; \
	
		
#define RR8_LO(reg, scratch1, scratch2) \
	mov 	scratch2, reg, lsr #1 ; \
	and	scratch2, scratch2, #0x7f	     ; \
	and	scratch1, r4, #0x1000  ; \
	orr	scratch2, scratch2, scratch1, lsr #5 ; \
	and	scratch1, reg, #0x1		     ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	/* zero */\
	tst	scratch2, #0xff		      ; \
	orreq	r4, r4, #0x8000		      ; \
	/* carry */\
	orr	r4, r4, scratch1, lsl #12	   ; \
	/* store result back in register*/\
	bic	reg, reg, #0xff		     ; \
	orr	reg, reg, scratch2	     ; \

	
#define SLA8_HI(reg, scratch1, scratch2) \
	mov	scratch2, reg, lsr #7 ; \
	bic	scratch2, scratch2, #1 ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	and	scratch1, scratch2, #0x100 ; \
	ands	scratch2, scratch2, #0xff  ; \
	orr	r4, r4, scratch1, lsl #4	   ; \
	orreq	r4, r4, #0x8000			   ; \
	/* store result back in register */\
	bic	reg, reg, #0xff00 ; \
	orr	reg, reg, scratch2, lsl #8 ; \
	
	
#define SLA8_LO(reg, scratch1, scratch2) \
	and	scratch2, reg, #0xff	      ; \
	mov	scratch2, scratch2, lsl #1    ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	and	scratch1, scratch2, #0x100 ; \
	ands	scratch2, scratch2, #0xff  ; \
	orr	r4, r4, scratch1, lsl #4	   ; \
	orreq	r4, r4, #0x8000			   ; \
	/* store result back in register */\
	bic	reg, reg, #0xff ; \
	orr	reg, reg, scratch2 ; \

	
#define SRA8_HI(reg, scratch1, scratch2) \
	mov	scratch2, reg, lsr #9 ; \
	mov	scratch1, reg, lsr #8 ; \
	and	scratch1, scratch1, #0x80      ; \
	orr	scratch2, scratch2, scratch1   ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	and	scratch1, reg, #0x100 ; \
	orr	r4, r4, scratch1, lsl #4      ; \
	tst	scratch2, #0xff		      ; \
	orreq	r4, r4, #0x8000		      ; \
	/* store result back in register */\
	bic	reg, reg, #0xff00 ; \
	orr	reg, reg, scratch2, lsl #8 ; \
	
	
#define SRA8_LO(reg, scratch1, scratch2) \
	and	scratch2, reg, #0xff ; \
	mov	scratch2, scratch2, lsr #1 ; \
	and	scratch1, reg, #0x80	   ; \
	orr	scratch2, scratch2, scratch1   ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	and	scratch1, reg, #0x1 ; \
	orr	r4, r4, scratch1, lsl #12      ; \
	tst	scratch2, #0xff		       ; \
	orreq	r4, r4, #0x8000		       ; \
	/* store result back in register */\
	bic	reg, reg, #0xff ; \
	orr	reg, reg, scratch2 ; \

#ifndef GAMEBOY
#define SLL8_HI(reg, scratch1, scratch2) \
	mov	scratch2, reg, lsr #7 ; \
	orr	scratch2, scratch2, #1 ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	/* carry */\
	and	scratch1, scratch2, #0x100 ; \
	and	scratch2, scratch2, #0xff  ; \
	orr	r4, r4, scratch1	   ; \
	/* other flags */\
	ldr	scratch1,[r0, #44] ; \
	ldrb	scratch1,[scratch1, scratch2] ; \
	orr	r4, r4, scratch1, lsl #8      ; \
	/* store result back in register */\
	bic	reg, reg, #0xff00 ; \
	orr	reg, reg, scratch2, lsl #8 ; \

	
#define SLL8_LO(reg, scratch1, scratch2) \
	and	scratch2, reg, #0xff	      ; \
	mov	scratch2, scratch2, lsl #1    ; \
	orr	scratch2, scratch2, #1	      ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	/* carry */\
	and	scratch1, scratch2, #0x100 ; \
	and	scratch2, scratch2, #0xff  ; \
	orr	r4, r4, scratch1	   ; \
	/* other flags */\
	ldr	scratch1,[r0, #44] ; \
	ldrb	scratch1,[scratch1, scratch2] ; \
	orr	r4, r4, scratch1, lsl #8      ; \
	/* store result back in register */\
	bic	reg, reg, #0xff ; \
	orr	reg, reg, scratch2 ; \

#else
@ swap nibbles on gameboy
#define SLL8_HI(reg, scratch1, scratch2) \
	and	scratch1, reg, #0x0f00 		; \
	and	scratch2, reg, #0xf000		; \
	mov	scratch2, scratch2, lsr #4	; \
	orrs	scratch2, scratch2, scratch1, lsl #4 ; \
	bic	reg, reg, #0xff00		     ; \
	orr	reg, reg, scratch2		     ; \
	bic	r4, r4, #0x8000			     ; \
	orreq	r4, r4, #0x8000			     ; \
	
	
#define SLL8_LO(reg, scratch1, scratch2) \
	and	scratch1, reg, #0x0f 		; \
	and	scratch2, reg, #0xf0		; \
	mov	scratch2, scratch2, lsr #4	; \
	orrs	scratch2, scratch2, scratch1, lsl #4 ; \
	bic	reg, reg, #0xff		     ; \
	orr	reg, reg, scratch2		     ; \
	bic	r4, r4, #0x8000			     ; \
	orreq	r4, r4, #0x8000			     ; \

#endif
	
	
#define SRL8_HI(reg, scratch1, scratch2) \
	mov	scratch2, reg, lsr #9 ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	and	scratch1, reg, #0x100 ; \
	orr	r4, r4, scratch1, lsl #4      ; \
	tst	scratch2, #0xff		      ; \
	orreq	r4, r4, #0x8000		      ; \
	/* store result back in register */\
	bic	reg, reg, #0xff00 ; \
	orr	reg, reg, scratch2, lsl #8 ; \

	
#define SRL8_LO(reg, scratch1, scratch2) \
	and	scratch2, reg, #0xff ; \
	mov	scratch2, scratch2, lsr #1 ; \
	/* do flags */\
	bic	r4, r4, #0xff00 ; \
	and	scratch1, reg, #0x1 ; \
	orr	r4, r4, scratch1, lsl #12      ; \
	tst	scratch2, #0xff		       ; \
	orreq	r4, r4, #0x8000		       ; \
	/* store result back in register */\
	bic	reg, reg, #0xff ; \
	orr	reg, reg, scratch2 ; \
	
	
#define BIT_TEST(reg, bit) \
	bic	r4, r4, #0xef00 ; \
	orr	r4, r4, #0x2000 ; \
	tst	reg, bit 	; \
	orreq	r4, r4, #0x8000 ; \
	
	
#define BIT_TEST7(reg, bit) \
	bic	r4, r4, #0xef00 ; \
	orr	r4, r4, #0x2000 ; \
	tst	reg, bit 	; \
	orreq	r4, r4, #0x8000 ; \


#define ADD8(reg1, scratch1, scratch2) \
	/* compute half-carry */\
	and	scratch1, r4, #0x0f	   	; \
	and	scratch2, reg1, #0x0f		; \
	add	scratch1, scratch1, scratch2	; \
	and	scratch2, scratch1, #0x10	; \
	/* actual add */\
	and	scratch1, r4, #0xff 		; \
	add	scratch1, scratch1, reg1	; \
	and	r4, r4, #0xff000000		; \
	orr	r4, r4, scratch2, lsl #9	; \
	mov	scratch2, scratch1, lsr #8	; \
	orr	r4, r4, scratch2, lsl #12	; \
	ands	scratch1, scratch1, #0xff	; \
	orr	r4, r4, scratch1		; \
	orreq	r4, r4, #0x8000			; \

	
#define ADC8(reg1, scratch1, scratch2) \
	/* compute half-carry */\
	and	scratch1, r4, #0xf	   	; \
	and	scratch2, reg1, #0xf		; \
	add	scratch1, scratch1, scratch2	; \
	tst	r4, #0x1000			; \
	addne	scratch1, scratch1, #1		; \
	and	scratch2, scratch1, #0x10	; \
	/* actual adc */\
	and	scratch1, r4, #0xff 		; \
	add	scratch1, scratch1, reg1	; \
	tst	r4, #0x1000			; \
	addne	scratch1, scratch1, #1		; \
	and	r4, r4, #0xff000000		; \
	orr	r4, r4, scratch2, lsl #9	; \
	mov	scratch2, scratch1, lsr #8	; \
	orr	r4, r4, scratch2, lsl #12	; \
	ands	scratch1, scratch1, #0xff	; \
	orr	r4, r4, scratch1		; \
	orreq	r4, r4, #0x8000			; \

#define SUB8(reg1, scratch1, scratch2) \
	/* compute half-carry */\
	and	scratch1, r4, #0xf	   	; \
	and	scratch2, reg1, #0xf		; \
	sub	scratch1, scratch1, scratch2	; \
	and	scratch2, scratch1, #0x10	; \
	/* actual subtract */\
	and	scratch1, r4, #0xff 		; \
	sub	scratch1, scratch1, reg1	; \
	and	r4, r4, #0xff000000		; \
	orr	r4, r4, scratch2, lsl #9	; \
	and	scratch2, scratch1, #0x100	; \
	orr	r4, r4, scratch2, lsl #4	; \
	ands	scratch1, scratch1, #0xff	; \
	orr	r4, r4, scratch1		; \
	orr	r4, r4, #0x4000			; \
	orreq	r4, r4, #0x8000			; \
	

#define CP8(reg1, scratch1, scratch2) \
	/* compute half-carry */\
	and 	scratch1, r4, #0xf 		; \
	and	scratch2, reg1, #0xf		; \
	sub	scratch1, scratch1, scratch2	; \
	and	scratch2, scratch1, #0x10	; \
	/* actual compare */\
	and	scratch1, r4, #0xff 		; \
	sub	scratch1, scratch1, reg1	; \
	bic	r4, r4, #0xff00			; \
	orr	r4, r4, scratch2, lsl #9	; \
	and	scratch2, scratch1, #0x100	; \
	orr	r4, r4, scratch2, lsl #4	; \
	ands	scratch1, scratch1, #0xff	; \
	orr	r4, r4, #0x4000			; \
	orreq	r4, r4, #0x8000			; \

	
#define SBC8(reg1, scratch1, scratch2) \
	/* compute half-carry */\
	and	scratch1, r4, #0xf	   	; \
	and	scratch2, reg1, #0xf		; \
	sub	scratch1, scratch1, scratch2	; \
	tst	r4, #0x1000			; \
	subne	scratch1, scratch1, #1		; \
	and	scratch2, scratch1, #0x10	; \
	/* actual subtraction */\
	and	scratch1, r4, #0xff 		; \
	sub	scratch1, scratch1, reg1	; \
	tst	r4, #0x1000			; \
	subne	scratch1, scratch1, #1		; \
	and	r4, r4, #0xff000000		; \
	orr	r4, r4, scratch2, lsl #9	; \
	and	scratch2, scratch1, #0x100	; \
	orr	r4, r4, scratch2, lsl #4	; \
	ands	scratch1, scratch1, #0xff	; \
	orr	r4, r4, scratch1		; \
	orr	r4, r4, #0x4000			; \
	orreq	r4, r4, #0x8000			; \
	

#define AND8(reg1, scratch1, scratch2) \
	and	scratch1, r4, reg1 ; \
	/* Clear flags and A, preserve R */\
	and	r4, r4, #0xff000000	; \
	/* Put result in A */\
	orr	r4, r4, scratch1	; \
	/* set the flags */\
	orr	r4, r4, #0x2000		      ; \
	tst	r4, #0xff		      ; \
	orreq	r4, r4, #0x8000		      ; \


#define OR8(reg1, scratch1, scratch2) \
	orr	scratch1, r4, reg1 ; \
	ands	scratch1, scratch1, #0xff ; \
	/* Clear flags and A, preserve R */\
	and	r4, r4, #0xff000000	; \
	/* Put result in A */\
	orr	r4, r4, scratch1	; \
	orreq	r4, r4, #0x8000		; \


#define XOR8(reg1, scratch1, scratch2) \
	eor	scratch1, r4, reg1 ; \
	ands	scratch1, scratch1, #0xff ; \
	/* Clear flags and A, preserve R */\
	and	r4, r4, #0xff000000	; \
	/* Put result in A */\
	orr	r4, r4, scratch1	; \
	orreq	r4, r4, #0x8000		; \


@ 16-bit arithmetic
#define INC16(reg) \
	add	reg, reg, #1 	; \
	bic	reg, reg, #65536 ; \
	
#define DEC16(reg) \
	sub	reg, reg, #1 	; \
	bic	reg, reg, #0xff000000 ; \
	bic	reg, reg, #0xff0000   ; \


#define ADD16(reg1, reg2, scratch1, scratch2) \
	/* compute half-carry */\
	bic	scratch1, reg1, #0xf000		; \
	bic	scratch2, reg2, #0xf000		; \
	add	scratch1, scratch1, scratch2	; \
	and	scratch2, scratch1, #0x1000	; \
	/* actual addition */\
	add	reg1, reg1, reg2 		; \
	bic	r4, r4, #0xff00			; \
	orr	r4, r4, scratch2, lsl #1	; \
	tst	reg1, #0x10000			; \
	orrne	r4, r4, #0x1000			; \
	bic	reg1, reg1, #0x10000		; \
	
		

	.text
	.code 32
	.align 2
	.global asmExecute

@============================================================
@
@ Main entry point into interpreter
@
@============================================================
	@ Register usage in here:
	@ r0 is the pointer to z80State (passed in as param)
	@    See gameboy.c for structure defn and field offsets
	@ r1 is used to hold instruction table pointer
	@ r2, r3, r8, r12 are scratch
	@ r4 is AF - d31-24 = int pending, d23-16 = unused, d15-8 = F, d7-0 = A
	@ r5 is BC
	@ r6 is DE
	@ r7 is HL
	@ r9 is PC
	@ r10 is tstate counter
	@ r11 is readPages pointer
	@
	@ The interpreter will run until the T-states counter goes
	@ above zero, at which point it will return.
	@ A pending interrupt is checked for and executed once at the
	@ beginning.
asmExecute:
	push	{r4-r11,lr}  		@ preserve registers

	@ load Z80 registers etc. into ARM registers
	ldrh	r4,[r0,#12]		@ AF
	ldrh	r5,[r0,#14]		@ BC
	ldrh	r6,[r0,#16]		@ DE
	ldrh	r7,[r0,#18]		@ HL
	ldrh	r9,[r0,#22]		@ PC
	ldr	r10,[r0]		@ tstate counter
	ldr	r11,[r0,#4]		@ readPages pointer
	ldrb	r3,[r0, #72]		@ int pending flag
	orr	r4, r4, r3, lsl #24	@ it goes in here

	ldr	r1,[r0,#40]		@ instruction table pointer

	@ test whether screen is enabled for this frame
	ldr	r12, [r0, #88]		@ ioRAM
	mov	r2, #255
	ldrb	r3, [r12, #0x40]
	tst	r3, #0x80
	moveq	r2, #0
	strb	r2, [r0, #76]
	bne	screen_is_not_disabled
	ldrb	r3, [r12, #0x41]
	bic	r3, r3, #3
	strb	r3, [r12, #0x41]
screen_is_not_disabled:	

	@ldr	r12, [r11, #16]		@ video RAM
	@add	r12, r12, #13
	@str	r12, [r0, #96]


	
check_interrupt:
	@ check for interrupt pending
	tst	r4, #0xff000000		@ test int pending flag
	bne	handle_interrupt

next_instruction:



@	ldr	r12, [r0, #88]
@	mov	r3, #0x5400
@	orr	r3, #0x0091
@	cmp	r3, r9
@	bne	skipweird
@	ldrh	r2, [r0, #94]
@	cmp	r2, #0
@	bne	skipweird
@	strh	r9, [r0, #94]
@	ldrb	r3, [r12, #0xc2]
@	strh	r3, [r0, #92]
@skipweird:	

@	ldrb	r3, [r0, #109]
@	cmp	r3, #0xf
@	bne	skipweird
@	mov	r3, #0x6200
@	orr	r3, r3, #0xd6
@	cmp	r3, r9
@	streqh	r9, [r0, #92]
@skipweird:	
	
	@ read a byte from PC into r3
	READ_BYTE(r3, r9, r3, r2)
	
	@ inc pc
	INC16(r9)

	@ lookup instruction in table and branch to it
	ldr	pc,[r1, r3, lsl #2]

handle_interrupt:
	@ test whether int that's pending is enabled!
	ldr	r12, [r0, #88]		@ ioRAM
	ldrb	r2, [r12, #0xf]		@ interrupt flag
	ldrb	r3, [r12, #0xff]	@ interrupt enable
	ands	r8, r2, r3
	beq	next_instruction	@ correct one not enabled

	@ handle Gameboy ints
	@ Gameboy CPU interrupts HALT even if interrupts are disabled
	@ check if CPU was on a halt or stop instruction, 'free' it if it was
	READ_BYTE(r3, r9, r3, r2)
	cmp	r3, #0x76
	addeq	r9, r9, #1
	cmp	r3, #0x10
	addeq	r9, r9, #1
	bic	r9, r9, #0x10000

	@ shouldn't generate video ints while display is enabled
	@tst	r8, #3
	@beq	int_skip_video_check
	@ldrb	r3, [r12, #0x40]
	@tst	r3, #0x80
	@bne	int_skip_video_check
	@ldrb	r3, [r12, #0xf]
	@bic	r3, r3, #3
	@strb	r3, [r12, #0xf]
	@b	next_instruction
int_skip_video_check:


	@ check whether global interrupts are enabled
	ldrb	r3,[r0, #38]		@ iff1
	cmp	r3, #0
	beq	next_instruction	@ disabled, skip

	@ disable them now
	mov	r2, #0
	strh	r2,[r0, #38]		@ iff1 & 2

	@ update interrupt flags, clear the one that's been initiated
	@ and update global int pending flag in r4 too
	@ r8 contains mask of ints that are pending and enabled
	@ r12 still points to ioram at this point

	@ get just highest priority one in r8
	tst	r8, #1
	movne	r8, #1
	tst	r8, #2
	movne	r8, #2
	tst	r8, #4
	movne	r8, #4
	tst	r8, #8
	movne	r8, #8
	tst	r8, #16
	movne	r8, #16
	
	ldrb	r2, [r12, #0xf]		@ interrupt flag
	ldrb	r3, [r12, #0xff]	@ interrupt enable
	bic	r2, r2, r8		@ clear the one being serviced
	strb	r2, [r12, #0xf]
	bic	r4, r4, #0xff000000
	tst	r2, r3
	orrne	r4, r4, #0xff000000	@ update global pending flag

	@ stack PC
	ldrh	r12, [r0, #20]		@ SP
	DEC16(r12)
	mov	r9, r9, ror #8
	WRITE_BYTE(r9, r12, r3, r2)
	DEC16(r12)
	mov	r9, r9, ror #24
	WRITE_BYTE(r9, r12, r3, r2)
	strh	r12, [r0, #20]		@ update SP

	@ set PC according to which int being handled
	mov	r9, #0x40
	tst	r8, #2
	movne	r9, #0x48
	tst	r8, #4
	movne	r9, #0x50
	tst	r8, #8
	movne	r9, #0x58
	tst	r8, #16
	movne	r9, #0x60
		
	b 	next_instruction

	
	.global	insn_table
insn_table:
	.word	insn00, insn01, insn02, insn03
	.word	insn04, insn05, insn06, insn07
	.word	insn08, insn09, insn0a, insn0b
	.word	insn0c, insn0d, insn0e, insn0f
	.word	insn10, insn11, insn12, insn13
	.word	insn14, insn15, insn16, insn17
	.word	insn18, insn19, insn1a, insn1b
	.word	insn1c, insn1d, insn1e, insn1f
	.word	insn20, insn21, insn22, insn23
	.word	insn24, insn25, insn26, insn27
	.word	insn28, insn29, insn2a, insn2b
	.word	insn2c, insn2d, insn2e, insn2f
	.word	insn30, insn31, insn32, insn33
	.word	insn34, insn35, insn36, insn37
	.word	insn38, insn39, insn3a, insn3b
	.word	insn3c, insn3d, insn3e, insn3f

	.word	insn40, insn41, insn42, insn43
	.word	insn44, insn45, insn46, insn47
	.word	insn48, insn49, insn4a, insn4b
	.word	insn4c, insn4d, insn4e, insn4f
	.word	insn50, insn51, insn52, insn53
	.word	insn54, insn55, insn56, insn57
	.word	insn58, insn59, insn5a, insn5b
	.word	insn5c, insn5d, insn5e, insn5f
	.word	insn60, insn61, insn62, insn63
	.word	insn64, insn65, insn66, insn67
	.word	insn68, insn69, insn6a, insn6b
	.word	insn6c, insn6d, insn6e, insn6f
	.word	insn70, insn71, insn72, insn73
	.word	insn74, insn75, insn76, insn77
	.word	insn78, insn79, insn7a, insn7b
	.word	insn7c, insn7d, insn7e, insn7f

	.word	insn80, insn81, insn82, insn83
	.word	insn84, insn85, insn86, insn87
	.word	insn88, insn89, insn8a, insn8b
	.word	insn8c, insn8d, insn8e, insn8f
	.word	insn90, insn91, insn92, insn93
	.word	insn94, insn95, insn96, insn97
	.word	insn98, insn99, insn9a, insn9b
	.word	insn9c, insn9d, insn9e, insn9f
	.word	insna0, insna1, insna2, insna3
	.word	insna4, insna5, insna6, insna7
	.word	insna8, insna9, insnaa, insnab
	.word	insnac, insnad, insnae, insnaf
	.word	insnb0, insnb1, insnb2, insnb3
	.word	insnb4, insnb5, insnb6, insnb7
	.word	insnb8, insnb9, insnba, insnbb
	.word	insnbc, insnbd, insnbe, insnbf

	.word	insnc0, insnc1, insnc2, insnc3
	.word	insnc4, insnc5, insnc6, insnc7
	.word	insnc8, insnc9, insnca, insncb
	.word	insncc, insncd, insnce, insncf
	.word	insnd0, insnd1, insnd2, insnd3
	.word	insnd4, insnd5, insnd6, insnd7
	.word	insnd8, insnd9, insnda, insndb
	.word	insndc, insndd, insnde, insndf
	.word	insne0, insne1, insne2, insne3
	.word	insne4, insne5, insne6, insne7
	.word	insne8, insne9, insnea, insneb
	.word	insnec, insned, insnee, insnef
	.word	insnf0, insnf1, insnf2, insnf3
	.word	insnf4, insnf5, insnf6, insnf7
	.word	insnf8, insnf9, insnfa, insnfb
	.word	insnfc, insnfd, insnfe, insnff

	@
	@ Gameboy display timing:
	@
	@ Per line:
	@   - 80 cycles in mode 2, accessing sprite RAM
	@   - 172 cycles in mode 3, accessing VRAM
	@   - 204 cycles in mode 0, horizontal blank
	@ 456 cycles total.
	@
	@ 4560 cycles (10 lines) in mode 1, vblank
	@
	@ 144 real lines (0-143) plus 10 lines vblank (144-153) = 154 lines altogether
	@ 70224 cycles per frame
	@
	@ ~60Hz
	@

done_execute:
	ldr	r12, [r0, #84]		@ screenState pointer

	@ free up r5, r6, r7 for video/sound code
	strh	r5, [r0, #14]
	strh	r6, [r0, #16]
	strh	r7, [r0, #18]

	ldrb	r3, [r0, #76]		@ screen enabled?
	cmp	r3, #0
	beq	skip_rendering		@ skip rendering if not

	@ check for leaving mode 2 - not actually an end-of-line
	ldrb	r3, [r12, #1]		@ vdpMode
	cmp	r3, #2
	beq	vdp_mode_2
	cmp	r3, #3
	beq	vdp_mode_3

	@ an actual end-of-line (mode 0 or 1) has occurred
	cmp	r3, #1
	beq	skip_rendering		@ don't render in vblank

	@ actually render a line here
	@ preserve r0, r4, r9, r10, r12!
#include "render.S"

skip_rendering:
	@ sound generation every line
	@ preserve r0, r4, r9, r10, r12!
#include "soundgen.S"

	@ reload r1 and r11
	ldr	r1, [r0, #40]
	ldr	r11, [r0, #4]

	ldr	r8, [r0, #88]		@ get ioRAM

	@ check serial latency
	ldrb	r2, [r0, #78]
	cmp	r2, #0
	beq	skip_serial
	subs	r2, r2, #1
	strb	r2, [r0, #78]
	bne	skip_serial
	@ fake serial int
	@orr	r4, r4, #0xff000000
	ldrb	r2, [r8, #0xf]
	@orr	r2, r2, #8
	strb	r2, [r8, #0xf]
	mov	r2, #0xff			@ fake received data
	strb	r2, [r8, #0x1]
	ldrb	r2, [r8, #0x2]
	@bic	r2, r2, #0x80
	strb	r2, [r8, #0x2]		@ clear serial transfer flag
skip_serial:	
	
	@ update the timer
	ldrb	r2, [r8, #7]
	tst	r2, #4
	beq	skip_timer_update
	ldr	r2, [r0, #64]		@ timer counter
	ldr	r3, [r0, #68]		@ timer increment
	adds	r2, r2, r3
	bcc	skip_timer_int

	ldrb	r2, [r8, #6]		@ reset the timer
	mov	r2, r2, lsl #24

	ldrb	r3, [r8, #0xf]		@ timer interrupt
	orr	r3, r3, #4
	strb	r3, [r8, #0xf]
	orr	r4, r4, #0xff000000
	
skip_timer_int:
	str	r2, [r0, #64]		@ store timer counter
	mov	r2, r2, lsr #24
	strb	r2, [r8, #5]		@ store value in register
skip_timer_update:	
	
	@ update divider register
	ldr	r2, [r0, #60]		@ internal counter is in 8.24
	mov	r3, #0xc50000		@ fixed point
	orr	r3, #0x1000000
	add	r2, r2, r3		@ increment it at ~16384Hz
	str	r2, [r0, #60]
	mov	r2, r2, lsr #24
	strb	r2, [r8, #0x4]		@ store whole part in register 4

	@ possible line interrupt if scanline co-incidence
	ldrb	r3, [r12, #0]		@ scanline

	ldrb	r2, [r0, #76]		@ screen enabled?
	cmp	r2, #0
	beq	screen_disabled
	
	ldrb	r2, [r8, #0x45]		@ scanline comparator
	cmp	r2, r3
	bne	skip_scanline_int
	ldrb	r2, [r8, #0x41]		@ LCD flags
	tst	r2, #64
	beq	skip_scanline_int

	@ldrb	r2, [r8, #0x40]		@ display enabled?
	@tst	r2, #0x80
	@beq	skip_scanline_int

	ldrb	r2, [r8, #0x41]
	orr	r2, r2, #4		@ set scanline coincidence flag
	strb	r2, [r8, #0x41]
	ldrb	r2, [r8, #0xf]		@ interrupt flags
	orr	r2, r2, #2		@ LCD interrupt
	strb	r2, [r8, #0xf]
	orr	r4, r4, #0xff000000	@ set pending int
skip_scanline_int:

	@ advance line counter, set new mode
	add	r3, r3, #1
	strb	r3, [r12, #0]		@ store scanline in our counter
	strb	r3, [r8, #0x44]		@ and in register 44
	cmp	r3, #144
	beq	start_vblank		@ finished last actual display line
	cmp	r3, #154
	beq	done_frame		@ finished whole frame

	ldrb	r3, [r12, #1]		@ VDP mode
	cmp	r3, #1
	beq	in_vblank

	@ start new real line (mode 2)
	sub	r10, r10, #80
	mov	r3, #2
	strb	r3, [r12, #1]
	ldrb	r2, [r8, #0x41]		@ get reg 0x41
	bic	r2, r2, #3
	orr	r2, r2, #2
	strb	r2, [r8, #0x41]		@ store vdpMode in there

	@ possible interrupt for entering mode 2
	tst	r2, #32
	beq	skip_mode2_int

	@ldrb	r3, [r8, #0x40]
	@tst	r3, #0x80		@ display enabled?
	@beq	skip_mode2_int
	
	ldrb	r2, [r8, #0x0f]
	orr	r2, r2, #2
	strb	r2, [r8, #0x0f]
	orr	r4, r4, #0xff000000
skip_mode2_int:	

	@ restore BC, DE, HL
	ldrh	r5, [r0, #14]
	ldrh	r6, [r0, #16]
	ldrh	r7, [r0, #18]
	b	check_interrupt
	
done_frame:
	@ setup scanline and VDP mode ready for next frame
	mov	r3, #0
	strb	r3, [r12, #0]		@ zero scanline
	strb	r3, [r8, #0x44]		@ and in register 44
	
	sub	r10, r10, #80
	mov	r3, #2
	strb	r3, [r12, #1]
	ldrb	r2, [r8, #0x41]		@ get reg 0x41
	bic	r2, r2, #3
	orr	r2, r2, #2
	strb	r2, [r8, #0x41]		@ store vdpMode in there

	@ possible interrupt for entering mode 2
	tst	r2, #32
	beq	skip_mode2_int2

	@ldrb	r3, [r8, #0x40]
	@tst	r3, #0x80		@ display enabled?
	@beq	skip_mode2_int2
	
	ldrb	r2, [r8, #0x0f]
	orr	r2, r2, #2
	strb	r2, [r8, #0x0f]
	orr	r4, r4, #0xff000000
skip_mode2_int2:
	
	@ store Z80 registers back into state struct
	strh	r4,[r0,#12]		@ AF
@	strh	r5,[r0,#14]		@ BC
@	strh	r6,[r0,#16]		@ DE
@	strh	r7,[r0,#18]		@ HL
	strh	r9,[r0,#22]		@ PC
	str	r10,[r0]		@ tstate counter

	mov	r4, r4, lsr #24
	strb	r4, [r0, #72]		@ int pending flag
	
	pop	{r4-r11,lr}		@ restore caller's registers
	mov	r0,#9
	bx	lr

	
	@ reached end of line in vblank
in_vblank:
	sub	r10, r10, #456

	@ restore BC, DE, HL
	ldrh	r5, [r0, #14]
	ldrh	r6, [r0, #16]
	ldrh	r7, [r0, #18]
	b	check_interrupt
	

	@ VDP mode 2 done. Go into mode 3 now
vdp_mode_2:
	sub	r10, r10, #172
	mov	r3, #3
	strb	r3, [r12, #1]		@ store vdpMode in screenState
	ldr	r8, [r0, #88]		@ get ioRAM
	ldrb	r2, [r8, #0x41]		@ get reg 0x41
	@bic	r2, r2, #3
	orr	r2, r2, #3
	strb	r2, [r8, #0x41]		@ store vdpMode in there
	b	check_interrupt

	@ VDP mode 3 done. Go into mode 0 now
vdp_mode_3:
	sub	r10, r10, #204
	mov	r3, #0
	strb	r3, [r12, #1]		@ store in screenState
	ldr	r8, [r0, #88]		@ get ioRAM
	ldrb	r2, [r8, #0x41]	 	@ get reg 0x41
	bic	r2, r2, #3
	strb	r2, [r8, #0x41]		@ store vdpMode in there

	@ possible interrupt for entering mode 0
	tst	r2, #8
	beq	check_interrupt

	@ldrb	r3, [r8, #0x40]
	@tst	r3, #0x80		@ display enabled?
	@beq	check_interrupt
	
	ldrb	r2, [r8, #0x0f]
	orr	r2, r2, #2
	strb	r2, [r8, #0x0f]
	orr	r4, r4, #0xff000000
	
	b	check_interrupt

	@ VDP just went into vblank mode (1)
start_vblank:
	strb	r3, [r12, #0]		@ store next display line
	sub	r10, r10, #456
	mov	r3, #1
	strb	r3, [r12, #1]		@ store new VDP mode
	ldrb	r2, [r8, #0x41]		@ get reg 0x41
	bic	r2, r2, #3
	orr	r2, r2, #1
	strb	r2, [r8, #0x41]		@ store vdpMode in there

	@ restore BC, DE, HL
	ldrh	r5, [r0, #14]
	ldrh	r6, [r0, #16]
	ldrh	r7, [r0, #18]

	@ldrb	r3, [r8, #0x40]
	@tst	r3, #0x80		@ display enabled?
	@beq	check_interrupt
	
	@ trigger vblank int
	tst	r2, #16
	beq	skip_vblank_int
	ldrb	r2, [r8, #0x0f]		@ interrupt flags
	orr	r2, r2, #2
	strb	r2, [r8, #0x0f]
skip_vblank_int:

	@ldrb	r2, [r0, #94]
	@subs	r2, r2, #1
	@strb	r2, [r0, #94]
	@bne	check_interrupt
	@mov	r2, #1
	@strb	r2, [r0, #94]
	
	ldrb	r2, [r8, #0x0f]		@ interrupt flags
	orr	r2, r2, #1
	strb	r2, [r8, #0x0f]
	orr	r4, r4, #0xff000000	@ int pending
	
	b	check_interrupt

	
	@ need to update scanline and r10 and restart
screen_disabled:	
	@ advance line counter, set new mode
	add	r3, r3, #1
	strb	r3, [r12, #0]		@ store scanline in our counter
	@ FIXME: should it go in reg 44 here or not??
	strb	r3, [r8, #0x44]		@ and in register 44
	cmp	r3, #154
	beq	screen_disabled_done_frame		@ finished whole frame
	sub	r10, r10, #456

	@ restore BC, DE, HL
	ldrh	r5, [r0, #14]
	ldrh	r6, [r0, #16]
	ldrh	r7, [r0, #18]
	b	check_interrupt

	
screen_disabled_done_frame:	
	@ setup scanline and VDP mode ready for next frame
	mov	r3, #0
	strb	r3, [r12, #0]		@ zero scanline
	strb	r3, [r8, #0x44]		@ and in register 44
	
	sub	r10, r10, #80
	mov	r3, #2
	strb	r3, [r12, #1]
	ldrb	r2, [r8, #0x41]		@ get reg 0x41
	bic	r2, r2, #3
	orr	r2, r2, #2
	strb	r2, [r8, #0x41]		@ store vdpMode in there

	@ store Z80 registers back into state struct
	strh	r4,[r0,#12]		@ AF
@	strh	r5,[r0,#14]		@ BC
@	strh	r6,[r0,#16]		@ DE
@	strh	r7,[r0,#18]		@ HL
	strh	r9,[r0,#22]		@ PC
	str	r10,[r0]		@ tstate counter

	mov	r4, r4, lsr #24
	strb	r4, [r0, #72]		@ int pending flag
	
	pop	{r4-r11,lr}		@ restore caller's registers
	mov	r0,#9
	bx	lr

	
@============================================================
@
@ Instruction implementations
@
@============================================================
@ nop
insn00: END_INSN(#4)

@ ld bc,NN
insn01:
	@ fetch C
	@ read a byte from PC into C
	READ_BYTE(r5, r9, r3, r2)

	@ inc pc
	INC16(r9)

	@ fetch B into r3
	READ_BYTE(r3, r9, r3, r2)

	@ inc pc
	INC16(r9)

	@ combine B onto BC
	orr	r5, r5, r3, lsl #8

	END_INSN(#10)

	
@ ld (bc),a
insn02: WRITE_BYTE(r4, r5, r3, r2)
	END_INSN(#7)

	
@ inc bc
insn03:	INC16(r5)
	END_INSN(#6)

@ inc b
insn04: INC8_HI(r5, r2)
	END_INSN(#4)
	
@ dec b	
insn05: DEC8_HI(r5, r2)
	END_INSN(#4)

@ ld b, N
insn06: READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	and	r5, r5, #0xff
	orr	r5, r5, r3, lsl #8
	END_INSN(#7)

@ rlca	
insn07:	mov	r3, r4, lsr #7
	mov	r2, r4, lsl #1
	and	r3, r3, #1
	and	r2, r2, #0xfe
	bic	r4, r4, #0xff
	bic	r4, r4, #0xff00
	orr	r4, r4, r3
	orr	r4, r4, r2
	orr	r4, r4, r3, lsl #12
	END_INSN(#4)

#ifndef GAMEBOY
@ ex af, af'
insn08: ldrh	r3,[r0, #28]    @ read af'
	strh	r4,[r0, #28]	@ store current AF in there
	and	r2, r4, #0xff000000  @ preserve R
	orr	r4, r3, r2
	END_INSN(#4)
#else
@ ld (NN),sp
insn08:	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	orr	r12, r12, r3, lsl #8
	ldrh	r8, [r0, #20]		@ read SP
	WRITE_BYTE(r8, r12, r3, r2)
	INC16(r12)
	mov	r8, r8, lsr #8
	WRITE_BYTE(r8, r12, r3, r2)
	END_INSN(#16)
#endif

@ add hl, bc
insn09: ADD16(r7, r5, r3, r2)
	END_INSN(#11)
	
@ ld a,(bc)
insn0a: READ_BYTE(r3, r5, r3, r2)
	bic	r4, r4, #0xff
	orr	r4, r4, r3
	END_INSN(#7)

@ dec bc
insn0b: DEC16(r5)
	END_INSN(#6)

@ inc c
insn0c: INC8_LO(r5, r2)
	END_INSN(#4)

@ dec c	
insn0d: DEC8_LO(r5, r2)
	END_INSN(#4)

@ ld c,N
insn0e:	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	and	r5, r5, #0xff00
	orr	r5, r5, r3
	END_INSN(#7)

@ rrca
insn0f: and	r3, r4, #0xff
	mov	r2, r3, lsr #1
	mov	r3, r3, lsl #7
	and	r3, r3, #0x80
	bic	r4, r4, #0xff
	bic	r4, r4, #0xff00
	orr	r4, r4, r2
	orr	r4, r4, r3
	orr	r4, r4, r3, lsl #5
	END_INSN(#4)

#ifndef GAMEBOY
@ djnz DIS
insn10: READ_SIGNED_BYTE(r3, r9, r3, r2)
	INC16(r9)
	sub	r5, r5, #0x100
	bic	r5, r5, #0xff0000
	bic	r5, r5, #0xff000000
	tst	r5, #0xff00
	addne	r9, r9, r3
	addne	r10, r10, #5  @ extra cycles if branch taken
	bic	r9, #0xff0000
	bic	r9, #0xff000000
	END_INSN(#8)
#else
@ stop - treat it same as HALT
insn10:	DEC16(r9)			@ point at HALT again
	mov	r10, #0			@ use up time
	b	done_execute
#endif

@ ld de, NN
insn11:
	@ fetch E
	@ read a byte from PC into E
	READ_BYTE(r6, r9, r3, r2)

	@ inc pc
	INC16(r9)

	@ fetch D into r3
	READ_BYTE(r3, r9, r3, r2)

	@ inc pc
	INC16(r9)

	@ combine D onto DE
	orr	r6, r6, r3, lsl #8

	END_INSN(#10)

@ ld (de),a
insn12:	WRITE_BYTE(r4, r6, r3, r2)
	END_INSN(#7)

@ inc de
insn13: INC16(r6)
	END_INSN(#6)

@ inc d
insn14: INC8_HI(r6, r2)
	END_INSN(#4)

@ dec d
insn15: DEC8_HI(r6, r2)
	END_INSN(#4)

@ ld d,N
insn16: READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	and	r6, r6, #0xff
	orr	r6, r6, r3, lsl #8
	END_INSN(#7)

@ rla
insn17: and	r2, r4, #0x1000 	@ old carry
	and	r3, r4, #0x80		@ new carry
	and	r12, r4, #0x7f		@ other bits
	bic	r4, #0xff
	bic	r4, #0xff00
	orr	r4, r4, r12, lsl #1
	orr	r4, r4, r2, lsr #12
	orr	r4, r4, r3, lsl #5
	END_INSN(#4)
	
@ jr DIS
insn18: READ_SIGNED_BYTE(r3, r9, r3, r2)
	INC16(r9)
	add	r9, r9, r3
	bic	r9, #0xff0000
	bic	r9, #0xff000000
	END_INSN(#12)

@ add hl,de
insn19: ADD16(r7, r6, r3, r2)
	END_INSN(#11)

@ ld a,(de)
insn1a:	READ_BYTE(r3, r6, r3, r2)
	bic	r4, r4, #0xff
	orr	r4, r4, r3
	END_INSN(#7)

@ dec de
insn1b: DEC16(r6)
	END_INSN(#6)

@ inc e
insn1c: INC8_LO(r6, r2)
	END_INSN(#4)

@ dec e
insn1d:	DEC8_LO(r6, r2)
	END_INSN(#4)

@ ld e,N
insn1e: READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	and	r6, r6, #0xff00
	orr	r6, r6, r3
	END_INSN(#7)

@ rra
insn1f:	and	r2, r4, #0x1000		@ old carry
	and	r3, r4, #0x1		@ new carry
	and	r12, r4, #0xfe		@ other bits
	bic	r4, r4, #0xff
	bic	r4, r4, #0xff00
	orr	r4, r4, r12, lsr #1
	orr	r4, r4, r2, lsr #5
	orr	r4, r4, r3, lsl #12
	END_INSN(#4)

@ jr nz,DIS
insn20: READ_SIGNED_BYTE(r3, r9, r3, r2)
	INC16(r9)
	tst	r4, #0x8000
	addeq	r9, r9, r3
	addeq	r10, r10, #5
	bic	r9, #0xff0000
	bic	r9, #0xff000000
	END_INSN(#7)


@ ld hl,NN
insn21:
	@ fetch L
	@ read a byte from PC into L
	READ_BYTE(r7, r9, r3, r2)

	@ inc pc
	INC16(r9)

	@ fetch H into r3
	READ_BYTE(r3, r9, r3, r2)

	@ inc pc
	INC16(r9)

	@ combine H onto HL
	orr	r7, r7, r3, lsl #8

	END_INSN(#10)

#ifndef GAMEBOY
@ ld (NN),hl
insn22:	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	orr	r12, r12, r3, lsl #8
	WRITE_BYTE(r7, r12, r3, r2)
	INC16(r12)
	mov	r7, r7, ror #8
	WRITE_BYTE(r7, r12, r3, r2)
	mov	r7, r7, ror #24
	END_INSN(#16)
#else
@ ld (hli),a
insn22:	WRITE_BYTE(r4, r7, r3, r2)
	INC16(r7)
	END_INSN(#8)
#endif

@ inc hl
insn23:	INC16(r7)
	END_INSN(#6)

@ inc h
insn24:	INC8_HI(r7, r2)
	END_INSN(#4)

@ dec h
insn25:	DEC8_HI(r7, r2)
	END_INSN(#4)

@ ld h,N
insn26:	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	and	r7, r7, #0xff
	orr	r7, r7, r3, lsl #8
	END_INSN(#7)

@ daa
insn27: @ work out correction factor in r12
	mov	r12, #0
	@ work out upper 4 bits
	tst	r4, #0x1000		@ test carry
	orrne	r12, r12, #0x60
	and	r3, r4, #0xff		@ get just A
	cmp	r3, #0x99
	orrgt	r12, r12, #0x60
	orrgt	r4, r4, #0x1000		@ set carry
	@ now work out lower 4 bits
	tst	r4, #0x2000		@ test half carry
	orrne	r12, r12, #0x06
	and	r3, r4, #0x0f
	cmp	r3, #0x09
	orrgt	r12, r12, #0x06
	@ work out whether to add or subtract
	and	r3, r4, #0xff		@ get just A
	tst	r4, #0x4000		@ test N flag
	subne	r3, r3, r12
	addeq	r3, r3, r12
	and	r3, r3, #0xff
	@ work out half-carry flag - bit 4 of r2
	eor	r2, r3, r4
	@ carry and N are already set
	bic	r4, r4, #0xc000
	bic	r4, r4, #0xff
	@ put result in A
	orr	r4, r4, r3
	@ put half-carry flag in
	and	r2, r2, #0x10
	orr	r4, r4, r2, lsl #9
	@ set Z
	tst	r4, #0xff
	orreq	r4, r4, #0x8000
	END_INSN(#4)

@ jr z,DIS
insn28: READ_SIGNED_BYTE(r3, r9, r3, r2)
	INC16(r9)
	tst	r4, #0x8000
	addne	r9, r9, r3
	addne	r10, r10, #5
	bic	r9, #0xff0000
	bic	r9, #0xff000000
	END_INSN(#7)


@ add hl,hl
insn29:	ADD16(r7, r7, r3, r2)
	END_INSN(#11)

#ifndef GAMEBOY
@ ld hl,(NN)
insn2a: READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	orr	r12, r12, r3, lsl #8
	READ_BYTE(r7, r12, r3, r2)
	INC16(r12)
	READ_BYTE(r3, r12, r3, r2)
	orr	r7, r7, r3, lsl #8
	END_INSN(#16)
#else
@ ld a,(hli)
insn2a:	READ_BYTE(r12, r7, r3, r2)
	INC16(r7)
	bic	r4, r4, #0xff
	orr	r4, r4, r12
	END_INSN(#8)
#endif

@ dec hl
insn2b:	DEC16(r7)
	END_INSN(#6)

@ inc l
insn2c:	INC8_LO(r7, r2)
	END_INSN(#4)

@ dec l
insn2d:	DEC8_LO(r7, r2)
	END_INSN(#4)

@ ld l,N
insn2e:	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	and	r7, r7, #0xff00
	orr	r7, r7, r3
	END_INSN(#7)

@ cpl
insn2f:	eor	r4, r4, #0xff
	orr	r4, r4, #0x6000
	END_INSN(#4)

@ jr nc,DIS
insn30: READ_SIGNED_BYTE(r3, r9, r3, r2)
	INC16(r9)
	tst	r4, #0x1000
	addeq	r9, r9, r3
	addeq	r10, r10, #5
	bic	r9, #0xff0000
	bic	r9, #0xff000000
	END_INSN(#7)

@ ld sp,NN
insn31: READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	orr	r12, r12, r3, lsl #8
	strh	r12,[r0,#20]
	END_INSN(#10)

#ifndef GAMEBOY
@ ld (NN),a
insn32: READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	orr	r12, r12, r3, lsl #8
	WRITE_BYTE(r4, r12, r3, r2)
	END_INSN(#13)
#else
@ ld (hld),a
insn32:	WRITE_BYTE(r4, r7, r3, r2)
	DEC16(r7)
	END_INSN(#8)
#endif

@ inc sp
insn33: ldrh	r12,[r0,#20]
	INC16(r12)
	strh	r12,[r0,#20]
	END_INSN(#6)

@ inc (hl)
insn34:	READ_BYTE(r12, r7, r3, r2)
	INC8_LO(r12, r2)
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#11)

@ dec(hl)
insn35: READ_BYTE(r12, r7, r3, r2)
	DEC8_LO(r12, r2)
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#11)

@ ld (hl),N
insn36:	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#10)

@ scf
insn37: orr	r4, r4, #0x1000
	bic	r4, r4, #0x6000
	END_INSN(#4)

@ jr c,DIS
insn38: READ_SIGNED_BYTE(r3, r9, r3, r2)
	INC16(r9)
	tst	r4, #0x1000
	addne	r9, r9, r3
	addne	r10, r10, #5
	bic	r9, #0xff0000
	bic	r9, #0xff000000
	END_INSN(#7)

@ add hl,sp
insn39: ldrh	r12,[r0, #20]
	ADD16(r7, r12, r3, r2)
	END_INSN(#11)

#ifndef GAMEBOY
@ ld a,(NN)
insn3a:	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	orr	r12, r12, r3, lsl #8
	READ_BYTE(r3, r12, r3, r2)
	bic	r4, r4, #0xff
	orr	r4, r4, r3
	END_INSN(#13)
#else
@ ld a,(hld)
insn3a:	READ_BYTE(r12, r7, r3, r2)
	DEC16(r7)
	bic	r4, r4, #0xff
	orr	r4, r4, r12
	END_INSN(#8)
#endif

@ dec sp
insn3b: ldrh	r12,[r0, #20]
	DEC16(r12)
	strh	r12,[r0, #20]
	END_INSN(#6)

@ inc a
insn3c: INC8_LO(r4, r2)
	END_INSN(#4)
	
@ dec a
insn3d:	DEC8_LO(r4, r2)
	END_INSN(#4)

@ ld a,N
insn3e:	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	bic	r4, r4, #0xff
	orr	r4, r4, r3
	END_INSN(#7)

@ ccf
insn3f: bic	r4, r4, #0x6000
	eor	r4, r4, #0x1000
	END_INSN(#4)


@
@ LD group
@
insn40: END_INSN(#4) @ ld b,b
insn41: and	r5, r5, #0xff
	orr	r5, r5, r5, lsl #8  @ ld b,c
	END_INSN(#4)
insn42: and	r5, r5, #0xff
	and	r3, r6, #0xff00
	orr	r5, r5, r3          @ ld b,d
	END_INSN(#4)
insn43: and	r5, r5, #0xff
	and	r3, r6, #0xff
	orr	r5, r5, r3, lsl #8  @ ld b,e
	END_INSN(#4)
insn44: and	r5, r5, #0xff
	and	r3, r7, #0xff00
	orr	r5, r5, r3	@ ld b,h
	END_INSN(#4)
insn45: and	r5, r5, #0xff
	and	r3, r7, #0xff
	orr	r5, r5, r3, lsl #8 @ ld b,l
	END_INSN(#4)
insn46: READ_BYTE(r3, r7, r3, r2)
	and	r5, r5, #0xff
	orr	r5, r5, r3, lsl #8 @ ld b,(hl)
	END_INSN(#7)
insn47: and	r5, r5, #0xff
	and	r3, r4, #0xff
	orr	r5, r5, r3, lsl #8 @ ld b,a
	END_INSN(#4)
	
insn48: and	r5, r5, #0xff00
	orr	r5, r5, r5, lsr #8  @ ld c,b
	END_INSN(#4)
insn49: END_INSN(#4)     @ ld c,c
insn4a: and	r5, r5, #0xff00
	orr	r5, r5, r6, lsr #8  @ ld c,d
	END_INSN(#4)
insn4b: and	r3, r6, #0xff
	and	r5, r5, #0xff00
	orr	r5, r5, r3          @ ld c,e
	END_INSN(#4)
insn4c: and	r5, r5, #0xff00
	orr	r5, r5, r7, lsr #8  @ ld c,h
	END_INSN(#4)
insn4d: and	r5, r5, #0xff00
	and	r3, r7, #0xff
	orr	r5, r5, r3	@ ld c,l
	END_INSN(#4)
insn4e: and	r5, r5, #0xff00
	READ_BYTE(r3, r7, r3, r2)
	orr	r5, r5, r3	@ ld c,(hl)
	END_INSN(#7)
insn4f: and	r5, r5, #0xff00
	and	r3, r4, #0xff
	orr	r5, r5, r3	@ ld c,a
	END_INSN(#4)

insn50: and	r6, r6, #0xff
	and	r3, r5, #0xff00
	orr	r6, r6, r3	@ ld d,b
	END_INSN(#4)
insn51: and	r6, r6, #0xff
	and	r3, r5, #0xff
	orr	r6, r6, r3, lsl #8 @ ld d,c
insn52: END_INSN(#4)		@ ld d,d
insn53: and	r6, r6, #0xff
	orr	r6, r6, r6, lsl #8 @ ld d,e
	END_INSN(#4)
insn54: and	r6, r6, #0xff
	and	r3, r7, #0xff00
	orr	r6, r6, r3	@ ld d,h
	END_INSN(#4)
insn55: and	r6, r6, #0xff
	and	r3, r7, #0xff
	orr	r6, r6, r3, lsl #8 @ ld d,l
	END_INSN(#4)
insn56: READ_BYTE(r3, r7, r3, r2)
	and	r6, r6, #0xff
	orr	r6, r6, r3, lsl #8 @ ld d,(hl)
	END_INSN(#7)
insn57: and	r6, r6, #0xff
	and	r3, r4, #0xff
	orr	r6, r6, r3, lsl #8 @ ld d,a
	END_INSN(#4)

insn58: and	r6, r6, #0xff00
	orr	r6, r6, r5, lsr #8 	@ ld e,b
	END_INSN(#4)
insn59: and	r6, r6, #0xff00
	and	r3, r5, #0xff
	orr	r6, r6, r3		@ ld e,c
	END_INSN(#4)
insn5a: and	r6, r6, #0xff00
	orr	r6, r6, r6, lsr #8	@ ld e,d
	END_INSN(#4)
insn5b: END_INSN(#4)			@ ld e,e
insn5c: and	r6, r6, #0xff00
	orr	r6, r6, r7, lsr #8	@ ld e,h
	END_INSN(#4)
insn5d: and	r6, r6, #0xff00
	and	r3, r7, #0xff
	orr	r6, r6, r3		@ ld e,l
	END_INSN(#4)
insn5e: and	r6, r6, #0xff00
	READ_BYTE(r3, r7, r3, r2)
	orr	r6, r6, r3		@ ld e,(hl)
	END_INSN(#7)
insn5f: and	r6, r6, #0xff00
	and	r3, r4, #0xff
	orr	r6, r6, r3		@ ld e,a
	END_INSN(#4)

insn60: and	r7, r7, #0xff
	and	r3, r5, #0xff00
	orr	r7, r7, r3		@ ld h,b
	END_INSN(#4)
insn61: and	r7, r7, #0xff
	and	r3, r5, #0xff
	orr	r7, r7, r3, lsl #8	@ ld h,c
	END_INSN(#4)
insn62:	and	r7, r7, #0xff
	and	r3, r6, #0xff00
	orr	r7, r7, r3		@ ld h,d
	END_INSN(#4)
insn63: and	r7, r7, #0xff
	and	r3, r6, #0xff
	orr	r7, r7, r3, lsl #8	@ ld h,e
	END_INSN(#4)
insn64: END_INSN(#4)			@ ld h,h
insn65: and	r7, r7, #0xff
	orr	r7, r7, r7, lsl #8	@ ld h,l
	END_INSN(#4)
insn66: READ_BYTE(r3, r7, r3, r2)
	and	r7, r7, #0xff
	orr	r7, r7, r3, lsl #8	@ ld h,(hl)
	END_INSN(#7)
insn67:	and	r7, r7, #0xff
	and	r3, r4, #0xff
	orr	r7, r7, r3, lsl #8	@ ld h,a
	END_INSN(#4)

insn68:	and	r7, r7, #0xff00
	orr	r7, r7, r5, lsr #8	@ ld l,b
	END_INSN(#4)
insn69:	and	r7, r7, #0xff00
	and	r3, r5, #0xff
	orr	r7, r7, r3		@ ld l,c
	END_INSN(#4)
insn6a: and	r7, r7, #0xff00
	orr	r7, r7, r6, lsr #8	@ ld l,d
	END_INSN(#4)
insn6b: and	r7, r7, #0xff00
	and	r3, r6, #0xff
	orr	r7, r7, r3		@ ld l,e
	END_INSN(#4)
insn6c:	and	r7, r7, #0xff00
	orr	r7, r7, r7, lsr #8	@ ld l,h
	END_INSN(#4)
insn6d: END_INSN(#4)			@ ld l,l
insn6e: READ_BYTE(r3, r7, r3, r2)
	and	r7, r7, #0xff00
	orr	r7, r7, r3		@ ld l,(hl)
	END_INSN(#7)
insn6f:	and	r7, r7, #0xff00
	and	r3, r4, #0xff
	orr	r7, r7, r3		@ ld l,a
	END_INSN(#4)

insn70:	mov	r12, r5, lsr #8
	WRITE_BYTE(r12, r7, r3, r2)	@ ld (hl),b
	END_INSN(#7)
insn71:	WRITE_BYTE(r5, r7, r3, r2)	@ ld (hl),c
	END_INSN(#7)
insn72:	mov	r12, r6, lsr #8
	WRITE_BYTE(r12, r7, r3, r2)	@ ld (hl),d
	END_INSN(#7)
insn73:	WRITE_BYTE(r6, r7, r3, r2)	@ ld (hl),e
	END_INSN(#7)
insn74:	mov	r12, r7, lsr #8		@ ld (hl),h
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#7)
insn75:	WRITE_BYTE(r7, r7, r3, r2)	@ ld (hl),l
	END_INSN(#7)
insn76: @ HALT
	DEC16(r9)			@ point at HALT again
	mov	r10, #0			@ use up time
	b	done_execute
insn77:	WRITE_BYTE(r4, r7, r3, r2)	@ ld (hl),a
	END_INSN(#7)

insn78:	bic	r4, r4, #0xff
	orr	r4, r4, r5, lsr #8	@ ld a,b
	END_INSN(#4)
insn79:	bic	r4, r4, #0xff
	and	r3, r5, #0xff
	orr	r4, r4, r3		@ ld a,c
	END_INSN(#4)
insn7a:	bic	r4, r4, #0xff
	orr	r4, r4, r6, lsr #8	@ ld a,d
	END_INSN(#4)
insn7b:	bic	r4, r4, #0xff
	and	r3, r6, #0xff
	orr	r4, r4, r3		@ ld a,e
	END_INSN(#4)
insn7c:	bic	r4, r4, #0xff
	orr	r4, r4, r7, lsr #8	@ ld a,h
	END_INSN(#4)
insn7d:	bic	r4, r4, #0xff
	and	r3, r7, #0xff
	orr	r4, r4, r3		@ ld a,l
	END_INSN(#4)
insn7e:	READ_BYTE(r3, r7, r3, r2)
	bic	r4, r4, #0xff
	orr	r4, r4, r3		@ ld a,(hl)
	END_INSN(#7)
insn7f:	END_INSN(#4)			@ ld a,a

@
@ Arithmetic group
@
insn80:	mov	r12, r5, lsr #8		@ add a,b
	ADD8(r12, r2, r3)
	END_INSN(#4)
insn81: and	r12, r5, #0xff		@ add a,c
	ADD8(r12, r2, r3)
	END_INSN(#4)
insn82:	mov	r12, r6, lsr #8		@ add a,d
	ADD8(r12, r2, r3)
	END_INSN(#4)
insn83:	and	r12, r6, #0xff		@ add a,e
	ADD8(r12, r2, r3)
	END_INSN(#4)
insn84: mov	r12, r7, lsr #8		@ add a,h
	ADD8(r12, r2, r3)
	END_INSN(#4)
insn85:	and	r12, r7, #0xff		@ add a,l
	ADD8(r12, r2, r3)
	END_INSN(#4)
insn86:	READ_BYTE(r12, r7, r3, r2)	@ add a,(hl)
	ADD8(r12, r2, r3)
	END_INSN(#7)
insn87:	and	r12, r4, #0xff		@ add a,a
	ADD8(r12, r2, r3)
	END_INSN(#4)
	
insn88:	mov	r12, r5, lsr #8		@ adc a,b
	ADC8(r12, r2, r3)
	END_INSN(#4)
insn89: and	r12, r5, #0xff		@ adc a,c
	ADC8(r12, r2, r3)
	END_INSN(#4)
insn8a:	mov	r12, r6, lsr #8		@ adc a,d
	ADC8(r12, r2, r3)
	END_INSN(#4)
insn8b:	and	r12, r6, #0xff		@ adc a,e
	ADC8(r12, r2, r3)
	END_INSN(#4)
insn8c: mov	r12, r7, lsr #8		@ adc a,h
	ADC8(r12, r2, r3)
	END_INSN(#4)
insn8d:	and	r12, r7, #0xff		@ adc a,l
	ADC8(r12, r2, r3)
	END_INSN(#4)
insn8e:	READ_BYTE(r12, r7, r3, r2)	@ adc a,(hl)
	ADC8(r12, r2, r3)
	END_INSN(#7)
insn8f:	and	r12, r4, #0xff		@ adc a,a
	ADC8(r12, r2, r3)
	END_INSN(#4)


insn90:	mov	r12, r5, lsr #8		@ sub b
	SUB8(r12, r2, r3)
	END_INSN(#4)
insn91: and	r12, r5, #0xff		@ sub c
	SUB8(r12, r2, r3)
	END_INSN(#4)
insn92:	mov	r12, r6, lsr #8		@ sub d
	SUB8(r12, r2, r3)
	END_INSN(#4)
insn93:	and	r12, r6, #0xff		@ sub e
	SUB8(r12, r2, r3)
	END_INSN(#4)
insn94: mov	r12, r7, lsr #8		@ sub h
	SUB8(r12, r2, r3)
	END_INSN(#4)
insn95:	and	r12, r7, #0xff		@ sub l
	SUB8(r12, r2, r3)
	END_INSN(#4)
insn96:	READ_BYTE(r12, r7, r3, r2)	@ sub (hl)
	SUB8(r12, r2, r3)
	END_INSN(#7)
insn97:	and	r12, r4, #0xff		@ sub a
	SUB8(r12, r2, r3)
	END_INSN(#4)
	
insn98:	mov	r12, r5, lsr #8		@ sbc a,b
	SBC8(r12, r2, r3)
	END_INSN(#4)
insn99: and	r12, r5, #0xff		@ sbc a,c
	SBC8(r12, r2, r3)
	END_INSN(#4)
insn9a:	mov	r12, r6, lsr #8		@ sbc a,d
	SBC8(r12, r2, r3)
	END_INSN(#4)
insn9b:	and	r12, r6, #0xff		@ sbc a,e
	SBC8(r12, r2, r3)
	END_INSN(#4)
insn9c: mov	r12, r7, lsr #8		@ sbc a,h
	SBC8(r12, r2, r3)
	END_INSN(#4)
insn9d:	and	r12, r7, #0xff		@ sbc a,l
	SBC8(r12, r2, r3)
	END_INSN(#4)
insn9e:	READ_BYTE(r12, r7, r3, r2)	@ sbc a,(hl)
	SBC8(r12, r2, r3)
	END_INSN(#7)
insn9f:	and	r12, r4, #0xff		@ sbc a,a
	SBC8(r12, r2, r3)
	END_INSN(#4)


insna0:	mov	r12, r5, lsr #8		@ and b
	AND8(r12, r2, r3)
	END_INSN(#4)
insna1: and	r12, r5, #0xff		@ and c
	AND8(r12, r2, r3)
	END_INSN(#4)
insna2:	mov	r12, r6, lsr #8		@ and d
	AND8(r12, r2, r3)
	END_INSN(#4)
insna3:	and	r12, r6, #0xff		@ and e
	AND8(r12, r2, r3)
	END_INSN(#4)
insna4: mov	r12, r7, lsr #8		@ and h
	AND8(r12, r2, r3)
	END_INSN(#4)
insna5:	and	r12, r7, #0xff		@ and l
	AND8(r12, r2, r3)
	END_INSN(#4)
insna6:	READ_BYTE(r12, r7, r3, r2)	@ and (hl)
	AND8(r12, r2, r3)
	END_INSN(#7)
insna7:	and	r12, r4, #0xff		@ and a
	AND8(r12, r2, r3)
	END_INSN(#4)
	
insna8:	mov	r12, r5, lsr #8		@ xor b
	XOR8(r12, r2, r3)
	END_INSN(#4)
insna9: and	r12, r5, #0xff		@ xor c
	XOR8(r12, r2, r3)
	END_INSN(#4)
insnaa:	mov	r12, r6, lsr #8		@ xor d
	XOR8(r12, r2, r3)
	END_INSN(#4)
insnab:	and	r12, r6, #0xff		@ xor e
	XOR8(r12, r2, r3)
	END_INSN(#4)
insnac: mov	r12, r7, lsr #8		@ xor h
	XOR8(r12, r2, r3)
	END_INSN(#4)
insnad:	and	r12, r7, #0xff		@ xor l
	XOR8(r12, r2, r3)
	END_INSN(#4)
insnae:	READ_BYTE(r12, r7, r3, r2)	@ xor (hl)
	XOR8(r12, r2, r3)
	END_INSN(#7)
insnaf:	and	r12, r4, #0xff		@ xor a
	XOR8(r12, r2, r3)
	END_INSN(#4)


insnb0:	mov	r12, r5, lsr #8		@ or b
	OR8(r12, r2, r3)
	END_INSN(#4)
insnb1: and	r12, r5, #0xff		@ or c
	OR8(r12, r2, r3)
	END_INSN(#4)
insnb2:	mov	r12, r6, lsr #8		@ or d
	OR8(r12, r2, r3)
	END_INSN(#4)
insnb3:	and	r12, r6, #0xff		@ or e
	OR8(r12, r2, r3)
	END_INSN(#4)
insnb4: mov	r12, r7, lsr #8		@ or h
	OR8(r12, r2, r3)
	END_INSN(#4)
insnb5:	and	r12, r7, #0xff		@ or l
	OR8(r12, r2, r3)
	END_INSN(#4)
insnb6:	READ_BYTE(r12, r7, r3, r2)	@ or (hl)
	OR8(r12, r2, r3)
	END_INSN(#7)
insnb7:	and	r12, r4, #0xff		@ or a
	OR8(r12, r2, r3)
	END_INSN(#4)
	
insnb8:	mov	r12, r5, lsr #8		@ cp b
	CP8(r12, r2, r3)
	END_INSN(#4)
insnb9: and	r12, r5, #0xff		@ cp c
	CP8(r12, r2, r3)
	END_INSN(#4)
insnba:	mov	r12, r6, lsr #8		@ cp d
	CP8(r12, r2, r3)
	END_INSN(#4)
insnbb:	and	r12, r6, #0xff		@ cp e
	CP8(r12, r2, r3)
	END_INSN(#4)
insnbc: mov	r12, r7, lsr #8		@ cp h
	CP8(r12, r2, r3)
	END_INSN(#4)
insnbd:	and	r12, r7, #0xff		@ cp l
	CP8(r12, r2, r3)
	END_INSN(#4)
insnbe:	READ_BYTE(r12, r7, r3, r2)	@ cp (hl)
	CP8(r12, r2, r3)
	END_INSN(#7)
insnbf:	and	r12, r4, #0xff		@ cp a
	CP8(r12, r2, r3)
	END_INSN(#4)


insnc0:	@ ret nz
	add	r10,r10,#1
	tst	r4,#0x8000
	beq	insnc9
	END_INSN(#4)
insnc1:	@ pop bc
	ldrh	r12,[r0, #20]
	READ_BYTE(r5, r12, r3, r2)
	INC16(r12)
	READ_BYTE(r3, r12, r3, r2)
	INC16(r12)
	strh	r12,[r0, #20]
	orr	r5, r5, r3, lsl #8
	END_INSN(#10)
insnc2:	@ jp nz,NN
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	tst	r4, #0x8000
	orreq	r9, r12, r3, lsl #8
	END_INSN(#10)
insnc3: @ jp NN
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	orr	r9, r12, r3, lsl #8
	END_INSN(#10)
insnc4:	@ call nz,NN
	tst	r4, #0x8000
	beq	insncd
	INC16(r9)
	INC16(r9)
	END_INSN(#10)
insnc5:	@ push bc
	ldrh	r12,[r0, #20]
	DEC16(r12)
	mov	r5, r5, ror #8
	WRITE_BYTE(r5, r12, r3, r2)
	DEC16(r12)
	mov	r5, r5, ror #24
	WRITE_BYTE(r5, r12, r3, r2)
	strh	r12,[r0, #20]
	END_INSN(#11)
insnc6:	@ add a,N
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	ADD8(r12, r2, r3)
	END_INSN(#7)
insnc7:	@ rst 0
	ldrh	r12,[r0, #20]
	DEC16(r12)
	mov	r9, r9, ror #8
	WRITE_BYTE(r9, r12, r3, r2)
	DEC16(r12)
	mov	r9, r9, ror #24
	WRITE_BYTE(r9, r12, r3, r2)
	strh	r12,[r0, #20]
	mov	r9, #0
	END_INSN(#11)
insnc8:	@ ret z
	add	r10,r10,#1
	tst	r4,#0x8000
	bne	insnc9
	END_INSN(#4)
insnc9:	@ ret
	ldrh	r12,[r0, #20]
	READ_BYTE(r9, r12, r3, r2)
	INC16(r12)
	READ_BYTE(r3, r12, r3, r2)
	INC16(r12)
	strh	r12,[r0, #20]
	orr	r9, r9, r3, lsl #8
	END_INSN(#10)
insnca:	@ jp z,NN
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	tst	r4, #0x8000
	orrne	r9, r12, r3, lsl #8
	END_INSN(#10)
insncc:	@ call z,NN
	tst	r4, #0x8000
	bne	insncd
	INC16(r9)
	INC16(r9)
	END_INSN(#10)
insncd:	@ call NN
	@ read destination address
	READ_BYTE(r8, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	orr	r8, r8, r3, lsl #8
	@ stack old PC
	ldrh	r12,[r0, #20]
	mov	r9, r9, ror #8
	DEC16(r12)
	WRITE_BYTE(r9, r12, r3, r2)
	DEC16(r12)
	mov	r9, r9, ror #24
	WRITE_BYTE(r9, r12, r3, r2)
	strh	r12,[r0, #20]
	@ jump
	mov	r9, r8
	END_INSN(#17)
insnce:	@ adc a,N
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	ADC8(r12, r2, r3)
	END_INSN(#7)
insncf:	@ rst 8
	ldrh	r12,[r0, #20]
	DEC16(r12)
	mov	r9, r9, ror #8
	WRITE_BYTE(r9, r12, r3, r2)
	DEC16(r12)
	mov	r9, r9, ror #24
	WRITE_BYTE(r9, r12, r3, r2)
	strh	r12,[r0, #20]
	mov	r9, #8
	END_INSN(#11)

insnd0:	@ ret nc
	add	r10,r10,#1
	tst	r4,#0x1000
	beq	insnc9
	END_INSN(#4)
insnd1:	@ pop de
	ldrh	r12,[r0, #20]
	READ_BYTE(r6, r12, r3, r2)
	INC16(r12)
	READ_BYTE(r3, r12, r3, r2)
	INC16(r12)
	strh	r12,[r0, #20]
	orr	r6, r6, r3, lsl #8
	END_INSN(#10)
insnd2:	@ jp nc,NN
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	tst	r4, #0x1000
	orreq	r9, r12, r3, lsl #8
	END_INSN(#10)
#ifndef GAMEBOY
insnd3:	@ out (N),a
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	and	r3, r4, #0xff
	orr	r2, r12, r3, lsl #8
	bl	port_out
	END_INSN(#11)
#endif
insnd4:	@ call nc,NN
	tst	r4, #0x1000
	beq	insncd
	INC16(r9)
	INC16(r9)
	END_INSN(#10)
insnd5:	@ push de
	ldrh	r12,[r0, #20]
	DEC16(r12)
	mov	r6, r6, ror #8
	WRITE_BYTE(r6, r12, r3, r2)
	DEC16(r12)
	mov	r6, r6, ror #24
	WRITE_BYTE(r6, r12, r3, r2)
	strh	r12,[r0, #20]
	END_INSN(#11)
insnd6:	@ sub N
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	SUB8(r12, r2, r3)
	END_INSN(#7)
insnd7:	@ rst 16
	ldrh	r12,[r0, #20]
	DEC16(r12)
	mov	r9, r9, ror #8
	WRITE_BYTE(r9, r12, r3, r2)
	DEC16(r12)
	mov	r9, r9, ror #24
	WRITE_BYTE(r9, r12, r3, r2)
	strh	r12,[r0, #20]
	mov	r9, #16
	END_INSN(#11)
insnd8:	@ ret c
	add	r10,r10,#1
	tst	r4,#0x1000
	bne	insnc9
	END_INSN(#4)
#ifndef GAMEBOY
insnd9:	@ exx
	ldrh	r3,[r0, #30]	@ load bc'
	ldrh	r2,[r0, #32]	@ load de'
	ldrh	r12,[r0, #34]	@ load hl'
	strh	r5,[r0, #30]
	strh	r6,[r0, #32]
	strh	r7,[r0, #34]
	mov	r5,r3
	mov	r6,r2
	mov	r7,r12
	END_INSN(#4)
#else
insnd9:	@ reti
	mov	r3, #0xff
	strb	r3, [r0, #38]
	strb	r3, [r0, #39]
	b	insnc9
#endif
insnda:	@ jp c,NN
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	tst	r4, #0x1000
	orrne	r9, r12, r3, lsl #8
	END_INSN(#10)
#ifndef GAMEBOY
insndb:	@ in a,(N)
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	and	r2, r4, #0xff
	orr	r2, r12, r2, lsl #8
	bl	port_in
	bic	r4, r4, #0xff
	orr	r4, r4, r2
	END_INSN(#11)
#endif
insndc:	@ call c,NN
	tst	r4, #0x1000
	bne	insncd
	INC16(r9)
	INC16(r9)
	END_INSN(#10)
insnde:	@ sbc a,N
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	SBC8(r12, r2, r3)
	END_INSN(#7)
insndf:	@ rst 24
	ldrh	r12,[r0, #20]
	DEC16(r12)
	mov	r9, r9, ror #8
	WRITE_BYTE(r9, r12, r3, r2)
	DEC16(r12)
	mov	r9, r9, ror #24
	WRITE_BYTE(r9, r12, r3, r2)
	strh	r12,[r0, #20]
	mov	r9, #24
	END_INSN(#11)

#ifndef GAMEBOY
insne0:	@ ret po
	add	r10,r10,#1
	tst	r4,#0x400
	beq	insnc9
	END_INSN(#4)
#else
insne0:	@ ld (FFN),a
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	orr	r12, r12, #0xff00
	WRITE_BYTE(r4, r12, r3, r2)
	END_INSN(#10)
#endif
insne1:	@ pop hl
	ldrh	r12,[r0, #20]
	READ_BYTE(r7, r12, r3, r2)
	INC16(r12)
	READ_BYTE(r3, r12, r3, r2)
	INC16(r12)
	strh	r12,[r0, #20]
	orr	r7, r7, r3, lsl #8
	END_INSN(#10)
#ifndef GAMEBOY
insne2:	@ jp po,NN
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	tst	r4, #0x400
	orreq	r9, r12, r3, lsl #8
	END_INSN(#10)
insne3:	@ ex (sp),hl
	ldrh	r12,[r0, #20]
	READ_BYTE(r8, r12, r3, r2)
	WRITE_BYTE(r7, r12, r3, r2)
	INC16(r12)
	READ_BYTE(r3, r12, r3, r2)
	orr	r8, r8, r3, lsl #8
	mov	r7, r7, ror #8
	WRITE_BYTE(r7, r12, r3, r2)
	mov	r7, r8
	END_INSN(#19)
insne4:	@ call po,NN
	tst	r4, #0x400
	beq	insncd
	INC16(r9)
	INC16(r9)
	END_INSN(#10)
#else
insne2:	@ ld (FFC),a
	orr	r12, r5, #0xff00
	WRITE_BYTE(r4, r12, r3, r2)
	END_INSN(#7)
#endif
insne5:	@ push hl
	ldrh	r12,[r0, #20]
	DEC16(r12)
	mov	r7, r7, ror #8
	WRITE_BYTE(r7, r12, r3, r2)
	DEC16(r12)
	mov	r7, r7, ror #24
	WRITE_BYTE(r7, r12, r3, r2)
	strh	r12,[r0, #20]
	END_INSN(#11)
insne6:	@ and N
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	AND8(r12, r2, r3)
	END_INSN(#7)
insne7:	@ rst 32
	ldrh	r12,[r0, #20]
	DEC16(r12)
	mov	r9, r9, ror #8
	WRITE_BYTE(r9, r12, r3, r2)
	DEC16(r12)
	mov	r9, r9, ror #24
	WRITE_BYTE(r9, r12, r3, r2)
	strh	r12,[r0, #20]
	mov	r9, #32
	END_INSN(#11)
#ifndef GAMEBOY
insne8:	@ ret pe
	add	r10,r10,#1
	tst	r4,#0x400
	bne	insnc9
	END_INSN(#4)
#else
insne8:	@ add sp,dis
	READ_SIGNED_BYTE(r12, r9, r3, r2)
	INC16(r9)
	ldrh	r8, [r0, #20]
	bic	r12, r12, #0xff0000
	bic	r12, r12, #0xff000000
	ADD16(r8, r12, r3, r2)
	strh	r8, [r0, #20]
	END_INSN(#10)
#endif
insne9:	@ jp (hl)
	mov	r9,r7
	END_INSN(#4)
#ifndef GAMEBOY
insnea:	@ jp pe,NN
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	tst	r4, #0x400
	orrne	r9, r12, r3, lsl #8
	END_INSN(#10)
insneb:	@ ex de,hl
	mov	r3,r7
	mov	r7,r6
	mov	r6,r3
	END_INSN(#4)
insnec:	@ call pe,NN
	tst	r4, #0x400
	bne	insncd
	INC16(r9)
	INC16(r9)
	END_INSN(#10)
#else
insnea:	@ ld (NN),a
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	orr	r12, r12, r3, lsl #8
	WRITE_BYTE(r4, r12, r3, r2)
	END_INSN(#13)
#endif
insnee:	@ xor N
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	XOR8(r12, r2, r3)
	END_INSN(#7)
insnef:	@ rst 40
	ldrh	r12,[r0, #20]
	DEC16(r12)
	mov	r9, r9, ror #8
	WRITE_BYTE(r9, r12, r3, r2)
	DEC16(r12)
	mov	r9, r9, ror #24
	WRITE_BYTE(r9, r12, r3, r2)
	strh	r12,[r0, #20]
	mov	r9, #40
	END_INSN(#11)

#ifndef GAMEBOY
insnf0:	@ ret p
	add	r10,r10,#1
	tst	r4,#0x8000
	beq	insnc9
	END_INSN(#4)
#else
insnf0:	@ ld a,(FFN)
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	orr	r12, r12, #0xff00
	READ_BYTE(r8, r12, r3, r2)
	bic	r4, r4, #0xff
	orr	r4, r4, r8

	b	insnf0sw
	mov	r3, #0x5400
	orr	r3, r3, #0x93
	cmp	r3, r9
	bne	insnf0sw
	ldrh	r2, [r0, #94]
	cmp	r2, #0
	bne	insnf0sw
	ldr	r12, [r0, #88]
	ldrb	r3, [r12, #0xc2]
	cmp	r3, #0
	beq	insnf0sw
	strh	r3, [r0, #92]
	strh	r9, [r0, #94]
	
insnf0sw:	
	END_INSN(#10)
#endif
insnf1:	@ pop af
	ldrh	r12,[r0, #20]
	READ_BYTE(r8, r12, r3, r2)
	INC16(r12)
	READ_BYTE(r3, r12, r3, r2)
	INC16(r12)
	strh	r12,[r0, #20]
	and	r4, r4, #0xff000000
	orr	r4, r4, r3
	orr	r4, r4, r8, lsl #8
	END_INSN(#10)
#ifndef GAMEBOY
insnf2:	@ jp p,NN
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	tst	r4, #0x8000
	orreq	r9, r12, r3, lsl #8
	END_INSN(#10)
#else
insnf2:	@ ld a,(c)
	orr	r12, r5, #0xff00
	READ_BYTE(r3, r12, r3, r2)
	bic	r4, r4, #0xff
	orr	r4, r4, r3
	END_INSN(#8)
#endif
insnf3:	@ di
	mov	r2,#0
	strb	r2,[r0, #38]
	strb	r2,[r0, #39]
	END_INSN(#4)
#ifndef GAMEBOY
insnf4:	@ call p,NN
	tst	r4, #0x8000
	beq	insncd
	INC16(r9)
	INC16(r9)
	END_INSN(#10)
#endif
insnf5:	@ push af
	ldrh	r12,[r0, #20]
	DEC16(r12)
	WRITE_BYTE(r4, r12, r3, r2)
	DEC16(r12)
	mov	r4, r4, ror #8
	WRITE_BYTE(r4, r12, r3, r2)
	mov	r4, r4, ror #24
	strh	r12,[r0, #20]
	END_INSN(#11)
insnf6:	@ or N
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	OR8(r12, r2, r3)
	END_INSN(#7)
insnf7:	@ rst 48
	ldrh	r12,[r0, #20]
	DEC16(r12)
	mov	r9, r9, ror #8
	WRITE_BYTE(r9, r12, r3, r2)
	DEC16(r12)
	mov	r9, r9, ror #24
	WRITE_BYTE(r9, r12, r3, r2)
	strh	r12,[r0, #20]
	mov	r9, #48
	END_INSN(#11)
#ifndef GAMEBOY
insnf8:	@ ret m
	add	r10,r10,#1
	tst	r4,#0x8000
	bne	insnc9
	END_INSN(#4)
#else
insnf8:	@ ldhl sp,N
	READ_SIGNED_BYTE(r12, r9, r3, r2)
	INC16(r9)
	bic	r12, r12, #0xff0000
	bic	r12, r12, #0xff000000
	ldrh	r7, [r0, #20]
	ADD16(r7, r12, r3, r2)
	END_INSN(#10)
#endif
insnf9:	@ ld sp,hl
	strh	r7,[r0, #20]
	END_INSN(#6)
#ifndef GAMEBOY
insnfa:	@ jp m,NN
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	tst	r4, #0x8000
	orrne	r9, r12, r3, lsl #8
	END_INSN(#10)
#else
insnfa:	@ ld a,(NN)
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)
	orr	r12, r12, r3, lsl #8
	READ_BYTE(r3, r12, r3, r2)
	bic	r4, r4, #0xff
	orr	r4, r4, r3
	END_INSN(#13)
#endif
insnfb:	@ ei
	mov	r2,#0xff
	strb	r2,[r0, #38]
	strb	r2,[r0, #39]
	END_INSN(#4)
#ifndef GAMEBOY
insnfc:	@ call m,NN
	tst	r4, #0x8000
	bne	insncd
	INC16(r9)
	INC16(r9)
	END_INSN(#10)
#endif
insnfe:	@ cp N
	READ_BYTE(r12, r9, r3, r2)
	INC16(r9)
	CP8(r12, r2, r3)
	END_INSN(#7)
insnff:	@ rst 56
	ldrh	r12,[r0, #20]
	DEC16(r12)
	mov	r9, r9, ror #8
	WRITE_BYTE(r9, r12, r3, r2)
	DEC16(r12)
	mov	r9, r9, ror #24
	WRITE_BYTE(r9, r12, r3, r2)
	strh	r12,[r0, #20]
	mov	r9, #56
	END_INSN(#11)

	
@============================================================
@
@ Include the files of prefixed instructions
@
@============================================================
#include "z80cb.S"

#ifndef GAMEBOY
#include "z80ed.S"
#include "z80ix.S"
#include "z80ixcb.S"
#else
	@ These are no-ops on Gameboy CPU
insnd3:
insndb:	
insndd:
insne3:
insne4:
insneb:
insnec:	
insned:
insnf4:
insnfc:	
insnfd:
	END_INSN(#4)
#endif

	@
	@ When this is called, pagingRegs have just been updated
	@ and ROM or RAM paging should possibly be changed in the
	@ page tables
	@
	@ Must preserve all registers - this is called from WRITE_BYTE!
	@
	@ FIXME: won't work properly for all of MBC 1, 2, 3

	@
	@ MBC operation details:
	@
	@ MBC1 - up to 2MB ROM, 32KB RAM
	@
	@ 0000-1FFF - write value with 0xA in lower 4 bits in here to enable
	@             RAM. Any other value disables it. Disabled by default
	@ 2000-3FFF - write value in here to select ROM bank for 4000-7FFF.
	@             00 is treated as 01 (because bank 0 is always mapped at
	@             0000 anyway). Only lower 5 bits specified here.
	@             The 00 issue means that banks 0x20, 0x40, 0x60 can't be
	@             mapped at all!
	@ 4000-5FFF - 2-bit register. Either specifies bits 5-6 of ROM bank
	@             number, or the RAM bank number for A000-BFFF.
	@ 6000-7FFF - 1-bit register. 00 = previous register is ROM upper bits,
	@             01 = previous register is RAM select
	@
	@
	@ MBC2 - up to 256KB ROM, 512x4bits RAM
	@
	@ 0000-1FFF - RAM enable (it's mapped to A000-A1FF when enabled)
	@             LSB of upper address byte must be 0
	@ 2000-3FFF - 4-bit ROM select register. LSB of upper address byte
	@             must be 1
	@
	@
	@ MBC3 - up to 2MB ROM, 32KB RAM, timer (mostly like MBC1)
	@
	@ 0000-1FFF - write value with 0xA in lower 4 bits to enable RAM or
	@             the clock registers (see below)
	@ 2000-3FFF - 7-bit ROM bank number. 00 is treated as 01 again.
	@ 4000-5FFF - Writing 00-03 maps that RAM bank into A000-BFFF. Writing
	@             08-0C maps that clock register to every address in the
	@             range A000-BFFF.
	@ 6000-7FFF - Write 00 then 01 here to "latch" current time into the
	@             RTC registers for reading them.
	@
	@ RTC registers:
	@  08 - seconds (0-59)
	@  09 - minutes (0-59)
	@  0A - hours (0-23)
	@  0B - lower 8-bits of day counter
	@  0C - d0 - upper bit of day counter
	@       d6 - halt flag - 0=active, 1=stop timer
	@       d7 - day counter overflow bit
	@
paging_write:
	push	{r2-r3}

	ldrb	r2, [r0, #79]		@ MBC type
	cmp	r2, #1
	beq	paging_mbc1
	cmp	r2, #2
	beq	paging_mbc2
	cmp	r2, #3
	beq	paging_mbc3

	@ unrecognised MBC (or no MBC)

	pop	{r2-r3}
	bx	lr

paging_mbc1:
	ldrb	r2, [r0, #111]          /* ROM or RAM mode? */
	cmp	r2, #0
	bne	paging_mbc1_ram_mode
	
	ldrb	r2, [r0, #109]		/* ROM page */
	and	r2, r2, #0x1f		/* FIXME: proper masking? */
	cmp	r2, #0
	addeq	r2, r2, #1

	ldrb	r3, [r0, #110]		/* upper bits */
	and	r3, r3, #3
	add	r2, r2, r3, lsl #5
	
	mov	r2, r2, lsl #14
	ldr	r3, [r11, #64]		/* ROM start */
	add	r2, r2, r3
	str	r2, [r11, #8]
	add	r2, r2, #0x2000
	str	r2, [r11, #12]

	ldr	r3, [r11, #68]		/* RAM start */
	str	r3, [r11, #20]
	str	r3, [r11, #52]

	pop	{r2-r3}
	bx	lr

paging_mbc1_ram_mode:
	ldrb	r2, [r0, #109]		/* ROM page */
	and	r2, r2, #0x1f		/* FIXME: proper masking? */
	cmp	r2, #0
	addeq	r2, r2, #1
	mov	r2, r2, lsl #14
	ldr	r3, [r11, #64]		/* ROM start */
	add	r2, r2, r3
	str	r2, [r11, #8]
	add	r2, r2, #0x2000
	str	r2, [r11, #12]

	ldrb	r2, [r0, #110]		/* RAM page */
	and	r2, r2, #3		/* FIXME: proper masking? */
	mov	r2, r2, lsl #13
	ldr	r3, [r11, #68]		/* RAM start */
	add	r2, r2, r3
	str	r2, [r11, #20]
	str	r2, [r11, #52]

	pop	{r2-r3}
	bx	lr

paging_mbc2:
	ldrb	r2, [r0, #109]		/* ROM page */
	and	r2, r2, #0xf
	cmp	r2, #0
	addeq	r2, r2, #1
	mov	r2, r2, lsl #14
	ldr	r3, [r11, #64]		/* ROM start */
	add	r2, r2, r3
	str	r2, [r11, #8]
	add	r2, r2, #0x2000
	str	r2, [r11, #12]

	pop	{r2-r3}
	bx	lr

paging_mbc3:
	ldrb	r2, [r0, #109]		/* ROM page */
	ldrb	r3, [r0, #77]		/* ROM size */
	sub	r3, r3, #1
	and	r2, r2, r3
	cmp	r2, #0
	addeq	r2, r2, #1
	mov	r2, r2, lsl #14
	ldr	r3, [r11, #64]		/* ROM start */
	add	r2, r2, r3
	str	r2, [r11, #8]
	add	r2, r2, #0x2000
	str	r2, [r11, #12]

	ldrb	r2, [r0, #110]		/* RAM page */
	ldrb	r3, [r0, #112]		/* RAM size */
	sub	r3, r3, #1
	and	r2, r2, r3
	mov	r2, r2, lsl #13
	ldr	r3, [r11, #68]		/* RAM start */
	add	r2, r2, r3
	str	r2, [r11, #20]
	str	r2, [r11, #52]

	@ real time clock not implemented
	pop	{r2-r3}
	bx	lr

	
	
	@
	@ When this is called, a value has just been written to an I/O
	@ register. regWritten contains the register number
	@
	@ Must preserve all registers - this is called from WRITE_BYTE!
	@
	@ FIXME: could speed this up with a jump table or a binary
	@ search tree.
	@
io_write:
	@ Remember to restore values of read-only ones
	push	{r2-r6}

	ldr	r4, [r0, #88]		@ ioRAM
	ldrb	r2, [r0, #74]		@ which register was written
	
	@ switch on r2 (regWritten)
	cmp	r2, #0
	beq	io_write_00
	cmp	r2, #2
	beq	io_write_02
	cmp	r2, #4
	beq	io_write_04
	cmp	r2, #5
	beq	io_write_05
	cmp	r2, #7
	beq	io_write_07
	cmp	r2, #0x10
	beq	io_write_10
	cmp	r2, #0x11
	beq	io_write_11
	cmp	r2, #0x12
	beq	io_write_12
	cmp	r2, #0x13
	beq	io_write_13
	cmp	r2, #0x14
	beq	io_write_14
	cmp	r2, #0x16
	beq	io_write_16
	cmp	r2, #0x17
	beq	io_write_17
	cmp	r2, #0x18
	beq	io_write_18
	cmp	r2, #0x19
	beq	io_write_19
	cmp	r2, #0x1b
	beq	io_write_1b
	cmp	r2, #0x1d
	beq	io_write_1d
	cmp	r2, #0x1e
	beq	io_write_1e
	cmp	r2, #0x20
	beq	io_write_20
	cmp	r2, #0x21
	beq	io_write_21
	cmp	r2, #0x22
	beq	io_write_22
	cmp	r2, #0x23
	beq	io_write_23
	cmp	r2, #0x41
	beq	io_write_41
	cmp	r2, #0x44
	beq	io_write_44
	cmp	r2, #0x46
	beq	io_write_46
	cmp	r2, #0x47
	beq	io_write_47
	cmp	r2, #0x48
	beq	io_write_48
	cmp	r2, #0x49
	beq	io_write_49

	@cmp	r2, #0x40
	@bne	io_write_done
	@ldrb	r3, [r4, #0x40]
	@tst	r3, #0x80
	@mov	r2, #2
	@strneh	r2, [r0, #94]
	
	
io_write_done:	

	pop	{r2-r6}
	bx	lr

	@==================================================
	@
	@ Misc ports
	@
	@==================================================
io_write_00:
	@ port 00: joypad port reading: ACTIVE
	ldrb	r2, [r4, #0]		@ get register 0 value
	ldrb	r3, [r0, #75]		@ joypad data
	tst	r2, #16
	andeq	r3, r3, #0xf
	tst	r2, #32
	moveq	r3, r3, lsr #4
	strb	r3, [r4, #0]		@ store selected data in reg 0
	b	io_write_done

io_write_02:
	@ port 02: serial transfer control: ACTIVE
	ldrb	r2, [r4, #2]
	tst	r2, #0x80
	beq	io_write_done
	mov	r2, #2
	strb	r2, [r0, #78]
	b	io_write_done
	
io_write_04:
	@ port 04: divider register: ACTIVE
	@ writing resets it to 0
	mov	r2, #0
	strb	r2, [r4, #4]
	str	r2, [r0, #60]
	b	io_write_done
	
io_write_05:
	@ port 05: timer counter: PRESERVE
	ldr	r3, [r0, #64]		@ read our copy of timerCounter
	mov	r3, r3, lsr #24
	strb	r3, [r4, #5]		@ overwrite last access
	b	io_write_done

io_write_07:
	@ port 07: timer control: ACTIVE
	ldrb	r3, [r4, #7]
	ands	r3, r3, #3		@ 00 - 4096Hz
	moveq	r2, #0x710000
	cmp	r3, #1			@ 01 - 262144Hz
	moveq	r2, #0x1c000000
	cmp	r3, #2			@ 10 - 65536Hz
	moveq	r2, #0x7000000
	cmp	r3, #3			@ 11 - 16384Hz
	moveq	r2, #0xc50000
	orreq	r2, #0x1000000
	str	r2, [r0, #68]		@ store new timer increment
	b	io_write_done

	
	@==================================================
	@
	@ Sound channel 1
	@
	@==================================================
io_write_10:
	@ redo all sweep data
	@ (72 * t)
	ldr	r2, [r0, #44]		@ soundState
	ldrb	r3, [r4, #0x10]		@ get all sweep info

	and	r5, r3, #0xf		@ get sweep type
	strb	r5, [r2, #28]		@ and store

	and	r3, r3, #0x70
	mov	r3, r3, lsl #2		@ get sweep time * 64
	add	r3, r3, r3, lsr #3	@ *72
	str	r3, [r2, #24]		@ sweep threshold
	
	b	io_write_done

	
io_write_11:
	@ redo threshold and length data
	ldr	r2, [r0, #44]		@ soundState

	@ Threshold is derived from Freq reg according to duty cycle
	ldr	r5, [r2, #4]		@ frequency
	ldrb	r3, [r4, #0x11]		@ read duty/length
	ands	r6, r3, #0xc0		@ get just duty
	moveq	r5, r5, lsr #3		@ 12.5%
	cmp	r6, #0x40
	moveq	r5, r5, lsr #2		@ 25%
	cmp	r6, #0x80
	moveq	r5, r5, lsr #1		@ 50%
	cmp	r6, #0xc0
	moveq	r5, r5, lsr #1		@ 50%
	addeq	r5, r5, r5, lsr #1	@ 75%
	str	r5, [r2, #12]		@ store channel1Threshold

	@ Now handle length
	and	r6, r3, #0x3f
	ldrb	r3, [r4, #0x14]
	tst	r3, #0x40
	beq	io_write_done
	rsb	r5, r6, #64		@ 64 - t1
	mov	r5, r5, lsl #5
	add	r5, r5, r5, lsr #2	@ (64 - t1) * 36
	str	r5, [r2, #16]		@ store channel1Length
	
	b	io_write_done

	
io_write_12:
	@ redo all envelope data
	@ (144 * n)
	ldr	r2, [r0, #44]		@ soundState

	ldrb	r3, [r4, #0x12]		@ get all envelope data
	mov	r5, r3, lsr #4		@ get initial volume
	strb	r5, [r2, #40]		@ store it
	mov	r5, #0xff
	tst	r3, #8
	movne	r5, #1
	strb	r5, [r2, #41]		@ store envelope step
	and	r3, r3, #7		@ get n
	mov	r3, r3, lsl #7		@ n * 128
	add	r3, r3, r3, lsr #3	@ n * 144
	str	r3, [r2, #36]		@ store envelope threshold
	mov	r3, #0
	str	r3, [r2, #32]		@ store envelope counter
	
	b	io_write_done
	
io_write_13:
	@ redo frequency and threshold
	ldr	r2, [r0, #44]		@ soundState

	@ Freq reg is (2048 - x) * 36
	ldrb	r3, [r4, #0x14]		@ high freq
	ldrb	r5, [r4, #0x13]		@ low freq
	orr	r5, r5, r3, lsl #8
	bic	r5, r5, #0xf800		@ get total freq
	rsb	r5, r5, #2048		@ 2048-freq
	mov	r5, r5, lsl #5
	add	r5, r5, r5, lsr #3	@ *36

	sub	r5, r5, r5, lsr #5	@ TUNING
	
	str	r5, [r2, #4]		@ store channel1Freq
	
	@ Threshold is derived from Freq reg according to duty cycle
	ldrb	r6, [r4, #0x11]		@ read duty/length
	ands	r6, r6, #0xc0		@ get just duty
	moveq	r5, r5, lsr #3		@ 12.5%
	cmp	r6, #0x40
	moveq	r5, r5, lsr #2		@ 25%
	cmp	r6, #0x80
	moveq	r5, r5, lsr #1		@ 50%
	cmp	r6, #0xc0
	moveq	r5, r5, lsr #1		@ 50%
	addeq	r5, r5, r5, lsr #1	@ 75%
	str	r5, [r2, #12]		@ store channel1Threshold
	b	io_write_done
	
io_write_14:
	@ port 14: frequency high 1: ACTIVE
	@ r4 points to register RAM
	ldr	r2, [r0, #44]		@ soundState

	@ redo frequency (& threshold) here
	@ Freq reg is (2048 - x) * 36
	ldrb	r3, [r4, #0x14]		@ high freq
	ldrb	r5, [r4, #0x13]		@ low freq
	orr	r5, r5, r3, lsl #8
	bic	r5, r5, #0xf800		@ get total freq
	rsb	r5, r5, #2048		@ 2048-freq
	mov	r5, r5, lsl #5
	add	r5, r5, r5, lsr #3	@ *36

	sub	r5, r5, r5, lsr #5	@ TUNING
	
	str	r5, [r2, #4]		@ store channel1Freq
	
	@ Threshold is derived from Freq reg according to duty cycle
	ldrb	r6, [r4, #0x11]		@ read duty/length
	ands	r6, r6, #0xc0		@ get just duty
	moveq	r5, r5, lsr #3		@ 12.5%
	cmp	r6, #0x40
	moveq	r5, r5, lsr #2		@ 25%
	cmp	r6, #0x80
	moveq	r5, r5, lsr #1		@ 50%
	cmp	r6, #0xc0
	moveq	r5, r5, lsr #1		@ 50%
	addeq	r5, r5, r5, lsr #1	@ 75%
	str	r5, [r2, #12]		@ store channel1Threshold
	
	tst	r3, #0x80		@ if we're not restarting, we're
	beq	io_write_done		@ done

	@ redo length counter
	@ r3 d6 tells us whether to take notice of it
	@ (64 - t1) * 36
	mov	r5, #0x7f000000		@ very long length
	tst	r3, #0x40
	beq	io_write_sound1_length
	ldrb	r5, [r4, #0x11]
	and	r5, r5, #0x3f		@ get t1
	rsb	r5, r5, #64		@ 64 - t1
	mov	r5, r5, lsl #5
	add	r5, r5, r5, lsr #2	@ (64 - t1) * 36
io_write_sound1_length:
	str	r5, [r2, #16]		@ store channel1Length
	
	mov	r3, #0
	str	r3, [r2, #8]		@ clear channel1 counters - main
	str	r3, [r2, #20]		@ sweep
	str	r3, [r2, #32]		@ envelope

	@ reset level to start of envelope
	ldrb	r3, [r4, #0x12]
	mov	r3, r3, lsr #4
	strb	r3, [r2, #40]		@ level
	
	b	io_write_done


	@==================================================
	@
	@ Sound channel 1
	@
	@==================================================
	@ channel 2 length/duty
io_write_16:
	ldr	r2, [r0, #44]		@ soundState

	@ Threshold is derived from Freq reg according to duty cycle
	ldr	r5, [r2, #44]		@ frequency
	ldrb	r3, [r4, #0x16]		@ read duty/length
	ands	r6, r3, #0xc0		@ get just duty
	moveq	r5, r5, lsr #3		@ 12.5%
	cmp	r6, #0x40
	moveq	r5, r5, lsr #2		@ 25%
	cmp	r6, #0x80
	moveq	r5, r5, lsr #1		@ 50%
	cmp	r6, #0xc0
	moveq	r5, r5, lsr #1		@ 50%
	addeq	r5, r5, r5, lsr #1	@ 75%
	str	r5, [r2, #52]		@ store channel2Threshold

	@ Now handle length
	and	r6, r3, #0x3f
	ldrb	r3, [r4, #0x19]
	tst	r3, #0x40
	beq	io_write_done
	rsb	r5, r6, #64		@ 64 - t1
	mov	r5, r5, lsl #5
	add	r5, r5, r5, lsr #2	@ (64 - t1) * 36
	str	r5, [r2, #56]		@ store channel2Length
	b	io_write_done

	
	@ channel 2 envelope
io_write_17:
	@ (144 * n)
	ldr	r2, [r0, #44]		@ soundState

	ldrb	r3, [r4, #0x17]		@ get all envelope data
	mov	r5, r3, lsr #4		@ get initial volume
	strb	r5, [r2, #68]		@ store it
	mov	r5, #0xff
	tst	r3, #8
	movne	r5, #1
	strb	r5, [r2, #69]		@ store envelope step
	and	r3, r3, #7		@ get n
	mov	r3, r3, lsl #7		@ n * 128
	add	r3, r3, r3, lsr #3	@ n * 144
	str	r3, [r2, #64]		@ store envelope threshold
	mov	r3, #0
	str	r3, [r2, #60]		@ store envelope counter
	
	b	io_write_done

	@ channel 2 freq low
io_write_18:	
	@ redo frequency and threshold
	ldr	r2, [r0, #44]		@ soundState

	@ Freq reg is (2048 - x) * 36
	ldrb	r3, [r4, #0x19]		@ high freq
	ldrb	r5, [r4, #0x18]		@ low freq
	orr	r5, r5, r3, lsl #8
	bic	r5, r5, #0xf800		@ get total freq
	rsb	r5, r5, #2048		@ 2048-freq
	mov	r5, r5, lsl #5
	add	r5, r5, r5, lsr #3	@ *36

	sub	r5, r5, r5, lsr #5	@ TUNING
	
	str	r5, [r2, #44]		@ store channel2Freq
	
	@ Threshold is derived from Freq reg according to duty cycle
	ldrb	r6, [r4, #0x16]		@ read duty/length
	ands	r6, r6, #0xc0		@ get just duty
	moveq	r5, r5, lsr #3		@ 12.5%
	cmp	r6, #0x40
	moveq	r5, r5, lsr #2		@ 25%
	cmp	r6, #0x80
	moveq	r5, r5, lsr #1		@ 50%
	cmp	r6, #0xc0
	moveq	r5, r5, lsr #1		@ 50%
	addeq	r5, r5, r5, lsr #1	@ 75%
	str	r5, [r2, #52]		@ store channel1Threshold
	b	io_write_done
	
io_write_19:
	@ port 19: frequency high 2: ACTIVE
	@ r4 points to register RAM
	ldr	r2, [r0, #44]		@ soundState

	@ redo frequency (& threshold) here
	@ Freq reg is (2048 - x) * 36
	ldrb	r3, [r4, #0x19]		@ high freq
	ldrb	r5, [r4, #0x18]		@ low freq
	orr	r5, r5, r3, lsl #8
	bic	r5, r5, #0xf800		@ get total freq
	rsb	r5, r5, #2048		@ 2048-freq
	mov	r5, r5, lsl #5
	add	r5, r5, r5, lsr #3	@ *36

	sub	r5, r5, r5, lsr #5	@ TUNING
	
	str	r5, [r2, #44]		@ store channel2Freq
	
	@ Threshold is derived from Freq reg according to duty cycle
	ldrb	r6, [r4, #0x16]		@ read duty/length
	ands	r6, r6, #0xc0		@ get just duty
	moveq	r5, r5, lsr #3		@ 12.5%
	cmp	r6, #0x40
	moveq	r5, r5, lsr #2		@ 25%
	cmp	r6, #0x80
	moveq	r5, r5, lsr #1		@ 50%
	cmp	r6, #0xc0
	moveq	r5, r5, lsr #1		@ 50%
	addeq	r5, r5, r5, lsr #1	@ 75%
	str	r5, [r2, #52]		@ store channel2Threshold
	
	tst	r3, #0x80		@ if we're not restarting, we're
	beq	io_write_done		@ done

	@ redo length counter
	@ r3 d6 tells us whether to take notice of it
	@ (64 - t1) * 36
	mov	r5, #0x7f000000		@ very long length
	tst	r3, #0x40
	beq	io_write_sound2_length
	ldrb	r5, [r4, #0x16]
	and	r5, r5, #0x3f		@ get t1
	rsb	r5, r5, #64		@ 64 - t1
	mov	r5, r5, lsl #5
	add	r5, r5, r5, lsr #2	@ (64 - t1) * 36
io_write_sound2_length:
	str	r5, [r2, #56]		@ store channel2Length
	
	mov	r3, #0
	str	r3, [r2, #48]		@ clear channel2 counters - main
	str	r3, [r2, #60]		@ envelope

	@ reset level to start of envelope
	ldrb	r3, [r4, #0x17]
	mov	r3, r3, lsr #4
	strb	r3, [r2, #68]		@ level
	b	io_write_done

	
	@==================================================
	@
	@ Sound channel 3
	@
	@==================================================
io_write_1b:
	ldr	r2, [r0, #44]		@ soundState
	ldrb	r5, [r4, #0x1e]
	tst	r5, #0x40		@ use length?
	beq	io_write_done
	
	ldrb	r3, [r4, #0x1b]		@ get length
	rsb	r3, r3, #256		@ 256 - t1
	mov	r3, r3, lsl #5
	add	r3, r3, r3, lsr #2	@ (256 - t1) * 36
	str	r3, [r2, #80]		@ store channel3Length
	b	io_write_done

io_write_1d:
	ldr	r2, [r0, #44]		@ soundState

	ldrb	r3, [r4, #0x1e]		@ high freq
	ldrb	r5, [r4, #0x1d]		@ low freq
	orr	r5, r5, r3, lsl #8
	bic	r5, r5, #0xf800		@ get total freq
	rsb	r5, r5, #2048		@ 2048 - freq
	mov	r5, r5, lsl #1
	add	r5, r5, r5, lsr #3	@ *72

	sub	r5, r5, r5, lsr #5	@ TUNING
	
	str	r5, [r2, #72]		@ channel3Freq
	b	io_write_done
	
io_write_1e:
	@ port 1E: frequency high 3: ACTIVE
	ldr	r2, [r0, #44]		@ soundState

	ldrb	r3, [r4, #0x1e]		@ high freq
	ldrb	r5, [r4, #0x1d]		@ low freq
	orr	r5, r5, r3, lsl #8
	bic	r5, r5, #0xf800		@ get total freq
	rsb	r5, r5, #2048		@ 2048 - freq
	mov	r5, r5, lsl #1
	add	r5, r5, r5, lsr #3	@ *72

	sub	r5, r5, r5, lsr #5	@ TUNING
	
	str	r5, [r2, #72]		@ channel3Freq

	tst	r3, #0x80		@ restarting?
	beq	io_write_done

	@ redo length counter
	mov	r5, #0x7f000000
	tst	r3, #0x40
	beq	io_write_sound3_length
	ldrb	r5, [r4, #0x1b]		@ get length
	rsb	r5, r5, #256		@ 256 - t1
	mov	r5, r5, lsl #5
	add	r5, r5, r5, lsr #2	@ (256 - t1) * 36
io_write_sound3_length:
	str	r5, [r2, #80]

	mov	r3, #0
	str	r3, [r2, #76]		@ reset channel3Counter
	
	b	io_write_done
	

	@==================================================
	@
	@ Sound channel 4
	@
	@==================================================
io_write_20:
	@ channel 4 length
	ldr	r2, [r0, #44]		@ soundState
	ldrb	r6, [r4, #0x20]		@ read length
	and	r6, r6, #0x3f
	ldrb	r3, [r4, #0x23]
	tst	r3, #0x40		@ using length?
	beq	io_write_done
	rsb	r5, r6, #64
	mov	r5, r5, lsl #5
	add	r5, r5, r5, lsr #2	@ (64 - t1) * 36
	str	r5, [r2, #96]		@ channel4Length
	b	io_write_done

io_write_21:
	@ channel 4 envelope
	ldr	r2, [r0, #44]		@ soundState

	ldrb	r3, [r4, #0x21]		@ get all envelope data
	mov	r5, r3, lsr #4		@ get initial volume
	strb	r5, [r2, #112]		@ store it
	mov	r5, #0xff
	tst	r3, #8
	movne	r5, #1
	strb	r5, [r2, #116]		@ store envelope step
	and	r3, r3, #7		@ get n
	mov	r3, r3, lsl #7
	add	r3, r3, r3, lsr #3	@ n * 144
	str	r3, [r2, #108]		@ store envelope threshold
	mov	r3, #0
	str	r3, [r2, #104]		@ reset envelope counter
	b	io_write_done

io_write_22:
	@ channel 4 noise control
	ldr	r2, [r0, #44]		@ soundState

	ldrb	r3, [r4, #0x22]		@ get noise control value
	and	r5, r3, #7		@ get r
	mov	r6, r3, lsr #4		@ get s
	mov	r5, r5, lsl #1		@ multiply r by 2 to start with
	cmp	r5, #0
	moveq	r5, #1			@ use 0.5 if r is 0
	cmp	r6, #1
	moveq	r5, r5, lsl #1		@ shift r by s
	cmp	r6, #2
	moveq	r5, r5, lsl #2
	cmp	r6, #3
	moveq	r5, r5, lsl #3
	cmp	r6, #4
	moveq	r5, r5, lsl #4
	cmp	r6, #5
	moveq	r5, r5, lsl #5
	cmp	r6, #6
	moveq	r5, r5, lsl #6
	cmp	r6, #7
	moveq	r5, r5, lsl #7
	cmp	r6, #8
	moveq	r5, r5, lsl #8
	cmp	r6, #9
	moveq	r5, r5, lsl #9
	cmp	r6, #10
	moveq	r5, r5, lsl #10
	cmp	r6, #11
	moveq	r5, r5, lsl #11
	cmp	r6, #12
	moveq	r5, r5, lsl #12
	cmp	r6, #13
	moveq	r5, r5, lsl #13
	cmp	r6, #14
	moveq	r5, r5, lsl #14
	cmp	r6, #15
	moveq	r5, r5, lsl #15

	mov	r5, r5, lsl #3		@ * 9
	add	r5, r5, r5, lsr #3

	sub	r5, r5, r5, lsr #5	@ TUNING
	
	str	r5, [r2, #88]		@ store frequency
	
	b	io_write_done

io_write_23:
	@ port 23: channel 4 restart
	ldr	r2, [r0, #44]		@ soundState
	ldrb	r3, [r4, #0x23]
	tst	r3, #0x80
	beq	io_write_done

	@ restarting
	mov	r5, #0x7f000000
	tst	r3, #0x40
	beq	io_write_sound4_length
	ldrb	r5, [r4, #0x20]
	and	r5, r5, #0x3f
	rsb	r5, r5, #64
	mov	r5, r5, lsl #5
	add	r5, r5, r5, lsr #2	@ (64 - t1) * 36
io_write_sound4_length:
	str	r5, [r2, #96]		@ channel4Length

	mov	r3, #0
	str	r3, [r2, #92]		@ clear main counter
	str	r3, [r2, #104]		@ and envelope counter

	mov	r3, #0xff
	orr	r3, #0x7f00
	strh	r3, [r2, #100]		@ re-initialise LFSR
	
	ldrb	r3, [r4, #0x21]		@ reset level to start of envelope
	mov	r3, r3, lsr #4
	strb	r3, [r2, #112]
	b	io_write_done


	@==================================================
	@
	@ VDP ports
	@
	@==================================================
io_write_41:
	@ port 41: VDP status: PRESERVE bits
	ldrb	r2, [r4, #0x41]
	and	r2, r2, #0xf8		@ keep top bits as written
	ldr	r3, [r0, #84]		@ get screenState
	ldrb	r5, [r3, #1]		@ get vdpMode
	orr	r2, r2, r5		@ put it in bits 0 and 1
	ldrb	r5, [r3, #0]		@ get scanline
	ldrb	r3, [r4, #0x45]		@ get scanline compare
	cmp	r3, r5
	orreq	r2, r2, #4		@ scanline co-incidence in bit 2
	strb	r2, [r4, #0x41]
	b	io_write_done
	
io_write_44:
	@ port 44: current scanline: ACTIVE
	@ writing any value resets to 0
	mov	r2, #0
	strb	r2, [r4, #0x44]
	b	io_write_done
	
io_write_46:
	@ port 46: DMA control: ACTIVE
	ldrb	r4, [r4, #0x46]		@ get value written
	mov	r4, r4, lsl #8		@ source address
	ldr	r5, [r0, #80]		@ oamRAM (destination)
	mov	r6, #0x28
dma_loop:
	READ_BYTE(r3, r4, r3, r2)	@ do DMA transfer
	add	r4, r4, #1
	strb	r3, [r5, #0]

	READ_BYTE(r3, r4, r3, r2)	@ do DMA transfer
	add	r4, r4, #1
	strb	r3, [r5, #1]

	READ_BYTE(r3, r4, r3, r2)	@ do DMA transfer
	add	r4, r4, #1
	strb	r3, [r5, #2]

	READ_BYTE(r3, r4, r3, r2)	@ do DMA transfer
	add	r4, r4, #1
	strb	r3, [r5, #3]

	add	r5, r5, #4
	subs	r6, r6, #1
	bne	dma_loop
	
	b	io_write_done

io_write_47:
	@ background palette
	ldrb	r2, [r4, #0x47]
	ldr	r3, [r0, #84]		@ screenState pointer
	add	r4, r3, #4		@ colours pointer

	and	r6, r2, #3
	ldr	r6, [r4, r6, lsl #2]
	str	r6, [r3, #20]
	
	and	r6, r2, #0xc
	ldr	r6, [r4, r6]
	str	r6, [r3, #24]

	and	r6, r2, #0x30
	ldr	r6, [r4, r6, lsr #2]
	str	r6, [r3, #28]

	and	r6, r2, #0xc0
	ldr	r6, [r4, r6, lsr #4]
	str	r6, [r3, #32]
	b	io_write_done

io_write_48:
	@ sprite palette 0
	ldrb	r2, [r4, #0x48]
	ldr	r3, [r0, #84]		@ screenState pointer
	add	r4, r3, #4		@ colours pointer

	and	r6, r2, #0xc
	ldr	r6, [r4, r6]
	str	r6, [r3, #40]

	and	r6, r2, #0x30
	ldr	r6, [r4, r6, lsr #2]
	str	r6, [r3, #44]

	and	r6, r2, #0xc0
	ldr	r6, [r4, r6, lsr #4]
	str	r6, [r3, #48]
	b	io_write_done

io_write_49:
	@ sprite palette 1
	ldrb	r2, [r4, #0x49]
	ldr	r3, [r0, #84]		@ screenState pointer
	add	r4, r3, #4		@ colours pointer

	and	r6, r2, #0xc
	ldr	r6, [r4, r6]
	str	r6, [r3, #56]

	and	r6, r2, #0x30
	ldr	r6, [r4, r6, lsr #2]
	str	r6, [r3, #60]

	and	r6, r2, #0xc0
	ldr	r6, [r4, r6, lsr #4]
	str	r6, [r3, #64]
	b	io_write_done
