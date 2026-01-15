import Foundation
import SwiftUI

@MainActor
class JABAManager: ObservableObject {
    static let shared = JABAManager()

    @Published var chatViewModel: ChatViewModel
    @Published var isVoiceModeActive: Bool = false

    private init() {
        self.chatViewModel = ChatViewModel()
        setupServices()
    }

    private func setupServices() {
        // Initialize Ollama service and check connection
        chatViewModel.ollamaService.checkConnection()

        // Request speech authorization
        JABASpeechManager.shared.requestAuthorization()
    }

    func activateVoiceMode() {
        isVoiceModeActive = true
    }

    func deactivateVoiceMode() {
        isVoiceModeActive = false
        JABASpeechManager.shared.stopRecording()
        JABASpeechManager.shared.stopSpeaking()
    }

    func toggleVoiceMode() {
        if isVoiceModeActive {
            deactivateVoiceMode()
        } else {
            activateVoiceMode()
        }
    }
}
