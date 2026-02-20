# Features

## Save speaker

Clone mode should have speakers:
- Default: (No speaker). Can use `save as speaker...` button together with a text input (at most 16 chars, trimmed) to save as speaker.
- clone from saved speaker. Replace `save as speaker` with `save`, to save to this very speaker. Allow modify name. 
- Speakers metadata (name, text_reference (string or null)) should be saved in ~/.ttsui/clone/speakers.json, while their audio should be copied to ~/.ttsui/clone/speakers/<speaker_name>/audio.wav . Note that modifying existing speakers should be carefully handled, especially when dealing with replacing files.


## Save state

When I input something in control mode, then switch to clone mode, things in control mode should not be lost. Everything should only be lost when app is exited.