import Foundation

enum WebSocketConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed(String)

    var isRunning: Bool {
        switch self {
        case .connecting, .connected, .reconnecting: true
        case .disconnected, .failed: false
        }
    }

    var localizedTitle: String {
        switch self {
        case .disconnected: String(localized: "feed.state.disconnected")
        case .connecting: String(localized: "feed.state.connecting")
        case .connected: String(localized: "feed.state.connected")
        case .reconnecting: String(localized: "feed.state.reconnecting")
        case .failed: String(localized: "feed.state.failed")
        }
    }
}
