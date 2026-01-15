//
//  AIChatView.swift
//  boringNotch
//
//  AI Chat View for Ollama Integration
//

import SwiftUI

struct AIChatView: View {
    @ObservedObject var ollamaManager = OllamaManager.shared
    @State private var inputText: String = ""
    @State private var showModelPicker: Bool = false
    @State private var isVoiceMode: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var viewDidAppear = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            Divider()
                .opacity(0.3)
            
            // Messages
            if ollamaManager.messages.isEmpty {
                emptyStateView
            } else {
                messagesScrollView
            }
            
            // Input Area
            inputArea
        }
        .onAppear {
            viewDidAppear = true
            // Delay focus to ensure view is fully loaded and animations complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
            Task {
                await ollamaManager.checkConnection()
                if ollamaManager.isConnected {
                    await ollamaManager.fetchModels()
                }
            }
        }
        .onChange(of: viewDidAppear) { _, appeared in
            if appeared {
                // Try to focus again if view just appeared
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !isInputFocused {
                        isInputFocused = true
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.title3)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Chat")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let model = ollamaManager.selectedModel {
                    Text(model.displayName)
                        .font(.caption)
                        .foregroundColor(.gray)
                } else if !ollamaManager.isConnected {
                    Text("Ollama not connected")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("No model selected")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Model Picker Button
            if ollamaManager.isConnected && !ollamaManager.availableModels.isEmpty {
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
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
            }
            
            // Clear Chat Button
            if !ollamaManager.messages.isEmpty {
                Button {
                    withAnimation {
                        ollamaManager.clearChat()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Start a conversation")
                .font(.title3)
                .foregroundColor(.white)
            
            Text("Ask me anything!")
                .font(.caption)
                .foregroundColor(.gray)
            
            if !ollamaManager.isConnected {
                VStack(spacing: 8) {
                    Text("Ollama not detected")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("Make sure Ollama is running on your Mac")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Button("Retry Connection") {
                        Task {
                            await ollamaManager.checkConnection()
                            if ollamaManager.isConnected {
                                await ollamaManager.fetchModels()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Messages
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(ollamaManager.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    // Streaming indicator
                    if ollamaManager.isStreaming && ollamaManager.currentStreamingMessage.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 8, height: 8)
                                    .opacity(0.6)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                        value: ollamaManager.isStreaming
                                    )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.leading, 12)
                    }
                }
                .padding()
            }
            .onChange(of: ollamaManager.messages.count) { _, _ in
                if let lastMessage = ollamaManager.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: ollamaManager.currentStreamingMessage) { _, _ in
                if let lastMessage = ollamaManager.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            if let error = ollamaManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        ollamaManager.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.2))
            }
            
            Divider()
                .opacity(0.3)
            
            HStack(alignment: .bottom, spacing: 12) {
                // Voice Mode Button (optional)
                if isVoiceMode {
                    Button {
                        // TODO: Implement voice recording
                        // For now, just a placeholder
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                ZStack(alignment: .leading) {
                    // Background that responds to clicks
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .frame(minHeight: 36)
                        .onTapGesture {
                            isInputFocused = true
                        }
                    
                    // Placeholder text
                    if inputText.isEmpty && !isInputFocused {
                        Text("Message...")
                            .foregroundColor(.gray)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    
                    // Actual text field
                    TextField("", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundColor(.white)
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .disabled(!ollamaManager.isConnected || ollamaManager.selectedModel == nil)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .onSubmit {
                            sendMessage()
                        }
                }
                
                Button {
                    if ollamaManager.isStreaming {
                        ollamaManager.stopStreaming()
                    } else {
                        sendMessage()
                    }
                } label: {
                    Image(systemName: ollamaManager.isStreaming ? "stop.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(canSend ? .blue : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!canSend && !ollamaManager.isStreaming)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.03))
        }
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

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: OllamaMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.isUser ? Color.blue : Color.white.opacity(0.1))
                    .cornerRadius(16)
                    .textSelection(.enabled)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AIChatView()
        .frame(width: 600, height: 700)
}
