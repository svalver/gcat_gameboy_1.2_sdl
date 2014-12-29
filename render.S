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
@ Render a single scanline
@
@ On entry: r0 points to z80State
@           r12 points to screenState
@ Must preserve r0, r4, r9, r10, r12
@
@ r0 - z80State
@ r1 - output buffer
@ r2 - scanline number
@
@ r5 - oamRAM/ioRAM pointer
@
@ r12 - screenState
@
@ FIXME: can probably optimise the renderers by combining one of the
@ bit-shifts into the 'ldr'.
@
	push	{r4, r9, r10}

	@ get our output buffer address in r1
	ldr	r1, [r12, #72]		@ screenBuffer
	ldrb	r2, [r12, #0]		@ scanline
	add	r1, r1, r2, lsl #10	@ 1K per line

	@ store horizontal scroll for later
	ldr	r5, [r0, #80]		@ oamRAM and ioRAM
	
	ldrb	r3, [r5, #0x143]	@ h scroll
	ldr	r4, [r12, #68]		@ lineScrolls
	strb	r3, [r4, r2]

	@ fill line with background colour 0
	ldr	r3, [r12, #20]		@ bgPalette[0]
	mov	r4, #8
render_fill_loop:
	str	r3, [r1, r4, lsl #2]
	add	r4, r4, #1
	cmp	r4, #176
	blt	render_fill_loop

	ldrb	r3, [r5, #0x140]	@ LCD control
	tst	r3, #0x80		@ test screen enable
	beq	render_skip_all

	mov	r6, #0

	@ draw sprites that go behind background
	tst	r3, #2			@ are sprites on?
	beq	render_skip_sprites1
	@b	render_skip_sprites1

	@ calculate sprite height
	tst	r3, #4
	mov	r3, #8
	movne	r3, #16
	
	@ sprite loop
	mov	r4, #0			@ loop counter
render_sprite_loop1:

	@ check 10 sprites on line
	cmp	r6, #10
	bge	render_skip_sprites1
	
	ldr	r7, [r5, r4, lsl #2]	@ read all sprite data
	tst	r7, #0x80000000
	beq	render_skip_sprite1	@ skip if in front of background

	and	r8, r7, #0xff		@ get sprite Y
	sub	r8, r8, #16
	cmp	r8, r2
	bgt	render_skip_sprite1
	add	r9, r8, r3
	cmp	r9, r2
	ble	render_skip_sprite1

	@ sprite is on this line
	@ increase sprites on line counter
	add	r6, r6, #1
	
	mov	r9, r7, lsr #8
	and	r9, r9, #0xff		@ get sprite X
	cmp	r9, #0
	beq	render_skip_sprite1
	cmp	r9, #168
	bge	render_skip_sprite1

	@ add low scroll and buffer pointer to x (r9)
	ldrb	r10, [r5, #0x143]
	and	r10, r10, #7
	add	r9, r9, r10
	add	r9, r1, r9, lsl #2
	
	@ get tile (<< 4) and adjust for big sprites
	mov	r10, r7, lsr #12
	and	r10, r10, #0xff0
	cmp	r3, #16
	andeq	r10, r10, #0xfe0

	@ get row within sprite
	sub	r8, r2, r8
	tst	r7, #0x40000000		@ flip vertical?
	subne	r8, r3, r8
	subne	r8, r8, #1

	@ read 2 bytes of pattern data
	add	r10, r10, r8, lsl #1	@ tile row address
	ldr	r8, [r12, #76]		@ video RAM
	ldrh	r8, [r8, r10]		@ read bytes
	
	@ get palette pointer
	add	r10, r12, #36
	tst	r7, #0x10000000
	addne	r10, r10, #16

	@ for actual sprite rendering we need:
	@  - two bytes of pattern data (r8)
	@  - buffer pointer (r9)
	@  - palette pointer (r10)
	@  - registers for col, scratch (r7, r11)
	@ need to preserve r0-r6 + r12
	tst	r7, #0x20000000
	bne	render_sprite_mirror1

	and	r7, r8, #0x80
	and	r11, r8, #0x8000
	mov	r7, r7, lsr #7
	orrs	r7, r7, r11, lsr #14
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9]
	
	and	r7, r8, #0x40
	and	r11, r8, #0x4000
	mov	r7, r7, lsr #6
	orrs	r7, r7, r11, lsr #13
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #4]
	
	and	r7, r8, #0x20
	and	r11, r8, #0x2000
	mov	r7, r7, lsr #5
	orrs	r7, r7, r11, lsr #12
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #8]
	
	and	r7, r8, #0x10
	and	r11, r8, #0x1000
	mov	r7, r7, lsr #4
	orrs	r7, r7, r11, lsr #11
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #12]
	
	and	r7, r8, #0x8
	and	r11, r8, #0x800
	mov	r7, r7, lsr #3
	orrs	r7, r7, r11, lsr #10
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #16]
	
	and	r7, r8, #0x4
	and	r11, r8, #0x400
	mov	r7, r7, lsr #2
	orrs	r7, r7, r11, lsr #9
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #20]
	
	and	r7, r8, #0x2
	and	r11, r8, #0x200
	mov	r7, r7, lsr #1
	orrs	r7, r7, r11, lsr #8
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #24]
	
	and	r7, r8, #0x1
	and	r11, r8, #0x100
	orrs	r7, r7, r11, lsr #7
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #28]
		
	b	render_skip_sprite1
render_sprite_mirror1:	

	and	r7, r8, #0x80
	and	r11, r8, #0x8000
	mov	r7, r7, lsr #7
	orrs	r7, r7, r11, lsr #14
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #28]
	
	and	r7, r8, #0x40
	and	r11, r8, #0x4000
	mov	r7, r7, lsr #6
	orrs	r7, r7, r11, lsr #13
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #24]
	
	and	r7, r8, #0x20
	and	r11, r8, #0x2000
	mov	r7, r7, lsr #5
	orrs	r7, r7, r11, lsr #12
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #20]
	
	and	r7, r8, #0x10
	and	r11, r8, #0x1000
	mov	r7, r7, lsr #4
	orrs	r7, r7, r11, lsr #11
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #16]
	
	and	r7, r8, #0x8
	and	r11, r8, #0x800
	mov	r7, r7, lsr #3
	orrs	r7, r7, r11, lsr #10
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #12]
	
	and	r7, r8, #0x4
	and	r11, r8, #0x400
	mov	r7, r7, lsr #2
	orrs	r7, r7, r11, lsr #9
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #8]
	
	and	r7, r8, #0x2
	and	r11, r8, #0x200
	mov	r7, r7, lsr #1
	orrs	r7, r7, r11, lsr #8
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #4]
	
	and	r7, r8, #0x1
	and	r11, r8, #0x100
	orrs	r7, r7, r11, lsr #7
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9]
		
render_skip_sprite1:
	add	r4, r4, #1
	cmp	r4, #40
	bne	render_sprite_loop1
	
render_skip_sprites1:
	@ store sprites on line counter for second loop
	strb	r6, [r12, #2]

	ldrb	r3, [r5, #0x140]		@ LCD control
	tst	r3, #1
	beq	render_skip_background

	@ get tilemap base address in r6
	mov	r6, #0x1800
	tst	r3, #8
	addne	r6, r6, #0x400
	
	@ check which tileset
	and	r3, r3, #0x10
	eor	r3, r3, #0x10
	mov	r3, r3, lsl #4

	@ calculate tilemap start address
	ldrb	r4, [r5, #0x142]		@ vertical scroll
	add	r4, r4, r2			@ line
	and	r7, r4, #7
	mov	r7, r7, lsl #1			@ get row within tile
	
	and	r4, r4, #0xf8
	add	r6, r6, r4, lsl #2

	@ setup for loop
	ldrb	r8, [r5, #0x143]
	mov	r8, r8, lsr #3			@ initial column

	ldr	r2, [r12, #76]
	add	r6, r6, r2			@ VRAM base

	add	r1, r1, #32			@ where to render to

	add	r5, r12, #20			@ palette
	
	@ loop over 21 tiles
	@
	@ Registers:
	@  - r0 - z80State
	@  - r1 - destination buffer
	@  - r2 - VRAM base
	@  - r3 - tileset offset
	@  - r4 - loop counter
	@  - r5 - palette pointer
	@  - r6 - tilemap base
	@  - r7 - row within tile
	@  - r8 - column
	@  - r9 - pattern data
	@  - r10 -
	@  - r11 -
	@  - r12 - screenState
	mov	r4, #21
render_background_loop:	

	@ lookup in tile map
	ldrb	r9, [r6, r8]
	add	r8, r8, #1		@ increment column
	and	r8, r8, #31

	cmp	r9, #128
	addlt	r9, r9, r3		@ add offset if necessary

	@ read pattern data
	add	r9, r7, r9, lsl #4
	ldrh	r9, [r2, r9]		@ read both bytes of pattern

	@ render!
	@ for rendering, need:
	@  - two bytes of pattern data (r9)
	@  - buffer pointer (r1)
	@  - palette pointer (r5)
	@  - registers for col, scratch (r10, r11)
	and	r10, r9, #0x80
	and	r11, r9, #0x8000
	mov	r10, r10, lsr #7
	orrs	r10, r10, r11, lsr #14
	ldr	r10, [r5, r10, lsl #2]
	strne	r10, [r1]

	and	r10, r9, #0x40
	and	r11, r9, #0x4000
	mov	r10, r10, lsr #6
	orrs	r10, r10, r11, lsr #13
	ldr	r10, [r5, r10, lsl #2]
	strne	r10, [r1, #4]

	and	r10, r9, #0x20
	and	r11, r9, #0x2000
	mov	r10, r10, lsr #5
	orrs	r10, r10, r11, lsr #12
	ldr	r10, [r5, r10, lsl #2]
	strne	r10, [r1, #8]

	and	r10, r9, #0x10
	and	r11, r9, #0x1000
	mov	r10, r10, lsr #4
	orrs	r10, r10, r11, lsr #11
	ldr	r10, [r5, r10, lsl #2]
	strne	r10, [r1, #12]

	and	r10, r9, #0x8
	and	r11, r9, #0x800
	mov	r10, r10, lsr #3
	orrs	r10, r10, r11, lsr #10
	ldr	r10, [r5, r10, lsl #2]
	strne	r10, [r1, #16]

	and	r10, r9, #0x4
	and	r11, r9, #0x400
	mov	r10, r10, lsr #2
	orrs	r10, r10, r11, lsr #9
	ldr	r10, [r5, r10, lsl #2]
	strne	r10, [r1, #20]

	and	r10, r9, #0x2
	and	r11, r9, #0x200
	mov	r10, r10, lsr #1
	orrs	r10, r10, r11, lsr #8
	ldr	r10, [r5, r10, lsl #2]
	strne	r10, [r1, #24]

	and	r10, r9, #0x1
	and	r11, r9, #0x100
	orrs	r10, r10, r11, lsr #7
	ldr	r10, [r5, r10, lsl #2]
	strne	r10, [r1, #28]
	
	@ loop back
	add	r1, r1, #32
	subs	r4, r4, #1
	bne	render_background_loop

	@ get back r1, r2 and r5
	sub	r1, r1, #704
	ldrb	r2, [r12, #0]
	ldr	r5, [r0, #80]
	
render_skip_background:

	ldrb	r3, [r5, #0x140]		@ LCD control
	tst	r3, #0x20
	beq	render_skip_window
	
	@ get position and check if it's on screen
	ldrb	r4, [r5, #0x14a]		@ window Y
	ldrb	r6, [r5, #0x14b]		@ window X
	cmp	r6, #167
	bge	render_skip_window
	cmp	r4, #144
	bge	render_skip_window
	cmp	r4, r2
	bgt	render_skip_window

	@ work out row, starting x, and width
	sub	r4, r2, r4			@ row
	ldrb	r7, [r5, #0x143]		@ x scroll
	and	r7, r7, #7
	add	r6, r6, r7
	add	r6, r6, #1			@ r6 is starting x
	rsb	r7, r6, #176
	mov	r7, r7, lsr #3			@ r7 is width

	@ work out tilemap
	mov	r8, #0x1800
	tst	r3, #0x40
	addne	r8, r8, #0x400

	@ check which tileset
	and	r3, r3, #0x10
	eor	r3, r3, #0x10
	mov	r3, r3, lsl #4

	@ work out row within tile, and tilemap address
	@ (row in r4 just now)
	and	r9, r4, #7
	mov	r9, r9, lsl #1
	and	r4, r4, #0xf8
	add	r8, r8, r4, lsl #2		@ tilemap source

	ldr	r2, [r12, #76]			@ VRAM
	add	r8, r8, r2

	add	r5, r12, #20			@ palette
	
	@ loop over window visible width
	@
	@ r0 - z80State
	@ r1 - buffer
	@ r2 - VRAM
	@ r3 - tileset offset
	@ r4 -
	@ r5 - palette
	@ r6 - column
	@ r7 - loop counter
	@ r8 - tilemap address
	@ r9 - row within tile
	@ r10 -
	@ r11 -
	@ r12 - screenState
	@
render_window_loop:	

	@ fetch a tile. translate according to tileset
	ldrb	r4, [r8], #1
	cmp	r4, #128
	addlt	r4, r4, r3		@ add offset if necessary
	
	@ read pattern data
	add	r4, r9, r4, lsl #4
	ldrh	r4, [r2, r4]		@ read both pattern bytes

	@ render!
	@ for rendering, need:
	@  - two bytes of pattern data (r4)
	@  - buffer pointer (r1, r6)
	@  - palette pointer (r5)
	@  - registers for col, scratch (r10, r11)
	and	r10, r4, #0x80
	and	r11, r4, #0x8000
	mov	r10, r10, lsr #7
	orrs	r10, r10, r11, lsr #14
	ldr	r10, [r5, r10, lsl #2]
	str	r10, [r1, r6, lsl #2]
	add	r6, r6, #1

	and	r10, r4, #0x40
	and	r11, r4, #0x4000
	mov	r10, r10, lsr #6
	orrs	r10, r10, r11, lsr #13
	ldr	r10, [r5, r10, lsl #2]
	str	r10, [r1, r6, lsl #2]
	add	r6, r6, #1

	and	r10, r4, #0x20
	and	r11, r4, #0x2000
	mov	r10, r10, lsr #5
	orrs	r10, r10, r11, lsr #12
	ldr	r10, [r5, r10, lsl #2]
	str	r10, [r1, r6, lsl #2]
	add	r6, r6, #1

	and	r10, r4, #0x10
	and	r11, r4, #0x1000
	mov	r10, r10, lsr #4
	orrs	r10, r10, r11, lsr #11
	ldr	r10, [r5, r10, lsl #2]
	str	r10, [r1, r6, lsl #2]
	add	r6, r6, #1

	and	r10, r4, #0x8
	and	r11, r4, #0x800
	mov	r10, r10, lsr #3
	orrs	r10, r10, r11, lsr #10
	ldr	r10, [r5, r10, lsl #2]
	str	r10, [r1, r6, lsl #2]
	add	r6, r6, #1

	and	r10, r4, #0x4
	and	r11, r4, #0x400
	mov	r10, r10, lsr #2
	orrs	r10, r10, r11, lsr #9
	ldr	r10, [r5, r10, lsl #2]
	str	r10, [r1, r6, lsl #2]
	add	r6, r6, #1

	and	r10, r4, #0x2
	and	r11, r4, #0x200
	mov	r10, r10, lsr #1
	orrs	r10, r10, r11, lsr #8
	ldr	r10, [r5, r10, lsl #2]
	str	r10, [r1, r6, lsl #2]
	add	r6, r6, #1

	and	r10, r4, #0x1
	and	r11, r4, #0x100
	orrs	r10, r10, r11, lsr #7
	ldr	r10, [r5, r10, lsl #2]
	str	r10, [r1, r6, lsl #2]
	add	r6, r6, #1	

	subs	r7, r7, #1
	bne	render_window_loop
	
	ldrb	r2, [r12, #0]
	ldr	r5, [r0, #80]

	ldrb	r3, [r5, #0x140]
render_skip_window:
	
	@ now draw sprites that are on top of background
	tst	r3, #2			@ are sprites on?
	beq	render_skip_sprites2

	@ calculate sprite height
	tst	r3, #4
	mov	r3, #8
	movne	r3, #16
	
	@ sprite loop
	mov	r4, #0			@ loop counter
	ldrb	r6, [r12, #2]		@ sprites on line count
render_sprite_loop2:

	@ check 10 sprites on line
	cmp	r6, #10
	bge	render_skip_sprites2
	
	ldr	r7, [r5, r4, lsl #2]	@ read all sprite data
	tst	r7, #0x80000000
	bne	render_skip_sprite2	@ skip if behind background

	and	r8, r7, #0xff		@ get sprite Y
	sub	r8, r8, #16
	cmp	r8, r2
	bgt	render_skip_sprite2
	add	r9, r8, r3
	cmp	r9, r2
	ble	render_skip_sprite2

	@ sprite is on this line
	@ increase sprites on line counter
	add	r6, r6, #1
	
	mov	r9, r7, lsr #8
	and	r9, r9, #0xff		@ get sprite X
	cmp	r9, #0
	beq	render_skip_sprite2
	cmp	r9, #168
	bge	render_skip_sprite2

	@ add low scroll and buffer pointer to x (r9)
	ldrb	r10, [r5, #0x143]
	and	r10, r10, #7
	add	r9, r9, r10
	add	r9, r1, r9, lsl #2
	
	@ get tile (<< 4) and adjust for big sprites
	mov	r10, r7, lsr #12
	and	r10, r10, #0xff0
	cmp	r3, #16
	andeq	r10, r10, #0xfe0

	@ get row within sprite
	sub	r8, r2, r8
	tst	r7, #0x40000000		@ flip vertical?
	subne	r8, r3, r8
	subne	r8, r8, #1

	@ read 2 bytes of pattern data
	add	r10, r10, r8, lsl #1	@ tile row address
	ldr	r8, [r12, #76]		@ video RAM
	ldrh	r8, [r8, r10]		@ read bytes
	
	@ get palette pointer
	add	r10, r12, #36
	tst	r7, #0x10000000
	addne	r10, r10, #16

	@ for actual sprite rendering we need:
	@  - two bytes of pattern data (r8)
	@  - buffer pointer (r9)
	@  - palette pointer (r10)
	@  - registers for col, scratch (r7, r11)
	@ need to preserve r0-r6 + r12
	tst	r7, #0x20000000
	bne	render_sprite_mirror2

	and	r7, r8, #0x80
	and	r11, r8, #0x8000
	mov	r7, r7, lsr #7
	orrs	r7, r7, r11, lsr #14
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9]
	
	and	r7, r8, #0x40
	and	r11, r8, #0x4000
	mov	r7, r7, lsr #6
	orrs	r7, r7, r11, lsr #13
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #4]
	
	and	r7, r8, #0x20
	and	r11, r8, #0x2000
	mov	r7, r7, lsr #5
	orrs	r7, r7, r11, lsr #12
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #8]
	
	and	r7, r8, #0x10
	and	r11, r8, #0x1000
	mov	r7, r7, lsr #4
	orrs	r7, r7, r11, lsr #11
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #12]
	
	and	r7, r8, #0x8
	and	r11, r8, #0x800
	mov	r7, r7, lsr #3
	orrs	r7, r7, r11, lsr #10
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #16]
	
	and	r7, r8, #0x4
	and	r11, r8, #0x400
	mov	r7, r7, lsr #2
	orrs	r7, r7, r11, lsr #9
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #20]
	
	and	r7, r8, #0x2
	and	r11, r8, #0x200
	mov	r7, r7, lsr #1
	orrs	r7, r7, r11, lsr #8
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #24]
	
	and	r7, r8, #0x1
	and	r11, r8, #0x100
	orrs	r7, r7, r11, lsr #7
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #28]
		
	b	render_skip_sprite2
render_sprite_mirror2:	

	and	r7, r8, #0x80
	and	r11, r8, #0x8000
	mov	r7, r7, lsr #7
	orrs	r7, r7, r11, lsr #14
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #28]
	
	and	r7, r8, #0x40
	and	r11, r8, #0x4000
	mov	r7, r7, lsr #6
	orrs	r7, r7, r11, lsr #13
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #24]
	
	and	r7, r8, #0x20
	and	r11, r8, #0x2000
	mov	r7, r7, lsr #5
	orrs	r7, r7, r11, lsr #12
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #20]
	
	and	r7, r8, #0x10
	and	r11, r8, #0x1000
	mov	r7, r7, lsr #4
	orrs	r7, r7, r11, lsr #11
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #16]
	
	and	r7, r8, #0x8
	and	r11, r8, #0x800
	mov	r7, r7, lsr #3
	orrs	r7, r7, r11, lsr #10
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #12]
	
	and	r7, r8, #0x4
	and	r11, r8, #0x400
	mov	r7, r7, lsr #2
	orrs	r7, r7, r11, lsr #9
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #8]
	
	and	r7, r8, #0x2
	and	r11, r8, #0x200
	mov	r7, r7, lsr #1
	orrs	r7, r7, r11, lsr #8
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9, #4]
	
	and	r7, r8, #0x1
	and	r11, r8, #0x100
	orrs	r7, r7, r11, lsr #7
	ldr	r7, [r10, r7, lsl #2]
	strne	r7, [r9]
		
render_skip_sprite2:
	add	r4, r4, #1
	cmp	r4, #40
	bne	render_sprite_loop2
	
render_skip_sprites2:

	
render_skip_all:	


	pop	{r4, r9, r10}
