import Foundation
import SwiftUI

struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var color: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, description: String = "", color: String = "blue", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayColor: Color {
        switch color {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "pink": return .pink
        case "yellow": return .yellow
        default: return .blue
        }
    }

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}
