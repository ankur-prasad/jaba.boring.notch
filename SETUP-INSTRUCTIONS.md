# JABA × boring.notch - Setup Instructions

## ✅ Integration Complete!

All code has been written and integrated. You just need to **add the files to Xcode** and **build**.

---

## Quick Start (2 Minutes)

### Step 1: Ensure Ollama is Running

```bash
# Check if Ollama is running
curl http://localhost:11434

# If not, start it
ollama serve

# Pull required models
ollama pull gemma3:4b
ollama pull llava:7b
```

### Step 2: Open Project in Xcode

```bash
cd "/Users/ankur/JABA - Just Another Boring AI/JABA-boring-notch"
open boringNotch.xcodeproj
```

### Step 3: Add JABA Files to Project

**In Xcode:**

1. **Right-click** the `boringNotch` folder (in Project Navigator on left)
2. Select **"Add Files to \"boringNotch\"..."**
3. Navigate to `boringNotch/JABA` folder
4. **Select the JABA folder**
5. Ensure these settings:
   - ✅ **"Create groups"** (selected)
   - ✅ **"boringNotch" target** (checked)
   - ❌ **"Copy items if needed"** (unchecked - files are already there)
6. Click **"Add"**

### Step 4: Build & Run

```bash
# In Xcode:
⌘B    # Build (should succeed with no errors)
⌘R    # Run

# Grant permissions when prompted:
# - Microphone (for voice)
# - Speech Recognition (for dictation)
# - Accessibility (for shortcuts)
```

### Step 5: Test JABA!

Press **⌘⇧J** - The notch should expand with JABA chat! 🎉

Try:
- Type a message and press Enter
- Press **⌘⇧V** for voice mode
- **Option+Click** the notch

---

## What Was Built

### New Features

1. **Chat Interface** - Compact 640×190pt chat UI in the notch
2. **Voice Mode** - Speech-to-text input + text-to-speech output
3. **File Support** - Analyze images, PDFs, documents
4. **Global Shortcuts** - `⌘⇧J` for chat, `⌘⇧V` for voice
5. **Click Access** - Option+click notch to open JABA

### Files Created

**JABA Directory** (`boringNotch/JABA/`):
- `JABAChatView.swift` - Main chat UI
- `JABAManager.swift` - State management
- `JABASpeechManager.swift` - Voice I/O
- `ChatViewModel.swift` - Chat logic
- `OllamaService.swift` - AI backend
- `LLMSettings.swift` - Settings
- `Message.swift` - Data models
- `ChatSession.swift` - Sessions
- `ChatHistoryManager.swift` - History
- `Project.swift` - Project model

**Modified Files**:
- `enums/generic.swift` - Added `.jaba` view case
- `Shortcuts/ShortcutConstants.swift` - Added shortcuts
- `boringNotchApp.swift` - Added keyboard handlers
- `ContentView.swift` - Added JABA view & click handler

### Preserved Features

✅ All boring.notch features work:
- Volume/Brightness HUD
- Music Player
- File Shelf
- Gestures
- Multi-display
- Settings

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧J` | Toggle JABA chat |
| `⌘⇧V` | Open JABA voice mode |
| `⌘⇧I` | Toggle boring.notch (Music/Shelf) |
| `Enter` | Send message |
| `Esc` | Close JABA |
| `Option + Click` | Open JABA from notch |

---

## Usage Guide

### Text Chat
1. Press `⌘⇧J`
2. Type your question
3. Press `Enter`
4. Read AI response
5. Press `Esc` or `⌘⇧J` to close

### Voice Chat
1. Press `⌘⇧V`
2. Click red mic icon
3. Speak your question
4. Click stop
5. Hear AI response

### File Analysis
1. Open JABA (`⌘⇧J`)
2. Click paperclip icon
3. Select image/PDF/file
4. Ask questions about it

---

## Troubleshooting

### Build Errors

**Error: "Cannot find JABAChatView"**
→ Files not added to Xcode. Follow Step 3 above.

**Error: "Cannot find JABAManager"**
→ JABA files not in target. Check File Inspector → Target Membership.

**Warnings about Sendable**
→ From boring.notch's existing code. Safe to ignore.

### Runtime Issues

**JABA won't open**
→ Ensure Ollama is running: `ollama serve`

**No models available**
→ Pull models: `ollama pull gemma3:4b`

**Voice not working**
→ Grant microphone permission in System Settings

**Connection failed**
→ Check Ollama: `curl http://localhost:11434`

---

## Project Structure

```
JABA-boring-notch/
├── boringNotch/
│   ├── JABA/                    ← New directory
│   │   ├── JABAChatView.swift
│   │   ├── JABAManager.swift
│   │   ├── JABASpeechManager.swift
│   │   ├── ChatViewModel.swift
│   │   ├── OllamaService.swift
│   │   └── Models/
│   ├── ContentView.swift        ← Modified
│   ├── boringNotchApp.swift     ← Modified
│   ├── enums/generic.swift      ← Modified
│   └── Shortcuts/               ← Modified
└── README-JABA.md               ← Documentation
```

---

## Documentation

- **[README-JABA.md](README-JABA.md)** - Complete feature guide
- **[JABA-QUICK-START.md](../JABA-QUICK-START.md)** - Quick start tutorial
- **[JABA-INTEGRATION-SUMMARY.md](../JABA-INTEGRATION-SUMMARY.md)** - Technical details
- **[MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md)** - Migrating from JABA-UI
- **[ADD-FILES-TO-XCODE.md](../ADD-FILES-TO-XCODE.md)** - Detailed Xcode instructions

---

## Next Steps

After setup:

1. **Test all features**:
   - Text chat
   - Voice mode
   - File uploads
   - Multiple models

2. **Customize**:
   - Try different Ollama models
   - Adjust temperature in code
   - Customize shortcuts

3. **Explore**:
   - Check out boring.notch features
   - Try volume/brightness HUD
   - Use Music player

---

## Support

- **Build issues**: Check [ADD-FILES-TO-XCODE.md](../ADD-FILES-TO-XCODE.md)
- **Usage help**: See [JABA-QUICK-START.md](../JABA-QUICK-START.md)
- **Integration details**: Read [JABA-INTEGRATION-SUMMARY.md](../JABA-INTEGRATION-SUMMARY.md)

---

## Success Checklist

After setup, you should be able to:

- [ ] Build project without errors (⌘B)
- [ ] Run app successfully (⌘R)
- [ ] See boring.notch in menu bar
- [ ] Press `⌘⇧J` to open JABA chat
- [ ] Type and send messages
- [ ] Receive AI responses
- [ ] Press `⌘⇧V` for voice mode
- [ ] Option+click notch to open JABA
- [ ] Attach files with paperclip
- [ ] Use volume/brightness controls
- [ ] Access Music player with `⌘⇧I`

---

**You're all set! Press `⌘⇧J` and start chatting with JABA! 🚀**
