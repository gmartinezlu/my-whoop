import XCTest
@testable import Sync

final class VentoBridgeTests: XCTestCase {
    func testPayloadEncodesRequiredJSONKeys() throws {
        let payload = VentoDailyPayload(
            date: "2026-08-01",
            hr_resting: 50,
            hrv_rmssd_ms: 60,
            spo2_avg_pct: 97,
            skin_temp_c: 33.1,
            resp_rate_avg: 14,
            recovery_score: 80,
            strain_score: 12,
            stress_avg: 35,
            sleep_hours: 7.5,
            sleep_efficiency_pct: 90,
            workouts: [VentoWorkoutPayload(start: "08:00", end: "08:45", avg_hr: 145, strain: 8)]
        )
        let data = try JSONEncoder().encode(payload)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["device_serial"] as? String, "5AG0371037")
        XCTAssertNotNil(object["workouts"])
        XCTAssertEqual(object["stress_avg"] as? Double, 35)
    }

    func testCoachMetricsEncodesHealthContext() throws {
        let metrics = VentoCoachMetrics(
            live_hr: 72,
            hrv_rmssd_ms: 48,
            recovery_score: 75,
            strain_score: 6.5,
            steps: 8300,
            active_calories_kcal: 420,
            vo2max: 38.2,
            sleep_hours: 7.1,
            awakenings: 2,
            menstrual_cycle_day: 12,
            menstrual_phase: "Folicular",
            mood_trend: "Estable",
            workout_active: false
        )
        let data = try JSONEncoder().encode(metrics)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["menstrual_phase"] as? String, "Folicular")
        XCTAssertEqual(object["steps"] as? Int, 8300)
    }
}
