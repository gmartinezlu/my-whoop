import Foundation

public enum Config {
    public static let webhookURLDefaultsKey = "ventoWebhookURL"
    public static let coachURLDefaultsKey = "ventoCoachURL"
    public static let defaultVentoWebhookURLString = "https://cloud.vento.build/api/core/v1/networks/mywhoop/boards/whoop_webhook/cards/ingest/run/raw?token=8360e0f8f85c12d370458e78eba982963c60223a2b9b98b7"
    public static let defaultVentoCoachURLString = "https://cloud.vento.build/api/core/v1/networks/mywhoop/boards/whoop_webhook/cards/coach/run/raw?token=673e24a31398bd5c92dbca2180da4d903a1ddb43362fc3b5"

    public static var webhookURL: URL? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: webhookURLDefaultsKey), !raw.isEmpty else {
                return nil
            }
            return URL(string: raw)
        }
        set {
            UserDefaults.standard.set(newValue?.absoluteString, forKey: webhookURLDefaultsKey)
        }
    }

    public static var coachURL: URL? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: coachURLDefaultsKey), !raw.isEmpty else {
                return nil
            }
            return URL(string: raw)
        }
        set {
            UserDefaults.standard.set(newValue?.absoluteString, forKey: coachURLDefaultsKey)
        }
    }
}
