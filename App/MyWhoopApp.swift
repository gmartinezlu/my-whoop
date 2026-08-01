import BLE
import SwiftUI
import WhoopUI

@main
struct MyWhoopApp: App {
    @StateObject private var bleManager = BLEManager()

    var body: some Scene {
        WindowGroup {
            TodayView(bleManager: bleManager)
        }
    }
}
