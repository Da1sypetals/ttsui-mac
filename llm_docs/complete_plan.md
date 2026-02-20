TTSUI-mac - SwiftUI TTS Application Plan
Context
Porting the Electron TTS application plan to a native macOS SwiftUI app. The app wraps Qwen3-TTS models from mlx_audio library with a GUI for three TTS modes: Clone, Control, and Design. Python TTS inference runs as a subprocess (one-shot execution per request, not a persistent server).

Tech Stack
UI Framework: SwiftUI (macOS 15+ / Sequoia)
Language: Swift 5.9+
TTS Engine: Python mlx_audio (subprocess - direct invocation)
IPC: Command-line arguments + stdout/stderr + temp files
Audio: AVFoundation for recording/playback
Python Path: Resolved via TTSUI_PYTHON env var, fallback to .env file with /Users/daisy/miniconda3/bin/python
Project Structure

ttsui-mac/
├── TTSUI/
│   ├── TTSUIApp.swift              # App entry point
│   ├── Models/
│   │   ├── TTSRequest.swift        # Request models for each mode
│   │   ├── TTSResponse.swift       # Parsed subprocess output
│   │   └── TTSSettings.swift       # App settings
│   ├── ViewModels/
│   │   ├── CloneViewModel.swift    # Clone mode logic
│   │   ├── ControlViewModel.swift  # Control mode logic
│   │   ├── DesignViewModel.swift   # Design mode logic
│   │   └── AudioRecorder.swift     # Recording state management
│   ├── Views/
│   │   ├── ContentView.swift       # Main view with mode tabs
│   │   ├── ModeSelector.swift      # Tab picker component
│   │   ├── CloneView.swift         # Clone mode UI
│   │   ├── ControlView.swift       # Control mode UI
│   │   ├── DesignView.swift        # Design mode UI
│   │   ├── AudioPlayerView.swift   # Playback controls
│   │   ├── LogPanel.swift          # Read-only Python output log
│   │   └── Components/
│   │       ├── DropZone.swift      # File drop component
│   │       ├── GenerateButton.swift
│   │       └── ProgressBar.swift
│   └── Services/
│       ├── PythonSubprocess.swift  # Python process manager
│       ├── TTSService.swift        # High-level TTS API
│       ├── AudioService.swift      # Recording/playback
│       └── FileService.swift       # File I/O operations
├── python/
│   └── tts_generate.py             # Python TTS subprocess script
├── .env                            # Local config: TTSUI_PYTHON=...
├── Package.swift                   # If using SPM dependencies
└── Info.plist
Python Subprocess Design (python/tts_generate.py)
One-shot script invoked per TTS request. Passes parameters via command-line arguments, writes progress to stderr, outputs result path to stdout.


# Usage examples:
python tts_generate.py clone \
  --model "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16" \
  --text "Hello from Sesame." \
  --ref-audio "/path/to/ref.wav" \
  --ref-text "Reference transcript." \
  --output "/path/to/output.wav"

python tts_generate.py control \
  --model "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16" \
  --text "I'm so excited!" \
  --speaker "Vivian" \
  --language "English" \
  --instruct "Very happy and excited." \
  --output "/path/to/output.wav"

python tts_generate.py design \
  --text "Big brother, you're back!" \
  --language "English" \
  --instruct "A cheerful young female voice..." \
  --output "/path/to/output.wav"
Available Models (from qwen_tts.md):

Mode	Model Options
Clone	Qwen3-TTS-12Hz-0.6B-Base-bf16, Qwen3-TTS-12Hz-1.7B-Base-bf16
Control	Qwen3-TTS-12Hz-0.6B-CustomVoice-bf16, Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16
Design	Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16 (only option)
Output Protocol:

stdout: Output file path on success, or ERROR: <message> on failure
stderr: Progress lines in format PROGRESS: <percent> <status_message>
Both stdout and stderr are captured and displayed in the UI LogPanel
UI Architecture
ContentView (Main)
ModeSelector at top (Segmented picker: Clone | Control | Design)
Switch on selected mode to show appropriate view
Shared AudioPlayerView for playback
LogPanel at bottom showing all Python subprocess output (stdout + stderr)
CloneView
Component	SwiftUI Type	Notes
Model Select	Picker	0.6B-Base (fast) / 1.7B-Base (quality)
Record Button	Button with toggle	Starts/stops recording
Reference Text	TextEditor	Optional transcript
Reference Audio	DropZone + Button	File drop or "Use Recorded"
Target Text	TextEditor	Required, validated
Generate Button	Button	Shows progress during generation
Save Button	Button	Opens NSSavePanel
ControlView
Component	SwiftUI Type	Notes
Model Select	Picker	0.6B-CustomVoice (fast) / 1.7B-CustomVoice (quality)
Speaker Select	Picker	Vivian, Serena, Uncle_Fu, Dylan, Eric, Ryan, Aiden
Language Select	Picker	Chinese, English
Emotion Input	TextEditor	Style/emotion instructions
Target Text	TextEditor	Required
Generate/Save Buttons	Button	Same pattern as Clone
DesignView
Component	SwiftUI Type	Notes
Language Select	Picker	Chinese, English
Voice Description	TextEditor	Describe desired voice
Target Text	TextEditor	Required
Generate/Save Buttons	Button	Same pattern
Note: Design mode uses only 1.7B-VoiceDesign model (no selection needed).

Directory Structure (User Data)

~/.ttsui/
├── clone/
│   ├── tmp_audio/          # Recorded reference audio
│   │   └── recorded.wav
│   └── generated/          # Generated audio files
│       └── <timestamp>.wav
├── control/
│   └── generated/
│       └── <timestamp>.wav
└── design/
    └── generated/
        └── <timestamp>.wav
Implementation Steps
Step 1: Project Setup
Create new Xcode SwiftUI project (macOS App)
Configure minimum deployment target: macOS 15.0
Add Entitlements for Microphone access (NSMicrophoneUsageDescription)
Create .env file with TTSUI_PYTHON=/Users/daisy/miniconda3/bin/python
Create folder structure as outlined above
Step 2: Python Subprocess Script
Create python/tts_generate.py with argparse CLI interface
Implement three generation methods (clone, control, design) using mlx_audio
Write progress to stderr, output path to stdout
Handle errors and exit codes
Step 3: Swift Services Layer
Implement PythonSubprocess.swift: spawn Python process per request, capture output
Implement TTSService.swift: build CLI args, invoke Python, parse results
Implement FileService.swift: create directories, manage files
Implement AudioService.swift: AVAudioRecorder wrapper
Step 4: ViewModels
Create base ObservableObject ViewModels for each mode
Handle loading states, error states, progress updates
Bind to TTSService methods
Step 5: Views - Core Components
Build reusable DropZone with NSFilePromiseReceiver
Build AudioPlayerView with AVAudioPlayer
Build GenerateButton with progress indicator
Step 6: Views - Mode Panels
Implement CloneView with recording integration
Implement ControlView with speaker picker
Implement DesignView with voice description
Step 7: Integration & Polish
Wire up all components in ContentView
Stream progress updates from stderr during generation
Implement save functionality with NSSavePanel
Add error handling and validation feedback
Key Implementation Details
LogPanel (Python Output Display)

// LogPanel.swift
struct LogPanel: View {
    @Binding var logEntries: [LogEntry]
    // Read-only ScrollView showing all Python output
    // Auto-scrolls to bottom on new entries
    // Shows timestamps and entry type (stdout/stderr)
}

// Captured by PythonSubprocess, published to UI
struct LogEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let content: String
    let type: LogType  // .stdout, .stderr
}
Python Subprocess Invocation

// PythonSubprocess.swift
class PythonSubprocess: ObservableObject {
    // Python path resolution order:
    // 1. TTSUI_PYTHON environment variable
    // 2. .env file in app bundle (key: TTSUI_PYTHON=/path/to/python)
    // 3. Hardcoded fallback: /Users/daisy/miniconda3/bin/python

    func resolvePythonPath() -> String

    // One-shot execution per TTS request
    func run(
        mode: TTSMode,
        args: [String],
        progressHandler: (Int, String) -> Void
    ) async throws -> URL  // Returns output file URL
}

// TTSService.swift - builds CLI arguments for each mode
extension TTSService {
    func clone(model: String, text: String, refAudio: URL?, refText: String?) async throws -> URL
    func control(model: String, text: String, speaker: String, language: String, instruct: String?) async throws -> URL
    func design(text: String, language: String, instruct: String) async throws -> URL
}
Audio Recording

// Use AVAudioRecorder for capturing microphone input
// Save to ~/.ttsui/clone/tmp_audio/recorded.wav
// Format: WAV, 16-bit, 24kHz (match model sample rate)
Progress Updates
Python writes progress to stderr in real-time:


PROGRESS: 10 Loading model...
PROGRESS: 30 Processing text...
PROGRESS: 60 Generating audio...
PROGRESS: 90 Saving output...
Swift reads stderr asynchronously via Pipe and publishes progress updates via ObservableObject.

Verification
Clone Mode: Record audio → enter target text → generate → verify output plays
Control Mode: Select speaker → enter emotion → generate → verify voice matches
Design Mode: Enter voice description → generate → verify unique voice created
Save: Generate audio → save to custom location → verify file exists
Progress: Verify progress updates display correctly during generation
Error Handling: Test with invalid inputs, verify error messages shown
Critical Files to Create
TTSUI/Services/PythonSubprocess.swift - Subprocess invocation + stdout/stderr capture
TTSUI/Services/TTSService.swift - High-level TTS API with model selection
python/tts_generate.py - Python TTS script (CLI interface to mlx_audio)
TTSUI/Views/ContentView.swift - Main UI entry point
TTSUI/Views/LogPanel.swift - Read-only Python output log display
TTSUI/ViewModels/CloneViewModel.swift - Clone mode logic