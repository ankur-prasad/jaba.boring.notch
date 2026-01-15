import Foundation
import Speech
import AVFoundation

class JABASpeechManager: NSObject, ObservableObject {
    static let shared = JABASpeechManager()

    // Speech Recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // Speech Synthesis
    private let speechSynthesizer = AVSpeechSynthesizer()

    @Published var isAuthorized = false
    @Published var isRecording = false
    @Published var isSpeaking = false

    private var recordingCompletion: ((Result<String, Error>) -> Void)?

    override private init() {
        super.init()
        speechSynthesizer.delegate = self
        requestAuthorization()
    }

    // MARK: - Authorization

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.isAuthorized = status == .authorized
            }
        }
    }

    // MARK: - Speech Recognition

    func startRecording(completion: @escaping (Result<String, Error>) -> Void) {
        // Check authorization
        guard isAuthorized else {
            completion(.failure(SpeechError.notAuthorized))
            return
        }

        // Cancel any ongoing recognition
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            completion(.failure(error))
            return
        }

        // Create and configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            completion(.failure(SpeechError.recognitionFailed))
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // Get the audio input node
        let inputNode = audioEngine.inputNode

        // Create a recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            var isFinal = false

            if let result = result {
                isFinal = result.isFinal
                if isFinal {
                    self?.stopRecording()
                    completion(.success(result.bestTranscription.formattedString))
                }
            }

            if error != nil || isFinal {
                self?.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self?.recognitionRequest = nil
                self?.recognitionTask = nil
                self?.isRecording = false

                if let error = error {
                    completion(.failure(error))
                }
            }
        }

        // Configure the microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start the audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            recordingCompletion = completion
        } catch {
            completion(.failure(error))
        }
    }

    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        isRecording = false
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    // MARK: - Speech Synthesis

    func speak(text: String, completion: (() -> Void)? = nil) {
        // Stop any ongoing speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        // Clean text for better speech (remove markdown, emojis)
        let cleanedText = cleanTextForSpeech(text)

        let utterance = AVSpeechUtterance(string: cleanedText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        speechSynthesizer.speak(utterance)

        // Store completion
        if let completion = completion {
            // Use a timer to check when speech is done
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.waitForSpeechCompletion(completion: completion)
            }
        }
    }

    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    private func waitForSpeechCompletion(completion: @escaping () -> Void) {
        if !speechSynthesizer.isSpeaking {
            isSpeaking = false
            completion()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.waitForSpeechCompletion(completion: completion)
            }
        }
    }

    private func cleanTextForSpeech(_ text: String) -> String {
        var cleaned = text

        // Remove markdown headers
        cleaned = cleaned.replacingOccurrences(of: #"#+\s+"#, with: "", options: .regularExpression)

        // Remove markdown bold/italic
        cleaned = cleaned.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"__(.+?)__"#, with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"_(.+?)_"#, with: "$1", options: .regularExpression)

        // Remove markdown links
        cleaned = cleaned.replacingOccurrences(of: #"\[(.+?)\]\(.+?\)"#, with: "$1", options: .regularExpression)

        // Remove code blocks and inline code
        cleaned = cleaned.replacingOccurrences(of: #"```[\s\S]*?```"#, with: "code block", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"`(.+?)`"#, with: "$1", options: .regularExpression)

        // Remove emojis (simple approach - remove common emoji patterns)
        let emojiPattern = "[\\u{1F600}-\\u{1F64F}\\u{1F300}-\\u{1F5FF}\\u{1F680}-\\u{1F6FF}\\u{2600}-\\u{26FF}\\u{2700}-\\u{27BF}\\u{1F900}-\\u{1F9FF}\\u{1F1E0}-\\u{1F1FF}]"
        cleaned = cleaned.replacingOccurrences(of: emojiPattern, with: "", options: .regularExpression)

        // Clean up extra whitespace
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension JABASpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
        }
    }
}

// MARK: - Errors
enum SpeechError: LocalizedError {
    case notAuthorized
    case recognitionFailed
    case audioEngineError

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in System Settings."
        case .recognitionFailed:
            return "Failed to create speech recognition request."
        case .audioEngineError:
            return "Audio engine error."
        }
    }
}
