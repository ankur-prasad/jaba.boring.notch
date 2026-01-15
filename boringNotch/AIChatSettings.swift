//
//  AIChatSettings.swift
//  boringNotch
//
//  AI Chat Settings View
//

import SwiftUI
import Defaults

extension Defaults.Keys {
    static let ollamaBaseURL = Key<String>("ollamaBaseURL", default: "http://localhost:11434")
    static let aiChatEnabled = Key<Bool>("aiChatEnabled", default: true)
}

struct AIChatSettings: View {
    @ObservedObject var ollamaManager = OllamaManager.shared
    @Default(.ollamaBaseURL) var ollamaBaseURL
    @Default(.aiChatEnabled) var aiChatEnabled
    @State private var customURL: String = ""
    @State private var showingURLEditor = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text("AI Chat")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Chat with AI models using Ollama")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Enable/Disable
                GroupBox {
                    Toggle("Enable AI Chat", isOn: $aiChatEnabled)
                        .toggleStyle(.switch)
                } label: {
                    Label("General", systemImage: "switch.2")
                }
                
                // Connection Status
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Circle()
                                .fill(ollamaManager.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(ollamaManager.isConnected ? "Connected to Ollama" : "Not Connected")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Button("Refresh") {
                                Task {
                                    await ollamaManager.checkConnection()
                                    if ollamaManager.isConnected {
                                        await ollamaManager.fetchModels()
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        if !ollamaManager.isConnected {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Make sure Ollama is installed and running")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Link("Download Ollama", destination: URL(string: "https://ollama.ai")!)
                                    .font(.caption)
                            }
                        }
                    }
                } label: {
                    Label("Connection", systemImage: "network")
                }
                
                // Server URL
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Server URL:")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text(ollamaBaseURL)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Button("Change Server URL") {
                            customURL = ollamaBaseURL
                            showingURLEditor = true
                        }
                        .buttonStyle(.bordered)
                        
                        if ollamaBaseURL != "http://localhost:11434" {
                            Button("Reset to Default") {
                                ollamaBaseURL = "http://localhost:11434"
                                ollamaManager.updateBaseURL(ollamaBaseURL)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                } label: {
                    Label("Server", systemImage: "server.rack")
                }
                
                // Available Models
                if !ollamaManager.availableModels.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Available Models")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text("\(ollamaManager.availableModels.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            ForEach(ollamaManager.availableModels) { model in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.displayName)
                                            .font(.body)
                                        
                                        if !model.displaySize.isEmpty {
                                            Text(model.displaySize)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if model == ollamaManager.selectedModel {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } label: {
                        Label("Models", systemImage: "cpu")
                    }
                } else if ollamaManager.isConnected {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No models installed")
                                .font(.subheadline)
                            
                            Text("Install a model using Terminal:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("ollama pull llama2")
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                            
                            Text("Or try other models:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• ollama pull mistral")
                                Text("• ollama pull codellama")
                                Text("• ollama pull llama3")
                            }
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        }
                    } label: {
                        Label("Models", systemImage: "cpu")
                    }
                }
                
                // Usage Tips
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        tipRow(icon: "command", text: "Press ⌥ Option while clicking the notch to open AI Chat")
                        tipRow(icon: "keyboard", text: "Press ⌘ Command + Shift + J to toggle AI Chat")
                        tipRow(icon: "brain", text: "Select different models from the chat header")
                        tipRow(icon: "trash", text: "Clear chat history anytime from the chat header")
                    }
                } label: {
                    Label("Tips", systemImage: "lightbulb")
                }
                
                Spacer()
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingURLEditor) {
            URLEditorSheet(url: $customURL) {
                ollamaBaseURL = customURL
                ollamaManager.updateBaseURL(customURL)
                showingURLEditor = false
            }
        }
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct URLEditorSheet: View {
    @Binding var url: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Server URL")
                .font(.headline)
            
            TextField("http://localhost:11434", text: $url)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(url.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
}

#Preview {
    AIChatSettings()
}
