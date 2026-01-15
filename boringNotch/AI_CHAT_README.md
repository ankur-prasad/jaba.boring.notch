# AI Chat Integration with Ollama

This implementation adds native AI chat capabilities to Boring Notch using Ollama, a local LLM runtime.

## Features

- ✅ **Native Integration**: AI chat built directly into the Boring Notch UI
- ✅ **Streaming Responses**: Real-time streaming of AI responses
- ✅ **Multiple Models**: Switch between different Ollama models
- ✅ **Keyboard Shortcuts**: Quick access via ⌘⇧J
- ✅ **Clean UI**: Dark theme matching Boring Notch aesthetic
- ✅ **Privacy First**: All processing happens locally on your Mac

## Setup

### 1. Install Ollama

Download and install Ollama from [https://ollama.ai](https://ollama.ai)

### 2. Pull a Model

Open Terminal and pull a model:

```bash
# Recommended for most users
ollama pull llama2

# Or try other models
ollama pull mistral
ollama pull codellama
ollama pull llama3
ollama pull phi
```

### 3. Start Ollama

Ollama should start automatically, but you can verify:

```bash
ollama list  # Shows installed models
ollama serve  # Starts the server (usually runs automatically)
```

### 4. Use in Boring Notch

- **Option 1**: Press `⌘⇧J` (Command + Shift + J) to open AI Chat
- **Option 2**: Hold `⌥ Option` while clicking the notch
- **Option 3**: Open Settings → AI Chat to configure

## Usage

1. **Open AI Chat**: Use keyboard shortcut or Option+click
2. **Select Model**: Click the settings icon in the chat header
3. **Start Chatting**: Type your message and press Enter
4. **Clear History**: Click the trash icon to start fresh

## Architecture

### Files Created

1. **OllamaManager.swift**: Core manager handling Ollama API communication
   - Connection management
   - Model discovery
   - Streaming chat responses
   - Message history

2. **AIChatView.swift**: SwiftUI chat interface
   - Message bubbles
   - Input field
   - Model picker
   - Empty states

3. **AIChatSettings.swift**: Settings panel
   - Connection status
   - Server URL configuration
   - Model list
   - Usage tips

### Key Components

```swift
// Manager (Singleton)
OllamaManager.shared
  ├─ isConnected: Bool
  ├─ availableModels: [OllamaModel]
  ├─ selectedModel: OllamaModel?
  ├─ messages: [OllamaMessage]
  └─ sendMessage(_ text: String) async

// View Integration
ContentView
  └─ case .jaba: AIChatView()
```

## API Integration

The implementation uses Ollama's REST API:

- **GET /api/tags**: List available models
- **POST /api/chat**: Send messages (streaming)

```swift
// Example request
{
  "model": "llama2",
  "messages": [
    {"role": "user", "content": "Hello!"}
  ],
  "stream": true
}
```

## Customization

### Change Server URL

Default: `http://localhost:11434`

To use a remote server:
1. Open Settings → AI Chat
2. Click "Change Server URL"
3. Enter new URL (e.g., `http://192.168.1.100:11434`)

### Default Model

The first available model is selected by default. Change it from:
- Chat header → Settings icon
- Or Settings → AI Chat → Models

## Troubleshooting

### "Ollama not connected"

1. Check if Ollama is running:
   ```bash
   curl http://localhost:11434/api/tags
   ```

2. Start Ollama:
   ```bash
   ollama serve
   ```

3. Click "Retry Connection" in the app

### "No models available"

Pull at least one model:
```bash
ollama pull llama2
```

### Slow Responses

- Use smaller models (e.g., `phi`, `mistral`)
- Ensure your Mac has sufficient RAM
- Close other resource-intensive apps

## Performance

- **Memory**: Depends on model size (2GB-8GB typical)
- **Speed**: Varies by model and hardware
- **Streaming**: Responses appear in real-time
- **Local**: No internet required after model download

## Future Enhancements

Potential improvements:

- [ ] Voice input/output
- [ ] Code syntax highlighting
- [ ] Export conversations
- [ ] Custom system prompts
- [ ] Multi-modal support (images)
- [ ] Model downloading from UI
- [ ] Conversation search
- [ ] Response regeneration

## Removed Dependencies

This implementation **removes** the previous JABA Python integration:
- No Python virtual environment needed
- No external processes
- Simpler architecture
- Faster startup

## Credits

Built on top of:
- [Ollama](https://ollama.ai) - Local LLM runtime
- Boring Notch - Dynamic notch for macOS

---

**Note**: This is a complete replacement of the previous JABA integration. The Python-based system has been removed in favor of this native Swift implementation.
