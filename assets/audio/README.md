# Original game audio

All music, ambience and effects were composed and synthesized specifically for The Quiet Conservatory by `tools/generate_audio.py`. No recordings, third-party music or external samples are used.

Music and forest ambience are 64-second, 22050 Hz, stereo 16-bit PCM WAV loops. Musical note tails wrap around each loop point. Soundscape applies quiet mix levels and crossfades. Effects are short, pooled and rate limited.

Run `python3 tools/generate_audio.py` to regenerate the assets with Python's standard library.
