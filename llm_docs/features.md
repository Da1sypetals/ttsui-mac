# Features

## Save speaker

Clone mode should have speakers:
- Default: (No speaker). Can use `save as speaker...` button together with a text input (at most 16 chars, trimmed) to save as speaker.
- clone from saved speaker. Replace `save as speaker` with `save`, to save to this very speaker. Allow modify name. 
- Speakers metadata (name, text_reference (string or null)) should be saved in ~/.ttsui/clone/speakers.json, while their audio should be copied to ~/.ttsui/clone/speakers/<speaker_name>/audio.wav . Note that modifying existing speakers should be carefully handled, especially when dealing with replacing files./


## Refactor model inference

Subprocess is a workaround. You should refactor this to a HTTP server as a more robust method of IPC. Note that:
- You MUST NOT use stdout/stderr for any kind of communication.
- You may need to modify both Swift code and Python code. Make the code robust and clean. You can refactor part of the code if needed.
- Require user to manually load/unload models. Only allow user to select models that are loaded. Unloading a model should REALLY release resources; you must achieve this or explicitly stop to inform me of why this is not achieveable.
- You MUST verify the project compiles and can build after each part of the code is completed.
- DO NOT use any sort of Mock, Skip, etc. to fool me or to try to get the app functioning while not implementing the real functionailty. You will be harshly punished if you did so.
- When python server side fails, an explicit and 


## Save state

When I input something in control mode, then switch to clone mode, things in control mode should not be lost. Everything should only be lost when app is exited.

## Mark dialects

@llm_docs/qwen_tts.md Mark in UI explicitly about the speakers that speaks dialects instead of mandarin.