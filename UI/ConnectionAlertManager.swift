import Foundation

#if os(iOS)
import UIKit
import UserNotifications
#endif

public enum ConnectionAlertManager {
    public static func requestPermission() {
        #if os(iOS)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        #endif
    }

    public static func notify(title: String, body: String) {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "mywhoop.connection.\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
        #endif
    }
}
