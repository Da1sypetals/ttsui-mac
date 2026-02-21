# Features

## Save speaker

Clone mode should have speakers:
- Default: (No speaker). Can use `save as speaker...` button together with a text input (at most 16 chars, trimmed) to save as speaker.
- clone from saved speaker. Replace `save as speaker` with `save`, to save to this very speaker. Allow modify name. 
- Speakers metadata (name, text_reference (string or null)) should be saved in ~/.ttsui/clone/speakers.json, while their audio should be copied to ~/.ttsui/clone/speakers/<speaker_name>/audio.wav . Note that modifying existing speakers should be carefully handled, especially when dealing with replacing files.


## Refactor model inference

Subprocess is a workaround. You should refactor this to a HTTP server as a more robust method of IPC. Note that:
- It should be able to take / receive all input and output as current one, e.g. python script output stdout/stderr to use as log, etc.
- You MUST NOT use stdout/stderr for any kind of communication.
- You may need to modify both Swift code and Python code. Make the code robust and clean. You can refactor part of the code if needed.


## Save state

When I input something in control mode, then switch to clone mode, things in control mode should not be lost. Everything should only be lost when app is exited.

## Mark dialects

@llm_docs/qwen_tts.md Mark in UI explicitly about the speakers that speaks dialects instead of mandarin.