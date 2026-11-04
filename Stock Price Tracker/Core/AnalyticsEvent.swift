import Foundation

enum AnalyticsEvent {
    case stockSelected(symbol: String)
    case feedStarted
    case feedStopped
    case connectionEstablished
    case connectionLost
    case sortChanged(type: String)

    var name: String {
        switch self {
        case .stockSelected: "stock_selected"
        case .feedStarted: "feed_started"
        case .feedStopped: "feed_stopped"
        case .connectionEstablished: "connection_established"
        case .connectionLost: "connection_lost"
        case .sortChanged: "sort_changed"
        }
    }

    var properties: [String: String] {
        switch self {
        case let .stockSelected(symbol): ["symbol": symbol]
        case let .sortChanged(type): ["type": type]
        default: [:]
        }
    }
}
