import Foundation

import Foundation
import SwiftUI

struct LLMSettings: Codable {
    var systemPrompt: String = ""
    var streamChatResponse: Bool = false
    var functionCalling: String = "default"
    var seed: Int? = nil
    var stopSequence: String = ""
    var temperature: Double? = nil
    var reasoningEffort: String = "default"
    var logitBias: String = ""
    var mirostat: Int? = nil
    var mirostatEta: Double? = nil
    var mirostatTau: Double? = nil
    var topK: Int? = nil
    var topP: Double? = nil
    var minP: Double? = nil
    var frequencyPenalty: Double? = nil
    var presencePenalty: Double? = nil
    var repeatLastN: Int? = nil
    var tfsZ: Double? = nil
    var numKeep: Int? = nil
    var numPredict: Int? = nil
    var repeatPenalty: Double? = nil
    var contextLength: Int? = nil
    var numBatch: Int? = nil
    var useMmap: Bool? = nil
    var useMlock: Bool? = nil
    var numThread: Int? = nil
    var numGpu: Int? = nil
    
    static var `default`: LLMSettings {
        return LLMSettings()
    }
}

@MainActor
class LLMSettingsManager: ObservableObject {
    @Published var settings = LLMSettings.default
    
    func reset() {
        settings = LLMSettings.default
    }
    
    func getOllamaOptions() -> [String: Any] {
        var options: [String: Any] = [:]
        
        if let temp = settings.temperature {
            options["temperature"] = temp
        }
        if let seed = settings.seed {
            options["seed"] = seed
        }
        if let mirostat = settings.mirostat {
            options["mirostat"] = mirostat
        }
        if let mirostatEta = settings.mirostatEta {
            options["mirostat_eta"] = mirostatEta
        }
        if let mirostatTau = settings.mirostatTau {
            options["mirostat_tau"] = mirostatTau
        }
        if let topK = settings.topK {
            options["top_k"] = topK
        }
        if let topP = settings.topP {
            options["top_p"] = topP
        }
        if let minP = settings.minP {
            options["min_p"] = minP
        }
        if let freqPenalty = settings.frequencyPenalty {
            options["frequency_penalty"] = freqPenalty
        }
        if let presPenalty = settings.presencePenalty {
            options["presence_penalty"] = presPenalty
        }
        if let repeatLastN = settings.repeatLastN {
            options["repeat_last_n"] = repeatLastN
        }
        if let tfsZ = settings.tfsZ {
            options["tfs_z"] = tfsZ
        }
        if let numKeep = settings.numKeep {
            options["num_keep"] = numKeep
        }
        if let numPredict = settings.numPredict {
            options["num_predict"] = numPredict
        }
        if let repeatPenalty = settings.repeatPenalty {
            options["repeat_penalty"] = repeatPenalty
        }
        if let contextLength = settings.contextLength {
            options["num_ctx"] = contextLength
        }
        if let numBatch = settings.numBatch {
            options["num_batch"] = numBatch
        }
        if let useMmap = settings.useMmap {
            options["use_mmap"] = useMmap
        }
        if let useMlock = settings.useMlock {
            options["use_mlock"] = useMlock
        }
        if let numThread = settings.numThread {
            options["num_thread"] = numThread
        }
        if let numGpu = settings.numGpu {
            options["num_gpu"] = numGpu
        }
        
        if !settings.stopSequence.isEmpty {
            options["stop"] = settings.stopSequence.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        
        return options
    }
}
