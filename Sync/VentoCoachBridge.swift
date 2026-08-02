import Foundation

public struct VentoCoachMetrics: Codable, Equatable, Sendable {
    public let live_hr: Int?
    public let hrv_rmssd_ms: Double?
    public let recovery_score: Int
    public let strain_score: Double
    public let steps: Int
    public let active_calories_kcal: Double?
    public let vo2max: Double?
    public let sleep_hours: Double?
    public let awakenings: Int
    public let menstrual_cycle_day: Int?
    public let menstrual_phase: String
    public let mood_trend: String
    public let workout_active: Bool

    public init(live_hr: Int?, hrv_rmssd_ms: Double?, recovery_score: Int, strain_score: Double, steps: Int, active_calories_kcal: Double?, vo2max: Double?, sleep_hours: Double?, awakenings: Int, menstrual_cycle_day: Int?, menstrual_phase: String, mood_trend: String, workout_active: Bool) {
        self.live_hr = live_hr
        self.hrv_rmssd_ms = hrv_rmssd_ms
        self.recovery_score = recovery_score
        self.strain_score = strain_score
        self.steps = steps
        self.active_calories_kcal = active_calories_kcal
        self.vo2max = vo2max
        self.sleep_hours = sleep_hours
        self.awakenings = awakenings
        self.menstrual_cycle_day = menstrual_cycle_day
        self.menstrual_phase = menstrual_phase
        self.mood_trend = mood_trend
        self.workout_active = workout_active
    }
}

public struct VentoCoachResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let summary: String
    public let recommendation: String
    public let training_focus: String
}

public enum VentoCoachError: Error, Equatable {
    case missingCoachURL
    case invalidResponse
    case httpStatus(Int)
}

public struct VentoCoachBridge: Sendable {
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared, encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
    }

    public func ask(_ metrics: VentoCoachMetrics, coachURL: URL? = Config.coachURL) async throws -> VentoCoachResponse {
        guard let coachURL else { throw VentoCoachError.missingCoachURL }
        var request = URLRequest(url: coachURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(metrics)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw VentoCoachError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw VentoCoachError.httpStatus(http.statusCode)
        }
        return try decoder.decode(VentoCoachResponse.self, from: data)
    }
}
