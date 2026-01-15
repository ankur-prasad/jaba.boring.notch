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

struct OllamaMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: String
    let content: String
    let timestamp: Date
    
    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
    
    var isUser: Bool {
        role == "user"
    }
}

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [MessagePayload]
    let stream: Bool
    
    struct MessagePayload: Codable {
        let role: String
        let content: String
    }
}

struct OllamaChatResponse: Codable {
    let model: String
    let message: MessageContent
    let done: Bool
    
    struct MessageContent: Codable {
        let role: String
        let content: String
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
    @Published var errorMessage: String?
    
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
        
        let (bytes, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OllamaError.serverNotReachable
        }
        
        var fullResponse = ""
        
        for try await line in bytes.lines {
            guard !line.isEmpty else { continue }
            
            do {
                let chatResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: Data(line.utf8))
                fullResponse += chatResponse.message.content
                
                // Update the message in real-time
                if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    messages[index] = OllamaMessage(
                        id: assistantMessageId,
                        role: "assistant",
                        content: fullResponse,
                        timestamp: messages[index].timestamp
                    )
                }
                
                currentStreamingMessage = fullResponse
                
                if chatResponse.done {
                    break
                }
            } catch {
                print("Error decoding stream chunk: \(error)")
            }
        }
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
