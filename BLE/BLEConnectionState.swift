import Foundation

public enum BLEConnectionState: String, Codable, Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case syncing
    case live
}
