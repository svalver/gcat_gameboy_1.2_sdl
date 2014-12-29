GCat's Gameboy Emulator (Raspberry Pi version)
==============================================
This emulator was originally written for Android; you can download the Android
version from my website (http://www.gcat.org.uk/emul/) if you're interested in
that. It's a very basic emulator, it doesn't have many features and it's only
been tested with a few games so there are probably still bugs.


License
-------
This code is released under version 3 of the GPL. See the COPYING file for
details. Some of the hardware setup code in emulator.c is taken from the
Raspberry Pi example programs which are under the Apache license.


Compilation Instructions
------------------------
If you are running the standard Raspbian OS, you should be able to just change
to the directory where you unpacked the source code and type "make". If all
goes well, the code should compile pretty quickly and generate an executable
called "gameboy". (The Makefile for the old Debian Squeeze distro is still
there as Makefile.squeeze just in case you're using it for some reason).

If you get an error while compiling, you may need to first build the ilclient
library. To do this:

 cd /opt/vc/src/hello_pi/libs/ilclient/
 make

I haven't tested on any other Linux distributions so I don't know whether it
works on them or not, but it shouldn't be too hard to get working. In addition
to the standard Linux build tools (GNU Make, GCC, etc.) the only things the
code depends on are the Raspberry Pi libraries from Broadcom. These are
installed in /opt/vc on Debian; if they're in a different location you'll need
to edit the Makefile and change any paths in there that refer to them.


Running the Emulator
--------------------
You need game ROMs in .gb format to run on the emulator. You can find plenty
of them online but bear in mind it's probably illegal to download them unless
you own the original game cartridges.

You can start the emulator from the command prompt and pass it the name of the
game you want to play, e.g.:

  ./gameboy tetris.gb

By default the sound will be output to the analogue socket. If you want it to
go to the HDMI port instead, use the '-h' switch:

  ./gameboy -h tetris.gb

(Note that this is the opposite way round from in the original release. I
discovered that trying to output to HDMI when it's not plugged in can crash
the emulator, so this way is safer).

Once the game is running, the keys are as follows:

 Arrow keys - emulate the Gameboy controller's D-pad
 A & S      - emulate the Gameboy controller's A and B buttons
 Space      - emulates the Start button
 Enter      - emulates the Select button
 Escape     - exits the emulator

Please note: the emulator will NOT work under X Windows at present. This is
because it uses raw keyboard input and that only works from a real terminal,
not a terminal window. I hope to solve this at some point by using a different
method to get input when X is running, but for now, don't run startx before you
run the emulator.


Reporting Bugs
--------------
You're welcome to send bug reports and feature requests to me at:

  emulators@gcat.org.uk

but bear in mind that I only play with these in my spare time, so I might not
get round to doing anything with them for a while (or ever!). I don't plan to
add any major new features but I might change my mind if I suddenly feel a
surge of enthusiasm ;).


Notes on the code
-----------------
The code consists of 2 C source files and 4 ARM assembly (.S) files. The
assembly code probably isn't really necessary, I expect it would be possible to
make it go fast enough in C, but when I first started Android app development
I was keen to learn about the ARM architecture, so I wanted to write some
assembly code anyway :). When I start coding for a new platform, I like to
understand what's really going on down at the low level. So I wouldn't recommend
this as a shining example of how to write an emulator, but here's the code
anyway in case you're interested.

emulator.c     - contains 'main', and also all the code for interfacing with
	       	 the Raspberry Pi's sound and graphics hardware. Some routines
		 here are taken from the sample programs. The code to set change
		 the keyboard settings so we can detect multiple key presses at
		 once is also in here. Although it's only showing a 2D image,
		 the code uses OpenGL ES 2 for the display, loading each frame
		 of the Gameboy screen into a texture and then drawing it as two
		 textured triangles.

gameboy.c      - contains the top level of the actual emulator code. This was
	         ported from Android native code using the Java Native
		 Interface, so some of it might not be done the way you'd
		 expect. This module declares most of the emulator's data
		 structures and interfaces with the assembly code.

z80*.S         - these are the CPU core. The entry point is at the label called
	         asmExecute. z80.S is the main part of the core, z80cb.S is
		 #included into it and handles instructions with the CB prefix.
		 (The Gameboy's CPU wasn't actually a real Z80 but a cut down
		 version. This code is adapted from the Z80 core in my Master
		 System emulator though).

render.S       - assembly code to render a single scanline of the Gameboy
	       	 screen into a buffer. There is a C version of this in gameboy.c
		 if you want to look at how it works. This code isn't actually
		 linked in, but is #included into the CPU core to avoid the
		 calling overhead.

soundgen.S     - assembly code to generate a sample of sound output from the
	       	 Gameboy's sound chip. The sample rate is set so that one sample
		 is generated for each scanline of the display, which makes the
		 code simpler. Again this file is #included into the CPU core.


Changelog
---------

1.2 - 20/03/2013 - updated Makefile to work with newest Raspbian
1.1 - 04/09/2012 - updated Makefile to work with Raspbian
      made analogue audio the default
1.0 - 14/05/2012 - original release
