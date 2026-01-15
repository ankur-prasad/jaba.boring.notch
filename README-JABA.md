# JABA × boring.notch Integration

**JABA** (Just Another Boring AI) has been integrated into [boring.notch](https://github.com/TheBoredTeam/boring.notch) as a native feature, bringing powerful local AI chat capabilities directly to your MacBook's notch.

## Features

### 🎯 Quick Access AI Chat
- **Keyboard Shortcuts**:
  - `⌘⇧J` - Toggle JABA chat interface
  - `⌘⇧V` - Open JABA in voice mode
- **Click Access**: Option+Click on the notch to open JABA
- **Seamless Integration**: Uses boring.notch's native expansion system

### 🎤 Voice Interaction
- **Speech-to-Text**: Dictate your messages hands-free
- **Text-to-Speech**: Hear AI responses spoken aloud
- **Toggle Support**: Switch between text and voice modes with one button
- **Visual Feedback**: Waveform and recording indicators

### 📎 Multi-Modal Context
- **File Support**: Drag & drop or attach files, PDFs, images
- **Image Analysis**: Uses LLaVA vision model for image understanding
- **PDF OCR**: Extracts and analyzes text from PDF documents
- **Document Context**: Ask follow-up questions about uploaded documents

### ⚡ Local & Private
- **100% Local**: All processing happens on your Mac via Ollama
- **No Cloud**: Conversations never leave your device
- **Fast**: Direct integration with local Ollama service
- **Private**: Complete privacy for sensitive conversations

### 🎨 Native Design
- **Notch-Optimized UI**: Compact interface designed for the notch space
- **Smooth Animations**: Inherits boring.notch's fluid transitions
- **Material Design**: Uses macOS vibrancy and blur effects
- **Dark/Light Support**: Automatically adapts to system appearance

## Installation

### Prerequisites
1. **macOS 14 Sonoma or later** with a notch
2. **Ollama** installed and running:
   ```bash
   brew install ollama
   ollama pull gemma3:4b
   ollama pull llava:7b  # For image analysis
   ```

### Setup
1. Clone this repository:
   ```bash
   git clone <your-repo-url> JABA-boring-notch
   cd JABA-boring-notch
   ```

2. Open the project in Xcode:
   ```bash
   open boringNotch.xcodeproj
   ```

3. Build and run (⌘R)

4. Grant permissions when prompted:
   - **Microphone**: For voice dictation
   - **Speech Recognition**: For transcribing voice input
   - **Accessibility**: For keyboard shortcuts and HUD replacement

## Usage

### Opening JABA Chat

**Keyboard Shortcut** (Recommended):
- Press `⌘⇧J` to open/close JABA chat
- The notch will expand showing the chat interface

**Voice Mode**:
- Press `⌘⇧V` to open JABA in voice mode
- Start speaking immediately

**Click**:
- Hold `Option (⌥)` and click the notch to open JABA

### Text Chat
1. Type your message in the input field
2. Press `Enter` or click the send button
3. View AI responses in the message list
4. Close with `Esc` or `⌘⇧J`

### Voice Chat
1. Click the microphone icon or press `⌘⇧V`
2. Speak your question
3. AI will respond with both text and speech
4. Toggle between text/voice with the mic button

### Adding Context
1. Click the paperclip icon
2. Select files, images, or PDFs
3. Ask questions about the content
4. Context is preserved for follow-up questions

## Architecture

### Directory Structure
```
boringNotch/
├── JABA/
│   ├── JABAChatView.swift         # Main chat UI
│   ├── JABAManager.swift          # Singleton manager
│   ├── JABASpeechManager.swift    # Voice I/O
│   ├── ChatViewModel.swift        # Chat state
│   ├── OllamaService.swift        # AI backend
│   └── Models/
│       ├── Message.swift          # Message models
│       ├── ChatSession.swift      # Session management
│       └── ...
├── ContentView.swift              # Updated with JABA case
├── BoringViewCoordinator.swift    # State coordinator
└── enums/generic.swift            # Added .jaba to NotchViews
```

### Integration Points

1. **NotchViews Enum**: Added `.jaba` case for view switching
2. **Keyboard Shortcuts**: Registered JABA shortcuts in `ShortcutConstants.swift`
3. **AppDelegate**: Added keyboard shortcut handlers in `boringNotchApp.swift`
4. **ContentView**: Added JABA view case in the notch expansion switch
5. **Click Handler**: Modified `doOpen()` to detect Option key for JABA

### Services

**JABAManager** (`JABAManager.swift`):
- Singleton managing JABA state
- Owns `ChatViewModel` instance
- Coordinates voice mode activation

**ChatViewModel** (`ChatViewModel.swift`):
- Manages conversation state
- Handles message sending/receiving
- Maintains document context
- Interfaces with OllamaService

**OllamaService** (`OllamaService.swift`):
- Communicates with local Ollama instance
- Handles text and vision model requests
- Processes PDFs with OCR
- Manages connection state

**JABASpeechManager** (`JABASpeechManager.swift`):
- Speech recognition (STT)
- Speech synthesis (TTS)
- Audio session management
- Text cleanup for better speech

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧J` | Toggle JABA chat |
| `⌘⇧V` | Open JABA in voice mode |
| `⌘⇧I` | Toggle notch (boring.notch default) |
| `Esc` | Close JABA |
| `Enter` | Send message |

## Retaining boring.notch Features

All original boring.notch features remain fully functional:

✅ **Volume/Brightness HUD** - Still works as before
✅ **Music Player** - Access with Home view
✅ **File Shelf** - Drag & drop files as usual
✅ **Gesture Controls** - All swipe gestures intact
✅ **Multi-Display** - JABA works on all screens
✅ **Settings** - Configure notch behavior

JABA adds a new view alongside Home and Shelf, not replacing them.

## Models

### Text Models (via Ollama)
- **gemma3:4b** (default) - Fast, lightweight
- **llama3.2** - Balanced performance
- **qwen2.5** - Strong reasoning
- Any Ollama-compatible model

### Vision Models (for images/PDFs)
- **llava:7b** (default) - Image understanding
- **llava:13b** - Better accuracy
- **bakllava** - Focused on OCR

Configure in Ollama and select in JABA settings.

## Performance

- **First Token Latency**: ~100-500ms (depending on model)
- **Tokens/Second**: 20-60 (M1/M2/M3)
- **Memory Usage**: +200-400MB (model dependent)
- **GPU Acceleration**: Automatic via Metal

## Troubleshooting

### JABA Won't Open
1. Ensure Ollama is running: `ollama serve`
2. Check models are installed: `ollama list`
3. Restart the app

### Voice Not Working
1. Grant Microphone permission in System Settings
2. Grant Speech Recognition permission
3. Test microphone in another app

### Slow Responses
1. Use smaller models (gemma3:4b)
2. Check Activity Monitor for CPU/GPU usage
3. Ensure no other AI tools are using Ollama

### Connection Failed
1. Verify Ollama is running: `curl http://localhost:11434`
2. Check firewall settings
3. Restart Ollama service

## Development

### Adding New Features

**New Message Types**:
1. Add case to `AttachmentType` enum
2. Update `OllamaService.sendMessageWithVision()`
3. Add UI in `JABAChatView`

**New Models**:
1. Pull model: `ollama pull model-name`
2. Model appears automatically in JABA

**Custom Shortcuts**:
1. Add to `ShortcutConstants.swift`
2. Register handler in `boringNotchApp.swift`
3. Update this README

### Testing
```bash
# Run in Xcode with ⌘R
# Or build release:
xcodebuild -scheme boringNotch -configuration Release
```

## Credits

- **boring.notch**: [@TheBoredTeam](https://github.com/TheBoredTeam/boring.notch)
- **JABA**: Original local AI chat implementation
- **Ollama**: Local LLM runtime
- **LLaVA**: Vision-language model

## License

Follows boring.notch's license. See [LICENSE](LICENSE) for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Roadmap

- [ ] Streaming responses for faster perceived speed
- [ ] Conversation history persistence
- [ ] Custom system prompts per conversation
- [ ] Integration with LocalRecall for RAG
- [ ] Quick actions (summarize, translate, etc.)
- [ ] Siri integration for hands-free activation

---

**Made with ❤️ for Mac users who value privacy and local AI**
