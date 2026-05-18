import Foundation

struct CardEntry: Identifiable, Codable {
    var id:     String = UUID().uuidString
    var cardID: String? = nil
    var note:   String = ""
}

struct ReadingEntry: Identifiable, Codable {
    var id:          String
    var date:        Date
    var title:       String
    var body:        String
    var cardEntries: [CardEntry]

    init(id:          String     = UUID().uuidString,
         date:        Date       = Date(),
         title:       String     = "",
         body:        String     = "",
         cardEntries: [CardEntry] = []) {
        self.id = id; self.date = date; self.title = title
        self.body = body; self.cardEntries = cardEntries
    }

    var allCardIDs: [String] { cardEntries.compactMap { $0.cardID } }
}
