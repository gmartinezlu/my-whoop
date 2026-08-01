import Foundation

public enum Config {
    public static let webhookURLDefaultsKey = "ventoWebhookURL"

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
}
