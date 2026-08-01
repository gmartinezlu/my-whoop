import Foundation

public struct MoodEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let moodScore: Int
    public let note: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), moodScore: Int, note: String = "") {
        self.id = id
        self.timestamp = timestamp
        self.moodScore = min(max(moodScore, 1), 5)
        self.note = note
    }
}

public enum EmotionalJournalCodec {
    public static func decode(_ raw: String) -> [MoodEntry] {
        guard let data = raw.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([MoodEntry].self, from: data)) ?? []
    }

    public static func encode(_ entries: [MoodEntry]) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    public static func trend(entries: [MoodEntry]) -> String {
        guard entries.count >= 2 else { return "Sin tendencia" }
        let recent = entries.suffix(5).map(\.moodScore)
        let average = Double(recent.reduce(0, +)) / Double(recent.count)
        let spread = (recent.max() ?? 0) - (recent.min() ?? 0)
        if spread >= 3 { return "Fluctuante" }
        if average >= 4 { return "Optimo" }
        if average <= 2 { return "Bajo" }
        return "Estable"
    }
}
