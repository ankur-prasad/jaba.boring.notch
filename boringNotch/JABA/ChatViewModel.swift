import Foundation
import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentInput: String = ""
    @Published var selectedModel: String = "gemma3:4b"
    @Published var isLoading: Bool = false
    @Published var temperature: Double = 0.7
    @Published var currentAttachments: [MessageAttachment] = []
    @Published var webSearchEnabled: Bool = false
    
    // Store document context for follow-up questions
    private var documentContext: String?

    @Published var ollamaService = OllamaService()
    var llmSettings: LLMSettingsManager?

    init() {
        // Add welcome message
        messages.append(Message(
            role: .assistant,
            content: "👋 Hello! I'm JABA, running locally on your Mac. All conversations stay private. How can I help you today?"
        ))
    }

    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !currentAttachments.isEmpty else { return }

        let userMessage = Message(role: .user, content: currentInput, attachments: currentAttachments.isEmpty ? nil : currentAttachments)
        messages.append(userMessage)

        let messageContent = currentInput
        let attachments = currentAttachments
        
        currentInput = ""
        currentAttachments = []
        isLoading = true
        
        // Check if we have attachments - use vision model if so
        if !attachments.isEmpty {
            // Use vision model for attachments and store the context
            ollamaService.sendMessageWithVision(
                prompt: messageContent,
                attachments: attachments,
                temperature: llmSettings?.settings.temperature ?? temperature,
                returnExtractedText: true  // Request the extracted text to be returned
            ) { [weak self] result in
                guard let self = self else { return }

                Task { @MainActor in
                    self.isLoading = false

                    switch result {
                    case .success(let response):
                        // Store the document context for future questions
                        if let extractedText = response.extractedText {
                            self.documentContext = extractedText
                        }
                        
                        self.messages.append(Message(
                            role: .assistant,
                            content: response.content,
                            metrics: response.metrics
                        ))

                    case .failure(let error):
                        self.messages.append(Message(
                            role: .assistant,
                            content: "❌ Error processing document: \(error.localizedDescription)"
                        ))
                    }
                }
            }
        } else {
            // Standard text-only message
            // Prepare messages with system prompt if configured
            var messagesToSend = messages.filter { $0.role != .system }
            if let systemPrompt = llmSettings?.settings.systemPrompt, !systemPrompt.isEmpty {
                messagesToSend.insert(Message(role: .system, content: systemPrompt), at: 0)
            }
            
            // If we have document context, add it to the system prompt (with size limit)
            if let docContext = documentContext {
                // Truncate context if too large (max ~8000 chars to leave room for conversation)
                let maxContextLength = 8000
                let truncatedContext = docContext.count > maxContextLength 
                    ? String(docContext.prefix(maxContextLength)) + "\n\n[Document truncated due to length...]"
                    : docContext
                
                let contextPrompt = "You have access to the following document content. Use it to answer questions:\n\n\(truncatedContext)"
                messagesToSend.insert(Message(role: .system, content: contextPrompt), at: 0)
            }
            
            // Get options from LLM settings
            let options = llmSettings?.getOllamaOptions() ?? [:]

            // Send to Ollama
            ollamaService.sendMessage(
                model: selectedModel,
                messages: messagesToSend,
                temperature: llmSettings?.settings.temperature ?? temperature,
                options: options
            ) { [weak self] result in
                guard let self = self else { return }

                Task { @MainActor in
                    self.isLoading = false

                    switch result {
                    case .success(let response):
                        self.messages.append(Message(
                            role: .assistant,
                            content: response.content,
                            metrics: response.metrics
                        ))

                    case .failure(let error):
                        self.messages.append(Message(
                            role: .assistant,
                            content: "❌ Error: \(error.localizedDescription)"
                        ))
                    }
                }
            }
        }
    }

    func clearChat() {
        messages.removeAll()
        documentContext = nil  // Clear document context
        messages.append(Message(
            role: .assistant,
            content: "Chat cleared. How can I help you?"
        ))
    }

    func retryLastMessage() {
        guard let lastUserMessage = messages.last(where: { $0.role == .user }) else { return }
        currentInput = lastUserMessage.content
        sendMessage()
    }

    /// Edit a user message in place (doesn't branch, just updates the message)
    func editMessageInPlace(messageId: UUID, newContent: String) {
        guard let messageIndex = messages.firstIndex(where: { $0.id == messageId }),
              messages[messageIndex].role == .user,
              !newContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Update the message content in place
        let updatedMessage = Message(
            id: messageId,
            role: .user,
            content: newContent,
            timestamp: messages[messageIndex].timestamp
        )
        messages[messageIndex] = updatedMessage
    }

    /// Edit a user message and branch the conversation from that point
    /// Creates a new message array with all messages up to (but not including) the edited message,
    /// then adds the edited message and gets a new response
    func editMessage(messageId: UUID, newContent: String, onBranch: @escaping ([Message]) -> Void) {
        guard let messageIndex = messages.firstIndex(where: { $0.id == messageId }),
              messages[messageIndex].role == .user,
              !newContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Create branched conversation: all messages before the edited one + the new edited message
        var branchedMessages = Array(messages.prefix(messageIndex))
        let editedMessage = Message(role: .user, content: newContent)
        branchedMessages.append(editedMessage)

        // Notify that we're branching (this will create a new chat session)
        onBranch(branchedMessages)

        // Update current messages to the branched version
        messages = branchedMessages
        isLoading = true

        // Prepare messages with system prompt if configured
        var messagesToSend = messages.filter { $0.role != .system }
        if let systemPrompt = llmSettings?.settings.systemPrompt, !systemPrompt.isEmpty {
            messagesToSend.insert(Message(role: .system, content: systemPrompt), at: 0)
        }

        // Get options from LLM settings
        let options = llmSettings?.getOllamaOptions() ?? [:]

        // Send to Ollama to get new response
        ollamaService.sendMessage(
            model: selectedModel,
            messages: messagesToSend,
            temperature: llmSettings?.settings.temperature ?? temperature,
            options: options
        ) { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                self.isLoading = false

                switch result {
                case .success(let response):
                    self.messages.append(Message(
                        role: .assistant,
                        content: response.content,
                        metrics: response.metrics
                    ))

                case .failure(let error):
                    self.messages.append(Message(
                        role: .assistant,
                        content: "❌ Error: \(error.localizedDescription)"
                    ))
                }
            }
        }
    }
}
