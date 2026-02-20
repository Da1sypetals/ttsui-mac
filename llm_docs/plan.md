Implement an app that performs TTS.
This application should encapsulate all 3 Qwen3-TTS models with full features exposed.

You should refer to ./qwen-tts.md for more info.

Python inference should be integrated as subprocess, NOT server. Wait with timeout (default 1800s) until Python exits.

The UI architecture should be:
- the top panel to choose from 3 modes: Clone (voice cloning), Control (CustomVoice), Design (voice design).

You should make the most use of 3rd party libraries, DO NOT reinvent wheels for things like writing audio files, etc. that has mature libraries.

UI of each mode:

## Clone:
- record/stop button, caches (store to temporary storage ~/.ttsui/tmp_audio/) only 1 audio clip, recording overwrites the cache. Record from system default mic.
- reference text box, optional
- reference audio box, allow select from file explorer / drag & drop / use recorded.
- target text box, required (trimmed) not empty
- a generate button, save to (~/.ttsui/generated_audio/)
- a save button, save the generated audio  to specific place. calls out the file explorer
- You should have separate dir for each mode

...todo



# Note

DO NOT change things I specified at will, e.g. dir names, default values.

