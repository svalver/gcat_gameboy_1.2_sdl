CFLAGS+=-DSTANDALONE -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS -DTARGET_POSIX -D_LINUX -fPIC -DPIC -D_REENTRANT -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -U_FORTIFY_SOURCE -Wall -g -DHAVE_LIBOPENMAX=2 -DOMX -DOMX_SKIP64BIT -ftree-vectorize -pipe -DUSE_EXTERNAL_OMX -DHAVE_LIBBCM_HOST -DUSE_EXTERNAL_LIBBCM_HOST -DUSE_VCHIQ_ARM -Wno-psabi -I$(SDKSTAGE)/opt/vc/include/

LDFLAGS+=-L$(SDKSTAGE)/opt/vc/lib/ -lGLESv2 -lEGL -lSDL -lopenmaxil -lbcm_host /opt/vc/src/hello_pi/libs/ilclient/libilclient.a

INCLUDES+=-I$(SDKSTAGE)/opt/vc/include/ -I./ -I/opt/vc/src/hello_pi/libs/ilclient -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux

all: gameboy

gameboy: emulator.o z80.o gameboy.o
	gcc -o gameboy emulator.o z80.o gameboy.o $(LDFLAGS)

gameboy_sdl: emulator_sdl.o z80.o gameboy.o
	gcc -o gameboy_sdl emulator_sdl.o z80.o gameboy.o $(LDFLAGS)

emulator.o: emulator.c
	gcc -c -o emulator.o emulator.c $(INCLUDES) $(CFLAGS)

emulator_sdl.o: emulator_sdl.c
	gcc -c -o emulator_sdl.o emulator_sdl.c $(INCLUDES) $(CFLAGS)

gameboy.o: gameboy.c
	gcc -c -o gameboy.o gameboy.c

z80.o: z80.S
	gcc -c -o z80.o z80.S
