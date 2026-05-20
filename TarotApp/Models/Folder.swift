import Foundation

struct Folder: Identifiable, Codable {
    var id:        String
    var name:      String
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
