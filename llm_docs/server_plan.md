# Implementation Plan: HTTP Server Refactoring for Model Inference

## Context

The current implementation uses subprocess-based IPC between Swift and Python:
- `PythonSubprocess.swift` manages Python process via stdin/stdout/stderr
- `tts_generate.py` loads models fresh on each invocation
- Models are selected via radio group picker (no load/unload lifecycle)
- No memory management or resource tracking exists

This refactoring replaces subprocess with HTTP server architecture to enable:
- Explicit model load/unload with resource management
- Memory tracking before/after model loading
- Proper model lifecycle with multiple simultaneous loaded models
- Robust IPC without stdout/stderr dependency

---

## Architecture Overview

```
Swift App                              Python Server
+------------------+                   +------------------+
| TTSServerManager | -- start proc --> | tts_server.py    |
|                  | <-- stderr ------ |   FastAPI/uvicorn|
|                  |   (startup only)  |   logging module |
+------------------+                   +------------------+
|                  |                   |                  |
| TTSHTTPClient    | <-- HTTP JSON --> | /models/load     |
|   - loadModel    |                   | /models/unload   |
|   - generate     |                   | /generate/*      |
+------------------+                   +------------------+
|                  |                   |                  |
| TTSHTTPClient    | <-- SSE stream -->| /logs/stream     |
|   - logStream    |   (real-time)     |   (real-time)    |
+------------------+                   +------------------+
|                  |                   |                  |
| ViewModels       |                   | ModelRegistry    |
|   - modelStates  |                   |   - memory info  |
+------------------+                   +------------------+
```

---

## Files to Create

### 1. `/Users/daisy/develop/ttsui-mac/python/tts_server.py`
FastAPI HTTP server with:
- **Endpoints:**
  - `POST /models/load` - Load model, return memory stats
  - `POST /models/unload` - Unload model, force GC, return memory stats
  - `GET /models` - List all models with states
  - `POST /generate/clone` - Generate with clone mode
  - `POST /generate/control` - Generate with control mode
  - `POST /generate/design` - Generate with design mode
  - `GET /health` - Health check
  - `GET /logs/stream` - SSE endpoint for real-time log streaming
  - `GET /logs` - Get all accumulated logs (for initial load)
  - `POST /logs/clear` - Clear accumulated logs
- **Proper logging setup:**
  - Use Python `logging` module with structured format
  - Log levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
  - Custom `LogCapture` handler to store logs for API access
  - Format: `%(asctime)s | %(levelname)s | %(message)s`
  - All server output goes through logger (no raw print for logs)
  - Log memory stats at INFO level during model load/unload
- **Real-time log streaming:**
  - Server-Sent Events (SSE) on `/logs/stream`
  - Swift client subscribes and receives logs as they occur
- **Memory tracking:** Use `psutil` to get RSS memory before/after load
- **GC on unload:** Call `gc.collect()` and `mx.clear_cache()` for MLX

### 2. `/Users/daisy/develop/ttsui-mac/ttsui-mac/Services/TTSHTTPClient.swift`
HTTP client with:
- URLSession-based API calls
- Codable request/response models
- 5-minute timeout for long generations
- Error handling with typed errors
- **SSE log streaming:**
  - `startLogStream()` - Opens SSE connection to `/logs/stream`
  - Parses SSE events and forwards to delegate
  - Handles reconnection on disconnect

### 3. `/Users/daisy/develop/ttsui-mac/ttsui-mac/Services/TTSServerManager.swift`
Server lifecycle manager:
- Start/stop Python server process
- Subscribe to SSE log stream and forward to `TTSService.logEntries`
- Capture server process stdout/stderr (for startup errors only)
- Health monitoring with retry
- Auto-restart on crash (optional)

### 4. `/Users/daisy/develop/ttsui-mac/ttsui-mac/Views/Components/ModelSelectionRow.swift`
Individual model row component with left-aligned layout:
```
[ ] Model Name     [Load]       <- unloaded (checkbox disabled)
[ ] Model Name     [spinner]    <- loading (checkbox disabled)
[x] Model Name     [Unload]     <- loaded (checkbox enabled, selected)
[ ] Model Name     [Retry]      <- error (checkbox disabled)
    Error: out of memory
```

Layout requirements:
- All elements left-aligned: checkbox → model name → load/unload button
- No elements aligned to the right
- Entire row is tappable to select the model (if loaded)
- Click on button area triggers load/unload action
- Memory stats are NOT displayed in the row - only logged to Python log panel

### 5. `/Users/daisy/develop/ttsui-mac/ttsui-mac/Views/Components/ModelSelectionGroup.swift`
Container for model rows with:
- Radio-style selection among loaded models
- Section header with model type name

### 6. `/Users/daisy/develop/ttsui-mac/ttsui-mac/Models/HTTPModels.swift`
Codable structs for API communication:
- `ModelInfo`, `ModelState` (enum)
- `LoadModelRequest/Response`
- `UnloadModelRequest/Response`
- `GenerateCloneRequest/Response`, etc.
- `LogEntry` (for SSE stream): timestamp, level, message

---

## Files to Modify

### 1. `/Users/daisy/develop/ttsui-mac/ttsui-mac/Services/TTSService.swift`
- Remove `PythonSubprocessDelegate` conformance
- Replace `subprocess.run()` with `httpClient.generate*()` calls
- Add model management methods: `loadModel()`, `unloadModel()`, `listModels()`
- Keep `logEntries` for server logs (populated from TTSServerManager)

### 2. `/Users/daisy/develop/ttsui-mac/ttsui-mac/ViewModels/CloneViewModel.swift`
- Replace `selectedModel: CloneModel` with `selectedModelId: String?`
- Add `modelStates: [String: ModelInfo]` for tracking load states
- Add `loadModel()`, `unloadModel()` async methods
- Update `canGenerate` to check if selected model is loaded

### 3. `/Users/daisy/develop/ttsui-mac/ttsui-mac/ViewModels/ControlViewModel.swift`
- Same changes as CloneViewModel

### 4. `/Users/daisy/develop/ttsui-mac/ttsui-mac/ViewModels/DesignViewModel.swift`
- Add model state for fixed VoiceDesign model
- Add load/unload methods

### 5. `/Users/daisy/develop/ttsui-mac/ttsui-mac/Views/CloneView.swift`
- Replace `GroupBox` + `Picker` with `ModelSelectionGroup`
- Bind to new model state properties

### 6. `/Users/daisy/develop/ttsui-mac/ttsui-mac/Views/ControlView.swift`
- Same changes as CloneView

### 7. `/Users/daisy/develop/ttsui-mac/ttsui-mac/Views/DesignView.swift`
- Add model loading UI for VoiceDesign model

### 8. `/Users/daisy/develop/ttsui-mac/ttsui-mac/ttsui_macApp.swift`
- Initialize `TTSServerManager.shared.startServer()` on app launch
- Show server status indicator (optional)

### 9. `/Users/daisy/develop/ttsui-mac/ttsui-mac/Services/TTSSettings.swift`
- Add `serverPort: Int = 8765` setting

---

## Files to Delete (after verification)

- `/Users/daisy/develop/ttsui-mac/ttsui-mac/Services/PythonSubprocess.swift`

---

## Model State Machine

```
unloaded ──[Load]──> loading ──[success]──> loaded
    ^                   │                      │
    │                [error]                [Unload]
    │                   │                      │
    │                   v                      v
    └──────────────> error <──[Unload]─── unloading
```

**States:**
- `unloaded`: Model not in memory, checkbox disabled, show "Load" button
- `loading`: Loading in progress, show spinner, checkbox disabled
- `loaded`: Ready for use, checkbox enabled, show "Unload" button + memory info
- `unloading`: Unloading in progress, show spinner
- `error`: Load failed, show "Retry" button + error message

---

## Logging Format

Python logging format:
```
2024-01-15 10:30:45,123 | INFO | Loading model: mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16
2024-01-15 10:30:45,124 | DEBUG | Memory before load: 256.3 MB
2024-01-15 10:30:53,456 | INFO | Model loaded successfully
2024-01-15 10:30:53,457 | INFO | Memory after load: 2847.1 MB (+2590.8 MB)
2024-01-15 10:30:53,457 | INFO | Load time: 8.2 seconds
```

Log levels used:
- `DEBUG`: Detailed memory stats, internal operations
- `INFO`: Model load/unload, generation start/complete, memory deltas
- `WARNING`: Non-critical issues (e.g., slow operation)
- `ERROR`: Failed operations, exceptions
- `CRITICAL`: Server crashes, unrecoverable errors

---

## Implementation Order

### Phase 1: Python HTTP Server
1. Create `tts_server.py` with FastAPI structure
2. Implement model registry with state management
3. Implement `/models/load` and `/models/unload` with memory tracking
4. Implement `/health` and `/logs` endpoints
5. Implement generation endpoints
6. Test standalone with curl

### Phase 2: Swift HTTP Infrastructure
1. Create `HTTPModels.swift` with Codable types
2. Create `TTSHTTPClient.swift` with all API methods
3. Create `TTSServerManager.swift` for process management
4. Add server port to `TTSSettings.swift`

### Phase 3: Integrate Server Management
1. Modify `ttsui_macApp.swift` to start server on launch
2. Wire server logs to `TTSService.logEntries`
3. Test server startup and health check

### Phase 4: New Model Selection UI
1. Create `ModelSelectionRow.swift` component
2. Create `ModelSelectionGroup.swift` component
3. Update ViewModels with model state management
4. Update Views to use new components

### Phase 5: Refactor TTSService
1. Replace subprocess calls with HTTP client calls
2. Update progress handling
3. Test end-to-end generation

### Phase 6: Cleanup
1. Delete `PythonSubprocess.swift`
2. Remove `tts_generate.py` (keep as backup)
3. Build verification

---

## Verification Checklist

After each phase:
- [ ] Project compiles without errors
- [ ] Project builds successfully in Xcode
- [ ] No runtime crashes on app launch

Final verification:
- [ ] Python server starts and responds to health check
- [ ] Models can be loaded via UI with memory stats displayed
- [ ] Models can be unloaded with memory released
- [ ] TTS generation works for all three modes
- [ ] Only loaded models can be selected for generation
- [ ] Server logs appear in UI log panel
- [ ] Loading animation shows immediately when button pressed

---

## Key Constraints

1. **NO stdout/stderr for IPC** - All communication via HTTP JSON responses
2. **NO Mock/Skip implementations** - Real functionality only
3. **Explicit load/unload** - User must manually manage model lifecycle
4. **Multiple models allowed** - Can load multiple models simultaneously
5. **UMA architecture** - Memory tracking uses RSS (shared GPU/CPU memory on Apple Silicon)
