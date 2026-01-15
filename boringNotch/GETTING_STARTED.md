# 🤖 Quick Start: AI Chat in Boring Notch

## What's New?

Your Boring Notch now has **built-in AI chat** powered by Ollama! Chat with AI models directly from the notch interface.

## 5-Minute Setup

### Step 1: Install Ollama

```bash
# Visit https://ollama.ai and download, or use Homebrew:
brew install ollama
```

### Step 2: Download a Model

```bash
# Start with Llama 2 (recommended):
ollama pull llama2

# Or try others:
ollama pull mistral    # Smaller, faster
ollama pull codellama  # Great for coding
ollama pull phi        # Tiny and fast
```

### Step 3: Start Chatting!

**Three ways to open AI Chat:**

1. ⌨️ Press `⌘⇧J` (Command + Shift + J)
2. 🖱️ Hold `⌥ Option` and click the notch
3. ⚙️ Open from Settings → AI Chat

## That's It!

The AI chat will:
- ✅ Auto-detect Ollama running on your Mac
- ✅ Show all installed models
- ✅ Stream responses in real-time
- ✅ Keep your chat history

## Tips

- **Switch models**: Click the slider icon in the chat header
- **Clear history**: Click the trash icon
- **Change server**: Settings → AI Chat → Server URL
- **Privacy**: Everything runs locally, no data leaves your Mac!

## Troubleshooting

**"Ollama not connected"**
```bash
# Make sure Ollama is running:
ollama serve

# Or check status:
curl http://localhost:11434/api/tags
```

**"No models available"**
```bash
# Install at least one model:
ollama pull llama2
```

## What Changed?

- ❌ **Removed**: Old Python-based JABA integration
- ✅ **Added**: Native Swift + Ollama integration
- ✅ **Result**: Faster, simpler, more reliable!

---

**Enjoy chatting with AI right in your notch! 🚀**
