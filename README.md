# Bad Apple Demo for Sega CD (30 FPS, Fullscreen)
What an original concept. I know there's another one that uses Cinepak, but this one uses a custom made codec. This doesn't really do anything new, programming-wise, I just made this for fun. It runs at a solid 30 FPS, 256x224 (set to H32 mode).

## How It Works
The video, at 30 FPS and only in 2 colors (black and white), was split into 2 second "packets". Each packet contains 60 video frames, with every 4 frames compressed into 1 by assigning a pixel from each frame to each bit in a palette index. An individual frame is displayed by highlighting the palette indices that use their assigned bit. Each set of 4 frames is then compressed again in Comper. I used H32 mode, because then a fullscreen frame would only take up less than half of VRAM. In H40 mode, it would take up more than half, which isn't very suitable for double buffering. Also less tiles to transfer, lol.

While it does that, for every packet, it loads the next packet into memory on the Sub CPU side, and on the Main CPU side, it takes what it currently has, and then for every 8 frames (the length it takes for 1 set of 4 frames to display at 30 FPS), it decompresses a 4 frame set, and piece by piece, loads it into VRAM. Double buffering is used so that it can be loaded offscreen, and then swapped when ready. Word RAM is also set to 1M/1M mode so that both CPUs can have a half of Word RAM to work with.

On the Sub CPU side, after it loads a packet, it then copies the audio data from that packet into a section of PCM wave RAM (double buffered here, too). Testing has shown that loading a packet and loading the PCM data (despite the PCM chip being slow as balls) is fast enough to not have to do any weird timing tricks or checks on the Sub CPU. The audio is set to 15360 Hz so that 2 seconds of it would fit rather snuggly in a PCM wave RAM section without filling it up all the way to make room for loop flags. It's good enough IMO.

The code is a bit on the messy side, because I programmed it in only a few days. lol

## Compatibility
Confirmed to work on a real US Model 2 Sega CD. Should work on any NTSC console, but not PAL, due to timing differences (video runs slower, and desyncs from the audio). I would have to rework a bit of this to get it to work properly in 50 Hz, but I can't really be arsed to do so (sorry, PAL regions :(). Emulator-wise, works fine on Kega Fusion and Genesis Plus GX, but again, not in PAL mode.

## Special Thanks
vladikcomper - Comper compression/decompressor

## Download
[Here](https://drive.google.com/file/d/1Y9n5cf8HIEDJCbQ53L_YIvEsvTowk8v_/view?usp=sharing)
