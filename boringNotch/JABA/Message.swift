import Foundation

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let metrics: MessageMetrics?
    let attachments: [MessageAttachment]?

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date(), metrics: MessageMetrics? = nil, attachments: [MessageAttachment]? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metrics = metrics
        self.attachments = attachments
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

struct MessageAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    let type: AttachmentType
    let fileName: String
    let data: Data
    let mimeType: String

    init(id: UUID = UUID(), type: AttachmentType, fileName: String, data: Data, mimeType: String) {
        self.id = id
        self.type = type
        self.fileName = fileName
        self.data = data
        self.mimeType = mimeType
    }

    static func == (lhs: MessageAttachment, rhs: MessageAttachment) -> Bool {
        lhs.id == rhs.id
    }
}

enum AttachmentType: String, Codable {
    case image
    case pdf
    case text
}

struct MessageMetrics: Codable, Equatable {
    let totalTokens: Int
    let tokensPerSecond: Double
    let timeToFirstToken: Double // in seconds
    let totalDuration: Double // in seconds
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
    let temperature: Double?
    let options: [String: AnyCodable]?

    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
}

// Helper to encode any type
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Cannot encode value"))
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
}

struct ChatResponse: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Codable {
        let index: Int?
        let message: ChatMessage
        let finish_reason: String?

        struct ChatMessage: Codable {
            let role: String
            let content: String
        }
    }
    
    struct Usage: Codable {
        let prompt_tokens: Int?
        let completion_tokens: Int?
        let total_tokens: Int?
    }
}
