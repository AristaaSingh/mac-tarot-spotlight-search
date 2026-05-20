import Foundation

struct CardEntry: Identifiable, Codable {
    var id:     String = UUID().uuidString
    var cardID: String? = nil
    var note:   String = ""
}

struct ReadingEntry: Identifiable, Codable {
    var id:          String
    var folderID:    String    // which folder this entry belongs to
    var date:        Date
    var title:       String
    var body:        String
    var cardEntries: [CardEntry]

    init(id:          String      = UUID().uuidString,
         folderID:    String      = "",
         date:        Date        = Date(),
         title:       String      = "",
         body:        String      = "",
         cardEntries: [CardEntry] = []) {
        self.id = id; self.folderID = folderID; self.date = date
        self.title = title; self.body = body; self.cardEntries = cardEntries
    }

    // Custom decode: folderID defaults to "" if missing (old entries without the field).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self,      forKey: .id)
        folderID    = (try? c.decodeIfPresent(String.self, forKey: .folderID)) ?? ""
        date        = try c.decode(Date.self,        forKey: .date)
        title       = try c.decode(String.self,      forKey: .title)
        body        = try c.decode(String.self,      forKey: .body)
        cardEntries = try c.decode([CardEntry].self, forKey: .cardEntries)
    }

    var allCardIDs: [String] { cardEntries.compactMap { $0.cardID } }
}
