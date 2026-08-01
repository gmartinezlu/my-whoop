import XCTest
@testable import WhoopUI

final class WhoopUITests: XCTestCase {
    func testSettingsViewCanInitialize() {
        _ = SettingsView()
    }

    func testMoodEntriesRoundTripAndTrend() {
        let entries = [
            MoodEntry(moodScore: 4),
            MoodEntry(moodScore: 5),
            MoodEntry(moodScore: 4)
        ]
        let encoded = EmotionalJournalCodec.encode(entries)
        XCTAssertEqual(EmotionalJournalCodec.decode(encoded).map(\.moodScore), [4, 5, 4])
        XCTAssertEqual(EmotionalJournalCodec.trend(entries: entries), "Optimo")
    }
}
