## Godot Steam Game decompile script (for Linux)

### Requirements:
- Game compiled in Godot Engine 3.5.3
- [Encryption key if encrypted](https://github.com/pozm/gdke) (put in key.txt)
- [Latest Steamworks sdk](https://partner.steamgames.com/dashboard) (rename to steamworks_sdk.zip)

[compiling godot engine](https://docs.godotengine.org/en/3.5/development/compiling/compiling_for_x11.html): 
- Clang 6+
- pkg-config (used to detect the dependencies below).
- X11, Xcursor, Xinerama, Xi and XRandR development libraries.
- MesaGL development libraries.
- ALSA development libraries.
- PulseAudio development libraries.

[(If you're on arch, you have to do this as well)](https://github.com/godotengine/godot/issues/46375#issuecomment-1373075734)

One liner: 
`./install_env-3.5.3.sh && ./decomp-3.5.3.sh <path to .pck> <path to output dir>`