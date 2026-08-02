import Foundation

public enum RawBLELogStore {
    public static let fileName = "mywhoop-raw-ble.log"

    public static var fileURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(fileName)
    }

    public static func append(characteristicUUID: String, payloadHex: String, reason: String) {
        let line = "\(iso8601Now()) characteristic=\(characteristicUUID) reason=\(reason) payload=\(payloadHex)\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: fileURL.path), let handle = try? FileHandle(forWritingTo: fileURL) {
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public static func text() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func iso8601Now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
