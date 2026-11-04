import Foundation

@MainActor
protocol WebSocketManaging: AnyObject {
    func connect(to endpoint: URL) -> UUID
    func send(_ message: String, sessionID: UUID) async throws
    func receive(sessionID: UUID) async throws -> String
    func disconnect(sessionID: UUID)
}

enum WebSocketError: LocalizedError, Equatable {
    case notConnected
    case connectionReplaced
    case invalidUTF8
    case unsupportedMessage
    case invalidPayload
    case unexpectedEcho
    case transportFailure(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConnected: "The WebSocket is not connected."
        case .connectionReplaced: "The WebSocket connection was replaced."
        case .invalidUTF8: "The WebSocket returned data that is not valid UTF-8."
        case .unsupportedMessage: "The WebSocket returned an unsupported message type."
        case .invalidPayload: "The WebSocket returned an invalid stock feed payload."
        case .unexpectedEcho: "The WebSocket response did not match the message sent."
        case let .transportFailure(_, message): message
        }
    }

    var isRetryable: Bool {
        switch self {
        case .notConnected, .connectionReplaced, .transportFailure: true
        case .invalidUTF8, .unsupportedMessage, .invalidPayload, .unexpectedEcho: false
        }
    }

    static func classify(_ error: Error) -> WebSocketError {
        if let error = error as? WebSocketError { return error }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .transportFailure(code: nsError.code, message: error.localizedDescription)
        }
        return .transportFailure(code: nsError.code, message: error.localizedDescription)
    }
}
