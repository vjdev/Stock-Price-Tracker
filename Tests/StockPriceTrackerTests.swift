import Combine
import XCTest
@testable import Stock_Price_Tracker

@MainActor
final class StockPriceTrackerTests: XCTestCase {
    func testSortingIsDeterministicForEqualPricesAndChanges() async {
        let repository = TestStockRepository()
        let viewModel = makeViewModel(repository: repository)
        repository.emit(snapshot: [
            stock("CCC", price: 20, change: 2),
            stock("AAA", price: 20, change: 2),
            stock("BBB", price: 10, change: 2)
        ])
        await waitForPublished(viewModel.$stocks) { $0.count == 3 }

        viewModel.sortOption = .priceAscending
        XCTAssertEqual(viewModel.sortedStocks.map(\.symbol), ["BBB", "AAA", "CCC"])
        viewModel.sortOption = .priceDescending
        XCTAssertEqual(viewModel.sortedStocks.map(\.symbol), ["AAA", "CCC", "BBB"])
        viewModel.sortOption = .changeAscending
        XCTAssertEqual(viewModel.sortedStocks.map(\.symbol), ["AAA", "BBB", "CCC"])
        viewModel.sortOption = .changeDescending
        XCTAssertEqual(viewModel.sortedStocks.map(\.symbol), ["AAA", "BBB", "CCC"])
    }

    func testSearchFiltersBySymbolAndCompanyName() async {
        let repository = TestStockRepository()
        let viewModel = makeViewModel(repository: repository)
        repository.emit(snapshot: [
            Stock(symbol: "AAPL", name: "Apple Inc.", description: "", price: 10, change: 1),
            Stock(symbol: "MSFT", name: "Microsoft", description: "", price: 20, change: 1)
        ])
        await waitForPublished(viewModel.$stocks) { $0.count == 2 }

        viewModel.searchQuery = "micro"
        XCTAssertEqual(viewModel.sortedStocks.map(\.symbol), ["MSFT"])
        viewModel.searchQuery = "aap"
        XCTAssertEqual(viewModel.sortedStocks.map(\.symbol), ["AAPL"])
    }

    func testViewModelStartsWithRepositorySnapshot() async {
        let repository = TestStockRepository()
        repository.emit(snapshot: [stock("AAA", price: 10, change: 1)])

        let viewModel = makeViewModel(repository: repository)
        await waitForPublished(viewModel.$stocks) { $0 == repository.stocks }

        XCTAssertEqual(viewModel.stocks, repository.stocks)
    }

    func testListAndDetailObserveTheSameRepositoryState() async {
        let repository = TestStockRepository()
        let viewModel = makeViewModel(repository: repository)
        let detail = StockDetailViewModel(symbol: "AAA", stockListViewModel: viewModel)
        repository.emit(snapshot: [stock("AAA", price: 10, change: 1)])
        await waitForPublished(viewModel.$stocks) { $0.first?.price == 10 }
        XCTAssertEqual(detail.stock?.price, 10)

        repository.emit(StockPriceUpdate(symbol: "AAA", price: 15, change: 2))
        await waitForPublished(viewModel.$stocks) { $0.first?.price == 15 }

        XCTAssertEqual(repository.stocks.first?.price, 15)
        XCTAssertEqual(detail.stock?.price, 15)
        XCTAssertEqual(viewModel.stocks.first?.price, 15)
    }

    func testPriceGeneratorProducesValidDeterministicSnapshotsAndUpdates() throws {
        let first = StockPriceGenerator(random: SeededRandomNumberGenerator(seed: 42))
        let second = StockPriceGenerator(random: SeededRandomNumberGenerator(seed: 42))

        let firstSnapshot = first.makeSnapshot()
        let secondSnapshot = second.makeSnapshot()
        XCTAssertEqual(firstSnapshot.map(\.symbol), StockWatchlist.symbols)
        XCTAssertEqual(firstSnapshot.map(\.price), secondSnapshot.map(\.price))
        XCTAssertTrue(firstSnapshot.allSatisfy {
            $0.price.isFinite && $0.price > 0 && (-2...2).contains($0.change)
        })

        let firstUpdate = try first.makeUpdate()
        let secondUpdate = try second.makeUpdate()
        XCTAssertEqual(firstUpdate, secondUpdate)
        XCTAssertTrue(StockWatchlist.symbols.contains(firstUpdate.symbol))
        XCTAssertTrue(firstUpdate.price.isFinite && firstUpdate.price > 0)
        XCTAssertTrue(firstUpdate.change.isFinite && (-1.2...1.2).contains(firstUpdate.change))
    }

    func testMapperRejectsUnknownSymbolsAndInvalidValues() throws {
        XCTAssertThrowsError(try StockFeedMapper.validatedSnapshot(from: StockFeedDTO(
            type: "snapshot",
            symbols: nil,
            stocks: [stock("FAKE", price: 10, change: 1)],
            symbol: nil,
            price: nil,
            change: nil
        )))
        XCTAssertThrowsError(try StockFeedMapper.stockUpdate(from: StockFeedDTO(
            type: "update",
            symbols: nil,
            stocks: nil,
            symbol: "AAPL",
            price: .infinity,
            change: 1
        )))
        XCTAssertThrowsError(try StockFeedMapper.stockUpdate(from: StockFeedDTO(
            type: "update",
            symbols: nil,
            stocks: nil,
            symbol: "UNKNOWN",
            price: 10,
            change: 1
        )))
    }

    func testEchoedSnapshotsAndUpdatesAreStoredByRepository() async {
        let socket = EchoingSocket()
        let repository = WebSocketStockRepository(socket: socket, updateInterval: .milliseconds(250))
        let viewModel = makeViewModel(repository: repository)
        defer { repository.stop() }
        repository.start()

        await waitForPublished(viewModel.$stocks) { $0.count == StockWatchlist.companies.count }
        let initialDates = Dictionary(uniqueKeysWithValues: viewModel.stocks.map { ($0.symbol, $0.lastUpdated) })
        await waitForPublished(viewModel.$stocks) {
            $0.contains { stock in
                guard let initialDate = initialDates[stock.symbol] else { return false }
                return stock.lastUpdated > initialDate
            }
        }

        XCTAssertEqual(repository.stocks, viewModel.stocks)
        XCTAssertTrue(socket.sentMessages.contains { $0.contains("\"type\":\"update\"") })
    }

    func testRapidStartStopNeverLeavesMultipleSocketSessions() async {
        let socket = EchoingSocket()
        let repository = WebSocketStockRepository(socket: socket)
        let firstConnection = expectation(description: "First socket session starts")
        socket.onConnect = { _ in firstConnection.fulfill() }

        repository.start()
        await fulfillment(of: [firstConnection], timeout: 3)
        repository.stop()
        let secondConnection = expectation(description: "Restarted socket session starts")
        socket.onConnect = { _ in secondConnection.fulfill() }
        repository.start()
        await fulfillment(of: [secondConnection], timeout: 3)
        XCTAssertEqual(socket.connectionCount, 2)
        XCTAssertNotEqual(socket.connectedSessionIDs[0], socket.connectedSessionIDs[1])
        XCTAssertLessThanOrEqual(socket.maximumActiveSessions, 1)
        repository.stop()
        XCTAssertEqual(socket.activeSessionCount, 0)
    }

    func testTransportFailureReconnectsAndPublishesSnapshot() async {
        let socket = EchoingSocket(receiveFailures: 1)
        let repository = WebSocketStockRepository(
            socket: socket,
            reconnectPolicy: ReconnectPolicy(initialDelay: 0.001, maximumDelay: 0.001, jitterFraction: 0)
        )
        let viewModel = makeViewModel(repository: repository)
        let connections = expectation(description: "Initial connection and reconnect")
        connections.expectedFulfillmentCount = 2
        socket.onConnect = { _ in connections.fulfill() }
        defer { repository.stop() }

        repository.start()
        await fulfillment(of: [connections], timeout: 3)
        await waitForPublished(viewModel.$stocks) { $0.count == StockWatchlist.companies.count }

        XCTAssertEqual(socket.connectionCount, 2)
        XCTAssertLessThanOrEqual(socket.maximumActiveSessions, 1)
    }

    func testStoppingDuringInFlightReceiveAllowsCleanRestart() async {
        let socket = EchoingSocket(blockNextReceive: true)
        let repository = WebSocketStockRepository(socket: socket)
        let viewModel = makeViewModel(repository: repository)
        let blockedReceive = expectation(description: "First session is blocked in receive")
        socket.onBlockedReceive = { _ in blockedReceive.fulfill() }

        repository.start()
        await fulfillment(of: [blockedReceive], timeout: 3)
        repository.stop()

        let restartedConnection = expectation(description: "New session starts after cancellation")
        socket.onConnect = { _ in restartedConnection.fulfill() }
        repository.start()
        await fulfillment(of: [restartedConnection], timeout: 3)
        await waitForPublished(viewModel.$stocks) { $0.count == StockWatchlist.companies.count }
        XCTAssertEqual(repository.stocks, viewModel.stocks)
        XCTAssertEqual(socket.activeSessionCount, 1)
        XCTAssertEqual(socket.maximumActiveSessions, 1)
        repository.stop()
    }

    func testRepositoryFinishesStreamsOnShutdown() async {
        let repository = WebSocketStockRepository(socket: EchoingSocket())
        var iterator = repository.stockSnapshots.makeAsyncIterator()
        var stateIterator = repository.connectionStates.makeAsyncIterator()
        let initialSnapshot = await iterator.next()
        let initialState = await stateIterator.next()
        XCTAssertEqual(initialSnapshot, [])
        XCTAssertEqual(initialState, .disconnected)

        repository.finish()

        let finishedSnapshot = await iterator.next()
        let finishedState = await stateIterator.next()
        XCTAssertNil(finishedSnapshot)
        XCTAssertNil(finishedState)
    }

    func testReconnectBackoffIsExponentialBoundedAndResettable() {
        let policy = ReconnectPolicy(initialDelay: 1, maximumDelay: 5, jitterFraction: 0.2)
        XCTAssertEqual(policy.delay(forAttempt: 1, jitter: 0), .seconds(1))
        XCTAssertEqual(policy.delay(forAttempt: 2, jitter: 0), .seconds(2))
        XCTAssertEqual(policy.delay(forAttempt: 10, jitter: 1), .seconds(5))
        XCTAssertEqual(policy.delay(forAttempt: 1, jitter: -1), .milliseconds(800))
    }

    func testNetworkManagerRejectsStaleSessionIdentifiers() async {
        let network = NetworkManager()
        let staleSessionID = UUID()
        do {
            try await network.send("{}", sessionID: staleSessionID)
            XCTFail("Send should fail for a session that was never connected")
        } catch {
            XCTAssertEqual(error as? WebSocketError, .connectionReplaced)
        }
        do {
            _ = try await network.receive(sessionID: staleSessionID)
            XCTFail("Receive should fail for a session that was never connected")
        } catch {
            XCTAssertEqual(error as? WebSocketError, .connectionReplaced)
        }
    }

    func testNetworkErrorClassificationMarksProtocolErrorsNonRetryable() {
        XCTAssertFalse(WebSocketError.invalidPayload.isRetryable)
        XCTAssertFalse(WebSocketError.unexpectedEcho.isRetryable)
        XCTAssertTrue(WebSocketError.classify(URLError(.notConnectedToInternet)).isRetryable)
    }

    func testCoordinatorIgnoresRepeatedStartsAndPausesForBackground() {
        let repository = TestStockRepository()
        let provider = RecordingAnalyticsProvider()
        let coordinator = AppCoordinator(
            repository: repository,
            analytics: AnalyticsOrchestrator(providers: [provider])
        )

        coordinator.startFeed()
        coordinator.startFeed()
        coordinator.sceneDidChange(isActive: false)
        coordinator.sceneDidChange(isActive: true)
        coordinator.stopFeed()

        XCTAssertEqual(repository.startCount, 2)
        XCTAssertEqual(repository.stopCount, 2)
        XCTAssertEqual(provider.events.filter { $0.name == "feed_started" }.count, 1)
        XCTAssertEqual(provider.events.filter { $0.name == "feed_stopped" }.count, 1)
    }

    func testMalformedAndUnexpectedEchoesFailTheFeed() async {
        let responses: [(String) -> String] = [
            { _ in "not-json" },
            { message in message.replacingOccurrences(of: "AAPL", with: "WRONG") }
        ]
        for response in responses {
            let repository = WebSocketStockRepository(socket: EchoingSocket(response: response))
            let viewModel = makeViewModel(repository: repository)
            repository.start()
            await waitForPublished(viewModel.$connectionState) {
                if case .failed = $0 { return true }
                return false
            }
            XCTAssertTrue(viewModel.stocks.isEmpty)
            repository.stop()
        }
    }

    func testAnalyticsOrchestratorSendsEventToEveryProvider() {
        let first = RecordingAnalyticsProvider()
        let second = RecordingAnalyticsProvider()
        AnalyticsOrchestrator(providers: [first, second])
            .track(.stockSelected(symbol: "AAPL"))
        XCTAssertEqual(first.events.count, 1)
        XCTAssertEqual(second.events.first?.properties["symbol"], "AAPL")
    }

    func testLocalizationKeysExistInBothLanguages() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Stock Price Tracker/Resources")
        for language in ["en", "ar"] {
            let file = resources
                .appendingPathComponent("\(language).lproj")
                .appendingPathComponent("Localizable.strings")
            let contents = try String(contentsOf: file, encoding: .utf8)
            for key in ["market.title", "feed.start", "stock.search", "sort.priceAscending"] {
                XCTAssertTrue(contents.contains("\"\(key)\" ="), "Missing \(key) in \(language)")
            }
        }
    }

    private func makeViewModel(repository: StockRepository) -> StockListViewModel {
        let coordinator = AppCoordinator(
            repository: repository,
            analytics: AnalyticsOrchestrator(providers: [])
        )
        return StockListViewModel(repository: repository, coordinator: coordinator)
    }

    private func stock(_ symbol: String, price: Double, change: Double) -> Stock {
        Stock(symbol: symbol, name: symbol, description: symbol, price: price, change: change)
    }

    private func waitForPublished<Value>(
        _ publisher: Published<Value>.Publisher,
        timeout: TimeInterval = 3,
        matching predicate: @escaping (Value) -> Bool
    ) async {
        let expectation = expectation(description: "Published value matches predicate")
        var didFulfill = false
        let cancellable = publisher.sink { value in
            if !didFulfill, predicate(value) {
                didFulfill = true
                expectation.fulfill()
            }
        }
        await fulfillment(of: [expectation], timeout: timeout)
        cancellable.cancel()
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return state
    }
}

private final class RecordingAnalyticsProvider: AnalyticsProvider {
    private(set) var events: [AnalyticsEvent] = []
    func track(event: AnalyticsEvent) { events.append(event) }
}

@MainActor
private final class TestStockRepository: StockRepository {
    private let snapshotContinuation: AsyncStream<[Stock]>.Continuation
    private let stateContinuation: AsyncStream<WebSocketConnectionState>.Continuation
    private(set) var stocks: [Stock] = []
    private(set) var startCount = 0
    private(set) var stopCount = 0

    let stockSnapshots: AsyncStream<[Stock]>
    let connectionStates: AsyncStream<WebSocketConnectionState>

    init() {
        var snapshots: AsyncStream<[Stock]>.Continuation!
        stockSnapshots = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { snapshots = $0 }
        snapshotContinuation = snapshots
        var states: AsyncStream<WebSocketConnectionState>.Continuation!
        connectionStates = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { states = $0 }
        stateContinuation = states
    }

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }

    func emit(snapshot: [Stock]) {
        stocks = snapshot
        snapshotContinuation.yield(stocks)
    }

    func emit(_ update: StockPriceUpdate) {
        guard let index = stocks.firstIndex(where: { $0.symbol == update.symbol }) else { return }
        stocks[index].price = update.price
        stocks[index].change = update.change
        stocks[index].lastUpdated = .now
        snapshotContinuation.yield(stocks)
    }
}

@MainActor
private final class EchoingSocket: WebSocketManaging {
    private struct Session {
        let continuation: AsyncStream<String>.Continuation
        var iterator: AsyncStream<String>.Iterator
    }

    private var sessions: [UUID: Session] = [:]
    private var pendingReceives: [UUID: CheckedContinuation<String, Error>] = [:]
    private let response: (String) -> String
    private var receiveFailures: Int
    private var blockNextReceive: Bool
    private(set) var sentMessages: [String] = []
    private(set) var disconnectCount = 0
    private(set) var connectionCount = 0
    private(set) var maximumActiveSessions = 0
    private(set) var connectedSessionIDs: [UUID] = []
    var onConnect: ((UUID) -> Void)?
    var onBlockedReceive: ((UUID) -> Void)?

    var activeSessionCount: Int { sessions.count }

    init(
        receiveFailures: Int = 0,
        blockNextReceive: Bool = false,
        response: @escaping (String) -> String = { $0 }
    ) {
        self.response = response
        self.receiveFailures = receiveFailures
        self.blockNextReceive = blockNextReceive
    }

    func connect(to endpoint: URL) -> UUID {
        let sessionID = UUID()
        let stream = AsyncStream<String>.makeStream(bufferingPolicy: .bufferingNewest(8))
        sessions[sessionID] = Session(continuation: stream.continuation, iterator: stream.stream.makeAsyncIterator())
        connectionCount += 1
        connectedSessionIDs.append(sessionID)
        maximumActiveSessions = max(maximumActiveSessions, sessions.count)
        onConnect?(sessionID)
        return sessionID
    }

    func send(_ message: String, sessionID: UUID) async throws {
        guard let session = sessions[sessionID] else { throw WebSocketError.connectionReplaced }
        sentMessages.append(message)
        session.continuation.yield(response(message))
    }

    func receive(sessionID: UUID) async throws -> String {
        if receiveFailures > 0 {
            receiveFailures -= 1
            throw URLError(.networkConnectionLost)
        }
        if blockNextReceive {
            blockNextReceive = false
            onBlockedReceive?(sessionID)
            return try await withCheckedThrowingContinuation { pendingReceives[sessionID] = $0 }
        }
        guard var session = sessions[sessionID] else { throw WebSocketError.connectionReplaced }
        guard let message = await session.iterator.next() else {
            throw WebSocketError.connectionReplaced
        }
        guard sessions[sessionID] != nil else { throw WebSocketError.connectionReplaced }
        sessions[sessionID] = session
        return message
    }

    func disconnect(sessionID: UUID) {
        guard let session = sessions.removeValue(forKey: sessionID) else { return }
        disconnectCount += 1
        session.continuation.finish()
        pendingReceives.removeValue(forKey: sessionID)?.resume(throwing: WebSocketError.connectionReplaced)
    }

}
