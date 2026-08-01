import Foundation

public struct VentoWorkoutPayload: Codable, Equatable, Sendable {
    public let start: String
    public let end: String
    public let avg_hr: Double
    public let strain: Double

    public init(start: String, end: String, avg_hr: Double, strain: Double) {
        self.start = start
        self.end = end
        self.avg_hr = avg_hr
        self.strain = strain
    }
}

public struct VentoDailyPayload: Codable, Equatable, Sendable {
    public let device_serial: String
    public let date: String
    public let hr_resting: Double
    public let hrv_rmssd_ms: Double
    public let spo2_avg_pct: Double
    public let skin_temp_c: Double
    public let resp_rate_avg: Double
    public let recovery_score: Double
    public let strain_score: Double
    public let stress_avg: Double
    public let sleep_hours: Double
    public let sleep_efficiency_pct: Double
    public let workouts: [VentoWorkoutPayload]

    public init(device_serial: String = "5AG0371037", date: String, hr_resting: Double, hrv_rmssd_ms: Double, spo2_avg_pct: Double, skin_temp_c: Double, resp_rate_avg: Double, recovery_score: Double, strain_score: Double, stress_avg: Double, sleep_hours: Double, sleep_efficiency_pct: Double, workouts: [VentoWorkoutPayload]) {
        self.device_serial = device_serial
        self.date = date
        self.hr_resting = hr_resting
        self.hrv_rmssd_ms = hrv_rmssd_ms
        self.spo2_avg_pct = spo2_avg_pct
        self.skin_temp_c = skin_temp_c
        self.resp_rate_avg = resp_rate_avg
        self.recovery_score = recovery_score
        self.strain_score = strain_score
        self.stress_avg = stress_avg
        self.sleep_hours = sleep_hours
        self.sleep_efficiency_pct = sleep_efficiency_pct
        self.workouts = workouts
    }
}

public enum VentoBridgeError: Error, Equatable {
    case missingWebhookURL
    case invalidResponse
    case httpStatus(Int)
}

public struct VentoBridge: Sendable {
    private let session: URLSession
    private let encoder: JSONEncoder
    private let sleeper: @Sendable (UInt64) async throws -> Void

    public init(session: URLSession = .shared, encoder: JSONEncoder = JSONEncoder(), sleeper: @escaping @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }) {
        self.session = session
        self.encoder = encoder
        self.sleeper = sleeper
    }

    public func post(_ payload: VentoDailyPayload, webhookURL: URL? = Config.webhookURL) async throws {
        guard let webhookURL else { throw VentoBridgeError.missingWebhookURL }
        let body = try encoder.encode(payload)
        var lastError: Error?

        for attempt in 0..<5 {
            do {
                var request = URLRequest(url: webhookURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = body

                let (_, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw VentoBridgeError.invalidResponse
                }
                guard (200..<300).contains(http.statusCode) else {
                    throw VentoBridgeError.httpStatus(http.statusCode)
                }
                return
            } catch {
                lastError = error
                if attempt < 4 {
                    let seconds = UInt64(pow(2.0, Double(attempt)))
                    try await sleeper(seconds * 1_000_000_000)
                }
            }
        }

        throw lastError ?? VentoBridgeError.invalidResponse
    }
}
