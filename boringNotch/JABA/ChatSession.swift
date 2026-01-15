import Foundation
import SwiftUI

struct ChatSession: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [Message]
    var createdAt: Date
    var updatedAt: Date
    var projectId: UUID?

    init(id: UUID = UUID(), title: String = "New Chat", messages: [Message] = [], createdAt: Date = Date(), updatedAt: Date = Date(), projectId: UUID? = nil) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.projectId = projectId
    }

    var preview: String {
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            return String(firstUserMessage.content.prefix(50))
        }
        return "Empty chat"
    }

    static func == (lhs: ChatSession, rhs: ChatSession) -> Bool {
        lhs.id == rhs.id
    }
}
