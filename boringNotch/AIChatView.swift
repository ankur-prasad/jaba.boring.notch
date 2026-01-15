//
//  AIChatView.swift
//  boringNotch
//
//  AI Chat View for Ollama Integration with dynamic sizing
//

import SwiftUI

struct AIChatView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var ollamaManager = OllamaManager.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var viewDidAppear = false
    @State private var isDraggingResize = false
    @State private var dragStartHeight: CGFloat = 0

    // Layout constants
    private let headerInputHeight: CGFloat = 110  // header + input area height

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            chatHeader

            // Messages area (fills available space)
            messagesScrollView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Input area (always visible)
            inputArea

            // Resize handle at bottom
            resizeHandle
        }
        .background(Color.black)
        .onAppear {
            viewDidAppear = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isInputFocused = true
            }
            Task {
                await ollamaManager.checkConnection()
                if ollamaManager.isConnected {
                    await ollamaManager.fetchModels()
                }
            }
            // Set initial chat size
            vm.updateChatSize(messageCount: ollamaManager.messages.count)
        }
        .onChange(of: ollamaManager.messages.count) { oldCount, newCount in
            // Auto-grow when messages are added (but don't shrink if user has resized)
            vm.expandChatIfNeeded(messageCount: newCount)
        }
        .onChange(of: coordinator.currentView) { oldView, newView in
            // Focus the input field when switching to JABA chat view
            if newView == .jaba {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
        }
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.white.opacity(isDraggingResize ? 0.15 : 0.05))
            .frame(height: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(isDraggingResize ? 0.5 : 0.3))
                    .frame(width: 36, height: 4)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !isDraggingResize {
                            isDraggingResize = true
                            dragStartHeight = vm.notchSize.height
                        }
                        let newHeight = dragStartHeight + value.translation.height
                        let clampedHeight = min(max(newHeight, chatMinOpenHeight), chatMaxOpenHeight)
                        vm.setChatHeight(clampedHeight)
                    }
                    .onEnded { _ in
                        isDraggingResize = false
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Compact Header

    private var chatHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)

            if let model = ollamaManager.selectedModel {
                Text(model.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            } else if !ollamaManager.isConnected {
                Text("Ollama not connected")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
            } else {
                Text("No model selected")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
            }

            Spacer()

            // Model picker (compact)
            if ollamaManager.isConnected && !ollamaManager.availableModels.isEmpty {
                modelPickerMenu
            }

            // Refresh connection button (if not connected)
            if !ollamaManager.isConnected {
                Button {
                    Task {
                        await ollamaManager.checkConnection()
                        if ollamaManager.isConnected {
                            await ollamaManager.fetchModels()
                        }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .padding(6)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Clear button
            if !ollamaManager.messages.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        ollamaManager.clearChat()
                        vm.resetChatHeight()  // Reset manual size when clearing
                        vm.updateChatSize(messageCount: 0)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .padding(6)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
    }

    private var modelPickerMenu: some View {
        Menu {
            ForEach(ollamaManager.availableModels) { model in
                Button {
                    ollamaManager.selectedModel = model
                } label: {
                    HStack {
                        Text(model.displayName)
                        if !model.displaySize.isEmpty {
                            Text("(\(model.displaySize))")
                                .foregroundColor(.secondary)
                        }
                        if model == ollamaManager.selectedModel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button {
                Task {
                    await ollamaManager.fetchModels()
                }
            } label: {
                Label("Refresh Models", systemImage: "arrow.clockwise")
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .padding(6)
                .background(Color.white.opacity(0.05))
                .clipShape(Circle())
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if ollamaManager.messages.isEmpty {
                        // Empty state placeholder
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 24))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("Start a conversation")
                                .font(.system(size: 12))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(ollamaManager.messages) { message in
                            CompactMessageBubble(message: message)
                                .id(message.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // Streaming indicator
                        if ollamaManager.isStreaming && ollamaManager.currentStreamingMessage.isEmpty {
                            streamingIndicator
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: ollamaManager.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: ollamaManager.currentStreamingMessage) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = ollamaManager.messages.last {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            // Error message (if any)
            if let error = ollamaManager.errorMessage {
                errorBanner(error)
            }

            // Main input row
            HStack(alignment: .center, spacing: 10) {
                inputField
                sendButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.03))
        }
    }

    private func errorBanner(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 10))
                .foregroundColor(.orange)
            Text(error)
                .font(.system(size: 10))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            Button {
                ollamaManager.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.15))
    }

    private var inputField: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .frame(minHeight: 32)

            if inputText.isEmpty {
                Text(placeholderText)
                    .foregroundColor(.gray.opacity(0.6))
                    .font(.system(size: 12))
                    .padding(.leading, 12)
            }

            TextField("", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(1...3)
                .focused($isInputFocused)
                .disabled(!ollamaManager.isConnected || ollamaManager.selectedModel == nil)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .onSubmit {
                    sendMessage()
                }
        }
    }

    private var placeholderText: String {
        if !ollamaManager.isConnected {
            return "Ollama not connected..."
        } else if ollamaManager.selectedModel == nil {
            return "Select a model..."
        } else {
            return "Ask anything..."
        }
    }

    private var sendButton: some View {
        Button {
            if ollamaManager.isStreaming {
                ollamaManager.stopStreaming()
            } else {
                sendMessage()
            }
        } label: {
            Image(systemName: ollamaManager.isStreaming ? "stop.fill" : "arrow.up")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(canSend ? .black : .gray)
                .frame(width: 26, height: 26)
                .background(canSend ? Color.white : Color.white.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend && !ollamaManager.isStreaming)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !ollamaManager.isLoading
        && ollamaManager.isConnected
        && ollamaManager.selectedModel != nil
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""

        Task {
            await ollamaManager.sendMessage(text)
        }
    }
}

// MARK: - Compact Message Bubble

struct CompactMessageBubble: View {
    let message: OllamaMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !message.isUser {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .frame(width: 14)
                    .padding(.top, 4)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(message.isUser ? Color.blue.opacity(0.8) : Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)

            if message.isUser {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .frame(width: 14)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AIChatView()
        .frame(width: 640, height: 450)
        .environmentObject(BoringViewModel())
}
