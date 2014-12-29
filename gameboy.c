/*
 * GCat's Gameboy Emulator
 * Copyright (c) 2012 James Perry
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct screenState_s {
    unsigned char scanline;  /* 0 */
    unsigned char vdpMode;   /* 1 */
    unsigned char spritesOnLine; /* 2 */
    char pad1;

    unsigned int colours[4]; /* 4 */
    unsigned int bgPalette[4]; /* 20 */
    unsigned int sprPalette0[4]; /* 36 */
    unsigned int sprPalette1[4]; /* 52 */

    unsigned char *lineScrolls; /* 68 */
    unsigned int *screenBuffer; /* 72 */
    unsigned char *videoRAM;    /* 76 */
} screenState_t;

typedef struct soundState_s
{
    unsigned char *soundBuffer; /* 0 */

    /* general channel 1 stuff */
    unsigned int channel1Freq; /* 4 */
    unsigned int channel1Counter; /* 8 */
    unsigned int channel1Threshold; /* 12 */ /* for the duty cycle */
    unsigned int channel1Length; /* 16 */ /* length cycles remaining */

    /* sweep - Step will be added to Freq whenever Counter passes
     * Threshold */
    unsigned int channel1SweepCounter; /* 20 */
    unsigned int channel1SweepThreshold; /* 24 */
    unsigned int channel1SweepStep;    /* 28 */ 

    /* envelope - Step will be added to Level whenever Counter passes
     * Threshold */
    unsigned int channel1EnvCounter; /* 32 */
    unsigned int channel1EnvThreshold;    /* 36 */
    unsigned char channel1Level;     /* 40 */
    signed char channel1LevelStep;   /* 41 */
    short pad1;                      /* 42 */

    /* Channel 2 general */
    unsigned int channel2Freq;    /* 44 */
    unsigned int channel2Counter; /* 48 */
    unsigned int channel2Threshold; /* 52 */
    unsigned int channel2Length;    /* 56 */

    /* channel 2 envelope */
    unsigned int channel2EnvCounter; /* 60 */
    unsigned int channel2EnvThreshold; /* 64*/
    unsigned char channel2Level;     /* 68 */
    signed char channel2LevelStep;   /* 69 */
    short pad2;                      /* 70 */

    /* channel 3 general */
    unsigned int channel3Freq;     /* 72 */
    unsigned int channel3Counter;  /* 76 */
    unsigned int channel3Length;   /* 80 */
    unsigned char channel3Sample;  /* 84 */
    char pad3;
    short pad4;

    /* channel 4 general */
    unsigned int channel4Freq;     /* 88 */
    unsigned int channel4Counter;  /* 92 */
    unsigned int channel4Length;   /* 96 */
    unsigned int channel4LFSR;     /* 100 */

    /* channel 4 envelope */
    unsigned int channel4EnvCounter; /* 104 */
    unsigned int channel4EnvThreshold;  /* 108 */
    unsigned int channel4Level;         /* 112 */
    signed char channel4LevelStep;      /* 116 */
    char pad5;
    short pad6;

    unsigned int channel1Output;   /* 120 */
    unsigned int channel2Output;   /* 124 */
    unsigned int channel3Output;   /* 128 */
    unsigned int channel4Output;   /* 132 */
} soundState_t;

/*
 * This structure holds all the important things the assembly code
 * needs to access. Mostly CPU state but also some Gameboy state
 * too.
 */
typedef struct z80State_s {
    int tstates; /* 0 */

    unsigned char **readPages; /* 4 */
    unsigned char *mem; /* 8 */

    unsigned short af; /* 12 */
    unsigned short bc; /* 14 */
    unsigned short de; /* 16 */
    unsigned short hl; /* 18 */

    unsigned short sp; /* 20 */
    unsigned short pc; /* 22 */

    unsigned short ix; /* 24 */
    unsigned short iy; /* 26 */
  
    unsigned short afp; /* 28 */
    unsigned short bcp; /* 30 */
    unsigned short dep; /* 32 */
    unsigned short hlp; /* 34 */

    unsigned char i; /* 36 */
    unsigned char r; /* 37 */
    unsigned char iff1; /* 38 */
    unsigned char iff2; /* 39 */

    unsigned int *itable; /* 40 */
    soundState_t *soundState; /* 44 */
    unsigned char *vhAddTable; /* 48 */
    unsigned char *vhSubTable; /* 52 */

    unsigned int *cbitable; /* 56 */
    unsigned int dividerCounter; /* 60 */
    unsigned int timerCounter; /* 64 */
    unsigned int timerIncrement; /* 68 */

    unsigned char intPending; /* 72 */
    unsigned char imode; /* 73 */
    unsigned char regWritten; /* 74 */
    /* Should be (from bit 0): RLUDABSelStart, active low */
    unsigned char joypadData; /* 75 */

    unsigned char screenEnabled; /* 76 */
    unsigned char romSize;       /* 77 */ /* in pages */
    unsigned char serialLatency; /* 78 */
    unsigned char mbcType;  /* 79 */

    unsigned char *oamRAM; /* 80 */
    screenState_t *screenState; /* 84 */
    unsigned char *ioRAM; /* 88 */

    unsigned short debugWords[8]; /* 92 */

    unsigned char pagingRegs[4]; /* 108 */

    unsigned char ramSize;  /* 112 */ /* in pages */
} z80State_t;

/* The CPU state */
static z80State_t z80State;
static screenState_t screenState;
static soundState_t soundState;

static unsigned char *cartridgeROM;
static unsigned char *cartridgeRAM;
static unsigned char *internalRAM;
static unsigned char *videoRAM;

static unsigned char *pageTable[20];

static int cartridgeSize;

static unsigned char newJoypadState;

/* sprite table and registers */
static unsigned char ioRAM[512];
//static unsigned char *ioRAM;

//static int executing = 0;

extern unsigned int insn_table[256];
extern unsigned int cbinsn_table[256];

/*
 * Gameboy memory map:
 *
 * 0000-3FFF - first ROM bank (always #0)
 * 4000-7FFF - second ROM bank (switchable)
 * 8000-9FFF - 8K video RAM
 * A000-BFFF - switchable RAM (from cartridge?)
 * C000-FDFF - internal RAM
 * FE00-FEFF - sprite table
 * FF00-FFFF - I/O registers
 *
 * Paging:
 *  - For MBC1:
 *    * write to 2000-3FFF to select second ROM bank
 *    * write to 4000-5FFF to select RAM bank
 *
 *  - For MBC2:
 *    * write to 2100-21FF to select second ROM bank
 */

static unsigned char initialIOValues[] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, /* 00 */
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x80, 0xbf, 0xf3, 0x00, 0xbf, 0x00, 0x3f, 0x00, /* 10 */
    0x00, 0xbf, 0x7f, 0xff, 0x9f, 0x00, 0xbf, 0x00,
    0xff, 0x00, 0x00, 0xbf, 0x77, 0xf3, 0xf1, 0x00, /* 20 */
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, /* 30 */
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x91, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0xfc, /* 40 */
    0xff, 0xff, 0x00, 0x00
};

static void resetCPU()
{
    /* initialise the CPU state */
    z80State.tstates = -80;
    z80State.readPages = &pageTable[0];
    //z80State.specMem = specMem;

    z80State.af = 0x0000;
    z80State.bc = 0x0000;
    z80State.de = 0x0000;
    z80State.hl = 0x0000;

    z80State.sp = 0x0000;
    z80State.pc = 0x0000;
    z80State.ix = 0x0000;
    z80State.iy = 0x0000;

    z80State.afp = 0x0000;
    z80State.bcp = 0x0000;
    z80State.dep = 0x0000;
    z80State.hlp = 0x0000;

    z80State.i = 0x00;
    z80State.r = 0x00;
    z80State.iff1 = 0x00;
    z80State.iff2 = 0x00;

    z80State.itable = insn_table;
    z80State.vhAddTable = NULL;
    z80State.vhSubTable = NULL;

    z80State.cbitable = cbinsn_table;
    z80State.dividerCounter = 0;
    z80State.timerCounter = 0;
    z80State.timerIncrement = 0;

    z80State.imode = 1;
    z80State.intPending = 0;

    z80State.regWritten = 0xff;
    z80State.joypadData = 0xff;

    z80State.serialLatency = 0;

    newJoypadState = 0xff;

    z80State.pagingRegs[0] = 0;
    z80State.pagingRegs[1] = 0;
    z80State.pagingRegs[2] = 0;
    z80State.pagingRegs[3] = 0;

    z80State.oamRAM = &ioRAM[0];
    z80State.ioRAM = &ioRAM[256];

    memset(cartridgeRAM, 0, 32*1024);
    memset(internalRAM, 0, 16*1024);
    memset(videoRAM, 0, 8*1024);
    memset(ioRAM, 0, 512);

    /* initialise page table */
    pageTable[0] = &cartridgeROM[0x00000];
    pageTable[1] = &cartridgeROM[0x02000];
    pageTable[2] = &cartridgeROM[0x04000];
    pageTable[3] = &cartridgeROM[0x06000];
    pageTable[4] = &videoRAM[0x00000];
    pageTable[5] = &cartridgeRAM[0x00000];
    pageTable[6] = &internalRAM[0x00000];
    pageTable[7] = &internalRAM[0x00000];

    pageTable[8] = &internalRAM[0x04000];
    pageTable[9] = &internalRAM[0x04000];
    pageTable[10] = &internalRAM[0x04000];
    pageTable[11] = &internalRAM[0x04000];
    pageTable[12] = &videoRAM[0x00000];
    pageTable[13] = &cartridgeRAM[0x00000];
    pageTable[14] = &internalRAM[0x00000];
    pageTable[15] = &internalRAM[0x00000];

    pageTable[16] = &cartridgeROM[0x00000];
    pageTable[17] = &cartridgeRAM[0x00000];
    pageTable[18] = &ioRAM[0] - 0x1e00;

    screenState.colours[0] = 0xffffffff;
    screenState.colours[1] = 0xffcccccc;
    screenState.colours[2] = 0xff888888;
    screenState.colours[3] = 0xff444444;
  
    screenState.bgPalette[0] = 0xffffffff;
    screenState.bgPalette[1] = 0xffcccccc;
    screenState.bgPalette[2] = 0xff888888;
    screenState.bgPalette[3] = 0xff444444;
  
    screenState.sprPalette0[0] = 0xffffffff;
    screenState.sprPalette0[1] = 0xffcccccc;
    screenState.sprPalette0[2] = 0xff888888;
    screenState.sprPalette0[3] = 0xff444444;
  
    screenState.sprPalette1[0] = 0xffffffff;
    screenState.sprPalette1[1] = 0xffcccccc;
    screenState.sprPalette1[2] = 0xff888888;
    screenState.sprPalette1[3] = 0xff444444;

    screenState.videoRAM = videoRAM;

    memset(screenState.lineScrolls, 0, 144);
  
    z80State.screenState = &screenState;
    screenState.scanline = 0;
    screenState.vdpMode = 2;

    z80State.debugWords[0] = 0;
    z80State.debugWords[1] = 0;
    z80State.debugWords[2] = 0;
    z80State.debugWords[3] = 0;
    z80State.debugWords[4] = 0;
    z80State.debugWords[5] = 0;
    z80State.debugWords[6] = 0;
    z80State.debugWords[7] = 0;

    z80State.screenEnabled = 0xff;

    /* initialise ioRAM to correct values for power on */
    memcpy(&ioRAM[0x100], initialIOValues, 0x4c);

    z80State.soundState = &soundState;
    soundState.channel1Freq = 0;
    soundState.channel1Counter = 0;
    soundState.channel1Threshold = 0;
    soundState.channel1Length = 0;
    soundState.channel1SweepCounter = 0;
    soundState.channel1SweepThreshold = 0;
    soundState.channel1SweepStep = 0;
    soundState.channel1EnvCounter = 0;
    soundState.channel1EnvThreshold = 0;
    soundState.channel1Level = 0;
    soundState.channel1LevelStep = 0;

    soundState.channel2Freq = 0;
    soundState.channel2Counter = 0;
    soundState.channel2Threshold = 0;
    soundState.channel2Length = 0;
    soundState.channel2EnvCounter = 0;
    soundState.channel2EnvThreshold = 0;
    soundState.channel2Level = 0;
    soundState.channel2LevelStep = 0;

    soundState.channel3Freq = 256;
    soundState.channel3Counter = 0;
    soundState.channel3Length = 0;
    soundState.channel3Sample = 0;

    soundState.channel4Freq = 256;
    soundState.channel4Counter = 0;
    soundState.channel4Length = 0;
    soundState.channel4LFSR = 0x7fff;
    soundState.channel4EnvCounter = 0;
    soundState.channel4EnvThreshold = 0;
    soundState.channel4Level = 0;
    soundState.channel4LevelStep = 0;
}

/*jint
Java_uk_org_gcat_gameboy_GcatGameboyApp_startup( JNIEnv* env,
jobject thiz )*/
int GB_startup()
{
    cartridgeROM = malloc(512*1024);
    cartridgeRAM = malloc(32*1024);
    internalRAM = malloc(24*1024); /* extra 8K for invalid write page */
    videoRAM = malloc(8*1024);

    screenState.lineScrolls = malloc(144);
    screenState.screenBuffer = malloc(256 * 144 * sizeof(unsigned int));

    soundState.soundBuffer = malloc(616);

    //ioRAM = malloc(512);

    if ((!cartridgeROM) || (!cartridgeRAM) || (!internalRAM) ||
	(!videoRAM) || (!screenState.lineScrolls) ||
	(!screenState.screenBuffer)) {
	return 0;
    }

    memset(cartridgeROM, 0, 512*1024);

    memset(soundState.soundBuffer, 0x80, 616);

    cartridgeROM[0] = 0xf3;
    cartridgeROM[1] = 0xc3;
    cartridgeROM[2] = 0x01;
    cartridgeROM[3] = 0x00;

    cartridgeSize = 2;

    z80State.romSize = 2;
    z80State.ramSize = 0;
    //executing = 0;

    resetCPU();
  
    return 1;
}

void GB_setCartridgeRAMContents(unsigned char *ram)
{
    memcpy(ram, cartridgeRAM, 32*1024);
}

void GB_getCartridgeRAMContents(unsigned char *ram)
{
    memcpy(cartridgeRAM, ram, 32*1024);
}


int GB_loadROM(char *filename)
{
    int len;
    unsigned char *s;
    FILE *f;

    f = fopen(filename, "rb");
    if (!f) {
	return 0;
    }
    fseek(f, 0, SEEK_END);
    len = ftell(f);
    fseek(f, 0, SEEK_SET);
    s = malloc(len);
    if (!s) {
	fclose(f);
	return 0;
    }
    fread(s, len, 1, f);
    fclose(f);

    if ((len > (512*1024)) || (len & 0x3fff)) {
	/* FIXME: maybe support up to 2MB cartridges, allocate bigger buffer */
	free(s);
	return 0;
    }

    /* copy in ROM data */
    cartridgeSize = len >> 14;
    memcpy(cartridgeROM, s, len);
    free(s);

    /* reset machine */
    resetCPU();

    z80State.af = 0xb001;
    z80State.bc = 0x0013;
    z80State.de = 0x00d8;
    z80State.hl = 0x014d;
    z80State.sp = 0xfffe;
    z80State.pc = 0x0100;

    /* 
     * get ROM/RAM sizes and MBC number, put them somewhere
     * for the paging handler
     */
    z80State.romSize = cartridgeSize;
    switch (cartridgeROM[0x149]) {
    case 0:
	z80State.ramSize = 0;
	break;
    case 1:
    case 2:
	z80State.ramSize = 1;
	break;
    case 3:
	z80State.ramSize = 4;
	break;
    }
    switch (cartridgeROM[0x147]) {
    case 0:
    case 8:
    case 9:
	/* no MBC */
	z80State.mbcType = 0;
	break;
    case 5:
    case 6:
	z80State.mbcType = 2;
	break;
    case 0xf:
    case 0x10:
    case 0x11:
    case 0x12:
    case 0x13:
	z80State.mbcType = 3;
	break;
    case 0x15:
    case 0x16:
    case 0x17:
	z80State.mbcType = 4;
	break;
    case 0x19:
    case 0x1a:
    case 0x1b:
    case 0x1c:
    case 0x1d:
    case 0x1e:
	z80State.mbcType = 5;
	break;
    default:
	/* default to MBC1 */
	z80State.mbcType = 1;
	break;
    }

    return 1;
}

/* assembly function which runs the Z80 until tstates overflows */
int asmExecute(z80State_t *state, unsigned char *mem);

/*
 * Runs the Z80 CPU for one frame
 */
/*jint
Java_uk_org_gcat_gameboy_GcatGameboyApp_execute( JNIEnv* env,
jobject thiz )*/
int GB_execute()
{
    int result;
    unsigned char jpd;

    static int tuneCounter = 300;
    static int tune = 0;


    /*
     * Load new joypad data synchronously here.
     * Trigger a joypad interrupt if any buttons have changed from not
     * pressed to pressed.
     */
    jpd = (~newJoypadState) & z80State.joypadData;
    if (jpd)
    {
        z80State.intPending = 0xff;
        ioRAM[0x10f] |= 0x10;
    }
    z80State.joypadData = newJoypadState;


    /*if (newJoypadState == 0xbf) {
      if (!z80State.debugWords[0]) {
      z80State.debugWords[0] = z80State.pc;
      }
      }*/

    //if (executing) return 0;
    //executing = 1;
    z80State.tstates = -80;
    //z80State.tstates = -4;

    result = asmExecute(&z80State, NULL);

    //z80State.debugWords[0] = internalRAM[0x1b95];
    /*if ((z80State.joypadData & 0xf) != 0xf) {
      z80State.debugWords[0] = internalRAM[0x1b96];
      }*/

    // Zelda sound test
    /*tuneCounter--;
      if (!tuneCounter) {
      tuneCounter = 300;
      internalRAM[0x1368] = tune;
      tune++;
      }*/

    //executing = 0;
    return z80State.pc;
}

/*void
Java_uk_org_gcat_gameboy_GcatGameboyApp_setJoypadState( JNIEnv* env,
							jobject thiz,
							jint jps)*/
void GB_setJoypadState(int jps)
{
    newJoypadState = jps;
}

// FIXME: port these if we ever want them
#if 0
jint
Java_uk_org_gcat_gameboy_GcatGameboyApp_getDebugWord( JNIEnv* env,
						      jobject thiz,
						      jint idx)
{
    return (jint)(z80State.debugWords[idx]);
}

jint
Java_uk_org_gcat_gameboy_GcatGameboyApp_getPC( JNIEnv* env,
					       jobject thiz )
{
    return z80State.pc;
}
#endif


void GB_getAudioData(unsigned char *audio)
{
    int i;

    for (i = 0; i < 616; i++) {
	audio[i*2] = 0;
	audio[i*2+1] = (soundState.soundBuffer[i] ^ 0x80);
    }
}

/*static unsigned int colours[4] = {
  0xffffffff, 0xffcccccc, 0xff888888, 0xff444444
  };*/

/*
 * Screen TODO:
 *
 * - DONE - handle disabling screen
 * - DONE - handle scrolling
 * - DONE - draw window display
 * - DONE - draw sprite display
 * - DONE - use correct tile maps
 * - DONE - use correct pattern sets
 * - DONE - use correct palettes
 * - DONE - make some sprites pass behind backdrop
 * - (fix sprite priorities (maybe))
 * - DONE - line-by-line update
 *
 * - centre display properly on phone screen
 */
static void renderLine(int line, unsigned int *dest)
{
    /* with an extra tile, and extra sprite space either side */
    static unsigned int buf[184];
    unsigned char *tmbase;
    int row;
    int trow, rwt, tcol;
    int tile;
    //unsigned char pal[4];
    //unsigned char opal1[4], opal2[4];
    int i;
    unsigned char b1, b2, col;
    unsigned int *p;
    int ts;
    int sprol = 0;

    /* work out palette for background and window */
    /*pal[0] = ioRAM[0x147] & 3;
      pal[1] = (ioRAM[0x147] >> 2) & 3;
      pal[2] = (ioRAM[0x147] >> 4) & 3;
      pal[3] = (ioRAM[0x147] >> 6) & 3;*/

    for (i = 8; i < 176; i++) {
	buf[i] = screenState.bgPalette[0];
    }

    /* draw sprites that pass behind background */
    if (ioRAM[0x140] & 0x2) {
	int sprh = 8;
	int sprx, spry, sprt, sprf;
	unsigned int *sprpal;

	/* work out palettes for sprites */
	/*opal1[1] = (ioRAM[0x148] >> 2) & 3;
	  opal1[2] = (ioRAM[0x148] >> 4) & 3;
	  opal1[3] = (ioRAM[0x148] >> 6) & 3;
	  opal2[1] = (ioRAM[0x149] >> 2) & 3;
	  opal2[2] = (ioRAM[0x149] >> 4) & 3;
	  opal2[3] = (ioRAM[0x149] >> 6) & 3;*/

	if (ioRAM[0x140] & 4) sprh = 16;

	/* draw sprites */
	for (i = 0; i < 40; i++) {
	    if (sprol == 10) break;

	    sprf = ioRAM[i*4+3];
	    if (sprf & 0x80) {
		spry = ioRAM[i*4] - 16;
		if ((spry <= line) && ((spry+sprh) > line)) {
		    sprol++;
	  
		    sprx = ioRAM[i*4+1];
		    if ((sprx != 0) && (sprx < 168)) {
			sprx += (ioRAM[0x143] & 7);
			sprt = ioRAM[i*4+2];
			if (sprh == 16) sprt &= 0xfe;
	    
			sprpal = &screenState.sprPalette0[0];
			if (sprf & 0x10) sprpal = &screenState.sprPalette1[0];
	    
			rwt = line - spry;
			if (sprf & 0x40) rwt = (sprh - 1) - rwt;
	    
			b1 = videoRAM[(rwt << 1) + (sprt << 4)];
			b2 = videoRAM[(rwt << 1) + (sprt << 4) + 1];
	    
			if (!(sprf & 0x20)) {
			    col = ((b1 & 0x80) >> 7) | ((b2 & 0x80) >> 6);
			    if (col) buf[sprx] = sprpal[col];
			    col = ((b1 & 0x40) >> 6) | ((b2 & 0x40) >> 5);
			    if (col) buf[sprx+1] = sprpal[col];
			    col = ((b1 & 0x20) >> 5) | ((b2 & 0x20) >> 4);
			    if (col) buf[sprx+2] = sprpal[col];
			    col = ((b1 & 0x10) >> 4) | ((b2 & 0x10) >> 3);
			    if (col) buf[sprx+3] = sprpal[col];
			    col = ((b1 & 0x08) >> 3) | ((b2 & 0x08) >> 2);
			    if (col) buf[sprx+4] = sprpal[col];
			    col = ((b1 & 0x04) >> 2) | ((b2 & 0x04) >> 1);
			    if (col) buf[sprx+5] = sprpal[col];
			    col = ((b1 & 0x02) >> 1) | ((b2 & 0x02) >> 0);
			    if (col) buf[sprx+6] = sprpal[col];
			    col = ((b1 & 0x01) >> 0) | ((b2 & 0x01) << 1);
			    if (col) buf[sprx+7] = sprpal[col];
			}
			else {
			    col = ((b1 & 0x80) >> 7) | ((b2 & 0x80) >> 6);
			    if (col) buf[sprx+7] = sprpal[col];
			    col = ((b1 & 0x40) >> 6) | ((b2 & 0x40) >> 5);
			    if (col) buf[sprx+6] = sprpal[col];
			    col = ((b1 & 0x20) >> 5) | ((b2 & 0x20) >> 4);
			    if (col) buf[sprx+5] = sprpal[col];
			    col = ((b1 & 0x10) >> 4) | ((b2 & 0x10) >> 3);
			    if (col) buf[sprx+4] = sprpal[col];
			    col = ((b1 & 0x08) >> 3) | ((b2 & 0x08) >> 2);
			    if (col) buf[sprx+3] = sprpal[col];
			    col = ((b1 & 0x04) >> 2) | ((b2 & 0x04) >> 1);
			    if (col) buf[sprx+2] = sprpal[col];
			    col = ((b1 & 0x02) >> 1) | ((b2 & 0x02) >> 0);
			    if (col) buf[sprx+1] = sprpal[col];
			    col = ((b1 & 0x01) >> 0) | ((b2 & 0x01) << 1);
			    if (col) buf[sprx+0] = sprpal[col];
			}
		    }
		}
	    }
	}
    }

    if (ioRAM[0x140] & 1) {
	/* draw background */

	/* work out tilemap to use */
	tmbase = &videoRAM[0x1800];
	if (ioRAM[0x140] & 8) {
	    tmbase += 0x400;
	}

	/* check bit 4 for which tileset */
	ts = ((ioRAM[0x140] & 0x10) ^ 0x10) << 4;

	/* work out which row we're doing */
	row = line + ioRAM[0x142];
	row &= 255;
	trow = row >> 3;
	rwt = ((row & 7) << 1);
	tmbase += (trow << 5);

	tcol = (ioRAM[0x143] >> 3);
	p = &buf[8];

	for (i = 0; i < 21; i++) {
	    tile = tmbase[tcol];
	    tcol++;
	    tcol &= 31;

	    if (tile < 128) tile |= ts;
      
	    b1 = videoRAM[rwt+tile*16];
	    b2 = videoRAM[rwt+tile*16+1];

	    col = ((b1 & 0x80) >> 7) | ((b2 & 0x80) >> 6);
	    if (col) p[0] = screenState.bgPalette[col];
	    col = ((b1 & 0x40) >> 6) | ((b2 & 0x40) >> 5);
	    if (col) p[1] = screenState.bgPalette[col];
	    col = ((b1 & 0x20) >> 5) | ((b2 & 0x20) >> 4);
	    if (col) p[2] = screenState.bgPalette[col];
	    col = ((b1 & 0x10) >> 4) | ((b2 & 0x10) >> 3);
	    if (col) p[3] = screenState.bgPalette[col];
	    col = ((b1 & 0x08) >> 3) | ((b2 & 0x08) >> 2);
	    if (col) p[4] = screenState.bgPalette[col];
	    col = ((b1 & 0x04) >> 2) | ((b2 & 0x04) >> 1);
	    if (col) p[5] = screenState.bgPalette[col];
	    col = ((b1 & 0x02) >> 1) | ((b2 & 0x02) >> 0);
	    if (col) p[6] = screenState.bgPalette[col];
	    col = ((b1 & 0x01) >> 0) | ((b2 & 0x01) << 1);
	    if (col) p[7] = screenState.bgPalette[col];

	    p += 8;
	}
    }
    if (ioRAM[0x140] & 0x20) {
	int wx, wy, ww;
	/* window goes at wx-7, wy, not scrollable */
	/* draw window */

	wy = ioRAM[0x14a];
	wx = ioRAM[0x14b];

	if ((wx < 167) && (wy < 144) && (line >= wy)) {

	    row = line - wy;

	    wx = (wx - 7) + 8 + (ioRAM[0x143] & 7);

	    ww = (176 - wx) >> 3;

	    /* work out tilemap to use */
	    tmbase = &videoRAM[0x1800];
	    if (ioRAM[0x140] & 0x40) {
		tmbase += 0x400;
	    }
      
	    /* check bit 4 for which tileset */
	    ts = ((ioRAM[0x140] & 0x10) ^ 0x10) << 4;
      
	    trow = row >> 3;
	    rwt = ((row & 7) << 1);
	    tmbase += (trow << 5);

	    for (i = 0; i < ww; i++) {
		tile = tmbase[i];

		if (tile < 128) tile |= ts;
      
		b1 = videoRAM[rwt+tile*16];
		b2 = videoRAM[rwt+tile*16+1];

		col = ((b1 & 0x80) >> 7) | ((b2 & 0x80) >> 6);
		buf[wx] = screenState.bgPalette[col];
		col = ((b1 & 0x40) >> 6) | ((b2 & 0x40) >> 5);
		buf[wx+1] = screenState.bgPalette[col];
		col = ((b1 & 0x20) >> 5) | ((b2 & 0x20) >> 4);
		buf[wx+2] = screenState.bgPalette[col];
		col = ((b1 & 0x10) >> 4) | ((b2 & 0x10) >> 3);
		buf[wx+3] = screenState.bgPalette[col];
		col = ((b1 & 0x08) >> 3) | ((b2 & 0x08) >> 2);
		buf[wx+4] = screenState.bgPalette[col];
		col = ((b1 & 0x04) >> 2) | ((b2 & 0x04) >> 1);
		buf[wx+5] = screenState.bgPalette[col];
		col = ((b1 & 0x02) >> 1) | ((b2 & 0x02) >> 0);
		buf[wx+6] = screenState.bgPalette[col];
		col = ((b1 & 0x01) >> 0) | ((b2 & 0x01) << 1);
		buf[wx+7] = screenState.bgPalette[col];

		wx += 8;
	    }
	}
    }

    /* FIXME: sprite priorities will be wrong... but same as CGB... */
    /* draw sprites in front of background */
    if (ioRAM[0x140] & 0x2) {
	int sprh = 8;
	int sprx, spry, sprt, sprf;
	unsigned int *sprpal;

	/* work out palettes for sprites */
	/*opal1[1] = (ioRAM[0x148] >> 2) & 3;
	  opal1[2] = (ioRAM[0x148] >> 4) & 3;
	  opal1[3] = (ioRAM[0x148] >> 6) & 3;
	  opal2[1] = (ioRAM[0x149] >> 2) & 3;
	  opal2[2] = (ioRAM[0x149] >> 4) & 3;
	  opal2[3] = (ioRAM[0x149] >> 6) & 3;*/

	if (ioRAM[0x140] & 4) sprh = 16;

	/* draw sprites */
	for (i = 0; i < 40; i++) {
	    if (sprol == 10) break;

	    sprf = ioRAM[i*4+3];
	    if (!(sprf & 0x80)) {
		spry = ioRAM[i*4] - 16;
		if ((spry <= line) && ((spry+sprh) > line)) {
		    sprol++;
	  
		    sprx = ioRAM[i*4+1];
		    if ((sprx != 0) && (sprx < 168)) {
			sprx += (ioRAM[0x143] & 7);
			sprt = ioRAM[i*4+2];
			if (sprh == 16) sprt &= 0xfe;
	    
			sprpal = &screenState.sprPalette0[0];
			if (sprf & 0x10) sprpal = &screenState.sprPalette1[0];
	    
			rwt = line - spry;
			if (sprf & 0x40) rwt = (sprh - 1) - rwt;
	    
			b1 = videoRAM[(rwt << 1) + (sprt << 4)];
			b2 = videoRAM[(rwt << 1) + (sprt << 4) + 1];
	    
			if (!(sprf & 0x20)) {
			    col = ((b1 & 0x80) >> 7) | ((b2 & 0x80) >> 6);
			    if (col) buf[sprx] = sprpal[col];
			    col = ((b1 & 0x40) >> 6) | ((b2 & 0x40) >> 5);
			    if (col) buf[sprx+1] = sprpal[col];
			    col = ((b1 & 0x20) >> 5) | ((b2 & 0x20) >> 4);
			    if (col) buf[sprx+2] = sprpal[col];
			    col = ((b1 & 0x10) >> 4) | ((b2 & 0x10) >> 3);
			    if (col) buf[sprx+3] = sprpal[col];
			    col = ((b1 & 0x08) >> 3) | ((b2 & 0x08) >> 2);
			    if (col) buf[sprx+4] = sprpal[col];
			    col = ((b1 & 0x04) >> 2) | ((b2 & 0x04) >> 1);
			    if (col) buf[sprx+5] = sprpal[col];
			    col = ((b1 & 0x02) >> 1) | ((b2 & 0x02) >> 0);
			    if (col) buf[sprx+6] = sprpal[col];
			    col = ((b1 & 0x01) >> 0) | ((b2 & 0x01) << 1);
			    if (col) buf[sprx+7] = sprpal[col];
			}
			else {
			    col = ((b1 & 0x80) >> 7) | ((b2 & 0x80) >> 6);
			    if (col) buf[sprx+7] = sprpal[col];
			    col = ((b1 & 0x40) >> 6) | ((b2 & 0x40) >> 5);
			    if (col) buf[sprx+6] = sprpal[col];
			    col = ((b1 & 0x20) >> 5) | ((b2 & 0x20) >> 4);
			    if (col) buf[sprx+5] = sprpal[col];
			    col = ((b1 & 0x10) >> 4) | ((b2 & 0x10) >> 3);
			    if (col) buf[sprx+4] = sprpal[col];
			    col = ((b1 & 0x08) >> 3) | ((b2 & 0x08) >> 2);
			    if (col) buf[sprx+3] = sprpal[col];
			    col = ((b1 & 0x04) >> 2) | ((b2 & 0x04) >> 1);
			    if (col) buf[sprx+2] = sprpal[col];
			    col = ((b1 & 0x02) >> 1) | ((b2 & 0x02) >> 0);
			    if (col) buf[sprx+1] = sprpal[col];
			    col = ((b1 & 0x01) >> 0) | ((b2 & 0x01) << 1);
			    if (col) buf[sprx+0] = sprpal[col];
			}
		    }
		}
	    }
	}
    }

    memcpy(dest, &buf[8 + (ioRAM[0x143] & 7)], 160*4);
}

void GB_getScreenPixels(unsigned int *screen)
{
    unsigned int *s, *p;
    int i, j, k;
    unsigned char *tilemap, *tileptr;
    unsigned char tile;
    unsigned char b1, b2, col;

    //s = (unsigned int *)(*env)->GetIntArrayElements(env, screen, NULL);
    s = screen;

    if (!(ioRAM[0x140] & 128)) {
	/* screen disabled */
	for (i = 0; i < (160*144); i++) {
	    s[i] = screenState.colours[0];
	}
    }
    else {
	p = s;
	for (i = 0; i < 144; i++) {
	    //renderLine(i, p);
	    memcpy(p, &screenState.screenBuffer[(i << 8) + (screenState.lineScrolls[i] & 7) + 8], 640);
	    p += 160;
	}

#if 0
	tilemap = &videoRAM[0x1c00];
    
	for (i = 0; i < 18; i++) {
	    p = &s[i * 8 * 160];
      
	    for (j = 0; j < 20; j++) {
	
		tile = *tilemap;
	
		//tile = (i * 20) + j;
	
		tilemap++;
	
		tileptr = &videoRAM[tile*16];
	
		for (k = 0; k < 8; k++) {
		    b1 = tileptr[0];
		    b2 = tileptr[1];
		    tileptr += 2;
	  
		    col = ((b1 & 0x80) >> 7) | ((b2 & 0x80) >> 6);
		    *p++ = colours[col];
		    col = ((b1 & 0x40) >> 6) | ((b2 & 0x40) >> 5);
		    *p++ = colours[col];
		    col = ((b1 & 0x20) >> 5) | ((b2 & 0x20) >> 4);
		    *p++ = colours[col];
		    col = ((b1 & 0x10) >> 4) | ((b2 & 0x10) >> 3);
		    *p++ = colours[col];
		    col = ((b1 & 0x08) >> 3) | ((b2 & 0x08) >> 2);
		    *p++ = colours[col];
		    col = ((b1 & 0x04) >> 2) | ((b2 & 0x04) >> 1);
		    *p++ = colours[col];
		    col = ((b1 & 0x02) >> 1) | ((b2 & 0x02) >> 0);
		    *p++ = colours[col];
		    col = ((b1 & 0x01) >> 0) | ((b2 & 0x01) << 1);
		    *p++ = colours[col];
	  
		    p += 152;
		}
		p -= 1272;
	    }
	    tilemap += 12;
	}
#endif
    }

    //(*env)->ReleaseIntArrayElements(env, screen, (jint *)s, 0);    
}

// FIXME: port snapshot functions if needed
#if 0
/*
 * Snapshot info required:
 *
 * All Z80 registers
 * Divider and timer counters
 * Paging registers
 *
 * VRAM contents
 * Cart RAM contents
 * Internal RAM contents
 * I/O Register and zero page contents
 * Sprite RAM contents
 * 
 * Other video and sound state can be regenerated from register contents
 *
 * 57881 bytes required
 */
void
Java_uk_org_gcat_gameboy_GcatGameboyApp_getSnapshotData( JNIEnv* env,
							 jobject thiz,
							 jbyteArray snapshot,
							 jint idx)
{
    unsigned char *s;
    s = (unsigned char *)(*env)->GetByteArrayElements(env, snapshot, NULL);
    s += idx;

    /* CPU state */
    s[0] = z80State.af & 0xff;
    s[1] = (z80State.af >> 8) & 0xff;
    s[2] = z80State.bc & 0xff;
    s[3] = (z80State.bc >> 8) & 0xff;
    s[4] = z80State.de & 0xff;
    s[5] = (z80State.de >> 8) & 0xff;
    s[6] = z80State.hl & 0xff;
    s[7] = (z80State.hl >> 8) & 0xff;
    s[8] = z80State.sp & 0xff;
    s[9] = (z80State.sp >> 8) & 0xff;
    s[10] = z80State.pc & 0xff;
    s[11] = (z80State.pc >> 8) & 0xff;
    s[12] = z80State.iff1;

    /* General hardware state */
    s[13] = z80State.dividerCounter & 0xff;
    s[14] = (z80State.dividerCounter >> 8) & 0xff;
    s[15] = (z80State.dividerCounter >> 16) & 0xff;
    s[16] = (z80State.dividerCounter >> 24) & 0xff;

    s[17] = z80State.timerCounter & 0xff;
    s[18] = (z80State.timerCounter >> 8) & 0xff;
    s[19] = (z80State.timerCounter >> 16) & 0xff;
    s[20] = (z80State.timerCounter >> 24) & 0xff;

    s[21] = z80State.pagingRegs[0];
    s[22] = z80State.pagingRegs[1];
    s[23] = z80State.pagingRegs[2];
    s[24] = z80State.pagingRegs[3];

    /* RAMs */
    memcpy(&s[25], videoRAM, 8192);
    memcpy(&s[25+8192], cartridgeRAM, 32768);
    memcpy(&s[25+40960], internalRAM, 16384);
    memcpy(&s[25+57344], ioRAM, 512);

    s -= idx;
    (*env)->ReleaseByteArrayElements(env, snapshot, (jbyte *)s, 0);
}

/* the correct ROM should already be loaded when this is called */
void
Java_uk_org_gcat_gameboy_GcatGameboyApp_setSnapshotData( JNIEnv* env,
							 jobject thiz,
							 jbyteArray snapshot,
							 jint idx)
{
    unsigned char *s;
    int rompage, rampage;
  
    s = (unsigned char *)(*env)->GetByteArrayElements(env, snapshot, NULL);
    s += idx;

    /* Restore CPU state */
    z80State.af = s[0] | (s[1] << 8);
    z80State.bc = s[2] | (s[3] << 8);
    z80State.de = s[4] | (s[5] << 8);
    z80State.hl = s[6] | (s[7] << 8);
    z80State.sp = s[8] | (s[9] << 8);
    z80State.pc = s[10] | (s[11] << 8);
    z80State.iff1 = s[12];
    z80State.iff2 = s[12];

    /* Restore general machine state */
    z80State.dividerCounter = s[13] | (s[14] << 8) | (s[15] << 16) |
	(s[16] << 24);
    z80State.timerCounter = s[17] | (s[18] << 8) | (s[19] << 16) |
	(s[20] << 24);
    z80State.pagingRegs[0] = s[21];
    z80State.pagingRegs[1] = s[22];
    z80State.pagingRegs[2] = s[23];
    z80State.pagingRegs[3] = s[24];

    /* Restore RAMs */
    memcpy(videoRAM, &s[25], 8192);
    memcpy(cartridgeRAM, &s[25+8192], 32768);
    memcpy(internalRAM, &s[25+40960], 16384);
    memcpy(ioRAM, &s[25+57344], 512);

    /*
     * Calculate other z80State members:
     *  - page table
     *  - timer increment
     *  - int pending?
     *  - tstates
     */
    if (ioRAM[0x10f] & ioRAM[0x1ff]) z80State.intPending = 0xff;
    z80State.tstates = -80;
    switch (ioRAM[0x107] & 3) {
    case 0:
	z80State.timerIncrement = 0x710000;
	break;
    case 1:
	z80State.timerIncrement = 0x1c000000;
	break;
    case 2:
	z80State.timerIncrement = 0x7000000;
	break;
    case 3:
	z80State.timerIncrement = 0x1c50000;
	break;
    }
    /*
     * Page tables: only second ROM read (entries 2 and 3),
     * cartridge RAM read (5) and cartridge RAM write (13)
     * need to be changed here
     */
    switch (z80State.mbcType) {
    case 0:
	/* no MBC - default mappings are fine */
	rompage = 1;
	rampage = 0;
	break;
    case 1:
	rampage = 0;
	rompage = z80State.pagingRegs[1] & 0x1f;
	if (!rompage) rompage++;
	if (z80State.pagingRegs[3]) {
	    rampage = z80State.pagingRegs[2] & 3;
	}
	else {
	    rompage |= ((z80State.pagingRegs[2] & 3) << 5);
	}
	break;
    case 2:
	/* MBC 2 - just ROM switching */
	rompage = z80State.pagingRegs[1] & 0xf;
	if (!rompage) rompage++;
	rampage = 0;
	break;
    case 3:
	rompage = z80State.pagingRegs[1] & (z80State.romSize - 1);
	rampage = z80State.pagingRegs[2] & (z80State.ramSize - 1);
	break;
    }
    pageTable[2] = &cartridgeROM[rompage << 14];
    pageTable[3] = &cartridgeROM[(rompage << 14) + 0x2000];
    pageTable[5] = &cartridgeRAM[rampage << 13];
    pageTable[13] = &cartridgeRAM[rampage << 13];

    /*
     * Calculate screenState members:
     *  - scanline
     *  - vdpMode
     *  - the 3 palettes
     */
    screenState.scanline = 0;
    screenState.vdpMode = 2;
  
    screenState.bgPalette[0] = screenState.colours[ioRAM[0x147] & 3];
    screenState.bgPalette[1] = screenState.colours[(ioRAM[0x147] >> 2) & 3];
    screenState.bgPalette[2] = screenState.colours[(ioRAM[0x147] >> 4) & 3];
    screenState.bgPalette[3] = screenState.colours[(ioRAM[0x147] >> 6) & 3];

    screenState.sprPalette0[0] = screenState.colours[ioRAM[0x148] & 3];
    screenState.sprPalette0[1] = screenState.colours[(ioRAM[0x148] >> 2) & 3];
    screenState.sprPalette0[2] = screenState.colours[(ioRAM[0x148] >> 4) & 3];
    screenState.sprPalette0[3] = screenState.colours[(ioRAM[0x148] >> 6) & 3];

    screenState.sprPalette1[0] = screenState.colours[ioRAM[0x149] & 3];
    screenState.sprPalette1[1] = screenState.colours[(ioRAM[0x149] >> 2) & 3];
    screenState.sprPalette1[2] = screenState.colours[(ioRAM[0x149] >> 4) & 3];
    screenState.sprPalette1[3] = screenState.colours[(ioRAM[0x149] >> 6) & 3];

    /*
     * Calculate soundState members:
     *  - channel 1
     *  - channel 2
     *  - channel 3
     *  - channel 4
     */
    /* FIXME: do it */

    s -= idx;

    (*env)->ReleaseByteArrayElements(env, snapshot, (jbyte *)s, 0);
}
#endif
