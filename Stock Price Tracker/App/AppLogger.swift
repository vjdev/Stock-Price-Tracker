import Foundation
import OSLog

enum AppLogger {
    static func logger(
        category: String,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) -> Logger {
        Logger(subsystem: bundleIdentifier ?? "StockTracker", category: category)
    }
}
