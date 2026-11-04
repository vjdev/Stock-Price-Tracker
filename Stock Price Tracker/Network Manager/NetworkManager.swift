import Foundation
import os

@MainActor
final class NetworkManager: WebSocketManaging {
    private let logger = AppLogger.logger(category: "WebSocket")
    private let taskFactory: (URL) -> WebSocketTasking
    private var task: WebSocketTasking?
    private var activeSessionID: UUID?

    init(taskFactory: @escaping (URL) -> WebSocketTasking = URLSessionWebSocketTaskAdapter.init(endpoint:)) {
        self.taskFactory = taskFactory
    }

    func connect(to endpoint: URL) -> UUID {
        disconnectCurrent()
        let task = taskFactory(endpoint)
        let sessionID = UUID()
        self.task = task
        activeSessionID = sessionID
        task.resume()
        logger.info("Started WebSocket connection to \(endpoint.absoluteString, privacy: .public)")
        return sessionID
    }

    func send(_ message: String, sessionID: UUID) async throws {
        guard activeSessionID == sessionID, let task else {
            throw WebSocketError.connectionReplaced
        }
        do {
            try await task.send(.string(message))
            guard activeSessionID == sessionID else { throw WebSocketError.connectionReplaced }
        } catch {
            let classified = Self.classify(error)
            logger.error("WebSocket send failed: \(classified.localizedDescription, privacy: .public)")
            throw classified
        }
    }

    func receive(sessionID: UUID) async throws -> String {
        guard activeSessionID == sessionID, let task else {
            throw WebSocketError.connectionReplaced
        }
        do {
            let message = try await task.receive()
            guard activeSessionID == sessionID else { throw WebSocketError.connectionReplaced }
            switch message {
            case let .string(text):
                return text
            case let .data(data):
                guard let text = String(data: data, encoding: .utf8) else {
                    throw WebSocketError.invalidUTF8
                }
                return text
            @unknown default:
                throw WebSocketError.unsupportedMessage
            }
        } catch {
            let classified = Self.classify(error)
            logger.error("WebSocket receive failed: \(classified.localizedDescription, privacy: .public)")
            throw classified
        }
    }

    func disconnect(sessionID: UUID) {
        guard activeSessionID == sessionID else { return }
        disconnectCurrent()
    }

    private func disconnectCurrent() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        activeSessionID = nil
    }

    private static func classify(_ error: Error) -> WebSocketError {
        if let error = error as? WebSocketError { return error }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return .connectionReplaced
        }
        return .classify(error)
    }
}

@MainActor
protocol WebSocketTasking: AnyObject {
    func resume()
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

@MainActor
private final class URLSessionWebSocketTaskAdapter: WebSocketTasking {
    private let task: URLSessionWebSocketTask

    init(endpoint: URL) {
        task = URLSession.shared.webSocketTask(with: endpoint)
    }

    func resume() {
        task.resume()
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        try await task.send(message)
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try await task.receive()
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        task.cancel(with: closeCode, reason: reason)
    }
}
