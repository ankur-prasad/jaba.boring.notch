import SwiftUI

struct JABAChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isExpanded: Bool
    @FocusState private var isInputFocused: Bool
    @State private var isVoiceMode: Bool = false
    @State private var isRecording: Bool = false
    @State private var isPlaying: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("JABA")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.05))

            Divider()

            // Compact message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages.filter { $0.role != .system }) { message in
                            CompactMessageRow(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Thinking...")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(height: 120)
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area with voice toggle
            HStack(spacing: 8) {
                // Attachment button
                Button(action: {
                    openFilePicker()
                }) {
                    Image(systemName: viewModel.currentAttachments.isEmpty ? "paperclip" : "paperclip.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(viewModel.currentAttachments.isEmpty ? .secondary : .blue)
                }
                .buttonStyle(.plain)
                .help("Add file, image, or PDF")

                // Voice mode toggle
                Button(action: {
                    toggleVoiceMode()
                }) {
                    Image(systemName: isVoiceMode ? "mic.fill" : "mic")
                        .font(.system(size: 14))
                        .foregroundColor(isVoiceMode ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle voice mode (⌘⇧V)")

                if isVoiceMode {
                    // Voice mode indicator
                    HStack(spacing: 4) {
                        if isRecording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .animation(.easeInOut(duration: 0.8).repeatForever(), value: isRecording)
                            Text("Listening...")
                        } else if isPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.blue)
                            Text("Speaking...")
                        } else {
                            Text("Voice mode")
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                } else {
                    // Text input field
                    TextField("Ask JABA anything...", text: $viewModel.currentInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($isInputFocused)
                        .onSubmit {
                            sendMessage()
                        }
                }

                // Send button
                Button(action: {
                    if isVoiceMode {
                        toggleRecording()
                    } else {
                        sendMessage()
                    }
                }) {
                    Image(systemName: isVoiceMode ? (isRecording ? "stop.circle.fill" : "mic.circle.fill") : "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(canSend ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSend && !isVoiceMode)
                .help(isVoiceMode ? "Start/Stop recording" : "Send message (⏎)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.03))

            // Attachment preview
            if !viewModel.currentAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.currentAttachments) { attachment in
                            AttachmentPill(attachment: attachment) {
                                viewModel.currentAttachments.removeAll { $0.id == attachment.id }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .frame(height: 32)
                .background(Color.black.opacity(0.02))
            }
        }
        .frame(width: 640, height: 190)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .onAppear {
            isInputFocused = true
        }
    }

    private var canSend: Bool {
        !viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !viewModel.currentAttachments.isEmpty
    }

    private func sendMessage() {
        guard canSend else { return }
        viewModel.sendMessage()
    }

    private func toggleVoiceMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isVoiceMode.toggle()
            if !isVoiceMode {
                stopRecording()
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        JABASpeechManager.shared.startRecording { result in
            isRecording = false
            switch result {
            case .success(let transcription):
                viewModel.currentInput = transcription
                sendMessageWithSpeech()
            case .failure(let error):
                print("Recording error: \(error)")
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        JABASpeechManager.shared.stopRecording()
    }

    private func sendMessageWithSpeech() {
        guard canSend else { return }

        // Send the message
        let messageToSpeak = viewModel.currentInput
        viewModel.sendMessage()

        // Wait for response and speak it
        // This is a simplified version - in production you'd want to observe the viewModel properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let lastMessage = viewModel.messages.last, lastMessage.role == .assistant {
                isPlaying = true
                JABASpeechManager.shared.speak(text: lastMessage.content) {
                    isPlaying = false
                }
            }
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .pdf, .plainText, .text]

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let mimeType = getMimeType(for: url)
                let attachmentType = getAttachmentType(for: url)

                let attachment = MessageAttachment(
                    type: attachmentType,
                    fileName: url.lastPathComponent,
                    data: data,
                    mimeType: mimeType
                )

                viewModel.currentAttachments.append(attachment)
            } catch {
                print("Error loading file: \(error)")
            }
        }
    }

    private func getMimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        default: return "application/octet-stream"
        }
    }

    private func getAttachmentType(for url: URL) -> AttachmentType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif": return .image
        case "pdf": return .pdf
        case "txt", "text": return .text
        default: return .text
        }
    }
}

// MARK: - Compact Message Row
struct CompactMessageRow: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Icon
            Image(systemName: message.role == .user ? "person.circle.fill" : "sparkles")
                .font(.system(size: 14))
                .foregroundColor(message.role == .user ? .blue : .purple)
                .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(message.content)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let metrics = message.metrics {
                    Text("\(Int(metrics.tokensPerSecond)) tok/s")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Attachment Pill
struct AttachmentPill: View {
    let attachment: MessageAttachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 10))
            Text(attachment.fileName)
                .font(.system(size: 10))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
    }

    private var iconName: String {
        switch attachment.type {
        case .image: return "photo"
        case .pdf: return "doc.fill"
        case .text: return "doc.text"
        }
    }
}
