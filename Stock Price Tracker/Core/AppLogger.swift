import Foundation
import OSLog

enum AppLogger {
    static func logger(category: String) -> Logger {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "StockTracker", category: category)
    }
}
