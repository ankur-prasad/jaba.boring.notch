//
//  OllamaManager.swift
//  boringNotch
//
//  AI Chat integration with Ollama
//

import Foundation
import Combine
import SwiftUI

// MARK: - Models

struct OllamaModel: Codable, Identifiable, Hashable {
    let name: String
    let modifiedAt: String?
    let size: Int64?
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
    }
    
    var displayName: String {
        name.components(separatedBy: ":").first ?? name
    }
    
    var displaySize: String {
        guard let size = size else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct OllamaModelsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaMessageMetrics: Codable, Equatable {
    let tokenCount: Int
    let tokensPerSecond: Double
    let timeToFirstToken: Double  // seconds
    let totalTime: Double  // seconds
}

struct OllamaMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: String
    let content: String
    let thinking: String?  // Reasoning/thinking content from models that support it
    let timestamp: Date
    let metrics: OllamaMessageMetrics?

    init(id: UUID = UUID(), role: String, content: String, thinking: String? = nil, timestamp: Date = Date(), metrics: OllamaMessageMetrics? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.thinking = thinking
        self.timestamp = timestamp
        self.metrics = metrics
    }

    var isUser: Bool {
        role == "user"
    }

    var hasThinking: Bool {
        thinking != nil && !thinking!.isEmpty
    }
}

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [MessagePayload]
    let stream: Bool
    let options: Options?

    struct MessagePayload: Codable {
        let role: String
        let content: String
    }

    struct Options: Codable {
        let num_ctx: Int?  // Context window size
        // Add other options as needed
    }

    init(model: String, messages: [MessagePayload], stream: Bool, options: Options? = nil) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.options = options
    }
}

struct OllamaChatResponse: Codable {
    let model: String
    let message: MessageContent
    let done: Bool
    // These fields are only present when done=true
    let totalDuration: Int64?  // nanoseconds
    let loadDuration: Int64?   // nanoseconds
    let promptEvalCount: Int?
    let promptEvalDuration: Int64?  // nanoseconds
    let evalCount: Int?  // number of generated tokens
    let evalDuration: Int64?  // nanoseconds

    struct MessageContent: Codable {
        let role: String
        let content: String
    }

    enum CodingKeys: String, CodingKey {
        case model, message, done
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalCount = "prompt_eval_count"
        case promptEvalDuration = "prompt_eval_duration"
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }
}

enum OllamaError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverNotReachable
    case decodingError(Error)
    case noModelsAvailable
    case streamError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Ollama URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverNotReachable:
            return "Cannot connect to Ollama. Make sure Ollama is running."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noModelsAvailable:
            return "No models available. Pull a model using 'ollama pull llama2'"
        case .streamError(let message):
            return "Streaming error: \(message)"
        }
    }
}

// MARK: - Ollama Manager

@MainActor
class OllamaManager: ObservableObject {
    static let shared = OllamaManager()

    @Published var messages: [OllamaMessage] = []
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var isStreaming: Bool = false
    @Published var availableModels: [OllamaModel] = []
    @Published var selectedModel: OllamaModel?
    @Published var currentStreamingMessage: String = ""
    @Published var currentStreamingThinking: String = ""  // Current thinking being streamed
    @Published var errorMessage: String?

    // Reasoning settings
    @Published var reasoningEnabled: Bool = true  // Show thinking if model provides it

    private var baseURL: String {
        UserDefaults.standard.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434"
    }

    private var session: URLSession
    private var streamTask: Task<Void, Never>?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        
        Task {
            await checkConnection()
            if isConnected {
                await fetchModels()
            }
        }
    }
    
    // MARK: - Connection Management
    
    func checkConnection() async {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            isConnected = false
            return
        }
        
        do {
            let (_, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                isConnected = (200...299).contains(httpResponse.statusCode)
            }
        } catch {
            isConnected = false
        }
    }
    
    func updateBaseURL(_ newURL: String) {
        UserDefaults.standard.set(newURL, forKey: "ollamaBaseURL")
        Task {
            await checkConnection()
            if isConnected {
                await fetchModels()
            }
        }
    }
    
    // MARK: - Models Management
    
    func fetchModels() async {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            errorMessage = OllamaError.invalidURL.localizedDescription
            return
        }
        
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
            availableModels = response.models
            
            if selectedModel == nil, let firstModel = response.models.first {
                selectedModel = firstModel
            }
            
            if availableModels.isEmpty {
                errorMessage = OllamaError.noModelsAvailable.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error fetching models: \(error)")
        }
    }
    
    // MARK: - Chat Management
    
    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let model = selectedModel else {
            errorMessage = "Please select a model first"
            return
        }
        
        let userMessage = OllamaMessage(role: "user", content: text)
        messages.append(userMessage)
        
        isLoading = true
        isStreaming = true
        currentStreamingMessage = ""
        currentStreamingThinking = ""
        errorMessage = nil
        
        // Create assistant message placeholder
        let assistantMessageId = UUID()
        let assistantMessage = OllamaMessage(id: assistantMessageId, role: "assistant", content: "")
        messages.append(assistantMessage)
        
        do {
            try await streamChat(model: model.name, assistantMessageId: assistantMessageId)
        } catch {
            errorMessage = error.localizedDescription
            // Remove the empty assistant message on error
            messages.removeAll { $0.id == assistantMessageId }
        }
        
        isLoading = false
        isStreaming = false
        currentStreamingMessage = ""
        currentStreamingThinking = ""
    }
    
    private func streamChat(model: String, assistantMessageId: UUID) async throws {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw OllamaError.invalidURL
        }

        let messagePayloads = messages.filter { !$0.content.isEmpty }.map {
            OllamaChatRequest.MessagePayload(role: $0.role, content: $0.content)
        }

        let requestBody = OllamaChatRequest(
            model: model,
            messages: messagePayloads,
            stream: true
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        // Track timing for metrics
        let startTime = Date()
        var firstTokenTime: Date?

        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OllamaError.serverNotReachable
        }

        var fullResponse = ""
        var finalMetrics: OllamaMessageMetrics?

        for try await line in bytes.lines {
            guard !line.isEmpty else { continue }

            do {
                let chatResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: Data(line.utf8))

                // Track time to first token
                if firstTokenTime == nil && !chatResponse.message.content.isEmpty {
                    firstTokenTime = Date()
                }

                fullResponse += chatResponse.message.content

                // Parse thinking and content from the response
                let (thinking, content) = parseThinkingContent(fullResponse)

                // Update the message in real-time (without metrics until done)
                if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    messages[index] = OllamaMessage(
                        id: assistantMessageId,
                        role: "assistant",
                        content: content,
                        thinking: thinking,
                        timestamp: messages[index].timestamp,
                        metrics: nil
                    )
                }

                currentStreamingMessage = content
                currentStreamingThinking = thinking ?? ""

                if chatResponse.done {
                    // Calculate metrics from Ollama response
                    let endTime = Date()
                    let totalTime = endTime.timeIntervalSince(startTime)
                    let timeToFirstToken = firstTokenTime?.timeIntervalSince(startTime) ?? 0

                    // Ollama provides eval_count (tokens generated) and eval_duration (nanoseconds)
                    let tokenCount = chatResponse.evalCount ?? 0
                    let evalDurationSeconds = Double(chatResponse.evalDuration ?? 0) / 1_000_000_000.0
                    let tokensPerSecond = evalDurationSeconds > 0 ? Double(tokenCount) / evalDurationSeconds : 0

                    finalMetrics = OllamaMessageMetrics(
                        tokenCount: tokenCount,
                        tokensPerSecond: tokensPerSecond,
                        timeToFirstToken: timeToFirstToken,
                        totalTime: totalTime
                    )

                    // Final parse of thinking and content
                    let (finalThinking, finalContent) = parseThinkingContent(fullResponse)

                    // Update message with final metrics
                    if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        messages[index] = OllamaMessage(
                            id: assistantMessageId,
                            role: "assistant",
                            content: finalContent,
                            thinking: finalThinking,
                            timestamp: messages[index].timestamp,
                            metrics: finalMetrics
                        )
                    }

                    break
                }
            } catch {
                print("Error decoding stream chunk: \(error)")
            }
        }
    }

    /// Parses thinking tags from model output
    /// Supports multiple formats used by different reasoning models:
    /// - <think>...</think> (DeepSeek-R1, Qwen-QwQ)
    /// - <thinking>...</thinking> (some models)
    /// - <reasoning>...</reasoning> (some models)
    /// - <thought>...</thought> (some models)
    /// - **Thinking:** ... **Response:** (markdown style, GPTOSS/GPT4All)
    /// - [Thinking] ... [Response] (bracket style)
    private func parseThinkingContent(_ text: String) -> (thinking: String?, content: String) {
        var thinkingParts: [String] = []
        var contentText = text

        // Try XML-style tags first (most common)
        let xmlPatterns = [
            #"<think>([\s\S]*?)</think>"#,
            #"<thinking>([\s\S]*?)</thinking>"#,
            #"<reasoning>([\s\S]*?)</reasoning>"#,
            #"<thought>([\s\S]*?)</thought>"#,
            #"<internal_thoughts>([\s\S]*?)</internal_thoughts>"#,
            #"<reflection>([\s\S]*?)</reflection>"#
        ]

        for pattern in xmlPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(contentText.startIndex..., in: contentText)
                let matches = regex.matches(in: contentText, options: [], range: range)

                for match in matches.reversed() {
                    if let thinkingRange = Range(match.range(at: 1), in: contentText) {
                        let thinkingText = String(contentText[thinkingRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !thinkingText.isEmpty {
                            thinkingParts.insert(thinkingText, at: 0)
                        }
                    }
                    if let fullMatchRange = Range(match.range, in: contentText) {
                        contentText.removeSubrange(fullMatchRange)
                    }
                }
            }
        }

        // If no XML tags found, try markdown-style patterns
        if thinkingParts.isEmpty {
            // Pattern: **Thinking:** or **Thought:** followed by content until **Response:** or **Answer:**
            let markdownPatterns = [
                #"\*\*(?:Thinking|Thought|Reasoning|Internal Thought):\*\*\s*([\s\S]*?)(?:\*\*(?:Response|Answer|Output|Reply):\*\*|$)"#,
                #"(?:Thinking|Thought|Reasoning):\s*([\s\S]*?)(?:(?:Response|Answer|Output|Reply):|$)"#
            ]

            for pattern in markdownPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(contentText.startIndex..., in: contentText)
                    if let match = regex.firstMatch(in: contentText, options: [], range: range) {
                        if let thinkingRange = Range(match.range(at: 1), in: contentText) {
                            let thinkingText = String(contentText[thinkingRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !thinkingText.isEmpty {
                                thinkingParts.append(thinkingText)
                                // Extract just the response part
                                if let fullMatchRange = Range(match.range, in: contentText) {
                                    let afterMatch = contentText[fullMatchRange.upperBound...]
                                    // Look for Response/Answer section
                                    let responsePatterns = [
                                        #"\*\*(?:Response|Answer|Output|Reply):\*\*\s*([\s\S]*)"#,
                                        #"(?:Response|Answer|Output|Reply):\s*([\s\S]*)"#
                                    ]
                                    var foundResponse = false
                                    for respPattern in responsePatterns {
                                        if let respRegex = try? NSRegularExpression(pattern: respPattern, options: .caseInsensitive) {
                                            let respRange = NSRange(contentText.startIndex..., in: contentText)
                                            if let respMatch = respRegex.firstMatch(in: contentText, options: [], range: respRange),
                                               let responseRange = Range(respMatch.range(at: 1), in: contentText) {
                                                contentText = String(contentText[responseRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                                                foundResponse = true
                                                break
                                            }
                                        }
                                    }
                                    if !foundResponse {
                                        contentText = String(afterMatch).trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                }
                                break
                            }
                        }
                    }
                }
            }
        }

        // Try bracket-style patterns [Thinking] ... [Response]
        if thinkingParts.isEmpty {
            let bracketPattern = #"\[(?:Thinking|Thought|Reasoning)\]\s*([\s\S]*?)(?:\[(?:Response|Answer|Output)\]|$)"#
            if let regex = try? NSRegularExpression(pattern: bracketPattern, options: .caseInsensitive) {
                let range = NSRange(contentText.startIndex..., in: contentText)
                if let match = regex.firstMatch(in: contentText, options: [], range: range) {
                    if let thinkingRange = Range(match.range(at: 1), in: contentText) {
                        let thinkingText = String(contentText[thinkingRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !thinkingText.isEmpty {
                            thinkingParts.append(thinkingText)
                            // Get content after [Response] tag
                            let responsePattern = #"\[(?:Response|Answer|Output)\]\s*([\s\S]*)"#
                            if let respRegex = try? NSRegularExpression(pattern: responsePattern, options: .caseInsensitive) {
                                if let respMatch = respRegex.firstMatch(in: contentText, options: [], range: range),
                                   let responseRange = Range(respMatch.range(at: 1), in: contentText) {
                                    contentText = String(contentText[responseRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }
                        }
                    }
                }
            }
        }

        let thinking = thinkingParts.isEmpty ? nil : thinkingParts.joined(separator: "\n\n")
        let cleanedContent = contentText.trimmingCharacters(in: .whitespacesAndNewlines)

        return (thinking, cleanedContent)
    }
    
    func clearChat() {
        messages.removeAll()
        currentStreamingMessage = ""
        errorMessage = nil
    }
    
    func deleteMessage(_ message: OllamaMessage) {
        messages.removeAll { $0.id == message.id }
    }
    
    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        isLoading = false
    }
}
