Gamepad/joystick support for GCat's Gameboy Emulator (Rasperry Pi)
==================================================================

The emulator was originally writen by GCat (website: http://www.gcat.org.uk/emul/, e-mail: emulators@gcat.org.uk ). It is a well-written emulator with some specific parts written in assembler, optimized for speed. Here I have replaced the keyboard functions by some SDL 1.2 calls. The main loop (emulator_sdl.c) polls the joystick state continuously (without event processing) and sets the emulated gameboy controller.

License
-------
This code is released under the same (original) version 3 of the GPL. See the COPYING file fordetails. Some of the hardware setup code in emulator.c is taken from the
Raspberry Pi example programs which are under the Apache license.


Compilation Instructions
------------------------
If you are running the standard Raspbian OS, you should be able to just change
to the directory where you unpacked the source code and type "make". If all
goes well, the code should compile pretty quickly and generate an executable
called "gameboy" (keyboard) or "gameboy_sdl" (joystick/gamepad).


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

Notice that trying to output to HDMI when it's not plugged in can crash
the emulator.