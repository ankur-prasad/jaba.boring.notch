import Foundation
import SwiftUI

@MainActor
class ChatHistoryManager: ObservableObject {
    @Published var chatSessions: [ChatSession] = []
    @Published var projects: [Project] = []
    @Published var currentSession: ChatSession?

    private let chatsKey = "jaba_chat_sessions"
    private let projectsKey = "jaba_projects"

    init() {
        loadChatSessions()
        loadProjects()
    }

    func createNewChat(projectId: UUID? = nil) -> ChatSession {
        let newSession = ChatSession(projectId: projectId)
        chatSessions.insert(newSession, at: 0)
        currentSession = newSession
        saveChatSessions()
        return newSession
    }

    func selectChat(_ session: ChatSession) {
        currentSession = session
    }

    func updateCurrentSession(messages: [Message]) {
        guard let session = currentSession else { return }

        if let index = chatSessions.firstIndex(where: { $0.id == session.id }) {
            let oldMessageCount = chatSessions[index].messages.count
            let newMessageCount = messages.count

            chatSessions[index].messages = messages

            // Only update timestamp if new messages were added
            if newMessageCount > oldMessageCount {
                chatSessions[index].updatedAt = Date()
            }

            // Auto-generate title from first message
            if chatSessions[index].title == "New Chat",
               let firstUserMessage = messages.first(where: { $0.role == .user }) {
                chatSessions[index].title = String(firstUserMessage.content.prefix(50))
            }

            currentSession = chatSessions[index]
            saveChatSessions()
        }
    }

    func deleteChat(_ session: ChatSession) {
        chatSessions.removeAll { $0.id == session.id }
        if currentSession?.id == session.id {
            currentSession = nil
        }
        saveChatSessions()
    }

    func renameChat(_ session: ChatSession, newName: String) {
        if let index = chatSessions.firstIndex(where: { $0.id == session.id }) {
            chatSessions[index].title = newName
            chatSessions[index].updatedAt = Date()
            saveChatSessions()
        }
    }

    // Project Management
    func createProject(name: String, description: String = "", color: String = "blue") -> Project {
        let project = Project(name: name, description: description, color: color)
        projects.append(project)
        saveProjects()
        return project
    }

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            saveProjects()
        }
    }

    func deleteProject(_ project: Project) {
        // Remove project
        projects.removeAll { $0.id == project.id }

        // Remove project association from chats
        for i in chatSessions.indices {
            if chatSessions[i].projectId == project.id {
                chatSessions[i].projectId = nil
            }
        }

        saveProjects()
        saveChatSessions()
    }

    func assignChatToProject(chatId: UUID, projectId: UUID?) {
        if let index = chatSessions.firstIndex(where: { $0.id == chatId }) {
            chatSessions[index].projectId = projectId
            saveChatSessions()
        }
    }

    func chatsForProject(_ projectId: UUID) -> [ChatSession] {
        return chatSessions.filter { $0.projectId == projectId }
    }

    func chatsWithoutProject() -> [ChatSession] {
        return chatSessions.filter { $0.projectId == nil }
    }

    // Persistence
    private func saveChatSessions() {
        if let encoded = try? JSONEncoder().encode(chatSessions) {
            UserDefaults.standard.set(encoded, forKey: chatsKey)
        }
    }

    private func loadChatSessions() {
        if let data = UserDefaults.standard.data(forKey: chatsKey),
           let decoded = try? JSONDecoder().decode([ChatSession].self, from: data) {
            chatSessions = decoded.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    private func saveProjects() {
        if let encoded = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(encoded, forKey: projectsKey)
        }
    }

    private func loadProjects() {
        if let data = UserDefaults.standard.data(forKey: projectsKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded.sorted { $0.updatedAt > $1.updatedAt }
        }
    }
}
