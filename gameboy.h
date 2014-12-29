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

#ifndef _GAMEBOY_H_
#define _GAMEBOY_H_

int GB_startup();
void GB_setCartridgeRAMContents(unsigned char *ram);
void GB_getCartridgeRAMContents(unsigned char *ram);
int GB_loadROM(char *filename);
int GB_execute();
void GB_setJoypadState(int jps);
void GB_getAudioData(unsigned char *audio);
void GB_getScreenPixels(unsigned int *screen);

#endif
