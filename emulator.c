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
#include <math.h>
#include <assert.h>

#include <unistd.h>
#include <linux/kd.h>
#include <termios.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <semaphore.h>

#include "bcm_host.h"
#include "ilclient.h"

#include "GLES/gl.h"
#include "EGL/egl.h"
#include "EGL/eglext.h"

#include "gameboy.h"


/*==============================================================================
 *
 * Audio output
 *
 * This code taken from the Raspberry Pi example programs, used under Apache
 * license:
 *
 * Copyright (c) 2012 Broadcom Europe Ltd
 *
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 *============================================================================*/
#ifndef countof
   #define countof(arr) (sizeof(arr) / sizeof(arr[0]))
#endif

#define BUFFER_SIZE_SAMPLES 308

typedef int int32_t;

typedef struct {
   sem_t sema;
   ILCLIENT_T *client;
   COMPONENT_T *audio_render;
   COMPONENT_T *list[2];
   OMX_BUFFERHEADERTYPE *user_buffer_list; // buffers owned by the client
   uint32_t num_buffers;
   uint32_t bytes_per_sample;
} AUDIOPLAY_STATE_T;

static void input_buffer_callback(void *data, COMPONENT_T *comp)
{
   // do nothing - could add a callback to the user
   // to indicate more buffers may be available.
}

int32_t audioplay_create(AUDIOPLAY_STATE_T **handle,
                         uint32_t sample_rate,
                         uint32_t num_channels,
                         uint32_t bit_depth,
                         uint32_t num_buffers,
                         uint32_t buffer_size)
{
   uint32_t bytes_per_sample = (bit_depth * num_channels) >> 3;
   int32_t ret = -1;
 
   *handle = NULL;

   // basic sanity check on arguments   
   if(sample_rate >= 8000 && sample_rate <= 96000 &&
      (num_channels == 1 || num_channels == 2 || num_channels == 4 || num_channels == 8) &&
      (bit_depth == 16 || bit_depth == 32) &&
      num_buffers > 0 &&
      buffer_size >= bytes_per_sample)
   {
      // buffer lengths must be 16 byte aligned for VCHI
      int size = (buffer_size + 15) & ~15;
      AUDIOPLAY_STATE_T *st;

      // buffer offsets must also be 16 byte aligned for VCHI
      st = calloc(1, sizeof(AUDIOPLAY_STATE_T));

      if(st)
      {
         OMX_ERRORTYPE error;
         OMX_PARAM_PORTDEFINITIONTYPE param;
         OMX_AUDIO_PARAM_PCMMODETYPE pcm;
         int32_t s;

         ret = 0;
         *handle = st;

         // create and start up everything
         s = sem_init(&st->sema, 0, 1);
         assert(s == 0);

         st->bytes_per_sample = bytes_per_sample;
         st->num_buffers = num_buffers;

         st->client = ilclient_init();
         assert(st->client != NULL);

         ilclient_set_empty_buffer_done_callback(st->client, input_buffer_callback, st);
         
         error = OMX_Init();
         assert(error == OMX_ErrorNone);            
         
         ilclient_create_component(st->client, &st->audio_render, "audio_render", ILCLIENT_ENABLE_INPUT_BUFFERS | ILCLIENT_DISABLE_ALL_PORTS);
         assert(st->audio_render != NULL);
         
         st->list[0] = st->audio_render;

         // set up the number/size of buffers
         memset(&param, 0, sizeof(OMX_PARAM_PORTDEFINITIONTYPE));
         param.nSize = sizeof(OMX_PARAM_PORTDEFINITIONTYPE);
         param.nVersion.nVersion = OMX_VERSION;
         param.nPortIndex = 100;
         
         error = OMX_GetParameter(ILC_GET_HANDLE(st->audio_render), OMX_IndexParamPortDefinition, &param);
         assert(error == OMX_ErrorNone);
         
         param.nBufferSize = size;
         param.nBufferCountActual = num_buffers;

         error = OMX_SetParameter(ILC_GET_HANDLE(st->audio_render), OMX_IndexParamPortDefinition, &param);
         assert(error == OMX_ErrorNone);

         // set the pcm parameters
         memset(&pcm, 0, sizeof(OMX_AUDIO_PARAM_PCMMODETYPE));
         pcm.nSize = sizeof(OMX_AUDIO_PARAM_PCMMODETYPE);
         pcm.nVersion.nVersion = OMX_VERSION;
         pcm.nPortIndex = 100;
         pcm.nChannels = num_channels;
         pcm.eNumData = OMX_NumericalDataSigned;
         pcm.eEndian = OMX_EndianLittle;
         pcm.nSamplingRate = sample_rate;
         pcm.bInterleaved = OMX_TRUE;
         pcm.nBitPerSample = bit_depth;
         pcm.ePCMMode = OMX_AUDIO_PCMModeLinear;

         switch(num_channels) {
         case 1:
            pcm.eChannelMapping[0] = OMX_AUDIO_ChannelCF;
            break;
         case 8:
            pcm.eChannelMapping[0] = OMX_AUDIO_ChannelLF;
            pcm.eChannelMapping[1] = OMX_AUDIO_ChannelRF;
            pcm.eChannelMapping[2] = OMX_AUDIO_ChannelCF;
            pcm.eChannelMapping[3] = OMX_AUDIO_ChannelLFE;
            pcm.eChannelMapping[4] = OMX_AUDIO_ChannelLR;
            pcm.eChannelMapping[5] = OMX_AUDIO_ChannelRR;
            pcm.eChannelMapping[6] = OMX_AUDIO_ChannelLS;
            pcm.eChannelMapping[7] = OMX_AUDIO_ChannelRS;
            break;
         case 4:
            pcm.eChannelMapping[0] = OMX_AUDIO_ChannelLF;
            pcm.eChannelMapping[1] = OMX_AUDIO_ChannelRF;
            pcm.eChannelMapping[2] = OMX_AUDIO_ChannelLR;
            pcm.eChannelMapping[3] = OMX_AUDIO_ChannelRR;
            break;
         case 2:
            pcm.eChannelMapping[0] = OMX_AUDIO_ChannelLF;
            pcm.eChannelMapping[1] = OMX_AUDIO_ChannelRF;
            break;
         }

         error = OMX_SetParameter(ILC_GET_HANDLE(st->audio_render), OMX_IndexParamAudioPcm, &pcm);
         assert(error == OMX_ErrorNone);

         ilclient_change_component_state(st->audio_render, OMX_StateIdle);
         if(ilclient_enable_port_buffers(st->audio_render, 100, NULL, NULL, NULL) < 0)
         {
            // error
            ilclient_change_component_state(st->audio_render, OMX_StateLoaded);
            ilclient_cleanup_components(st->list);

            error = OMX_Deinit();
            assert(error == OMX_ErrorNone);
            
            ilclient_destroy(st->client);
            
            sem_destroy(&st->sema);
            free(st);
            *handle = NULL;
            return -1;
         }

         ilclient_change_component_state(st->audio_render, OMX_StateExecuting);
      }
   }

   return ret;
}

int32_t audioplay_delete(AUDIOPLAY_STATE_T *st)
{
   OMX_ERRORTYPE error;

   ilclient_change_component_state(st->audio_render, OMX_StateIdle);

   error = OMX_SendCommand(ILC_GET_HANDLE(st->audio_render), OMX_CommandStateSet, OMX_StateLoaded, NULL);
   assert(error == OMX_ErrorNone);

   ilclient_disable_port_buffers(st->audio_render, 100, st->user_buffer_list, NULL, NULL);
   ilclient_change_component_state(st->audio_render, OMX_StateLoaded);
   ilclient_cleanup_components(st->list);

   error = OMX_Deinit();
   assert(error == OMX_ErrorNone);

   ilclient_destroy(st->client);

   sem_destroy(&st->sema);
   free(st);

   return 0;
}

uint8_t *audioplay_get_buffer(AUDIOPLAY_STATE_T *st)
{
   OMX_BUFFERHEADERTYPE *hdr = NULL;

   hdr = ilclient_get_input_buffer(st->audio_render, 100, 0);

   if(hdr)
   {
      // put on the user list
      sem_wait(&st->sema);

      hdr->pAppPrivate = st->user_buffer_list;
      st->user_buffer_list = hdr;

      sem_post(&st->sema);
   }

   return hdr ? hdr->pBuffer : NULL;
}

int32_t audioplay_play_buffer(AUDIOPLAY_STATE_T *st,
                              uint8_t *buffer,
                              uint32_t length)
{
   OMX_BUFFERHEADERTYPE *hdr = NULL, *prev = NULL;
   int32_t ret = -1;

   if(length % st->bytes_per_sample)
      return ret;

   sem_wait(&st->sema);

   // search through user list for the right buffer header
   hdr = st->user_buffer_list;
   while(hdr != NULL && hdr->pBuffer != buffer && hdr->nAllocLen < length)
   {
      prev = hdr;
      hdr = hdr->pAppPrivate;
   }

   if(hdr) // we found it, remove from list
   {
      ret = 0;
      if(prev)
         prev->pAppPrivate = hdr->pAppPrivate;
      else
         st->user_buffer_list = hdr->pAppPrivate;
   }

   sem_post(&st->sema);

   if(hdr)
   {
      OMX_ERRORTYPE error;

      hdr->pAppPrivate = NULL;
      hdr->nOffset = 0;
      hdr->nFilledLen = length;
     
      error = OMX_EmptyThisBuffer(ILC_GET_HANDLE(st->audio_render), hdr);
      assert(error == OMX_ErrorNone);   
   }

   return ret;   
}

int32_t audioplay_set_dest(AUDIOPLAY_STATE_T *st, const char *name)
{
   int32_t success = -1;
   OMX_CONFIG_BRCMAUDIODESTINATIONTYPE ar_dest;

   if (name && strlen(name) < sizeof(ar_dest.sName))
   {
      OMX_ERRORTYPE error;
      memset(&ar_dest, 0, sizeof(ar_dest));
      ar_dest.nSize = sizeof(OMX_CONFIG_BRCMAUDIODESTINATIONTYPE);
      ar_dest.nVersion.nVersion = OMX_VERSION;
      strcpy((char *)ar_dest.sName, name);

      error = OMX_SetConfig(ILC_GET_HANDLE(st->audio_render), OMX_IndexConfigBrcmAudioDestination, &ar_dest);
      assert(error == OMX_ErrorNone);
      success = 0;
   }

   return success;
}


uint32_t audioplay_get_latency(AUDIOPLAY_STATE_T *st)
{
   OMX_PARAM_U32TYPE param;
   OMX_ERRORTYPE error;

   memset(&param, 0, sizeof(OMX_PARAM_U32TYPE));
   param.nSize = sizeof(OMX_PARAM_U32TYPE);
   param.nVersion.nVersion = OMX_VERSION;
   param.nPortIndex = 100;

   error = OMX_GetConfig(ILC_GET_HANDLE(st->audio_render), OMX_IndexConfigAudioRenderingLatency, &param);
   assert(error == OMX_ErrorNone);

   return param.nU32;
}

/*==============================================================================
 *
 * Graphics output stuff
 *
 * Some of this also taken from example codes, see above comment block for
 * license information.
 *
 *============================================================================*/

static unsigned int screen_width, screen_height;
static EGLDisplay display;
static EGLSurface surface;
static EGLContext context;

static GLuint tex;
static unsigned char *img;

/*
 * OpenGL ES doesn't support quads so we draw two triangles instead
 */
static GLfloat quadCoords[6 * 3] = {
    0.0, 0.0, 0.5,
    1920.0, 0.0, 0.5,
    1920.0, 1080.0, 0.5,

    0.0, 0.0, 0.5,
    1920.0, 1080.0, 0.5,
    0.0, 1080.0, 0.5
};

static const GLfloat texCoords[6 * 2] = {
   0.f,  1.f,
   1.f,  1.f,
   1.f,  0.f,

   0.f,  1.f,
   1.f,  0.f,
   0.f,  0.f
};

static int border_size = 100;

static void init_ogl()
{
    int32_t success = 0;
    EGLBoolean result;
    EGLint num_config;

    static EGL_DISPMANX_WINDOW_T nativewindow;

    DISPMANX_ELEMENT_HANDLE_T dispman_element;
    DISPMANX_DISPLAY_HANDLE_T dispman_display;
    DISPMANX_UPDATE_HANDLE_T dispman_update;
    VC_RECT_T dst_rect;
    VC_RECT_T src_rect;

    static const EGLint attribute_list[] ={
	EGL_RED_SIZE, 8,
	EGL_GREEN_SIZE, 8,
	EGL_BLUE_SIZE, 8,
	EGL_ALPHA_SIZE, 8,
	EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
	EGL_NONE
    };
   
    EGLConfig config;
    int lmargin, rmargin, tmargin, bmargin;
    int i, j;

    // get an EGL display connection
    display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    assert(display!=EGL_NO_DISPLAY);
   
    // initialize the EGL display connection
    result = eglInitialize(display, NULL, NULL);
    assert(EGL_FALSE != result);

    // get an appropriate EGL frame buffer configuration
    result = eglChooseConfig(display, attribute_list, &config, 1, &num_config);
    assert(EGL_FALSE != result);
    
    // create an EGL rendering context
    context = eglCreateContext(display, config, EGL_NO_CONTEXT, NULL);
    assert(context!=EGL_NO_CONTEXT);
    
    // create an EGL window surface
    success = graphics_get_display_size(0 /* LCD */, &screen_width, &screen_height);
    assert( success >= 0 );
    
    dst_rect.x = 0;
    dst_rect.y = 0;
    dst_rect.width = screen_width;
    dst_rect.height = screen_height;
    
    src_rect.x = 0;
    src_rect.y = 0;
    src_rect.width = screen_width << 16;
    src_rect.height = screen_height << 16;        
    
    dispman_display = vc_dispmanx_display_open( 0 /* LCD */);
    dispman_update = vc_dispmanx_update_start( 0 );
    
    dispman_element = vc_dispmanx_element_add ( dispman_update, dispman_display,
						0/*layer*/, &dst_rect, 0/*src*/,
						&src_rect, DISPMANX_PROTECTION_NONE, 0 /*alpha*/, 0/*clamp*/, 0/*transform*/);
    
    nativewindow.element = dispman_element;
    nativewindow.width = screen_width;
    nativewindow.height = screen_height;
    vc_dispmanx_update_submit_sync( dispman_update );
    
    surface = eglCreateWindowSurface( display, config, &nativewindow, NULL );
    assert(surface != EGL_NO_SURFACE);
    
    // connect the context to the surface
    result = eglMakeCurrent(display, surface, surface, context);
    assert(EGL_FALSE != result);
    
    // Set background color and clear buffers
    glClearColor(0.15f, 0.25f, 0.35f, 1.0f);
    glClear( GL_COLOR_BUFFER_BIT );
    glClear( GL_DEPTH_BUFFER_BIT );
    glShadeModel(GL_FLAT);
    
    // Enable back face culling.
    glEnable(GL_CULL_FACE);

    /* work out co-ordinates to draw to based on screen resolution */
    border_size = screen_width / 20;

    tmargin = screen_height - border_size;
    bmargin = border_size;

    lmargin = (screen_width - (screen_height - (border_size*2))) / 2;
    rmargin = screen_width - lmargin;

    /* update co-ordinates to draw screen to */
    quadCoords[0] = (GLfloat)lmargin;
    quadCoords[3] = (GLfloat)rmargin;
    quadCoords[6] = (GLfloat)rmargin;
    quadCoords[9] = (GLfloat)lmargin;
    quadCoords[12] = (GLfloat)rmargin;
    quadCoords[15] = (GLfloat)lmargin;

    quadCoords[1] = (GLfloat)bmargin;
    quadCoords[4] = (GLfloat)bmargin;
    quadCoords[7] = (GLfloat)tmargin;
    quadCoords[10] = (GLfloat)bmargin;
    quadCoords[13] = (GLfloat)tmargin;
    quadCoords[16] = (GLfloat)tmargin;

    /* create a buffer for the screen data */
    img = malloc(160*144*4);
    /* fill it with a nice gradient pattern that's never really seen anymore */
    for (i = 0; i < 144; i++) {
	for (j = 0; j < 160; j++) {
	    img[(i*640)+(j*4)+0] = (i);
	    img[(i*640)+(j*4)+1] = (j);
	    img[(i*640)+(j*4)+2] = 0;
	    img[(i*640)+(j*4)+3] = 255;
	}
    }

    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 160, 144, 0, GL_RGBA, GL_UNSIGNED_BYTE, img);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, (GLfloat)GL_NEAREST);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, (GLfloat)GL_NEAREST);

    /* setup texture and spatial co-ordinates */
    glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);

    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(3, GL_FLOAT, 0, quadCoords);

    /* setup a flat 2D projection */
    glViewport(0, 0, screen_width, screen_height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(0.0, (float)screen_width, 0.0, (float)screen_height, -1.0, 1.0);
    glMatrixMode(GL_MODELVIEW);
}

static void exit_func(void)
// Function to be passed to atexit().
{
   // clear screen
   glClear( GL_COLOR_BUFFER_BIT );
   eglSwapBuffers(display, surface);

   // Release OpenGL resources
   eglMakeCurrent( display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT );
   eglDestroySurface( display, surface );
   eglDestroyContext( display, context );
   eglTerminate( display );

   free(img);
} // exit_func()

/*==============================================================================
 *
 * Keyboard input
 *
 * To allow us to detect key presses and releases as well as different keys
 * simultaneously, we set standard input to non-blocking and non-buffering, and
 * tell the kernel to give us raw scan codes. However this will only work from
 * a real console, not under X Windows. Could possibly create a hidden X
 * window to get input events when running under X.
 *
 *============================================================================*/
static struct termios tty_attr_old;
static int old_keyboard_mode;

/*
 * FIXME: find some way to get keyboard input under X Windows
 */

int setupKeyboard()
{
    struct termios tty_attr;
    int flags;

    /* make stdin non-blocking */
    flags = fcntl(0, F_GETFL);
    flags |= O_NONBLOCK;
    fcntl(0, F_SETFL, flags);

    /* save old keyboard mode */
    if (ioctl(0, KDGKBMODE, &old_keyboard_mode) < 0) {
	return 0;
    }

    tcgetattr(0, &tty_attr_old);

    /* turn off buffering, echo and key processing */
    tty_attr = tty_attr_old;
    tty_attr.c_lflag &= ~(ICANON | ECHO | ISIG);
    tty_attr.c_iflag &= ~(ISTRIP | INLCR | ICRNL | IGNCR | IXON | IXOFF);
    tcsetattr(0, TCSANOW, &tty_attr);

    ioctl(0, KDSKBMODE, K_RAW);
    return 1;
}

void restoreKeyboard()
{
    tcsetattr(0, TCSAFLUSH, &tty_attr_old);
    ioctl(0, KDSKBMODE, old_keyboard_mode);
}

/*
 * Represents Gameboy controller state. Each bit (0 to 7) represents
 * a button. 0 means it's currently pressed, 1 means not.
 */
static unsigned char controllerState = 0xff;

static int escapePressed = 0;

void updateController()
{
    char buf[1];
    int res;
    
    /* read scan code from stdin */
    res = read(0, &buf[0], 1);
    /* keep reading til there's no more*/
    while (res >= 0) {
	switch (buf[0]) {
	case 0x69: /* left arrow */
	    controllerState &= 0xfd;
	    break;
	case 0xe9:
	    controllerState |= 0x02;
	    break;
	case 0x6a: /* right arrow */
	    controllerState &= 0xfe;
	    break;
	case 0xea:
	    controllerState |= 0x01;
	    break;
	case 0x67: /* up arrow */
	    controllerState &= 0xfb;
	    break;
	case 0xe7:
	    controllerState |= 0x04;
	    break;
	case 0x6c: /* down arrow */
	    controllerState &= 0xf7;
	    break;
	case 0xec:
	    controllerState |= 0x08;
	    break;
	case 0x01: /* escape */
	    break;
	case 0x81:
	    escapePressed = 1;
	    break;
	case 0x39: /* space (start) */
	    controllerState &= 0x7f;
	    break;
	case 0xb9:
	    controllerState |= 0x80;
	    break;
	case 0x1c: /* enter (select) */
	    controllerState &= 0xbf;
	    break;
	case 0x9c:
	    controllerState |= 0x40;
	    break;
	case 0x1e: /* A */
	    controllerState &= 0xef;
	    break;
	case 0x9e:
	    controllerState |= 0x10;
	    break;
	case 0x1f: /* S */
	    controllerState &= 0xdf;
	    break;
	case 0x9f:
	    controllerState |= 0x20;
	    break;
	}
	res = read(0, &buf[0], 1);
    }

    /* pass controller state to the emulation */
    GB_setJoypadState(controllerState);
}

/*==============================================================================
 *
 * Main loop/misc
 *
 *============================================================================*/
void usage(char *argv0)
{
    printf("Usage: %s [-h] <game.gb>\n", argv0);
    printf("  -h: output audio to HDMI port instead of analogue\n");
}

unsigned char saveRAM[32*1024];

int main(int argc, char *argv[])
{
    int i, sum;
    int exitloop;
    int res;
    AUDIOPLAY_STATE_T *st;
    unsigned char *audiobuf2;
    int buffer_size = BUFFER_SIZE_SAMPLES * 2 * 2;
    char *romname, *savename, *dot;
    char *audioType = "local";
    int frame = 0;
    FILE *f;

    if ((argc != 2) && (argc != 3)) {
	usage(argv[0]);
	return 0;
    }
    romname = argv[1];
    if (argc == 3) {
	if (strcmp(argv[1], "-h")) {
	    usage(argv[0]);
	    return 0;
	}
	audioType = "hdmi";
	romname = argv[2];
    }

    /*
     * Set keyboard to give us raw scan codes
     */
    if (!setupKeyboard())
    {
        fprintf(stderr, "Configuring keyboard failed. This program will not work remotely or under X windows\n");
	return 1;
    }

    /* initialise Broadcom libs and graphics */
    bcm_host_init();
    init_ogl();

    /* initialise audio playback */
    res = audioplay_create(&st, 18480, 2, 16, 4, buffer_size);
    if (res != 0) {
	fprintf(stderr, "Error in audioplay_create\n");
	restoreKeyboard();
	return 1;
    }

    /* select the audio destination */
    res = audioplay_set_dest(st, audioType);
    if (res != 0) {
	fprintf(stderr, "Error setting audio out to %s\n", audioType);
	restoreKeyboard();
	return 1;
    }

    /* initialise the emulator */
    GB_startup();

    /* load the game ROM */
    if (!GB_loadROM(romname)) {
	fprintf(stderr, "Error loading ROM %s\n", romname);
	restoreKeyboard();
	return 1;
    }

    /* see if there's a save file */
    memset(saveRAM, 0, 32*1024);
    savename = malloc(strlen(romname) + 5);
    strcpy(savename, romname);
    dot = strrchr(savename, '.');
    if (!dot) {
	strcat(savename, ".sav");
    }
    else {
	strcpy(dot, ".sav");
    }
    f = fopen(savename, "rb");
    if (f) {
	fread(saveRAM, 1, 32*1024, f);
	fclose(f);
	GB_getCartridgeRAMContents(saveRAM);
    }

    /* main emulator frame loop */
    exitloop = 0;
    while (!exitloop) {
	unsigned int *uimg = (unsigned int *)img;

	/* run the CPU for a frame */
	GB_execute();

	/* 
	 * only render the graphics every second frame - eglSwapBuffers can only be called
	 * at 50Hz max and the emulator loop needs to run at 60Hz
	 */
	if ((frame & 1) == 0) {
	    /* get graphics data into our texture buffer */
	    GB_getScreenPixels(uimg);

	    glClearColor(1.0, 1.0, 1.0, 1.0);
	    glClear( GL_COLOR_BUFFER_BIT );

	    glMatrixMode(GL_MODELVIEW);
	    
	    glEnable(GL_TEXTURE_2D);
	    glTexEnvx(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
	
	    /* update the texture with new frame */
	    glBindTexture(GL_TEXTURE_2D, tex);
	    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 160, 144, 0, GL_RGBA, GL_UNSIGNED_BYTE, img);
	    
	    /* draw the display as a quad */
	    glDrawArrays(GL_TRIANGLES, 0, 6);
	    
	    /* make latest frame visible */
	    eglSwapBuffers(display, surface);
	}

	/* handle keyboard input */
	updateController();
	if (escapePressed) exitloop = 1;

	/* 
	 * wait for audio buffer to be available. this should lock the emulation to its correct
	 * speed 
	 */
	audiobuf2 = audioplay_get_buffer(st);
	while (audiobuf2 == NULL) {
	    usleep(1000);
	    audiobuf2 = audioplay_get_buffer(st);
	}

	/* get audio data and send it out */
	GB_getAudioData(audiobuf2);

	audioplay_play_buffer(st, audiobuf2, buffer_size);

	frame++;
    }

    /* save to cartridge RAM */
    GB_setCartridgeRAMContents(saveRAM);
    sum = 0;
    for (i = 0; i < (32*1024); i++) {
	sum += saveRAM[i];
    }
    if (sum != 0) {
	/* only save if the game wrote something in there */
	f = fopen(savename, "wb");
	if (!f) {
	    fprintf(stderr, "Error writing save file %s, your game will not be saved :(\n", savename);
	}
	else {
	    fwrite(saveRAM, 1, 32*1024, f);
	    fclose(f);
	}
    }

    free(savename);
    
    /* stop the graphics, audio and keyboard */
    exit_func();
    audioplay_delete(st);
    restoreKeyboard();
    
    return 0;
}
