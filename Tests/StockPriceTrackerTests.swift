import Combine
import XCTest
@testable import Stock_Price_Tracker

@MainActor
final class StockPriceTrackerTests: XCTestCase {
    func testAppConfigurationUsesSecureWebSocketEndpoint() {
        XCTAssertEqual(AppConfiguration.stockFeedEndpoint.scheme, "wss")
        XCTAssertEqual(AppConfiguration.stockFeedEndpoint.host, "ws.postman-echo.com")
        XCTAssertEqual(AppConfiguration.stockFeedEndpoint.path, "/raw")
    }

    func testAppLoggerCreatesLoggerForCategory() {
        let logger = AppLogger.logger(category: "UnitTest")
        logger.info("Logger is available for the requested category.")

        let fallbackLogger = AppLogger.logger(category: "UnitTestFallback", bundleIdentifier: nil)
        fallbackLogger.info("Logger falls back to the default subsystem when no bundle ID exists.")
    }

    func testStockIdentitySignAndWatchlistMetadataAreConsistent() {
        let positive = stock("AAA", price: 10, change: 0)
        let negative = stock("BBB", price: 10, change: -0.01)

        XCTAssertEqual(positive.id, positive.symbol)
        XCTAssertTrue(positive.isPositive)
        XCTAssertFalse(negative.isPositive)
        XCTAssertEqual(StockWatchlist.symbols.count, StockWatchlist.companies.count)
        XCTAssertEqual(Set(StockWatchlist.symbols).count, StockWatchlist.symbols.count)
        XCTAssertTrue(StockWatchlist.companies.allSatisfy {
            !$0.symbol.isEmpty && !$0.name.isEmpty && !$0.description.isEmpty
        })
    }

    func testStockPriceUpdateDefaultsAbsoluteChangeToZeroForInitialPayloads() {
        let update = StockPriceUpdate(symbol: "AAPL", price: 100, change: 0)
        XCTAssertEqual(update.absoluteChange, 0)
    }

    func testSortOptionsHaveStableIdentifiersForEverySortMode() {
        XCTAssertEqual(
            StockSortOption.allCases.map(\.id),
            ["priceAscending", "priceDescending", "changeAscending", "changeDescending"]
        )
    }

    func testLocaleFormattingRespectsSelectedLocale() {
        let englishCurrency = LocaleFormatting.currency(1234.56, locale: Locale(identifier: "en_US"))
        let germanCurrency = LocaleFormatting.currency(1234.56, locale: Locale(identifier: "de_DE"))
        let arabicCurrency = LocaleFormatting.currency(1234.56, locale: Locale(identifier: "ar_EG"))
        let englishPercentage = LocaleFormatting.percentage(12.34, locale: Locale(identifier: "en_US"))
        let germanPercentage = LocaleFormatting.percentage(12.34, locale: Locale(identifier: "de_DE"))

        XCTAssertNotEqual(englishCurrency, germanCurrency)
        XCTAssertNotEqual(englishCurrency, arabicCurrency)
        XCTAssertNotEqual(englishPercentage, germanPercentage)
        XCTAssertTrue(englishCurrency.contains("$"))
        XCTAssertTrue(germanCurrency.contains(","))
        XCTAssertTrue(englishPercentage.contains("."))
        XCTAssertTrue(germanPercentage.contains(","))
    }

    func testAnalyticsEventsExposeExpectedNamesAndProperties() {
        let cases: [(AnalyticsEvent, String, [String: String])] = [
            (.stockSelected(symbol: "AAPL"), "stock_selected", ["symbol": "AAPL"]),
            (.feedStarted, "feed_started", [:]),
            (.feedStopped, "feed_stopped", [:]),
            (.connectionEstablished, "connection_established", [:]),
            (.connectionLost, "connection_lost", [:]),
            (.sortChanged(type: "priceAscending"), "sort_changed", ["type": "priceAscending"])
        ]

        for (event, name, properties) in cases {
            XCTAssertEqual(event.name, name)
            XCTAssertEqual(event.properties, properties)
        }
    }

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

        repository.emit(StockPriceUpdate(symbol: "AAA", price: 15, change: 2, absoluteChange: 5))
        await waitForPublished(viewModel.$stocks) { $0.first?.price == 15 }

        XCTAssertEqual(repository.stocks.first?.price, 15)
        XCTAssertEqual(repository.stocks.first?.absoluteChange, 5)
        XCTAssertEqual(detail.stock?.price, 15)
        XCTAssertEqual(detail.stock?.absoluteChange, 5)
        XCTAssertEqual(viewModel.stocks.first?.price, 15)
        XCTAssertEqual(viewModel.stocks.first?.absoluteChange, 5)
    }

    func testPriceGeneratorProducesValidDeterministicSnapshotsAndUpdates() throws {
        let first = StockPriceGenerator(random: SeededRandomNumberGenerator(seed: 42))
        let second = StockPriceGenerator(random: SeededRandomNumberGenerator(seed: 42))

        let firstSnapshot = first.makeSnapshot()
        let secondSnapshot = second.makeSnapshot()
        XCTAssertEqual(firstSnapshot.map(\.symbol), StockWatchlist.symbols)
        XCTAssertEqual(firstSnapshot.map(\.price), secondSnapshot.map(\.price))
        XCTAssertTrue(firstSnapshot.allSatisfy {
            $0.price.isFinite && $0.price > 0 && $0.change == 0 && $0.absoluteChange == 0
        })

        let firstUpdate = try first.makeUpdate()
        let secondUpdate = try second.makeUpdate()
        XCTAssertEqual(firstUpdate, secondUpdate)
        XCTAssertTrue(StockWatchlist.symbols.contains(firstUpdate.symbol))
        XCTAssertTrue(firstUpdate.price.isFinite && firstUpdate.price > 0)
        XCTAssertTrue(firstUpdate.change.isFinite && (-1.2...1.2).contains(firstUpdate.change))
        XCTAssertTrue(firstUpdate.absoluteChange.isFinite)
    }

    func testPriceGeneratorCalculatesAbsoluteAndPercentageMovementFromPriorPrice() throws {
        var observedPositiveChange = false
        var observedNegativeChange = false

        for seed in 0..<20 {
            let generator = StockPriceGenerator(random: SeededRandomNumberGenerator(seed: UInt64(seed)))
            let snapshot = generator.makeSnapshot()
            let update = try generator.makeUpdate()
            let previousPrice = try XCTUnwrap(snapshot.first { $0.symbol == update.symbol }?.price)

            XCTAssertEqual(update.absoluteChange, update.price - previousPrice, accuracy: 0.000_000_1)
            XCTAssertEqual(update.change, update.absoluteChange / previousPrice * 100, accuracy: 0.000_000_1)
            observedPositiveChange = observedPositiveChange || update.absoluteChange > 0
            observedNegativeChange = observedNegativeChange || update.absoluteChange < 0
        }

        XCTAssertTrue(observedPositiveChange)
        XCTAssertTrue(observedNegativeChange)
    }

    func testPriceGeneratorRequiresSnapshotBeforeGeneratingUpdates() {
        let generator = StockPriceGenerator(random: SeededRandomNumberGenerator(seed: 7))
        XCTAssertThrowsError(try generator.makeUpdate())
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
            symbol: "AAPL",
            price: 10,
            change: 1,
            absoluteChange: .infinity
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

    func testMapperPreservesValidSnapshotAndBuildsFeedMessages() throws {
        let input = [
            stock("AAPL", price: 100, change: 1.25),
            stock("MSFT", price: 200, change: -0.5)
        ]
        let snapshotMessage = StockFeedMapper.snapshotMessage(input)
        XCTAssertEqual(snapshotMessage.type, "snapshot")
        XCTAssertEqual(try StockFeedMapper.validatedSnapshot(from: snapshotMessage), input)

        let update = StockPriceUpdate(symbol: "AAPL", price: 101, change: 1, absoluteChange: 1)
        let updateMessage = StockFeedMapper.updateMessage(update)
        XCTAssertEqual(updateMessage.type, "update")
        XCTAssertEqual(try StockFeedMapper.stockUpdate(from: updateMessage), update)
    }

    func testMapperRejectsEmptyDuplicateAndMalformedSnapshots() {
        let malformedSnapshots = [
            StockFeedDTO(type: "snapshot", symbols: nil, stocks: [], symbol: nil, price: nil, change: nil),
            StockFeedDTO(type: "snapshot", symbols: nil, stocks: [
                stock("AAPL", price: 10, change: 0),
                stock("AAPL", price: 11, change: 1)
            ], symbol: nil, price: nil, change: nil),
            StockFeedDTO(type: "update", symbols: nil, stocks: [
                stock("AAPL", price: 10, change: 0)
            ], symbol: nil, price: nil, change: nil),
            StockFeedDTO(type: "snapshot", symbols: nil, stocks: [
                stock("AAPL", price: 0, change: 0)
            ], symbol: nil, price: nil, change: nil),
            StockFeedDTO(type: "snapshot", symbols: nil, stocks: [
                stock("AAPL", price: 10, change: .nan)
            ], symbol: nil, price: nil, change: nil)
        ]

        for payload in malformedSnapshots {
            XCTAssertThrowsError(try StockFeedMapper.validatedSnapshot(from: payload))
        }
    }

    func testStockFeedDTOEncodesAndDecodesAllPayloadFields() throws {
        let payload = StockFeedDTO(
            type: "update",
            symbols: ["AAPL"],
            stocks: [stock("AAPL", price: 125.5, change: 2)],
            symbol: "AAPL",
            price: 125.5,
            change: 2,
            absoluteChange: 2.5
        )
        let decoded = try JSONDecoder().decode(StockFeedDTO.self, from: JSONEncoder().encode(payload))

        XCTAssertEqual(decoded, payload)
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

    func testNetworkManagerDoesNotLetOldSessionOperateOnReplacement() async {
        let network = NetworkManager()
        let endpoint = URL(string: "wss://127.0.0.1:1/raw")!
        let oldSessionID = network.connect(to: endpoint)
        let currentSessionID = network.connect(to: endpoint)
        defer { network.disconnect(sessionID: currentSessionID) }

        do {
            try await network.send("{}", sessionID: oldSessionID)
            XCTFail("A replaced session must not send")
        } catch {
            XCTAssertEqual(error as? WebSocketError, .connectionReplaced)
        }

        do {
            _ = try await network.receive(sessionID: oldSessionID)
            XCTFail("A replaced session must not receive")
        } catch {
            XCTAssertEqual(error as? WebSocketError, .connectionReplaced)
        }
    }

    func testNetworkManagerSendsReceivesAndDecodesStringAndDataMessages() async throws {
        let socket = TestWebSocketTask()
        let network = NetworkManager(taskFactory: { _ in socket })
        let endpoint = URL(string: "wss://example.test/stock-feed")!
        let sessionID = network.connect(to: endpoint)

        try await network.send("request", sessionID: sessionID)
        socket.enqueue(.string("text response"))
        let textResponse = try await network.receive(sessionID: sessionID)
        XCTAssertEqual(textResponse, "text response")

        socket.enqueue(.data(Data("data response".utf8)))
        let dataResponse = try await network.receive(sessionID: sessionID)
        XCTAssertEqual(dataResponse, "data response")
        XCTAssertEqual(socket.sentMessages.count, 1)
        XCTAssertTrue(socket.isResumed)

        network.disconnect(sessionID: sessionID)
        XCTAssertTrue(socket.isCancelled)
    }

    func testNetworkManagerRejectsInvalidUTF8AndClassifiesTransportFailure() async {
        let socket = TestWebSocketTask()
        let network = NetworkManager(taskFactory: { _ in socket })
        let sessionID = network.connect(to: URL(string: "wss://example.test/stock-feed")!)

        socket.enqueue(.data(Data([0xFF])))
        do {
            _ = try await network.receive(sessionID: sessionID)
            XCTFail("Invalid UTF-8 data should be rejected")
        } catch {
            XCTAssertEqual(error as? WebSocketError, .invalidUTF8)
        }

        socket.receiveError = URLError(.networkConnectionLost)
        do {
            _ = try await network.receive(sessionID: sessionID)
            XCTFail("Transport errors should be classified")
        } catch let error as WebSocketError {
            guard case .transportFailure = error else {
                return XCTFail("Expected a transport failure, got \(error)")
            }
        } catch {
            XCTFail("Expected WebSocketError, got \(error)")
        }

        network.disconnect(sessionID: sessionID)
    }

    func testNetworkManagerClassifiesSendCancellation() async {
        let socket = TestWebSocketTask()
        socket.sendError = URLError(.cancelled)
        let network = NetworkManager(taskFactory: { _ in socket })
        let sessionID = network.connect(to: URL(string: "wss://example.test/stock-feed")!)

        do {
            try await network.send("request", sessionID: sessionID)
            XCTFail("Cancelled sends should be classified")
        } catch {
            XCTAssertEqual(error as? WebSocketError, .connectionReplaced)
        }

        network.disconnect(sessionID: sessionID)
    }

    func testNetworkManagerRejectsCompletionFromReplacedInFlightSend() async {
        let socket = TestWebSocketTask()
        socket.blockNextSend = true
        let network = NetworkManager(taskFactory: { _ in socket })
        let endpoint = URL(string: "wss://example.test/stock-feed")!
        let sessionID = network.connect(to: endpoint)
        let sendBlocked = expectation(description: "Send suspended before it completes")
        socket.onSendBlocked = { sendBlocked.fulfill() }

        let sendTask = Task {
            try await network.send("request", sessionID: sessionID)
        }
        await fulfillment(of: [sendBlocked], timeout: 3)
        _ = network.connect(to: endpoint)
        socket.completePendingSend()

        do {
            try await sendTask.value
            XCTFail("A send completing on a replaced session must be rejected")
        } catch {
            XCTAssertEqual(error as? WebSocketError, .connectionReplaced)
        }
    }

    func testURLSessionWebSocketAdapterClassifiesUnavailableServer() async {
        let network = NetworkManager()
        let sessionID = network.connect(to: URL(string: "ws://127.0.0.1:1/stock-feed")!)
        defer { network.disconnect(sessionID: sessionID) }

        do {
            try await network.send("request", sessionID: sessionID)
            XCTFail("An unavailable loopback server should fail the WebSocket send")
        } catch let error as WebSocketError {
            guard case .transportFailure = error else {
                return XCTFail("Expected a transport failure, got \(error)")
            }
        } catch {
            XCTFail("Expected WebSocketError, got \(error)")
        }

        do {
            _ = try await network.receive(sessionID: sessionID)
            XCTFail("Receiving from an unavailable server should fail")
        } catch let error as WebSocketError {
            guard case .transportFailure = error else {
                return XCTFail("Expected a transport failure, got \(error)")
            }
        } catch {
            XCTFail("Expected WebSocketError, got \(error)")
        }
    }

    func testNetworkManagerIgnoresDisconnectFromReplacedSession() {
        let firstSocket = TestWebSocketTask()
        let secondSocket = TestWebSocketTask()
        var sockets = [firstSocket, secondSocket]
        let network = NetworkManager(taskFactory: { _ in sockets.removeFirst() })
        let endpoint = URL(string: "wss://example.test/stock-feed")!

        let oldSessionID = network.connect(to: endpoint)
        let currentSessionID = network.connect(to: endpoint)
        network.disconnect(sessionID: oldSessionID)

        XCTAssertTrue(firstSocket.isCancelled)
        XCTAssertFalse(secondSocket.isCancelled)

        network.disconnect(sessionID: currentSessionID)
        XCTAssertTrue(secondSocket.isCancelled)
    }

    func testNetworkErrorClassificationMarksProtocolErrorsNonRetryable() {
        let terminalErrors: [WebSocketError] = [
            .invalidUTF8, .unsupportedMessage, .invalidPayload, .unexpectedEcho
        ]
        XCTAssertTrue(terminalErrors.allSatisfy { !$0.isRetryable })
        XCTAssertTrue(WebSocketError.notConnected.isRetryable)
        XCTAssertTrue(WebSocketError.connectionReplaced.isRetryable)
        XCTAssertTrue(WebSocketError.classify(URLError(.notConnectedToInternet)).isRetryable)
        XCTAssertEqual(WebSocketError.invalidPayload.errorDescription, "The WebSocket returned an invalid stock feed payload.")
        guard case let .transportFailure(code, _) = WebSocketError.classify(
            NSError(domain: "UnitTestTransport", code: 17)
        ) else {
            return XCTFail("Unknown transport errors should be classified as retryable transport failures")
        }
        XCTAssertEqual(code, 17)
    }

    func testConnectionStateRunningStatusMatchesLifecycle() {
        XCTAssertFalse(WebSocketConnectionState.disconnected.isRunning)
        XCTAssertTrue(WebSocketConnectionState.connecting.isRunning)
        XCTAssertTrue(WebSocketConnectionState.connected.isRunning)
        XCTAssertTrue(WebSocketConnectionState.reconnecting.isRunning)
        XCTAssertFalse(WebSocketConnectionState.failed("offline").isRunning)
    }

    func testRepositoryPublishesLatestConnectionStateAfterRapidStop() async {
        let repository = WebSocketStockRepository(socket: EchoingSocket())
        var stateIterator = repository.connectionStates.makeAsyncIterator()
        _ = await stateIterator.next()

        repository.start()
        repository.stop()

        let latestState = await stateIterator.next()
        XCTAssertEqual(latestState, .disconnected)
        repository.finish()
    }

    func testRepositoryDoesNotReconnectAfterInvalidPayload() async {
        let socket = EchoingSocket(response: { _ in "not-json" })
        let repository = WebSocketStockRepository(socket: socket)
        let viewModel = makeViewModel(repository: repository)
        defer { repository.stop() }

        repository.start()
        await waitForPublished(viewModel.$connectionState) {
            if case .failed = $0 { return true }
            return false
        }

        XCTAssertEqual(socket.connectionCount, 1)
        guard case let .failed(message) = viewModel.connectionState else {
            return XCTFail("Expected an invalid payload failure")
        }
        XCTAssertFalse(message.isEmpty)
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

    func testCoordinatorTracksConnectionTransitionsAndFeedActions() {
        let repository = TestStockRepository()
        let provider = RecordingAnalyticsProvider()
        let coordinator = AppCoordinator(
            repository: repository,
            analytics: AnalyticsOrchestrator(providers: [provider])
        )

        coordinator.startFeed()
        coordinator.connectionDidChange(.connected)
        coordinator.connectionDidChange(.connected)
        coordinator.connectionDidChange(.reconnecting)
        coordinator.connectionDidChange(.connected)
        coordinator.selectStock(symbol: "AAPL")
        coordinator.changeSort(to: "priceAscending")
        coordinator.stopFeed()

        XCTAssertEqual(provider.events.map(\.name), [
            "feed_started", "connection_established", "connection_lost",
            "connection_established", "stock_selected", "sort_changed", "feed_stopped"
        ])
    }

    func testAppContainerUsesInjectedRepositoryAndAnalyticsProvider() {
        let repository = TestStockRepository()
        let provider = RecordingAnalyticsProvider()
        let container = AppContainer(repository: repository, analyticsProviders: [provider])

        XCTAssertTrue(container.repository === repository)
        container.stockListViewModel.startFeed()
        container.stockListViewModel.selectStock(symbol: "AAPL")

        XCTAssertEqual(repository.startCount, 1)
        XCTAssertEqual(provider.events.map(\.name), ["feed_started", "stock_selected"])
    }

    func testStockListViewModelForwardsFeedSelectionAndSortActions() {
        let repository = TestStockRepository()
        let provider = RecordingAnalyticsProvider()
        let coordinator = AppCoordinator(
            repository: repository,
            analytics: AnalyticsOrchestrator(providers: [provider])
        )
        let viewModel = StockListViewModel(repository: repository, coordinator: coordinator)

        viewModel.startFeed()
        viewModel.selectStock(symbol: "AAPL")
        viewModel.sortOption = .changeAscending
        viewModel.sortOption = .changeAscending
        viewModel.stopFeed()

        XCTAssertEqual(repository.startCount, 1)
        XCTAssertEqual(repository.stopCount, 1)
        XCTAssertEqual(provider.events.map(\.name), ["feed_started", "stock_selected", "sort_changed", "feed_stopped"])
    }

    func testStockListViewModelObservesConnectionStateChanges() async {
        let repository = TestStockRepository()
        let viewModel = makeViewModel(repository: repository)

        repository.emit(state: .reconnecting)
        await waitForPublished(viewModel.$connectionState) { $0 == .reconnecting }

        XCTAssertEqual(viewModel.connectionState, .reconnecting)
    }

    func testStockDetailViewModelTracksAppearingAndRemovedStock() async {
        let repository = TestStockRepository()
        let viewModel = makeViewModel(repository: repository)
        let detail = StockDetailViewModel(symbol: "AAPL", stockListViewModel: viewModel)
        XCTAssertNil(detail.stock)

        repository.emit(snapshot: [stock("AAPL", price: 10, change: 1)])
        await waitForPublished(viewModel.$stocks) { !$0.isEmpty }
        XCTAssertEqual(detail.stock?.price, 10)

        repository.emit(snapshot: [])
        await waitForPublished(viewModel.$stocks) { $0.isEmpty }
        XCTAssertNil(detail.stock)
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
            let requiredKeys = [
                "feed.start", "feed.stop", "feed.state.connected", "feed.state.connecting",
                "feed.state.disconnected", "feed.state.failed", "feed.state.reconnecting",
                "market.empty.message", "market.empty.title", "market.title", "market.trackedSymbols",
                "sort.changeAscending", "sort.changeDescending", "sort.priceAscending",
                "sort.priceDescending", "sort.title", "stock.about", "stock.lastUpdated",
                "stock.change.absolute", "stock.search", "stock.unavailable.title"
            ]
            for key in requiredKeys {
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

    private func stock(
        _ symbol: String,
        price: Double,
        change: Double,
        absoluteChange: Double = 0
    ) -> Stock {
        Stock(
            symbol: symbol,
            name: symbol,
            description: symbol,
            price: price,
            change: change,
            absoluteChange: absoluteChange
        )
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

    func emit(state: WebSocketConnectionState) {
        stateContinuation.yield(state)
    }

    func emit(_ update: StockPriceUpdate) {
        guard let index = stocks.firstIndex(where: { $0.symbol == update.symbol }) else { return }
        stocks[index].price = update.price
        stocks[index].change = update.change
        stocks[index].absoluteChange = update.absoluteChange
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

@MainActor
private final class TestWebSocketTask: WebSocketTasking {
    private var incomingMessages: [URLSessionWebSocketTask.Message] = []
    private var nextIncomingMessage = 0
    private(set) var sentMessages: [URLSessionWebSocketTask.Message] = []
    private(set) var isResumed = false
    private(set) var isCancelled = false
    var receiveError: Error?
    var sendError: Error?
    var blockNextSend = false
    var onSendBlocked: (() -> Void)?
    private var pendingSend: CheckedContinuation<Void, Error>?

    func resume() {
        isResumed = true
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        if let sendError {
            throw sendError
        }
        sentMessages.append(message)
        guard blockNextSend else { return }
        blockNextSend = false
        try await withCheckedThrowingContinuation {
            pendingSend = $0
            onSendBlocked?()
        }
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        if let receiveError {
            throw receiveError
        }
        guard incomingMessages.indices.contains(nextIncomingMessage) else {
            throw WebSocketError.notConnected
        }
        defer { nextIncomingMessage += 1 }
        return incomingMessages[nextIncomingMessage]
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isCancelled = true
    }

    func enqueue(_ message: URLSessionWebSocketTask.Message) {
        incomingMessages.append(message)
    }

    func completePendingSend() {
        pendingSend?.resume(returning: ())
        pendingSend = nil
    }
}
