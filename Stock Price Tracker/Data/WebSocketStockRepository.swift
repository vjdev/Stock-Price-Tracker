import Foundation
import os

@MainActor
final class WebSocketStockRepository: StockRepository {
    private let endpoint: URL
    private let socket: WebSocketManaging
    private let priceGenerator: StockPriceGenerating
    private let logger = AppLogger.logger(category: "StockFeed")
    private var feedTask: Task<Void, Never>?
    private var shouldRun = false
    private var runID: UInt64 = 0
    private var socketSessionID: UUID?
    private let snapshotsContinuation: AsyncStream<[Stock]>.Continuation
    private let stateContinuation: AsyncStream<WebSocketConnectionState>.Continuation

    private(set) var stocks: [Stock] = []
    let stockSnapshots: AsyncStream<[Stock]>
    let connectionStates: AsyncStream<WebSocketConnectionState>

    init(
        endpoint: URL? = nil,
        socket: WebSocketManaging? = nil,
        priceGenerator: StockPriceGenerating? = nil,
        reconnectPolicy: ReconnectPolicy = .default,
        updateInterval: Duration = .seconds(1)
    ) {
        self.endpoint = endpoint ?? AppConfiguration.stockFeedEndpoint
        self.socket = socket ?? NetworkManager()
        self.priceGenerator = priceGenerator ?? StockPriceGenerator()
        self.reconnectPolicy = reconnectPolicy
        self.updateInterval = updateInterval

        var snapshots: AsyncStream<[Stock]>.Continuation!
        stockSnapshots = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { snapshots = $0 }
        snapshotsContinuation = snapshots
        var states: AsyncStream<WebSocketConnectionState>.Continuation!
        connectionStates = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { states = $0 }
        stateContinuation = states
        snapshotsContinuation.yield([])
        stateContinuation.yield(.disconnected)
    }

    private let reconnectPolicy: ReconnectPolicy
    private let updateInterval: Duration

    deinit {
        feedTask?.cancel()
        snapshotsContinuation.finish()
        stateContinuation.finish()
        if let socketSessionID {
            let socket = socket
            Task { @MainActor in socket.disconnect(sessionID: socketSessionID) }
        }
    }

    func start() {
        guard !shouldRun else { return }
        shouldRun = true
        runID &+= 1
        let currentRunID = runID
        stateContinuation.yield(.connecting)
        feedTask = Task { [weak self] in
            await self?.runConnectionLoop(runID: currentRunID)
        }
    }

    func stop() {
        guard shouldRun || feedTask != nil else { return }
        shouldRun = false
        runID &+= 1
        feedTask?.cancel()
        feedTask = nil
        disconnectSocket()
        stateContinuation.yield(.disconnected)
    }

    func finish() {
        stop()
        snapshotsContinuation.finish()
        stateContinuation.finish()
    }

    private func runConnectionLoop(runID: UInt64) async {
        var retryAttempt = 0
        while isCurrent(runID) {
            do {
                try await runEchoSession(runID: runID) {
                    retryAttempt = 0
                }
            } catch is CancellationError {
                break
            } catch {
                guard isCurrent(runID) else { break }
                let classified = WebSocketError.classify(error)
                guard classified.isRetryable else {
                    logger.error("Non-retryable feed error: \(classified.localizedDescription, privacy: .public)")
                    shouldRun = false
                    stateContinuation.yield(.failed(classified.localizedDescription))
                    disconnectSocket()
                    break
                }

                retryAttempt += 1
                logger.error("Feed connection dropped: \(classified.localizedDescription, privacy: .public)")
                disconnectSocket()
                stateContinuation.yield(.reconnecting)
                do {
                    try await Task.sleep(for: reconnectPolicy.delay(forAttempt: retryAttempt))
                } catch {
                    break
                }
            }
        }

        if runID == self.runID {
            feedTask = nil
        }
    }

    private func runEchoSession(
        runID: UInt64,
        onSuccessfulCommunication: () -> Void
    ) async throws {
        guard isCurrent(runID) else { throw CancellationError() }
        let sessionID = socket.connect(to: endpoint)
        socketSessionID = sessionID

        _ = try await roundTrip(
            StockFeedDTO(type: "subscribe", symbols: StockWatchlist.symbols, stocks: nil, symbol: nil, price: nil, change: nil),
            sessionID: sessionID,
            runID: runID,
            onSuccessfulCommunication: onSuccessfulCommunication
        )
        publishState(.connected, runID: runID)

        let snapshot = priceGenerator.makeSnapshot()
        let echo = try await roundTrip(
            StockFeedMapper.snapshotMessage(snapshot),
            sessionID: sessionID,
            runID: runID,
            onSuccessfulCommunication: onSuccessfulCommunication
        )
        let receivedSnapshot = try StockFeedMapper.validatedSnapshot(from: echo)
        guard receivedSnapshot == snapshot else { throw WebSocketError.unexpectedEcho }
        replaceStocks(with: receivedSnapshot, runID: runID)

        while isCurrent(runID) {
            try await Task.sleep(for: updateInterval)
            let update = try priceGenerator.makeUpdate()
            let echo = try await roundTrip(
                StockFeedMapper.updateMessage(update),
                sessionID: sessionID,
                runID: runID,
                onSuccessfulCommunication: onSuccessfulCommunication
            )
            let receivedUpdate = try StockFeedMapper.stockUpdate(from: echo)
            guard receivedUpdate == update else { throw WebSocketError.unexpectedEcho }
            apply(receivedUpdate, runID: runID)
            publishState(.connected, runID: runID)
        }
    }

    private func roundTrip(
        _ request: StockFeedDTO,
        sessionID: UUID,
        runID: UInt64,
        onSuccessfulCommunication: () -> Void
    ) async throws -> StockFeedDTO {
        let data = try JSONEncoder().encode(request)
        guard let text = String(data: data, encoding: .utf8) else { throw WebSocketError.invalidPayload }
        try await socket.send(text, sessionID: sessionID)
        guard isCurrent(runID), socketSessionID == sessionID else { throw CancellationError() }
        let response = try await socket.receive(sessionID: sessionID)
        guard isCurrent(runID), socketSessionID == sessionID else { throw CancellationError() }
        guard let responseData = response.data(using: .utf8) else { throw WebSocketError.invalidPayload }
        let decoded: StockFeedDTO
        do {
            decoded = try JSONDecoder().decode(StockFeedDTO.self, from: responseData)
        } catch {
            throw WebSocketError.invalidPayload
        }
        guard decoded == request else { throw WebSocketError.unexpectedEcho }
        onSuccessfulCommunication()
        return decoded
    }

    private func replaceStocks(with snapshot: [Stock], runID: UInt64) {
        guard isCurrent(runID) else { return }
        stocks = snapshot
        snapshotsContinuation.yield(stocks)
    }

    private func apply(_ update: StockPriceUpdate, runID: UInt64) {
        guard isCurrent(runID),
              let index = stocks.firstIndex(where: { $0.symbol == update.symbol }) else { return }
        stocks[index].price = update.price
        stocks[index].change = update.change
        stocks[index].lastUpdated = .now
        snapshotsContinuation.yield(stocks)
    }

    private func publishState(_ state: WebSocketConnectionState, runID: UInt64) {
        guard isCurrent(runID) else { return }
        stateContinuation.yield(state)
    }

    private func isCurrent(_ runID: UInt64) -> Bool {
        shouldRun && self.runID == runID && !Task.isCancelled
    }

    private func disconnectSocket() {
        guard let sessionID = socketSessionID else { return }
        socketSessionID = nil
        socket.disconnect(sessionID: sessionID)
    }
}

struct ReconnectPolicy: Sendable {
    let initialDelay: TimeInterval
    let maximumDelay: TimeInterval
    let jitterFraction: Double

    nonisolated static let `default` = ReconnectPolicy(initialDelay: 1, maximumDelay: 30, jitterFraction: 0.2)

    func delay(forAttempt attempt: Int, jitter: Double = Double.random(in: -1...1)) -> Duration {
        let exponent = min(max(attempt - 1, 0), 30)
        let upperBound = max(maximumDelay, 0)
        let base = min(max(initialDelay, 0) * pow(2, Double(exponent)), upperBound)
        let fraction = min(max(jitterFraction, 0), 1)
        let adjusted = min(max(base * (1 + jitter * fraction), 0), upperBound)
        return .seconds(adjusted)
    }
}
