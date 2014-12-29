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
@ All CB-prefixed instructions (except for DDCB and FDCB) implemented in
@ here
@

insncb: @ fetch second byte of instruction
	READ_BYTE(r3, r9, r3, r2)
	INC16(r9)

	@ lookup instruction and branch to it
	ldr	r2,[r0, #56]
	ldr	pc,[r2, r3, lsl #2]
	
	
	.global	cbinsn_table
cbinsn_table:
	.word	cbinsn00, cbinsn01, cbinsn02, cbinsn03
	.word	cbinsn04, cbinsn05, cbinsn06, cbinsn07
	.word	cbinsn08, cbinsn09, cbinsn0a, cbinsn0b
	.word	cbinsn0c, cbinsn0d, cbinsn0e, cbinsn0f
	.word	cbinsn10, cbinsn11, cbinsn12, cbinsn13
	.word	cbinsn14, cbinsn15, cbinsn16, cbinsn17
	.word	cbinsn18, cbinsn19, cbinsn1a, cbinsn1b
	.word	cbinsn1c, cbinsn1d, cbinsn1e, cbinsn1f
	.word	cbinsn20, cbinsn21, cbinsn22, cbinsn23
	.word	cbinsn24, cbinsn25, cbinsn26, cbinsn27
	.word	cbinsn28, cbinsn29, cbinsn2a, cbinsn2b
	.word	cbinsn2c, cbinsn2d, cbinsn2e, cbinsn2f
	.word	cbinsn30, cbinsn31, cbinsn32, cbinsn33
	.word	cbinsn34, cbinsn35, cbinsn36, cbinsn37
	.word	cbinsn38, cbinsn39, cbinsn3a, cbinsn3b
	.word	cbinsn3c, cbinsn3d, cbinsn3e, cbinsn3f

	.word	cbinsn40, cbinsn41, cbinsn42, cbinsn43
	.word	cbinsn44, cbinsn45, cbinsn46, cbinsn47
	.word	cbinsn48, cbinsn49, cbinsn4a, cbinsn4b
	.word	cbinsn4c, cbinsn4d, cbinsn4e, cbinsn4f
	.word	cbinsn50, cbinsn51, cbinsn52, cbinsn53
	.word	cbinsn54, cbinsn55, cbinsn56, cbinsn57
	.word	cbinsn58, cbinsn59, cbinsn5a, cbinsn5b
	.word	cbinsn5c, cbinsn5d, cbinsn5e, cbinsn5f
	.word	cbinsn60, cbinsn61, cbinsn62, cbinsn63
	.word	cbinsn64, cbinsn65, cbinsn66, cbinsn67
	.word	cbinsn68, cbinsn69, cbinsn6a, cbinsn6b
	.word	cbinsn6c, cbinsn6d, cbinsn6e, cbinsn6f
	.word	cbinsn70, cbinsn71, cbinsn72, cbinsn73
	.word	cbinsn74, cbinsn75, cbinsn76, cbinsn77
	.word	cbinsn78, cbinsn79, cbinsn7a, cbinsn7b
	.word	cbinsn7c, cbinsn7d, cbinsn7e, cbinsn7f

	.word	cbinsn80, cbinsn81, cbinsn82, cbinsn83
	.word	cbinsn84, cbinsn85, cbinsn86, cbinsn87
	.word	cbinsn88, cbinsn89, cbinsn8a, cbinsn8b
	.word	cbinsn8c, cbinsn8d, cbinsn8e, cbinsn8f
	.word	cbinsn90, cbinsn91, cbinsn92, cbinsn93
	.word	cbinsn94, cbinsn95, cbinsn96, cbinsn97
	.word	cbinsn98, cbinsn99, cbinsn9a, cbinsn9b
	.word	cbinsn9c, cbinsn9d, cbinsn9e, cbinsn9f
	.word	cbinsna0, cbinsna1, cbinsna2, cbinsna3
	.word	cbinsna4, cbinsna5, cbinsna6, cbinsna7
	.word	cbinsna8, cbinsna9, cbinsnaa, cbinsnab
	.word	cbinsnac, cbinsnad, cbinsnae, cbinsnaf
	.word	cbinsnb0, cbinsnb1, cbinsnb2, cbinsnb3
	.word	cbinsnb4, cbinsnb5, cbinsnb6, cbinsnb7
	.word	cbinsnb8, cbinsnb9, cbinsnba, cbinsnbb
	.word	cbinsnbc, cbinsnbd, cbinsnbe, cbinsnbf

	.word	cbinsnc0, cbinsnc1, cbinsnc2, cbinsnc3
	.word	cbinsnc4, cbinsnc5, cbinsnc6, cbinsnc7
	.word	cbinsnc8, cbinsnc9, cbinsnca, cbinsncb
	.word	cbinsncc, cbinsncd, cbinsnce, cbinsncf
	.word	cbinsnd0, cbinsnd1, cbinsnd2, cbinsnd3
	.word	cbinsnd4, cbinsnd5, cbinsnd6, cbinsnd7
	.word	cbinsnd8, cbinsnd9, cbinsnda, cbinsndb
	.word	cbinsndc, cbinsndd, cbinsnde, cbinsndf
	.word	cbinsne0, cbinsne1, cbinsne2, cbinsne3
	.word	cbinsne4, cbinsne5, cbinsne6, cbinsne7
	.word	cbinsne8, cbinsne9, cbinsnea, cbinsneb
	.word	cbinsnec, cbinsned, cbinsnee, cbinsnef
	.word	cbinsnf0, cbinsnf1, cbinsnf2, cbinsnf3
	.word	cbinsnf4, cbinsnf5, cbinsnf6, cbinsnf7
	.word	cbinsnf8, cbinsnf9, cbinsnfa, cbinsnfb
	.word	cbinsnfc, cbinsnfd, cbinsnfe, cbinsnff


@
@ Shifts and rotates
@
cbinsn00:
	RLC8_HI(r5, r3, r2)
	END_INSN(#8)
cbinsn01:
	RLC8_LO(r5, r3, r2)
	END_INSN(#8)
cbinsn02:
	RLC8_HI(r6, r3, r2)
	END_INSN(#8)
cbinsn03:
	RLC8_LO(r6, r3, r2)
	END_INSN(#8)
cbinsn04:
	RLC8_HI(r7, r3, r2)
	END_INSN(#8)
cbinsn05:
	RLC8_LO(r7, r3, r2)
	END_INSN(#8)
cbinsn06:
	READ_BYTE(r12, r7, r3, r2)
	RLC8_LO(r12, r3, r2)
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsn07:
	RLC8_LO(r4, r3, r2)
	END_INSN(#8)
	
cbinsn08:
	RRC8_HI(r5, r3, r2)
	END_INSN(#8)
cbinsn09:
	RRC8_LO(r5, r3, r2)
	END_INSN(#8)
cbinsn0a:
	RRC8_HI(r6, r3, r2)
	END_INSN(#8)
cbinsn0b:
	RRC8_LO(r6, r3, r2)
	END_INSN(#8)
cbinsn0c:
	RRC8_HI(r7, r3, r2)
	END_INSN(#8)
cbinsn0d:
	RRC8_LO(r7, r3, r2)
	END_INSN(#8)
cbinsn0e:
	READ_BYTE(r12, r7, r3, r2)
	RRC8_LO(r12, r3, r2)
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsn0f:
	RRC8_LO(r4, r3, r2)
	END_INSN(#8)

cbinsn10:
	RL8_HI(r5, r3, r2)
	END_INSN(#8)
cbinsn11:
	RL8_LO(r5, r3, r2)
	END_INSN(#8)
cbinsn12:
	RL8_HI(r6, r3, r2)
	END_INSN(#8)
cbinsn13:
	RL8_LO(r6, r3, r2)
	END_INSN(#8)
cbinsn14:
	RL8_HI(r7, r3, r2)
	END_INSN(#8)
cbinsn15:
	RL8_LO(r7, r3, r2)
	END_INSN(#8)
cbinsn16:
	READ_BYTE(r12, r7, r3, r2)
	RL8_LO(r12, r3, r2)
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsn17:
	RL8_LO(r4, r3, r2)
	END_INSN(#8)
	
cbinsn18:
	RR8_HI(r5, r3, r2)
	END_INSN(#8)
cbinsn19:
	RR8_LO(r5, r3, r2)
	END_INSN(#8)
cbinsn1a:
	RR8_HI(r6, r3, r2)
	END_INSN(#8)
cbinsn1b:
	RR8_LO(r6, r3, r2)
	END_INSN(#8)
cbinsn1c:
	RR8_HI(r7, r3, r2)
	END_INSN(#8)
cbinsn1d:
	RR8_LO(r7, r3, r2)
	END_INSN(#8)
cbinsn1e:
	READ_BYTE(r12, r7, r3, r2)
	RR8_LO(r12, r3, r2)
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsn1f:
	RR8_LO(r4, r3, r2)
	END_INSN(#8)

cbinsn20:
	SLA8_HI(r5, r3, r2)
	END_INSN(#8)
cbinsn21:
	SLA8_LO(r5, r3, r2)
	END_INSN(#8)
cbinsn22:
	SLA8_HI(r6, r3, r2)
	END_INSN(#8)
cbinsn23:
	SLA8_LO(r6, r3, r2)
	END_INSN(#8)
cbinsn24:
	SLA8_HI(r7, r3, r2)
	END_INSN(#8)
cbinsn25:
	SLA8_LO(r7, r3, r2)
	END_INSN(#8)
cbinsn26:
	READ_BYTE(r12, r7, r3, r2)
	SLA8_LO(r12, r3, r2)
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsn27:
	SLA8_LO(r4, r3, r2)
	END_INSN(#8)

cbinsn28:
	SRA8_HI(r5, r3, r2)
	END_INSN(#8)
cbinsn29:
	SRA8_LO(r5, r3, r2)
	END_INSN(#8)
cbinsn2a:
	SRA8_HI(r6, r3, r2)
	END_INSN(#8)
cbinsn2b:
	SRA8_LO(r6, r3, r2)
	END_INSN(#8)
cbinsn2c:
	SRA8_HI(r7, r3, r2)
	END_INSN(#8)
cbinsn2d:
	SRA8_LO(r7, r3, r2)
	END_INSN(#8)
cbinsn2e:
	READ_BYTE(r12, r7, r3, r2)
	SRA8_LO(r12, r3, r2)
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsn2f:
	SRA8_LO(r4, r3, r2)
	END_INSN(#8)

cbinsn30:
	SLL8_HI(r5, r3, r2)
	END_INSN(#8)
cbinsn31:
	SLL8_LO(r5, r3, r2)
	END_INSN(#8)
cbinsn32:
	SLL8_HI(r6, r3, r2)
	END_INSN(#8)
cbinsn33:
	SLL8_LO(r6, r3, r2)
	END_INSN(#8)
cbinsn34:
	SLL8_HI(r7, r3, r2)
	END_INSN(#8)
cbinsn35:
	SLL8_LO(r7, r3, r2)
	END_INSN(#8)
cbinsn36:
	READ_BYTE(r12, r7, r3, r2)
	SLL8_LO(r12, r3, r2)
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsn37:
	SLL8_LO(r4, r3, r2)
	END_INSN(#8)

cbinsn38:
	SRL8_HI(r5, r3, r2)
	END_INSN(#8)
cbinsn39:
	SRL8_LO(r5, r3, r2)
	END_INSN(#8)
cbinsn3a:
	SRL8_HI(r6, r3, r2)
	END_INSN(#8)
cbinsn3b:
	SRL8_LO(r6, r3, r2)
	END_INSN(#8)
cbinsn3c:
	SRL8_HI(r7, r3, r2)
	END_INSN(#8)
cbinsn3d:
	SRL8_LO(r7, r3, r2)
	END_INSN(#8)
cbinsn3e:
	READ_BYTE(r12, r7, r3, r2)
	SRL8_LO(r12, r3, r2)
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsn3f:
	SRL8_LO(r4, r3, r2)
	END_INSN(#8)

@
@ Bit tests
@
@ Flag behaviour:
@  - Z is inverse of bit being tested
@  - P/V set to same as Z
@  - N cleared, H set
@  - S clear unless bit 7 being tested and bit 7 is set
@  - C unaffected
@  - undoc set in a weird way, ignore for now
@
cbinsn40:
	BIT_TEST(r5, #0x100)
	END_INSN(#8)
cbinsn41:
	BIT_TEST(r5, #1)
	END_INSN(#8)
cbinsn42:
	BIT_TEST(r6, #0x100)
	END_INSN(#8)
cbinsn43:
	BIT_TEST(r6, #1)
	END_INSN(#8)
cbinsn44:
	BIT_TEST(r7, #0x100)
	END_INSN(#8)
cbinsn45:
	BIT_TEST(r7, #1)
	END_INSN(#8)
cbinsn46:
	READ_BYTE(r12, r7, r3, r2)
	BIT_TEST(r12, #1)
	END_INSN(#12)
cbinsn47:
	BIT_TEST(r4, #1)
	END_INSN(#8)
	
cbinsn48:
	BIT_TEST(r5, #0x200)
	END_INSN(#8)
cbinsn49:
	BIT_TEST(r5, #2)
	END_INSN(#8)
cbinsn4a:
	BIT_TEST(r6, #0x200)
	END_INSN(#8)
cbinsn4b:
	BIT_TEST(r6, #2)
	END_INSN(#8)
cbinsn4c:
	BIT_TEST(r7, #0x200)
	END_INSN(#8)
cbinsn4d:
	BIT_TEST(r7, #2)
	END_INSN(#8)
cbinsn4e:
	READ_BYTE(r12, r7, r3, r2)
	BIT_TEST(r12, #2)
	END_INSN(#12)
cbinsn4f:
	BIT_TEST(r4, #2)
	END_INSN(#8)
	
cbinsn50:
	BIT_TEST(r5, #0x400)
	END_INSN(#8)
cbinsn51:
	BIT_TEST(r5, #4)
	END_INSN(#8)
cbinsn52:
	BIT_TEST(r6, #0x400)
	END_INSN(#8)
cbinsn53:
	BIT_TEST(r6, #4)
	END_INSN(#8)
cbinsn54:
	BIT_TEST(r7, #0x400)
	END_INSN(#8)
cbinsn55:
	BIT_TEST(r7, #4)
	END_INSN(#8)
cbinsn56:
	READ_BYTE(r12, r7, r3, r2)
	BIT_TEST(r12, #4)
	END_INSN(#12)
cbinsn57:
	BIT_TEST(r4, #4)
	END_INSN(#8)
	
cbinsn58:
	BIT_TEST(r5, #0x800)
	END_INSN(#8)
cbinsn59:
	BIT_TEST(r5, #8)
	END_INSN(#8)
cbinsn5a:
	BIT_TEST(r6, #0x800)
	END_INSN(#8)
cbinsn5b:
	BIT_TEST(r6, #8)
	END_INSN(#8)
cbinsn5c:
	BIT_TEST(r7, #0x800)
	END_INSN(#8)
cbinsn5d:
	BIT_TEST(r7, #8)
	END_INSN(#8)
cbinsn5e:
	READ_BYTE(r12, r7, r3, r2)
	BIT_TEST(r12, #8)
	END_INSN(#12)
cbinsn5f:
	BIT_TEST(r4, #8)
	END_INSN(#8)
	
cbinsn60:
	BIT_TEST(r5, #0x1000)
	END_INSN(#8)
cbinsn61:
	BIT_TEST(r5, #16)
	END_INSN(#8)
cbinsn62:
	BIT_TEST(r6, #0x1000)
	END_INSN(#8)
cbinsn63:
	BIT_TEST(r6, #16)
	END_INSN(#8)
cbinsn64:
	BIT_TEST(r7, #0x1000)
	END_INSN(#8)
cbinsn65:
	BIT_TEST(r7, #16)
	END_INSN(#8)
cbinsn66:
	READ_BYTE(r12, r7, r3, r2)
	BIT_TEST(r12, #16)
	END_INSN(#12)
cbinsn67:
	BIT_TEST(r4, #16)
	END_INSN(#8)
	
cbinsn68:
	BIT_TEST(r5, #0x2000)
	END_INSN(#8)
cbinsn69:
	BIT_TEST(r5, #0x20)
	END_INSN(#8)
cbinsn6a:
	BIT_TEST(r6, #0x2000)
	END_INSN(#8)
cbinsn6b:
	BIT_TEST(r6, #0x20)
	END_INSN(#8)
cbinsn6c:
	BIT_TEST(r7, #0x2000)
	END_INSN(#8)
cbinsn6d:
	BIT_TEST(r7, #0x20)
	END_INSN(#8)
cbinsn6e:
	READ_BYTE(r12, r7, r3, r2)
	BIT_TEST(r12, #0x20)
	END_INSN(#12)
cbinsn6f:
	BIT_TEST(r4, #0x20)
	END_INSN(#8)
	
cbinsn70:
	BIT_TEST(r5, #0x4000)
	END_INSN(#8)
cbinsn71:
	BIT_TEST(r5, #0x40)
	END_INSN(#8)
cbinsn72:
	BIT_TEST(r6, #0x4000)
	END_INSN(#8)
cbinsn73:
	BIT_TEST(r6, #0x40)
	END_INSN(#8)
cbinsn74:
	BIT_TEST(r7, #0x4000)
	END_INSN(#8)
cbinsn75:
	BIT_TEST(r7, #0x40)
	END_INSN(#8)
cbinsn76:
	READ_BYTE(r12, r7, r3, r2)
	BIT_TEST(r12, #0x40)
	END_INSN(#12)
cbinsn77:
	BIT_TEST(r4, #0x40)
	END_INSN(#8)
	
cbinsn78:
	BIT_TEST7(r5, #0x8000)
	END_INSN(#8)
cbinsn79:
	BIT_TEST7(r5, #0x80)
	END_INSN(#8)
cbinsn7a:
	BIT_TEST7(r6, #0x8000)
	END_INSN(#8)
cbinsn7b:
	BIT_TEST7(r6, #0x80)
	END_INSN(#8)
cbinsn7c:
	BIT_TEST7(r7, #0x8000)
	END_INSN(#8)
cbinsn7d:
	BIT_TEST7(r7, #0x80)
	END_INSN(#8)
cbinsn7e:
	READ_BYTE(r12, r7, r3, r2)
	BIT_TEST7(r12, #0x80)
	END_INSN(#12)
cbinsn7f:
	BIT_TEST7(r4, #0x80)
	END_INSN(#8)
	

@
@ Resets
@
cbinsn80:
	bic	r5, r5, #0x100
	END_INSN(#8)
cbinsn81:
	bic	r5, r5, #1
	END_INSN(#8)
cbinsn82:
	bic	r6, r6, #0x100
	END_INSN(#8)
cbinsn83:
	bic	r6, r6, #1
	END_INSN(#8)
cbinsn84:
	bic	r7, r7, #0x100
	END_INSN(#8)
cbinsn85:
	bic	r7, r7, #1
	END_INSN(#8)
cbinsn86:
	READ_BYTE(r12, r7, r3, r2)
	bic	r12, r12, #1
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsn87:
	bic	r4, r4, #1
	END_INSN(#8)
	
cbinsn88:
	bic	r5, r5, #0x200
	END_INSN(#8)
cbinsn89:
	bic	r5, r5, #2
	END_INSN(#8)
cbinsn8a:
	bic	r6, r6, #0x200
	END_INSN(#8)
cbinsn8b:
	bic	r6, r6, #2
	END_INSN(#8)
cbinsn8c:
	bic	r7, r7, #0x200
	END_INSN(#8)
cbinsn8d:
	bic	r7, r7, #2
	END_INSN(#8)
cbinsn8e:
	READ_BYTE(r12, r7, r3, r2)
	bic	r12, r12, #2
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsn8f:
	bic	r4, r4, #2
	END_INSN(#8)

cbinsn90:
	bic	r5, r5, #0x400
	END_INSN(#8)
cbinsn91:
	bic	r5, r5, #4
	END_INSN(#8)
cbinsn92:
	bic	r6, r6, #0x400
	END_INSN(#8)
cbinsn93:
	bic	r6, r6, #4
	END_INSN(#8)
cbinsn94:
	bic	r7, r7, #0x400
	END_INSN(#8)
cbinsn95:
	bic	r7, r7, #4
	END_INSN(#8)
cbinsn96:
	READ_BYTE(r12, r7, r3, r2)
	bic	r12, r12, #4
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsn97:
	bic	r4, r4, #4
	END_INSN(#8)
	
cbinsn98:
	bic	r5, r5, #0x800
	END_INSN(#8)
cbinsn99:
	bic	r5, r5, #8
	END_INSN(#8)
cbinsn9a:
	bic	r6, r6, #0x800
	END_INSN(#8)
cbinsn9b:
	bic	r6, r6, #8
	END_INSN(#8)
cbinsn9c:
	bic	r7, r7, #0x800
	END_INSN(#8)
cbinsn9d:
	bic	r7, r7, #8
	END_INSN(#8)
cbinsn9e:
	READ_BYTE(r12, r7, r3, r2)
	bic	r12, r12, #8
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsn9f:
	bic	r4, r4, #8
	END_INSN(#8)

cbinsna0:
	bic	r5, r5, #0x1000
	END_INSN(#8)
cbinsna1:
	bic	r5, r5, #0x10
	END_INSN(#8)
cbinsna2:
	bic	r6, r6, #0x1000
	END_INSN(#8)
cbinsna3:
	bic	r6, r6, #0x10
	END_INSN(#8)
cbinsna4:
	bic	r7, r7, #0x1000
	END_INSN(#8)
cbinsna5:
	bic	r7, r7, #0x10
	END_INSN(#8)
cbinsna6:
	READ_BYTE(r12, r7, r3, r2)
	bic	r12, r12, #0x10
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsna7:
	bic	r4, r4, #0x10
	END_INSN(#8)
	
cbinsna8:
	bic	r5, r5, #0x2000
	END_INSN(#8)
cbinsna9:
	bic	r5, r5, #0x20
	END_INSN(#8)
cbinsnaa:
	bic	r6, r6, #0x2000
	END_INSN(#8)
cbinsnab:
	bic	r6, r6, #0x20
	END_INSN(#8)
cbinsnac:
	bic	r7, r7, #0x2000
	END_INSN(#8)
cbinsnad:
	bic	r7, r7, #0x20
	END_INSN(#8)
cbinsnae:
	READ_BYTE(r12, r7, r3, r2)
	bic	r12, r12, #0x20
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsnaf:
	bic	r4, r4, #0x20
	END_INSN(#8)

cbinsnb0:
	bic	r5, r5, #0x4000
	END_INSN(#8)
cbinsnb1:
	bic	r5, r5, #0x40
	END_INSN(#8)
cbinsnb2:
	bic	r6, r6, #0x4000
	END_INSN(#8)
cbinsnb3:
	bic	r6, r6, #0x40
	END_INSN(#8)
cbinsnb4:
	bic	r7, r7, #0x4000
	END_INSN(#8)
cbinsnb5:
	bic	r7, r7, #0x40
	END_INSN(#8)
cbinsnb6:
	READ_BYTE(r12, r7, r3, r2)
	bic	r12, r12, #0x40
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsnb7:
	bic	r4, r4, #0x40
	END_INSN(#8)
	
cbinsnb8:
	bic	r5, r5, #0x8000
	END_INSN(#8)
cbinsnb9:
	bic	r5, r5, #0x80
	END_INSN(#8)
cbinsnba:
	bic	r6, r6, #0x8000
	END_INSN(#8)
cbinsnbb:
	bic	r6, r6, #0x80
	END_INSN(#8)
cbinsnbc:
	bic	r7, r7, #0x8000
	END_INSN(#8)
cbinsnbd:
	bic	r7, r7, #0x80
	END_INSN(#8)
cbinsnbe:
	READ_BYTE(r12, r7, r3, r2)
	bic	r12, r12, #0x80
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsnbf:
	bic	r4, r4, #0x80
	END_INSN(#8)

@
@ Sets
@
cbinsnc0:
	orr	r5, r5, #0x100
	END_INSN(#8)
cbinsnc1:
	orr	r5, r5, #1
	END_INSN(#8)
cbinsnc2:
	orr	r6, r6, #0x100
	END_INSN(#8)
cbinsnc3:
	orr	r6, r6, #1
	END_INSN(#8)
cbinsnc4:
	orr	r7, r7, #0x100
	END_INSN(#8)
cbinsnc5:
	orr	r7, r7, #1
	END_INSN(#8)
cbinsnc6:
	READ_BYTE(r12, r7, r3, r2)
	orr	r12, r12, #0x1
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsnc7:
	orr	r4, r4, #1
	END_INSN(#8)

cbinsnc8:
	orr	r5, r5, #0x200
	END_INSN(#8)
cbinsnc9:
	orr	r5, r5, #2
	END_INSN(#8)
cbinsnca:
	orr	r6, r6, #0x200
	END_INSN(#8)
cbinsncb:
	orr	r6, r6, #2
	END_INSN(#8)
cbinsncc:
	orr	r7, r7, #0x200
	END_INSN(#8)
cbinsncd:
	orr	r7, r7, #2
	END_INSN(#8)
cbinsnce:
	READ_BYTE(r12, r7, r3, r2)
	orr	r12, r12, #0x2
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsncf:
	orr	r4, r4, #2
	END_INSN(#8)

cbinsnd0:
	orr	r5, r5, #0x400
	END_INSN(#8)
cbinsnd1:
	orr	r5, r5, #4
	END_INSN(#8)
cbinsnd2:
	orr	r6, r6, #0x400
	END_INSN(#8)
cbinsnd3:
	orr	r6, r6, #4
	END_INSN(#8)
cbinsnd4:
	orr	r7, r7, #0x400
	END_INSN(#8)
cbinsnd5:
	orr	r7, r7, #4
	END_INSN(#8)
cbinsnd6:
	READ_BYTE(r12, r7, r3, r2)
	orr	r12, r12, #0x4
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsnd7:
	orr	r4, r4, #4
	END_INSN(#8)

cbinsnd8:
	orr	r5, r5, #0x800
	END_INSN(#8)
cbinsnd9:
	orr	r5, r5, #8
	END_INSN(#8)
cbinsnda:
	orr	r6, r6, #0x800
	END_INSN(#8)
cbinsndb:
	orr	r6, r6, #8
	END_INSN(#8)
cbinsndc:
	orr	r7, r7, #0x800
	END_INSN(#8)
cbinsndd:
	orr	r7, r7, #8
	END_INSN(#8)
cbinsnde:
	READ_BYTE(r12, r7, r3, r2)
	orr	r12, r12, #0x8
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsndf:
	orr	r4, r4, #8
	END_INSN(#8)

cbinsne0:
	orr	r5, r5, #0x1000
	END_INSN(#8)
cbinsne1:
	orr	r5, r5, #0x10
	END_INSN(#8)
cbinsne2:
	orr	r6, r6, #0x1000
	END_INSN(#8)
cbinsne3:
	orr	r6, r6, #0x10
	END_INSN(#8)
cbinsne4:
	orr	r7, r7, #0x1000
	END_INSN(#8)
cbinsne5:
	orr	r7, r7, #0x10
	END_INSN(#8)
cbinsne6:
	READ_BYTE(r12, r7, r3, r2)
	orr	r12, r12, #0x10
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsne7:
	orr	r4, r4, #0x10
	END_INSN(#8)

cbinsne8:
	orr	r5, r5, #0x2000
	END_INSN(#8)
cbinsne9:
	orr	r5, r5, #0x20
	END_INSN(#8)
cbinsnea:
	orr	r6, r6, #0x2000
	END_INSN(#8)
cbinsneb:
	orr	r6, r6, #0x20
	END_INSN(#8)
cbinsnec:
	orr	r7, r7, #0x2000
	END_INSN(#8)
cbinsned:
	orr	r7, r7, #0x20
	END_INSN(#8)
cbinsnee:
	READ_BYTE(r12, r7, r3, r2)
	orr	r12, r12, #0x20
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsnef:
	orr	r4, r4, #0x20
	END_INSN(#8)

cbinsnf0:
	orr	r5, r5, #0x4000
	END_INSN(#8)
cbinsnf1:
	orr	r5, r5, #0x40
	END_INSN(#8)
cbinsnf2:
	orr	r6, r6, #0x4000
	END_INSN(#8)
cbinsnf3:
	orr	r6, r6, #0x40
	END_INSN(#8)
cbinsnf4:
	orr	r7, r7, #0x4000
	END_INSN(#8)
cbinsnf5:
	orr	r7, r7, #0x40
	END_INSN(#8)
cbinsnf6:
	READ_BYTE(r12, r7, r3, r2)
	orr	r12, r12, #0x40
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsnf7:
	orr	r4, r4, #0x40
	END_INSN(#8)

cbinsnf8:
	orr	r5, r5, #0x8000
	END_INSN(#8)
cbinsnf9:
	orr	r5, r5, #0x80
	END_INSN(#8)
cbinsnfa:
	orr	r6, r6, #0x8000
	END_INSN(#8)
cbinsnfb:
	orr	r6, r6, #0x80
	END_INSN(#8)
cbinsnfc:
	orr	r7, r7, #0x8000
	END_INSN(#8)
cbinsnfd:
	orr	r7, r7, #0x80
	END_INSN(#8)
cbinsnfe:
	READ_BYTE(r12, r7, r3, r2)
	orr	r12, r12, #0x80
	WRITE_BYTE(r12, r7, r3, r2)
	END_INSN(#15)
cbinsnff:
	orr	r4, r4, #0x80
	END_INSN(#8)

