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
@ Generate 2 sound samples for this scanline
@
@ Need to preserve r0, r4, r9, r10, r12
@
@ r0 - z80State
@ r1 - soundState
@ r2 - ioRAM
@ r3 - samples
@ r4, 9, 10 - preserve
@ r5, 6, 7, 8, 11 - scratch
@ r12 - screenState
@
@ FIXME: make sure channels 3 and 4 can't get into infinite loops
@        under any circumstances
@
@ This is called at 9240Hz. But actual sample update runs at 18480Hz
@

	ldr	r1, [r0, #44]		@ soundState
	ldr	r2, [r0, #88]		@ ioRAM


	mov	r3, #0x80		@ initial sample
	orr	r3, #0x800000		@ second sample

	ldrb	r12, [r2, #0x26]	@ channels playing mask
	and	r12, r12, #0x80
	
	@ main sound control
	ldrb	r5, [r2, #0x26]
	tst	r5, #0x80
	beq	skip_sound

@======================================================================
@
@ Channel 1
@
@======================================================================
	mov	r3, #0
	@ update channel 1
	
	ldr	r5, [r1, #16]		@ Length remaining
	cmp	r5, #0
	beq	channel1_skip
	sub	r5, r5, #1
	str	r5, [r1, #16]

	@ update r26 with sound status!
	orr	r12, r12, #1
	
	@ update envelope to get level
	ldrb	r5, [r1, #40]		@ Level
	ldr	r6, [r1, #32]		@ EnvCounter
	ldr	r7, [r1, #36]		@ EnvThreshold
	cmp	r7, #0
	beq	channel1_skip_envelope
	add	r6, r6, #1
	cmp	r6, r7
	blt	channel1_skip_envelope
	sub	r6, r6, r7		@ reset EnvCounter
	ldrsb	r7, [r1, #41]		@ LevelStep
	add	r5, r5, r7
	cmp	r5, #0
	movlt	r5, #0
	cmp	r5, #15
	movgt	r5, #15
	strb	r5, [r1, #40]		@ store updated level
channel1_skip_envelope:	
	str	r6, [r1, #32]		@ store env counter

	@ now got level in r5
	@ update frequency sweep

	ldr	r6, [r1, #4]		@ Freq

	ldr	r7, [r1, #20]		@ SweepCounter
	ldr	r8, [r1, #24]		@ SweepThreshold
	cmp	r8, #0
	beq	channel1_skip_sweep	@ threshold of 0 means sweep is off
	
	add	r7, r7, #1
	str	r7, [r1, #20]		@ store SweepCounter
	cmp	r7, r8
	blt	channel1_skip_sweep
	sub	r7, r7, r8		@ reset SweepCounter
	str	r7, [r1, #20]		@ store SweepCounter

#if 0
	ldr	r11, [r1, #12]		@ threshold

	ldrb	r7, [r1, #28]		@ sweep type
	ands	r7, r7, #7
	moveq	r8, #0
	moveq	r11, #0
	cmp	r7, #1
	moveq	r8, r6, lsr #1
	moveq	r11, r11, lsr #1
	cmp	r7, #2
	moveq	r8, r6, lsr #2
	moveq	r11, r11, lsr #2
	cmp	r7, #3
	moveq	r8, r6, lsr #3
	moveq	r11, r11, lsr #3
	cmp	r7, #4
	moveq	r8, r6, lsr #4
	moveq	r11, r11, lsr #4
	cmp	r7, #5
	moveq	r8, r6, lsr #5
	moveq	r11, r11, lsr #5
	cmp	r7, #6
	moveq	r8, r6, lsr #6
	moveq	r11, r11, lsr #6
	cmp	r7, #7
	moveq	r8, r6, lsr #7
	moveq	r11, r11, lsr #7

	ldrb	r7, [r1, #28]
	tst	r7, #8
	beq	sweep_increase_freq

	ldr	r7, [r1, #12]
	add	r7, r7, r11, lsl #3
	str	r7, [r1, #12]
	
	add	r6, r6, r8, lsl #3
	str	r6, [r1, #4]
	b	channel1_skip_sweep
sweep_increase_freq:
	ldr	r7, [r1, #12]
	sub	r7, r7, r11, lsl #3
	str	r7, [r1, #12]
	
	cmp	r6, r8
	subge	r6, r6, r8, lsl #3
	str	r6, [r1, #4]
#endif	

	ldrb	r8, [r2, #0x13]		@ low freq
	ldrb	r7, [r2, #0x14]		@ high freq
	orr	r8, r8, r7, lsl #8
	bic	r8, r8, #0xf800		@ construct whole freq
	ldrb	r7, [r1, #28]		@ sweep type
	@cmp	r7, #0
	@addeq	r8, r8, r8
	cmp	r7, #1
	addeq	r8, r8, r8, lsr #1
	cmp	r7, #2
	addeq	r8, r8, r8, lsr #2
	cmp	r7, #3
	addeq	r8, r8, r8, lsr #3
	cmp	r7, #4
	addeq	r8, r8, r8, lsr #4
	cmp	r7, #5
	addeq	r8, r8, r8, lsr #5
	cmp	r7, #6
	addeq	r8, r8, r8, lsr #6
	cmp	r7, #7
	addeq	r8, r8, r8, lsr #7

	@cmp	r7, #8
	@subeq	r8, r8, r8
	cmp	r7, #9
	subeq	r8, r8, r8, lsr #1
	cmp	r7, #10
	subeq	r8, r8, r8, lsr #2
	cmp	r7, #11
	subeq	r8, r8, r8, lsr #3
	cmp	r7, #12
	subeq	r8, r8, r8, lsr #4
	cmp	r7, #13
	subeq	r8, r8, r8, lsr #5
	cmp	r7, #14
	subeq	r8, r8, r8, lsr #6
	cmp	r7, #15
	subeq	r8, r8, r8, lsr #7

	bic	r8, #0xff000000
	bic	r8, #0x00ff0000
	bic	r8, #0x0000f800
	
	@ store back in reg 13 and 14
	strb	r8, [r2, #0x13]
	ldrb	r7, [r2, #0x14]
	and	r7, r7, #0xf8
	orr	r7, r7, r8, lsr #8
	strb	r7, [r2, #0x14]
	
	@ copy actual freq to r6
	rsb	r6, r8, #2048
	mov	r6, r6, lsl #5			@ 2048-freq
	add	r6, r6, r6, lsr #3		@ *36

	sub	r6, r6, r6, lsr #5	@ TUNING
	

	@ determine new threshold from duty cycle
	ldrb	r7, [r2, #0x11]			@ read duty/length
	ands	r7, r7, #0xc0
	moveq	r8, r6, lsr #3
	cmp	r7, #0x40
	moveq	r8, r6, lsr #2
	cmp	r7, #0x80
	moveq	r8, r6, lsr #1
	cmp	r6, #0xc0
	moveq	r8, r6, lsr #1
	addeq	r8, r8, r8, lsr #1
	str	r8, [r1, #12]			@ store duty threshold

	@mov	r8, #0
	@str	r8, [r1, #8]
	
	@ and store in soundState for later
	str	r6, [r1, #4]

	
channel1_skip_sweep:

	@ now got level in r5 and frequency in r6
	ldr	r7, [r1, #8]		@ Counter
	ldr	r8, [r1, #12]		@ Threshold
	add	r7, r7, #256
	cmp	r7, r6
	subge	r7, r7, r6		@ subtract freq if gone over
	cmp	r7, r8			@ test against Threshold
	addge	r3, r3, r5
	sublt	r3, r3, r5

	@ do second sample
	add	r7, r7, #256
	cmp	r7, r6
	subge	r7, r7, r6
	cmp	r7, r8
	addge	r3, r3, r5, lsl #16
	sublt	r3, r3, r5, lsl #16

	str	r7, [r1, #8]		@ store updated Counter

channel1_skip:
	str	r3, [r1, #120]

@======================================================================
@
@ Channel 2
@
@======================================================================
	mov	r3, #0
	@
	@ Update channel 2
	@
	ldr	r5, [r1, #56]		@ channel2Length
	cmp	r5, #0
	beq	channel2_skip
	sub	r5, r5, #1
	str	r5, [r1, #56]

	@ update r26 with sound status!
	orr	r12, r12, #2
	
	@ update envelope to get level
	ldrb	r5, [r1, #68]		@ channel2Level
	ldr	r6, [r1, #60]		@ env counter
	ldr	r7, [r1, #64]		@ env threshold
	cmp	r7, #0
	beq	channel2_skip_envelope
	add	r6, r6, #1
	cmp	r6, r7
	blt	channel2_skip_envelope
	sub	r6, r6, r7		@ reset env counter
	ldrsb	r7, [r1, #69]		@ level step
	add	r5, r5, r7
	cmp	r5, #0
	movlt	r5, #0
	cmp	r5, #15
	movgt	r5, #15
	strb	r5, [r1, #68]		@ store updated level
channel2_skip_envelope:
	str	r6, [r1, #60]		@ store env counter

	ldr	r6, [r1, #44]

	@ now got level in r5, freq in r6
	ldr	r7, [r1, #48]		@ counter
	ldr	r8, [r1, #52]		@ threshold
	add	r7, r7, #256
	cmp	r7, r6
	subge	r7, r7, r6		@ subtract freq if gone over
	cmp	r7, r8			@ test against threshold
	addge	r3, r3, r5
	sublt	r3, r3, r5

	@ do second sample
	add	r7, r7, #256
	cmp	r7, r6
	subge	r7, r7, r6
	cmp	r7, r8
	addge	r3, r3, r5, lsl #16
	sublt	r3, r3, r5, lsl #16

	str	r7, [r1, #48]		@ store updated Counter

channel2_skip:	
	str	r3, [r1, #124]

@======================================================================
@
@ Channel 3
@
@======================================================================
	mov	r3, #0

	ldrb	r5, [r2, #0x1a]
	tst	r5, #0x80
	beq	channel3_skip

	@ channel 3 is playing

	ldr	r5, [r1, #80]		@ Length remaining
	cmp	r5, #0
	beq	channel3_skip
	sub	r5, r5, #1
	str	r5, [r1, #80]

	mov	r3, #0xf0

	@ update r26 with sound status!
	orr	r12, r12, #4
	
	ldr	r5, [r1, #72]		@ channel 3 frequency

	ldr	r6, [r1, #76]		@ channel 3 counter
	ldrb	r8, [r1, #84]		@ channel 3 current sample
	add	r6, r6, #256
channel3_loop1:	
	cmp	r6, r5
	blt	channel3_no_overflow1
	sub	r6, r6, r5
	add	r8, r8, #1		@ onto next sample
	and	r8, r8, #31
	b	channel3_loop1
channel3_no_overflow1:
	add	r11, r2, #0x30		@ point to sample RAM
	ldrb	r11, [r11, r8, lsr #1]	@ read sample
	tst	r8, #1
	moveq	r11, r11, lsr #4
	and	r11, r11, #0xf		@ we have the sample
	
	ldrb	r5, [r2, #0x1c]		@ read output level
	ands	r5, r5, #0x60
	moveq	r11, #0
	moveq	r3, #0
	cmp	r5, #0x40
	moveq	r11, r11, lsr #1	@ adjust sample accordingly
	moveq	r3, #0xf8
	cmp	r5, #0x60
	moveq	r11, r11, lsr #2
	moveq	r3, #0xfc

	add	r3, r3, r11, lsl #1	@ add it to output

	@ now do 2nd sample
	ldr	r5, [r1, #72]		@ reload frequency
	orr	r3, r3, #0xf00000

	add	r6, r6, #256
channel3_loop2:	
	cmp	r6, r5
	blt	channel3_no_overflow2
	sub	r6, r6, r5
	add	r8, r8, #1		@ onto next sample
	and	r8, r8, #31
	b	channel3_loop2
channel3_no_overflow2:
	add	r11, r2, #0x30		@ point to sample RAM
	ldrb	r11, [r11, r8, lsr #1]	@ read sample
	tst	r8, #1
	moveq	r11, r11, lsr #4
	and	r11, r11, #0xf		@ we have the sample
	
	ldrb	r5, [r2, #0x1c]		@ read output level
	ands	r5, r5, #0x60
	moveq	r11, #0
	biceq	r3, r3, #0xff0000
	cmp	r5, #0x40
	moveq	r11, r11, lsr #1	@ adjust sample accordingly
	orreq	r3, r3, #0xf80000
	cmp	r5, #0x60
	moveq	r11, r11, lsr #2
	orreq	r3, r3, #0xfc0000

	add	r3, r3, r11, lsl #17	@ add it to output

	str	r6, [r1, #76]		@ store counter again
	strb	r8, [r1, #84]		@ store current sample

channel3_skip:
	str	r3, [r1, #128]
	
@======================================================================
@
@ Channel 4
@
@======================================================================
	mov	r3, #0
	ldr	r5, [r1, #96]		@ channel4Length
	cmp	r5, #0
	beq	channel4_skip
	sub	r5, r5, #1
	str	r5, [r1, #96]

	@ update r26 with sound status!
	orr	r12, r12, #8
	
	@ update envelope to get level
	ldrb	r5, [r1, #112]		@ level
	ldr	r6, [r1, #104]		@ env counter
	ldr	r7, [r1, #108]		@ threshold
	cmp	r7, #0
	beq	channel4_skip_envelope
	add	r6, r6, #1
	cmp	r6, r7
	blt	channel4_skip_envelope
	sub	r6, r6, r7		@ reset counter
	ldrsb	r7, [r1, #116]		@ level step
	add	r5, r5, r7
	cmp	r5, #0
	movlt	r5, #0
	cmp	r5, #15
	movgt	r5, #15
	strb	r5, [r1, #112]		@ store updated level
channel4_skip_envelope:
	str	r6, [r1, #104]		@ store env counter

	@ level now in r5
	ldr	r6, [r1, #88]		@ freq
	ldr	r7, [r1, #92]		@ counter
	ldrh	r8, [r1, #100]		@ LFSR
	add	r7, r7, #256
channel4_loop1:	
	cmp	r7, r6
	blt	channel4_done1
	sub	r7, r7, r6		@ subtract frequency

	@ update the LFSR!
	ldrb	r11, [r2, #0x22]
	tst	r11, #8
	and	r11, r8, #1
	eor	r11, r11, r8, lsr #1
	and	r11, r11, #1		@ get new bit for left side
	bne	channel4_7bit1

	@ 15-bit LFSR
	mov	r8, r8, lsr #1
	bic	r8, r8, #0xc000
	orr	r8, r8, r11, lsl #14
	strh	r8, [r1, #100]
	b	channel4_loop1
channel4_7bit1:
	@ 7-bit LFSR
	mov	r8, r8, lsr #1
	and	r8, r8, #0x3f
	orr	r8, r8, r11, lsl #6
	strh	r8, [r1, #100]
	b	channel4_loop1
channel4_done1:	

	tst	r8, #1
	addne	r3, r3, r5
	subeq	r3, r3, r5

	@ do second sample
	add	r7, r7, #256
channel4_loop2:	
	cmp	r7, r6
	blt	channel4_done2
	sub	r7, r7, r6		@ subtract frequency

	@ update the LFSR!
	ldrb	r11, [r2, #0x22]
	tst	r11, #8
	and	r11, r8, #1
	eor	r11, r11, r8, lsr #1
	and	r11, r11, #1		@ get new bit for left side
	bne	channel4_7bit2

	@ 15-bit LFSR
	mov	r8, r8, lsr #1
	bic	r8, r8, #0xc000
	orr	r8, r8, r11, lsl #14
	strh	r8, [r1, #100]
	b	channel4_loop2
channel4_7bit2:
	@ 7-bit LFSR
	mov	r8, r8, lsr #1
	and	r8, r8, #0x3f
	orr	r8, r8, r11, lsl #6
	strh	r8, [r1, #100]
	b	channel4_loop2
channel4_done2:	

	str	r7, [r1, #92]		@ store updated counter
	
	tst	r8, #1
	addne	r3, r3, r5, lsl #16
	subeq	r3, r3, r5, lsl #16

channel4_skip:
	str	r3, [r1, #132]

skip_sound:
	strb	r12, [r2, #0x26]	@ store channels playing mask
	
	ldr	r12, [r0, #84]		@ get back screenState

	ldr	r5, [r1, #0]		@ soundBuffer
	ldrb	r6, [r12, #0]		@ scanline

	@
	@ registers for mixing:
	@  r0 - z80State
	@  r1 - soundState
	@  r2 - ioRAM
	@  r3 - channel 1 sample
	@  r5 - sound buffer
	@  r6 - scanline
	@  r7 - channel 2 sample
	@  r8 - scratch
	@  r11 - mixer byte
	@  r12 - screenState
	@

	@ initialise samples
	@mov	r3, #0x80
	@orr	r3, r3, r3, lsl #16
	@mov	r7, r3
	mov	r3, #0
	mov	r7, #0

	ldrb	r11, [r2, #0x25]	@ get mixer byte

	@ mix channel 1
	ldr	r8, [r1, #120]
	tst	r11, #1
	addne	r3, r3, r8
	tst	r11, #0x10
	addne	r7, r7, r8
	
	@ mix channel 2
	ldr	r8, [r1, #124]
	tst	r11, #2
	addne	r3, r3, r8
	tst	r11, #0x20
	addne	r7, r7, r8
	
	@ mix channel 3
	ldr	r8, [r1, #128]
	tst	r11, #4
	addne	r3, r3, r8
	tst	r11, #0x40
	addne	r7, r7, r8
	
	@ mix channel 4
	ldr	r8, [r1, #132]
	tst	r11, #8
	addne	r3, r3, r8
	tst	r11, #0x80
	addne	r7, r7, r8

	ldrb	r8, [r2, #0x24]		@ get volume levels
	and	r8, r8, #0x77
	rsb	r8, r8, #0x77
	mov	r11, r8, lsr #4
	and	r8, r8, #0x7

	@ sign-extend the samples
	bic	r3, r3, #0xff00
	bic	r3, r3, #0xff000000
	bic	r7, r7, #0xff00
	bic	r7, r7, #0xff000000

	tst	r3, #0x80
	orrne	r3, r3, #0xff00
	tst	r3, #0x800000
	orrne	r3, r3, #0xff000000
	tst	r7, #0x80
	orrne	r7, r7, #0xff00
	tst	r7, #0x800000
	orrne	r7, r7, #0xff000000

	@ adjust for overall volumes
	lsr	r3, r3, r8
	lsr	r7, r7, r11

	@ add offset of 0x80 for unsigned 8-bit samples
	mov	r8, #0x80
	orr	r8, r8, r8, lsl #16
	add	r3, r3, r8
	add	r7, r7, r8
	
	strb	r3, [r5, r6, lsl #2]	@ store first left sample
	add	r5, r5, #1
	strb	r7, [r5, r6, lsl #2]	@ store first right sample
	add	r5, r5, #1
	
	mov	r3, r3, lsr #16
	mov	r7, r7, lsr #16
	strb	r3, [r5, r6, lsl #2]	@ store second left sample
	add	r5, r5, #1
	strb	r7, [r5, r6, lsl #2]	@ store second right sample

	